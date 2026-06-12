//
//  GameTypeExtensions.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import RealmSwift

///通过文件名后缀生成GameType
extension GameType {
    static var multiPlatformFileExtensions = ["chd", "iso", "rvz", "bin", "cue", "m3u", "pbp", "ccd", "zip"]
    
    static func gameTypes(multiPlatformFileExtension: String) -> [GameType] {
        let ext = multiPlatformFileExtension.lowercased()
        guard multiPlatformFileExtensions.contains(ext) else { return [] }
        switch ext {
        case "chd":
            return [.ps1, .psp, .mcd, .ss, .dc]
        case "iso":
            return [.psp, .mcd, .ss, .dos, .gc, .wii]
        case "rvz":
            return [.gc, .wii]
        case "bin":
            return [.md, .gg, .ms, ._32x, .dc, .a2600, .a5200, .a7800, .jaguar]
        case "cue":
            return [.ps1, .mcd, .ss, .dc, .dos]
        case "m3u":
            return [ ps1, .mcd, .ss, .dc, .dos]
        case "pbp":
            return [.ps1, .psp]
        case "ccd":
            return [.ps1, .ss]
        case "zip":
            return [.arcade, .dos]
        default:
            return []
        }
    }
    
    init(fileExtension: String) {
        let ext = fileExtension.lowercased()
        if GameType.multiPlatformFileExtensions.contains(ext) {
            //会混淆的后缀 多个平台都用这个后缀，则返回unknown
            self = .unknown
        } else if ["gba"].contains(ext)  {
            self = .gba
        } else if ["gbc"].contains(ext) {
            self = .gbc
        } else if ["gb"].contains(ext) {
            self = .gb
        }  else if ["ds", "nds"].contains(ext) {
            self = .ds
        } else if ["nes", "fc", "unf", "unif"].contains(ext)  {
            self = .nes
        } else if ["fds"].contains(ext)  {
            self = .fds
        }else if ["smc", "sfc", "fig", "snes"].contains(ext) {
            self = .snes
        } else if ["gcm", "gcz", "dol"].contains(ext) {
            self = .gc
        } else if ["wbfs", "ciso", "wia"].contains(ext) {
            self = .wii
        } else if ["3ds", "cia", "app", "cci", "cxi", "3dsx"].contains(ext) {
            self = ._3ds
        } else if ["elf", "iso", "cso", "prx", "pbp", "chd"].contains(ext) {
            self = .psp
        } else if ["md", "gen", "smd", "bin"].contains(ext) {
            self = .md
        } else if ["chd", "iso", "mdcd", "cue", "m3u"].contains(ext) {
            self = .mcd
        } else if ["32x"].contains(ext) {
            self = ._32x
        } else if ["sg"].contains(ext) {
            self = .sg1000
        } else if ["gg", "bin"].contains(ext) {
            self = .gg
        } else if ["ms", "sms", "bms", "bin"].contains(ext) {
            self = .ms
        } else if ["iso", "chd", "ccd", "cue", "m3u", "ss"].contains(ext) {
            self = .ss
        } else if ["n64", "v64", "z64"].contains(ext) {
            self = .n64
        } else if ["vb", "vboy"].contains(ext) {
            self = .vb
        } else if ["min"].contains(ext) {
            self = .pm
        } else if ["cue", "m3u", "pbp", "chd", "ccd", "ps1"].contains(ext) {
            self = .ps1
        } else if ["cdi", "gdi", "chd", "cue", "bin", "m3u"].contains(ext) {
            self = .dc
        } else if ["wad", "iwad", "pwad"].contains(ext) {
            self = .doom
        } else if ["zip", "7z", "cmd"].contains(ext) {
            self = .arcade
        } else if ["a26", "bin"].contains(ext) {
            self = .a2600
        } else if ["a52", "bin"].contains(ext) {
            self = .a5200
        } else if ["a78", "bin", "cdf"].contains(ext) {
            self = .a7800
        } else if ["j64", "jag", "rom", "abs", "cof", "bin", "prg"].contains(ext) {
            self = .jaguar
        } else if ["lnx", "o"].contains(ext) {
            self = .lynx
        } else if ["jar"].contains(ext) {
            self = .j2me
        } else if ["zip", "dosz", "exe", "com", "bat", "iso", "cue", "img", "ima", "vhd", "jrc", "tc", "m3u", "conf"].contains(ext) {
            self = .dos
        } else {
            self = .notSupport
        }
    }
    
