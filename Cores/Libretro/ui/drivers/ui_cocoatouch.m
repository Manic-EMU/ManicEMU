/* RetroArch - A frontend for libretro.
 *  Copyright (C) 2011-2016 - Daniel De Matteis
 *
 * RetroArch is free software: you can redistribute it and/or modify it under the terms
 * of the GNU General Public License as published by the Free Software Found-
 * ation, either version 3 of the License, or (at your option) any later version.
 *
 * RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with RetroArch.
 * If not, see <http://www.gnu.org/licenses/>.
 */

#import "LibretroCore.h"

#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <boolean.h>

#include <file/file_path.h>
#include <queues/task_queue.h>
#include <string/stdstring.h>
#include <retro_timers.h>
#include <dynamic/dylib.h>

#include "cocoa/cocoa_common.h"
#include "cocoa/apple_platform.h"
#include "../ui_companion_driver.h"
#include "../../audio/audio_driver.h"
#include "../../configuration.h"
#include "../../frontend/frontend.h"
#include "../../input/input_driver.h"
#include "../../input/drivers/cocoa_input.h"
#include "../../input/drivers_keyboard/keyboard_event_apple.h"
#include "../../retroarch.h"
#include "../../tasks/task_content.h"
#include "../../verbosity.h"
#include "../../cheevos/cheevos.h"
#include "../../gfx/video_driver.h"
#include "../../gfx/video_shader_parse.h"
#include "../../runloop.h"

#ifdef HAVE_MENU
#include "../../menu/menu_setting.h"
#endif

#ifdef HAVE_COCOA_METAL
#import <Metal/Metal.h>
#import <simd/simd.h>
#include "../../gfx/video_shader_parse.h"
#include "../../gfx/drivers_shader/slang_process.h"
#include <formats/image.h>
#endif

#import <AVFoundation/AVFoundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>

#import <MetricKit/MetricKit.h>
#import <MetricKit/MXMetricManager.h>

#ifdef HAVE_MFI
#import <GameController/GCMouse.h>
#endif

#ifdef HAVE_SDL2
#define SDL_MAIN_HANDLED
#include "SDL.h"
#endif

#if defined(HAVE_COCOA_METAL) || defined(HAVE_COCOATOUCH)
#import "JITSupport.h"
id<ApplePlatform> apple_platform;
#else
static id apple_platform;
#endif
static CFRunLoopObserverRef iterate_observer;

static void ui_companion_cocoatouch_event_command(
      void *data, enum event_command cmd) { }

static struct string_list *ui_companion_cocoatouch_get_app_icons(void)
{
   static struct string_list *list = NULL;
   static dispatch_once_t onceToken;

   dispatch_once(&onceToken, ^{
         union string_list_elem_attr attr;
         attr.i = 0;
         NSDictionary *iconfiles = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];
         NSString *primary;
         const char *cstr;
#if TARGET_OS_TV
         primary = iconfiles[@"CFBundlePrimaryIcon"];
#else
         primary = iconfiles[@"CFBundlePrimaryIcon"][@"CFBundleIconName"];
#endif
         list = string_list_new();
         cstr = [primary cStringUsingEncoding:kCFStringEncodingUTF8];
         if (cstr)
            string_list_append(list, cstr, attr);

         NSArray<NSString *> *alts;
#if TARGET_OS_TV
         alts = iconfiles[@"CFBundleAlternateIcons"];
#else
         alts = [iconfiles[@"CFBundleAlternateIcons"] allKeys];
#endif
         NSArray<NSString *> *sorted = [alts sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
         for (NSString *str in sorted)
         {
            cstr = [str cStringUsingEncoding:kCFStringEncodingUTF8];
            if (cstr)
               string_list_append(list, cstr, attr);
         }
      });

   return list;
}

static void ui_companion_cocoatouch_set_app_icon(const char *iconName)
{
   NSString *str;
   if (!string_is_equal(iconName, "Default"))
      str = [NSString stringWithCString:iconName encoding:NSUTF8StringEncoding];
   [[UIApplication sharedApplication] setAlternateIconName:str completionHandler:nil];
}

static uintptr_t ui_companion_cocoatouch_get_app_icon_texture(const char *icon)
{
   static NSMutableDictionary<NSString *, NSNumber *> *textures = nil;
   static dispatch_once_t once;
   dispatch_once(&once, ^{
      textures = [NSMutableDictionary dictionaryWithCapacity:6];
   });

   NSString *iconName = [NSString stringWithUTF8String:icon];
   if (!textures[iconName])
   {
      UIImage *img = [UIImage imageNamed:iconName];
      if (!img)
      {
         RARCH_LOG("could not load %s\n", icon);
         return 0;
      }
      NSData *png = UIImagePNGRepresentation(img);
      if (!png)
      {
         RARCH_LOG("could not get png for %s\n", icon);
         return 0;
      }

      uintptr_t item;
      gfx_display_reset_textures_list_buffer(&item, TEXTURE_FILTER_MIPMAP_LINEAR,
                                             (void*)[png bytes], (unsigned int)[png length], IMAGE_TYPE_PNG,
                                             NULL, NULL);
      textures[iconName] = [NSNumber numberWithUnsignedLong:item];
   }

   return [textures[iconName] unsignedLongValue];
}

static void rarch_draw_observer(CFRunLoopObserverRef observer,
    CFRunLoopActivity activity, void *info)
{
   uint32_t runloop_flags;
   int          ret   = runloop_iterate();

   if (ret == -1)
   {
      ui_companion_cocoatouch_event_command(
            NULL, CMD_EVENT_MENU_SAVE_CURRENT_CONFIG);
//      main_exit(NULL);
//      exit(0); //禁止杀死应用
      return;
   }

   task_queue_check();

   runloop_flags = runloop_get_flags();
   if (!(runloop_flags & RUNLOOP_FLAG_IDLE))
      CFRunLoopWakeUp(CFRunLoopGetMain());
}

void rarch_start_draw_observer(void)
{
   if (iterate_observer && CFRunLoopObserverIsValid(iterate_observer))
       return;

   if (iterate_observer != NULL)
      CFRelease(iterate_observer);
   iterate_observer = CFRunLoopObserverCreate(0, kCFRunLoopBeforeWaiting,
                                              true, 0, rarch_draw_observer, 0);
   CFRunLoopAddObserver(CFRunLoopGetMain(), iterate_observer, kCFRunLoopCommonModes);
}

void rarch_stop_draw_observer(void)
{
    if (!iterate_observer || !CFRunLoopObserverIsValid(iterate_observer))
        return;
    CFRunLoopObserverInvalidate(iterate_observer);
    CFRelease(iterate_observer);
    iterate_observer = NULL;
}

void get_ios_version(int *major, int *minor)
{
   static int savedMajor, savedMinor;
   static dispatch_once_t onceToken;

   dispatch_once(&onceToken, ^ {
         NSArray *decomposed_os_version = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
         if (decomposed_os_version.count > 0)
            savedMajor = (int)[decomposed_os_version[0] integerValue];
         if (decomposed_os_version.count > 1)
            savedMinor = (int)[decomposed_os_version[1] integerValue];
      });
   if (major) *major = savedMajor;
   if (minor) *minor = savedMinor;
}

bool ios_running_on_ipad(void)
{
   return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
}

/* Input helpers: This is kept here because it needs ObjC */
static void handle_touch_event(NSArray* touches)
{
#if !TARGET_OS_TV
   unsigned i;
   cocoa_input_data_t *apple = (cocoa_input_data_t*)
      input_state_get_ptr()->current_data;
   float scale               = cocoa_screen_get_native_scale();

   if (!apple)
      return;

   apple->touch_count = 0;

   for (i = 0; i < touches.count && (apple->touch_count < MAX_TOUCHES); i++)
   {
      UITouch      *touch = [touches objectAtIndex:i];
      CGPoint       coord = [touch locationInView:[touch view]];
      if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
      {
         apple->touches[apple->touch_count   ].screen_x = coord.x * scale;
         apple->touches[apple->touch_count ++].screen_y = coord.y * scale;
      }
   }
#endif
}

#ifndef HAVE_APPLE_STORE
/* iOS7 Keyboard support */
@interface UIEvent(iOS7Keyboard)
@property(readonly, nonatomic) long long _keyCode;
@property(readonly, nonatomic) _Bool _isKeyDown;
@property(retain, nonatomic) NSString *_privateInput;
@property(nonatomic) long long _modifierFlags;
- (struct __IOHIDEvent { }*)_hidEvent;
@end

@interface UIApplication(iOS7Keyboard)
- (void)handleKeyUIEvent:(UIEvent*)event;
- (id)_keyCommandForEvent:(UIEvent*)event;
@end
#endif

@interface RApplication : UIApplication
@end

@implementation RApplication

#ifndef HAVE_APPLE_STORE
/* Keyboard handler for iOS 7. */

/* This is copied here as it isn't
 * defined in any standard iOS header */
enum
{
   NSAlphaShiftKeyMask                  = 1 << 16,
   NSShiftKeyMask                       = 1 << 17,
   NSControlKeyMask                     = 1 << 18,
   NSAlternateKeyMask                   = 1 << 19,
   NSCommandKeyMask                     = 1 << 20,
   NSNumericPadKeyMask                  = 1 << 21,
   NSHelpKeyMask                        = 1 << 22,
   NSFunctionKeyMask                    = 1 << 23,
   NSDeviceIndependentModifierFlagsMask = 0xffff0000U
};

