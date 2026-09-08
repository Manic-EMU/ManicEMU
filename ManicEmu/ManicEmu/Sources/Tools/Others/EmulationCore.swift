//
//  EmulationCore.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/3.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

enum EmulationCore: CaseIterable {
    case Nestopia,
         Snes9x,
         PicoDrive,
         Yabause,
         BeetleSaturn,
         Mupen64PlushNext,
         BeetleVB,
         PokeMini,
         BeetlePSXHW,
         bsnes,
         Gambatte,
         VBAM,
         mGBA,
         Flycast,
         Gearsystem,
         ClownMDEmu,
         bsnesJG,
         melonDSDS,
         PPSSPP,
         MAME,
         FinalBurnNeo,
         Citra,
         Azahar,
         JGenesis,
         DeSmuME,
         Stella,
         Atari800,
         ProSystem,
         VirtualJaguar,
         Holani,
         J2meJS,
         freej2me,
         PrBoom,
         DOSBoxPure,
         PCSXReArmed,
         EKA2L1,
         Dolphin,
         BeetlePCE,
         BeetleNeoPop,
         VICEx64sc,
         PUAE,
         gpSP,
         MesenS,
         Symbian
    
    var name: String {
        switch self {
        case .Nestopia:
            "Nestopia"
        case .Snes9x:
            "Snes9x"
        case .PicoDrive:
            "PicoDrive"
        case .Yabause:
            "Yabause"
        case .BeetleSaturn:
            "Beetle Saturn"
        case .Mupen64PlushNext:
            "Mupen64Plus-Next"
        case .BeetleVB:
            "Beetle VB"
        case .PokeMini:
            "PokeMini"
        case .BeetlePSXHW:
            "Beetle PSX HW"
        case .bsnes:
            "bsnes"
        case .Gambatte:
            "Gambatte"
        case .VBAM:
            "VBA-M"
        case .mGBA:
            "mGBA"
        case .Flycast:
            "Flycast"
        case .ClownMDEmu:
            "ClownMDEmu"
        case .Gearsystem:
            "Gearsystem"
        case .bsnesJG:
            "bsnes-jg"
        case .melonDSDS:
            "melonDS DS"
        case .PPSSPP:
            "PPSSPP"
        case .MAME:
            "MAME"
        case .FinalBurnNeo:
            "FinalBurn Neo"
        case .PrBoom:
            "PrBoom"
        case .Citra:
            "Citra"
        case .Azahar:
            "Azahar"
        case .JGenesis:
            "JGenesis"
        case .DeSmuME:
            "DeSmuME"
        case .Stella:
            "Stella"
        case .Atari800:
            "Atari800"
        case .ProSystem:
            "ProSystem"
        case .VirtualJaguar:
            "Virtual Jaguar"
        case .Holani:
            "Holani"
        case .J2meJS:
            "J2meJS"
        case .freej2me:
            "freej2me"
        case .DOSBoxPure:
            "DOSBox-pure"
        case .PCSXReArmed:
            "PCSX-ReARMed"
        case .EKA2L1:
            "EKA2L1"
        case .Dolphin:
            "dolphin-emu"
        case .BeetlePCE:
            "Beetle PCE"
        case .BeetleNeoPop:
            "Beetle NeoPop"
        case .VICEx64sc:
            "VICE x64sc"
        case .PUAE:
            "PUAE"
        case .gpSP:
            "gpSP"
        case .MesenS:
            "Mesen-S"
        case .Symbian:
            "Symbian"
        }
    }
    
    static var nonCommercialCores: Set<Self> {
        return [.PicoDrive, .FinalBurnNeo, .Snes9x]
    }
    
    var gameTypes: [GameType]? {
#if !SIDE_LOAD
        //The non-commercial core is only available when sideloaded.
        if Self.nonCommercialCores.contains(self) {
            return nil
        }
#endif
        switch self {
        case .Nestopia:
            return [.nes]
        case .Snes9x, .bsnes, .bsnesJG:
            return [.snes]
        case .PicoDrive:
            return [._32x, .mcd, .md, .sg1000, .gg, .ms]
        case .Yabause, .BeetleSaturn:
            return [.ss]
        case .Mupen64PlushNext:
            return [.n64]
        case .BeetleVB:
            return [.vb]
        case .PokeMini:
            return [.pm]
        case .BeetlePSXHW, .PCSXReArmed:
            return [.ps1]
        case .Gambatte:
            return [.gbc, .gb]
        case .VBAM, .mGBA:
            return [.gba, .gbc, .gb]
        case .Flycast:
            return [.dc]
        case .Gearsystem:
            return [.gg]
        case .ClownMDEmu:
            return [.md]
        case .melonDSDS, .DeSmuME:
            return [.ds]
        case .PPSSPP:
            return [.psp]
        case .MAME, .FinalBurnNeo:
            return [.arcade]
        case .Citra, .Azahar:
            return [._3ds]
        case .JGenesis:
            return [._32x, .mcd]
        case .Stella:
            return [.a2600]
        case .Atari800:
            return [.a5200]
        case .ProSystem:
            return [.a7800]
        case .VirtualJaguar:
            return [.jaguar]
        case .Holani:
            return [.lynx]
        case .J2meJS, .freej2me:
            return [.j2me]
        case .PrBoom:
            return [.doom]
        case .DOSBoxPure:
            return [.dos]
        case .EKA2L1:
            return [.symbian]
        case .Dolphin:
            return [.ngc, .wii]
        case .BeetlePCE:
            return [.pce]
        case .BeetleNeoPop:
            return [.ngp]
        case .VICEx64sc:
            return [.c64]
        case .PUAE:
            return [.amiga]
        case .gpSP:
            return [.gba]
        case .MesenS:
            return [.snes, .gb, .gbc]
        case .Symbian:
            return [.symbian]
        }
    }
    
    var isLibretroCore: Bool {
        if self == .Citra ||
            self == .J2meJS ||
            self == .JGenesis ||
            self == .freej2me ||
            self == .Symbian {
            return false
        }
        return true
    }
    
    static var libretroCores: [Self] {
        return allCases.filter({
#if SIDE_LOAD
            return $0.isLibretroCore
#else
            return $0.isLibretroCore && !nonCommercialCores.contains($0)
#endif
        })
    }
    
    /// RA netplay: .info `savestate_features` is deterministic (or omitted) *and*
    /// libretro docs do not mark Netplay unsupported. serialized/basic/no-savestate
    /// cores are out, except netpacket cores (DOSBox-pure, melonDS DS, Virtual Jaguar)
    /// and Holani (docs: state-based netplay).
    var supportNetplay: Bool {
        guard isLibretroCore else { return false }
        switch self {
        case .Nestopia,
                .Snes9x,
                .PicoDrive,
                .BeetleSaturn,
                .BeetleVB,
                .Gearsystem,
                .ClownMDEmu,
                .MAME,
                .FinalBurnNeo,
                .Stella,
                .DOSBoxPure,
                .BeetlePCE,
                .BeetleNeoPop,
                .gpSP,
                .MesenS:
            return true
        default:
            return false
        }
    }
    
    var supportJit: Bool {
        switch self {
        case .Citra,
                .Azahar,
                .PPSSPP,
                .melonDSDS,
                .Mupen64PlushNext,
                .BeetlePSXHW,
                .Flycast,
                .DOSBoxPure,
                .Symbian,
                .Dolphin:
            return true
        default:
            return false
        }
    }
}