    init?(saveFileExtension: String) {
        switch saveFileExtension.lowercased() {
        case "dsv": self = .ds
        case "bkr": self = .ss
        case "eep": self = .pm
        case "mcd", "mcr": self = .ps1
        default: return nil
        }
    }
    
    init?(shortName: String) {
        if shortName.uppercased() == "3DS" {
            self = ._3ds
        } else if shortName.uppercased() == "NDS" {
            self = .ds
        } else if shortName.uppercased() == "GBA" {
            self = .gba
        } else if shortName.uppercased() == "GBC" {
            self = .gbc
        } else if shortName.uppercased() == "GB" {
            self = .gb
        } else if shortName.uppercased() == "NES" {
            self = .nes
        } else if shortName.uppercased() == "FDS" {
            self = .fds
        } else if shortName.uppercased() == "SNES" {
            self = .snes
        } else if shortName.uppercased() == "PSP" {
            self = .psp
        } else if shortName.uppercased() == "MD" {
            self = .md
        } else if shortName.uppercased() == "MCD" {
            self = .mcd
        } else if shortName.uppercased() == "32X" {
            self = ._32x
        } else if shortName.uppercased() == "SG-1000" {
            self = .sg1000
        } else if shortName.uppercased() == "GG" {
            self = .gg
        } else if shortName.uppercased() == "MS" {
            self = .ms
        } else if shortName.uppercased() == "SS" {
            self = .ss
        } else if shortName.uppercased() == "N64" {
            self = .n64
        } else if shortName.uppercased() == "VB" {
            self = .vb
        } else if shortName.uppercased() == "PM" {
            self = .pm
        } else if shortName.uppercased() == "PS1" {
            self = .ps1
        } else if shortName.uppercased() == "DC" {
            self = .dc
        } else if shortName.uppercased() == "DOOM" {
            self = .doom
        } else if shortName.uppercased() == "Arcade".uppercased() {
            self = .arcade
        } else if shortName.uppercased() == "NS" {
            self = .ns
        } else if shortName.uppercased() == "2600" {
            self = .a2600
        } else if shortName.uppercased() == "5200" {
            self = .a5200
        } else if shortName.uppercased() == "7800" {
            self = .a7800
        } else if shortName.uppercased() == "JAGUAR" {
            self = .jaguar
        } else if shortName.uppercased() == "LYNX" {
            self = .lynx
        } else if shortName.uppercased() == "GC" {
            self = .gc
        } else if shortName.uppercased() == "WII" {
            self = .wii
        } else if shortName.uppercased() == "XBOX360" {
            self = .xbox360
        } else if shortName.uppercased() == "J2ME" {
            self = .j2me
        } else if shortName.uppercased() == "DOS" {
            self = .dos
        } else {
            return nil
        }
    }
    
