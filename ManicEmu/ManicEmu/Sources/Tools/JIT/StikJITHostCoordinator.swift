//
//  StikJITHostCoordinator.swift
//  ManicEmu
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#if SIDE_LOAD
import UIKit
import Darwin

final class StikJITHostCoordinator {
    static let shared = StikJITHostCoordinator()
    private static let acquireToastID = "StikJITAcquire"

    private let readinessTimeout: TimeInterval = 60
    private let closeSessionTimeout: TimeInterval = 3
    private var activeLauncher: StikJITExtensionLauncher?
    private var activeHost: HostBridge?
    private var readinessPoll: Timer?
    private var attemptID = 0
    private var publishAcquireProgress = false
    /// `enableJIT` is in the universal.js `while (!detached)` loop (TXM), so brk still works.
    private var scriptSessionLive = false
    private var acquireBusy = false
    private var pendingAcquires: [(AcquireReason, (Bool, String?) -> Void)] = []
    private var activeRunner: StikJITRunnerXPCProtocol?
    /// NSExtension cannot be relaunched in the same turn as `_kill`.
    private var helperNeedsRelaunchDelay = false
    private var closingForRemount = false
    /// True after this process called Built-in `enableJIT`. StikDebug-only sessions
    /// must not remount JITEnabler when the core has already DETACH'd.
    private var builtInAttachedThisProcess = false
    private let helperRelaunchDelay: TimeInterval = 1.0
    private let untraceTimeout: TimeInterval = 2.0

    private init() {}

    /// Who is actually attached. `jitLaunchMode` is only the user's preferred method.
    enum ActiveDebugger {
        case none
        case builtIn
        case external
    }

    var isBuiltInSessionLive: Bool { scriptSessionLive }

    /// StikDebug (or another debugger) is attached, and it is not our helper.
    var isExternallyTraced: Bool {
        EntitlementChecker.isCurrentlyTraced && !scriptSessionLive
    }

    var activeDebugger: ActiveDebugger {
        if scriptSessionLive { return .builtIn }
        if EntitlementChecker.isCurrentlyTraced { return .external }
        return .none
    }

    var activeDebuggerDisplayName: String {
        switch activeDebugger {
        case .builtIn:
            return R.string.localizable.jitMethodBuiltInDebugger()
        case .external:
            return R.string.localizable.jitMethodExternalDebugger()
        case .none:
            return R.string.localizable.jitDebuggerNotAttached()
        }
    }

    /// Game start: remount a TXM listening debugger if needed.
    /// `jitAvailable()` is the JIT environment at this moment. `loadConfig` will not
    /// enable core JIT when this is false, so do not attach here to create one.
    /// Legacy/PPL only need `CS_DEBUGGED` (already implied by `jitOn`). TXM also
    /// needs a live script / `P_TRACED` to handle `brk`.
    func acquireIfNeeded(game: Game, completion: @escaping () -> Void) {
        let jitOn = LibretroCore.jitAvailable()
        guard jitOn, game.supportJit, game.jit, !game.safeMode else {
            completion()
            return
        }
        if !ProcessInfo.processInfo.hasTXM {
            completion()
            return
        }

        let finish: (Bool, String?) -> Void = { ok, message in
            self.publishAcquireProgress = false
            UIView.hideToast(identifier: Self.acquireToastID)
            if !ok, let message {
                UIView.makeToast(message: message)
            }
            completion()
        }

        let debuggerListening = scriptSessionLive || EntitlementChecker.isCurrentlyTraced
        if debuggerListening {
            completion()
            return
        }
        acquire(reason: .gameLaunch, completion: finish)
    }

    /// Settings "Enable JIT" — always close a live TXM script then remount.
    func acquireNow(completion: @escaping (Bool, String?) -> Void) {
        acquire(reason: .manual, completion: completion)
    }

