//
//  Functions.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

func objectInfo(_ object: AnyObject) -> String {
    "\(NSStringFromClass(type(of: object))): \(Unmanaged.passUnretained(object).toOpaque())"
}

func topApplicationViewController() -> UIViewController? {
    if let vc = topViewController(rootViewController: UIWindow.applicationWindow?.rootViewController) {
        return vc
    }
    return nil
}

func topViewController(in scene: UIWindowScene?) -> UIViewController? {
    if let window = UIWindow.topWindow(in: scene),
       let vc = topViewController(rootViewController: window.rootViewController) {
        return vc
    }
    return nil
}

private func topViewController(rootViewController: UIViewController?) -> UIViewController? {
    if rootViewController is UITabBarController, let vc = (rootViewController as! UITabBarController).selectedViewController {
        return topViewController(rootViewController: vc)
    } else if rootViewController is UINavigationController, let vc = (rootViewController as! UINavigationController).visibleViewController {
        return topViewController(rootViewController: vc)
    } else if let vc = rootViewController?.presentedViewController {
        return topViewController(rootViewController: vc)
    } else {
        return rootViewController
    }
}
