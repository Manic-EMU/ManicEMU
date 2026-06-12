//
//  System.swift
//  Delta
//
//  Created by Riley Testut on 4/30/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later



enum System: CaseIterable
{
    case dos
    case doom
    case j2me
    case xbox360
    case wii
    case gc
    case jaguar
    case lynx
    case a7800
    case a5200
    case a2600
    case ns
    case arcade
    case dc
    case ps1
    case pm
    case vb
    case n64
    case ss
    case ms
    case gg
    case sg1000
    case _32x
    case mcd
    case md
    case psp
    case _3ds
    case ds
    case gba
    case gbc
    case gb
    case nes
    case fds
    case snes

    static var registeredSystems: [System] {
        let systems = System.allCases.filter { Delta.registeredCores.keys.contains($0.gameType) }
        return systems
    }
    
    static var allCores: [DeltaCoreProtocol] {
        return [NES.core, SNES.core, ThreeDS.core, Wii.core, GameCube.core, GBC.core, GBA.core, PSP.core, MD.core, MCD.core, S2X.core, SG1000.core, GG.core, MS.core, SS.core, N64.core, GB.core, VB.core, PM.core, PS1.core, DC.core, DS.core, FDS.core, Arcade.core, A2600.core, A5200.core, A7800.core, Lynx.core, Jaguar.core, J2ME.core, DOOM.core, DOS.core]
    }
}

extension System {
    
    var gameType: GameType {
        switch self
        {
        case .nes: return .nes
        case .snes: return .snes
        case ._3ds: return ._3ds
        case .gbc: return .gbc
        case .gb: return .gb
        case .gba: return .gba
        case .ds: return .ds
        case .psp: return .psp
        case .md: return .md
        case .mcd: return .mcd
        case ._32x: return ._32x
        case .sg1000: return .sg1000
        case .gg: return .gg
        case .ms: return .ms
        case .ss: return .ss
        case .n64: return .n64
        case .vb: return .vb
        case .pm: return .pm
        case .ps1: return .ps1
        case .dc: return .dc
        case .fds: return .fds
        case .arcade: return .arcade
        case .doom: return .doom
        case .ns: return .ns
        case .a2600: return .a2600
        case .a5200: return .a5200
        case .a7800: return .a7800
        case .jaguar: return .jaguar
        case .lynx: return .lynx
        case .j2me: return .j2me
        case .xbox360: return .xbox360
        case .wii: return .wii
        case .gc: return .gc
        case .dos: return .dos
        }
    }
}