/* This is specifically for iOS 9, according to the private headers */
-(void)handleKeyUIEvent:(UIEvent *)event
{
    /* This gets called twice with the same timestamp
     * for each keypress, that's fine for polling
     * but is bad for business with events. */
    static double last_time_stamp;

    if (last_time_stamp == event.timestamp)
       return [super handleKeyUIEvent:event];

    last_time_stamp        = event.timestamp;

    /* If the _hidEvent is NULL, [event _keyCode] will crash.
     * (This happens with the on screen keyboard). */
    if (event._hidEvent)
    {
        NSString       *ch = (NSString*)event._privateInput;
        uint32_t character = 0;
        uint32_t mod       = 0;
        NSUInteger mods    = event._modifierFlags;

        if (mods & NSAlphaShiftKeyMask)
           mod |= RETROKMOD_CAPSLOCK;
        if (mods & NSShiftKeyMask)
           mod |= RETROKMOD_SHIFT;
        if (mods & NSControlKeyMask)
           mod |= RETROKMOD_CTRL;
        if (mods & NSAlternateKeyMask)
           mod |= RETROKMOD_ALT;
        if (mods & NSCommandKeyMask)
           mod |= RETROKMOD_META;
        if (mods & NSNumericPadKeyMask)
           mod |= RETROKMOD_NUMLOCK;

        if (ch && ch.length != 0)
        {
            unsigned i;
            character = [ch characterAtIndex:0];

            apple_input_keyboard_event(event._isKeyDown,
                  (uint32_t)event._keyCode, 0, mod,
                  RETRO_DEVICE_KEYBOARD);

            for (i = 1; i < ch.length; i++)
                apple_input_keyboard_event(event._isKeyDown,
                      0, [ch characterAtIndex:i], mod,
                      RETRO_DEVICE_KEYBOARD);
        }

        apple_input_keyboard_event(event._isKeyDown,
              (uint32_t)event._keyCode, character, mod,
              RETRO_DEVICE_KEYBOARD);
    }

    [super handleKeyUIEvent:event];
}

/* This is for iOS versions < 9.0 */
- (id)_keyCommandForEvent:(UIEvent*)event
{
   /* This gets called twice with the same timestamp
    * for each keypress, that's fine for polling
    * but is bad for business with events. */
   static double last_time_stamp;

   if (last_time_stamp == event.timestamp)
      return [super _keyCommandForEvent:event];
   last_time_stamp = event.timestamp;

   /* If the _hidEvent is null, [event _keyCode] will crash.
    * (This happens with the on screen keyboard). */
   if (event._hidEvent)
   {
      NSString       *ch = (NSString*)event._privateInput;
      uint32_t character = 0;
      uint32_t mod       = 0;
      NSUInteger mods    = event._modifierFlags;

      if (mods & NSAlphaShiftKeyMask)
         mod |= RETROKMOD_CAPSLOCK;
      if (mods & NSShiftKeyMask)
         mod |= RETROKMOD_SHIFT;
      if (mods & NSControlKeyMask)
         mod |= RETROKMOD_CTRL;
      if (mods & NSAlternateKeyMask)
         mod |= RETROKMOD_ALT;
      if (mods & NSCommandKeyMask)
         mod |= RETROKMOD_META;
      if (mods & NSNumericPadKeyMask)
         mod |= RETROKMOD_NUMLOCK;

      if (ch && ch.length != 0)
      {
         unsigned i;
         character = [ch characterAtIndex:0];

         apple_input_keyboard_event(event._isKeyDown,
               (uint32_t)event._keyCode, 0, mod,
               RETRO_DEVICE_KEYBOARD);

         for (i = 1; i < ch.length; i++)
            apple_input_keyboard_event(event._isKeyDown,
                  0, [ch characterAtIndex:i], mod,
                  RETRO_DEVICE_KEYBOARD);
      }

      apple_input_keyboard_event(event._isKeyDown,
            (uint32_t)event._keyCode, character, mod,
            RETRO_DEVICE_KEYBOARD);
   }

   return [super _keyCommandForEvent:event];
}
#else
- (void)handleUIPress:(UIPress *)press withEvent:(UIPressesEvent *)event down:(BOOL)down
{
   NSString       *ch;
   uint32_t character = 0;
   uint32_t mod       = 0;
   NSUInteger mods    = 0;
   if (@available(iOS 13.4, tvOS 13.4, *))
   {
      ch = (NSString*)press.key.characters;
      mods = event.modifierFlags;
   }

   if (mods & UIKeyModifierAlphaShift)
      mod |= RETROKMOD_CAPSLOCK;
   if (mods & UIKeyModifierShift)
      mod |= RETROKMOD_SHIFT;
   if (mods & UIKeyModifierControl)
      mod |= RETROKMOD_CTRL;
   if (mods & UIKeyModifierAlternate)
      mod |= RETROKMOD_ALT;
   if (mods & UIKeyModifierCommand)
      mod |= RETROKMOD_META;
   if (mods & UIKeyModifierNumericPad)
      mod |= RETROKMOD_NUMLOCK;

   if (ch && ch.length != 0)
   {
      unsigned i;
      character = [ch characterAtIndex:0];

      apple_input_keyboard_event(down,
                                 (uint32_t)press.key.keyCode, 0, mod,
                                 RETRO_DEVICE_KEYBOARD);

      for (i = 1; i < ch.length; i++)
         apple_input_keyboard_event(down,
                                    0, [ch characterAtIndex:i], mod,
                                    RETRO_DEVICE_KEYBOARD);
   }

   if (@available(iOS 13.4, tvOS 13.4, *))
      apple_input_keyboard_event(down,
                                 (uint32_t)press.key.keyCode, character, mod,
                                 RETRO_DEVICE_KEYBOARD);
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
   for (UIPress *press in presses)
      [self handleUIPress:press withEvent:event down:YES];
   [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
   for (UIPress *press in presses)
      [self handleUIPress:press withEvent:event down:NO];
   [super pressesEnded:presses withEvent:event];
}
#endif

#define GSEVENT_TYPE_KEYDOWN 10
#define GSEVENT_TYPE_KEYUP 11

- (void)sendEvent:(UIEvent *)event
{
   [super sendEvent:event];
   if (@available(iOS 13.4, tvOS 13.4, *))
   {
      if (event.type == UIEventTypeHover)
         return;
   }
   if (event.allTouches.count)
      handle_touch_event(event.allTouches.allObjects);

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
   {
      int major, minor;
      get_ios_version(&major, &minor);

      if ((major < 7) && [event respondsToSelector:@selector(_gsEvent)])
      {
         /* Keyboard event hack for iOS versions prior to iOS 7.
          *
          * Derived from:
                  * http://nacho4d-nacho4d.blogspot.com/2012/01/
                  * catching-keyboard-events-in-ios.html
                  */
         const uint8_t *eventMem = objc_unretainedPointer([event performSelector:@selector(_gsEvent)]);
         int           eventType = eventMem ? *(int*)&eventMem[8] : 0;

         switch (eventType)
         {
            case GSEVENT_TYPE_KEYDOWN:
              case GSEVENT_TYPE_KEYUP:
               apple_input_keyboard_event(eventType == GSEVENT_TYPE_KEYDOWN,
                     *(uint16_t*)&eventMem[0x3C], 0, 0, RETRO_DEVICE_KEYBOARD);
               break;
         }
      }
   }
#endif
}

@end

#ifdef HAVE_COCOA_METAL
@implementation MetalLayerView

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (instancetype)init {
    self = [super init];
    if (self)
        [self setupMetalLayer];
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self)
        [self setupMetalLayer];
    return self;
}

- (CAMetalLayer *)metalLayer {
    return (CAMetalLayer *)self.layer;
}

- (void)setupMetalLayer {
    self.metalLayer.device = MTLCreateSystemDefaultDevice();
    self.metalLayer.contentsScale = cocoa_screen_get_native_scale();
    self.metalLayer.opaque = YES;
}

@end
#endif

#if TARGET_OS_IOS
@interface RetroArch_iOS () <MXMetricManagerSubscriber, UIPointerInteractionDelegate>
@end
#endif

@implementation RetroArch_iOS

