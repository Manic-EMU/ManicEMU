//
//  Manufacturer.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/12.
//  Copyright © 2025 Manic EMU. All rights reserved.
//



enum Manufacturer: Int, CaseIterable {
    case nintendo, sony, sega, arcade, atari, sun, microsoft, modRetro, nokia, nec, snk, commodore, bandai, adobe
    
    static var allCases: [Manufacturer] {
        if Locale.prefersUS {
            [.nintendo, .sony, .sega, .atari, .arcade, .sun, .microsoft, .modRetro, .nokia, .nec, .snk, .commodore, .bandai, .adobe]
        } else {
            [.nintendo, .sony, .sega, .arcade, .atari, .sun, .microsoft, .modRetro, .nokia, .nec, .snk, .commodore, .bandai, .adobe]
        }
    }
    
    init?(title: String) {
        if let m = Manufacturer.allCases.first(where: { $0.title == title }) {
            self = m
        } else {
            return nil
        }
    }
    
    var title: String {
        switch self {
        case .nintendo:
            "Nintendo"
        case .sony:
            "SONY"
        case .sega:
            "SEGA"
        case .arcade:
            "Arcade"
        case .atari:
            "Atari"
        case .sun:
            "Sun"
        case .microsoft:
            "Microsoft"
        case .modRetro:
            "ModRetro"
        case .nokia:
            "Nokia"
        case .nec:
            "NEC"
        case .snk:
            "SNK"
        case .commodore:
            "Commodore"
        case .bandai:
            "Bandai"
        case .adobe:
            "Adobe"
        }
    }
    
    var gameTypes: [GameType] {
        if self == .modRetro {
            return [.chm]
        }
        return System.allGameTypes.filter({ $0.manufacturer == self })
    }
    
    var normalImage: UIImage {
        switch self {
        case .nintendo:
            R.image.nintendo_normal()!
        case .sony:
            R.image.sony_normal()!
        case .sega:
            R.image.sega_normal()!
        case .arcade:
            R.image.arcade_normal()!
        case .atari:
            R.image.atari_normal()!
        case .sun:
            R.image.sun_normal()!
        case .microsoft:
            R.image.microsoft_normal()!
        case .modRetro:
            R.image.modretro_normal()!
        case .nokia:
            R.image.nokia_normal()!
        case .nec:
            R.image.nec_normal()!
        case .snk:
            R.image.snk_normal()!
        case .commodore:
            R.image.commodore_normal()!
        case .bandai:
            R.image.bandai_normal()!
        case .adobe:
            R.image.adobe_normal()!
        }
    }
    
    var highlightImage: UIImage {
        switch self {
        case .nintendo:
            R.image.nintendo_highlight()!
        case .sony:
            R.image.sony_highlight()!
        case .sega:
            R.image.sega_highlight()!
        case .arcade:
            R.image.arcade_highlight()!
        case .atari:
            R.image.atari_highlight()!
        case .sun:
            R.image.sun_highlight()!
        case .microsoft:
            R.image.microsoft_highlight()!
        case .modRetro:
            R.image.modretro_highlight()!
        case .nokia:
            R.image.nokia_highlight()!
        case .nec:
            R.image.nec_highlight()!
        case .snk:
            R.image.snk_highlight()!
        case .commodore:
            R.image.commodore_highlight()!
        case .bandai:
            R.image.bandai_highlight()!
        case .adobe:
            R.image.adobe_highlight()!
        }
    }
}
