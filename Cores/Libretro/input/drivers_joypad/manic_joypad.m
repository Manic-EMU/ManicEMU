/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2010-2014 - Hans-Kristian Arntzen
 *  Copyright (C) 2011-2017 - Daniel De Matteis
 *
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>

#include <boolean.h>

#include <AvailabilityMacros.h>

#include "../input_driver.h"
#include "../../tasks/tasks_internal.h"

#import <GameController/GameController.h>
#import <CoreHaptics/CoreHaptics.h>

#ifndef MAX_MANIC_CONTROLLERS
#define MAX_MANIC_CONTROLLERS 4
#endif
#ifndef MAX_MANIC_AXES
#define MAX_MANIC_AXES 6
#endif

#if TARGET_OS_IOS
#include "../../configuration.h"

#ifdef HAVE_COREMOTION
#import <CoreHaptics/CoreHaptics.h>
// 触觉引擎状态管理
typedef struct {
    CHHapticEngine *hapticEngine;
    id strongRumblePlayer;
    id weakRumblePlayer;
    bool hapticsSupported;
    bool isEngineRunning;
    bool isShuttingDown;
    uint64_t lastRumbleTime[2]; // 记录每种震动类型的最后执行时间
    uint16_t lastRumbleStrength[2]; // 记录每种震动类型的最后强度
} manic_haptic_state_t;

static manic_haptic_state_t hapticState = {0};
#endif

/* TODO/FIXME - static globals */
static uint32_t manic_buttons[MAX_USERS];
static int16_t  manic_axes[MAX_USERS][MAX_MANIC_AXES];
static uint32_t manic_last_reported_state[MAX_USERS];

static bool manic_inited;
#ifdef HAVE_COREMOTION
// 清理触觉引擎资源
void manic_cleanup_haptic_engine(void) {
    if (@available(iOS 13.0, *)) {
        hapticState.isShuttingDown = true;
        
        // 停止所有正在运行的震动
        if (hapticState.strongRumblePlayer) {
            if ([hapticState.strongRumblePlayer respondsToSelector:@selector(stopAtTime:error:)]) {
                [hapticState.strongRumblePlayer performSelector:@selector(stopAtTime:error:)
                                                     withObject:@0
                                                     withObject:nil];
            }
            hapticState.strongRumblePlayer = nil;
        }
        
        if (hapticState.weakRumblePlayer) {
            if ([hapticState.weakRumblePlayer respondsToSelector:@selector(stopAtTime:error:)]) {
                [hapticState.weakRumblePlayer performSelector:@selector(stopAtTime:error:)
                                                     withObject:@0
                                                     withObject:nil];
            }
            hapticState.weakRumblePlayer = nil;
        }
        
        // 停止并清理引擎
        if (hapticState.hapticEngine) {
            [hapticState.hapticEngine stopWithCompletionHandler:^(NSError * _Nullable error) {
                hapticState.hapticEngine = nil;
            }];
        }
        
        // 重置状态
        // 手动重置结构体字段，而不是使用 memset
        hapticState.hapticEngine = nil;
        hapticState.strongRumblePlayer = nil;
        hapticState.weakRumblePlayer = nil;
        hapticState.hapticsSupported = false;
        hapticState.isEngineRunning = false;
        hapticState.isShuttingDown = false;
        hapticState.lastRumbleTime[0] = 0;
        hapticState.lastRumbleTime[1] = 0;
        hapticState.lastRumbleStrength[0] = 0;
        hapticState.lastRumbleStrength[1] = 0;
    }
}
#endif

void manic_input_set_deinit(void) {
    if (manic_inited) {
#ifdef HAVE_COREMOTION
    // 清理触觉引擎资源
    manic_cleanup_haptic_engine();
#endif
    }
    manic_inited = false;
}

static void manic_post_trace(NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ManicN64InputTraceNotification" object:nil userInfo:@{ @"message": message }];
    });
}

