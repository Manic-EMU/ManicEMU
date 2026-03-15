
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
import ManicEmuCore
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
            NotificationCenter.default.post(name: Constants.NotificationName.MotionShake, object: nil)
#if DEBUG
            if FLEXManager.shared.isHidden {
                FLEXManager.shared.showExplorer()
            } else {
                FLEXManager.shared.hideExplorer()
            }
            UIWindow.startShowingTouches()
#endif
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    //支持的旋转方向
    static var orientation: UIInterfaceOrientationMask = Constants.Config.DefaultOrientation {
        didSet {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    weak var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //日志系统初始化
        LogSetup()
        
        //禁用UIScrollView的iOS26的边缘效果
        UIScrollView.disableEdgeEffect()
        
        //注册模拟器核心
        System.allCores.forEach { ManicEmu.register($0) }
        
#if CRASH_COLLECT
        //收集闪退日志 用于内测用户测试bug时使用
        let apmConfig = UMAPMConfig.default()
        apmConfig.crashAndBlockMonitorEnable = true
        apmConfig.javaScriptBridgeEnable = false
        apmConfig.launchMonitorEnable = false
        apmConfig.logCollectEnable = false
        apmConfig.memMonitorEnable = false
        apmConfig.networkEnable = false
        apmConfig.oomMonitorEnable = false
        apmConfig.pageMonitorEnable = false
        apmConfig.logCollectEnable = false
        UMCrashConfigure.setAPMConfig(apmConfig)
        MobClick.setAutoPageEnabled(true)
        UMConfigure.initWithAppkey(Constants.Cipher.UMAppKey, channel: nil);
#endif
        
        //启动游戏手柄监听
        ExternalGameControllerUtils.shared.startDetecting()
        //启动游戏手柄点击监听
        UIControllerKit.shared.start()
        
        //启动清理
        //wifi缓存 粘贴版缓存 下载的缓存
        CacheManager.clear()
        
        //内购初始化
        PurchaseManager.setup()
        ExternalGameControllerUtils.shared.forceSetPlayerIndex = PurchaseManager.isMember ? 0 : nil
        
        //监听会员状态变化
        NotificationCenter.default.addObserver(forName: Constants.NotificationName.MembershipChange, object: nil, queue: .main) { _ in
            //强制设置外置控制器是否只能玩玩家一
            ExternalGameControllerUtils.shared.forceSetPlayerIndex = PurchaseManager.isMember ? 0 : nil
        }
        //注册静默通知 用于CloudKit的同步
        application.registerForRemoteNotifications()
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
    
    //允许的旋转类型
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientation
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