#pragma mark - ApplePlatform
-(id)renderView { return _renderView; }
-(bool)hasFocus
{
    return [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
}

- (void)setViewType:(apple_view_type_t)vt
{
    if (vt == _vt)
        return;
    
    _vt = vt;
    if (_renderView != nil)
    {
        [_renderView removeFromSuperview];
        _renderView = nil;
    }
    
    switch (vt)
    {
#ifdef HAVE_COCOA_METAL
        case APPLE_VIEW_TYPE_VULKAN:
            _renderView = [MetalLayerView new];
#if TARGET_OS_IOS
            _renderView.multipleTouchEnabled = YES;
#endif
            break;
        case APPLE_VIEW_TYPE_METAL:
        {
            MetalView *v = [MetalView new];
            v.paused                = YES;
            v.enableSetNeedsDisplay = NO;
#if TARGET_OS_IOS
            v.multipleTouchEnabled  = YES;
#endif
            _renderView = v;
        }
            break;
#endif
        case APPLE_VIEW_TYPE_OPENGL_ES:
            _renderView = (BRIDGE GLKView*)glkitview_init();
            break;
            
        case APPLE_VIEW_TYPE_NONE:
        default:
            return;
    }
    
    _renderView.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *rootView = [CocoaView get].view;
    [rootView addSubview:_renderView];
#if TARGET_OS_IOS
    if (@available(iOS 13.4, *))
    {
        [_renderView addInteraction:[[UIPointerInteraction alloc] initWithDelegate:self]];
        _renderView.userInteractionEnabled = YES;
    }
#endif
    [[_renderView.topAnchor constraintEqualToAnchor:rootView.topAnchor] setActive:YES];
    [[_renderView.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor] setActive:YES];
    [[_renderView.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor] setActive:YES];
    [[_renderView.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor] setActive:YES];
    [_renderView layoutIfNeeded];
}

- (apple_view_type_t)viewType { return _vt; }

- (void)setVideoMode:(gfx_ctx_mode_t)mode
{
#ifdef HAVE_COCOA_METAL
    MetalView *metalView = (MetalView*) _renderView;
    CGFloat scale        = [[UIScreen mainScreen] scale];
    [metalView setDrawableSize:CGSizeMake(
                                          _renderView.bounds.size.width * scale,
                                          _renderView.bounds.size.height * scale
                                          )];
#endif
}

- (void)setCursorVisible:(bool)v { /* no-op for iOS */ }
- (bool)setDisableDisplaySleep:(bool)disable
{
#if TARGET_OS_TV
    [[UIApplication sharedApplication] setIdleTimerDisabled:disable];
    return YES;
#else
    return NO;
#endif
}
+ (RetroArch_iOS*)get {
    return (RetroArch_iOS*)[[LibretroCore sharedInstance] retroArch_iOS];
}

-(NSString*)documentsDirectory
{
    if (_documentsDirectory == nil)
    {
#if TARGET_OS_IOS
        NSArray *paths      = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#elif TARGET_OS_TV
        NSArray *paths      = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#endif
        _documentsDirectory = paths.firstObject;
    }
    return _documentsDirectory;
}

- (void)handleAudioSessionInterruption:(NSNotification *)notification
{
    NSNumber *type = notification.userInfo[AVAudioSessionInterruptionTypeKey];
    if (![type isKindOfClass:[NSNumber class]])
        return;
    
    if ([type unsignedIntegerValue] == AVAudioSessionInterruptionTypeBegan)
    {
        RARCH_LOG("AudioSession Interruption Began\n");
        audio_driver_stop();
    }
    else if ([type unsignedIntegerValue] == AVAudioSessionInterruptionTypeEnded)
    {
        RARCH_LOG("AudioSession Interruption Ended\n");
        audio_driver_start(false);
    }
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    char arguments[]   = "retroarch";
    char       *argv[] = {arguments,   NULL};
    int argc           = 1;
    apple_platform     = self;
    
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"restore_default_config"])
    {
        [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"restore_default_config"];
        [NSUserDefaults.standardUserDefaults setObject:@"" forKey:@FILE_PATH_MAIN_CONFIG];
        
        // Get the Caches directory path
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cachesDirectory = [paths firstObject];
        
        // Define the original and new file paths
        NSString *originalPath = [cachesDirectory stringByAppendingPathComponent:@"RetroArch/config/retroarch.cfg"];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"HHmm-yyMMdd"];
        NSString *timestamp = [dateFormatter stringFromDate:[NSDate date]];
        NSString *newPath = [cachesDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"RetroArch/config/RetroArch-%@.cfg", timestamp]];
        
        // File manager instance
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // Check if the file exists and rename it
        if ([fileManager fileExistsAtPath:originalPath])
        {
            NSError *error = nil;
            if ([fileManager moveItemAtPath:originalPath toPath:newPath error:&error])
                NSLog(@"File renamed to %@", newPath);
            else
                NSLog(@"Error renaming file: %@", error.localizedDescription);
        }
        else
            NSLog(@"File does not exist at path %@", originalPath);
    }
    
    [self setDelegate:self];
    
    /* Setup window */
    self.window        = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window makeKeyAndVisible];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    
    [self showGameView];
    
    rarch_main(argc, argv, NULL);
    
    uico_driver_state_t *uico_st     = uico_state_get_ptr();
    rarch_setting_t *appicon_setting = menu_setting_find_enum(MENU_ENUM_LABEL_APPICON_SETTINGS);
    struct string_list *icons;
    if (               appicon_setting
        && uico_st->drv
        && uico_st->drv->get_app_icons
        && (icons = uico_st->drv->get_app_icons())
        && icons->size > 1)
    {
        int i;
        size_t _len    = 0;
        char *options = NULL;
        const char *icon_name;
        
        appicon_setting->default_value.string = icons->elems[0].data;
        icon_name = [[application alternateIconName] cStringUsingEncoding:kCFStringEncodingUTF8]; /* need to ask uico_st for this */
        for (i = 0; i < (int)icons->size; i++)
        {
            _len += strlen(icons->elems[i].data) + 1;
            if (string_is_equal(icon_name, icons->elems[i].data))
                appicon_setting->value.target.string = icons->elems[i].data;
        }
        options = (char*)calloc(_len, sizeof(char));
        string_list_join_concat(options, _len, icons, "|");
        if (appicon_setting->values)
            free((void*)appicon_setting->values);
        appicon_setting->values = options;
    }
    
    rarch_start_draw_observer();
    
#if TARGET_OS_TV
    update_topshelf();
#endif
    
#if TARGET_OS_IOS
    if (@available(iOS 13.0, *))
        [MXMetricManager.sharedManager addSubscriber:self];
#endif
    
#ifdef HAVE_MFI
    extern void *apple_gamecontroller_joypad_init(void *data);
    apple_gamecontroller_joypad_init(NULL);
    if (@available(macOS 11, iOS 14, tvOS 14, *))
    {
        [[NSNotificationCenter defaultCenter] addObserverForName:GCMouseDidConnectNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note)
         {
            GCMouse *mouse = note.object;
            mouse.mouseInput.mouseMovedHandler = ^(GCMouseInput * _Nonnull mouse, float delta_x, float delta_y)
            {
                cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
                if (!apple)
                    return;
                apple->window_pos_x      += (int16_t)delta_x;
                apple->window_pos_y      -= (int16_t)delta_y;
            };
            mouse.mouseInput.leftButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed)
            {
                cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
                if (!apple)
                    return;
                if (pressed)
                    apple->mouse_buttons |= (1 << 0);
                else
                    apple->mouse_buttons &= ~(1 << 0);
            };
            mouse.mouseInput.rightButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed)
            {
                cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
                if (!apple)
                    return;
                if (pressed)
                    apple->mouse_buttons |= (1 << 1);
                else
                    apple->mouse_buttons &= ~(1 << 1);
            };
        }];
    }
#endif
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
#if TARGET_OS_TV
    update_topshelf();
#endif
    rarch_stop_draw_observer();
    command_event(CMD_EVENT_SAVE_FILES, NULL);
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    rarch_stop_draw_observer();
    retroarch_main_quit();
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    self.bgDate = [NSDate date];
    rarch_stop_draw_observer();
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    rarch_start_draw_observer();
    NSError *error;
    settings_t *settings            = config_get_ptr();
    bool ui_companion_start_on_boot = settings->bools.ui_companion_start_on_boot;
    
    if (settings->bools.audio_respect_silent_mode)
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
    else
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    if (!ui_companion_start_on_boot)
        [self showGameView];
    
#ifdef HAVE_CLOUDSYNC
    if (self.bgDate)
    {
        if (   [[NSDate date] timeIntervalSinceDate:self.bgDate] > 60.0f
            && (   !(runloop_get_flags() & RUNLOOP_FLAG_CORE_RUNNING)
                || retroarch_ctl(RARCH_CTL_IS_DUMMY_CORE, NULL)))
            task_push_cloud_sync();
        self.bgDate = nil;
    }
#endif
}

-(BOOL)openRetroArchURL:(NSURL *)url
{
    if ([url.host isEqualToString:@"topshelf"])
    {
        NSURLComponents *comp = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
        NSString *ns_path, *ns_core_path;
        char path[PATH_MAX_LENGTH];
        char core_path[PATH_MAX_LENGTH];
        content_ctx_info_t content_info = { 0 };
        for (NSURLQueryItem *q in comp.queryItems)
        {
            if ([q.name isEqualToString:@"path"])
                ns_path = q.value;
            else if ([q.name isEqualToString:@"core_path"])
                ns_core_path = q.value;
        }
        if (!ns_path || !ns_core_path)
            return NO;
        fill_pathname_expand_special(path, [ns_path UTF8String], sizeof(path));
        fill_pathname_expand_special(core_path, [ns_core_path UTF8String], sizeof(core_path));
        RARCH_LOG("TopShelf told us to open %s with %s\n", path, core_path);
        return task_push_load_content_with_new_core_from_companion_ui(core_path, path,
                                                                      NULL, NULL, NULL,
                                                                      &content_info, NULL, NULL);
    }
    return NO;
}

-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    if ([[url scheme] isEqualToString:@"retroarch"])
        return [self openRetroArchURL:url];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString     *filename = (NSString*)url.path.lastPathComponent;
    NSError         *error = nil;
    settings_t *settings   = config_get_ptr();
    char fullpath[PATH_MAX_LENGTH] = {0};
    fill_pathname_join_special(fullpath, settings->paths.directory_core_assets, [filename UTF8String], sizeof(fullpath));
    NSString  *destination = [NSString stringWithUTF8String:fullpath];
    /* Copy file to documents directory if it's not already
     * inside Documents directory */
    if ([url startAccessingSecurityScopedResource])
    {
        if (![[url path] containsString: self.documentsDirectory])
            if (![manager fileExistsAtPath:destination])
                [manager copyItemAtPath:[url path] toPath:destination error:&error];
        [url stopAccessingSecurityScopedResource];
    }
    task_push_dbscan(
                     settings->paths.directory_playlist,
                     settings->paths.path_content_database,
                     fullpath,
                     false,
                     false,
                     NULL);
    return true;
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
#if TARGET_OS_IOS
    [self setToolbarHidden:![[viewController toolbarItems] count] animated:YES];
#endif
}

- (void)showGameView
{
    [self popToRootViewControllerAnimated:NO];
    
#if TARGET_OS_IOS
    [self setToolbarHidden:true animated:NO];
    [[UIApplication sharedApplication] setStatusBarHidden:true withAnimation:UIStatusBarAnimationNone];
    [[UIApplication sharedApplication] setIdleTimerDisabled:true];
#endif
    
    [self.window setRootViewController:[CocoaView get]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        command_event(CMD_EVENT_AUDIO_START, NULL);
    });
}

- (void)supportOtherAudioSessions { }

