
//
//  AppDelegate.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/25.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import UniformTypeIdentifiers
import IQKeyboardManagerSwift
import IceCream
import CloudKit
#if DEBUG
import FLEX
import ShowTouches
#endif

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: R.NotificationName.MotionShake, object: nil)
#if DEBUG
            if FLEXManager.shared.isHidden {
                FLEXManager.shared.showExplorer()
            } else {
                FLEXManager.shared.hideExplorer()
            }
            UIWindow.configure(ShowTouchesConfig(touchColor: R.Color.Main))
            UIWindow.showTouches()
#endif
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    // Allowed interface orientations. Rotation follows this mask, not overlay windows.
    static var orientation: UIInterfaceOrientationMask = R.Config.DefaultOrientation {
        didSet {
            if !OrientationLockPin.isPinned {
                UIViewController.attemptRotationToDeviceOrientation()
            }
            if #available(iOS 26.0, *) {
                let root = ApplicationSceneDelegate.applicationWindow?.rootViewController
                root?.setNeedsUpdateOfSupportedInterfaceOrientations()
                root?.setNeedsUpdateOfPrefersInterfaceOrientationLocked()
            }
        }
    }
    
    weak var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //日志系统初始化
        LogSetup()
        
        //禁用UIScrollView的iOS26的边缘效果
        UIScrollView.disableEdgeEffect()
        
        //注册模拟器核心
        System.allCores.forEach { Delta.register($0) }
        
        //启动游戏手柄监听
        ExternalGameControllerManager.shared.startMonitoring()
        
        //Start listening for game controller or keyboard clicks.
        FocusKeyObserver.shared.start()
        FocusSystem.shared.moveHintTitle = R.string.localizable.focusHintMove()
        FocusSystem.shared.confirmHintTitle = R.string.localizable.confirmTitle()
        FocusSystem.shared.cancelHintTitle = R.string.localizable.focusHintBack()
        
        //启动清理
        //wifi缓存 粘贴版缓存 下载的缓存
        CacheManager.clear()
        
        //内购初始化
        PurchaseManager.setup()
        
        //监听会员状态变化
        NotificationCenter.default.addObserver(forName: R.NotificationName.MembershipChange, object: nil, queue: .main) { _ in
            //强制设置外置控制器是否只能玩玩家一
            ExternalGameControllerManager.shared.forceSetPlayerIndex = PurchaseManager.isMember ? 0 : nil
        }
        //注册静默通知 用于CloudKit的同步
        application.registerForRemoteNotifications()
        
        //Enable the imitation keyboard blocking issue
        IQKeyboardManager.shared.isEnabled = true
        OrientationLockPin.start()
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        var isWindowExternal = false
        if #available(iOS 16.0, *) {
            if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
                isWindowExternal = true
            }
        } else {
            if connectingSceneSession.role == .windowExternalDisplay {
                isWindowExternal = true
            }
        }
        if isWindowExternal {
            return UISceneConfiguration(name: "External Configuration", sessionRole: connectingSceneSession.role)
        } else {
            return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        }
    }
    
    //处理后台下载
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        let manager = DownloadManager.shared.sessionManager
        if manager.identifier == identifier {
            manager.completionHandler = completionHandler
        }
    }
    
    // Allowed orientations. Control Center portrait lock is pinned in OrientationLockPin.
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationLockPin.resolvedMask(for: window)
    }
    
    //APNS推送回调 没有真正开启用户推送通知，开启了静默通知 用于CloudKit的同步
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.debug("收到APNS通知:\(userInfo)")
        if let dict = userInfo as? [String: NSObject],
            let notification = CKNotification(fromRemoteNotificationDictionary: dict),
            let subscriptionID = notification.subscriptionID, IceCreamSubscription.allIDs.contains(subscriptionID) {
            NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: userInfo)
            completionHandler(.newData)
        }
    }
}