void manic_input_button_event(unsigned port, unsigned button_id, bool pressed) {
    uint32_t *buttons        = &manic_buttons[port];
    if (pressed) {
        switch (button_id) {
            case RETRO_DEVICE_ID_JOYPAD_UP:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_UP);
                break;
            case RETRO_DEVICE_ID_JOYPAD_DOWN:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_DOWN);
                break;
            case RETRO_DEVICE_ID_JOYPAD_LEFT:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_LEFT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_RIGHT:
                *buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_B:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_B);
                break;
            case RETRO_DEVICE_ID_JOYPAD_A:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_A);
                break;
            case RETRO_DEVICE_ID_JOYPAD_Y:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_Y);
                break;
            case RETRO_DEVICE_ID_JOYPAD_X:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_X);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_L);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_R);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L2:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_L2);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R2:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_R2);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L3:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_L3);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R3:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_R3);
                break;
            case RETRO_DEVICE_ID_JOYPAD_SELECT:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_START:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_START);
                break;
            case RARCH_FIRST_CUSTOM_BIND:
                *buttons |=  (1 << RARCH_FIRST_CUSTOM_BIND);
                break;
            default:
                break;
        }
    } else {
        switch (button_id) {
            case RETRO_DEVICE_ID_JOYPAD_UP:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_UP);
                break;
            case RETRO_DEVICE_ID_JOYPAD_DOWN:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_DOWN);
                break;
            case RETRO_DEVICE_ID_JOYPAD_LEFT:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_LEFT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_RIGHT:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_RIGHT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_B:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_B);
                break;
            case RETRO_DEVICE_ID_JOYPAD_A:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_A);
                break;
            case RETRO_DEVICE_ID_JOYPAD_Y:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_Y);
                break;
            case RETRO_DEVICE_ID_JOYPAD_X:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_X);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L2:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L2);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R2:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R2);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L3:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L3);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R3:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R3);
                break;
            case RETRO_DEVICE_ID_JOYPAD_SELECT:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_START:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
                break;
            case RARCH_FIRST_CUSTOM_BIND:
                *buttons &= ~(1 << RARCH_FIRST_CUSTOM_BIND);
                break;
            default:
                break;
        }
    }

    if (port < MAX_USERS) {
        manic_post_trace([NSString stringWithFormat:@"JOY btn p%u id%u %@ 0x%04x", port, button_id, pressed ? @"on" : @"off", (unsigned)(manic_buttons[port] & 0xFFFF)]);
    }
}

void manic_input_analog_event(unsigned port, unsigned stick_id, float x_value, float y_value) {
    switch (stick_id) {
        case RETRO_DEVICE_INDEX_ANALOG_LEFT:
            manic_axes[port][0] = x_value * 32767.0f;
            manic_axes[port][1] = y_value * 32767.0f;
            break;
        case RETRO_DEVICE_INDEX_ANALOG_RIGHT:
            manic_axes[port][2] = x_value * 32767.0f;
            manic_axes[port][3] = y_value * 32767.0f;
            break;
        default:
            break;
    }

    if (port < MAX_USERS) {
        manic_post_trace([NSString stringWithFormat:@"JOY axis p%u s%u %.2f %.2f", port, stick_id, x_value, y_value]);
    }
    
}


static void manic_gamecontroller_joypad_poll(void) { }

#endif

#ifdef HAVE_COREMOTION
// 检查震动是否应该被忽略（防止重复调用）
static bool manic_should_ignore_rumble(enum retro_rumble_effect type, uint16_t strength) {
    if (@available(iOS 13.0, *)) {
        uint64_t currentTime = mach_absolute_time();
        uint64_t timeDiff = currentTime - hapticState.lastRumbleTime[type];
        
        // 如果强度相同且在50ms内重复调用，则忽略
        if (hapticState.lastRumbleStrength[type] == strength &&
            timeDiff < 50000000) { // 50ms in nanoseconds
            return true;
        }
        
        // 更新记录
        hapticState.lastRumbleTime[type] = currentTime;
        hapticState.lastRumbleStrength[type] = strength;
    }
    return false;
}

// 安全地启动震动模式
static bool manic_safe_start_rumble(id player) {
    if (@available(iOS 13.0, *)) {
        if (!player || hapticState.isShuttingDown || !hapticState.isEngineRunning) {
            return false;
        }
        
        @try {
            if ([player respondsToSelector:@selector(startAtTime:error:)]) {
                NSError *error = nil;
                BOOL success = [player startAtTime:0 error:&error];
                if (error) {
                    // 如果引擎已停止，尝试重新启动
                    if (hapticState.hapticEngine) {
                        [hapticState.hapticEngine startWithCompletionHandler:^(NSError * _Nullable startError) {
                            if (!startError) {
                                hapticState.isEngineRunning = YES;
                            }
                        }];
                    }
                    return false;
                }
                return success;
            }
        } @catch (NSException *exception) {
            // 捕获异常，防止崩溃
            return false;
        }
    }
    return false;
}

