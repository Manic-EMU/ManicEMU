//
//  Database.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift
import IceCream
import ZIPFoundation

struct Database {
    /// Independent of marketing version. Bump only when Realm object schema changes; never decrease.
    /// Existing 2.0.0 databases already store this as 200 (`"2.0.0"` with dots stripped).
    private static let schemaVersion: UInt64 = 201
    
    static func setup(completion: (()->Void)? = nil) {
        do {
            let realm = Database.realm
            
            if realm.object(ofType: Prefference.self, forPrimaryKey: Prefference.defaultName) == nil {
                try? realm.write {
                    realm.add(Prefference())
                }
            }
            
            if realm.object(ofType: Settings.self, forPrimaryKey: Settings.defaultName) == nil {
                Log.debug("Settings missing; initializing")
                try realm.write {
                    realm.add(Settings())
                }
            }
            
            //处理主题
            let theme = realm.object(ofType: Theme.self, forPrimaryKey: Theme.defaultName)
            if theme == nil {
                //初始化主题
                let newTheme = Theme()
                try? realm.write({
                    realm.add(newTheme)
                })
            } else if let theme {
                //检查是否新增了平台
                let platformOrder = theme.platformOrder
                let allPlatforms = System.allCases.map { $0.gameType.localizedShortName }
                var needToAdd = [String]()
                if platformOrder.count != allPlatforms.count {
                    //需要新增平台
                    for platform in allPlatforms {
                        if !(platformOrder.contains(where: { $0 == platform })) {
                            needToAdd.append(platform)
                        }
                    }
                    try? realm.write({
                        theme.platformOrder.insert(contentsOf: needToAdd, at: 0)
                    })
                }
                if theme.gamesPerRow == 0 {
                    try? realm.write({
                        theme.gamesPerRow = 2
                    })
                }
            }
            
            //检查是否有游戏的封面还没有匹配
            let games = realm.objects(Game.self).where {
                !$0.isDeleted &&
                $0.gameCover == nil &&
                $0.onlineCoverUrl == nil &&
                !$0.hasCoverMatch
            }
            games.forEach { game in
                OnlineCoverManager.shared.addCoverMatch(OnlineCoverManager.CoverMatch(game: game))
            }
            
            if let systemCoreVersion = UserDefaults.standard.string(forKey: R.DefaultKey.SystemCoreVersion) {
                // Existing version record means this is an upgrade; run data migrations.
                let systemCoreVersionNumber = systemCoreVersion.parsedVersionNumber
                
                if systemCoreVersionNumber < 141 {
                    //调整1.4.0的gameType问题
                    let mds = realm.objects(Game.self).where { $0.gameType == .md && ($0.fileExtension.equals("chd", options: .caseInsensitive) || $0.fileExtension.equals("32x", options: .caseInsensitive)) }
                    if mds.count > 0 {
                        try? realm.write {
                            for md in mds {
                                if md.fileExtension.lowercased() == "chd" {
                                    md.gameType = .mcd
                                } else if md.fileExtension.lowercased() == "32x" {
                                    md.gameType = ._32x
                                }
                            }
                        }
                    }
                }
                
                
                if systemCoreVersionNumber < 142 {
                    //调整土星的默认使用核心
                    //只有1.4.2之前的版本需要处理 将所有已经导入的SS核心默认使用Yabause
                    let games = realm.objects(Game.self).where({ $0.gameType == .ss })
                    if games.count > 0 {
                        try? realm.write({
                            for ss in games {
                                ss.defaultCore = 1
                            }
                        })
                    }
                }
                
                if systemCoreVersionNumber < 150 {
                    //将所有GB和GBC进行分离
                    let gbcs = realm.objects(Game.self).where({ $0.gameType == .gbc }).filter({ $0.fileExtension.lowercased() == "gb" })
                    if gbcs.count > 0 {
                        try? realm.write({
                            for gbc in gbcs {
                                gbc.gameType = .gb
                            }
                        })
                    }
                }
                
                if systemCoreVersionNumber < 155 {
                    let allSkins = realm.objects(Skin.self)
                    //调整skinType
                    //.buildIn的值等于原来的.manic .import等于原来的.delta
                    let oldSkins = allSkins.where({ $0.skinType == .buildIn || $0.skinType == .import })
                    try? realm.write({
                        for oldSkin in oldSkins {
                            if !oldSkin.isFlexSkin {
                                oldSkin.skinType = .import
                            }
                        }
                    })
                    
                    //修复可能皮肤的identifier相同的错误
                    let defaultSkins = allSkins.where({ $0.skinType == .default })
                    for defaultSkin in defaultSkins {
                        let otherSkins = allSkins.where({ $0.identifier == defaultSkin.identifier && $0.skinType != .default && $0.gameType == defaultSkin.gameType })
                        if otherSkins.count > 0 {
                            for (index, otherSkin) in otherSkins.enumerated() {
                                try? realm.write {
                                    otherSkin.identifier = otherSkin.identifier + "_\(index)"
                                }
                            }
                        }
                    }
                }
                
                if systemCoreVersionNumber < 170 {
                    //调整snes gba的默认核心
                    let games = realm.objects(Game.self).where({ $0.gameType == .snes || $0.gameType == .gba })
                    if games.count > 0 {
                        try? realm.write({
                            for g in games {
                                if g.gameType == .gba, g.gameSaveStates.count > 0 {
                                    g.defaultCore = 1
                                } else if g.gameType == .snes {
                                    //如果将snes游戏迁移至bsnes 则将存档文件从Snes9x迁移到bsnes
                                    let oldSaveUrl = URL(fileURLWithPath: R.Path.Snes9x.appendingPathComponent("\(g.name).srm"))
                                    if FileManager.default.fileExists(atPath: oldSaveUrl.path) {
                                        try? FileManager.safeMoveItem(at: oldSaveUrl, to: URL(fileURLWithPath: R.Path.bsnes.appendingPathComponent("\(g.name).srm")), shouldReplace: true)
                                    }
                                }
                            }
                        })
                        
                        //将GBA即时存档文件都进行核心标记
                        for g in games {
                            if g.gameType == .gba, g.gameSaveStates.count > 0 {
                                for s in g.gameSaveStates {
                                    s.updateExtra(key: ExtraKey.saveStateCore.rawValue, value: 1)
                                }
                            }
                        }
                    }
#if SIDE_LOAD
                    //Sideload版本默认使用Picodrive
                    let picodriveGames = realm.objects(Game.self).where({ $0.gameType == .md || $0.gameType == .ms || $0.gameType == .gg || $0.gameType == .sg1000 })
                    if picodriveGames.count > 0 {
                        try? realm.write({
                            for g in picodriveGames {
                                g.defaultCore = 1
                            }
                        })
                        for g in picodriveGames {
                            if g.gameSaveStates.count > 0 {
                                for s in g.gameSaveStates {
                                    s.updateExtra(key: ExtraKey.saveStateCore.rawValue, value: 1)
                                }
                            }
                        }
                    }
#else
                    let picodriveGames = realm.objects(Game.self).where({ $0.gameType == .md || $0.gameType == .ms || $0.gameType == .gg || $0.gameType == .sg1000 })
                    if picodriveGames.count > 0 {
                        for g in picodriveGames {
                            //将picodrive的存档转移到Gearsystem或ClownMDEmu的目录
                            let oldSaveUrl = URL(fileURLWithPath: R.Path.PicoDrive.appendingPathComponent("\(g.name).srm"))
                            if FileManager.default.fileExists(atPath: oldSaveUrl.path) {
                                try? FileManager.safeMoveItem(at: oldSaveUrl, to: g.gameSaveUrl, shouldReplace: true)
                            }
                            //将旧的即时存档全部编辑Picodrive生成
                            if g.gameSaveStates.count > 0 {
                                for s in g.gameSaveStates {
                                    s.updateExtra(key: ExtraKey.saveStateCore.rawValue, value: 1)
                                }
                            }
                        }
                    }
#endif
                }
                
                //1.7.3之后将nes和fds区分开
                if systemCoreVersionNumber <= 173 {
                    var needsUpdate: Bool = systemCoreVersionNumber < 173
                    if !needsUpdate {
                        let systemCoreBuildVersion = UserDefaults.standard.integer(forKey: R.DefaultKey.SystemCoreBuildVersion)
                        let appBuildVersion = Int(R.Config.AppBuildVersion) ?? 0
                        if appBuildVersion > systemCoreBuildVersion {
                            needsUpdate = true
                        }
                    }
                    
                    if needsUpdate {
                        let nesGames = realm.objects(Game.self).where({ $0.gameType == .nes })
                        for nes in nesGames {
                            if nes.fileExtension.lowercased() == "fds" {
                                try? realm.write({
                                    nes.gameType = .fds
                                })
                            }
                        }
                    }
                }
                
                //修复1.9.1将J2meJS破坏的存档
                if systemCoreVersionNumber < 192 {
                    let games = realm.objects(Game.self).where({ $0.gameType == .j2me || $0.defaultCore == 0 })
                    for game in games {
                        if FileManager.default.fileExists(atPath: game.gameSaveUrl.path),
                           let newSaveUrl = fixJ2meJSSave(fileName: game.fileName, url: game.gameSaveUrl) {
                            try? FileManager.safeMoveItem(at: newSaveUrl, to: game.gameSaveUrl, shouldReplace: true)
                        }
                    }
                }
                
                if systemCoreVersionNumber < 200 {
                    //Migrate skin configuration
                    let games = realm.objects(Game.self).where({ $0.portraitSkin != nil || $0.landscapeSkin != nil })
                    for game in games {
                        if let skin = game.portraitSkin {
                            Prefference.defalut.storePrefference(kind: .skin,
                                                                 storeKey: .orientationKey(gameId: game.id, isLandScape: false),
                                                                 storeValue: skin.id)
                            try? realm.write({
                                game.portraitSkin = nil
                            })
                        }
                        if let skin = game.landscapeSkin {
                            Prefference.defalut.storePrefference(kind: .skin,
                                                                 storeKey: .orientationKey(gameId: game.id, isLandScape: true),
                                                                 storeValue: skin.id)
                            try? realm.write({
                                game.landscapeSkin = nil
                            })
                        }
                    }
                    if let skinConfigs = SkinConfig.deserialize(from: Settings.defalut.skinConfig) {
                        for (gameTypeString, skinId) in skinConfigs.portraitSkins {
                            if let gameType = GameType(shortName: gameTypeString) {
                                Prefference.defalut.storePrefference(kind: .skin,
                                                                     storeKey: .orientationKey(gameType: gameType, isLandScape: false),
                                                                     storeValue: skinId)
                            }
                        }
                        for (gameTypeString, skinId) in skinConfigs.landscapeSkins {
                            if let gameType = GameType(shortName: gameTypeString) {
                                Prefference.defalut.storePrefference(kind: .skin,
                                                                     storeKey: .orientationKey(gameType: gameType, isLandScape: true),
                                                                     storeValue: skinId)
                            }
                        }
                        try? realm.write({
                            Settings.defalut.skinConfig = ""
                        })
                    }
                    
                    //Migrate flexBackground configuration
                    let backgrounds = FlexBackground.getAllBackground()
                    for background in backgrounds {
                        let isLandScape = background.name.contains("landscape")
                        if background.global {
                            Prefference.defalut.storePrefference(kind: .flexBackground,
                                                                 storeKey: .orientationKey(isLandScape: isLandScape),
                                                                 storeValue: background.name)
                            continue
                        } else if background.consoles.count > 0 {
                            for console in background.consoles {
                                if let gameType = GameType(shortName: console) {
                                    Prefference.defalut.storePrefference(kind: .flexBackground,
                                                                         storeKey: .orientationKey(gameType: gameType, isLandScape: isLandScape),
                                                                         storeValue: background.name)
                                }
                            }
                            continue
                        } else {
                            for gameId in background.games {
                                Prefference.defalut.storePrefference(kind: .flexBackground,
                                                                     storeKey: .orientationKey(gameId: gameId, isLandScape: isLandScape),
                                                                     storeValue: background.name)
                            }
                        }
                    }
                    
                    //Migrate shader configuration
                    let shaderGames = realm.objects(Game.self).where({ $0.filterName != nil })
                    for game in shaderGames {
                        if let filterName = game.filterName {
                            Prefference.defalut.storePrefference(kind: .shader,
                                                                 storeKey: .shaderKey(gameId: game.id,
                                                                                      isGlsl: game.supportGlslShaders),
                                                                 storeValue: filterName)
                        }
                    }
                    
                    if let shaderConfig = ShaderConfig.getConfig() {
                        for (platform, shaderPath) in shaderConfig.coreConfigs {
                            if let gameType = GameType(shortName: platform) {
                                let isGlsl = gameType == .n64 && shaderPath.pathExtension.lowercased() == "glslp"
                                Prefference.defalut.storePrefference(kind: .shader,
                                                                     storeKey: .shaderKey(gameType: gameType, isGlsl: isGlsl),
                                                                     storeValue: shaderPath)
                            }
                        }
                        
                        if let globalShaderPath = shaderConfig.globalConfig {
                            let isGlsl = globalShaderPath.pathExtension.lowercased() == "glslp"
                            Prefference.defalut.storePrefference(kind: .shader,
                                                                 storeKey: .shaderKey(isGlsl: isGlsl),
                                                                 storeValue: globalShaderPath)
                        }
                    }
                    
                    //update gamesPerRow 2 to 3 for default
                    if Theme.defalut.gamesPerRow == 2 {
                        Theme.change { realm in
                            Theme.defalut.gamesPerRow = 3
                        }
                    }
                    
                    //The default core for the 3DS has been changed to Azahar.
                    var config = GlobalCoreSwitch.getConfig(realm: realm)
                    if config.getUsingCoreName(gameType: GameType._3ds) == nil {
                        config.setUsingCoreName(gameType: ._3ds, coreName: EmulationCore.Azahar.name)
                    }
                }
            }
            
            // After data migrations so Game.portraitSkin still points at live Skin objects.
            syncDefaultSkins(realm: realm)
            addEmbedSkins()
            
            //Prevent the game from not being removed after Articbase finishes its work due to an error.
            if let articbase = realm.object(ofType: Game.self, forPrimaryKey: R.Strings.AzaharArticBaseGameID) {
                try? realm.write {
                    realm.delete(articbase)
                }
            }
            
        } catch {
            Log.error("初始化数据错误 \(error)")
        }
        completion?()
    }
    
