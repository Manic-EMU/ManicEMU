//
//  UniversalScript.swift
//  ManicJIT-script
//
//  Created by Stossy11 on 20/3/2026.
//
import Foundation

#if SIDE_LOAD
/// `uname` machine id, e.g. `iPad13,16`.
private func hardwareIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }
}

/// iOS 26+ only. TXM is A15+/M2+ (`iPhone`/`iPad` machine major >= 14).
/// Unparseable IDs stay PPL so we never brk on unknown hardware.
private func hasTXMSilicon() -> Bool {
    let id = hardwareIdentifier()
    let digits: Substring
    if id.hasPrefix("iPhone") {
        digits = id.dropFirst(6)
    } else if id.hasPrefix("iPad") {
        digits = id.dropFirst(4)
    } else {
        return false
    }
    guard let comma = digits.firstIndex(of: ","),
          let major = Int(digits[..<comma]) else {
        return false
    }
    return major >= 14
}

enum JITMemoryPath {
    case legacy
    case ppl
    case txm
}

public extension ProcessInfo {
    /// A15+ / M2+ silicon. Independent of OS version.
    var hasTXMSilicon: Bool { ManicEmu.hasTXMSilicon() }

    /// Allocator path cores use: iOS < 26 is always legacy W^X.
    internal var jitMemoryPath: JITMemoryPath {
        if operatingSystemVersion.majorVersion < 26 {
            return .legacy
        }
        return ManicEmu.hasTXMSilicon() ? .txm : .ppl
    }

    var hasTXM: Bool {
        let v = operatingSystemVersion
        if v.majorVersion < 26 {
            Log.debug("[JIT Env] Device: Legacy machine=\(hardwareIdentifier())")
            return false
        }
        let result = ManicEmu.hasTXMSilicon()
        Log.debug("[JIT Env] Device: \(result ? "TXM" : "PPL") machine=\(hardwareIdentifier())")
        return result
    }
}


@_silgen_name("BreakSendJITScript")
func BreakSendJITScript(_ script: UnsafePointer<CChar>!, _ length: size_t)

@_silgen_name("JIT26Detach")
func JIT26Detach()

func handler(sig: Int32, info: UnsafeMutablePointer<siginfo_t>?, context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let uc = context.bindMemory(to: ucontext_t.self, capacity: 1)
    uc.pointee.uc_mcontext.pointee.__ss.__pc += 4
    uc.pointee.uc_mcontext.pointee.__ss.__x.0 = 0
}

// here to stop app from crashing when app launched without JIT attached on 26 TXM
func JIT26BreakpointHandler() {
    var sa = sigaction()
    sa.sa_flags = SA_SIGINFO
    
    sa.__sigaction_u.__sa_sigaction = handler
    
    sigaction(SIGTRAP, &sa, nil)
}
#endif

func setupUniversalScript(gameType: GameType) {
#if SIDE_LOAD
    guard #available(iOS 19.0, *) else { return }
    guard ProcessInfo.processInfo.hasTXM else { return }
    
    JIT26BreakpointHandler()
    
    var script: String? = nil
    switch gameType {
    case ._3ds:
        script = """
          legacyCommands[0x70] = function(b) {};
          legacyCommands[0x71] = function(b) {};
      """
    case .n64:
        // TXM uses core-side brk #0xf00d (universal.js). Stub leftover 0x69
        // so an old dynarec binary cannot call prepare_memory_region after detach.
        script = """
          legacyCommands[0x70] = function(b) {};
          legacyCommands[0x71] = function(b) {};
          legacyCommands[0x69] = function(b) {};
      """
    default: return
    }
    
    guard let script else { return }
    
    BreakSendJITScript(script, script.count)
#endif
}