#if TARGET_OS_IOS
- (void)didReceiveMetricPayloads:(NSArray<MXMetricPayload *> *)payloads API_AVAILABLE(ios(13.0))
{
    for (MXMetricPayload *payload in payloads)
    {
        NSString *json = [[NSString alloc] initWithData:[payload JSONRepresentation] encoding:kCFStringEncodingUTF8];
        RARCH_LOG("Got Metric Payload:\n%s\n", [json cStringUsingEncoding:kCFStringEncodingUTF8]);
    }
}

- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> *)payloads API_AVAILABLE(ios(14.0))
{
    for (MXDiagnosticPayload *payload in payloads)
    {
        NSString *json = [[NSString alloc] initWithData:[payload JSONRepresentation] encoding:kCFStringEncodingUTF8];
        RARCH_LOG("Got Diagnostic Payload:\n%s\n", [json cStringUsingEncoding:kCFStringEncodingUTF8]);
    }
}

- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region API_AVAILABLE(ios(13.4))
{
    cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
    if (!apple)
        return nil;
    if (apple->mouse_grabbed)
        return [UIPointerStyle hiddenPointerStyle];
    return nil;
}

- (UIPointerRegion *)pointerInteraction:(UIPointerInteraction *)interaction
                       regionForRequest:(UIPointerRegionRequest *)request
                          defaultRegion:(UIPointerRegion *)defaultRegion API_AVAILABLE(ios(13.4))
{
    cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
    if (!apple || apple->mouse_grabbed)
        return nil;
    CGPoint location = [apple_platform.renderView convertPoint:[request location] fromView:nil];
    apple->touches[0].screen_x = (int16_t)(location.x * [[UIScreen mainScreen] scale]);
    apple->touches[0].screen_y = (int16_t)(location.y * [[UIScreen mainScreen] scale]);
    apple->window_pos_x = (int16_t)(location.x * [[UIScreen mainScreen] scale]);
    apple->window_pos_y = (int16_t)(location.y * [[UIScreen mainScreen] scale]);
    return [UIPointerRegion regionWithRect:[apple_platform.renderView bounds] identifier:@"game view"];
}
#endif

static BOOL LibretroInitial = false;
static BOOL RespectSilentMode = false;
static void *loaded_core_handle = NULL;

static void ensure_manic_joypad_driver(void) {
    settings_t *settings = config_get_ptr();
    if (!settings) {
        return;
    }

    if (!string_is_equal(settings->arrays.input_joypad_driver, "manic")) {
        configuration_set_string(settings, settings->arrays.input_joypad_driver, "manic");
    }

    joypad_driver_reinit(NULL, "manic");
}

static NSString * _Nullable current_n64_runtime_plugin(NSString * _Nullable corePath, const char *symbolName) {
    typedef const char *(*plugin_getter_t)(void);

    plugin_getter_t getter = (plugin_getter_t)dlsym(RTLD_DEFAULT, symbolName);
    if (getter) {
        const char *value = getter();
        return value ? [NSString stringWithUTF8String:value] : nil;
    }

    if (!corePath || !symbolName) {
        return nil;
    }

    NSString *executablePath = [[NSBundle bundleWithPath:corePath] executablePath] ?: corePath;

    if (!loaded_core_handle) {
        loaded_core_handle = dlopen(executablePath.fileSystemRepresentation, RTLD_NOW | RTLD_NOLOAD);
        if (!loaded_core_handle) {
            loaded_core_handle = dlopen(executablePath.fileSystemRepresentation, RTLD_NOW);
        }
    }

    if (!loaded_core_handle) {
        return nil;
    }

    getter = (plugin_getter_t)dlsym(loaded_core_handle, symbolName);
    if (!getter) {
        return nil;
    }

    const char *value = getter();
    return value ? [NSString stringWithUTF8String:value] : nil;
}

static void post_n64_input_trace(NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ManicN64InputTraceNotification" object:nil userInfo:@{ @"message": message }];
    });
}

- (void)startWithCustomSaveDir:(NSString *_Nullable)customSaveDir {
    if (LibretroInitial) {
        return;
    }
    
    //防止音频驱动加载的时候中断别的应用的音频
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
    
    LibretroInitial = true;
    set_libretro_is_going_to_stop(false);
    char arguments[]   = "retroarch";
    char       *argv[] = {arguments,   NULL};
    int argc           = 1;
    apple_platform     = self;
    
    [CocoaView get].view.frame = [[UIScreen mainScreen] bounds];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        command_event(CMD_EVENT_AUDIO_START, NULL);
    });
    
    extern void manic_input_set_deinit(void);
    manic_input_set_deinit();
    
    if (customSaveDir) {
        set_custom_save_dir(customSaveDir.UTF8String);
    } else {
        set_custom_save_dir(NULL);
    }
    
    rarch_main(argc, argv, NULL);
    ensure_manic_joypad_driver();
    [self updateLibretroConfig:@"input_joypad_driver" value:@"manic"];
    
    rarch_start_draw_observer();
}

- (void)pause {
    if (!LibretroInitial) { return; }
    command_event(CMD_EVENT_PAUSE, NULL);
    rarch_stop_draw_observer();
}

- (void)stop {
    if (!LibretroInitial) { return; }
    LibretroInitial = false;
    set_libretro_is_going_to_stop(true);
    command_event(CMD_EVENT_CLOSE_CONTENT, NULL);
    command_event(CMD_EVENT_UNLOAD_CORE, NULL);
    rarch_stop_draw_observer();
    main_exit(NULL);
    self.gamePath = nil;
    self.corePath = nil;
    loaded_core_handle = NULL;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
}

- (void)resume {
    if (!LibretroInitial) { return; }
    
    // 保存当前的快进状态
    float currentFastforwardRate = g_custom_fastforward_ratio;
    BOOL isFastforwarding = (g_custom_fastforward_ratio > 0.0f);
    
    rarch_start_draw_observer();
    
    command_event(CMD_EVENT_RESUME, NULL);
    if (needToLoadStatePath) {
        [self loadGame:self.gamePath corePath:self.corePath completion:nil];
        
        // 恢复快进状态（如果之前处于快进模式）
        if (isFastforwarding) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self fastForward:currentFastforwardRate];
            });
        }
        
        if (needToLoadStateDelay > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(needToLoadStateDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self loadState:needToLoadStatePath];
                needToLoadStatePath = nil;
            });
        } else {
            [self loadState:needToLoadStatePath];
            needToLoadStatePath = nil;
        }
    } else if (isFastforwarding) {
        // 如果没有需要加载的存档，但是之前处于快进状态，恢复快进
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self fastForward:currentFastforwardRate];
        });
    }
}

- (BOOL)loadGame:(NSString *_Nonnull)gamePath corePath:(NSString *_Nonnull)corePath completion:(void(^ _Nullable)(NSDictionary *_Nullable))completion {
    ensure_manic_joypad_driver();
    settings_t *settings = config_get_ptr();
    settings->bools.video_font_enable = false;//禁用通知
    settings->bools.audio_respect_silent_mode = RespectSilentMode;
    set_custom_save_ext(g_customSaveExtension ? g_customSaveExtension.UTF8String : NULL);
    content_ctx_info_t content_info;
    content_info.argc        = 0;
    content_info.argv        = NULL;
    content_info.args        = NULL;
    content_info.environ_get = NULL;
    
    NSError *error;
    AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionMixWithOthers |
    AVAudioSessionCategoryOptionAllowBluetoothA2DP |
    AVAudioSessionCategoryOptionAllowAirPlay;
    if (RespectSilentMode) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient withOptions:options error:&error];
    } else {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:options error:&error];
    }

    /* N64 JIT core probe removed: the dlopen/dlclose cycle before the real
       load could leave JIT memory or OpenGL state in an inconsistent state,
       causing a black screen.  RetroArch's own core loader will report
       errors if the dylib cannot be loaded. */
    
    task_push_load_content_with_new_core_from_menu(corePath.UTF8String,
                                                   gamePath.UTF8String,
                                                   &content_info,
                                                   CORE_TYPE_PLAIN,
                                                   NULL,
                                                   NULL);
    
    self.gamePath = gamePath;
    self.corePath = corePath;
    
    //核心信息
    core_info_t *core_info      = NULL;
    core_info_get_current_core(&core_info);
    
    if (completion) {
        completion(nil);
    }
    return YES;
}

- (void)loadCoreWithoutContent:(NSString *_Nonnull)corePath {
    ensure_manic_joypad_driver();
    settings_t *settings = config_get_ptr();
    settings->bools.video_font_enable = false;//禁用通知
    settings->bools.audio_respect_silent_mode = RespectSilentMode;
    set_custom_save_ext(g_customSaveExtension ? g_customSaveExtension.UTF8String : NULL);
    // 直接调用RetroArch的无内容核心加载函数
    task_push_load_contentless_core_from_menu(corePath.UTF8String);
}

extern void manic_input_button_event(unsigned port, unsigned button_id, bool pressed);
extern void manic_input_analog_event(unsigned port, unsigned stick_id, float x_value, float y_value);
- (void)pressButton:(unsigned)button playerIndex:(unsigned)playerIndex {
    post_n64_input_trace([NSString stringWithFormat:@"LR press %u p%u", button, playerIndex]);
    manic_input_button_event(playerIndex, button, true);
}

- (void)releaseButton:(unsigned)button playerIndex:(unsigned)playerIndex {
    post_n64_input_trace([NSString stringWithFormat:@"LR release %u p%u", button, playerIndex]);
    manic_input_button_event(playerIndex, button, false);
}

- (void)moveStick:(BOOL)isLeft x:(CGFloat)x y:(CGFloat)y playerIndex:(unsigned)playerIndex {
    post_n64_input_trace([NSString stringWithFormat:@"LR %@ %.2f %.2f p%u", isLeft ? @"left" : @"right", x, y, playerIndex]);
    manic_input_analog_event(playerIndex, isLeft ? RETRO_DEVICE_INDEX_ANALOG_LEFT : RETRO_DEVICE_INDEX_ANALOG_RIGHT, x, y);
}

