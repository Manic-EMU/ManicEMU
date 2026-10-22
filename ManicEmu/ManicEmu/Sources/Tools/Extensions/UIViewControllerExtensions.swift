//
//  UIViewControllerExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/1.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

extension UIViewController {
    var hostingWindow: UIWindow? {
        view.window
    }
    
    var hostingWindowScene: UIWindowScene? {
        hostingWindow?.windowScene
    }
    
    static func shouldStatusBarHidden(window: UIWindow?,
                                      presentedViewController: UIViewController? = nil) -> Bool? {
        if let presentedViewController {
            if let nav = presentedViewController as? UINavigationController {
                return (nav.topViewController ?? presentedViewController).prefersStatusBarHidden
            } else if presentedViewController.isBeingPresented {
                return presentedViewController.prefersStatusBarHidden
            }
        }
        if UIDevice.isPad, let window {
            return window.size.IsRelativelyWideRectangle
        } else if UIDevice.isPhoneDuoInner && !UIDevice.isPhoneDuoSplitView {
            return true
        } else if #available(iOS 27.1, *), DuoTabletopKit.isTabletopMode {
            return true
        }
        return nil
    }
}
