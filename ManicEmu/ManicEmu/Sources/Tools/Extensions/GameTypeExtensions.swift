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
    static var multiPlatformFileExtensions = ["chd", "iso", "bin", "cue", "m3u", "pbp", "ccd", "zip", "7z", "elf", "dol", "rvz", "wad", "prg"]
    
    static func gameTypes(multiPlatformFileExtension: String) -> [GameType] {
        let ext = multiPlatformFileExtension.lowercased()
        guard multiPlatformFileExtensions.contains(ext) else { return [] }
        switch ext {
        case "chd":
            return [.ps1, .psp, .mcd, .ss, .dc, .pce, .amiga]
        case "iso":
            return [.psp, .mcd, .ss, .dos, .ngc, .wii, .amiga]
        case "bin":
            return [.ps1, .md, .gg, .ms, ._32x, .dc, .a2600, .a5200, .a7800, .jaguar, .c64]
        case "cue":
            return [.ps1, .mcd, .ss, .dc, .dos, .pce, .amiga]
        case "m3u":
            return [.ps1, .mcd, .ss, .dc, .dos, .pce, .c64, .amiga, .ngc]
        case "pbp":
            return [.ps1, .psp]
        case "ccd":
            return [.ps1, .ss, .pce, .amiga]
        case "zip":
            return [.arcade, .dos, .c64, .amiga]
        case "7z":
            return [.amiga]
        case "elf":
            return [.psp, .ngc, .wii]
        case "dol":
            return [.ngc, .wii]
        case "rvz":
            return [.ngc, .wii]
        case "wad":
            return [.doom, .wii]
        case "prg":
            return [.c64, .jaguar]
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
        } else if ["sis", "sisx", "n-gage"].contains(ext) {
            self = .symbian
        } else if ["gcm", "gcz"].contains(ext) {
            self = .ngc
        } else if ["wbfs", "ciso", "wia"].contains(ext) {
            self = .wii
        } else if ["pce", "sgx", "toc"].contains(ext) {
            self = .pce
        } else if ["ngp", "ngc", "ngpc", "npc"].contains(ext) {
            self = .ngp
        } else if ["d64", "d71", "d80", "d81", "d82", "g64", "g41", "x64", "t64", "tap", "prg", "p00", "crt", "d6z", "d7z", "d8z", "g6z", "g4z", "x6z", "cmd", "vfl", "vsf", "nib", "nbz", "d2m", "d4m", "gz"].contains(ext) {
            self = .c64
        } else if ["adf", "adz", "dms", "fdi", "ipf", "hdf", "hdz", "lha", "slave", "info", "nrg", "mds", "uae", "rp9"].contains(ext) {
            self = .amiga
        } else if ["ws", "wsc", "pc2", "pcv2"].contains(ext) {
            self = .wsc
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
        } else if shortName.uppercased() == "PS2" {
            self = .ps2
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
        } else if shortName.uppercased() == "XBOX360" {
            self = .xbox360
        } else if shortName.uppercased() == "J2ME" {
            self = .j2me
        } else if shortName.uppercased() == "DOS" {
            self = .dos
        } else if shortName.uppercased() == "XBOX" {
            self = .xbox
        } else if shortName.uppercased() == "Symbian".uppercased() {
            self = .symbian
        } else if shortName.uppercased() == "NGC" {
            self = .ngc
        } else if shortName.uppercased() == "Wii".uppercased() {
            self = .wii
        } else if shortName.uppercased() == "PCE" {
            self = .pce
        } else if shortName.uppercased() == "NGP" {
            self = .ngp
        } else if shortName.uppercased() == "C64" {
            self = .c64
        } else if shortName.uppercased() == "Amiga".uppercased() {
            self = .amiga
        } else if shortName.uppercased() == "WSC" {
            self = .wsc
        } else if shortName.uppercased() == "WS" {
            self = .ws
        } else {
            return nil
        }
    }
    
    var localizedName: String {
        switch self
        {
        case .nes: return Locale.prefersUS ? "Nintendo Entertainment System" : "Family Computer"
        case .fds: return "Famicom Disk System"
        case .snes: return Locale.prefersUS ? "Super Nintendo Entertainment System" : "Super Famicom"
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
        case .ps2: return "PlayStation 2"
        case .dc: return "Dreamcast"
        case .doom: return "DOOM"
        case .arcade: return "Arcade"
        case .ns: return "Nintendo Switch"
        case .a2600: return "Atari 2600"
        case .a5200: return "Atari 5200 SuperSystem"
        case .a7800: return "Atari 7800 ProSystem"
        case .jaguar: return "Atari Jaguar"
        case .lynx: return "Atari Lynx"
        case .j2me: return "Java ME"
        case .xbox360: return "Xbox 360"
        case .dos: return "MS-DOS"
        case .win95: return "Windows 95"
        case .win98: return "Windows 98"
        case .xbox: return "Xbox"
        case .symbian: return "Symbian OS"
        case .ngc: return "Nintendo GameCube"
        case .wii: return "Nintendo Wii"
        case .pce: return "PC Engine"
        case .turbografx_16: return "TurboGrafx-16"
        case .turbografx_cd: return "TurboGrafx-CD"
        case .supergrafx: return "SuperGrafx"
        case .ngp: return "Neo Geo Pocket"
        case .ngpc: return "Neo Geo Pocket Color"
        case .c64: return "Commodore 64"
        case .amiga: return "Commodore Amiga"
        case .wsc: return "WonderSwan Color"
        case .ws: return "WonderSwan"
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
        case .ps2: return NSLocalizedString("PS2", comment: "")
        case .dc: return NSLocalizedString("DC", comment: "")
        case .doom: return NSLocalizedString("DOOM", comment: "")
        case .arcade: return NSLocalizedString("Arcade", comment: "")
        case .ns: return  NSLocalizedString("NS", comment: "")
        case .a2600: return  NSLocalizedString("2600", comment: "")
        case .a5200: return  NSLocalizedString("5200", comment: "")
        case .a7800: return  NSLocalizedString("7800", comment: "")
        case .jaguar: return  NSLocalizedString("JAGUAR", comment: "")
        case .lynx: return  NSLocalizedString("LYNX", comment: "")
        case .j2me: return  NSLocalizedString("J2ME", comment: "")
        case .xbox360: return  NSLocalizedString("XBOX360", comment: "")
        case .dos: return  NSLocalizedString("DOS", comment: "")
        case .win95: return  NSLocalizedString("WIN95", comment: "")
        case .win98: return  NSLocalizedString("WIN98", comment: "")
        case .xbox: return  NSLocalizedString("XBOX", comment: "")
        case .symbian: return  NSLocalizedString("Symbian", comment: "")
        case .ngc: return  NSLocalizedString("NGC", comment: "")
        case .wii: return  NSLocalizedString("Wii", comment: "")
        case .pce: return  NSLocalizedString("PCE", comment: "")
        case .turbografx_16: return  NSLocalizedString("TG-16", comment: "")
        case .turbografx_cd: return  NSLocalizedString("TG-CD", comment: "")
        case .supergrafx: return  NSLocalizedString("SGX", comment: "")
        case .ngp: return  NSLocalizedString("NGP", comment: "")
        case .ngpc: return  NSLocalizedString("NGPC", comment: "")
        case .c64: return  NSLocalizedString("C64", comment: "")
        case .amiga: return  NSLocalizedString("Amiga", comment: "")
        case .wsc: return  NSLocalizedString("WSC", comment: "")
        case .ws: return  NSLocalizedString("WS", comment: "")
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
        case .ps2: return 2000
        case .dc: return 1998
        case .doom: return 1993
        case .arcade: return 1971
        case .ns: return 2017
        case .a2600: return 1977
        case .a5200: return 1982
        case .a7800: return 1986
        case .lynx: return 1989
        case .jaguar: return 1993
        case .j2me: return 1999
        case .xbox360: return 2005
        case .dos: return 1981
        case .win95: return 1995
        case .win98: return 1998
        case .xbox: return 2001
        case .symbian: return 2003
        case .ngc: return 2001
        case .wii: return 2006
        case .pce: return 1987
        case .turbografx_16: return 1989
        case .turbografx_cd: return 1989
        case .supergrafx: return 1989
        case .ngp: return 1998
        case .ngpc: return 1999
        case .c64: return 1982
        case .amiga: return 1985
        case .wsc: return 2000
        case .ws: return 1999
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
        case .j2me: return J2ME.core
        case .dos: return DOS.core
        case .symbian: return Symbian.core
        case .ngc: return NGC.core
        case .wii: return Wii.core
        case .pce: return PCE.core
        case .ngp: return NGP.core
        case .c64: return C64.core
        case .amiga: return Amiga.core
        case .wsc: return WSC.core
        default: return nil
        }
    }
    
    /**
     "/system/a26" 2600
     "/system/jag" Jaguar
     "/system/lnx" Lynx
     "/system/3do" 3DO Interactive
     "/system/pcd" PC Engine CD/TurboGrafx16
     "/system/pce" PC Engine/TurboGrafx16
     "/system/cdi" Philips CD-i
     "/system/gam" Tiger Game.com
     "/system/ws" WonderSwan
     "/system/wsc" WonderSwan Color
     "/system/dc" Dreamcast
     "/system/gg" Game Gear
     "/system/32x" Genesis 32X
     "/system/gen" Genesis/Mega Drive
     "/system/sms" Master System
     "/system/sat" Saturn
     "/system/scd" Sega CD
     "/system/fds" Famicom Disk System
     "/system/gb" Game Boy
     "/system/gba" Game Boy Advance
     "/system/gbc" Game Boy Color
     "/system/ngc" Gamecube
     "/system/3ds" Nintendo 3DS
     "/system/3dsd" Nintendo 3DS (DLC)
     "/system/n64" Nintendo 64
     "/system/nds" Nintendo DS
     "/system/nes" Nintendo Entertainment System
     "/system/nsw" Nintendo Switch
     "/system/snes" Super Nintendo
     "/system/nvb" Virtual Boy
     "/system/wii" Wii
     "/system/wdl" Wii (DLC)
     "/system/msx" MSX
     "/system/psx" Playstation
     "/system/ps2" Playstation 2
     "/system/ps3" Playstation 3
     "/system/ps3n" Playstation 3 (PSN)
     "/system/psp" Playstation Portable
     "/system/pspn" Playstation Portable (PSN)
     "/system/psv" Playstation Vita
     "/system/psvn" Playstation Vita (PSN)
     "/system/neo" SNK Neo Geo
     "/system/ngp" SNK Neo Geo Pocket
     "/system/ngpc" SNK Neo Geo Pocket Color
     "/system/pc" PC
     */
    var gamehackingSystem: String? {
        switch self {
        case .md: return "gen"
        case .mcd: return "scd"
        case .sg1000: return nil
        case .ms: return "sms"
        case .ss: return "sat"
        case .vb: return "nvb"
        case .pm: return nil
        case .ps1: return "psx"
        case .doom: return nil
        case .arcade: return nil
        case .a2600: return "a26"
        case .a5200: return nil
        case .a7800: return nil
        case .jaguar: return "jag"
        case .lynx: return "lnx"
        case .j2me: return nil
        case .dos: return nil
        case .symbian: return nil
        case .pce, .turbografx_16: return "pce"
        case .turbografx_cd: return "pcd"
        case .supergrafx: return "pce"
        default: return localizedShortName.lowercased()
        }
    }
    
    func reuseGameType() -> GameType {
        if self == .mcd || self == ._32x {
            return .md
        } else if self == .fds {
            return .nes
        } else if self == .doom || self == .c64 || self == .amiga {
            return .dos
        }
        return self
    }
    
    var supportCores: [String] {
        if self == .ss {
            return [EmulationCore.BeetleSaturn.name, EmulationCore.Yabause.name]
        } else if self == .gba {
            return [EmulationCore.mGBA.name, EmulationCore.VBAM.name, EmulationCore.gpSP.name]
        } else if self == .md {
#if SIDE_LOAD
            return [EmulationCore.ClownMDEmu.name, EmulationCore.PicoDrive.name]
#endif
        } else if self == .ms || self == .gg || self == .sg1000 {
#if SIDE_LOAD
            return [EmulationCore.Gearsystem.name, EmulationCore.PicoDrive.name]
#endif
        } else if self == .gb || self == .gbc {
            return [EmulationCore.Gambatte.name, EmulationCore.mGBA.name, EmulationCore.VBAM.name, EmulationCore.MesenS.name]
        } else if self == .arcade {
#if SIDE_LOAD
            return [EmulationCore.MAME.name, EmulationCore.FinalBurnNeo.name]
#endif
        } else if self == ._3ds {
            return [EmulationCore.Citra.name, EmulationCore.Azahar.name]
        } else if self == ._32x {
#if SIDE_LOAD
            return [EmulationCore.PicoDrive.name, EmulationCore.JGenesis.name]
#endif
        } else if self == .mcd {
#if SIDE_LOAD
            return [EmulationCore.PicoDrive.name, EmulationCore.JGenesis.name, EmulationCore.ClownMDEmu.name]
#else
            return ["", EmulationCore.JGenesis.name, EmulationCore.ClownMDEmu.name]
#endif
        } else if self == .ds {
            return [EmulationCore.melonDSDS.name, EmulationCore.DeSmuME.name]
        } else if self == .j2me {
            return [EmulationCore.J2meJS.name, EmulationCore.freej2me.name]
        } else if self == .ps1 {
            return [EmulationCore.BeetlePSXHW.name, EmulationCore.PCSXReArmed.name]
        } else if self == .snes {
#if SIDE_LOAD
            return [EmulationCore.bsnes.name, EmulationCore.Snes9x.name, EmulationCore.MesenS.name]
#else
            return [EmulationCore.bsnes.name, "", EmulationCore.MesenS.name]
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
        } else if self == .dos || self == .doom || self == .c64 || self == .amiga {
            return [.dos, .doom, .c64, .amiga]
        }
        return [self]
    }
    
    /// Platforms that reuse DOS joypad/keyboard skins.
    var supportsKeyboardSkin: Bool {
        self == .dos || self == .c64 || self == .amiga
    }
    
    /// Default/FLEX skin layout inherited from DOS (includes DOOM).
    var usesDOSSkinLayout: Bool {
        self == .dos || self == .doom || self == .c64 || self == .amiga
    }
    
    func isNDSBiosComplete() -> (isDSComplete: Bool, isDsiComplete: Bool) {
        guard self == .ds else { return (false, false) }
        let dsBiosItems = R.BIOS.DSBios.filter({ !$0.fileName.hasPrefix("dsi_") })
        let dsiBiosItems = R.BIOS.DSBios.filter({ $0.fileName.hasPrefix("dsi_") })
        
        func isComplete(biosItems: [BIOSItem]) -> Bool {
            var isComplete = true
            let fileManager = FileManager.default
            for bios in biosItems {
                let biosInLib = R.Path.System.appendingPathComponent(bios.fileName)
                let biosInDoc = R.Path.BIOS.appendingPathComponent(bios.fileName)
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
        case ._3ds, .ds, .gb, .gba, .gbc, .nes, .fds, .snes, .vb, .pm, .n64, .ns, .ngc, .wii:
            return .nintendo
        case .ps1, .ps2, .psp:
            return .sony
        case .md, .mcd, ._32x, .sg1000, .gg, .ms, .ss, .dc:
            return .sega
        case .arcade, .doom:
            return .arcade
        case .a2600, .a5200, .a7800, .jaguar, .lynx:
            return .atari
        case .j2me:
            return .sun
        case .xbox360, .dos, .win95, .win98, .xbox:
            return .microsoft
        case .chm:
            return .modRetro
        case .symbian:
            return .nokia
        case .pce, .turbografx_16, .turbografx_cd, .supergrafx:
            return .nec
        case .ngp, .ngpc:
            return .snk
        case .c64, .amiga:
            return .commodore
        case .wsc, .ws:
            return .bandai
        default:
            return .nintendo
        }
    }
    
    var supportAnalogInput: Bool {
        switch self {
        case .psp, ._3ds, .arcade, .dc, .ps1, .n64, .dos, .ngc, .wii, .c64, .amiga:
            return true
        default: return false
        }
    }
    
    var coreConfigIcon: ASIcon {
        switch self {
        case .dos:
            return .symbolImage(R.image.customDos())
        case .j2me:
            return .symbolImage(R.image.j2mesettings_iconSymbols())
        default:
            return .symbol(.sliderHorizontal3)
        }
    }
    
    var coreConfigTitle: String {
        localizedShortName + R.string.localizable.tabbarTitleSettings()
    }
    
    private static var brandImageCaches = [String: UIImage?]()
    var brandImage: UIImage? {
        let key = "\(localizedShortName)_\(Settings.appearance.rawValue)"
        if let image = Self.brandImageCaches[key] {
            return image
        } else {
            var image: UIImage? = nil
            if self == ._3ds {
                image = R.image.sds_group_brand()
            } else if self == .ds {
                image = R.image.ds_group_brand()
            } else if self == .gba {
                image = R.image.gba_group_brand()
            } else if self == .gbc {
                image = R.image.gbc_group_brand()
            } else if self == .gb {
                image = R.image.gb_group_brand()
            } else if self == .nes {
                image = R.image.nes_group_brand()
            } else if self == .fds {
                image = R.image.fds_group_brand()
            } else if self == .snes {
                image = R.image.snes_group_brand()
            } else if self == .psp {
                image = R.image.psp_group_brand()
            } else if self == .md {
                if Locale.prefersUS {
                    image = R.image.md_group_brand_us()
                } else {
                    image = R.image.md_group_brand()
                }
            } else if self == .mcd {
                if Locale.prefersUS {
                    image = R.image.mcd_group_brand_us()
                } else {
                    image = R.image.mcd_group_brand()
                }
            } else if self == ._32x {
                if Locale.prefersUS {
                    image = R.image.s2x_group_brand_us()
                } else {
                    image = R.image.s2x_group_brand()
                }
            } else if self == .ss {
                image = R.image.ss_group_brand()
            } else if self == .sg1000 {
                image = R.image.sg1000_group_brand()
            } else if self == .gg {
                image = R.image.gg_group_brand()
            } else if self == .ms {
                image = R.image.ms_group_brand()
            } else if self == .n64 {
                image = R.image.n64_group_brand()
            } else if self == .vb {
                image = R.image.vb_group_brand()
            } else if self == .pm {
                image = R.image.pm_group_brand()
            } else if self == .ps1 {
                image = R.image.ps1_group_brand()
            } else if self == .dc {
                image = R.image.dc_group_brand()
            } else if self == .arcade {
                image = R.image.arcade_group_brand()
            } else if self == .ns {
                image = R.image.ns_group_brand()
            } else if self == .a2600 {
                image = R.image.a2600_group_brand()
            } else if self == .a5200 {
                image = R.image.a5200_group_brand()
            } else if self == .a7800 {
                image = R.image.a7800_group_brand()
            } else if self == .jaguar {
                image = R.image.jaguar_group_brand()
            } else if self == .lynx {
                image = R.image.lynx_group_brand()
            } else if self == .xbox360 {
                image = R.image.xbox360_group_brand()
            } else if self == .j2me {
                image = R.image.j2me_group_brand()
            } else if self == .doom {
                image = R.image.doom_group_brand()
            } else if self == .dos {
                image = R.image.dos_group_brand()
            } else if self == .chm {
                image = R.image.chm_group_brand()
            } else if self == .win95 {
                image = R.image.win95_group_brand()
            } else if self == .win98 {
                image = R.image.win98_group_brand()
            } else if self == .xbox {
                image = R.image.xbox_group_brand()
            } else if self == .symbian {
                image = R.image.symbian_group_brand()
            } else if self == .ngc {
                image = R.image.ngc_group_brand()
            } else if self == .wii {
                image = R.image.wii_group_brand()
            } else if self == .pce {
                image = R.image.pce_group_brand()
            } else if self == .turbografx_16 {
                image = R.image.turbografx_16_group_brand()
            } else if self == .turbografx_cd {
                image = R.image.turbografx_cd_group_brand()
            } else if self == .supergrafx {
                image = R.image.supergrafx_group_brand()
            } else if self == .ngp {
                image = R.image.ngp_group_brand()
            } else if self == .ngpc {
                image = R.image.ngp_color_group_brand()
            } else if self == .c64 {
                image = R.image.c64_group_brand()
            } else if self == .amiga {
                image = R.image.amiga_group_brand()
            } else if self == .wsc {
                image = R.image.wsc_group_brand()
            } else if self == .ws {
                image = R.image.ws_group_brand()
            } else if self == .ps2 {
                image = R.image.ps2_group_brand()
            }
            Self.brandImageCaches[key] = image
            return image
        }
    }
    
    var externalType: Bool {
        if self == .ns ||
            self == .xbox360 ||
            self == .xbox ||
            self == .ps2 {
            return true
        }
        return false
    }
    
    var supportShaders: Bool {
        if self == .j2me ||
            externalType {
            return false
        }
        return true
    }
    
    var biosItems: [BIOSItem] {
        if self == .mcd {
            return R.BIOS.MegaCDBios
        } else if self == .ss {
            return R.BIOS.SaturnBios
        } else if self == .ds {
            return R.BIOS.DSBios
        } else if self == .ps1 {
            return R.BIOS.PS1Bios
        } else if self == .dc {
            return R.BIOS.DCBios
        }  else if self == .gb {
            return R.BIOS.GBBios
        }  else if self == .gbc {
            return R.BIOS.GBCBios
        }  else if self == .gba {
            return R.BIOS.GBABios
        }  else if self == .fds {
            return R.BIOS.FDSBios
        }  else if self == .pm {
            return R.BIOS.PMBios
        } else if self == ._3ds {
            return R.BIOS.ThreeDSBios
        } else if self == .arcade {
            return R.BIOS.ArcadeDSBios
        } else if self == .a5200 {
            return R.BIOS.A5200Bios
        } else if self == .a7800 {
            return R.BIOS.A7800Bios
        } else if self == .lynx {
            return R.BIOS.LynxBios
        } else if self == .pce {
            return R.BIOS.PCEBios
        } else if self == .c64 {
            return R.BIOS.C64Bios
        } else if self == .amiga {
            return R.BIOS.AmigaBios
        } else if self == .symbian {
            return [BIOSItem(fileName: R.string.localizable.symbianOSFirmware(),
                             imported: false,
                             desc: R.string.localizable.symbianOSFirmwareDesc(),
                             required: true)]
        } else if self == .ngc {
            return [BIOSItem(fileName: "IPL.bin",
                             imported: false,
                             desc: R.string.localizable.biosCommondDesc(),
                             required: false)]
        } else if self == .wii {
            return R.BIOS.WiiBios
        }
        return []
    }
}

///让GameType支持realm的存储
extension GameType: @retroactive PersistableEnum {
    public static var allCases: [GameType] {
        System.allCases.map { $0.gameType }
    }
}