    /// Cold start: attach built-in JIT when auto-enable is on (default on).
    /// Scene `connectionOptions` cannot tell icon tap from StikDebug `process_control`
    /// relaunch — both look like a normal launch. A debugger-started process is already
    /// `P_TRACED` and/or `CS_DEBUGGED` before our code runs (cannot tell StikDebug vs Xcode).
    func enableOnLaunchIfNeeded() {
        guard StikJITManager.shared.jitLaunchMode == .builtInDebugger else { return }
        guard Settings.defalut.getExtraBool(key: ExtraKey.autoEnableJITOnLaunch.rawValue) ?? true else { return }
        guard StikJITManager.shared.isBuiltInAvailable, StikJITManager.shared.hasPairingFile else { return }
        if isLaunchedUnderExternalDebugger { return }
        acquireNow { ok, message in
            if ok {
                UIView.makeToast(message: R.string.localizable.enableJITSuccess())
            } else if let message, !message.isEmpty {
                UIView.makeToast(message: message)
            }
        }
    }

    /// True when this process was started (or attached) by a debugger before launch code ran.
    private var isLaunchedUnderExternalDebugger: Bool {
        EntitlementChecker.isCurrentlyTraced || LibretroCore.jitAvailable()
    }

    /// Game exit / cores that send CMD_DETACH: close then remount so the next launch can brk.
    func reacquireAfterDetach() {
        acquire(reason: .reattach, completion: { _, _ in })
    }

    func prepareDevice(progress: @escaping (String) -> Void, completion: @escaping (Bool, String?) -> Void) {
        guard #available(iOS 17.4, *) else {
            completion(false, R.string.localizable.jitRequiresiOS174())
            return
        }
        guard !StikJITManager.shared.isRunningInLiveContainer else {
            completion(false, R.string.localizable.jitLiveContainerUnavailable())
            return
        }
        guard EntitlementChecker.hasGetTaskAllow else {
            completion(false, R.string.localizable.jitGetTaskAllowMissing())
            return
        }
        guard let pairingData = pairingData() else {
            completion(false, R.string.localizable.jitPairingRequired())
            return
        }

