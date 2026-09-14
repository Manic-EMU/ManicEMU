//
//  GameOptionTypes.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/17.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import RealmSwift

extension GameOption {
    enum Scene {
        case common
        case gameInfo
        case gaming
    }
    
    enum Accessory {
        case chevron(String?)
        case `switch`(ASSwitch.State)
        case image(ASIcon)
        
        var chevronValue: (isChevron: Bool, string: String?)? {
            if case let .chevron(string) = self {
                return (true, string)
            }
            return nil
        }
        
        var switchValue: ASSwitch.State? {
            if case let .switch(state) = self {
                return state
            }
            return nil
        }
        
        var imageValue: ASIcon? {
            if case let .image(icon) = self {
                return icon
            }
            return nil
        }
    }
    
    enum ControllerType: Int, PersistableEnum {
        case dPad, thumbStick
        
        var image: UIImage {
            switch self {
            case .dPad:
                UIImage(symbol: .dpad)
            case .thumbStick:
                R.image.customArcadeStick()!.applySymbolConfig()
            }
        }
        
        var title: String {
            switch self {
            case .dPad:
                R.string.localizable.gameSettingControllerTypeDPad()
            case .thumbStick:
                R.string.localizable.gameSettingControllerTypeStick()
            }
        }
        
        var next: ControllerType {
            return self == .dPad ? .thumbStick : .dPad
        }
    }
    
    enum HapticType: Int, PersistableEnum {
        case off, soft, light, medium, heavy, rigid
        
        var image: UIImage {
            switch self {
            case .off:
                UIImage(symbol: .iphoneSlash)
            default:
                UIImage(symbol: .iphoneRadiowavesLeftAndRight)
            }
        }
        
        var title: String {
            switch self {
            case .off:
                R.string.localizable.gameSettingHapticOff()
            case .soft:
                R.string.localizable.gameSettingHapticSoft()
            case .light:
                R.string.localizable.gameSettingHapticLight()
            case .medium:
                R.string.localizable.gameSettingHapticMedium()
            case .heavy:
                R.string.localizable.gameSettingHapticHeavy()
            case .rigid:
                R.string.localizable.gameSettingHapticRigid()
            }
        }
        
        var next: HapticType {
            if let type = HapticType(rawValue: self.rawValue + 1) {
                return type
            } else {
                return .off
            }
        }
    }
    
    enum OrientationType: Int, PersistableEnum {
        case auto, portrait, landscape
        
        var title: String {
            switch self {
            case .auto:
                R.string.localizable.gameSettingOrientationAuto()
            case .portrait:
                R.string.localizable.gameSettingOrientationPortrait()
            case .landscape:
                R.string.localizable.gameSettingOrientationLandscape()
            }
        }
        
        var next: OrientationType {
            if let type = OrientationType(rawValue: self.rawValue + 1) {
                return type
            } else {
                return .auto
            }
        }
    }
    
    enum FastForwardSpeed: Int, CaseIterable, PersistableEnum  {
        case one = 1, two, three, four, five
        
        var title: String {
            if self == .one {
                return R.string.localizable.gameSettingFastForwardResume()
            } else {
                return R.string.localizable.gameSettingFastForward(" x\(self.rawValue)")
            }
        }
        
        var next: FastForwardSpeed {
            if let speed = FastForwardSpeed(rawValue: self.rawValue + 1) {
                return speed
            } else {
                return .one
            }
        }
    }
    
    //undefine is designed to avoid problems during domain migration
    enum Resolution: Int, CaseIterable, PersistableEnum  {
        case undefine, one, two, three, four, five, six, seven, eight, nine, ten
        
        var title: String {
            return R.string.localizable.gameSettingResolution(self == .undefine ? "x1" : "x\(self.rawValue)")
        }
        
        var next: Resolution {
            if let speed = Resolution(rawValue: self.rawValue + 1) {
                return speed
            } else {
                return .one
            }
        }
        
        //PS1
        static var ResolutionForPS1: [Resolution] { Array(Resolution.allCases[1..<5]) }
        
        static var AllResolutionTitleForPS1: [String] { ["1x", "2x", "4x", "8x"] }
        
        var resolutionTitleForPS1: String {
            let titles = Self.AllResolutionTitleForPS1
            if let index = Self.ResolutionForPS1.firstIndex(of: self), index < titles.count {
                return titles[index]
            }
            return "1x"
        }
        
        var nextForPS1: Resolution {
            if let p = Resolution(rawValue: self.rawValue + 1), Self.ResolutionForPS1.contains([p]) {
                return p
            } else {
                return .one
            }
        }
        
        //N64ParaLLEl
        static var ResolutionForN64ParaLLEl: [Resolution] { Array(Resolution.allCases[1..<4]) }
        
        static var AllResolutionTitleForN64ParaLLEl: [String] { ["1x", "2x", "4x"] }
        
        var resolutionTitleForN64ParaLLEl: String {
            let titles = Self.AllResolutionTitleForN64ParaLLEl
            if let index = Self.ResolutionForN64ParaLLEl.firstIndex(of: self), index < titles.count {
                return titles[index]
            }
            return "1x"
        }
        