- (void)sendEvent:(UIEvent * _Nonnull)event {
    if (@available(iOS 13.4, tvOS 13.4, *))
    {
        if (event.type == UIEventTypeHover)
            return;
    }
    if (event.allTouches.count)
        handle_touch_event(event.allTouches.allObjects);
}

- (void)mute:(BOOL)mute {
    audio_driver_state_t *audio = audio_state_get_ptr();
    audio->mute_enable = !mute;
}

- (void)snapshot:(void(^ _Nullable)(UIImage *_Nullable image))completion {
    if (!completion) {
        return;
    }
    
    // 在主线程上执行截图操作，确保在游戏循环中正确执行
    dispatch_async(dispatch_get_main_queue(), ^{
        struct video_viewport vp;
        video_driver_state_t *video_st = video_state_get_ptr();
        runloop_state_t *runloop_st = runloop_state_get_ptr();
        uint8_t *buffer = NULL;
        
        // 检查视频驱动是否可用
        if (!video_st || !video_st->current_video || !video_st->current_video->read_viewport) {
            completion(nil);
            return;
        }
        
        // 初始化视口
        vp.x = 0;
        vp.y = 0;
        vp.width = 0;
        vp.height = 0;
        vp.full_width = 0;
        vp.full_height = 0;
        
        // 获取视口信息
        if (!video_driver_get_viewport_info(&vp) || !vp.width || !vp.height) {
            completion(nil);
            return;
        }
        
        // 分配缓冲区 (RGB24格式，每像素3字节)
        buffer = (uint8_t*)malloc(vp.width * vp.height * 3);
        if (!buffer) {
            completion(nil);
            return;
        }
        
        // 获取当前运行循环标志
        uint32_t runloop_flags = runloop_get_flags();
        bool is_idle = (runloop_flags & RUNLOOP_FLAG_IDLE) ? true : false;
        bool is_fastforward = (runloop_flags & RUNLOOP_FLAG_FASTMOTION) ? true : false;
        bool is_paused = (runloop_flags & RUNLOOP_FLAG_PAUSED) ? true : false;
        
        if (!is_paused) {
            [self pause];
        }
        
        // 为了确保能够读取到帧缓冲，我们需要多次尝试
        bool read_success = false;
        int retry_count = 0;
        const int max_retries = is_fastforward ? 10 : 3;
        
        // 在快进状态下，我们需要先暂停快进，截图后再恢复
        bool need_restore_fastforward = false;
        if (is_fastforward && runloop_st) {
            NSLog(@"[snapshot2] 检测到快进状态，临时暂停快进以确保截图成功");
            // 临时禁用快进
            runloop_st->flags &= ~RUNLOOP_FLAG_FASTMOTION;
            need_restore_fastforward = true;
            
            // 强制渲染一帧以确保有可用的后备缓冲区
            if (runloop_st->flags & RUNLOOP_FLAG_CORE_RUNNING) {
                video_driver_cached_frame();
            }
            
            // 给渲染一些时间完成
            usleep(5000); // 等待5ms
        }
        
        while (!read_success && retry_count < max_retries) {
            // 强制渲染当前帧
            if (runloop_st && (runloop_st->flags & RUNLOOP_FLAG_CORE_RUNNING)) {
                video_driver_cached_frame();
            }
            
            // 给渲染一些时间完成，特别是第一次尝试
            if (retry_count == 0) {
                usleep(2000); // 等待2ms
            } else if (retry_count > 0) {
                usleep(1000); // 等待1ms
            }
            
            // 尝试读取视口数据
            read_success = video_st->current_video->read_viewport(video_st->data, buffer, is_idle);
            retry_count++;
            
            if (!read_success) {
                NSLog(@"[snapshot2] 读取视口失败，重试次数: %d/%d, 快进: %s, 暂停: %s",
                      retry_count, max_retries, is_fastforward ? "是" : "否", is_paused ? "是" : "否");
            }
        }
        
        // 恢复快进状态
        if (need_restore_fastforward && runloop_st) {
            NSLog(@"[snapshot2] 恢复快进状态");
            runloop_st->flags |= RUNLOOP_FLAG_FASTMOTION;
        }
        if (!is_paused) {
            [self resume];
        }
        
        if (read_success) {
            // 成功读取，转换为UIImage
            UIImage *image = [self createUIImageFromBGRBuffer:buffer width:vp.width height:vp.height];
            free(buffer);
            
            if (image) {
                NSLog(@"[snapshot2] 截图成功，尺寸: %.0fx%.0f", image.size.width, image.size.height);
                completion(image);
            } else {
                NSLog(@"[snapshot2] 图像转换失败");
                completion(nil);
            }
        } else {
            // 所有重试都失败了
            NSLog(@"[snapshot2] 读取视口失败，已重试 %d 次", max_retries);
            free(buffer);
            completion(nil);
        }
    });
}

- (UIImage *_Nullable)createUIImageFromBGRBuffer:(uint8_t *_Nullable)buffer width:(NSUInteger)width height:(NSUInteger)height {
    if (!buffer || width == 0 || height == 0) {
        NSLog(@"[createUIImageFromBGRBuffer] 无效参数: buffer=%p, width=%lu, height=%lu", buffer, (unsigned long)width, (unsigned long)height);
        return nil;
    }
    
    NSLog(@"[createUIImageFromBGRBuffer] 开始创建图像，尺寸: %lux%lu", (unsigned long)width, (unsigned long)height);
    
    // 检查前几个字节的数据以确认有效性
    NSLog(@"[createUIImageFromBGRBuffer] 前12字节数据(BGR): %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X",
          buffer[0], buffer[1], buffer[2], buffer[3], buffer[4], buffer[5],
          buffer[6], buffer[7], buffer[8], buffer[9], buffer[10], buffer[11]);
    
    // Metal驱动返回的数据实际上是BGR格式，我们需要转换为RGBA
    size_t totalPixels = width * height;
    uint8_t *rgbaBuffer = malloc(totalPixels * 4); // RGBA需要4字节每像素
    if (!rgbaBuffer) {
        NSLog(@"[createUIImageFromBGRBuffer] 分配RGBA缓冲区失败");
        return nil;
    }
    
    // 将BGR转换为RGBA（添加Alpha通道），同时翻转图像使其正向显示
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            // 源数据是bottom-up，所以从底部开始读取
            size_t srcRow = (height - 1 - y);
            size_t srcIndex = (srcRow * width + x) * 3;
            
            // 目标数据是top-down，正常顺序写入
            size_t dstIndex = (y * width + x) * 4;
            
            // Metal驱动输出的是BGR格式，我们需要交换R和B通道，并添加Alpha
            rgbaBuffer[dstIndex + 0] = buffer[srcIndex + 2]; // R = 原来的B
            rgbaBuffer[dstIndex + 1] = buffer[srcIndex + 1]; // G = 原来的G
            rgbaBuffer[dstIndex + 2] = buffer[srcIndex + 0]; // B = 原来的R
            rgbaBuffer[dstIndex + 3] = 255;                  // A = 完全不透明
        }
    }
    
    NSLog(@"[createUIImageFromBGRBuffer] 转换后前16字节数据(RGBA): %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X",
          rgbaBuffer[0], rgbaBuffer[1], rgbaBuffer[2], rgbaBuffer[3],
          rgbaBuffer[4], rgbaBuffer[5], rgbaBuffer[6], rgbaBuffer[7],
          rgbaBuffer[8], rgbaBuffer[9], rgbaBuffer[10], rgbaBuffer[11],
          rgbaBuffer[12], rgbaBuffer[13], rgbaBuffer[14], rgbaBuffer[15]);
    
    // 创建CGColorSpace
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) {
        NSLog(@"[createUIImageFromBGRBuffer] 创建颜色空间失败");
        free(rgbaBuffer);
        return nil;
    }
    
    size_t bytesPerRow = width * 4; // RGBA每行4字节每像素
    
    // 使用CGBitmapContext创建图像，使用RGBA格式
    CGContextRef context = CGBitmapContextCreate(
                                                 rgbaBuffer,                    // 数据指针
                                                 width,                         // 宽度
                                                 height,                        // 高度
                                                 8,                            // 每个组件的位数
                                                 bytesPerRow,                  // 每行字节数
                                                 colorSpace,                   // 色彩空间
                                                 kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault  // RGBA格式
                                                 );
    
    CGColorSpaceRelease(colorSpace);
    
    if (!context) {
        NSLog(@"[createUIImageFromBGRBuffer] 创建CGContext失败");
        free(rgbaBuffer);
        return nil;
    }
    
    // 从context创建CGImage
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    // 现在可以安全地释放RGBA缓冲区
    free(rgbaBuffer);
    
    if (!cgImage) {
        NSLog(@"[createUIImageFromBGRBuffer] 创建CGImage失败");
        return nil;
    }
    
    // 由于我们在转换时已经处理了bottom-up到top-down的翻转，现在可以使用正常方向
    UIImage *image = [UIImage imageWithCGImage:cgImage scale:1.0 orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    
    if (!image) {
        NSLog(@"[createUIImageFromBGRBuffer] 创建UIImage失败");
        return nil;
    }
    
    NSLog(@"[createUIImageFromBGRBuffer] 成功创建图像，最终尺寸: %.0fx%.0f", image.size.width, image.size.height);
    return image;
}

- (BOOL)saveState:(void(^ _Nullable)(NSString *_Nullable path))completion {
    if (!completion) {
        return NO;
    }
    NSLog(@"开始存档");
    NSString *statePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%f.state", [[NSDate now] timeIntervalSince1970] * 1000]];
    if (content_save_state(statePath.UTF8String, true)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            content_wait_for_save_state_task();
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"开始结束");
                completion(statePath);
            });
        });
        return YES;
    }
    return NO;
}

- (BOOL)loadState:(NSString *_Nonnull)path {
    return content_load_state(path.UTF8String, false, false);
}

