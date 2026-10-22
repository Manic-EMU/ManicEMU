//
//  DuoTabletopControlController.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import ProHUD

@available(iOS 27.1, *)
final class DuoTabletopControlController: UIViewController {
    private let motion = CMMotionManager()
    
    override func loadView() {
        view = DuoTabletopControlView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startGravity()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        motion.stopDeviceMotionUpdates()
    }
    
    override var prefersInterfaceOrientationLocked: Bool {
        DuoTabletopKit.isTabletopOrientationLocked
    }
    
    override var prefersStatusBarHidden: Bool {
        if let action = AppContext.prefersStatusBarHidden, let result = action(presentedViewController) {
            return result
        }
        return true
    }
    
    private func startGravity() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.2
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let gravity = data?.gravity else { return }
            self.updateUpright(gravity)
        }
    }
    
    /// y dominates for portrait and upside-down. A landscape tilt does not release the lock.
    private func updateUpright(_ gravity: CMAcceleration) {
        guard DuoTabletopKit.isTabletopOrientationLocked,
              abs(gravity.y) > abs(gravity.x), abs(gravity.y) > 0.35 else { return }
        let target: UIInterfaceOrientation = gravity.y < 0 ? .portrait : .portraitUpsideDown
        guard let interface = view.window?.windowScene?.effectiveGeometry.interfaceOrientation
                ?? ApplicationSceneDelegate.applicationScene?.effectiveGeometry.interfaceOrientation,
              interface == .portrait || interface == .portraitUpsideDown,
              interface != target else { return }
        let mask: UIInterfaceOrientationMask = target == .portraitUpsideDown ? .portraitUpsideDown : .portrait
        DuoTabletopKit.tabletopPendingOrientation = target
        DuoTabletopKit.isTabletopOrientationLocked = false
        AppDelegate.orientation = mask
        ApplicationSceneDelegate.applicationScene?.requestGeometryUpdate(
            UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
        )
    }
}
