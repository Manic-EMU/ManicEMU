//
//  Settings.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift

import IceCream
import SmartCodable

extension Settings: CKRecordConvertible & CKRecordRecoverable {
    var isDeleted: Bool { return false }
}

class Settings: Object, ObjectUpdatable {
    //一定要在Database的setup调用后才调用此方法
    static let defalut: Settings  = {
        return Database.realm.object(ofType: Settings.self, forPrimaryKey: Settings.defaultName)!
    }()
    
    static let defaultName = "SettingsDefault"
    ///名称当主键
    @Persisted(primaryKey: true) var name: String = Settings.defaultName
    
    ///皮肤配置 平台对应的默认皮肤 json格式 key是GameType value是Skin的id
    @available(*, deprecated)
    @Persisted var skinConfig: String
    
    ///快速开始游戏
    @Persisted var quickGame: Bool = false
    ///AirPlay全屏模式
    @Persisted var airPlay: Bool = true
    ///应用图标配置
    @Persisted var appIconIndex: Int = 0
    ///语言
    @Persisted var language: String?
    ///游戏功能排序
    @available(*, deprecated)
    @Persisted var gameFunctionList: List<Int>
    
    /// 展示在默认皮肤上的功能数量
    @available(*, deprecated)
    @Persisted var displayGamesFunctionCount: Int = R.Numbers.GameFunctionButtonCount
    ///iCloud同步 只会在本地进行存储，意味着一个新设备安装的时候 默认都是false
#if SIDE_LOAD
    var iCloudSyncEnable: Bool = false
    /// UserDefaults only; safe from any thread. Do not read `Settings.defalut` off its Realm thread.
    static var iCloudSyncEnableValue: Bool { false }
#else
    var iCloudSyncEnable: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: "iCloudSyncEnable")
            if newValue {
                //开启iCloud同步
                SyncManager.shared.startSync()
            } else {
                //关闭iCloud同步
                SyncManager.shared.stopSync()
            }
            NotificationCenter.default.post(name: R.NotificationName.iCloudEnableChange, object: nil)
        }
        get {
            UserDefaults.standard.bool(forKey: "iCloudSyncEnable")
        }
    }
    /// UserDefaults only; safe from any thread. Do not read `Settings.defalut` off its Realm thread.
    static var iCloudSyncEnableValue: Bool {
        UserDefaults.standard.bool(forKey: "iCloudSyncEnable")
    }
#endif
    ///3DS模式 默认兼容模式
    @Persisted var threeDSMode: ThreeDSMode = .compatibility
    ///连上手柄时 是否自动全屏
    @Persisted var fullScreenWhenConnectController: Bool = true
    ///默认图标
    @Persisted var desktopIcon: String?
    ///是否自动即时存档
    @Persisted var autoSaveState: Bool = false
    ///3ds进阶设置模式
    @Persisted var threeDSAdvancedSettingMode: Bool = false
    ///跟随系统静音
    @Persisted var respectSilentMode: Bool = false
    ///额外数据备用
    @Persisted var extras: Data?
    
    @Persisted var avatar: CreamAsset?
    
    enum Appearance: Int {
        case dark, light, auto
        var desc: String {
            switch self {
            case .light:
                R.string.localizable.appearanceLight()
            case .dark:
                R.string.localizable.appearanceDark()
            case .auto:
                R.string.localizable.appearanceAuto()
            }
        }
    }
    static var appearance: Appearance {
        get {
            return Appearance(rawValue: UserDefaults.standard.integer(forKey: R.DefaultKey.Appearance)) ?? .dark
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: R.DefaultKey.Appearance)
            ThemeManager.shared.updateAppearance()
        }
    }
    
    func getExtra(key: String) -> Any? {
        if let extras {
            return Self.getExtra(extras: extras, key: key)
        }
        return nil
    }
    
    func updateExtra(key: String, value: Any?) {
        if let extras, let data = Self.updateExtra(extras: extras, key: key, value: value) {
            Self.change { realm in
                self.extras = data
            }
        } else if let data = [key: value].jsonData() {
            Self.change { realm in
                self.extras = data
            }
        }
    }
    
    var airPlayScaling: GameOption.AirPlayScaling {
        GameOption.AirPlayScaling(rawValue: Settings.defalut.getExtraInt(key: ExtraKey.airPlayScaling.rawValue) ?? 0) ?? .coreProvided
    }
    
    var airPlayLayout: GameOption.AirPlayLayout {
        GameOption.AirPlayLayout(rawValue: Settings.defalut.getExtraInt(key: ExtraKey.airPlayLayout.rawValue) ?? 0) ?? .embeddedTopLeft
    }
    
    func getPlatformVisible(platform: String) -> Bool {
        var realPlatform = platform
        if GameType.chm.localizedShortName == platform {
            realPlatform = GameType.gb.localizedName
        } else if GameType.win95.localizedShortName == platform || GameType.win98.localizedShortName == platform {
            realPlatform = GameType.dos.localizedName
        } else if GameType.turbografx_16.localizedShortName == platform ||
                    GameType.turbografx_cd.localizedShortName == platform ||
                    GameType.supergrafx.localizedShortName == platform {
            realPlatform = GameType.pce.localizedName
        } else if GameType.ngpc.localizedShortName == platform {
            realPlatform = GameType.ngp.localizedName
        } else if GameType.ws.localizedShortName == platform {
            realPlatform = GameType.wsc.localizedName
        }
        return getExtraBool(key: realPlatform + "Visible") ?? true
    }
    
    func setPlatformVisible(platform: String, visible: Bool) {
        updateExtra(key: platform + "Visible", value: visible ? nil : false)
        NotificationCenter.default.post(name: R.NotificationName.PlatformVisibleChange, object: platform)
    }
    
    var SteamGridDBAPIKey: String? {
        Settings.defalut.getExtraString(key: ExtraKey.steamGridDBAPIKey.rawValue)
    }
    
    static var nickname: String {
        let nickname = Settings.defalut.getExtraString(key: ExtraKey.nickname.rawValue)?.trimmed
        if let nickname, !nickname.isEmpty {
            return nickname
        }
        return defaultNickname
    }
    
    static let defaultNickname = R.string.localizable.adventurer()
}

struct SkinConfig: SmartCodable {
    var portraitSkins = [String: String]()
    var landscapeSkins = [String: String]()
    
    var jsonString: String? {
        self.toJSONString()
    }
}
