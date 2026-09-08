//
//  UniversalScript.c
//  ManicJIT-script
//
//  Created by Stossy11 on 20/3/2026.
//


#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef P_TRACED
#define P_TRACED 0x00000800
#endif

__attribute__((noinline,optnone,naked))
void BreakSendJITScript(char* script, size_t len) {
   asm("mov x16, #2 \n"
       "brk #0xf00d \n"
       "ret");
}

// CMD_DETACH for universal.js (x16 = 0). A live TXM script sends D and exits
// so the next enableJIT can vAttach again. Harmless without a debugger (SIGTRAP skips).
__attribute__((noinline,optnone,naked))
void JIT26Detach(void) {
   asm("mov x16, #0 \n"
       "brk #0xf00d \n"
       "ret");
}

// True while a debugger is attached (P_TRACED). CS_DEBUGGED can outlive detach.
int ManicProcessIsTraced(void) {
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc info;
    size_t size = sizeof(info);
    memset(&info, 0, sizeof(info));
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) {
        return 0;
    }
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}
