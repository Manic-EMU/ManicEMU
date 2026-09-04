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
    
    static var topWindow: UIWindow? {
        var window: UIWindow? = nil
#if os(iOS)
        window = ApplicationSceneDelegate.applicationScene?.windows.last(where: { w in
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
        })
#elseif os(tvOS)
        window = TVAppSceneDelegate.applicationScene?.windows.last
#endif
        return window ?? applicationWindow
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