// 创建默认的触觉模式
static void manic_create_default_haptic_patterns(void) {
    if (@available(iOS 13.0, *)) {
        if (!hapticState.hapticEngine || !hapticState.hapticsSupported) return;
        
        // 创建强震动模式 (RETRO_RUMBLE_STRONG)
        CHHapticEvent *strongEvent = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient
                                                                   parameters:@[
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0],
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.5]
                                                                   ]
                                                                       relativeTime:0];
        
        CHHapticPattern *strongPattern = [[CHHapticPattern alloc] initWithEvents:@[strongEvent] parameters:@[] error:nil];
        if (strongPattern) {
            hapticState.strongRumblePlayer = [hapticState.hapticEngine createPlayerWithPattern:strongPattern error:nil];
        }
        
        // 创建弱震动模式 (RETRO_RUMBLE_WEAK)
        CHHapticEvent *weakEvent = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient
                                                                 parameters:@[
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:0.5],
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.3]
                                                                 ]
                                                                     relativeTime:0];
        
        CHHapticPattern *weakPattern = [[CHHapticPattern alloc] initWithEvents:@[weakEvent] parameters:@[] error:nil];
        if (weakPattern) {
            hapticState.weakRumblePlayer = [hapticState.hapticEngine createPlayerWithPattern:weakPattern error:nil];
        }
    }
}

// 创建自定义震动模式
static id manic_create_custom_rumble_pattern(float intensity, float sharpness, float duration) {
    if (@available(iOS 13.0, *)) {
        if (!hapticState.hapticEngine || !hapticState.hapticsSupported || hapticState.isShuttingDown) {
            return nil;
        }
        
        // 创建多个震动事件来模拟持续的震动效果
        NSMutableArray *events = [[NSMutableArray alloc] init];
        float eventInterval = 0.05f; // 50ms 间隔
        int eventCount = (int)(duration / eventInterval);
        
        for (int i = 0; i < eventCount; i++) {
            CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient
                                                                 parameters:@[
                [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:intensity],
                [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:sharpness]
                                                                 ]
                                                                     relativeTime:i * eventInterval];
            [events addObject:event];
        }
        
        CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:events parameters:@[] error:nil];
        if (pattern) {
            return [hapticState.hapticEngine createPlayerWithPattern:pattern error:nil];
        }
    }
    return nil;
}
#endif

void *manic_gamecontroller_joypad_init(void *data) {
    if (manic_inited)
        return (void*)-1;
    
#ifdef HAVE_COREMOTION
    // 初始化 Core Haptics
        if (@available(iOS 13.0, *)) {
            if (CHHapticEngine.capabilitiesForHardware.supportsHaptics) {
                NSError *error = nil;
                hapticState.hapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
                if (hapticState.hapticEngine && !error) {
                    hapticState.hapticEngine.autoShutdownEnabled = YES;
                    
                    // 设置引擎停止回调
                    hapticState.hapticEngine.stoppedHandler = ^(CHHapticEngineStoppedReason reason) {
                        hapticState.isEngineRunning = NO;
                        hapticState.strongRumblePlayer = nil;
                        hapticState.weakRumblePlayer = nil;
                    };
                    
                    // 启动 haptic engine
                    [hapticState.hapticEngine startWithCompletionHandler:^(NSError * _Nullable error) {
                        if (error) {
                            hapticState.hapticsSupported = false;
                            hapticState.isEngineRunning = false;
                        } else {
                            hapticState.hapticsSupported = true;
                            hapticState.isEngineRunning = true;
                            // 创建默认的震动模式
                            manic_create_default_haptic_patterns();
                        }
                    }];
                } else {
                    hapticState.hapticsSupported = false;
                    hapticState.isEngineRunning = false;
                }
            } else {
                hapticState.hapticsSupported = false;
                hapticState.isEngineRunning = false;
            }
        } else {
            hapticState.hapticsSupported = false;
            hapticState.isEngineRunning = false;
        }
#endif
    
    manic_inited = true;
    for (unsigned i = 0; i < MAX_USERS; i++) {
        input_autoconfigure_connect("Manic Controller", [NSString stringWithFormat:@"Manic Player %d", i].UTF8String, manic_joypad.ident, i, 0, 0);
    }
    return (void*)-1;
}

static void manic_gamecontroller_joypad_destroy(void) {
    manic_input_set_deinit();
}

static int32_t manic_gamecontroller_joypad_button(unsigned port, uint16_t joykey) {
    if (port >= DEFAULT_MAX_PADS)
        return 0;
    /* Check hat. */
    else if (GET_HAT_DIR(joykey))
        return 0;
    else if (joykey < 32)
        return ((manic_buttons[port] & (1 << joykey)) != 0);
    return 0;
}

static void manic_gamecontroller_joypad_get_buttons(unsigned port, input_bits_t *state) {
    BITS_COPY16_PTR(state, manic_buttons[port]);
}

