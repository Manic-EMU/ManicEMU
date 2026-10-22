//
//  Skin.swift
//  ManicEmu
//
//  Created by Max on 2025/1/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift
import IceCream

extension Skin: CKRecordConvertible & CKRecordRecoverable {
    /// Bundled skins follow the app package. Only imported and buildIn skins sync to iCloud.
    var isSyncable: Bool { skinType == .import || skinType == .buildIn }
}

enum SkinType: Int, PersistableEnum {
//    case `default`, manic, delta
    case `default`, buildIn, `import`, playcase
}

///只存储用户皮肤 自带的默认皮肤不会进行存储
class Skin: Object, ObjectUpdatable {
    ///id 由文件的Hash值决定
    @Persisted(primaryKey: true) var id: String //!!!设计漏洞 不要用hash来获取皮肤 可能skin文件会被修改
    ///皮肤名称 在info.json的identifier来决定
    @Persisted var identifier: String
    ///皮肤名称 在info.json的name来决定
    @Persisted var name: String
    ///文件名（包括了扩展名）
    @Persisted var fileName: String
    ///游戏平台类型
    @Persisted var gameType: GameType
    ///皮肤类型
    @Persisted var skinType: SkinType
    ///皮肤数据
    @Persisted var skinData: CreamAsset?
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
    ///额外数据备用
    @Persisted var extras: Data?
    
    ///文件是否存在
    var isFileExtsts: Bool {
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    var fileURL: URL {
        if skinType == .default, let core = gameType.manicEmuCore {
            return core.resourceBundle.url(forResource: core.name, withExtension: "manicskin")!
        } else if let filePath = skinData?.filePath {
            return filePath
        }
        //这里没什么用 如果返回下面的地址 说明该皮肤不可用 或者 是嵌入式manic皮肤
        return URL(fileURLWithPath: R.Path.Resource.appendingPathComponent(fileName))
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
    
    var canDeleted: Bool {
        if skinType == .default || skinType == .buildIn {
            return false
        }
        return true
    }
    
    lazy var controllerSkin: ControllerSkin? = {
        ControllerSkin(fileURL: fileURL)
    }()
    
    var isFlexSkin: Bool {
        return fileName.contains("_FLEX.manicskin")
    }
    
    var isEditable: Bool {
        if skinType == .default || isKeyboardSkin {
            return false
        }
        return true
    }
    
    var isKeyboardSkin: Bool {
        identifier.hasSuffix(".keyboard")
    }
    
    var supportShortcut: Bool {
        skinType == .default || isKeyboardSkin || identifier == R.Strings.WiimoteSkinIdentifier 
    }
    
    var previewPortraitTraits: ControllerSkin.Traits? = nil
    var previewLandscapeTraits: ControllerSkin.Traits? = nil
    
    /// Drop stale `.buildIn` rows iCloud restored after a bundle skin file (hash PK) changed.
    /// Default / PlayCase are local-only (`isSyncable`); imported skins are user data. Runs once per app version.
    static func polishSkinsAfterRealmSync() {
        guard let systemCoreVersion = UserDefaults.standard.string(forKey: R.DefaultKey.SystemCoreVersion) else { return }
        let flagKey = R.DefaultKey.HasPolishSkins + systemCoreVersion
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        
        let realm = Database.realm
        let skins = Array(realm.objects(Skin.self).where { !$0.isDeleted && $0.skinType == .buildIn })
        
        func identityKey(_ identifier: String, _ gameType: GameType) -> String {
            "\(identifier)\0\(gameType.rawValue)"
        }
        func matchesCurrentId(_ skinId: String, hash: String) -> Bool {
            skinId == hash || skinId.hasPrefix(hash + ".")
        }
        
        var currentHashByIdentity = [String: String]()
        for skin in skins {
            let path = R.Path.Resource.appendingPathComponent(skin.fileName)
            guard FileManager.default.fileExists(atPath: path),
                  let hash = FileHashUtil.truncatedHash(url: URL(fileURLWithPath: path)) else {
                continue
            }
            currentHashByIdentity[identityKey(skin.identifier, skin.gameType)] = hash
        }
        // Resource files not ready yet; retry on a later sync instead of locking this version.
        guard !currentHashByIdentity.isEmpty else { return }
        
        let stale = skins.filter { skin in
            guard let hash = currentHashByIdentity[identityKey(skin.identifier, skin.gameType)] else {
                return false
            }
            return !matchesCurrentId(skin.id, hash: hash)
        }
        if !stale.isEmpty {
            Log.debug("[Skin] polish: remove \(stale.count) stale buildIn skin(s)")
            try? realm.write {
                for skin in stale {
                    if Settings.defalut.iCloudSyncEnable {
                        skin.skinData?.deleteAndClean(realm: realm)
                        skin.isDeleted = true
                    } else {
                        realm.delete(skin)
                    }
                }
            }
        }
        // Preference remap already ran in Database.setup / addEmbedSkins on this launch.
        UserDefaults.standard.set(object: true, forKey: flagKey)
    }
}
