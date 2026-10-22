//
//  DuoTabletopKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import ProHUD

@available(iOS 27.1, *)
struct DuoTabletopKit {
    
    /// This parameter directly changes how UIDevice determines the device orientation and type.
    static var isTabletopMode: Bool = false
    
    /// True only while Tabletop is running on iPhone Duo. Other devices and platforms stay on their own path.
    static var isTabletopActive: Bool {
        isTabletopMode && UIDevice.isPhoneDuo
    }
    
    /// While true, Tabletop refuses further rotation. Cleared only for one portrait flip.
    static var isTabletopOrientationLocked = false
    
    /// Upright orientation the open lock is waiting to reach. Nil while locked.
    static var tabletopPendingOrientation: UIInterfaceOrientation?
    
    /// Tabletop buttons are D-pad input, not a touch that should dismiss FocusKit focus.
    static func isTabletopControlTouch(_ touch: UITouch) -> Bool {
        isTabletopActive && touch.window is DuoTabletopControlWindow
    }
    
    /// Inner-display Tabletop artboard (`Dark`, 669×951). The controller pane keeps its origin; the app window stretches down to meet it.
    private enum TabletopMetrics {
        static let screen = CGSize(width: 669, height: 951)
        static let bottomOriginY: CGFloat = 476
    }
    
    private static var savedOrientation: UIInterfaceOrientationMask?
    
    private static var controlWindow: UIWindow?
    
    private static var resumeAfterPlay = false
    
    private static var resumeOnActive = false
    /// Prevents the transition completion from delivering a second size change for the same frame update.
    
    private static var isDeliveringTabletopSizeTransition = false
    
    /// Stops Tabletop because a game is starting. Returns whether it was active.
    @discardableResult
    static func pauseTabletopForPlay() -> Bool {
        guard isTabletopActive else { return false }
        resumeAfterPlay = true
        resumeOnActive = false
        stopTabletopMode()
        return true
    }
    
    /// External emulator: restore when this scene becomes active again, if the hinge is still partially open.
    static func markTabletopResumeWhenActive() {
        guard resumeAfterPlay else { return }
        resumeOnActive = true
    }
    
    
    static func resumeTabletopAfterPlayIfNeeded() {
        // External emulators resume from sceneDidBecomeActive. Any other exit starts Tabletop if the hinge is still partial,
        // including a fold that happened during play and was ignored because a game was running.
        guard !resumeOnActive else { return }
        resumeTabletopIfStillPartiallyOpen()
    }
    
    
    static func resumeTabletopOnBecomeActiveIfNeeded() {
        guard resumeOnActive else { return }
        resumeTabletopIfStillPartiallyOpen()
    }
    
    
    static func resumeTabletopIfStillPartiallyOpen() {
        resumeAfterPlay = false
        resumeOnActive = false
        guard UIDevice.isPhoneDuoInnerFullScreen else { return }
        guard let hinge = DuoHingeKit.currentStatusHinge, hinge.status == .partiallyOpen else { return }
        startTabletopMode()
    }
    
    
    static func relayoutTabletopPanesIfNeeded() {
        guard isTabletopActive else { return }
        applyTabletopPanes()
    }
    