        var nextForN64ParaLLEl: Resolution {
            if let p = Resolution(rawValue: self.rawValue + 1), Self.ResolutionForN64ParaLLEl.contains([p]) {
                return p
            } else {
                return .one
            }
        }
    }
    
    enum Palette: Int, CaseIterable, PersistableEnum {
        case None, DMG, Light, Pocket, Blue, Brown, DarkBlue, DarkBrown, DarkGreen, Grayscale, Green, Inverted, Orange, PastelMix, Red, Yellow
        
        var shortTitle: String {
            switch self {
            case .None: R.string.localizable.off()
            case .DMG: "DMG"
            case .Light: "Light"
            case .Pocket: "Pocket"
            case .Blue: "Blue"
            case .Brown: "Brown"
            case .DarkBlue: "Dark Blue"
            case .DarkBrown: "Dark Brown"
            case .DarkGreen: "Dark Green"
            case .Grayscale: "Grayscale"
            case .Green: "Green"
            case .Inverted: "Inverted"
            case .Orange: "Orange"
            case .PastelMix: "Pastel Mix"
            case .Red: "Red"
            case .Yellow: "Yellow"
            }
        }
        
        var optionForGambatte: String {
            switch self {
            case .None:
                R.string.localizable.off()
            case .DMG:
                "GB - DMG"
            case .Light:
                "GB - Light"
            case .Pocket:
                "GB - Pocket"
            case .Blue:
                "GBC - Blue"
            case .Brown:
                "GBC - Brown"
            case .DarkBlue:
                "GBC - Dark Blue"
            case .DarkBrown:
                "GBC - Dark Brown"
            case .DarkGreen:
                "GBC - Dark Green"
            case .Grayscale:
                "GBC - Grayscale"
            case .Green:
                "GBC - Green"
            case .Inverted:
                "GBC - Inverted"
            case .Orange:
                "GBC - Orange"
            case .PastelMix:
                "GBC - Pastel Mix"
            case .Red:
                "GBC - Red"
            case .Yellow:
                "GBC - Yellow"
            }
        }
        
        var optionForMGBA: String {
            switch self {
            case .None:
                "Grayscale"
            case .DMG:
                "DMG Green"
            case .Light:
                "GB Light"
            case .Pocket:
                "GB Pocket"
            case .Blue:
                "GBC Blue ←"
            case .Brown:
                "GBC Brown ↑"
            case .DarkBlue:
                "GBC Dark Blue ←A"
            case .DarkBrown:
                "GBC Dark Brown ↑B"
            case .DarkGreen:
                "GBC Dark Green →A"
            case .Grayscale:
                "GBC Gray ←B"
            case .Green:
                "GBC Green →"
            case .Inverted:
                "GBC Reverse →B"
            case .Orange:
                "GBC Orange ↓A"
            case .PastelMix:
                "GBC Pale Yellow ↓"
            case .Red:
                "GBC Red ↑A"
            case .Yellow:
                "GBC Yellow ↓B"
            }
        }
        
        var optionForVBAM: String {
            switch self {
            case .None:
                "black and white"
            case .DMG:
                "gba sp"
            case .Light:
                "green forest"
            case .Pocket:
                "original gameboy"
            case .Blue:
                "blue sea"
            case .Brown:
                "hot desert"
            case .DarkBlue:
                "blue sea"
            case .DarkBrown:
                "wierd colors"
            case .DarkGreen:
                "green forest"
            case .Grayscale:
                "black and white"
            case .Green:
                "green forest"
            case .Inverted:
                "dark knight"
            case .Orange:
                "hot desert"
            case .PastelMix:
                "wierd colors"
            case .Red:
                "pink dreams"
            case .Yellow:
                "hot desert"
            }
        }
        
        var title: String {
            return R.string.localizable.paletteTitle() +  (self == .None ? "" : "\n") + shortTitle
        }
        
        var next: Palette {
            if let p = Palette(rawValue: self.rawValue + 1) {
                return p
            } else {
                return .None
            }
        }
        
        //For VB
        static var PalettesForVB: [Palette] { Array(Palette.allCases[0..<8]) }
        
        static var AllPaletteTitleForVB: [String] { ["black & red", "black & white", "black & blue", "black & cyan", "black & electric cyan", "black & green", "black & magenta", "black & yellow"] }
        
        var paletteTitleForVB: String {
            let titles = Self.AllPaletteTitleForVB
            if let index = Self.PalettesForVB.firstIndex(of: self), index < titles.count {
                return titles[index]
            }
            return "black & red"
        }
        
        var nextForVB: Palette {
            if let p = Palette(rawValue: self.rawValue + 1), Self.PalettesForVB.contains([p]) {
                return p
            } else {
                return .None
            }
        }
        
        //For PM
        static var PalettesForPM: [Palette] { Array(Palette.allCases[0..<14]) }
        
