//
//  UIWindowExtensions.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/26.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import UIKit
import ProHUD

extension UIWindow {
    static var applicationWindow: UIWindow? {
#if os(iOS)
        return ApplicationSceneDelegate.applicationWindow
#elseif os(tvOS)
        return TVAppSceneDelegate.applicationWindow
#else
        return nil
#endif
    }
    
    /// Content window in `scene`, skipping alerts and keeping an elevated ProHUD sheet when one is visible.
    /// Pass nil to resolve the main application scene. A scene that was passed in is never replaced by another scene's window.
    static func topWindow(in scene: UIWindowScene?) -> UIWindow? {
        let resolvedScene = scene ?? ApplicationSceneDelegate.applicationScene
        if let window = resolvedScene?.windows.last(where: { w in
            if w.isHidden {
                return false
            }
            
            if w.rootViewController == nil {
                return false
            }
            
            if String(describing: type(of: w)) == "SheetWindow" {
                return w.windowLevel != .normal
            }
            
            if String(describing: type(of: w)) == "AlertWindow" {
                return false
            }
            
            if w.windowLevel != .normal {
                return false
            }
            
            return true
        }) {
            return window
        }
        if scene == nil {
            return applicationWindow
        }
        return nil
    }
    
#if os(iOS)
    func showDropView() {
        guard subviews.first(where: { $0 is DropGlowEffectView }) == nil else { return }
        let dropView = DropGlowEffectView()
        addSubview(dropView)
        dropView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        dropView.alpha = 0
        UIView.normalAnimate {
            dropView.alpha = 1
        }
    }
    
    func hideDropView() {
        subviews.forEach { subView in
            if subView is DropGlowEffectView {
                UIView.normalAnimate {
                    subView.alpha = 0
                } completion: { _ in
                    subView.removeFromSuperview()
                }
            }
        }
    }
#endif
}