    var localizedName: String {
        switch self
        {
        case .nes: return "Nintendo"
        case .fds: return "Famicom Disk System"
        case .snes: return "Super Nintendo"
        case ._3ds: return "Nintendo 3DS"
        case .gbc: return "Game Boy Color"
        case .gb: return "Game Boy"
        case .chm: return "Chromatic"
        case .gba: return "Game Boy Advance"
        case .ds: return "Nintendo DS"
        case .psp: return "PlayStation Portable"
        case .md: return Locale.prefersUS ? "Sega Genesis" : "Mega Drive"
        case .mcd: return Locale.prefersUS ? "Sega CD" : "Mega-CD"
        case ._32x: return Locale.prefersUS ? "Genesis 32X" : "Super 32X"
        case .sg1000: return "SG-1000"
        case .gg: return "Game Gear"
        case .ms: return "Sega Master System"
        case .ss: return "Sega Saturn"
        case .n64: return "Nintendo 64"
        case .vb: return "Virtual Boy"
        case .pm: return "Pokémon Mini"
        case .ps1: return "PlayStation"
        case .dc: return "Dreamcast"
        case .doom: return "DOOM"
        case .arcade: return "Arcade"
        case .ns: return "Nintendo Switch"
        case .a2600: return "Atari 2600"
        case .a5200: return "Atari 5200 SuperSystem"
        case .a7800: return "Atari 7800 ProSystem"
        case .jaguar: return "Atari Jaguar"
        case .lynx: return "Atari Lynx"
        case .gc: return "Nintendo GameCube"
        case .wii: return "Nintendo Wii"
        case .j2me: return "Java ME"
        case .xbox360: return "Xbox 360"
        case .dos: return "MS-DOS"
        case .win95: return "Windows 95"
        case .win98: return "Windows 98"
        default: return ""
        }
    }
    
    var localizedShortName: String {
        switch self
        {
        case .nes: return NSLocalizedString("NES", comment: "")
        case .fds: return NSLocalizedString("FDS", comment: "")
        case .snes: return NSLocalizedString("SNES", comment: "")
        case ._3ds: return NSLocalizedString("3DS", comment: "")
        case .gbc: return NSLocalizedString("GBC", comment: "")
        case .gb: return NSLocalizedString("GB", comment: "")
        case .chm: return NSLocalizedString("CHM", comment: "")
        case .gba: return NSLocalizedString("GBA", comment: "")
        case .ds: return NSLocalizedString("NDS", comment: "")
        case .psp: return NSLocalizedString("PSP", comment: "")
        case .md: return NSLocalizedString("MD", comment: "")
        case .mcd: return NSLocalizedString("MCD", comment: "")
        case ._32x: return NSLocalizedString("32X", comment: "")
        case .sg1000: return NSLocalizedString("SG-1000", comment: "")
        case .gg: return NSLocalizedString("GG", comment: "")
        case .ms: return NSLocalizedString("MS", comment: "")
        case .ss: return NSLocalizedString("SS", comment: "")
        case .n64: return NSLocalizedString("N64", comment: "")
        case .vb: return NSLocalizedString("VB", comment: "")
        case .pm: return NSLocalizedString("PM", comment: "")
        case .ps1: return NSLocalizedString("PS1", comment: "")
        case .dc: return NSLocalizedString("DC", comment: "")
        case .doom: return NSLocalizedString("DOOM", comment: "")
        case .arcade: return NSLocalizedString("Arcade", comment: "")
        case .ns: return  NSLocalizedString("NS", comment: "")
        case .a2600: return  NSLocalizedString("2600", comment: "")
        case .a5200: return  NSLocalizedString("5200", comment: "")
        case .a7800: return  NSLocalizedString("7800", comment: "")
        case .jaguar: return  NSLocalizedString("JAGUAR", comment: "")
        case .lynx: return  NSLocalizedString("LYNX", comment: "")
        case .gc: return  NSLocalizedString("GC", comment: "")
        case .wii: return  NSLocalizedString("Wii", comment: "")
        case .j2me: return  NSLocalizedString("J2ME", comment: "")
        case .xbox360: return  NSLocalizedString("XBOX360", comment: "")
        case .dos: return  NSLocalizedString("DOS", comment: "")
        case .win95: return  NSLocalizedString("WIN95", comment: "")
        case .win98: return  NSLocalizedString("WIN98", comment: "")
        case .unknown: return R.string.localizable.unknownPlatform()
        default: return ""
        }
    }
    
