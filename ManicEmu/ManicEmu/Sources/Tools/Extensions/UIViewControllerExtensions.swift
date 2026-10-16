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
}