// 存储自定义的快进速率，避免被配置重载覆盖
static float g_custom_fastforward_ratio = 0.0f;

- (void)fastForward:(float)rate {
    settings_t *settings = config_get_ptr();
    if (!settings) {
        return;
    }
    
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    input_driver_state_t *input_st = input_state_get_ptr();
    audio_driver_state_t *audio_st = audio_state_get_ptr();
    video_driver_state_t *video_st = video_state_get_ptr();
    
    if (!runloop_st || !input_st || !audio_st || !video_st) {
        return;
    }
    
    bool audio_fastforward_mute = settings->bools.audio_fastforward_mute;
    bool frame_time_counter_reset_after_ffwd = settings->bools.frame_time_counter_reset_after_fastforwarding;
    
    if (rate <= 1.0f) {
        // ===== 恢复正常速度 =====
        
        // 1. 恢复 fastforward ratio 到用户配置或 1.0
        g_custom_fastforward_ratio = 0.0f;
        
        // 2. 清除快进标志
        runloop_st->flags &= ~RUNLOOP_FLAG_FASTMOTION;
        
        // 3. 清除非阻塞输入标志
        input_st->flags &= ~INP_FLAG_NONBLOCKING;
        
        // 4. 设置 fastforward_after_frames，用于平滑过渡
        runloop_st->fastforward_after_frames = 1;
        
        // 5. 恢复音频状态（取消静音）
        if (audio_fastforward_mute) {
            audio_st->flags &= ~AUDIO_FLAG_MUTED;
        }
        
        // 6. 使用 driver_set_nonblock_state() 统一设置驱动非阻塞状态
        // 这个函数会自动处理音频和视频驱动的非阻塞状态，以及 chunk_size
        driver_set_nonblock_state();
        
        // 7. 重置视频帧时间计数器（如果需要）
        if (frame_time_counter_reset_after_ffwd && video_st) {
            video_st->frame_time_count = 0;
        }
        
        // 8. 更新帧率限制为正常速度
        command_event(CMD_EVENT_SET_FRAME_LIMIT, NULL);
        
    } else {
        // ===== 启用快进 =====
        
        // 1. 保存自定义快进速率
        g_custom_fastforward_ratio = rate;
        
        // 2. 设置快进标志
        runloop_st->flags |= RUNLOOP_FLAG_FASTMOTION;
        
        // 3. 设置非阻塞输入标志
        input_st->flags |= INP_FLAG_NONBLOCKING;
        
        // 4. 根据设置决定是否静音音频
        if (audio_fastforward_mute) {
            audio_st->flags |= AUDIO_FLAG_MUTED;
        } else {
            audio_st->flags &= ~AUDIO_FLAG_MUTED;
        }
        
        // 5. 使用 driver_set_nonblock_state() 统一设置驱动非阻塞状态
        driver_set_nonblock_state();
        
        // 6. 更新帧率限制为快进速率
        command_event(CMD_EVENT_SET_FRAME_LIMIT, NULL);
    }
}

// 获取当前应该使用的快进速率
// 这个函数会在 runloop 中被调用，用于获取实际的快进倍率
float get_custom_fastforward_ratio(void) {
    return g_custom_fastforward_ratio;
}

- (void)reload {
    [self reloadByKeepState: NO];
}

static NSString *_Nullable needToLoadStatePath = nil;
- (void)reloadByKeepState:(BOOL)keepState {
    // 保存当前的快进状态
    float currentFastforwardRate = g_custom_fastforward_ratio;
    BOOL isFastforwarding = (g_custom_fastforward_ratio > 0.0f);
    
    if (keepState) {
        [self saveState:^(NSString * _Nullable path) {
            if (iterate_observer) {
                //游戏运行状态 直接加载存档
                [self loadGame:self.gamePath corePath:self.corePath completion:nil];
                
                // 恢复快进状态（如果之前处于快进模式）
                if (isFastforwarding) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [self fastForward:currentFastforwardRate];
                    });
                }
                
                if (needToLoadStateDelay > 0) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(needToLoadStateDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self loadState:path];
                    });
                } else {
                    [self loadState:path];
                }
            } else {
                //暂停中 标记在恢复的时候需要加载游戏和存档
                needToLoadStatePath = path;
            }
        }];
    } else {
        [self loadGame:self.gamePath corePath:self.corePath completion:nil];
        
        // 恢复快进状态（如果之前处于快进模式）
        if (isFastforwarding) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self fastForward:currentFastforwardRate];
            });
        }
    }
}


- (void)updatePSPCheat:(NSString *_Nonnull)cheatCode cheatFilePath:(NSString *_Nonnull)cheatFilePath reloadGame:(BOOL)reloadGame {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:cheatFilePath]) {
        [fileManager removeItemAtPath:cheatFilePath error:nil];
    }
    if (cheatCode && ![cheatCode isEqualToString:@""]) {
        [fileManager createDirectoryAtPath:[cheatFilePath stringByDeletingLastPathComponent] withIntermediateDirectories:true attributes:nil error:nil];
        [cheatCode writeToFile:cheatFilePath atomically:true encoding:NSUTF8StringEncoding error:nil];
    }
    if (reloadGame) {
        [self reloadByKeepState:YES];
    }
}

- (void)setPSPResolution:(unsigned)resolution reload:(BOOL)reload {
    NSString *configFilePath = [self.workspace stringByAppendingPathComponent:@"config/PPSSPP/PPSSPP.opt"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:configFilePath]) {
        core_options_flush();//生成配置
    }
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"读取文件失败: %@", error.localizedDescription);
        return;
    }
    
    // 正则匹配并替换
    NSString *pattern = @"ppsspp_internal_resolution\\s*=\\s*\"[^\"]*\"";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (error) {
        NSLog(@"正则表达式错误: %@", error.localizedDescription);
        return;
    }
    
    NSString *newValue = [NSString stringWithFormat:@"%dx%d", 480*resolution, 272*resolution];
    NSString *replacement = [NSString stringWithFormat:@"ppsspp_internal_resolution = \"%@\"", newValue];
    NSString *updatedContents = nil;
    if ([regex numberOfMatchesInString:fileContents options:0 range:NSMakeRange(0, fileContents.length)] > 0) {
        updatedContents = [regex stringByReplacingMatchesInString:fileContents
                                                          options:0
                                                            range:NSMakeRange(0, fileContents.length)
                                                     withTemplate:replacement];
    } else if (fileContents.length > 0) {
        updatedContents = [fileContents stringByAppendingFormat:@"\n%@", replacement];
    } else {
        updatedContents = replacement;
    }
    
    
    
    // 写回文件
    [updatedContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (reload) {
        [self reloadByKeepState:YES];
    }
}

- (void)updateCoreConfig:(NSString *_Nonnull)coreName key:(NSString *_Nonnull)key value:(NSString *_Nonnull)value reload:(BOOL)reload {
    NSString *configPath = [NSString stringWithFormat:@"config/%@/%@.opt", coreName, coreName];
    NSString *configFilePath = [self.workspace stringByAppendingPathComponent:configPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:configFilePath]) {
        core_options_flush();//生成配置
    }
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"读取文件失败: %@", error.localizedDescription);
        [NSFileManager.defaultManager createDirectoryAtPath:[configFilePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        fileContents = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
        // 写回文件
        [fileContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (reload) {
            [self reloadByKeepState:YES];
        }
        return;
    }
    
    NSString *oldValue = [self configValueForKey:key inFileContents:fileContents];
    if ([oldValue isEqualToString:value]) {
        return;
    }
    
    // 正则匹配并替换
    NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*\"[^\"]*\"", key] ;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (error) {
        NSLog(@"正则表达式错误: %@", error.localizedDescription);
        return;
    }
    NSString *replacement = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
    NSString *updatedContents = nil;
    if ([regex numberOfMatchesInString:fileContents options:0 range:NSMakeRange(0, fileContents.length)] > 0) {
        updatedContents = [regex stringByReplacingMatchesInString:fileContents
                                                          options:0
                                                            range:NSMakeRange(0, fileContents.length)
                                                     withTemplate:replacement];
    } else if (fileContents.length > 0) {
        updatedContents = [fileContents stringByAppendingFormat:@"\n%@", replacement];
    } else {
        updatedContents = replacement;
    }
    // 写回文件
    [updatedContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (reload) {
        [self reloadByKeepState:YES];
    }
}

- (void)updateCoreConfig:(NSString *_Nonnull)coreName configs:(NSDictionary<NSString*, NSString*> *_Nullable)configs reload:(BOOL)reload {
    if (configs.count == 0) return;
    
    NSString *configPath = [NSString stringWithFormat:@"config/%@/%@.opt", coreName, coreName];
    NSString *configFilePath = [self.workspace stringByAppendingPathComponent:configPath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:configFilePath]) {
        core_options_flush();
    }
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error || !fileContents) {
        NSLog(@"读取文件失败: %@", error.localizedDescription);
        [NSFileManager.defaultManager createDirectoryAtPath:[configFilePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSMutableArray *newLines = [NSMutableArray array];
        [configs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            [newLines addObject:[NSString stringWithFormat:@"%@ = \"%@\"", key, value]];
        }];
        NSString *newFileContent = [newLines componentsJoinedByString:@"\n"];
        [newFileContent writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        if (reload) {
            [self reloadByKeepState:YES];
        }
        return;
    }
    
    NSMutableString *updatedContents = [fileContents mutableCopy];
    __block BOOL changed = NO;
    
    [configs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        NSString *oldValue = [self configValueForKey:key inFileContents:fileContents];
        if ([oldValue isEqualToString:value]) return;
        
        NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*\"[^\"]*\"", key];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSString *replacement = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
        
        if ([regex numberOfMatchesInString:updatedContents options:0 range:NSMakeRange(0, updatedContents.length)] > 0) {
            [regex replaceMatchesInString:updatedContents options:0 range:NSMakeRange(0, updatedContents.length) withTemplate:replacement];
        } else {
            [updatedContents appendFormat:@"\n%@", replacement];
        }
        
        changed = YES;
    }];
    
    if (changed) {
        [updatedContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        if (reload) {
            [self reloadByKeepState:YES];
        }
    }
}