    var year: Int {
        switch self
        {
        case .nes: return 1985
        case .fds: return 1986
        case .snes: return 1990
        case ._3ds: return 2011
        case .gb: return 1989
        case .chm: return 2024
        case .gbc: return 1998
        case .gba: return 2001
        case .ds: return 2004
        case .psp: return 2004
        case .md: return 1988
        case .mcd: return 1991
        case ._32x: return 1994
        case .sg1000: return 1983
        case .gg: return 1990
        case .ms: return 1985
        case .ss: return 1994
        case .n64: return 1996
        case .vb: return 1995
        case .pm: return 2001
        case .ps1: return 1995
        case .dc: return 1998
        case .doom: return 1993
        case .arcade: return 1971
        case .ns: return 2017
        case .a2600: return 1977
        case .a5200: return 1982
        case .a7800: return 1986
        case .lynx: return 1989
        case .jaguar: return 1993
        case .gc: return 2001
        case .wii: return 2006
        case .j2me: return 1999
        case .xbox360: return 2005
        case .dos: return 1981
        case .win95: return 1995
        case .win98: return 1998
        default: return 0
        }
    }
    
    var manicEmuCore: DeltaCoreProtocol? {
        switch self
        {
        case .nes: return NES.core
        case .fds: return FDS.core
        case .snes: return SNES.core
        case ._3ds: return ThreeDS.core
        case .gbc: return GBC.core
        case .gb: return GB.core
        case .gba: return GBA.core
        case .ds: return DS.core
        case .psp: return PSP.core
        case .md: return MD.core
        case .mcd: return MCD.core
        case ._32x: return S2X.core
        case .sg1000: return SG1000.core
        case .gg: return GG.core
        case .ms: return MS.core
        case .ss: return SS.core
        case .n64: return N64.core
        case .vb: return VB.core
        case .pm: return PM.core
        case .ps1: return PS1.core
        case .dc: return DC.core
        case .doom: return DOOM.core
        case .arcade: return Arcade.core
        case .a2600: return A2600.core
        case .a5200: return A5200.core
        case .a7800: return A7800.core
        case .jaguar: return Jaguar.core
        case .lynx: return Lynx.core
        case .gc: return GameCube.core
        case .wii: return Wii.core
        case .j2me: return J2ME.core
        case .dos: return DOS.core
        default: return nil
        }
    }
    
    func reuseGameType() -> GameType {
        if self == .mcd || self == ._32x {
            return .md
        } else if self == .fds {
            return .nes
        } else if self == .doom {
            return .dos
        }
        return self
    }
    
    var supportCores: [String] {
        if self == .ss {
            return [LibretroCore.Cores.BeetleSaturn.name, LibretroCore.Cores.Yabause.name]
        } else if self == .gba {
            return [LibretroCore.Cores.mGBA.name, LibretroCore.Cores.VBAM.name]
        } else if self == .md {
#if SIDE_LOAD
            return [LibretroCore.Cores.ClownMDEmu.name, LibretroCore.Cores.PicoDrive.name]
#endif
        } else if self == .ms || self == .gg || self == .sg1000 {
#if SIDE_LOAD
            return [LibretroCore.Cores.Gearsystem.name, LibretroCore.Cores.PicoDrive.name]
#endif
        } else if self == .gb || self == .gbc {
            return [LibretroCore.Cores.Gambatte.name, LibretroCore.Cores.mGBA.name, LibretroCore.Cores.VBAM.name]
        } else if self == .arcade {
#if SIDE_LOAD
            return [LibretroCore.Cores.MAME.name, LibretroCore.Cores.FinalBurnNeo.name]
#endif
        } else if self == ._3ds {
            return [LibretroCore.Cores.Citra.name, LibretroCore.Cores.Azahar.name]
        } else if self == ._32x {
#if SIDE_LOAD
            return [LibretroCore.Cores.PicoDrive.name, LibretroCore.Cores.JGenesis.name]
#endif
        } else if self == .mcd {
#if SIDE_LOAD
            return [LibretroCore.Cores.PicoDrive.name, LibretroCore.Cores.JGenesis.name, LibretroCore.Cores.ClownMDEmu.name]
#else
            return ["", LibretroCore.Cores.JGenesis.name, LibretroCore.Cores.ClownMDEmu.name]
#endif
        } else if self == .ds {
            return [LibretroCore.Cores.melonDSDS.name, LibretroCore.Cores.DeSmuME.name]
        } else if self == .j2me {
            return [LibretroCore.Cores.J2meJS.name, LibretroCore.Cores.freej2me.name]
        } else if self == .ps1 {
            return [LibretroCore.Cores.BeetlePSXHW.name, LibretroCore.Cores.PCSXReArmed.name]
        } else if self == .gc || self == .wii {
            return [LibretroCore.Cores.Dolphin.name]
        } else if self == .snes {
#if SIDE_LOAD
            return [LibretroCore.Cores.bsnes.name, LibretroCore.Cores.Snes9x.name]
#endif
        }
        return []
    }
    
