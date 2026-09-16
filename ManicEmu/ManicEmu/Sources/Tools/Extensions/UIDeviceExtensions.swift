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
    
    enum LayoutStyle: String {
        case iPadFullscreen = "iPad Full Screen"
        case iPadHalfScreen = "iPad 1/2 Screen"
        case iPadTwoThirdScreeen = "iPad 2/3 Screen"
        case iPadOneThirdScreen = "iPad 1/3 Screen"
        case iPhoneFullScreen = "iPhone"
    }
    
    static var layoutStyle: LayoutStyle {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .iPhoneFullScreen
        }
        let screenSize = UIScreen.main.bounds.size
        let appSize = R.Size.WindowSize
        let screenWidth = screenSize.width
        let appWidth = appSize.width
        
        if screenSize == appSize {
            return .iPadFullscreen
        }
        let persent = CGFloat(appWidth / screenWidth) * 100.0
        if persent <= 55.0 && persent >= 45.0 {
            // 半分屏
            return .iPadHalfScreen
        } else if persent > 55.0 {
            // 2/3
            return .iPadTwoThirdScreeen
        } else {
            // 1/3
            return .iPadOneThirdScreen
        }
    }
    
    static var isLandscape: Bool {
        UIDevice.currentOrientation == .landscapeLeft || UIDevice.currentOrientation == .landscapeRight
    }
    
    static var isPortrait: Bool {
        !isLandscape
    }
    
    static var isPadMini: Bool {
        if UIDevice.isPad, R.Size.WindowSize.minDimension <= 744 {
            return true
        }
        return false
    }
    
    static var isSmallScreenPhone: Bool {
        return Device.size().rawValue < Size.screen5_8Inch.rawValue
    }
    
    static var isProMaxPhone: Bool {
        return isPhone && Device.size().rawValue >= Size.screen6_3Inch.rawValue
    }
    
    static var currentOrientation: UIInterfaceOrientation {
        UIWindow.applicationWindow?.windowScene?.interfaceOrientation ?? .portrait
    }
    static var hasNotch: Bool {
        let insets = R.Size.SafeArea
        let orientation = UIDevice.currentOrientation
        if orientation == .landscapeRight {
            return insets.left > 20
        } else if orientation == .landscapeLeft {
            return insets.right > 20
        } else if orientation == .portraitUpsideDown {
            return insets.bottom > 20
        }
        return insets.top > 20
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
        if Device.isPhone() || Device.isPod() {
            return true
        } else if Device.isSimulator() {
            if R.Size.WindowSize.minDimension < 744 { //ipad mini 8.3寸 最小宽度是744
                return true
            }
        }
        return false
    }
    
    static var isPad: Bool {
        if Device.isPad() {
            return true
        } else if Device.isSimulator() {
            if R.Size.WindowSize.minDimension >= 744 { //ipad mini 8.3寸 最小宽度是744
                return true
            }
        }
        return false
    }
    
    static var isMac: Bool { ProcessInfo.processInfo.isiOSAppOnMac }
    
    static var deviceInfo: String {
        return "Device:\(Device.version())\nVersion:\(UIDevice.current.systemVersion)"
    }
    
    static var isDarkMode: Bool {
        ApplicationSceneDelegate.applicationWindow?.traitCollection.userInterfaceStyle == .dark
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
/// iPhone Control Center lock is a portrait lock. While the app interface is
/// landscape and the phone is still held landscape, omit portrait so UIKit cannot snap back.
enum OrientationLockPin {
    private enum PhysicalAttitude {
        case landscape
        case portrait
        case flat
        case unknown
    }
    
    private static let motion = CMMotionManager()
    private static var started = false
    private static var holdingLandscape = false
    private static var lastPhysicalLandscape: Bool?
    private static var lastDevicePortraitWhileHolding = false
    
    static var isPinned: Bool { holdingLandscape }
    /// Only during Control Center portrait-lock fighting a landscape UI.
    /// Returning true whenever we are in landscape locks iOS 26 and blocks rotating back.
    static var prefersLocked: Bool {
        guard holdingLandscape else { return false }
        let device = UIDevice.current.orientation
        return device.isPortrait || device.isFlat
    }
    
    static func start() {
        guard !started else { return }
        started = true
        guard UIDevice.isPhone, !UIDevice.isMac else { return }
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        startAccelerometerIfNeeded()
        
        let center = NotificationCenter.default
        center.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            handlePhysicalChange()
        }
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            startAccelerometerIfNeeded()
            handlePhysicalChange()
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            if motion.isAccelerometerActive {
                motion.stopAccelerometerUpdates()
            }
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            startAccelerometerIfNeeded()
        }
    }
    
    /// `window` is ignored for attitude. Overlay windows (toast / alert / sheet) are often
    /// wider than tall and must not flip the app-wide hold.
    static func resolvedMask(for window: UIWindow?) -> UIInterfaceOrientationMask {
        let allowed = AppDelegate.orientation
        guard UIDevice.isPhone, !UIDevice.isMac else { return allowed }
        
        let landscapeAllowed = allowed.intersection(.landscape)
        guard !landscapeAllowed.isEmpty else {
            holdingLandscape = false
            return allowed
        }
        
        switch physicalAttitude() {
        case .portrait:
            holdingLandscape = false
            return allowed
        case .landscape:
            if isAppInterfaceLandscape() {
                holdingLandscape = true
            }
            return holdingLandscape ? landscapeAllowed : allowed
        case .flat, .unknown:
            return holdingLandscape ? landscapeAllowed : allowed
        }
    }
    
    /// Fight a Control Center snap to portrait only. A real portrait hold must go through.
    static func resistPortraitTransitionIfNeeded(to size: CGSize) {
        guard UIDevice.isPhone, !UIDevice.isMac else { return }
        guard size.height > size.width else { return }
        guard physicalAttitude() == .landscape else { return }
        _ = resolvedMask(for: ApplicationSceneDelegate.applicationWindow)
        if holdingLandscape {
            applyMaskChange()
        }
    }
    
    private static func handlePhysicalChange() {
        let before = holdingLandscape
        _ = resolvedMask(for: ApplicationSceneDelegate.applicationWindow)
        let devicePortrait = UIDevice.current.orientation.isPortrait
        if before != holdingLandscape {
            lastDevicePortraitWhileHolding = holdingLandscape && devicePortrait
            applyMaskChange()
            return
        }
        if holdingLandscape, devicePortrait, !lastDevicePortraitWhileHolding {
            lastDevicePortraitWhileHolding = true
            applyMaskChange()
            return
        }
        if UIDevice.current.orientation.isLandscape {
            lastDevicePortraitWhileHolding = false
        }
    }
    
    private static func applyMaskChange() {
        notifyOrientationControllers()
        if #available(iOS 16.0, *) {
            if let scene = ApplicationSceneDelegate.applicationScene {
                scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: geometryTargetMask()))
            }
        } else if holdingLandscape {
            UIDevice.current.setValue(preferredInterfaceOrientation().rawValue, forKey: "orientation")
        }
        if !holdingLandscape {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    /// PlayViewController is presented on top of Home; iOS 26 reads the visible VC.
    private static func notifyOrientationControllers() {
        var vc = ApplicationSceneDelegate.applicationWindow?.rootViewController
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
    
    private static func geometryTargetMask() -> UIInterfaceOrientationMask {
        let allowed = AppDelegate.orientation
        if holdingLandscape {
            return preferredLandscapeMask()
        }
        switch physicalAttitude() {
        case .portrait:
            let portrait = allowed.intersection(.portrait)
            return portrait.isEmpty ? allowed : portrait
        case .landscape:
            let landscape = allowed.intersection(.landscape)
            return landscape.isEmpty ? allowed : landscape
        default:
            return allowed
        }
    }
    
    private static func startAccelerometerIfNeeded() {
        guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 0.1
        motion.startAccelerometerUpdates(to: .main) { _, _ in
            handlePhysicalChange()
        }
    }
    
    private static func isAppInterfaceLandscape() -> Bool {
        let interface = ApplicationSceneDelegate.applicationScene?.interfaceOrientation
            ?? ApplicationSceneDelegate.applicationWindow?.windowScene?.interfaceOrientation
            ?? UIDevice.currentOrientation
        return interface.isLandscape
    }
    
    /// Desk / face-up only. A reclined gaming grip must still count as portrait or landscape.
    private static func physicalAttitude() -> PhysicalAttitude {
        guard let acceleration = motion.accelerometerData?.acceleration else {
            return lastPhysicalLandscape.map { $0 ? .landscape : .portrait } ?? .unknown
        }
        let ax = abs(acceleration.x)
        let ay = abs(acceleration.y)
        let az = abs(acceleration.z)
        if az > 0.85 && ax < 0.35 && ay < 0.35 {
            return .flat
        }
        
        let hysteresis: Double = 0.2
        let now: Bool
        if let last = lastPhysicalLandscape {
            now = last ? ax + hysteresis > ay : ax > ay + hysteresis
        } else {
            now = ax > ay
        }
        lastPhysicalLandscape = now
        return now ? .landscape : .portrait
    }
    
    private static func preferredLandscapeMask() -> UIInterfaceOrientationMask {
        preferredInterfaceOrientation().interfaceMask
    }
    
    private static func preferredInterfaceOrientation() -> UIInterfaceOrientation {
        let interface = ApplicationSceneDelegate.applicationScene?.interfaceOrientation
            ?? ApplicationSceneDelegate.applicationWindow?.windowScene?.interfaceOrientation
            ?? UIDevice.currentOrientation
        if interface.isLandscape { return interface }
        if let acceleration = motion.accelerometerData?.acceleration {
            return acceleration.x > 0 ? .landscapeLeft : .landscapeRight
        }
        return .landscapeRight
    }
}

private extension UIInterfaceOrientation {
    var interfaceMask: UIInterfaceOrientationMask {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return []
        }
    }
}
#endif