    static var realm: Realm {
        let config = defaultConfig
        do {
            return try Realm(configuration: config)
        } catch {
            Log.error("生成数据库失败 \(error)")
        }
        if let realm = try? Realm(configuration: config) {
            return realm
        }
        // Unreadable file (corruption / schema mismatch). Wipe so launch can continue; game data in this file is already inaccessible.
        Log.error("Retry opening Realm failed; resetting on-disk file so the app can launch")
        removeRealmFiles(config)
        if let realm = try? Realm(configuration: config) {
            return realm
        }
        Log.error("Reset Realm still failed; using in-memory fallback")
        var memoryConfig = config
        memoryConfig.fileURL = nil
        memoryConfig.inMemoryIdentifier = "ManicEmu.LaunchFallback"
        return try! Realm(configuration: memoryConfig)
    }
    
    private static func removeRealmFiles(_ config: Realm.Configuration) {
        guard let fileURL = config.fileURL else { return }
        let folder = fileURL.deletingLastPathComponent()
        let name = fileURL.lastPathComponent
        let extras = [
            fileURL,
            URL(fileURLWithPath: fileURL.path + ".lock"),
            URL(fileURLWithPath: fileURL.path + ".note"),
            folder.appendingPathComponent("\(name).management")
        ]
        for url in extras {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private static var defaultConfig: Realm.Configuration {
        var config = Realm.Configuration.defaultConfiguration
        if !FileManager.default.fileExists(atPath: R.Path.Realm) {
            try? FileManager.default.createDirectory(atPath: R.Path.Realm, withIntermediateDirectories: true)
        }
        config.fileURL = URL(fileURLWithPath: R.Path.RealmFilePath)
        config.schemaVersion = schemaVersion
        // Additive changes (new types/optional properties) apply automatically when this
        // version increases. Put property renames or destructive transforms inside.
        config.migrationBlock = { _, oldSchemaVersion in
            if oldSchemaVersion < 201 {
                // FilesSyncRecord is a new type; Realm creates its table automatically.
            }
        }
        return config
    }
    
    /// Insert missing default skins. Prefer defaults over local copies of the same skin.
    private static func syncDefaultSkins(realm: Realm) {
        let wanted = generateDefaultSkins()
        Log.debug("[Skin] syncDefaultSkins: wanted \(wanted.count) default skins")
        guard !wanted.isEmpty else { return }
        
        var toDelete: [Skin] = []
        var toAdd: [Skin] = []
        var deletingIds = Set<String>()
        
        func markDelete(_ skin: Skin) {
            guard !skin.isInvalidated, !deletingIds.contains(skin.id) else { return }
            deletingIds.insert(skin.id)
            toDelete.append(skin)
        }
        
        var unchangedDefaults = 0
        for newSkin in wanted {
            if let existing = realm.object(ofType: Skin.self, forPrimaryKey: newSkin.id),
               !existing.isInvalidated {
                if existing.skinType == .default {
                    unchangedDefaults += 1
                    continue
                }
                // Same file as a default skin; drop the local copy.
                logSkin("update (replace local with default)", existing, extra: "-> \(describeSkin(newSkin))")
                remapSkinPreference(from: existing.id, to: newSkin.id)
                markDelete(existing)
                toAdd.append(newSkin)
                continue
            }
            
            let sameIdentity = Array(realm.objects(Skin.self).where {
                $0.identifier == newSkin.identifier && $0.gameType == newSkin.gameType
            })
            var needsAdd = true
            for old in sameIdentity where !old.isInvalidated {
                if old.skinType == .default && old.id == newSkin.id {
                    needsAdd = false
                    unchangedDefaults += 1
                    continue
                }
                if old.skinType == .default {
                    logSkin("update (default hash changed)", old, extra: "-> \(describeSkin(newSkin))")
                } else {
                    logSkin("update (replace local with default)", old, extra: "-> \(describeSkin(newSkin))")
                }
                remapSkinPreference(from: old.id, to: newSkin.id)
                markDelete(old)
            }
            if needsAdd {
                toAdd.append(newSkin)
            }
        }
        
        Log.debug("[Skin] syncDefaultSkins: unchanged \(unchangedDefaults), will delete \(toDelete.count), add \(toAdd.count)")
        if toDelete.isEmpty && toAdd.isEmpty {
            return
        }
        
        do {
            try realm.write {
                deleteSkinFilesAndObjects(toDelete, realm: realm)
                addSkinsIfAbsent(toAdd, realm: realm)
            }
        } catch {
            Log.error("[Skin] syncDefaultSkins failed: \(error)")
        }
    }
    
    private static func generateDefaultSkins() -> [Skin] {
        var defaultSkins = [Skin]()
        var usedIds = Set<String>()
        for core in System.allCores {
            let gameType = core.gameType
            guard let controllerSkin = ControllerSkin.standardControllerSkin(for: gameType),
                  let hash = FileHashUtil.truncatedHash(url: controllerSkin.fileURL),
                  let skinId = availableSkinId(hash: hash, usedIds: &usedIds, gameType: gameType) else {
                Log.debug("[Skin] skip default for \(core.name): file missing")
                continue
            }
            if skinId != hash {
                Log.debug("[Skin] default id collision for \(core.name): hash=\(hash) id=\(skinId)")
            }
            let skin = Skin()
            skin.id = skinId
            skin.identifier = controllerSkin.identifier
            skin.name = controllerSkin.name
            skin.fileName = "\(core.name).manicskin"
            skin.gameType = gameType
            skin.skinType = .default
            defaultSkins.append(skin)
        }
        return defaultSkins
    }
    
    /// File hash is the normal PK. Reuse skins (C64/Amiga/…) may hash to the same file; keep a unique id so every platform still gets a default row.
    private static func availableSkinId(hash: String, usedIds: inout Set<String>, gameType: GameType, realm: Realm? = nil) -> String? {
        func isFree(_ id: String) -> Bool {
            !usedIds.contains(id) && realm?.object(ofType: Skin.self, forPrimaryKey: id) == nil
        }
        var candidates = [hash, "\(hash).\(gameType.rawValue)"]
        for n in 1...5 {
            candidates.append("\(hash).\(gameType.rawValue).\(n)")
        }
        for id in candidates {
            if isFree(id) {
                usedIds.insert(id)
                return id
            }
        }
        return nil
    }
    
    private static func describeSkin(_ skin: Skin) -> String {
        if skin.isInvalidated {
            return "<invalidated>"
        }
        return "\(skin.name) file=\(skin.fileName) id=\(skin.id) identifier=\(skin.identifier) gameType=\(skin.gameType.localizedShortName) type=\(skin.skinType)"
    }
    
    private static func logSkin(_ action: String, _ skin: Skin, extra: String = "") {
        let suffix = extra.isEmpty ? "" : " \(extra)"
        Log.debug("[Skin] \(action): \(describeSkin(skin))\(suffix)")
    }
    
    /// `realm.add` with the default `.error` policy raises an ObjC NSException on duplicate PK; Swift `catch` cannot handle it.
    private static func addSkinsIfAbsent(_ skins: [Skin], realm: Realm) {
        var seen = Set<String>()
        for skin in skins {
            guard !skin.id.isEmpty, seen.insert(skin.id).inserted else { continue }
            if realm.object(ofType: Skin.self, forPrimaryKey: skin.id) != nil {
                logSkin("skip add (primary key exists)", skin)
                continue
            }
            realm.add(skin)
            logSkin("added", skin)
        }
    }
    
    private static func deleteSkinFilesAndObjects(_ skins: [Skin], realm: Realm) {
        for skin in skins where !skin.isInvalidated {
            logSkin("deleted", skin)
            if let asset = skin.skinData, !asset.isInvalidated {
                try? FileManager.safeRemoveItem(at: asset.filePath)
                realm.delete(asset)
            }
            realm.delete(skin)
        }
    }
    
    private static func remapSkinPreference(from oldId: String, to newId: String) {
        guard oldId != newId else { return }
        Log.debug("[Skin] remap preference \(oldId) -> \(newId)")
        let apply = {
            Prefference.defalut.replaceValue(kind: .skin, value: oldId, replace: newId)
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
    
    private static func addEmbedSkins() {
        DispatchQueue.global().async {
            Log.debug("[Skin] addEmbedSkins: start")
            let realm = Database.realm
            let fileManager = FileManager.default
            let resourcePath = R.Path.Resource
            let standardDefaultFileNames = Set(System.allCores.map { "\($0.name).manicskin" })
            if let contents = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                let skinNames = contents.filter { $0.hasSuffix(".manicskin") }
                Log.debug("[Skin] addEmbedSkins: found \(skinNames.count) .manicskin files")
                var embedSkins = [Skin]()
                var embedIds = Set<String>()
                var preferenceRemaps: [(String, String)] = []
                var unchangedCount = 0
                var skippedDefaultCount = 0
                for skinName in skinNames {
                    // Standard per-core files are inserted by syncDefaultSkins.
                    if standardDefaultFileNames.contains(skinName) {
                        continue
                    }
                    guard let controllerSkin = ControllerSkin(fileURL: URL(fileURLWithPath: resourcePath.appendingPathComponent(skinName))),
                          let hash = FileHashUtil.truncatedHash(url: controllerSkin.fileURL) else {
                        Log.debug("[Skin] skip embed \(skinName): unreadable")
                        continue
                    }
                    let matchesDefault = realm.objects(Skin.self).where {
                        $0.identifier == controllerSkin.identifier &&
                        $0.gameType == controllerSkin.gameType &&
                        $0.skinType == .default
                    }.count > 0
                    if matchesDefault {
                        skippedDefaultCount += 1
                        continue
                    }
                    
                    var newSkinType = SkinType.buildIn
                    let oldSkins = Array(realm.objects(Skin.self).where {
                        $0.identifier == controllerSkin.identifier &&
                        $0.gameType == controllerSkin.gameType &&
                        $0.skinType != .default
                    })
                    // Same file is already stored (id is the hash, or a collision suffix of that hash).
                    if oldSkins.contains(where: { $0.id == hash || $0.id.hasPrefix("\(hash).") }) {
                        unchangedCount += 1
                        continue
                    }
                    let oldSkinIds = oldSkins.map(\.id)
                    let isUpdate = !oldSkins.isEmpty
                    if isUpdate {
                        newSkinType = oldSkins.first!.skinType
                        for old in oldSkins {
                            logSkin("update (embed file hash changed)", old, extra: "-> file=\(skinName) hash=\(hash)")
                        }
                        try? realm.write {
                            deleteSkinFilesAndObjects(oldSkins, realm: realm)
                        }
                    }
                    
                    guard let skinId = availableSkinId(hash: hash, usedIds: &embedIds, gameType: controllerSkin.gameType, realm: realm) else {
                        Log.debug("[Skin] skip embed \(skinName): no free primary key")
                        continue
                    }
                    
                    let skin = Skin()
                    skin.id = skinId
                    skin.identifier = controllerSkin.identifier
                    skin.name = controllerSkin.name
                    skin.fileName = controllerSkin.fileURL.lastPathComponent
                    skin.gameType = controllerSkin.gameType
                    skin.skinType = newSkinType
                    if newSkinType != .default {
                        skin.skinData = CreamAsset.create(objectID: skin.id, propName: "skinData", url: controllerSkin.fileURL)
                    }
                    embedSkins.append(skin)
                    for oldId in oldSkinIds {
                        preferenceRemaps.append((oldId, skin.id))
                    }
                }
                Log.debug("[Skin] addEmbedSkins: unchanged \(unchangedCount), skipped default identity \(skippedDefaultCount), will add \(embedSkins.count)")
                if !embedSkins.isEmpty {
                    try? realm.write {
                        addSkinsIfAbsent(embedSkins, realm: realm)
                    }
                }
                for remap in preferenceRemaps {
                    remapSkinPreference(from: remap.0, to: remap.1)
                }
            } else {
                Log.debug("[Skin] addEmbedSkins: resource directory unreadable")
            }
            
#if !SIDE_LOAD
            if !UserDefaults.standard.bool(forKey: R.DefaultKey.HasImportedPlayCaseSkin) {
                Log.debug("[Skin] PlayCase: first import")
                if let contents = try? fileManager.contentsOfDirectory(atPath: resourcePath.appendingPathComponent("PlayCase")) {
                    let skinNames = contents.filter { $0.hasSuffix(".playcase") }
                    Log.debug("[Skin] PlayCase: found \(skinNames.count) files")
                    var embedSkins = [Skin]()
                    var playcaseIds = Set<String>()
                    for skinName in skinNames {
                        guard let controllerSkin = ControllerSkin(fileURL: URL(fileURLWithPath: resourcePath.appendingPathComponent("PlayCase").appendingPathComponent(skinName))),
                              let hash = FileHashUtil.truncatedHash(url: controllerSkin.fileURL) else {
                            continue
                        }
                        if let existing = realm.object(ofType: Skin.self, forPrimaryKey: hash),
                           existing.identifier == controllerSkin.identifier {
                            logSkin("unchanged PlayCase", existing)
                            continue
                        }
                        if let skin = realm.objects(Skin.self).first(where: { $0.identifier == controllerSkin.identifier && $0.skinType != .default }) {
                            if skin.skinType != .playcase {
                                logSkin("update (mark PlayCase type)", skin)
                                try? realm.write {
                                    skin.skinType = .playcase
                                }
                            } else {
                                logSkin("unchanged PlayCase", skin)
                            }
                            continue
                        }
                        if realm.objects(Skin.self).where({
                            $0.identifier == controllerSkin.identifier && $0.skinType == .default
                        }).count > 0 {
                            Log.debug("[Skin] skip PlayCase \(controllerSkin.name): identifier belongs to a default skin")
                            continue
                        }
                        guard let skinId = availableSkinId(hash: hash, usedIds: &playcaseIds, gameType: controllerSkin.gameType, realm: realm) else {
                            Log.debug("[Skin] skip PlayCase \(skinName): no free primary key")
                            continue
                        }
                        let skin = Skin()
                        skin.id = skinId
                        skin.identifier = controllerSkin.identifier
                        skin.name = controllerSkin.name
                        skin.fileName = controllerSkin.fileURL.lastPathComponent
                        skin.gameType = controllerSkin.gameType
                        skin.skinType = .playcase
                        skin.skinData = CreamAsset.create(objectID: skin.id, propName: "skinData", url: controllerSkin.fileURL)
                        embedSkins.append(skin)
                    }
                    if !embedSkins.isEmpty {
                        Log.debug("[Skin] PlayCase: will add \(embedSkins.count)")
                        try? realm.write {
                            addSkinsIfAbsent(embedSkins, realm: realm)
                        }
                    } else {
                        Log.debug("[Skin] PlayCase: nothing to add")
                    }
                } else {
                    Log.debug("[Skin] PlayCase: directory missing")
                }
                UserDefaults.standard.set(true, forKey: R.DefaultKey.HasImportedPlayCaseSkin)
            }
#endif
        }
    }
    
    static func fixJ2meJSSave(fileName: String, url: URL) -> URL? {
        let zipUrl = URL(fileURLWithPath: R.Path.Cache.appendingPathComponent("\(fileName)"))
        let tempWorkSpaceUrl = URL(fileURLWithPath: R.Path.Cache.appendingPathComponent(fileName.deletingPathExtension))
        do {
            try FileManager.default.unzipItem(at: url, to: tempWorkSpaceUrl)
        } catch {
            Log.debug("not j2mejs zip save file")
            return nil
        }
        
        let oldRecordStoreJsonPath = tempWorkSpaceUrl.path.appendingPathComponent("metadata/RecordStore_game.0.json")
        let oldRecordStoreSavePath = tempWorkSpaceUrl.path.appendingPathComponent("saves/RecordStore_game.0")
        let newRecordStoreJsonPath = tempWorkSpaceUrl.path.appendingPathComponent("metadata/RecordStore_\(fileName)_game.0.json")
        let newRecordStoreSavePath = tempWorkSpaceUrl.path.appendingPathComponent("saves/RecordStore_\(fileName)_game.0")
        
        if FileManager.default.fileExists(atPath: newRecordStoreJsonPath) {
            //save file correct
            return url
        } else {
            //This is an old save—we should try to upgrade it.
            do {
                //1、gen metadata/RecordStore_xxx.jar_game.0.json and adjust the path order correctly.
                if var json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: oldRecordStoreJsonPath))) as? [String: Any] {
                    json["path"] = "/RecordStore/\(fileName)/game.0"
                    if let jsonData = try? JSONSerialization.data(withJSONObject: json) {
                        try jsonData.write(to: URL(fileURLWithPath: newRecordStoreJsonPath))
                        //2、gen metadata/RecordStore_xxx.jar_game.0.json
                        try FileManager.safeCopyItem(at: URL(fileURLWithPath: oldRecordStoreSavePath), to: URL(fileURLWithPath: newRecordStoreSavePath), shouldReplace: true)
                        //3、remove old save
                        try FileManager.safeRemoveItem(at: zipUrl)
                        //4、gen new save
                        try FileManager.default.zipItem(at: tempWorkSpaceUrl, to: zipUrl, shouldKeepParent: false)
                    }
                }
            } catch {
                Log.debug("update J2meJS saves failed:\(error)")
                return nil
            }
        }
        //4、Clear Cache
        try? FileManager.default.removeItem(at: tempWorkSpaceUrl)
        return zipUrl
    }
}