    var reuseSkinGameType: [GameType] {
        if self == .gb || self == .gbc {
            return [.gb, .gbc]
        } else if self == .md || self == .mcd || self == ._32x {
            return [.md, .mcd, ._32x]
        } else if self == .ms || self == .gg || self == .sg1000 {
            return [.ms, .gg, .sg1000]
        } else if self == .nes || self == .fds {
            return [.nes, .fds]
        } else if self == .dos || self == .doom {
            return [.dos, .doom]
        }
        return [self]
    }
    
    func isNDSBiosComplete() -> (isDSComplete: Bool, isDsiComplete: Bool) {
        guard self == .ds else { return (false, false) }
        let dsBiosItems = Constants.BIOS.DSBios.filter({ !$0.fileName.hasPrefix("dsi_") })
        let dsiBiosItems = Constants.BIOS.DSBios.filter({ $0.fileName.hasPrefix("dsi_") })
        
        func isComplete(biosItems: [BIOSItem]) -> Bool {
            var isComplete = true
            let fileManager = FileManager.default
            for bios in biosItems {
                let biosInLib = Constants.Path.System.appendingPathComponent(bios.fileName)
                let biosInDoc = Constants.Path.BIOS.appendingPathComponent(bios.fileName)
                if fileManager.fileExists(atPath: biosInLib) {
                    continue
                } else if fileManager.fileExists(atPath: biosInDoc) {
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: biosInDoc), to: URL(fileURLWithPath: biosInLib))
                    continue
                } else {
                    isComplete = false
                    break
                }
            }
            return isComplete
        }
        
        return (isComplete(biosItems: dsBiosItems), isComplete(biosItems: dsiBiosItems))
    }
    
    var manufacturer: Manufacturer {
        switch self {
        case ._3ds, .ds, .gb, .gba, .gbc, .nes, .fds, .snes, .vb, .pm, .n64, .ns, .gc, .wii:
            return .nintendo
        case .ps1, .psp:
            return .sony
        case .md, .mcd, ._32x, .sg1000, .gg, .ms, .ss, .dc:
            return .sega
        case .arcade, .doom:
            return .arcade
        case .a2600, .a5200, .a7800, .jaguar, .lynx:
            return .atari
        case .j2me:
            return .sun
        case .xbox360, .dos, .win95, .win98:
            return .microsoft
        case .chm:
            return .modRetro
        default:
            return .nintendo
        }
    }
    
    var supportAnalogInput: Bool {
        switch self {
        case .psp, ._3ds, .arcade, .dc, .ps1, .n64, .dos, .gc:
            return true
        default: return false
        }
    }
    
    var coreConfigIcon: UIImage? {
        switch self {
        case .dos:
            return R.image.customDos()
        case .j2me:
            return R.image.customJava()
        default:
            return nil
        }
    }
    
    var coreConfigTitle: String {
        localizedShortName + R.string.localizable.tabbarTitleSettings()
    }
}

///让GameType支持realm的存储
extension GameType: @retroactive PersistableEnum {
    public static var allCases: [GameType] {
        System.allCases.map { $0.gameType }
    }
}
