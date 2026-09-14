//
//  MappingOption.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/1.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

enum MappingOption: String, CaseIterable {
    case quickSave
    case quickLoad
    case toggleFastForward
    case fastForward
    case fastForward2x
    case fastForward3x
    case fastForward4x
    case reverseScreens //bindable
    case volume //bindable
    case saveStates
    case cheatCodes
    case skins
    case filters
    case screenshot
    case haptics
    case controllers
    case orientation
    case functionLayout
    case restart
    case resolution
    case quit
    case amiibo
    case homeMenu
    case airplay
    case toggleControlls //bindable
    case blowing
    case palette
    case swapDisk
    case retroAchievements
    case airPlayScaling
    case airPlayLayout
    case toggleAnalog //bindable
    case gameplayManuals
    case triggerPro
    case tvType//Color or BW bindable
    case leftDifficulty // A or B bindable
    case rightDifficulty //A or B bindable
    case screenScaling
    case j2meSettings
    case dosSettings
    case insertDisc
    case useKeyboardSkin
    case useJoypadSkin
    //v2.0.0 j2meSettings/dosSettings has been replaced with coreSettings
    case coreSettings
    case rewind
    //v2.0.1
    case slowMotion
    case wswanRotation
    case ndsLidToggle
    
    //Both the key and the value need to be unique
    static let GameOptionMappings: BiMap<MappingOption, GameOption> = [
        .quickSave: .saveState,
        .quickLoad: .quickLoadState,
        .toggleFastForward: .fastForward,
        .reverseScreens: .swapScreen,
        .volume: .volume,
        .saveStates: .stateList,
        .cheatCodes: .cheatCode,
        .skins: .skins,
        .filters: .shaders,
        .screenshot: .screenShot,
        .haptics: .haptic,
        .controllers: .controllerSetting,
        .orientation: .orientation,
        .functionLayout: .gameOptionSort,
        .restart: .reload,
        .resolution: .resolution,
        .quit: .quit,
        .amiibo: .amiibo,
        .homeMenu: .consoleHome,
        .airplay: .airplay,
        .toggleControlls: .hideControls,
        .blowing: .simBlowing,
        .palette: .palette,
        .swapDisk: .swapDisk,
        .retroAchievements: .retroAchievements,
        .airPlayScaling: .airPlayScaling,
        .airPlayLayout: .airPlayLayout,
        .toggleAnalog: .ps1ControllerMode,
        .gameplayManuals: .manual,
        .triggerPro: .triggerPro,
        .screenScaling: .screenScaling,
        .insertDisc: .insertDisc,
        .coreSettings: .coreSettings,
        .wswanRotation: .wswanRotation,
        .ndsLidToggle: .ndsLidToggle
    ]
    
    static func availableOptions(games: [Game]) -> [Self] {
        var availableGameOptions: [GameOption] = GameOption.availableOptions(games: games, scene: .gaming)
        availableGameOptions = GameOption.groupAndSortOptions(availableGameOptions).flatMap({ $0 })
        var availableMappingOptions = availableGameOptions.compactMap({ Self.GameOptionMappings.key(forValue: $0) })
        if let toggleFastForwardIndex = availableMappingOptions.firstIndex(where: { $0 == .toggleFastForward }) {
            availableMappingOptions.insert(contentsOf: [
                .fastForward2x,
                .fastForward3x,
                .fastForward4x,
                .fastForward
            ], at: min(toggleFastForwardIndex+1, availableGameOptions.count - 1))
        }
        
        if games.allSatisfy({ $0.gameType == .a2600 }) {
            availableMappingOptions.append(contentsOf: [
                .tvType,
                .leftDifficulty,
                .rightDifficulty
            ])
        }
        
        if games.allSatisfy({ $0.supportRewind }) {
            availableMappingOptions.append(.rewind)
        }
        
        if games.allSatisfy({ $0.gameType.supportsKeyboardSkin }) {
            availableMappingOptions.append(.useJoypadSkin)
            availableMappingOptions.append(.useKeyboardSkin)
        }
        
        if games.allSatisfy({ $0.supportSlowMotion }) {
            availableMappingOptions.append(.slowMotion)
        }
        
        return availableMappingOptions
    }
    
    var icon: ASIcon {
        if let gameOption = Self.GameOptionMappings.value(forKey: self) {
            return gameOption.icon
        }
        switch self {
        case .fastForward, .fastForward2x, .fastForward3x, .fastForward4x:
            return GameOption.fastForward.icon
            
        case .tvType:
            return .symbol(.tv)
            
        case .leftDifficulty, .rightDifficulty:
            return .symbol(.barometer)
            
        case .rewind:
            return GameOption.rewind.icon
            
        default:
            return .symbol(.questionmark)
        }
    }
    
    var title: String {
        if let gameOption = Self.GameOptionMappings.value(forKey: self) {
            return gameOption.title
        }
        switch self {
        case .fastForward:
            return R.string.localizable.holdMaxFastForward()
        case .fastForward2x:
            return R.string.localizable.holdFastForward("2x")
        case .fastForward3x:
            return R.string.localizable.holdFastForward("3x")
        case .fastForward4x:
            return R.string.localizable.holdFastForward("4x")
        case .tvType:
            return "TV Type"
        case .leftDifficulty:
            return "Left Difficulty"
        case .rightDifficulty:
            return "Right Difficulty"
        case .rewind:
            return GameOption.rewind.title
        default:
            return ""
        }
    }
    
    var gameOption: GameOption? {
        Self.GameOptionMappings.value(forKey: self)
    }
}