    /// Rotation finished. Lock again and assign so the system re-reads the lock.
    static func finishTabletopOrientationFlip() {
        guard isTabletopMode, tabletopPendingOrientation != nil else { return }
        tabletopPendingOrientation = nil
        isTabletopOrientationLocked = true
        AppDelegate.orientation = [.portrait, .portraitUpsideDown]
    }
    
    
    static func startTabletopMode() {
        guard UIDevice.isPhoneDuo else { return }
        guard !PlayViewController.isGaming else { return }
        // Already inside Tabletop, `isPhoneDuoInnerFullScreen` is false. Relayout before that guard.
        if isTabletopMode {
            applyTabletopPanes()
            return
        }
        guard UIDevice.isPhoneDuoInnerFullScreen else { return }
        guard ApplicationSceneDelegate.applicationScene != nil,
              ApplicationSceneDelegate.applicationWindow != nil else { return }
        
        savedOrientation = AppDelegate.orientation
        isTabletopMode = true
        isTabletopOrientationLocked = true
        AppContext.isPhoneDuoTabletopMode = true
        applyTabletopPanes()
        // Assignment makes the system re-read prefersInterfaceOrientationLocked. The mask itself is ignored on Duo inner.
        AppDelegate.orientation = [.portrait, .portraitUpsideDown]
        
        AppContext.hideAllHUDs()
    }
    
    
    static func stopTabletopMode() {
        guard isTabletopActive else { return }
        isTabletopMode = false
        isTabletopOrientationLocked = false
        tabletopPendingOrientation = nil
        controlWindow?.isHidden = true
        controlWindow?.rootViewController = nil
        controlWindow = nil
        ApplicationSceneDelegate.applicationWindow?.makeKey()
        
        let restored = savedOrientation ?? R.Config.DefaultOrientation
        savedOrientation = nil
        // Re-read the lock. requestGeometryUpdate cannot rotate Duo inner by itself.
        AppDelegate.orientation = restored
        restoreFullScreenFrame()
        
        AppContext.isPhoneDuoTabletopMode = false
    }
    
    
    private static func sceneBounds() -> CGRect? {
        guard let scene = ApplicationSceneDelegate.applicationScene else { return nil }
        let bounds = scene.coordinateSpace.bounds
        guard bounds.width > 1, bounds.height > 1 else { return nil }
        return bounds
    }
    
    
    private static func applyTabletopPanes() {
        guard isTabletopMode, let bounds = sceneBounds(),
              let appWindow = ApplicationSceneDelegate.applicationWindow,
              let scene = ApplicationSceneDelegate.applicationScene else { return }
        let scale = max(appWindow.screen.scale, 1)
        let scaleY = bounds.height / TabletopMetrics.screen.height
        let bottomY = bounds.minY + ((TabletopMetrics.bottomOriginY * scaleY) * scale).rounded() / scale
        let appFrame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bottomY - bounds.minY)
        let bottomFrame = CGRect(x: bounds.minX, y: bottomY, width: bounds.width, height: max(0, bounds.maxY - bottomY))
        let window = controlWindow ?? {
            let created = DuoTabletopControlWindow(windowScene: scene)
            created.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
            created.backgroundColor = .clear
            created.rootViewController = DuoTabletopControlController()
            created.overrideUserInterfaceStyle = appWindow.overrideUserInterfaceStyle
            controlWindow = created
            return created
        }()
        window.frame = bottomFrame
        window.isHidden = false
        // Touches land here, but FocusKit reads the key window. Keep that on the app window.
        if window.isKeyWindow {
            appWindow.makeKey()
        }
        // Frame assignment is not a system size transition, so deliver viewWillTransition ourselves.
        setAppWindowFrame(appFrame, of: appWindow)
    }
    
    
    private static func restoreFullScreenFrame() {
        guard let bounds = sceneBounds(),
              let appWindow = ApplicationSceneDelegate.applicationWindow else { return }
        setAppWindowFrame(bounds, of: appWindow)
    }
    
    /// UIKit only sends `viewWillTransition` for a scene geometry change. A manual window frame does not.
    /// Callbacks still see the old size; the frame changes before alongside and completion.
    
    private static func setAppWindowFrame(_ frame: CGRect, of appWindow: UIWindow) {
        guard !isDeliveringTabletopSizeTransition else { return }
        defer { AppContext.syncTabletopOverlayWindows() }
        guard !appWindow.frame.equalTo(frame) else { return }
        guard let root = appWindow.rootViewController, root.isViewLoaded else {
            appWindow.frame = frame
            return
        }
        isDeliveringTabletopSizeTransition = true
        defer { isDeliveringTabletopSizeTransition = false }
        let coordinator = TabletopSizeTransitionCoordinator(viewController: root)
        root.viewWillTransition(to: frame.size, with: coordinator)
        appWindow.frame = frame
        UIView.performWithoutAnimation {
            root.view.layoutIfNeeded()
            coordinator.performAlongside()
            root.view.layoutIfNeeded()
        }
        coordinator.performCompletion()
    }
}