        static var AllPaletteTitleForPM: [String] { ["Default", "Old", "Monochrome", "Green", "Green Vector", "Red", "Red Vector", "Blue LCD", "LEDBacklight", "Girl Power", "Blue", "Blue Vector", "Sepia", "Monochrome Vector"] }
        
        var paletteTitleForPM: String {
            let titles = Self.AllPaletteTitleForPM
            if let index = Self.PalettesForPM.firstIndex(of: self), index < titles.count {
                return titles[index]
            }
            return "Default"
        }
        
        var nextForPM: Palette {
            if let p = Palette(rawValue: self.rawValue + 1), Self.PalettesForPM.contains([p]) {
                return p
            } else {
                return .None
            }
        }
        
        //For WS
        static var AllPaletteTitleForWS: [String] {
            ["default",
             "wonderswan",
             "wondeswan_color",
             "swancrystal",
             "gb_dmg",
             "gb_pocket",
             "gb_light",
             "blossom_pink",
             "bubbles_blue",
             "buttercup_green",
             "digivice",
             "game_com",
             "gameking",
             "game_master",
             "golden_wild",
             "greenscale",
             "hokage_orange",
             "labo_fawn",
             "legendary_super_saiyan",
             "microvision",
             "million_live_gold",
             "odyssey_gold",
             "shiny_sky_blue",
             "slime_blue",
             "ti_83",
             "travel_wood",
             "virtual_boy"]
        }
    }
    
    enum AirPlayScaling: Int, CaseIterable {
        case coreProvided, square, standard, widescreen, full
        
        var title: String {
            switch self {
            case .coreProvided:
                R.string.localizable.scalingCoreProvided()
            case .square:
                R.string.localizable.scalingSquare()
            case .standard:
                R.string.localizable.scalingStandard()
            case .widescreen:
                R.string.localizable.scalingWidescreen()
            case .full:
                R.string.localizable.scalingFull()
            }
        }
        
        var ratio: CGSize {
            switch self {
            case .coreProvided, .full, .square:
                    .init(1)
            case .standard:
                    .init(width: 4, height: 3)
            case .widescreen:
                    .init(width: 16, height: 9)
            }
        }
        
        var next: AirPlayScaling {
            if let type = AirPlayScaling(rawValue: self.rawValue + 1) {
                return type
            } else {
                return .coreProvided
            }
        }
    }
    
    enum AirPlayLayout: Int, CaseIterable {
        
        case embeddedTopLeft, embeddedTopRight, embeddedBottomLeft, embeddedBottomRight, sideBySide, stacked, largeSmallTopLeft, largeSmallTopRight, largeSmallBottomLeft, largeSmallBottomRight, singleScreen
        
        var title: String {
            switch self {
            case .sideBySide: R.string.localizable.layoutSideBySide()
            case .stacked: R.string.localizable.layoutStacked()
            case .largeSmallTopLeft: R.string.localizable.layoutLargeSmallTopLeft()
            case .largeSmallTopRight: R.string.localizable.layoutLargeTopRight()
            case .largeSmallBottomLeft: R.string.localizable.layoutLargeBottomLeft()
            case .largeSmallBottomRight: R.string.localizable.layoutLargeBottomRight()
            case .embeddedTopLeft: R.string.localizable.layoutEmbeddedTopLeft()
            case .embeddedTopRight: R.string.localizable.layoutEmbeddedTopRight()
            case .embeddedBottomLeft: R.string.localizable.layoutEmbeddedBottomLeft()
            case .embeddedBottomRight: R.string.localizable.layoutEmbeddedBottomRight()
            case .singleScreen: R.string.localizable.layoutSingleScreen()
            }
        }
        
        var next: AirPlayLayout {
            if let type = AirPlayLayout(rawValue: self.rawValue + 1) {
                return type
            } else {
                return .sideBySide
            }
        }
    }
    
    enum ScreenScaling: Int, CaseIterable {
        case stretch, fit
        var title: String {
            switch self {
            case .stretch: R.string.localizable.screenScalingStretch()
            case .fit: R.string.localizable.screenScalingFit()
            }
        }
        
        var next: ScreenScaling {
            if let type = ScreenScaling(rawValue: self.rawValue + 1) {
                return type
            } else {
                return .stretch
            }
        }
    }
    
    enum SlowMotionSpeed: Int, CaseIterable  {
        case off, one, two, three, four, five
        
        var title: String {
            if self == .off {
                return R.string.localizable.gameSettingFastForwardResume()
            } else {
                return R.string.localizable.slowMotionRatio(" x\(self.rawValue)")
            }
        }
        
        var next: SlowMotionSpeed {
            if let speed = SlowMotionSpeed(rawValue: self.rawValue + 1) {
                return speed
            } else {
                return .off
            }
        }

        var ratio: Float {
            switch self {
            case .off:
                return 1.0
            case .one:
                return 1.2
            case .two:
                return 1.5
            case .three:
                return 3
            case .four:
                return 5.0
            case .five:
                return 10.0
            }
        }
    }
}