        startHelper { runner, finish in
            self.activeHost?.onPreparationProgress = { stage, _, detail in
                DispatchQueue.main.async {
                    progress(detail ?? stage)
                }
            }
            self.activeHost?.onPreparationFinished = { readiness, reason, _ in
                DispatchQueue.main.async {
                    let hinted = reason.map(Self.troubleshootingHint)
                    switch readiness {
                    case "ready":
                        StikJITManager.shared.updateReadiness(status: R.string.localizable.jitPrepareReady(), reason: nil)
                        finish()
                        completion(true, nil)
                    case "unreachable":
                        StikJITManager.shared.updateReadiness(status: R.string.localizable.jitPrepareUnreachable(), reason: hinted)
                        finish()
                        completion(false, StikJITManager.shared.preparationFailureReason)
                    default:
                        StikJITManager.shared.updateReadiness(status: R.string.localizable.jitPrepareNotReady(), reason: hinted)
                        finish()
                        completion(false, StikJITManager.shared.preparationFailureReason)
                    }
                }
            }
            runner.prepareDevice(pairingData: pairingData)
        } failure: { error in
            StikJITManager.shared.updateReadiness(status: R.string.localizable.jitPrepareNotReady(), reason: error)
            completion(false, error)
        }
    }

    func resetCachedDDI(completion: @escaping (Bool, String?) -> Void) {
        guard #available(iOS 17.4, *) else {
            completion(false, R.string.localizable.jitRequiresiOS174())
            return
        }
        startHelper { runner, finish in
            self.activeHost?.onResetFinished = { ok, error in
                DispatchQueue.main.async {
                    if ok {
                        StikJITManager.shared.invalidateReadiness()
                    }
                    finish()
                    completion(ok, error)
                }
            }
            runner.resetCachedDDI()
        } failure: { error in
            completion(false, error)
        }
    }

    @discardableResult
    func openExternalDebugger() -> Bool {
        guard UIApplication.shared.canOpenURL(R.URLs.EnableJITUrl) else {
            return false
        }
        UIApplication.shared.open(R.URLs.EnableJITUrl)
        return true
    }

    // MARK: - Private

    private enum AcquireReason {
        case gameLaunch
        case manual
        case reattach
    }

    private func acquire(reason: AcquireReason, completion: @escaping (Bool, String?) -> Void) {
        pendingAcquires.append((reason, completion))
        startNextAcquire()
    }

    private func startNextAcquire() {
        guard !acquireBusy, let job = pendingAcquires.first else { return }
        pendingAcquires.removeFirst()
        acquireBusy = true
        performAcquire(reason: job.0) { [weak self] ok, message in
            job.1(ok, message)
            // Let a same-turn jitFinished/onFinished run first so it cannot kill the next helper.
            DispatchQueue.main.async {
                self?.acquireBusy = false
                self?.startNextAcquire()
            }
        }
    }

    private func performAcquire(reason: AcquireReason, completion: @escaping (Bool, String?) -> Void) {
        let mode = StikJITManager.shared.jitLaunchMode

        if mode == .externalDebugger {
            if reason != .manual, EntitlementChecker.isCurrentlyTraced {
                completion(true, nil)
                return
            }
            if openExternalDebugger() {
                return
            }
            completion(false, R.string.localizable.notInstall("StikDebug"))
            return
        }

        if reason == .gameLaunch, scriptSessionLive {
            completion(true, nil)
            return
        }

        // A second vAttach while debugserver is already attached makes universal.js
        // spin on `c` with no T-packet (Failed to extract registers forever).
        if isExternallyTraced {
            if reason == .manual {
                completion(false, R.string.localizable.jitExternalDebuggerAttached())
            } else {
                completion(true, nil)
            }
            return
        }

        if reason == .gameLaunch {
            publishAcquireProgress = true
            showAcquireToast(R.string.localizable.enableJIT())
        } else {
            publishAcquireProgress = false
        }

        guard EntitlementChecker.hasGetTaskAllow else {
            completion(false, R.string.localizable.jitGetTaskAllowMissing())
            return
        }

        closeLiveScriptSession { [weak self] in
            self?.startEnableJIT(completion: completion)
        }
    }

    /// If universal.js is still in `while (!detached)`, send CMD_DETACH first.
    /// On success keep the helper — killing it and relaunching immediately yields
    /// "Couldn't communicate with a helper application".
    private func closeLiveScriptSession(completion: @escaping () -> Void) {
        guard scriptSessionLive, activeLauncher != nil, ProcessInfo.processInfo.hasTXM else {
            invalidateHelper()
            completion()
            return
        }

        Log.debug("[StikJIT] sending CMD_DETACH before remount")
        closingForRemount = true
        var closed = false
        let finish = { [weak self] (keepHelper: Bool) in
            guard let self, !closed else { return }
            closed = true
            self.scriptSessionLive = false
            self.closingForRemount = false
            if keepHelper {
                self.waitUntilNotTraced(completion: completion)
            } else {
                Log.debug("[StikJIT] CMD_DETACH timed out, dropping helper")
                self.invalidateHelper()
                completion()
            }
        }

        activeHost?.onFinished = { _, _ in
            DispatchQueue.main.async { finish(true) }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            JIT26Detach()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + closeSessionTimeout) {
            finish(false)
        }
    }

    private func waitUntilNotTraced(completion: @escaping () -> Void) {
        let deadline = Date().addingTimeInterval(untraceTimeout)
        func tick() {
            if !EntitlementChecker.isCurrentlyTraced || Date() >= deadline {
                completion()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: tick)
        }
        tick()
    }

    private func startEnableJIT(completion: @escaping (Bool, String?) -> Void) {
        guard #available(iOS 17.4, *) else {
            completion(false, R.string.localizable.jitRequiresiOS174())
            return
        }
        guard !StikJITManager.shared.isRunningInLiveContainer else {
            completion(false, R.string.localizable.jitLiveContainerUnavailable())
            return
        }
        guard let pairingData = pairingData() else {
            completion(false, R.string.localizable.jitPairingRequired())
            return
        }
        if EntitlementChecker.isCurrentlyTraced {
            completion(false, R.string.localizable.jitExternalDebuggerAttached())
            return
        }

        attemptID += 1
        let thisAttempt = attemptID
        let targetPID = Int32(getpid())
        let forceScript = StikJITManager.shared.shouldForceScript
        let alreadyDebugged = LibretroCore.jitAvailable()
        var didComplete = false
        let completeOnce: (Bool, String?) -> Void = { [weak self] ok, message in
            guard let self, thisAttempt == self.attemptID, !didComplete else { return }
            didComplete = true
            self.readinessPoll?.invalidate()
            self.readinessPoll = nil
            completion(ok, message)
            if !ok {
                self.invalidateHelper()
            }
        }

        let run: (StikJITRunnerXPCProtocol) -> Void = { [weak self] runner in
            guard let self, thisAttempt == self.attemptID else { return }
            self.activeRunner = runner
            self.activeHost?.onLog = { [weak self] line in
                Log.debug("[StikJIT] \(line)")
                DispatchQueue.main.async {
                    if line.contains("attach_response")
                        || line.contains("JIT enabled (debugger attached") {
                        completeOnce(true, nil)
                    }
                    guard let self, self.publishAcquireProgress else { return }
                    self.showAcquireToast(line)
                }
            }
            self.activeHost?.onFinished = { ok, message in
                DispatchQueue.main.async {
                    guard thisAttempt == self.attemptID else { return }
                    self.scriptSessionLive = false
                    if ok {
                        if LibretroCore.jitAvailable() {
                            completeOnce(true, nil)
                        }
                        // TXM: script exited on DETACH after we already completed; drop idle helper.
                        if didComplete {
                            self.invalidateHelper()
                        }
                        return
                    }
                    let detail = (message?.isEmpty == false)
                        ? Self.troubleshootingHint(message!)
                        : R.string.localizable.jitPrepareNotReady()
                    completeOnce(false, detail)
                }
            }
            self.scriptSessionLive = true
            self.builtInAttachedThisProcess = true
            runner.enableJIT(forParentPID: targetPID, pairingData: pairingData, forceScript: forceScript)
            // Re-attach while CS_DEBUGGED is already set: do not treat that flag as "listening".
            if !(forceScript && alreadyDebugged) {
                self.waitForReadiness { ok, message in
                    completeOnce(ok, message)
                }
            }
        }

        let launchHelper = { [weak self] in
            guard let self, thisAttempt == self.attemptID else { return }
            self.startHelper(keepUntilJITFinished: true) { runner, _ in
                run(runner)
            } failure: { error in
                completeOnce(false, Self.troubleshootingHint(error))
            }
        }

        if let runner = activeRunner, activeLauncher != nil {
            run(runner)
        } else if helperNeedsRelaunchDelay {
            helperNeedsRelaunchDelay = false
            DispatchQueue.main.asyncAfter(deadline: .now() + helperRelaunchDelay, execute: launchHelper)
        } else {
            launchHelper()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + readinessTimeout) { [weak self] in
            guard let self, thisAttempt == self.attemptID, !didComplete else { return }
            completeOnce(false, R.string.localizable.jitAcquireTimeout())
            self.invalidateHelper()
        }
    }

    private func waitForReadiness(completion: @escaping (Bool, String?) -> Void) {
        if LibretroCore.jitAvailable() {
            completion(true, nil)
            return
        }

        readinessPoll?.invalidate()
        let deadline = Date().addingTimeInterval(readinessTimeout)
        readinessPoll = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            if LibretroCore.jitAvailable() {
                timer.invalidate()
                self?.readinessPoll = nil
                completion(true, nil)
            } else if Date() > deadline {
                timer.invalidate()
                self?.readinessPoll = nil
                completion(false, R.string.localizable.jitAcquireTimeout())
            }
        }
        if let poll = readinessPoll {
            RunLoop.main.add(poll, forMode: .common)
        }
    }

    private func pairingData() -> Data? {
        guard let url = StikJITManager.shared.currentPairingFileURL() else { return nil }
        return try? Data(contentsOf: url)
    }

    private func startHelper(
        keepUntilJITFinished: Bool = false,
        request: @escaping (StikJITRunnerXPCProtocol, @escaping () -> Void) -> Void,
        failure: @escaping (String) -> Void
    ) {
        if !keepUntilJITFinished, activeLauncher != nil {
            failure("Another StikJIT operation is already in progress.")
            return
        }
        let killedExisting = activeLauncher != nil
        invalidateHelper()

        let create = { [weak self] in
            guard let self else { return }
            let host = HostBridge()
            let launcher = StikJITExtensionLauncher(host: host)
            self.activeHost = host
            self.activeLauncher = launcher

            let finish: () -> Void = { [weak self] in
                self?.invalidateHelper()
            }

            if keepUntilJITFinished {
                host.onLog = { [weak self] line in
                    Log.debug("[StikJIT] \(line)")
                    DispatchQueue.main.async {
                        guard let self, self.publishAcquireProgress else { return }
                        self.showAcquireToast(line)
                    }
                }
            }

            launcher.launch { _, runner, error in
                DispatchQueue.main.async {
                    if let error {
                        finish()
                        failure(Self.troubleshootingHint(error.localizedDescription))
                        return
                    }
                    guard let runner else {
                        finish()
                        failure("Could not create the StikJIT runner proxy.")
                        return
                    }
                    request(runner, finish)
                }
            }
        }

        if killedExisting || helperNeedsRelaunchDelay {
            helperNeedsRelaunchDelay = false
            DispatchQueue.main.asyncAfter(deadline: .now() + helperRelaunchDelay, execute: create)
        } else {
            create()
        }
    }

    private func showAcquireToast(_ message: String) {
        UIView.makeToast(message: message, isRemovable: false, identifier: Self.acquireToastID)
    }

    private func invalidateHelper() {
        if activeLauncher != nil {
            helperNeedsRelaunchDelay = true
        }
        scriptSessionLive = false
        activeRunner = nil
        readinessPoll?.invalidate()
        readinessPoll = nil
        activeLauncher?.invalidate()
        activeLauncher = nil
        activeHost = nil
    }

    private static func troubleshootingHint(_ message: String) -> String {
        if message.contains("NSExtension creation failed") {
            return "\(message) StikJIT currently will not work inside LiveContainer."
        }
        if message.contains("Timed out connecting to 10.7.0.1:49152") {
            return "\(message) Make sure LocalDevVPN is connected and either a Wi-Fi network is connected or Airplane Mode is enabled."
        }
        if message.contains("Connection refused") {
            return "\(message) Reboot your device, then try again."
        }
        return message
    }
}

private final class HostBridge: NSObject, StikJITHostXPCProtocol {
    var onPreparationProgress: ((String, Double, String?) -> Void)?
    var onPreparationFinished: ((String, String?, NSNumber?) -> Void)?
    var onResetFinished: ((Bool, String?) -> Void)?
    var onLog: ((String) -> Void)?
    var onFinished: ((Bool, String?) -> Void)?

    func preparationProgress(_ stage: String, fraction: Double, detail: String?) {
        onPreparationProgress?(stage, fraction, detail)
    }

    func preparationFinished(_ readiness: String, reason: String?, txmPresent: NSNumber?) {
        onPreparationFinished?(readiness, reason, txmPresent)
    }

    func ddiResetFinished(_ ok: Bool, error: String?) {
        onResetFinished?(ok, error)
    }

    func jitLog(_ line: String) {
        onLog?(line)
    }

    func jitFinished(_ ok: Bool, error: String?) {
        onFinished?(ok, error)
    }
}
#endif
