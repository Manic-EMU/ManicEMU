//
//  Game.swift
//  ManicEmu
//
//  Created by Max on 2025/1/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift

import IceCream
import Citra
import SmartCodable

enum ThreeDSMode: Int, PersistableEnum {
    case compatibility, performance, quality
}

extension Game: CKRecordConvertible & CKRecordRecoverable {}

class Game: Object, ObjectUpdatable {
    
    ///id 由文件的Hash值决定
    @Persisted(primaryKey: true) var id: String
    ///游戏名称 默认是文件名 不包含扩展名
    @Persisted var name: String
    ///别名 用户自行修改的名称
    @Persisted var aliasName: String? = nil
    ///文件名后缀
    @Persisted var fileExtension: String
    ///游戏类型
    @Persisted var gameType: GameType
    ///封面图片数据 可以用于生产UIImage
    @Persisted var gameCover: CreamAsset?
    ///作弊码列表
    @Persisted var gameCheats: List<GameCheat>
    ///指定竖屏皮肤
    @Persisted var portraitSkin: Skin?
    ///指定横屏皮肤
    @Persisted var landscapeSkin: Skin?
    ///导入时间
    @Persisted var importDate: Date
    ///最后一次游玩时间
    @Persisted var latestPlayDate: Date?
    ///总共游玩时长 ms
    @Persisted var totalPlayDuration: Double = 0
    ///上一次游玩时长 ms
    @Persisted var latestPlayDuration: Double = 0
    ///游戏模拟器存档
    @Persisted var gameSaveStates: List<GameSaveState>
    ///游戏音乐开关
    @Persisted var volume: Bool = true
    ///快进速度
    @Persisted var speed: GameSetting.FastForwardSpeed = .one
    ///分辨率
    @Persisted var resolution: GameSetting.Resolution = .one
    ///交换屏幕
    @Persisted var swapScreen: Bool = false
    ///游戏震感
    @Persisted var haptic: GameSetting.HapticType = .soft
    ///控制器方式
    @Persisted var controllerType: GameSetting.ControllerType = .dPad
    ///屏幕旋转方式
    @Persisted var orientation: GameSetting.OrientationType = .auto
    /// 使用的滤镜名称 nil则不使用滤镜
    @Persisted var filterName: String? = nil
    ///额外数据备用
    @Persisted var extras: Data?
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
    ///jit是否开启
    @Persisted var jit: Bool = false
    ///精确贴图
    @Persisted var accurateShaders: Bool = false
    ///是否搜索过封面
    @Persisted var hasCoverMatch: Bool = false
    ///在线匹配的封面路径
    @Persisted var onlineCoverUrl: String? = nil
    ///机型语言或地区选项
    @Persisted var region: Int = 0
    ///是否允许渲染右眼
    @Persisted var renderRightEye: Bool = false
    ///默认核心 土星0:Beetle 1:Yabause
    @Persisted var defaultCore: Int = 0
    ///GBC调色板
    @Persisted var pallete: GameSetting.Palette = .None
    ///是否强制全屏 不进行同步
    var forceFullSkin: Bool = false

    static let DsHomeMenuPrimaryKey = "Home Menu"
    static let DsiHomeMenuPrimaryKey = "Home Menu (DSi)"
    
    static let DOSHomeMenuPrimaryKey = "Home Menu (DOSBox)"
    
    ///安全模式
    var safeMode = false
    
    ///文件是否存在
    var isRomExtsts: Bool {
        if isAzaharArticBase {
            return true
        }
        return FileManager.default.fileExists(atPath: romUrl.path)
    }
    ///游戏自带存档是否存在
    var isSaveExtsts: Bool {
        FileManager.default.fileExists(atPath: gameSaveUrl.path)
    }
    
    /// 文件名 包含名称和扩展名
    var fileName: String {
        "\(name).\(fileExtension)"
    }
    
    //游戏文件路径
    var romUrl: URL {
        if isMultiFileGame {
            return URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent(fileName.deletingPathExtension).appendingPathComponent(fileName))
        }
        
