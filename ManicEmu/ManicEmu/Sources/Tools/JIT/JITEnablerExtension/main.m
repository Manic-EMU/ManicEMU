//
//  main.m
//  JITEnabler
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <os/log.h>
#import <unistd.h>

static void ManicStikJITAllowXPCClass(id self, SEL _cmd, id cls, id key, BOOL allowingInvocations) {}

__attribute__((used, visibility("default")))
int NSExtensionMain(int argc, char* argv[]) {
#if DEBUG
    os_log_t log = os_log_create("com.aoshuang.manicemu.JITEnabler", "StikJIT");
    os_log_with_type(log, OS_LOG_TYPE_DEFAULT, "JITEnabler main pid %{public}d", getpid());
#endif
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    Method method = class_getInstanceMethod(
        NSClassFromString(@"NSXPCDecoder"),
        @selector(_validateAllowedClass:forKey:allowingInvocations:));
    if (method) {
        method_setImplementation(method, (IMP)ManicStikJITAllowXPCClass);
    }
#pragma clang diagnostic pop

    int (*originalNSExtensionMain)(int, char**) =
        (int (*)(int, char**))dlsym(RTLD_NEXT, "NSExtensionMain");
    return originalNSExtensionMain(argc, argv);
}
