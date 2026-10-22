//
//  UIDeviceExtensions.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/25.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import CoreHaptics
import Haptica
import AudioToolbox.AudioServices
import ARKit
import Metal
import Device
#if os(iOS)
import CoreMotion
#endif

enum PerformanceTier {
    case low    // A10 and below (iPhone 7 / iPad 6th gen, iPhone9,x / iPad7,x)
    case normal // A11–A14/M1 (iPhone 8–12 / iPad Air 4–Pro 2021, iPhone13,x / iPad13,x)
    case high   // A15–A18 / M2–M3 (below iPhone 17 / iPad Pro M4)
    case ultra  // A19 / M4 and newer (iPhone18,x / iPad16,x)
}

extension UIDevice {
    static func generateHaptic(style: HapticFeedbackStyle = .soft) {
        if supportsHaptics {
            Haptic.impact(style).generate()
        } else {
            AudioServicesPlaySystemSound(1130)
        }
    }
    
    static func generateAchievementHaptic() {
        let achievementPattern: [LegacyNote] = [
            // 开场强烈震动
            .haptic(.impact(.heavy)),
            .wait(0.1),
            .haptic(.impact(.rigid)),

            // 节奏庆祝（三连击）
            .wait(0.15),
            .haptic(.impact(.medium)),
            .wait(0.1),
            .haptic(.impact(.medium)),
            .wait(0.1),
            .haptic(.impact(.medium)),

            // 收尾轻快感
            .wait(0.2),
            .haptic(.impact(.light)),
            .wait(0.05),
            .haptic(.impact(.soft))
        ]
        Haptic.play(achievementPattern)
    }
    
    static var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
    