- (void)updateRunningCoreConfigs:(NSDictionary<NSString*, NSString*> *_Nullable)configs flush:(BOOL)flush {
    // 获取 runloop 状态
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    
    // 确保核心选项管理器存在
    if (!runloop_st->core_options) {
        return;
    }
    
    [configs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        // 方法1：通过键名设置配置
        const char *option_key = [key cStringUsingEncoding:NSUTF8StringEncoding];
        const char *option_value = [value cStringUsingEncoding:NSUTF8StringEncoding];
        size_t option_idx, value_idx;
        
        // 1. 根据键名获取选项索引
        if (core_option_manager_get_idx(runloop_st->core_options, option_key, &option_idx)) {
            // 2. 根据值字符串获取值索引
            if (core_option_manager_get_val_idx(runloop_st->core_options, option_idx, option_value, &value_idx)) {
                // 3. 设置配置值
                core_option_manager_set_val(runloop_st->core_options, option_idx, value_idx, false);
            }
        }
        if (flush) {
            core_options_flush();
        }
    }];
}

- (void)updateLibretroConfigs:(NSDictionary<NSString*, NSString*> *_Nullable)configs {
    if (configs.count == 0) return;
    
    NSString *configFilePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject stringByAppendingString:@"/Libretro/config/retroarch.cfg"];
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error || !fileContents) {
        NSLog(@"读取文件失败: %@", error.localizedDescription);
        [NSFileManager.defaultManager createDirectoryAtPath:[configFilePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSMutableArray *newLines = [NSMutableArray array];
        [configs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            [newLines addObject:[NSString stringWithFormat:@"%@ = \"%@\"", key, value]];
        }];
        NSString *newFileContent = [newLines componentsJoinedByString:@"\n"];
        [newFileContent writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    
    NSMutableString *updatedContents = [fileContents mutableCopy];
    __block BOOL changed = NO;
    
    [configs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        NSString *oldValue = [self configValueForKey:key inFileContents:fileContents];
        if ([oldValue isEqualToString:value]) return;
        
        NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*\"[^\"]*\"", key];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSString *replacement = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
        
        if ([regex numberOfMatchesInString:updatedContents options:0 range:NSMakeRange(0, updatedContents.length)] > 0) {
            [regex replaceMatchesInString:updatedContents options:0 range:NSMakeRange(0, updatedContents.length) withTemplate:replacement];
        } else {
            [updatedContents appendFormat:@"\n%@", replacement];
        }
        
        changed = YES;
    }];
    
    if (changed) {
        [updatedContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (void)updateLibretroConfig:(NSString *_Nonnull)key value:(NSString *_Nonnull)value {
    NSString *configFilePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject stringByAppendingString:@"/Libretro/config/retroarch.cfg"];
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"读取文件失败: %@", error.localizedDescription);
        [NSFileManager.defaultManager createDirectoryAtPath:[configFilePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        fileContents = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
        // 写回文件
        [fileContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        return;
    }
    
    NSString *oldValue = [self configValueForKey:key inFileContents:fileContents];
    if ([oldValue isEqualToString:value]) {
        return;
    }
    
    if (!oldValue) {
        //当前key不存在 直接添加到末尾
        fileContents = [fileContents stringByAppendingString:[NSString stringWithFormat:@"\n%@ = \"%@\"", key, value]];
        [fileContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        return;
    }
    
    // 正则匹配并替换
    NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*\"[^\"]*\"", key] ;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (error) {
        NSLog(@"正则表达式错误: %@", error.localizedDescription);
        return;
    }
    NSString *replacement = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
    NSString *updatedContents = [regex stringByReplacingMatchesInString:fileContents
                                                                options:0
                                                                  range:NSMakeRange(0, fileContents.length)
                                                           withTemplate:replacement];
    // 写回文件
    [updatedContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

- (NSString * _Nullable)coreConfigValue:(NSString * _Nonnull)coreName key:(NSString * _Nonnull)key {
    NSString *configPath = [NSString stringWithFormat:@"config/%@/%@.opt", coreName, coreName];
    NSString *configFilePath = [self.workspace stringByAppendingPathComponent:configPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:configFilePath]) {
        core_options_flush();//生成配置
    }
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error || !fileContents) {
        return nil;
    }
    
    return [self configValueForKey:key inFileContents:fileContents];
}

- (NSString * _Nullable)libretroConfigValue:(NSString * _Nonnull)key {
    NSString *configFilePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject stringByAppendingString:@"/Libretro/config/retroarch.cfg"];
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        return nil;
    }
    return [self configValueForKey:key inFileContents:fileContents];
}

- (NSString * _Nullable)libretroRuntimeVideoDriver {
    const char *ident = video_driver_get_ident();
    return ident ? [NSString stringWithUTF8String:ident] : nil;
}

- (NSString * _Nullable)n64RuntimeRDPPlugin {
    return current_n64_runtime_plugin(self.corePath, "mupen64plus_current_rdp_plugin");
}

- (NSString * _Nullable)n64RuntimeRSPPlugin {
    return current_n64_runtime_plugin(self.corePath, "mupen64plus_current_rsp_plugin");
}

- (NSString * _Nullable)n64ParallelStatus {
    return current_n64_runtime_plugin(self.corePath, "mupen64plus_parallel_status");
}

- (NSString * _Nullable)configValueForKey:(NSString * _Nonnull)key inFileContents:(NSString * _Nonnull)fileContents {
    NSError *error = nil;
    // 构建正则表达式
    NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*\"([^\"]*)\"", key];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (error) {
        NSLog(@"正则表达式错误: %@", error.localizedDescription);
        return nil;
    }
    
    NSTextCheckingResult *match = [regex firstMatchInString:fileContents options:0 range:NSMakeRange(0, fileContents.length)];
    
    if (match && match.numberOfRanges > 1) {
        NSRange valueRange = [match rangeAtIndex:1];
        return [fileContents substringWithRange:valueRange];
    }
    
    return nil;
}

- (BOOL)setShaderWith:(NSString *_Nullable)path {
    settings_t *settings = config_get_ptr();
    if (!settings) {
        return NO;
    }
    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        settings->bools.video_shader_enable = true;
        video_shader_toggle(settings, true);
        return set_shader_preset(path.UTF8String);
    } else {
        settings->bools.video_shader_enable = false;
        video_shader_toggle(settings, true);
        return NO;
    }
}

bool set_shader_preset(const char * _Nullable preset_path)
{
    settings_t *settings = config_get_ptr();
    video_driver_state_t *video_st = video_state_get_ptr();
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    
    if (!video_st || !video_st->current_video || !video_st->current_video->set_shader)
        return false;
    
    // 获取 shader 类型
    enum rarch_shader_type type = video_shader_parse_type(preset_path);
    if (type == RARCH_SHADER_NONE)
        return false;
    
    // 设置 shader
    if (video_st->current_video->set_shader(video_st->data, type, preset_path))
    {
        // 启用 shader
        configuration_set_bool(settings, settings->bools.video_shader_enable, true);
        
        // 更新运行时 shader preset 路径
        if (!string_is_empty(preset_path))
        {
            if (runloop_st->runtime_shader_preset_path != preset_path)
                strlcpy(runloop_st->runtime_shader_preset_path,
                        preset_path,
                        sizeof(runloop_st->runtime_shader_preset_path));
            
            // 更新 shader manager
            struct video_shader *shader = menu_shader_get();
            if (shader)
            {
                if (menu_shader_manager_set_preset(shader, type, preset_path, false))
                    shader->flags &= ~SHDR_FLAG_MODIFIED;
            }
        }
        else
        {
            runloop_st->runtime_shader_preset_path[0] = '\0';
        }
        return true;
    } else {
        return false;
    }
}

- (void)appendShader:(NSString *_Nonnull)path prepend:(BOOL)prepend {
    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        RARCH_ERR("[Shader] Append shader failed: file does not exist");
        return;
    }

    settings_t *settings = config_get_ptr();
    if (!settings) return;

    // 获取当前shader
    struct video_shader *current_shader = menu_shader_get();
    if (!current_shader) {
        RARCH_ERR("[Shader] No current shader to append to");
        return;
    }

    menu_shader_manager_append_preset(current_shader, path.UTF8String, prepend);
}

- (NSArray<ShaderParameter *> *_Nullable)loadParameters {
    // 获取当前shader
    struct video_shader *shader = menu_shader_get();
    if (!shader || shader->num_parameters == 0) {
        RARCH_LOG("[Shader] No shader parameters found");
        return @[];
    }

    NSMutableArray<ShaderParameter *> *parameters = [NSMutableArray arrayWithCapacity:shader->num_parameters];

    // 遍历所有参数
    for (unsigned i = 0; i < shader->num_parameters; i++) {
        struct video_shader_parameter *param = &shader->parameters[i];

        ShaderParameter *shaderParam = [[ShaderParameter alloc] init];
        shaderParam.identifier = [NSString stringWithUTF8String:param->id];
        shaderParam.desc = [NSString stringWithUTF8String:param->desc];
        shaderParam.current = param->current;
        shaderParam.minimum = param->minimum;
        shaderParam.maximum = param->maximum;
        shaderParam.step = param->step;
        shaderParam.pass = param->pass;

        [parameters addObject:shaderParam];

        RARCH_LOG("[Shader] Loaded parameter: %s (%.3f) - %s",
                  param->id, param->current, param->desc);
    }

    RARCH_LOG("[Shader] Loaded %lu shader parameters", (unsigned long)parameters.count);
    return parameters;
}