        var localUrl = URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent(fileName))
        
        if gameType == ._3ds,
           fileExtension.lowercased() == "app",
           let ciaPath = CitraCore.shared().getCIAContentPath(identifier: identifierFor3DS, isSdmc: true) {
            localUrl = URL(fileURLWithPath: ciaPath)
            if !FileManager.default.fileExists(atPath: localUrl.path),
               let urlInNand = CitraCore.shared().getCIAContentPath(identifier: identifierFor3DS, isSdmc: false){
                localUrl = URL(fileURLWithPath: urlInNand)
            }
        } else if isAzaharArticBase {
            return URL(string: "articinio://\(name)")!
        }
        
        if isPSPPBPGame, let gamePath = getExtraString(key: ExtraKey.pspPBPGamePath.rawValue) {
            return URL(fileURLWithPath: Constants.Path.PSPGame.appendingPathComponent(gamePath))
        }
        
        return localUrl
    }
    //游戏自带存档路径
    var gameSaveUrl: URL {
        if gameType == ._3ds {
            //存档 sdmc/Nintendo 3DS/000...0/000...0/title/[game-TID-high]/[game-TID-low]/data/00000001/
            if let titlePath = CitraCore.shared().getTitlePath(identifier: identifierFor3DS, isSdmc: true) {
                return URL(fileURLWithPath: titlePath.appendingPathComponent("data/00000001/"))
            }
        }
        
        if gameType == .psp {
            if let code = self.gameCodeForPSP {
                if let path = try? FileManager.default.contentsOfDirectory(atPath: Constants.Path.PSPSave).first(where: { $0.hasPrefix(code) }) {
                    return URL(fileURLWithPath: Constants.Path.PSPSave.appendingPathComponent(path))
                }
            }
        } else if gameType == .nes || gameType == .fds {
            return URL(fileURLWithPath: Constants.Path.Nestopia.appendingPathComponent("\(name).srm"))
        } else if gameType == .snes {
            if defaultCore == 0 {
                return URL(fileURLWithPath: Constants.Path.bsnes.appendingPathComponent("\(name).srm"))
            } else if defaultCore == 1 {
                return URL(fileURLWithPath: Constants.Path.Snes9x.appendingPathComponent("\(name).srm"))
            }
        } else if isPicodriveCore {
            return URL(fileURLWithPath: Constants.Path.PicoDrive.appendingPathComponent("\(name).srm"))
        } else if isClownMDEmuCore {
            return URL(fileURLWithPath: Constants.Path.ClownMDEmu.appendingPathComponent("\(name).srm"))
        } else if isGearSystemCore {
            return URL(fileURLWithPath: Constants.Path.Gearsystem.appendingPathComponent("\(name).srm"))
        } else if gameType == .n64 {
            return URL(fileURLWithPath: Constants.Path.Mupen64PlushNext.appendingPathComponent("\(name).srm"))
        } else if gameType == .ss {
            if defaultCore == 0 {
                return URL(fileURLWithPath: Constants.Path.BeetleSaturn.appendingPathComponent("\(name).bkr"))
            } else {
                return URL(fileURLWithPath: Constants.Path.Yabause.appendingPathComponent("\(name).srm"))
            }
        } else if gameType == .ds {
            return URL(fileURLWithPath: Constants.Path.DSSavePath.appendingPathComponent("\(name).srm"))
        } else if gameType == .gba {
            return URL(fileURLWithPath: Constants.Path.GBASavePath.appendingPathComponent("\(name).sav"))
        } else if gameType == .gbc {
            return URL(fileURLWithPath: Constants.Path.GBCSavePath.appendingPathComponent("\(name).sav"))
        } else if gameType == .gb {
            return URL(fileURLWithPath: Constants.Path.GBSavePath.appendingPathComponent("\(name).sav"))
        } else if gameType == .vb {
            return URL(fileURLWithPath: Constants.Path.BeetleVB.appendingPathComponent("\(name).srm"))
        } else if gameType == .pm {
            return URL(fileURLWithPath: Constants.Path.PokeMini.appendingPathComponent("\(name).eep"))
        } else if gameType == .ps1 {
            if defaultCore == 0 {
                return URL(fileURLWithPath: Constants.Path.BeetlePSXHW.appendingPathComponent("\(name).srm"))
            } else if defaultCore == 1 {
                return URL(fileURLWithPath: Constants.Path.PCSXReArmed.appendingPathComponent("\(name).srm"))
            }
        } else if gameType == .arcade {
            return URL(fileURLWithPath: Constants.Path.MAME.appendingPathComponent("\(name).srm"))
        } else if gameType == .a2600 {
            return URL(fileURLWithPath: Constants.Path.Stella.appendingPathComponent("\(name).srm"))
        } else if gameType == .a5200 {
            return URL(fileURLWithPath: Constants.Path.Atari800.appendingPathComponent("\(name).srm"))
        } else if gameType == .a7800 {
            return URL(fileURLWithPath: Constants.Path.ProSystem.appendingPathComponent("\(name).srm"))
        } else if gameType == .jaguar {
            let srmPath = Constants.Path.Holani.appendingPathComponent("\(name).srm")
            if FileManager.default.fileExists(atPath: srmPath) {
                return URL(fileURLWithPath: srmPath)
            } else {
                return URL(fileURLWithPath: Constants.Path.Holani.appendingPathComponent("\(name).cdrom.srm"))
            }
        } else if gameType == .lynx {
            return URL(fileURLWithPath: Constants.Path.Holani.appendingPathComponent("\(name).srm"))
        } else if gameType == .j2me {
            return URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent("\(name).\(defaultCore == 0 ? LibretroCore.Cores.J2meJS.name : LibretroCore.Cores.freej2me.name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")"))
        } else if gameType == .dos {
            if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: Constants.Path.DOSBoxPure), includingPropertiesForKeys: [.isDirectoryKey]) {
                for case let fileURL as URL in enumerator {
                    let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    guard !isDirectory else { continue }
                    if fileURL.lastPathComponent == "\(name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")" {
                        return fileURL
                    }
                }
            }
            return URL(fileURLWithPath: Constants.Path.DOSBoxPure.appendingPathComponent("\(name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")"))
        }
        
        let localUrl = URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent("\(name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")"))
        return localUrl
    }
    
    var identifierFor3DS: UInt64 {
        return UInt64(getExtraInt(key: ExtraKey.identifier.rawValue) ?? 0)
    }

    var rommRomId: Int? {
        get { getExtraInt(key: ExtraKey.rommRomId.rawValue) }
        set { updateExtra(key: ExtraKey.rommRomId.rawValue, value: newValue) }
    }

    var rommServiceId: String? {
        get { getExtraString(key: ExtraKey.rommServiceId.rawValue) }
        set { updateExtra(key: ExtraKey.rommServiceId.rawValue, value: newValue) }
    }
    
    var gameCodeForPSP: String? {
        if gameType == .psp {
           return getExtraString(key: ExtraKey.PSPGameCode.rawValue)
        } else {
            return nil
        }
    }
    
    var translatedName: String? {
        if let extras,
           let extraInfos = try? extras.jsonObject() as? [String: Any],
           let name = extraInfos["translatedName"] as? String {
            return name
        } else {
            return nil
        }
    }
    
    func setExtras(_ extras: [AnyHashable: Any]) {
        Game.change { realm in
            self.extras = extras.jsonData()
        }
    }
    
    var libretroShaderPath: String? {
        if let filterName {
            return Constants.Path.Shaders.appendingPathComponent(filterName)
        }
        return nil
    }
    
    func isBIOSMissing(required: Bool = true) -> Bool {
        let requireBIOS: [BIOSItem]
        if gameType == .mcd {
            if defaultCore == 2 {
                //ClownMDEmu核心不需要bios
                return false
            }
            requireBIOS = Constants.BIOS.MegaCDBios.filter({ required ? $0.required : true })
        } else if gameType == .ss {
            if defaultCore == 0 {
                requireBIOS = Array(Constants.BIOS.SaturnBios[1...2]).filter({ required ? $0.required : true })
            } else {
                requireBIOS = [Constants.BIOS.SaturnBios[0]].filter({ required ? $0.required : true })
            }
        } else if gameType == .ds {
            requireBIOS = Constants.BIOS.DSBios.filter({ required ? $0.required : true })
        } else if gameType == .fds {
            requireBIOS = Constants.BIOS.FDSBios
        } else {
            return false
        }
        let fileManager = FileManager.default
        for bios in requireBIOS {
            var biosInLib = Constants.Path.System.appendingPathComponent(bios.fileName)
            if gameType == .dc {
                biosInLib = Constants.Path.Flycast.appendingPathComponent("dc/\(bios.fileName)")
            }
            let biosInDoc = Constants.Path.BIOS.appendingPathComponent(bios.fileName)
            if fileManager.fileExists(atPath: biosInLib) {
                continue
            } else if fileManager.fileExists(atPath: biosInDoc) {
                try? FileManager.safeCopyItem(at: URL(fileURLWithPath: biosInDoc), to: URL(fileURLWithPath: biosInLib))
                continue
            } else {
                return true
            }
        }
        return false
    }
    
    var ps1ImportedBios: [BIOSItem] {
        let ps1Bios = Constants.BIOS.PS1Bios
        let fileManager = FileManager.default
        var result = [BIOSItem]()
        for bios in ps1Bios {
            let biosInLib = Constants.Path.System.appendingPathComponent(bios.fileName)
            let biosInDoc = Constants.Path.BIOS.appendingPathComponent(bios.fileName)
            if fileManager.fileExists(atPath: biosInLib) {
                result.append(bios)
            } else if fileManager.fileExists(atPath: biosInDoc) {
                try? FileManager.safeCopyItem(at: URL(fileURLWithPath: biosInDoc), to: URL(fileURLWithPath: biosInLib))
                result.append(bios)
            }
        }
        return result
    }
    
    var ps1OverrideBios: String {
        if let biosConfig = getExtraString(key: ExtraKey.biosName.rawValue) {
            if biosConfig == "ps1_rom.bin" {
                return "ps1_rom"
            } else if biosConfig == "PSXONPSP660.bin" {
                return "psxonpsp"
            } else {
                return "disabled"
            }
        }
        return "openbios"
    }
    
    var libretroCorePath: String? {
        if gameType == .psp {
            return Bundle.main.path(forResource: "ppsspp.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .nes || gameType == .fds  {
            return Bundle.main.path(forResource: "nestopia.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .snes {
            if defaultCore == 0 {
                if getExtraBool(key: ExtraKey.snesVRAM.rawValue) ?? false {
                    return Bundle.main.path(forResource: "bsnes.libretro", ofType: "framework", inDirectory: "Frameworks")
                } else {
                    return Bundle.main.path(forResource: "bsnes-jg.libretro", ofType: "framework", inDirectory: "Frameworks")
                }
            } else if defaultCore == 1 {
                return Bundle.main.path(forResource: "snes9x.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if isPicodriveCore {
            return Bundle.main.path(forResource: "picodrive.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if isClownMDEmuCore {
            return Bundle.main.path(forResource: "clownmdemu.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if isGearSystemCore {
            return Bundle.main.path(forResource: "gearsystem.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .ss {
            if self.fileExtension.lowercased() == "iso" || defaultCore == 1 {
                return Bundle.main.path(forResource: "yabause.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else if defaultCore == 0 {
                return Bundle.main.path(forResource: "mednafen.saturn.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == .n64 {
            if #available(iOS 26.0, *), LibretroCore.jitAvailable(), jit {
                return Bundle.main.path(forResource: "mupen64plus.next.jit.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else {
                return Bundle.main.path(forResource: "mupen64plus.next.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == .vb {
            return Bundle.main.path(forResource: "mednafen.vb.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .pm {
            return Bundle.main.path(forResource: "pokemini.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .ps1 {
            if defaultCore == 0 {
                return Bundle.main.path(forResource: "mednafen.psx.hw.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else if defaultCore == 1 {
                return Bundle.main.path(forResource: "pcsx.rearmed.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == .gb || gameType == .gbc {
            if defaultCore == 0 {
                return Bundle.main.path(forResource: "gambatte.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else if defaultCore == 1 {
                return Bundle.main.path(forResource: "mgba.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else if defaultCore == 2 {
                return Bundle.main.path(forResource: "vbam.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == .gba {
            if defaultCore == 0 {
                return Bundle.main.path(forResource: "mgba.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else {
                return Bundle.main.path(forResource: "vbam.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == .dc {
            if LibretroCore.jitAvailable(), jit {
                return Bundle.main.path(forResource: "flycast.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else {
                if defaultCore == 0 {
                    return Bundle.main.path(forResource: "flycast-jitless.libretro", ofType: "framework", inDirectory: "Frameworks")
                } else if defaultCore == 1 {
                    return Bundle.main.path(forResource: "flycast-jitless-wince.libretro", ofType: "framework", inDirectory: "Frameworks")
                } else if defaultCore == 2 {
                    return Bundle.main.path(forResource: "flycast-jitless-fuse.libretro", ofType: "framework", inDirectory: "Frameworks")
                }
            }
        } else if gameType == .ds {
            if defaultCore == 0 {
                return Bundle.main.path(forResource: "melondsds.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else {
                return Bundle.main.path(forResource: "desmume.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == .doom {
            return Bundle.main.path(forResource: "prboom.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .arcade {
            if defaultCore == 0 {
                return Bundle.main.path(forResource: "mame.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else {
                return Bundle.main.path(forResource: "fbneo.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == ._3ds, defaultCore == 1 {
            return Bundle.main.path(forResource: "azahar.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .a2600 {
            return Bundle.main.path(forResource: "stella.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .a5200 {
            return Bundle.main.path(forResource: "atari800.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .a7800 {
            return Bundle.main.path(forResource: "prosystem.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .jaguar {
            return Bundle.main.path(forResource: "virtualjaguar.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .lynx {
            return Bundle.main.path(forResource: "holani.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .dos {
            return Bundle.main.path(forResource: "dosbox.pure.libretro", ofType: "framework", inDirectory: "Frameworks")
        }
        return nil
    }
    
    var isPicodriveCore: Bool {
        if (gameType == ._32x || gameType == .mcd) && defaultCore == 0 {
            return true
        }
        
        if (gameType == .md || gameType == .sg1000 || gameType == .gg || gameType == .ms) && defaultCore == 1 {
            return true
        }
        return false
    }
    
    var isGearSystemCore: Bool {
        if (gameType == .sg1000 || gameType == .gg || gameType == .ms) && defaultCore == 0 {
            return true
        }
        return false
    }
    
    var isClownMDEmuCore: Bool {
        if (gameType == .md && defaultCore == 0) || (gameType == .mcd && defaultCore == 2) {
            return true
        }
        return false
    }
    
    var hasTransferPak: Bool {
        guard gameType == .n64 else { return false }
        let romPath = romUrl.path
        if FileManager.default.fileExists(atPath: romPath + ".gb"), FileManager.default.fileExists(atPath: romPath + ".sav") {
            return true
        }
        return false
    }
    
    var isNDSHomeMenuGame: Bool {
        guard gameType == .ds else { return false }
        if isDSHomeMenuGame || isDSiHomeMenuGame {
            return true
        }
        return false
    }
    
    var isDSHomeMenuGame: Bool {
        guard gameType == .ds else { return false }
        if id == Game.DsHomeMenuPrimaryKey {
            return true
        }
        return false
    }
    
    var isDSiHomeMenuGame: Bool {
        guard gameType == .ds else { return false }
        if id == Game.DsiHomeMenuPrimaryKey {
            return true
        }
        return false
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
    
    var hasGBASlotInsert: Bool {
        guard gameType == .ds else { return false }
        if FileManager.default.fileExists(atPath: romUrl.path + ".slot.gba") {
            return true
        }
        return false
    }
    
    var isN64ParaLLEl: Bool {
        if LibretroCore.jitAvailable(), jit {
            return false
        }
        return gameType == .n64 && !(getExtraBool(key: ExtraKey.rdpPlugin.rawValue) ?? true)
    }
    
    var is3DSHomeMenuGame: Bool {
        guard gameType == ._3ds else { return false }
        return Constants.Numbers.ThreeDSHomeMenuIdentifiers.contains(where: { $0 == identifierFor3DS })
    }
    
    var supportRetroAchievements: Bool {
        if gameType == ._3ds || gameType == .doom || gameType == .a5200 || gameType == .dos {
            return false
        }
        if gameType == .arcade, defaultCore == 0 {
            return false
        }
        if isJGenesisCore {
            return false
        }
        if isJ2MECore {
            return false
        }
        return true
    }
    
    var supportSwapDisc: Bool {
        if fileExtension.lowercased() == "m3u" || fileExtension.lowercased() == "pbp" {
            return true
        } else if gameType == .dos, let diskCount = diskInfo?.diskCount, diskCount > 0 {
            return true
        }
        return false
    }
    
    func getAchievementProgress(id: Int) -> AchievementProgress? {
        if let jsonString = getExtraString(key: ExtraKey.achievementsProgress.rawValue) {
            if let progresses = [AchievementProgress].deserialize(from: jsonString) {
                return progresses.first(where: { $0.id == id })
            }
        }
        return nil
    }
    
    func updateAchievementProgress(_ progress: AchievementProgress) {
        if let jsonString = getExtraString(key: ExtraKey.achievementsProgress.rawValue) {
            if var progresses = [AchievementProgress].deserialize(from: jsonString) {
                progresses.removeAll(where: { $0.id == progress.id })
                progresses.append(progress)
                if let jsonString = progresses.toJSONString() {
                    updateExtra(key: ExtraKey.achievementsProgress.rawValue, value: jsonString)
                }
            }
        }
    }
    
    func removeAchievementProgress(id: Int) {
        if let jsonString = getExtraString(key: ExtraKey.achievementsProgress.rawValue) {
            if var progresses = [AchievementProgress].deserialize(from: jsonString) {
                var isRemoved = false
                progresses.removeAll(where: {
                    if $0.id == id {
                        isRemoved = true
                        return true
                    } else {
                        return false
                    }
                })
                if isRemoved, let jsonString = progresses.toJSONString() {
                    updateExtra(key: ExtraKey.achievementsProgress.rawValue, value: jsonString)
                }
            }
        }
    }
    
    var isMultiFileGame: Bool {
        return fileExtension.lowercased() == "m3u" || fileExtension.lowercased() == "cue" || fileExtension.lowercased() == "gdi" 
    }
    
    var enableAchievements: Bool {
        get {
            getExtraBool(key: ExtraKey.enableAchievements.rawValue) ?? Settings.defalut.getExtraBool(key: ExtraKey.globalAchievements.rawValue) ?? false
        }
        set {
            updateExtra(key: ExtraKey.enableAchievements.rawValue, value: newValue)
        }
        
    }
    
    var enableHarcore: Bool {
        get {
            enableAchievements ? (getExtraBool(key: ExtraKey.achievementsHardcore.rawValue) ?? Settings.defalut.getExtraBool(key: ExtraKey.globalHardcore.rawValue) ?? false) : false
        }
        set {
            updateExtra(key: ExtraKey.achievementsHardcore.rawValue, value: newValue)
        }
    }
    
    var manualsPath: String? {
        if let fileName = getExtraString(key: ExtraKey.manualFileName.rawValue) {
            return Constants.Path.GameplayManuals.appendingPathComponent(fileName)
        }
        return nil
    }
    
    var isManualsExists: Bool {
        if let manualsPath {
            return FileManager.default.fileExists(atPath: manualsPath)
        }
        return false
    }
    
    struct NESPalette {
        enum NESPaletteType {
            case nestopia, buildIn, custom
        }
        
        var name: String
        var type: NESPaletteType
    }
    
    lazy var nesPalettes: [NESPalette] = {
        guard gameType == .nes || gameType == .fds else { return [] }
        
        let nestopias = ["cxa2025as", "cxa2025as_jp", "royaltea", "consumer", "canonical", "alternative", "rgb", "pal", "composite-direct-fbx", "pvm-style-d93-fbx", "ntsc-hardware-fbx", "nes-classic-fbx-fs", "restored-wii-vc", "wii-vc", "raw"]
        var results: [NESPalette] = []
        results.append(contentsOf: nestopias.map({ NESPalette(name: $0, type: .nestopia) }))
        
        if let buildIns = try? FileManager.default.contentsOfDirectory(atPath: Constants.Path.NESPalettes) {
            results.append(contentsOf: buildIns.sorted().compactMap({
                if $0.pathExtension.lowercased() == "pal" {
                    return NESPalette(name: $0.deletingPathExtension, type: .buildIn)
                } else {
                    return nil
                }
            }))
        }
        
        if let customs = try? FileManager.default.contentsOfDirectory(atPath: Constants.Path.CustomPalettes.appendingPathComponent(gameType.localizedShortName)) {
            results.append(contentsOf: customs.sorted().compactMap({
                if $0.pathExtension.lowercased() == "pal" {
                    return NESPalette(name: $0.deletingPathExtension, type: .custom)
                } else {
                    return nil
                }
            }))
        }
        
        return results
    }()
    
    static var defaultNesPalette: NESPalette {
        NESPalette(name: "cxa2025as", type: .nestopia)
    }
    
    var nextNesPalette: NESPalette {
        guard gameType == .nes || gameType == .fds else { return Self.defaultNesPalette }
        
        if let nesPalette = getExtraString(key: ExtraKey.nesPalette.rawValue) {
            if let index = nesPalettes.firstIndex(where: { $0.name == nesPalette }) {
                if index < nesPalettes.count - 1 {
                    return nesPalettes[index.advanced(by: 1)]
                }
            }
        } else {
            return nesPalettes[1]
        }
        return Self.defaultNesPalette
    }
    
    var currentNesPalette: NESPalette {
        guard gameType == .nes || gameType == .fds else { return Self.defaultNesPalette }
        if let nesPalette = getExtraString(key: ExtraKey.nesPalette.rawValue) {
            return nesPalettes.first(where: { $0.name == nesPalette }) ?? Self.defaultNesPalette
        }
        return Self.defaultNesPalette
    }
    
    var isLibretroType: Bool {
        if isCitra3DS || isJGenesisCore || isJ2MECore {
            return false
        }
        return true
    }
    
    var isCitra3DS: Bool {
        return gameType == ._3ds && defaultCore == 0
    }
    
    var isAzahar3DS: Bool {
        return gameType == ._3ds && defaultCore == 1
    }
    
    var isJGenesisCore: Bool {
        return ((gameType == ._32x || gameType == .mcd) && defaultCore == 1)
    }

    var isJ2MECore: Bool {
        return gameType == .j2me
    }

    var coreNameForMultiSupport: String {
        if gameType.supportCores.count > 0, defaultCore < gameType.supportCores.count {
            return "(\(gameType.supportCores[defaultCore]))"
        }
        return ""
    }
    
    var isAtari: Bool {
        return gameType == .a2600 || gameType == .a5200 || gameType == .a7800 || gameType == .jaguar || gameType == .lynx
    }
    
    func processNDSGameSave(runInBackground: Bool = true) {
        guard gameType == .ds, isSaveExtsts else { return }
        //处理DS的存档
        let coreIndex = defaultCore
        let saveUrl = gameSaveUrl
        
        func processSave() {
            //melonDS的srm存档和Desmume的dsv存档不互通，这里需要先进行转换
            if coreIndex == 0, NDSSaveConverter.checkSaveType(fileURL: saveUrl) == .dsv {
                NDSSaveConverter.dsvToSav(saveUrl: saveUrl)
            } else if coreIndex == 1, NDSSaveConverter.checkSaveType(fileURL: saveUrl) == .sav {
                NDSSaveConverter.savToDsv(saveUrl: saveUrl)
            }
        }
        
        if runInBackground {
            DispatchQueue.global().async {
                processSave()
            }
        } else {
            processSave()
        }
    }
    
    var screenScaling: GameSetting.ScreenScaling {
        if let scalingInt = getExtraInt(key: ExtraKey.screenScaling.rawValue),
            let scaling = GameSetting.ScreenScaling(rawValue: scalingInt) {
            return scaling
        }
        return .stretch
    }
    
    var j2meScreenSize: J2MESize {
        if let sizeString = getExtraString(key: ExtraKey.j2meScreenSize.rawValue),
           let size = J2MESize(stringValue: sizeString) {
            return size
        }
        return J2MESize.defaultSize
    }
    
    var j2meScreenRotation: Bool {
        getExtraBool(key: ExtraKey.j2meScreenRotate.rawValue) ?? false
    }
    
    func deleteJ2meSaves() {
        let j2mejsUrl = URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent("\(name).\(LibretroCore.Cores.J2meJS.name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")"))
        try? FileManager.safeRemoveItem(at: j2mejsUrl)
        SyncManager.delete(localFilePath: j2mejsUrl.path)
        
        let freej2meUrl = URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent("\(name).\(LibretroCore.Cores.freej2me.name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")"))
        try? FileManager.safeRemoveItem(at: freej2meUrl)
        SyncManager.delete(localFilePath: freej2meUrl.path)
    }
    
    func getStoreCoreConfigs() -> [String: String]? {
        guard isLibretroType else { return nil }
        if let coreConfigsString = getExtraString(key: ExtraKey.coreConfigs.rawValue),
            let jsonData = coreConfigsString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] {
            return json
        }
        return nil
    }
    
    func getStoreCoreConfigsString(enableJIT: Bool = false) -> String? {
        if var coreConfigs = getStoreCoreConfigs() {
            coreConfigs["dosbox_pure_cpu_core"] = "normal"
            var result = ""
            for (key, value) in coreConfigs {
                if key == "dosbox_pure_cpu_core" {
                    result += "\(key) = \"\(enableJIT ? "dynamic" : "normal")\"\n"
                } else {
                    result += "\(key) = \"\(value)\"\n"
                }
            }
            return result
        }
        return nil
    }
    
    var diskInfo: LibretroDisk? { LibretroCore.sharedInstance().getDiskInfo() }
    
    func deleteDosFiles() {
        var fileUrls = [URL]()
        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: Constants.Path.DOSBoxPure), includingPropertiesForKeys: [.isDirectoryKey]) {
            for case let fileURL as URL in enumerator {
                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard !isDirectory else { continue }
                if fileURL.lastPathComponent.contains(name) {
                    fileUrls.append(fileURL)
                }
            }
        }
        
        fileUrls.forEach({
            try? FileManager.safeRemoveItem(at: $0)
            SyncManager.delete(localFilePath: $0.path)
        })
    }
    
    var isDOSHomeMenuGame: Bool {
        guard gameType == .dos else { return false }
        if id == Game.DOSHomeMenuPrimaryKey {
            return true
        }
        return false
    }
    
    var isAzaharArticBase: Bool {
        if gameType == ._3ds, id == Constants.Strings.AzaharArticBaseGameID {
            return true
        }
        return false
    }
    
    var isArticBaseHomeMenu: Bool {
        guard gameType == ._3ds, defaultCore == 1 else { return false }
        return getExtraBool(key: ExtraKey.isArticBaseHomeMenu.rawValue) ?? false
    }
    
    var isPSPPBPGame: Bool {
        guard gameType == .psp else { return false }
        return getExtraBool(key: ExtraKey.isPSPPBPGame.rawValue) ?? false
    }
    
    var supportChangeCategory: Bool {
        if gameType == .gb || gameType == .dos {
            return true
        }
        return false
    }
    
    var supportCategories: [GameType] {
        if gameType == .gb {
            return [.gb, .chm]
        } else if gameType == .dos {
            return [.dos, .win95, .win98]
        }
        return []
    }
    
    func updateCategory(gameType: GameType) {
        guard supportChangeCategory else { return }
        if gameType == .gb || gameType == .dos {
            updateExtra(key: ExtraKey.gameTypeCategory.rawValue, value: 0)
        } else if gameType == .chm || gameType == .win95 {
            updateExtra(key: ExtraKey.gameTypeCategory.rawValue, value: 1)
        } else if gameType == .win98 {
            updateExtra(key: ExtraKey.gameTypeCategory.rawValue, value: 2)
        }
    }
    
    func changeDefaultCore(coreIndex: Int) {
        if defaultCore != coreIndex {
            let oldSaveUrl = gameSaveUrl
            Game.change { realm in
                defaultCore = coreIndex
            }
            //SS J2me的存档不切换
            let newSaveUrl = gameSaveUrl
            if gameType != .ss, gameType != .j2me, FileManager.default.fileExists(atPath: oldSaveUrl.path) {
                try? FileManager.safeMoveItem(at: oldSaveUrl, to: newSaveUrl)
            }
            //处理DS的存档
            processNDSGameSave()
            Log.debug("[Game] using \(gameType.supportCores[coreIndex])(\(coreIndex)) core for \(gameType.localizedShortName)")
        }
    }
    
}


struct AchievementProgress: SmartCodable {
    var id: Int = 0
    var measuredProgress: String = ""
    var measuredPercent: CGFloat = 0
}