    static var isLandscape: Bool {
        if #available(iOS 27.1, *) {
            if DuoTabletopKit.isTabletopMode {
                return true
            }
        }
        return UIDevice.currentOrientation == .landscapeLeft || UIDevice.currentOrientation == .landscapeRight
    }
    
    static var isPortrait: Bool {
        !isLandscape
    }
    
    static var isPadMini: Bool {
        if UIDevice.isPad {
            switch Device.version(detectSimulator: true) {
            case .iPadMini,
                 .iPadMini2,
                 .iPadMini3,
                 .iPadMini4,
                 .iPadMini5,
                 .iPadMini6,
                 .iPadMini7:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    static var isStandardPhone: Bool {
        switch Device.version(detectSimulator: true) {
        case .iPhone2G,
             .iPhone3G,
             .iPhone3GS,
             .iPhone4,
             .iPhone4S,
             .iPhone5,
             .iPhone5C,
             .iPhone5S,
             .iPhone6,
             .iPhone6Plus,
             .iPhone6S,
             .iPhone6SPlus,
             .iPhoneSE,
             .iPhone7,
             .iPhone7Plus,
             .iPhone8,
             .iPhone8Plus,
             .iPhoneSE2,
             .iPhoneSE3:
            return true
        default:
            return false
        }
    }
    
    static var isEdgeToEdgePhone: Bool {
        guard isPhone else { return false }
        return !isStandardPhone && !isPhoneDuo
    }
    
    static var isProMaxPhone: Bool {
        return isPhone && !isPhoneDuo && Device.size().rawValue >= Size.screen6_3Inch.rawValue
    }
    
    static func isFullScreenIPad(window: UIWindow) -> Bool {
        guard isPad else { return false }
        return window.bounds.equalTo(window.screen.bounds)
    }
    
    static func isWindowAppIPad(window: UIWindow) -> Bool {
        guard isPad else { return false }
        return !window.bounds.equalTo(window.screen.bounds)
    }
    
    static var currentOrientation: UIInterfaceOrientation {
        if #available(iOS 27.1, *) {
            if DuoTabletopKit.isTabletopMode {
                return .landscapeLeft
            }
        }
        return UIWindow.applicationWindow?.windowScene?.interfaceOrientation ?? .portrait
    }
    static var hasNotch: Bool {
        switch Device.version(detectSimulator: true) {
        case .iPhoneX,
             .iPhoneXS,
             .iPhoneXS_Max,
             .iPhoneXR,
             .iPhone11,
             .iPhone11Pro,
             .iPhone11Pro_Max,
             .iPhone12Mini,
             .iPhone12,
             .iPhone12Pro,
             .iPhone12Pro_Max,
             .iPhone13Mini,
             .iPhone13,
             .iPhone13Pro,
             .iPhone13Pro_Max,
             .iPhone14,
             .iPhone14Plus,
             .iPhone16e,
             .iPhone17e:
            return true
        default:
            return false
        }
    }
    
    static var hasDynamicIsland: Bool {
        Device.hasDynamicIsland
    }
    
    private static var mtlDevice: MTLDevice? = MTLCreateSystemDefaultDevice()
    
    var hasA9ProcessorOrBetter: Bool {
        // ARKit is only supported by devices with an A9 processor or better, according to the documentation.
        // https://developer.apple.com/documentation/arkit/arconfiguration/2923553-issupported
        return ARConfiguration.isSupported
    }
    
    var hasA11ProcessorOrBetter: Bool {
        guard let mtlDevice = UIDevice.mtlDevice else { return false }
        return mtlDevice.supportsFeatureSet(.iOS_GPUFamily4_v1) // iOS GPU Family 4 = A11 GPU
    }
    
    var hasA15ProcessorOrBetter: Bool {
        guard let mtlDevice = UIDevice.mtlDevice else { return false }
        return mtlDevice.supportsFamily(.apple8) // Apple 8 = A15/A16/M2 GPU
    }
    
    static var isPhone: Bool {
        if Device.isPhone(detectSimulator: true) || Device.isPod(detectSimulator: true) {
            return true
        }
        return false
    }
    
    static var isPhoneDuo: Bool {
        guard isPhone else { return false }
        return Device.version(detectSimulator: true) == .iPhoneDuo
    }
    
    static var isPhoneDuoInner: Bool {
        if #available(iOS 27.1, *) {
            if DuoTabletopKit.isTabletopMode {
                return false
            }
        }
        guard isPhoneDuo else { return false }
        // 669×951 pt, including partially folded. The scene stays on the inner display until closed.
        return Device.size() == .screen7_6Inch
    }
    
    static var isPhoneDuoInnerFullScreen: Bool {
        guard isPhoneDuoInner else { return false }
        return !isPhoneDuoSplitView
    }
    
    static var isPhoneDuoOuter: Bool {
        if #available(iOS 27.1, *) {
            if DuoTabletopKit.isTabletopMode {
                return true
            }
        }
        guard isPhoneDuo else { return false }
        // 466×678 pt. Only the closed pose uses the outer display.
        return Device.size() == .screen5_4Inch_2
    }
    
    static var isPhoneDuoSplitView: Bool {
        guard isPhoneDuoInner && isLandscape else { return false }
        if let appWindow = ApplicationSceneDelegate.applicationWindow {
            return !appWindow.screen.bounds.equalTo(appWindow.bounds)
        }
        return false
    }
    
    static var isPhoneDuoSplitViewRight: Bool {
        guard isPhoneDuoSplitView else { return false }
        if let appWindow = ApplicationSceneDelegate.applicationWindow {
            return appWindow.safeAreaInsets.right > 0
        }
        return false
    }
    
    static var isPhoneDuoCompactWidth: Bool {
        (isPhoneDuoOuter && isPortrait) || (isPhoneDuoSplitViewRight && isLandscape)
    }
    
    static var isPad: Bool {
        if Device.isPad(detectSimulator: true) {
            return true
        }
        return false
    }
    
    static var isMac: Bool { ProcessInfo.processInfo.isiOSAppOnMac }
    
    static var deviceInfo: String {
        return "Device:\(Device.version())\nVersion:\(UIDevice.current.systemVersion)"
    }
    
    static var isDarkMode: Bool {
        UIWindow.applicationWindow?.traitCollection.userInterfaceStyle == .dark
    }
    
    static var isIOS15: Bool {
        if #available(iOS 16.0, tvOS 16.0, *) {
            return false
        } else {
           return true
        }
    }
    
    /// `uname` / simulator model id, e.g. `iPhone18,2`.
    private static var machineIdentifier: String {
        #if targetEnvironment(simulator)
        if let id = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return id
        }
        #endif
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
    
    static var performanceTier: PerformanceTier {
        if isMac {
            return .ultra
        }
        
        let id = machineIdentifier
        let family: String
        let digits: Substring
        if id.hasPrefix("iPhone") {
            family = "iPhone"
            digits = id.dropFirst(6)
        } else if id.hasPrefix("iPad") {
            family = "iPad"
            digits = id.dropFirst(4)
        } else if id.hasPrefix("iPod") {
            return .low
        } else {
            return performanceTierFromMetal
        }
        
        guard let comma = digits.firstIndex(of: ","),
              let major = Int(digits[..<comma]) else {
            return performanceTierFromMetal
        }
        
        if family == "iPhone" {
            if major <= 9 { return .low }
            if major <= 13 { return .normal }
            if major < 18 { return .high }
            return .ultra
        }
        
        // iPad16,1–2 = mini (A17 Pro); 16,3+ = M4 Pro/Air
        if major <= 7 { return .low }
        if major <= 13 { return .normal }
        if major < 16 { return .high }
        if major == 16 {
            let minor = Int(digits[digits.index(after: comma)...]) ?? 0
            return minor >= 3 ? .ultra : .high
        }
        return .ultra
    }
    
    /// Used when `hw.machine` is missing or unparseable (simulator host, unknown id).
    private static var performanceTierFromMetal: PerformanceTier {
        guard let mtlDevice else { return .low }
        if mtlDevice.supportsFamily(.apple8) { return .high }
        if mtlDevice.supportsFamily(.apple4) { return .normal }
        return .low
    }
}