- (void)updateParameterWith:(NSString *_Nonnull)identifier
                      value:(float)value
               changingPath:(NSString *_Nonnull)changingPath {
    if (!identifier || identifier.length == 0) {
        RARCH_ERR("[Shader] Update parameter failed: invalid identifier");
        return;
    }

    // 获取当前shader
    struct video_shader *shader = menu_shader_get();
    if (!shader || shader->num_parameters == 0) {
        RARCH_ERR("[Shader] No shader parameters found to update");
        return;
    }

    // 查找匹配的参数
    struct video_shader_parameter *target_param = NULL;
    for (unsigned i = 0; i < shader->num_parameters; i++) {
        if (strcmp(shader->parameters[i].id, identifier.UTF8String) == 0) {
            target_param = &shader->parameters[i];
            break;
        }
    }

    if (!target_param) {
        RARCH_ERR("[Shader] Parameter not found: %s", identifier.UTF8String);
        return;
    }

    // 验证并修正值范围
    float clamped_value = value;
    if (clamped_value < target_param->minimum) {
        clamped_value = target_param->minimum;
        RARCH_LOG("[Shader] Parameter value clamped to minimum: %.3f", clamped_value);
    } else if (clamped_value > target_param->maximum) {
        clamped_value = target_param->maximum;
        RARCH_LOG("[Shader] Parameter value clamped to maximum: %.3f", clamped_value);
    }

    // 更新参数值
    target_param->current = clamped_value;

    // 标记shader为已修改
    shader->flags |= SHDR_FLAG_MODIFIED;
    
    video_shader_write_preset(changingPath.UTF8String, shader, true);
}


- (void)addCheatCode:(NSString *_Nonnull)code index:(unsigned)index enable:(BOOL)enable {
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (runloop_st && runloop_st->current_core.retro_cheat_set) {
        runloop_st->current_core.retro_cheat_set(index, enable, code.UTF8String);
    }
}

- (void)resetCheatCode {
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (runloop_st && runloop_st->current_core.retro_cheat_reset) {
        runloop_st->current_core.retro_cheat_reset();
    }
}

- (void)setRespectSilentMode:(BOOL)respect {
    RespectSilentMode = respect;
}

- (void)setDiskIndex:(unsigned)index delay:(BOOL)delay {
    command_event(CMD_EVENT_DISK_EJECT_TOGGLE, NULL);
    if (delay) {
        BOOL isPause = NO;
        uint32_t runloop_flags = runloop_get_flags();
        if (runloop_flags & RUNLOOP_FLAG_PAUSED) {
            isPause = YES;
        }
        
        [self resume];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            unsigned mutableIndex = index;
            command_event(CMD_EVENT_DISK_INDEX, &mutableIndex);
            command_event(CMD_EVENT_DISK_EJECT_TOGGLE, NULL);
            if (isPause) {
                [self pause];
            }
        });
    } else {
        command_event(CMD_EVENT_DISK_INDEX, &index);
        command_event(CMD_EVENT_DISK_EJECT_TOGGLE, NULL);
    }
}

- (NSUInteger)getCurrentDiskIndex {
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (!runloop_st) {
        return 0;
    }
    rarch_system_info_t *sys_info = &runloop_st->system;
    if (!sys_info) {
        return 0;
    }
    disk_control_interface_t *disk_control = &sys_info->disk_control;
    if (!disk_control) {
        return 0;
    }
    unsigned image_index = disk_control->cb.get_image_index();
    return image_index;
}

- (NSUInteger)getDiskCount {
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (!runloop_st) {
        return 0;
    }
    rarch_system_info_t *sys_info = &runloop_st->system;
    if (!sys_info) {
        return 0;
    }
    disk_control_interface_t *disk_control = &sys_info->disk_control;
    if (!disk_control) {
        return 0;
    }
    unsigned num_images  = disk_control->cb.get_num_images();
    return num_images;
}

- (void)setPSXAnalog:(BOOL)isAnalog {
    if (isAnalog) {
        for (unsigned i = 0; i < 8; i++) {
            retro_ctx_controller_info_t pad;
            pad.port   = i;
            pad.device = 517;
            core_set_controller_port_device(&pad);
            input_config_set_device(i, 517);
        }
    } else {
        for (unsigned i = 0; i < 8; i++) {
            retro_ctx_controller_info_t pad;
            pad.port   = i;
            pad.device = 1;
            core_set_controller_port_device(&pad);
            input_config_set_device(i, 1);
        }
    }
}

- (void)setN64ControllerDevice {
    for (unsigned i = 0; i < 8; i++) {
        retro_ctx_controller_info_t pad;
        pad.port   = i;
        pad.device = RETRO_DEVICE_ANALOG;
        core_set_controller_port_device(&pad);
        input_config_set_device(i, RETRO_DEVICE_ANALOG);
    }
}

static double needToLoadStateDelay = 0;
- (void)setReloadDelay:(double)delay {
    needToLoadStateDelay = delay;
}

- (void)turnOffHardcode {
    settings_t *settings = config_get_ptr();
    configuration_set_bool(settings, settings->bools.cheevos_hardcore_mode_enable, false);
    rcheevos_hardcore_enabled_changed();
}

- (void)resetRetroAchievements {
    rcheevos_reset_game(false);
}

static NSString * _Nullable g_customSaveExtension = nil;
- (void)setCustomSaveExtension:(NSString *_Nullable)customSaveExtension {
    g_customSaveExtension = customSaveExtension;
}

- (void)setEnableRumble:(BOOL)enable {
    set_enable_rumble(enable);
}

- (BOOL)getSensorEnable:(int)playerIndex {
    return input_get_sensor_enable(playerIndex);
}

- (void)sendTouchEventX:(CGFloat)x y:(CGFloat)y {
#if !TARGET_OS_TV
    cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
    float scale = cocoa_screen_get_native_scale();
    
    if (!apple) {
        return;
    }
    
    // 模拟触摸开始
    apple->touch_count = 1;
    apple->touches[0].screen_x = x * scale;
    apple->touches[0].screen_y = y * scale;
#endif
}

- (void)releaseTouchEvent {
#if !TARGET_OS_TV
    cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
    
    if (!apple) {
        return;
    }
    
    apple->touch_count = 0;
#endif
}

- (NSString *_Nullable)getCoreConfigs:(NSString *_Nonnull)coreName {
    NSString *configPath = [NSString stringWithFormat:@"config/%@/%@.opt", coreName, coreName];
    NSString *configFilePath = [self.workspace stringByAppendingPathComponent:configPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:configFilePath]) {
        core_options_flush();//生成配置
    }
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    if (error || !fileContents) {
        return nil;
    }
    
    return fileContents;
}

- (void)updateFBNeoCheatCode:(NSArray<NSString *> *_Nonnull)keys enable:(BOOL)enable {
    // 获取 runloop 状态
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    
    // 确保核心选项管理器存在
    if (!runloop_st->core_options) {
        return;
    }
    
    [keys enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        const char *option_key = [key cStringUsingEncoding:NSUTF8StringEncoding];
        size_t option_idx, value_idx = enable ? 1 : 0;
        
        if (core_option_manager_get_idx(runloop_st->core_options, option_key, &option_idx)) {
            core_option_manager_set_val(runloop_st->core_options, option_idx, value_idx, false);
        }
    }];
    
    core_options_flush();
}

- (void)setFastforwardFrameSkip:(BOOL)frameSkip {
    settings_t *settings = config_get_ptr();
    if (!settings) {
        return;
    }
    settings->bools.fastforward_frameskip = frameSkip;
}

- (void)loadAmiibo:(NSString *_Nonnull)path {
#ifdef HAVE_DYNAMIC
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (!runloop_st || !runloop_st->lib_handle) {
        return;
    }
    
    typedef bool (*retro_load_amiibo_t)(const char*);
    retro_load_amiibo_t load_amiibo = (retro_load_amiibo_t)dylib_proc(runloop_st->lib_handle, "retro_load_amiibo");
    if (load_amiibo) {
        load_amiibo([path UTF8String]);
    }
#endif
}

- (BOOL)isSearchingAmiibo {
#ifdef HAVE_DYNAMIC
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (!runloop_st || !runloop_st->lib_handle) {
        return NO;
    }
    
    typedef bool (*retro_is_searching_amiibo_t)(void);
    retro_is_searching_amiibo_t is_searching = (retro_is_searching_amiibo_t)dylib_proc(runloop_st->lib_handle, "retro_is_searching_amiibo");
    if (is_searching) {
        return is_searching() ? YES : NO;
    }
#endif
    return NO;
}

@end

ui_companion_driver_t ui_companion_cocoatouch = {
   NULL, /* init */
   NULL, /* deinit */
   NULL, /* toggle */
   ui_companion_cocoatouch_event_command,
   NULL, /* notify_refresh */
   NULL, /* msg_queue_push */
   NULL, /* render_messagebox */
   NULL, /* get_main_window */
   NULL, /* log_msg */
   NULL, /* is_active */
   ui_companion_cocoatouch_get_app_icons,
   ui_companion_cocoatouch_set_app_icon,
   ui_companion_cocoatouch_get_app_icon_texture,
   NULL, /* browser_window */
   NULL, /* msg_window */
   NULL, /* window */
   NULL, /* application */
   "cocoatouch",
};

#ifndef NO_ROOT_VIEW
int main(int argc, char *argv[])
{
#if TARGET_OS_IOS
    if (jb_enable_ptrace_hack())
        RARCH_LOG("Ptrace hack complete, JIT support is enabled.\n");
    else
        RARCH_WARN("Ptrace hack NOT available; Please use an app like Jitterbug.\n");
#endif
#ifdef HAVE_SDL2
    SDL_SetMainReady();
#endif
   @autoreleasepool {
      return UIApplicationMain(argc, argv, NSStringFromClass([RApplication class]), NSStringFromClass([RetroArch_iOS class]));
   }
}
#endif