static int16_t manic_gamecontroller_joypad_axis(unsigned port, uint32_t joyaxis) {
    if (AXIS_NEG_GET(joyaxis) < MAX_MANIC_AXES) {
        int16_t axis = AXIS_NEG_GET(joyaxis);
        int16_t val  = manic_axes[port][axis];
        if (val < 0)
            return val;
    } else if (AXIS_POS_GET(joyaxis) < MAX_MANIC_AXES) {
        int16_t axis = AXIS_POS_GET(joyaxis);
        int16_t val  = manic_axes[port][axis];
        if (val > 0)
            return val;
    }
    return 0;
}

static int16_t manic_gamecontroller_joypad_state(rarch_joypad_info_t *joypad_info,
                                                 const struct retro_keybind *binds,
                                                 unsigned port)
{
   uint16_t port_idx                    = joypad_info->joy_idx;

   if (port_idx >= DEFAULT_MAX_PADS)
      return 0;

   if (manic_last_reported_state[port_idx] != manic_buttons[port_idx]) {
      manic_last_reported_state[port_idx] = manic_buttons[port_idx];
      manic_post_trace([NSString stringWithFormat:@"JOY state p%u 0x%04x", port_idx, (unsigned)(manic_buttons[port_idx] & 0xFFFF)]);
   }

   return (int16_t)(manic_buttons[port_idx] & 0xFFFF);
}

static bool manic_gamecontroller_joypad_set_rumble(unsigned pad,
                                                   enum retro_rumble_effect type, uint16_t strength) {
    if (!get_enable_rumble()) {
        return false;
    }
    
    if (get_is_libretro_going_to_stop()) {
        return false;
    }
    
#ifdef HAVE_COREMOTION
    if (@available(iOS 13.0, *)) {
        // 检查是否应该忽略重复的震动调用
        if (manic_should_ignore_rumble(type, strength)) {
            return true; // 返回true表示"成功"，但实际不执行
        }
        
        // 检查引擎状态
        if (!hapticState.hapticsSupported || !hapticState.hapticEngine || hapticState.isShuttingDown) {
            return false;
        }
        
        // 如果引擎未运行，尝试重新启动
        if (!hapticState.isEngineRunning) {
            [hapticState.hapticEngine startWithCompletionHandler:^(NSError * _Nullable error) {
                if (!error) {
                    hapticState.isEngineRunning = YES;
                    // 重新创建默认模式
                    manic_create_default_haptic_patterns();
                }
            }];
            return false;
        }
        
        // 将 16 位强度值转换为 0.0-1.0 范围
        float normalizedStrength = (float)strength / 65535.0f;
        
        // 根据震动类型和强度创建相应的触觉反馈
        switch (type) {
            case RETRO_RUMBLE_STRONG: {
                // 强震动 - 使用高强度和中等锐度
                float intensity = normalizedStrength * 1.0f;
                float sharpness = 0.7f;
                float duration = 0.2f; // 200ms
                
                id player = manic_create_custom_rumble_pattern(intensity, sharpness, duration);
                if (player) {
                    return manic_safe_start_rumble(player);
                }
                
                // 如果自定义模式创建失败，尝试使用默认模式
                if (hapticState.strongRumblePlayer) {
                    return manic_safe_start_rumble(hapticState.strongRumblePlayer);
                }
                break;
            }
                
            case RETRO_RUMBLE_WEAK: {
                // 弱震动 - 使用中等强度和低锐度
                float intensity = normalizedStrength * 0.6f;
                float sharpness = 0.3f;
                float duration = 0.15f; // 150ms
                
                id player = manic_create_custom_rumble_pattern(intensity, sharpness, duration);
                if (player) {
                    return manic_safe_start_rumble(player);
                }
                
                // 如果自定义模式创建失败，尝试使用默认模式
                if (hapticState.weakRumblePlayer) {
                    return manic_safe_start_rumble(hapticState.weakRumblePlayer);
                }
                break;
            }
                
            default:
                return false;
        }
    }
#endif
    
    return false;
}

static bool manic_gamecontroller_joypad_query_pad(unsigned pad)
{
    return pad < MAX_USERS;
}

static const char *manic_gamecontroller_joypad_name(unsigned pad)
{
    if (pad < MAX_USERS)
        return "Manic Controller";
    return NULL;
}

input_device_driver_t manic_joypad = {
    manic_gamecontroller_joypad_init,
    manic_gamecontroller_joypad_query_pad,
    manic_gamecontroller_joypad_destroy,
    manic_gamecontroller_joypad_button,
    manic_gamecontroller_joypad_state,
    manic_gamecontroller_joypad_get_buttons,
    manic_gamecontroller_joypad_axis,
    manic_gamecontroller_joypad_poll,
    manic_gamecontroller_joypad_set_rumble,
    NULL,
    NULL,
    NULL,
    manic_gamecontroller_joypad_name,
    "manic",
};