extension Device {
    static public func isPhone(detectSimulator: Bool = true) -> Bool {
        return type(detectSimulator: detectSimulator) == .iPhone
    }
}

#if os(iOS)
/// iPhone-only. Control Center lock is portrait-only; iPad already locks the current
/// orientation and must not use this path.
///
/// Unlocked: return the app mask and do not touch geometry.
/// Control Center visible in landscape: omit portrait so a lock tap cannot snap to portrait.
/// Lock engaged in landscape: freeze until UIDevice reports landscape again (lock off).
///
/// A real turn reports portrait before the interface rotates. Pin only after gravity stays
/// clearly horizontal through a short confirmation, and cancel that confirmation if the
/// interface actually reaches portrait.
enum OrientationLockPin {
    private enum PhysicalAttitude {
        case landscape
        case portrait
        case flat
        case unknown
    }
    
    private static let motion = CMMotionManager()
    /// How long a portrait report must keep disagreeing with gravity before it is a lock.
    private static let confirmationDelay: TimeInterval = 0.4
    private static var started = false
    private static var motionGeneration = 0
    private static var latestGravity: CMAcceleration?
    private static var confirmItem: DispatchWorkItem?
    /// Bumped on cancel so a block that already left the queue cannot clear a newer confirmation.
    private static var confirmToken = 0
    private static var unlockItem: DispatchWorkItem?
    private static var unlockToken = 0
    private static var isReconciling = false
    /// User turned on Control Center lock while the UI was landscape.
    private static var lockedInLandscape = false
    /// Omit portrait. Set while Control Center covers a landscape UI, and held through the
    /// post-return confirmation so that window cannot snap to portrait.
    private static var controlCenterOpenInLandscape = false
    /// Landscape side at the moment Control Center opened. `.landscape` (both) is resolved
    /// by the system to landscapeRight, which flips a landscapeLeft UI.
    private static var lockedLandscapeSide: UIInterfaceOrientationMask?
    
    static var isPinned: Bool { lockedInLandscape }
    static var prefersLocked: Bool { lockedInLandscape || controlCenterOpenInLandscape }
    /// iOS 26 overlay windows copy the scene bounds after a forced landscape update.
    static var onForcedLandscapeGeometry: (() -> Void)?
    
    static func handleSceneWillResignActive() {
        beginControlCenterIfLandscape()
    }
    
