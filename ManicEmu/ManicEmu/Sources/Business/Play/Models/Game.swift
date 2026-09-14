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
import Kingfisher

enum ThreeDSMode: Int, PersistableEnum {
    case compatibility, performance, quality
}

extension Game: CKRecordConvertible & CKRecordRecoverable {
    var isSyncable: Bool { !isAzaharArticBase }
}

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
    
    @Persisted var icon: CreamAsset?
    var iconImage: UIImage? {
        guard let imageData = icon?.storedData() else { return nil }
        return UIImage(data: imageData)
    }
    
    @Persisted var banner: CreamAsset?
    var bannerImage: UIImage? {
        guard let imageData = banner?.storedData() else { return nil }
        return UIImage(data: imageData)
        
    }
    
    ///作弊码列表
    @Persisted var gameCheats: List<GameCheat>
    ///指定竖屏皮肤
    @available(*, deprecated)
    @Persisted var portraitSkin: Skin?
    ///指定横屏皮肤
    @available(*, deprecated)
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
    @Persisted var speed: GameOption.FastForwardSpeed = .one
    ///分辨率
    @Persisted var resolution: GameOption.Resolution = .one
    ///交换屏幕
    @Persisted var swapScreen: Bool = false
    ///游戏震感
    @Persisted var haptic: GameOption.HapticType = .soft
    ///控制器方式
    @Persisted var controllerType: GameOption.ControllerType = .dPad
    ///屏幕旋转方式
    @Persisted var orientation: GameOption.OrientationType = .auto
    /// 使用的滤镜名称 nil则不使用滤镜
    @available(*, deprecated)
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
    ///默认核心 每种游戏和核心情况不一，请参考libretroCorePath
    @Persisted var defaultCore: Int = 0
    ///GBC调色板
    @Persisted var pallete: GameOption.Palette = .None
    ///是否强制全屏 不进行同步
    var forceFullSkin: Bool = false
    
    static let DsHomeMenuPrimaryKey = "Home Menu"
    static let DsiHomeMenuPrimaryKey = "Home Menu (DSi)"
    static let DOSHomeMenuPrimaryKey = "Home Menu (DOSBox)"
    static let SymbianHomePrimary = "Home Menu (Symbian)"
    
    ///安全模式
    var safeMode = false
    
    ///文件是否存在
    var isRomExtsts: Bool {
        if isAzaharArticBase || gameType == .symbian {
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
            return URL(fileURLWithPath: R.Path.Data.appendingPathComponent(fileName.deletingPathExtension).appendingPathComponent(fileName))
        }
        
        var localUrl = URL(fileURLWithPath: R.Path.Data.appendingPathComponent(fileName))
        
        if gameType == ._3ds,
           fileExtension.lowercased() == "app",
           let ciaPath = CitraCore.shared().getCIAContentPath(identifier: identifierFor3DS, isSdmc: true) {
            localUrl = URL(fileURLWithPath: ciaPath)
            if !FileManager.default.fileExists(atPath: localUrl.path),
               let urlInNand = CitraCore.shared().getCIAContentPath(identifier: identifierFor3DS, isSdmc: false){
                localUrl = URL(fileURLWithPath: urlInNand)
            }
            return localUrl
        } else if isAzaharArticBase {
            return URL(string: "articinio://\(name)")!
        } else if isPSPPBPGame, let gamePath = getExtraString(key: ExtraKey.pspPBPGamePath.rawValue) {
            return URL(fileURLWithPath: R.Path.PSPGame.appendingPathComponent(gamePath))
        } else if gameType == .symbian {
            if isSymbianHomeMenu, let app = symbianSystemApp {
                return URL(string: "uid://\(app.uid)")!
            } else {
                return URL(string: "uid://\(id)")!
            }
        } else if gameType == .ps1, fileExtension.lowercased() == "bin" {
            // Beetle/PCSX cannot load a raw .bin; prefer the sibling .cue when it exists.
            let cueUrl = localUrl.deletingPathExtension().appendingPathExtension("cue")
            if FileManager.default.fileExists(atPath: cueUrl.path) {
                return cueUrl
            }
        }
        
        return localUrl
    }
    
    /// PS1 cores require a .cue next to a raw .bin. Writes a single-track sheet if missing.
    func ensurePS1BinCueSheet() {
        guard gameType == .ps1, fileExtension.lowercased() == "bin" else { return }
        let binUrl = URL(fileURLWithPath: R.Path.Data.appendingPathComponent(fileName))
        guard FileManager.default.fileExists(atPath: binUrl.path) else { return }
        let cueUrl = binUrl.deletingPathExtension().appendingPathExtension("cue")
        guard !FileManager.default.fileExists(atPath: cueUrl.path) else { return }
        
        let trackMode: String
        if let size = try? FileManager.default.attributesOfItem(atPath: binUrl.path)[.size] as? UInt64,
           size % 2352 != 0,
           size % 2048 == 0 {
            trackMode = "MODE1/2048"
        } else {
            trackMode = "MODE2/2352"
        }
        let cueSheet = """
        FILE "\(binUrl.lastPathComponent)" BINARY
          TRACK 01 \(trackMode)
            INDEX 01 00:00:00
        """
        try? cueSheet.writeWithCompletePath(to: cueUrl)
        SyncManager.upload(localFilePath: cueUrl.path)
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
                if let path = try? FileManager.default.contentsOfDirectory(atPath: R.Path.PSPSave).first(where: { $0.hasPrefix(code) }) {
                    return URL(fileURLWithPath: R.Path.PSPSave.appendingPathComponent(path))
                }
            }
        } else if gameType == .nes {
            return URL(fileURLWithPath: R.Path.Nestopia.appendingPathComponent("\(name).srm"))
        } else if gameType == .fds {
            return URL(fileURLWithPath: R.Path.Nestopia.appendingPathComponent("\(name).sav"))
        } else if gameType == .snes {
            if defaultCore == 0 {
                return URL(fileURLWithPath: R.Path.bsnes.appendingPathComponent("\(name).srm"))
            } else if defaultCore == 1 {
                return URL(fileURLWithPath: R.Path.Snes9x.appendingPathComponent("\(name).srm"))
            }
        } else if isPicodriveCore {
            return URL(fileURLWithPath: R.Path.PicoDrive.appendingPathComponent("\(name).srm"))
        } else if isClownMDEmuCore {
            return URL(fileURLWithPath: R.Path.ClownMDEmu.appendingPathComponent("\(name).srm"))
        } else if isGearSystemCore {
            return URL(fileURLWithPath: R.Path.Gearsystem.appendingPathComponent("\(name).srm"))
        } else if gameType == .n64 {
            return URL(fileURLWithPath: R.Path.Mupen64PlushNext.appendingPathComponent("\(name).srm"))
        } else if gameType == .ss {
            if defaultCore == 0 {
                return URL(fileURLWithPath: R.Path.BeetleSaturn.appendingPathComponent("\(name).bkr"))
            } else {
                return URL(fileURLWithPath: R.Path.Yabause.appendingPathComponent("\(name).srm"))
            }
        } else if gameType == .ds {
            return URL(fileURLWithPath: R.Path.DSSavePath.appendingPathComponent("\(name).srm"))
        } else if gameType == .gba {
            return URL(fileURLWithPath: R.Path.GBASavePath.appendingPathComponent("\(name).sav"))
        } else if gameType == .gbc {
            return URL(fileURLWithPath: R.Path.GBCSavePath.appendingPathComponent("\(name).sav"))
        } else if gameType == .gb {
            return URL(fileURLWithPath: R.Path.GBSavePath.appendingPathComponent("\(name).sav"))
        } else if gameType == .vb {
            return URL(fileURLWithPath: R.Path.BeetleVB.appendingPathComponent("\(name).srm"))
        } else if gameType == .pm {
            return URL(fileURLWithPath: R.Path.PokeMini.appendingPathComponent("\(name).eep"))
        } else if gameType == .ps1 {
            if defaultCore == 0 {
                return URL(fileURLWithPath: R.Path.BeetlePSXHW.appendingPathComponent("\(name).srm"))
            } else if defaultCore == 1 {
                return URL(fileURLWithPath: R.Path.PCSXReArmed.appendingPathComponent("\(name).srm"))
            }
        } else if gameType == .arcade {
            return URL(fileURLWithPath: R.Path.MAME.appendingPathComponent("\(name).srm"))
        } else if gameType == .a2600 {
            return URL(fileURLWithPath: R.Path.Stella.appendingPathComponent("\(name).srm"))
        } else if gameType == .a5200 {
            return URL(fileURLWithPath: R.Path.Atari800.appendingPathComponent("\(name).srm"))
        } else if gameType == .a7800 {
            return URL(fileURLWithPath: R.Path.ProSystem.appendingPathComponent("\(name).srm"))
        } else if gameType == .jaguar {
            let srmPath = R.Path.Holani.appendingPathComponent("\(name).srm")
            if FileManager.default.fileExists(atPath: srmPath) {
                return URL(fileURLWithPath: srmPath)
            } else {
                return URL(fileURLWithPath: R.Path.Holani.appendingPathComponent("\(name).cdrom.srm"))
            }
        } else if gameType == .lynx {
            return URL(fileURLWithPath: R.Path.Holani.appendingPathComponent("\(name).srm"))
        } else if gameType == .pce {
            return URL(fileURLWithPath: R.Path.BeetlePCE.appendingPathComponent("\(name).srm"))
        } else if gameType == .ngp {
            return URL(fileURLWithPath: R.Path.BeetleNeoPop.appendingPathComponent("\(name).flash"))
        } else if gameType == .wsc {
            return URL(fileURLWithPath: R.Path.BeetleWonderSwan.appendingPathComponent("\(name).srm"))
        } else if gameType == .c64 {
            return URL(fileURLWithPath: R.Path.VICEx64sc.appendingPathComponent("\(name).nvr"))
        } else if gameType == .amiga {
            return URL(fileURLWithPath: R.Path.PUAE.appendingPathComponent("\(name).nvr"))
        } else if gameType == .j2me {
            return URL(fileURLWithPath: R.Path.Data.appendingPathComponent("\(name).\(defaultCore == 0 ? EmulationCore.J2meJS.name : EmulationCore.freej2me.name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")"))
        } else if gameType == .dos {
            if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: R.Path.DOSBoxPure), includingPropertiesForKeys: [.isDirectoryKey]) {
                for case let fileURL as URL in enumerator {
                    let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    guard !isDirectory else { continue }
                    if fileURL.lastPathComponent == "\(name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")" {
                        return fileURL
                    }
                }
            }
            return URL(fileURLWithPath: R.Path.DOSBoxPure.appendingPathComponent("\(EmulationCore.DOSBoxPure.name)/\(name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")"))
        }
        
        let localUrl = URL(fileURLWithPath: R.Path.Data.appendingPathComponent("\(name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")"))
        return localUrl
    }
    
    var identifierFor3DS: UInt64 {
        return UInt64(getExtraInt(key: ExtraKey.identifier.rawValue) ?? 0)
    }
    
    var gameCodeForPSP: String? {
        if gameType == .psp {
            return getExtraString(key: ExtraKey.PSPGameCode.rawValue)
        } else {
            return nil
        }
    }
    
    var gameIDForDolphin: String? {
        guard isDolphinCore else { return nil }
        let value = getExtraString(key: ExtraKey.dolphinGameID.rawValue)
        return (value?.isEmpty == false) ? value : nil
    }
    
    /// Parse the ROM header into extras when the Game ID is missing.
    @discardableResult
    func ensureDolphinGameID() -> String? {
        if let gameIDForDolphin { return gameIDForDolphin }
        guard isDolphinCore else { return nil }
        let id: String?
        if fileExtension.lowercased() == "elf" {
            id = DolphinGameID.makeElfOrDolID(fileName: fileName)
        } else {
            id = DolphinGameID.read(from: romUrl)
        }
        guard let id else { return nil }
        updateExtra(key: ExtraKey.dolphinGameID.rawValue, value: id)
        return id
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
    
    func isBIOSMissing(required: Bool = true) -> Bool {
        let requireBIOS: [BIOSItem]
        if gameType == .mcd {
            if defaultCore == 2 {
                // ClownMDEmu does not need BIOS.
                return false
            }
            requireBIOS = R.BIOS.MegaCDBios.filter({ required ? $0.required : true })
        } else if gameType == .ss {
            if defaultCore == 0 {
                requireBIOS = Array(R.BIOS.SaturnBios[1...2]).filter({ required ? $0.required : true })
            } else {
                requireBIOS = [R.BIOS.SaturnBios[0]].filter({ required ? $0.required : true })
            }
        } else if gameType == .ds {
            requireBIOS = R.BIOS.DSBios.filter({ required ? $0.required : true })
        } else if gameType == .fds {
            requireBIOS = R.BIOS.FDSBios
        } else if gameType == .wii {
            requireBIOS = R.BIOS.WiiBios.filter({ required ? $0.required : true })
        } else {
            return false
        }
        let fileManager = FileManager.default
        for bios in requireBIOS {
            var biosInLib = R.Path.System.appendingPathComponent(bios.fileName)
            if gameType == .dc {
                biosInLib = R.Path.Flycast.appendingPathComponent("dc/\(bios.fileName)")
            }
            let biosInDoc = R.Path.BIOS.appendingPathComponent(bios.fileName)
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
        let ps1Bios = R.BIOS.PS1Bios
        let fileManager = FileManager.default
        var result = [BIOSItem]()
        for bios in ps1Bios {
            let biosInLib = R.Path.System.appendingPathComponent(bios.fileName)
            let biosInDoc = R.Path.BIOS.appendingPathComponent(bios.fileName)
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
    
    var libretroCore: EmulationCore? {
        if gameType == .psp {
            return .PPSSPP
        } else if gameType == .nes || gameType == .fds  {
            return .Nestopia
        } else if gameType == .snes {
            if defaultCore == 0 {
                if getExtraBool(key: ExtraKey.snesVRAM.rawValue) ?? false {
                    return .bsnes
                } else {
                    return .bsnesJG
                }
            } else if defaultCore == 1 {
                return .Snes9x
            } else if defaultCore == 2 {
                return .MesenS
            }
        } else if isPicodriveCore {
            return .PicoDrive
        } else if isClownMDEmuCore {
            return .ClownMDEmu
        } else if isGearSystemCore {
            return .Gearsystem
        } else if gameType == .ss {
            if self.fileExtension.lowercased() == "iso" || defaultCore == 1 {
                return .Yabause
            } else if defaultCore == 0 {
                return .BeetleSaturn
            }
        } else if gameType == .n64 {
            return .Mupen64PlushNext
        } else if gameType == .vb {
            return .BeetleVB
        } else if gameType == .pm {
            return .PokeMini
        } else if gameType == .ps1 {
            if defaultCore == 0 {
                return .BeetlePSXHW
            } else if defaultCore == 1 {
                return .PCSXReArmed
            }
        } else if gameType == .gb || gameType == .gbc {
            if defaultCore == 0 {
                return .Gambatte
            } else if defaultCore == 1 {
                return .mGBA
            } else if defaultCore == 2 {
                return .VBAM
            }
        } else if gameType == .gba {
            if defaultCore == 0 {
                return .mGBA
            } else if defaultCore == 1 {
                return .VBAM
            } else if defaultCore == 2 {
                return .gpSP
            }
        } else if gameType == .dc {
            return .Flycast
        } else if gameType == .ds {
            if defaultCore == 0 {
                return .melonDSDS
            } else {
                return .DeSmuME
            }
        } else if gameType == .doom {
            return .PrBoom
        } else if gameType == .arcade {
            if isSegaArcade {
                return .Flycast
            }
            if defaultCore == 0 {
                return .MAME
            } else {
                return .FinalBurnNeo
            }
        } else if gameType == ._3ds, defaultCore == 1 {
            return .Azahar
        } else if gameType == .a2600 {
            return .Stella
        } else if gameType == .a5200 {
            return .Atari800
        } else if gameType == .a7800 {
            return .ProSystem
        } else if gameType == .jaguar {
            return .VirtualJaguar
        } else if gameType == .lynx {
            return .Holani
        } else if gameType == .pce {
            return .BeetlePCE
        } else if gameType == .ngp {
            return .BeetleNeoPop
        } else if gameType == .wsc {
            return .BeetleWonderSwan
        } else if gameType == .c64 {
            return .VICEx64sc
        } else if gameType == .amiga {
            return .PUAE
        } else if gameType == .dos {
            return .DOSBoxPure
        } else if gameType == .symbian {
            return .EKA2L1
        } else if gameType == .ngc || gameType == .wii {
            return .Dolphin
        }
        return nil
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
            } else if defaultCore == 2 {
                return Bundle.main.path(forResource: "mesen-s.libretro", ofType: "framework", inDirectory: "Frameworks")
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
            return Bundle.main.path(forResource: "mupen64plus.next.libretro", ofType: "framework", inDirectory: "Frameworks")
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
            } else if defaultCore == 3 {
                return Bundle.main.path(forResource: "mesen-s.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == .gba {
            if defaultCore == 0 {
                return Bundle.main.path(forResource: "mgba.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else if defaultCore == 1 {
                return Bundle.main.path(forResource: "vbam.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else if defaultCore == 2 {
                return Bundle.main.path(forResource: "gpsp.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == .dc || isSegaArcade {
            if LibretroCore.jitAvailable(), jit {
                return Bundle.main.path(forResource: "flycast.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else {
                return Bundle.main.path(forResource: "flycast-jitless.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == .ds {
            if defaultCore == 0 {
                return Bundle.main.path(forResource: "melondsds.libretro", ofType: "framework", inDirectory: "Frameworks")
            } else {
                return Bundle.main.path(forResource: "desmume.libretro", ofType: "framework", inDirectory: "Frameworks")
            }
        } else if gameType == .doom {
            return Bundle.main.path(forResource: "prboom.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .arcade && !isSegaArcade {
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
        } else if gameType == .pce {
            return Bundle.main.path(forResource: "mednafen.pce.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .ngp {
            return Bundle.main.path(forResource: "mednafen.ngp.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .wsc {
            return Bundle.main.path(forResource: "mednafen.wswan.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .c64 {
            return Bundle.main.path(forResource: "vice.x64sc.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .amiga {
            return Bundle.main.path(forResource: "puae.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .dos {
            return Bundle.main.path(forResource: "dosbox.pure.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .symbian {
            return Bundle.main.path(forResource: "eka2l1.libretro", ofType: "framework", inDirectory: "Frameworks")
        } else if gameType == .ngc || gameType == .wii {
            return Bundle.main.path(forResource: "dolphin.libretro", ofType: "framework", inDirectory: "Frameworks")
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
        return gameType == .n64 && !(getExtraBool(key: ExtraKey.rdpPlugin.rawValue) ?? true)
    }
    
    var is3DSHomeMenuGame: Bool {
        guard gameType == ._3ds else { return false }
        return R.Numbers.ThreeDSHomeMenuIdentifiers.contains(where: { $0 == identifierFor3DS })
    }
    
    var supportRetroAchievements: Bool {
        if gameType == ._3ds || gameType == .doom || gameType == .a5200 || gameType == .dos || gameType == .symbian {
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
        } else if gameType == .fds {
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
            return R.Path.GameplayManuals.appendingPathComponent(fileName)
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
        
        if let buildIns = try? FileManager.default.contentsOfDirectory(atPath: R.Path.NESPalettes) {
            results.append(contentsOf: buildIns.sorted().compactMap({
                if $0.pathExtension.lowercased() == "pal" {
                    return NESPalette(name: $0.deletingPathExtension, type: .buildIn)
                } else {
                    return nil
                }
            }))
        }
        
        if let customs = try? FileManager.default.contentsOfDirectory(atPath: R.Path.CustomPalettes.appendingPathComponent(gameType.localizedShortName)) {
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
    
    var screenScaling: GameOption.ScreenScaling {
        if let scalingInt = getExtraInt(key: ExtraKey.screenScaling.rawValue),
           let scaling = GameOption.ScreenScaling(rawValue: scalingInt) {
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
        let j2mejsUrl = URL(fileURLWithPath: R.Path.Data.appendingPathComponent("\(name).\(EmulationCore.J2meJS.name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")"))
        try? FileManager.safeRemoveItem(at: j2mejsUrl)
        SyncManager.delete(localFilePath: j2mejsUrl.path)
        
        let freej2meUrl = URL(fileURLWithPath: R.Path.Data.appendingPathComponent("\(name).\(EmulationCore.freej2me.name).\(gameType.manicEmuCore?.gameSaveFileExtension ?? "")"))
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
        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: R.Path.DOSBoxPure), includingPropertiesForKeys: [.isDirectoryKey]) {
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
        if gameType == ._3ds, id == R.Strings.AzaharArticBaseGameID {
            return true
        }
        return false
    }
    
    var isArticBaseHomeMenu: Bool {
        guard gameType == ._3ds, defaultCore == 1 else { return false }
        return getExtraBool(key: ExtraKey.isArticBaseHomeMenu.rawValue) ?? false
    }
    
    var isSymbianHomeMenu: Bool {
        guard gameType == .symbian else { return false }
        if id == Game.SymbianHomePrimary {
            return true
        }
        return false
    }
    
    var isPSPPBPGame: Bool {
        guard gameType == .psp else { return false }
        return getExtraBool(key: ExtraKey.isPSPPBPGame.rawValue) ?? false
    }
    
    var supportChangeCategory: Bool {
        if gameType == .gb ||
            (gameType == .dos && !isDOSHomeMenuGame) ||
            gameType == .pce ||
            gameType == .ngp ||
            gameType == .wsc {
            return true
        }
        return false
    }
    
    var supportedCategories: [GameType] {
        if gameType == .gb {
            return [.gb, .chm]
        } else if gameType == .dos {
            return [.dos, .win95, .win98]
        } else if gameType == .pce {
            return [.pce, .turbografx_16, .turbografx_cd, .supergrafx]
        } else if gameType == .ngp {
            return [.ngp, .ngpc]
        } else if gameType == .wsc {
            return [.wsc, .ws]
        }
        return []
    }
    
    func updateCategory(gameType: GameType) {
        guard supportChangeCategory else { return }
        if gameType == .gb || gameType == .dos || gameType == .pce || gameType == .ngp || gameType == .wsc {
            updateExtra(key: ExtraKey.gameTypeCategory.rawValue, value: 0)
        } else if gameType == .chm || gameType == .win95 || gameType == .turbografx_16 || gameType == .ngpc || gameType == .ws {
            updateExtra(key: ExtraKey.gameTypeCategory.rawValue, value: 1)
        } else if gameType == .win98 || gameType == .turbografx_cd {
            updateExtra(key: ExtraKey.gameTypeCategory.rawValue, value: 2)
        } else if gameType == .supergrafx {
            updateExtra(key: ExtraKey.gameTypeCategory.rawValue, value: 3)
        }
    }
    
    func matchCover(force: Bool = false,
                    useVirtualGameTypeIfNeed: Bool = true) {
        if gameCover == nil && onlineCoverUrl == nil {
            if force || !hasCoverMatch {
                OnlineCoverManager.shared.addCoverMatch(OnlineCoverManager.CoverMatch(gameType: effectiveGameType,
                                                                                      gameID: id,
                                                                                      gameName: name,
                                                                                      fileExtension: fileExtension))
            }
        }
    }
    
    var virtualGameType: GameType? {
        if supportedCategories.count > 0,
           let category = getExtraInt(key: ExtraKey.gameTypeCategory.rawValue),
           category < supportedCategories.count {
            return supportedCategories[category]
        }
        return nil
    }
    
    /// GB/DOS/PCE/NGP/WSC support category switching onto virtual GameTypes.
    var effectiveGameType: GameType {
        virtualGameType ?? gameType
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
    
    var supportCheatCode: Bool {
        if gameType == .vb ||
            gameType == .pm ||
            isJGenesisCore ||
            gameType.externalType ||
            isAtari ||
            (gameType == .ss && defaultCore == 0) ||
            gameType == .dc ||
            isSegaArcade ||
            gameType == .j2me ||
            gameType == .dos ||
            gameType == .symbian ||
            isClownMDEmuCore ||
            gameType == .pce ||
            gameType == .amiga ||
            gameType == .c64 ||
            gameType == .sg1000 ||
            gameType == .ngp  {
            return false
        }
        return true
    }
    
    var supportLanguage: Bool {
        if gameType == ._3ds ||
            gameType == .psp ||
            (gameType == .ss && defaultCore == 0) ||
            gameType == .ds ||
            gameType == .dc ||
            isDolphinCore ||
            gameType == .wsc{
            return true
        }
        return false
    }
    
    var supportedLanguages: [String] {
        var languages = [String]()
        if gameType == ._3ds {
            languages = R.Strings.ThreeDSConsoleLanguage
        } else if gameType == .psp {
            languages = R.Strings.PSPConsoleLanguage
        } else if gameType == .ss {
            languages = R.Strings.SaturnConsoleLanguage
        } else if gameType == .ds {
            languages = R.Strings.DSConsoleLanguage
        } else if gameType == .dc {
            languages = R.Strings.DCConsoleLanguage
        } else if isDolphinCore {
            languages = R.Strings.DolphinLanguage
        } else if gameType == .wsc {
            languages = R.Strings.WSwanLanguage
        }
        return languages
    }
    
    var supportJit: Bool {
        if (isCitra3DS && !Settings.defalut.threeDSAdvancedSettingMode) ||
            isAzahar3DS ||
            gameType == .psp ||
            (gameType == .ds && defaultCore == 0) ||
            gameType == .n64 ||
            (gameType == .ps1 && defaultCore == 0) ||
            gameType == .dc ||
            isSegaArcade ||
            gameType == .dos ||
            gameType == .symbian ||
            isDolphinCore {
            return true
        }
        return false
    }
    
    var supportCoreSettings: Bool {
        if isLibretroType || isJ2MECore || isCitra3DS {
            return true
        }
        return false
    }
    
    func getCoverImage(completion: ((UIImage?) -> Void)? = nil) {
        guard let completion else { return }
        if let imageData = gameCover?.storedData(),
            let image = UIImage(data: imageData) {
            completion(image)
        } else if let onlineCoverUrl,
                    let url = URL(string: onlineCoverUrl) {
            KingfisherManager.shared.retrieveImage(with: url, completionHandler: { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let imageResult):
                        completion(imageResult.image)
                    case .failure(_):
                        completion(nil)
                    }
                }
            })
        } else {
            completion(nil)
        }
    }
    
    var supportFastForward: Bool {
        if (gameType == .j2me && defaultCore != 0) ||
            gameType == .symbian {
            return false
        }
        return true
    }
    
    var supportSlangShaders: Bool {
        if (gameType == ._3ds && defaultCore == 0) ||
            (gameType == .mcd && defaultCore != 0) ||
            (gameType == ._32x && defaultCore != 0) ||
            gameType == .j2me ||
            (gameType == .n64 && !isN64ParaLLEl) ||
            gameType.externalType ||
            gameType == .symbian {
            return false
        }
        return true
    }
    
    var supportGlslShaders: Bool {
        if gameType == .n64, !isN64ParaLLEl {
            return true
        }
        return false
    }
    
    var supportSwapScreen: Bool {
        if gameType == ._3ds || gameType == .ds {
            return true
        }
        return false
    }
    
    var supportResolution: Bool {
        if gameType == ._3ds ||
            (gameType == .ds && defaultCore != 0) ||
            gameType == .psp ||
            gameType == .n64 ||
            (gameType == .ps1 && defaultCore == 0) ||
            gameType == .dc ||
            gameType == .doom {
            return true
        }
        return false
    }
    
    var supportConsoleHome: Bool {
        if isCitra3DS ||
            gameType == .wii {
            return true
        }
        return false
    }
    
    var supportAmiibo: Bool {
        if gameType == ._3ds {
            return true
        }
        return false
    }
    
    var supportSimBlowing: Bool {
        if gameType == ._3ds || gameType == .ds {
            return true
        }
        return false
    }
    
    var supportPalette: Bool {
        if gameType == .nes ||
            gameType == .fds ||
            (gameType == .gb && defaultCore != 3) ||
            gameType == .vb ||
            gameType == .pm ||
            effectiveGameType == .ws {
            return true
        }
        return false
    }
    
    var supportAirPlayLayout: Bool {
        if gameType == ._3ds || gameType == .ds {
            return true
        }
        return false
    }
    
    var supportScreenScaling: Bool {
        if (gameType == .mcd && defaultCore != 0) ||
            (gameType == ._32x && defaultCore != 0) {
            return false
        }
        return true
    }
    
    var supportInsertDisc: Bool {
        if gameType == .ps1 ||
            gameType == .dos ||
            gameType == .c64 ||
            gameType == .amiga {
            return true
        }
        return false
    }
    
    var supportSaveState: Bool {
        if gameType == .jaguar || gameType == .j2me || gameType == .symbian {
            return false
        }
        return true
    }
    
    var supportSave: Bool {
        if isDOSHomeMenuGame ||
            gameType == .sg1000 {
            return false
        }
        return true
    }
    
    
    var gameCoverIcon: ASIcon {
        let icon: ASIcon
        if let imageData = gameCover?.storedData(),
           let image = UIImage(data: imageData) {
            icon = .image(image, cornerStyle: .radius(R.Size.CornerRadiusMicro))
        } else if let urlString = onlineCoverUrl,
                  let url = URL(string: urlString) {
            icon = .imageUrl(url, cornerStyle: .radius(R.Size.CornerRadiusMicro))
        } else {
            icon = .symbolImage(R.image.logo_iconSymbols(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        }
        return icon
    }
    
    var displayName: String {
        aliasName ?? name
    }
    
    /// Whether rewind is available. Requires savestate_features of serialized or higher.
    var supportRewind: Bool {
        // Non-libretro and external types do not support rewind.
        guard isLibretroType, !gameType.externalType else { return false }
        // Jaguar has savestate = false. DOOM, 3DS, DC, Symbian, NGC, and Wii are basic-only.
        if gameType == .jaguar ||
            gameType == .doom ||
            gameType == ._3ds ||
            gameType == .dc ||
            gameType == .symbian ||
            isDolphinCore ||
            gameType == .vb {
            return false
        }
        // Saturn: only Beetle Saturn (defaultCore == 0) supports rewind; Yabause is basic.
        if gameType == .ss, fileExtension.lowercased() == "iso" || defaultCore == 1 {
            return false
        }
        return true
    }
    
    //For Symbian system apps
    var symbianSystemApp: SymbianSystemApp? = nil
    
    func updateSymbianGame(device: LibretroSymbianDevice, changeSkin: Bool = false) {
        guard gameType == .symbian else { return }
        updateExtra(key: ExtraKey.symbianFirmwareCode.rawValue, value: device.firmwareCode)
        updateExtra(key: ExtraKey.symbianFirmwareModel.rawValue, value: device.model)
        updateExtra(key: ExtraKey.symbianOSVer.rawValue, value: SymbianOS.getOS(by: device).rawValue)
        
        guard changeSkin else { return }
        //Set the skin preference based on the system version
        let gameId = id
        DispatchQueue.main.async {
            
            func changeSkin(isLandScape: Bool, isFlex: Bool, isEdge: Bool) {
                let skinUrl: URL
                if isFlex {
                    skinUrl = isEdge ? R.URLs.SymbianEdgeFlexSkinUrl : R.URLs.SymbianFlexSkinUrl
                } else {
                    skinUrl = isEdge ? R.URLs.SymbianEdgeSkinUrl : R.URLs.SymbianSkinUrl
                }
                guard let skinId = FileHashUtil.truncatedHash(url: skinUrl) else { return }
                Prefference.defalut.storePrefference(kind: .skin,
                                                     storeKey: .orientationKey(gameId: gameId, isLandScape: isLandScape),
                                                     storeValue: skinId)
            }
            
            let prefferedEdgeSkin = SymbianOS.getOS(by: device).rawValue > SymbianOS.S60v3.rawValue
            let realm = Database.realm
            var hadSetLandscapeSkin = false
            var hadSetPortraitSkin = false
            
            if let skinId = Prefference.defalut.getPrefference(kind: .skin,
                                                               storeKey: .orientationKey(gameId: gameId, isLandScape: true),
                                                               bestEfforts: true)?.skinValue?.skinId,
               let skin = realm.object(ofType: Skin.self, forPrimaryKey: skinId) {
                //设置过横屏
                hadSetLandscapeSkin = true
                
                if !prefferedEdgeSkin && skin.identifier == R.Strings.SymbianEdgeSkinIdentifier {
                    //要换成标准横屏
                    changeSkin(isLandScape: true, isFlex: false, isEdge: false)
                } else if !prefferedEdgeSkin && skin.identifier == R.Strings.SymbianEdgeFlexSkinIdentifier {
                    //切换到flex标准横屏
                    changeSkin(isLandScape: true, isFlex: true, isEdge: false)
                } else if prefferedEdgeSkin && skin.identifier == R.Strings.SymbianSkinIdentifier {
                    //切换Edge横屏
                    changeSkin(isLandScape: true, isFlex: false, isEdge: true)
                } else if prefferedEdgeSkin && skin.identifier == R.Strings.SymbianSkinIdentifier {
                    //切换Edge Flex横屏
                    changeSkin(isLandScape: true, isFlex: true, isEdge: true)
                }
            }
            
            if let skinId = Prefference.defalut.getPrefference(kind: .skin,
                                                               storeKey: .orientationKey(gameId: gameId, isLandScape: false),
                                                               bestEfforts: true)?.skinValue?.skinId,
               let skin = realm.object(ofType: Skin.self, forPrimaryKey: skinId) {
                //设置过竖屏
                hadSetPortraitSkin = true
                if !prefferedEdgeSkin && skin.identifier == R.Strings.SymbianEdgeSkinIdentifier {
                    //要换成标准竖屏
                    changeSkin(isLandScape: false, isFlex: false, isEdge: false)
                } else if !prefferedEdgeSkin && skin.identifier == R.Strings.SymbianEdgeFlexSkinIdentifier {
                    //切换到flex标准竖屏
                    changeSkin(isLandScape: false, isFlex: true, isEdge: false)
                } else if prefferedEdgeSkin && skin.identifier == R.Strings.SymbianSkinIdentifier {
                    //切换Edge竖屏
                    changeSkin(isLandScape: false, isFlex: false, isEdge: true)
                } else if prefferedEdgeSkin && skin.identifier == R.Strings.SymbianSkinIdentifier {
                    //切换Edge Flex竖屏
                    changeSkin(isLandScape: false, isFlex: true, isEdge: true)
                }
            }
            
            if !hadSetLandscapeSkin {
                //需要设置横屏
                if prefferedEdgeSkin {
                    //切换Edge横屏
                    changeSkin(isLandScape: true, isFlex: false, isEdge: true)
                } else {
                    //要换成标准横屏
                    changeSkin(isLandScape: true, isFlex: false, isEdge: false)
                }
            }
            
            if !hadSetPortraitSkin {
                //需要设置竖屏
                if prefferedEdgeSkin {
                    //切换Edge竖屏
                    changeSkin(isLandScape: false, isFlex: false, isEdge: true)
                } else {
                    //要换成标准竖屏
                    changeSkin(isLandScape: false, isFlex: false, isEdge: false)
                }
            }
        }
    }
    
    /// Relative E: prefixes `system/<dir>/<name>` from an N-Gage 1.0 dump. Empty for SIS/SISX.
    var ngageRelativeFiles: [String] {
        let raw: [String]
        if let files = getExtra(key: ExtraKey.ngageFiles.rawValue) as? [String] {
            raw = files
        } else if let joined = getExtraString(key: ExtraKey.ngageFiles.rawValue), !joined.isEmpty {
            raw = joined.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        } else {
            return []
        }
        let compacted = Array(Set(raw.compactMap { Self.ngageEDriveRelativePath($0) })).sorted()
        if Set(raw) != Set(compacted), realm?.isInWriteTransaction != true {
            updateExtra(key: ExtraKey.ngageFiles.rawValue, value: compacted)
        }
        return compacted
    }
    
    /// `system/apps/6rbc` even if an older import stored a leaf or temp absolute path.
    private static func ngageEDriveRelativePath(_ path: String) -> String? {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        guard let range = normalized.range(of: "system/") else { return nil }
        let parts = String(normalized[range.lowerBound...]).split(separator: "/").map(String.init)
        guard parts.count >= 3, parts[0] == "system" else { return nil }
        return "\(parts[0])/\(parts[1])/\(parts[2])"
    }
    
    var symbianInstallPackages: [(uid: Int, index: Int)] {
        guard let items = getExtra(key: ExtraKey.symbianPackages.rawValue) as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let uid = Self.symbianJSONInt(item["uid"]), let index = Self.symbianJSONInt(item["index"]) else {
                return nil
            }
            return (uid, index)
        }
    }
    
    private static func symbianJSONInt(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }
    
    /// Removes N-Gage card files from E: or uninstalls SIS packages. Call before deleting the Realm row.
    func uninstallFromSymbianStorage() {
        guard gameType == .symbian else { return }
        let files = ngageRelativeFiles
        if !files.isEmpty {
            let root = R.Path.EKA2L1DriveE
            for relative in files {
                let path = root.appendingPathComponent(relative)
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: path))
                if isDirectory.boolValue {
                    SyncManager.deletePath(localPath: path)
                } else {
                    SyncManager.delete(localFilePath: path)
                }
            }
            return
        }
        for package in symbianInstallPackages {
            LibretroCore.uninstallSymbianGame(withUid: package.uid, index: package.index)
        }
    }
    
    var usingSymbianDeviceIndex: Int? {
        if let firmwareCode = getExtraString(key: ExtraKey.symbianFirmwareCode.rawValue),
           let devices = LibretroCore.getSymbianDevices(),
           let index = devices.firstIndex(where: { $0.firmwareCode == firmwareCode }) {
            return index
        }
        return nil
    }
    
    var usingSymbianOS: SymbianOS {
        if let int = getExtraInt(key: ExtraKey.symbianOSVer.rawValue),
            let os = SymbianOS(rawValue: int) {
            return os
        }
        return .S60v3
    }
    
    func handleTapAction(forceQuick: Bool = false, saveState: GameSaveState? = nil) {
        if isNDSHomeMenuGame {
            let biosCompletion = gameType.isNDSBiosComplete()
            if (id == Game.DsHomeMenuPrimaryKey && !biosCompletion.isDSComplete) ||
                (id == Game.DsiHomeMenuPrimaryKey && !biosCompletion.isDsiComplete) {
                //弹出bios导入页面
                BIOSSelectionView.show(gameType: gameType)
            } else {
                PlayViewController.startGame(game: self, saveState: saveState)
            }
        } else if isSymbianHomeMenu {
            SymbianFirmwareView.show()
        } else if Settings.defalut.quickGame || forceQuick {
            PlayViewController.startGame(game: self, saveState: saveState)
        } else {
            if gameType == .unknown {
                PlatformSelectionView.show(games: [self])
            } else {
                GameInfoView.show(readyAction: .default, game: self)
            }
        }
    }
    
    var isDolphinCore: Bool {
        gameType == .ngc || gameType == .wii
    }
    
    var supportSlowMotion: Bool {
        if isLibretroType && gameType != .symbian {
            return true
        }
        return false
    }
    
    var wswanPaletteTitle: String {
        guard effectiveGameType == .ws else { return "default" }
        let index = getExtraInt(key: ExtraKey.wswanPalette.rawValue) ?? 0
        return GameOption.Palette.AllPaletteTitleForWS[index]
    }
    
    var isNaomiGame: Bool {
        guard gameType == .arcade else { return false }
        return getExtraInt(key: ExtraKey.arcadeType.rawValue) == 1
    }
    
    var isAtomiswaveGame: Bool {
        guard gameType == .arcade else { return false }
        return getExtraInt(key: ExtraKey.arcadeType.rawValue) == 2
    }
    
    var isSegaSPGame: Bool {
        guard gameType == .arcade else { return false }
        return getExtraInt(key: ExtraKey.arcadeType.rawValue) == 3
    }
    
    var isSegaArcade: Bool {
        isNaomiGame || isAtomiswaveGame || isSegaSPGame
    }
}


struct AchievementProgress: SmartCodable {
    var id: Int = 0
    var measuredProgress: String = ""
    var measuredPercent: CGFloat = 0
}
