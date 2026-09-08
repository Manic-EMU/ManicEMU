//
//  EntitlementChecker.swift
//  ManicEmu
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#if SIDE_LOAD
import Foundation
import Darwin
import Security

enum EntitlementChecker {
    /// Host process only. Checking from the helper inspects the wrong executable.
    static var hasGetTaskAllow: Bool {
        typealias CreateFn = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
        typealias CopyFn = @convention(c) (
            AnyObject,
            CFString,
            UnsafeMutablePointer<Unmanaged<CFError>?>?
        ) -> Unmanaged<CFTypeRef>?

        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)
        guard let createSymbol = dlsym(defaultHandle, "SecTaskCreateFromSelf"),
              let copySymbol = dlsym(defaultHandle, "SecTaskCopyValueForEntitlement") else {
            return false
        }

        let create = unsafeBitCast(createSymbol, to: CreateFn.self)
        let copy = unsafeBitCast(copySymbol, to: CopyFn.self)
        guard let task = create(nil)?.takeRetainedValue() else {
            return false
        }
        guard let value = copy(task, "get-task-allow" as CFString, nil)?.takeRetainedValue() else {
            return false
        }
        return (value as? NSNumber)?.boolValue == true
    }

    /// Debugger is attached right now. `CS_DEBUGGED` can still be set after detach.
    /// This is only a boolean: Xcode, StikDebug, AltStore, and SideStore all attach via debugserver.
    static var isCurrentlyTraced: Bool {
        ManicProcessIsTraced() != 0
    }
}

@_silgen_name("ManicProcessIsTraced")
private func ManicProcessIsTraced() -> Int32
#endif