    static func start() {
        guard !started else { return }
        started = true
        guard shouldHandle else { return }
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        startMotionIfNeeded()
        
        let center = NotificationCenter.default
        center.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            handleDeviceOrientationNotification()
        }
        center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            beginControlCenterIfLandscape()
        }
        center.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: .main) { note in
            guard note.object as? UIWindowScene === ApplicationSceneDelegate.applicationScene else { return }
            beginControlCenterIfLandscape()
        }
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            handleDidBecomeActive()
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            stopMotion()
            cancelLockConfirmation()
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            startMotionIfNeeded()
        }
    }
    
    static func resolvedMask(for window: UIWindow?) -> UIInterfaceOrientationMask {
        if #available(iOS 27.1, *), DuoTabletopKit.isTabletopActive {
            return [.portrait, .portraitUpsideDown]
        }
        let allowed = AppDelegate.orientation
        guard shouldHandle else { return allowed }
        
        let landscapeAllowed = allowed.intersection(.landscape)
        guard !landscapeAllowed.isEmpty else {
            lockedInLandscape = false
            controlCenterOpenInLandscape = false
            lockedLandscapeSide = nil
            cancelLockConfirmation()
            return allowed
        }
        
        if lockedInLandscape || controlCenterOpenInLandscape {
            return preferredLandscapeMask(allowed: allowed)
        }
        return allowed
    }
    
    static func resistPortraitTransitionIfNeeded(to size: CGSize) {
        guard shouldHandle, size.height > size.width else { return }
        if lockedInLandscape {
            reassertLockedLandscape()
            return
        }
        // Portrait geometry with no pin yet is a real turn. Control Center keeps its own mask.
        if !controlCenterOpenInLandscape {
            cancelLockConfirmation()
        }
    }
    
    private static var shouldHandle: Bool {
        UIDevice.isPhone && !UIDevice.isMac
    }
    
    private static func beginControlCenterIfLandscape() {
        guard shouldHandle, isAppInterfaceLandscape() else { return }
        // Drop a pending in-app sample. The mask covers the tap; become-active confirms it.
        cancelLockConfirmation()
        captureLandscapeSideIfNeeded()
        let alreadySet = controlCenterOpenInLandscape
        controlCenterOpenInLandscape = true
        if !alreadySet {
            notifyOrientationControllers()
        }
    }
    
    private static func handleDidBecomeActive() {
        startMotionIfNeeded()
        let device = UIDevice.current.orientation
        if lockedInLandscape {
            cancelLockConfirmation()
            if device.isLandscape || physicalAttitude() == .portrait {
                // Lock off while the phone is portrait never posts a landscape device event.
                releaseLandscapeLock()
            } else {
                controlCenterOpenInLandscape = false
                notifyOrientationControllers()
            }
            return
        }
        guard controlCenterOpenInLandscape else { return }
        if portraitSuppressionStillNeeded() {
            scheduleLockConfirmation()
        } else {
            endControlCenterSuppression()
        }
    }
    
    private static func handleDeviceOrientationNotification() {
        guard shouldHandle else { return }
        let device = UIDevice.current.orientation
        if lockedInLandscape {
            if device.isLandscape {
                releaseLandscapeLock()
            } else if physicalAttitude() != .portrait && (device.isPortrait || device.isFlat) {
                // Portrait gravity is handled by the motion sample, so a lock-on
                // notification cannot unpin from one bad reading.
                reassertLockedLandscape()
            }
            return
        }
        // Control Center is up: portrait is already omitted. Decide after it closes.
        if controlCenterOpenInLandscape, UIApplication.shared.applicationState != .active {
            return
        }
        if isLandscapeHeldPortraitReport() {
            scheduleLockConfirmation()
            return
        }
        if controlCenterOpenInLandscape {
            if !portraitSuppressionStillNeeded() {
                endControlCenterSuppression()
            }
            return
        }
        // Unknown gravity is not a decision. Portrait, flat, or a landscape device is.
        let attitude = physicalAttitude()
        if !isAppInterfaceLandscape() || device.isLandscape || attitude == .portrait || attitude == .flat {
            cancelLockConfirmation()
        }
    }
    
    /// Device says portrait while gravity is still clearly landscape. Flat and unknown do not count.
    private static func isLandscapeHeldPortraitReport() -> Bool {
        guard isAppInterfaceLandscape() else { return false }
        guard UIDevice.current.orientation.isPortrait else { return false }
        return physicalAttitude() == .landscape
    }
    
    /// Lock engaged with the phone lying flat: device reports portrait, gravity has no screen axis.
    private static func isFlatPortraitLockReport() -> Bool {
        guard isAppInterfaceLandscape() else { return false }
        guard UIDevice.current.orientation.isPortrait else { return false }
        return physicalAttitude() == .flat
    }
    
    private static func isConfirmedPortraitLock() -> Bool {
        if isLandscapeHeldPortraitReport() { return true }
        // Flat-on-table only counts after Control Center; an in-app face-up pass must not pin.
        return controlCenterOpenInLandscape && isFlatPortraitLockReport()
    }
    
    /// Keep omitting portrait while gravity is missing or still shows the lock signature.
    private static func portraitSuppressionStillNeeded() -> Bool {
        guard isAppInterfaceLandscape() else { return false }
        let device = UIDevice.current.orientation
        if device.isLandscape { return false }
        if device == .unknown { return true }
        switch physicalAttitude() {
        case .portrait:
            return false
        case .unknown:
            return true
        case .landscape, .flat:
            return device.isPortrait
        }
    }
    
    private static func scheduleLockConfirmation() {
        guard confirmItem == nil else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        confirmToken += 1
        let token = confirmToken
        let item = DispatchWorkItem {
            guard confirmToken == token else { return }
            confirmItem = nil
            applyLockConfirmation()
        }
        confirmItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + confirmationDelay, execute: item)
    }
    
    private static func cancelLockConfirmation() {
        confirmToken += 1
        confirmItem?.cancel()
        confirmItem = nil
    }
    
    private static func applyLockConfirmation() {
        guard UIApplication.shared.applicationState == .active else { return }
        guard isConfirmedPortraitLock() else {
            if controlCenterOpenInLandscape {
                endControlCenterSuppression()
            }
            return
        }
        captureLandscapeSideIfNeeded()
        lockedInLandscape = true
        controlCenterOpenInLandscape = false
        applyLockChange()
    }
    
    /// Phone is really portrait, or UIDevice caught up to landscape after the lock was turned off.
    private static func releaseLandscapeLock() {
        guard lockedInLandscape else { return }
        lockedInLandscape = false
        controlCenterOpenInLandscape = false
        lockedLandscapeSide = nil
        cancelLockConfirmation()
        cancelPortraitUnlock()
        applyLockChange()
    }
    
    /// Keep the first landscape side. A later snap to the other side must not replace it.
    private static func captureLandscapeSideIfNeeded() {
        guard case .none = lockedLandscapeSide else { return }
        switch currentInterfaceOrientation() {
        case .landscapeLeft:
            lockedLandscapeSide = .landscapeLeft
        case .landscapeRight:
            lockedLandscapeSide = .landscapeRight
        default:
            break
        }
    }
    
    private static func schedulePortraitUnlock() {
        guard lockedInLandscape, unlockItem == nil else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        unlockToken += 1
        let token = unlockToken
        let item = DispatchWorkItem {
            guard unlockToken == token else { return }
            unlockItem = nil
            guard lockedInLandscape, physicalAttitude() == .portrait else { return }
            releaseLandscapeLock()
        }
        unlockItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
    
    private static func cancelPortraitUnlock() {
        unlockToken += 1
        unlockItem?.cancel()
        unlockItem = nil
    }
    
    /// One concrete landscape side. Both-sides `.landscape` is what snaps the UI to landscapeRight.
    private static func preferredLandscapeMask(allowed: UIInterfaceOrientationMask) -> UIInterfaceOrientationMask {
        let landscapeAllowed = allowed.intersection(.landscape)
        if let side = lockedLandscapeSide, landscapeAllowed.contains(side) {
            return side
        }
        switch currentInterfaceOrientation() {
        case .landscapeLeft where landscapeAllowed.contains(.landscapeLeft):
            return .landscapeLeft
        case .landscapeRight where landscapeAllowed.contains(.landscapeRight):
            return .landscapeRight
        default:
            return landscapeAllowed
        }
    }
    
    /// Gravity updated before the deadline. Release early when the phone is clearly portrait.
    /// Never engages the lock; only the confirmation block does that.
    private static func reconcilePendingConfirmation() {
        guard !isReconciling, confirmItem != nil else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        isReconciling = true
        defer { isReconciling = false }
        if lockedInLandscape { return }
        if controlCenterOpenInLandscape {
            if !portraitSuppressionStillNeeded() {
                endControlCenterSuppression()
            }
            return
        }
        if !isAppInterfaceLandscape() || UIDevice.current.orientation.isLandscape || physicalAttitude() == .portrait {
            cancelLockConfirmation()
        }
    }
    
    private static func endControlCenterSuppression() {
        guard controlCenterOpenInLandscape else { return }
        controlCenterOpenInLandscape = false
        if !lockedInLandscape {
            lockedLandscapeSide = nil
        }
        cancelLockConfirmation()
        notifyOrientationControllers()
        // Portrait-locked gameplay must not be spun just because Control Center closed.
        guard allowsCurrentDeviceOrientation() else { return }
        UIViewController.attemptRotationToDeviceOrientation()
    }
    
    private static func allowsCurrentDeviceOrientation() -> Bool {
        let mask: UIInterfaceOrientationMask
        switch UIDevice.current.orientation {
        case .portrait: mask = .portrait
        case .portraitUpsideDown: mask = .portraitUpsideDown
        case .landscapeLeft: mask = .landscapeLeft
        case .landscapeRight: mask = .landscapeRight
        default: return false
        }
        return AppDelegate.orientation.contains(mask)
    }
    
    private static func applyLockChange() {
        notifyOrientationControllers()
        if lockedInLandscape {
            reassertLockedLandscape()
        } else {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    private static func reassertLockedLandscape() {
        notifyOrientationControllers()
        let mask = preferredLandscapeMask(allowed: AppDelegate.orientation)
        if #available(iOS 16.0, *) {
            ApplicationSceneDelegate.applicationScene?.requestGeometryUpdate(
                UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
            )
            if #available(iOS 26.0, *) {
                onForcedLandscapeGeometry?()
                DispatchQueue.main.async {
                    guard lockedInLandscape else { return }
                    onForcedLandscapeGeometry?()
                }
            }
        } else {
            UIDevice.current.setValue(interfaceOrientation(for: mask).rawValue, forKey: "orientation")
        }
    }
    
    private static func interfaceOrientation(for mask: UIInterfaceOrientationMask) -> UIInterfaceOrientation {
        if mask == .landscapeLeft { return .landscapeLeft }
        if mask == .landscapeRight { return .landscapeRight }
        return currentInterfaceOrientation().isLandscape ? currentInterfaceOrientation() : .landscapeRight
    }
    
    /// App window and ProHUD overlay windows. The sheet is often the window that actually rotates.
    private static func notifyOrientationControllers() {
        var roots: [UIViewController] = []
        let windows = ApplicationSceneDelegate.applicationScene?.windows ?? []
        for window in windows {
            if let root = window.rootViewController {
                roots.append(root)
            }
        }
        if roots.isEmpty, let root = UIWindow.applicationWindow?.rootViewController {
            roots.append(root)
        }
        for root in roots {
            var vc: UIViewController? = root
            while let current = vc {
                if #available(iOS 16.0, *) {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
                if #available(iOS 26.0, *) {
                    current.setNeedsUpdateOfPrefersInterfaceOrientationLocked()
                }
                vc = current.presentedViewController
            }
        }
    }
    
    private static func startMotionIfNeeded() {
        guard shouldHandle, motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.1
        motionGeneration += 1
        let generation = motionGeneration
        motion.startDeviceMotionUpdates(to: .main) { data, _ in
            guard generation == motionGeneration else { return }
            latestGravity = data?.gravity
            reconcilePendingConfirmation()
            guard lockedInLandscape else { return }
            if physicalAttitude() == .portrait {
                schedulePortraitUnlock()
            } else {
                cancelPortraitUnlock()
            }
        }
    }
    
    private static func stopMotion() {
        motionGeneration += 1
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
        latestGravity = nil
    }
    
    private static func isAppInterfaceLandscape() -> Bool {
        currentInterfaceOrientation().isLandscape
    }
    
    private static func currentInterfaceOrientation() -> UIInterfaceOrientation {
        ApplicationSceneDelegate.applicationScene?.interfaceOrientation
            ?? UIWindow.applicationWindow?.windowScene?.interfaceOrientation
            ?? UIDevice.currentOrientation
    }
    
    /// Fused gravity, not raw acceleration. The band around 45° stays `.unknown` so a real
    /// turn that UIDevice already calls portrait cannot arm a pin.
    private static func physicalAttitude() -> PhysicalAttitude {
        guard let gravity = latestGravity else { return .unknown }
        let ax = abs(gravity.x)
        let ay = abs(gravity.y)
        let az = abs(gravity.z)
        if az > 0.85 && ax < 0.35 && ay < 0.35 {
            return .flat
        }
        let margin = 0.3
        if ax > ay + margin && ax > 0.35 { return .landscape }
        if ay > ax + margin && ay > 0.35 { return .portrait }
        return .unknown
    }
}
#endif
