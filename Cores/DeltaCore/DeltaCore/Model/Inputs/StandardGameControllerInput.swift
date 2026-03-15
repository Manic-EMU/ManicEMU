//
//  StandardGameControllerInput.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/20/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

public extension GameControllerInputType
{
    static let standard = GameControllerInputType("standard")
}

public enum StandardGameControllerInput: String, Codable
{
    case menu
    //自定义
    case flex
    case quickSave
    case quickLoad
    case fastForward
    case toggleFastForward
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
    case fastForward2x
    case fastForward3x
    case fastForward4x
    case tvType//Color or BW bindable
    case leftDifficulty // A or B bindable
    case rightDifficulty //A or B bindable

    case up
    case down
    case left
    case right
    
    case rightDpadUp
    case rightDpadDown
    case rightDpadLeft
    case rightDpadRight
    
    case leftThumbstickUp
    case leftThumbstickDown
    case leftThumbstickLeft
    case leftThumbstickRight
    
    case rightThumbstickUp
    case rightThumbstickDown
    case rightThumbstickLeft
    case rightThumbstickRight
    
    case a
    case b
    case c
    case x
    case y
    case z
    
    case start
    case select
    
    case l
    case l1
    case l2
    case l3
    
    case r
    case r1
    case r2
    case r3
}

extension StandardGameControllerInput: Input
{
    public var type: InputType {
        return .controller(.standard)
    }
    
    public var isContinuous: Bool {
        switch self
        {
        case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight: return true
        case .rightThumbstickUp, .rightThumbstickDown, .rightThumbstickLeft, .rightThumbstickRight: return true
        default: return false
        }
    }
}

public extension StandardGameControllerInput
{
    private static var inputMappings = [GameType: GameControllerInputMapping]()

    private func fallbackInput(for gameType: GameType) -> Input? {
        guard let deltaCore = ManicEmu.core(for: gameType) else { return nil }

        let candidates: [String]

        switch gameType.rawValue {
        case "public.aoshuang.game.n64":
            switch self {
            case .menu: candidates = ["menu"]
            case .up: candidates = ["up"]
            case .down: candidates = ["down"]
            case .left: candidates = ["left"]
            case .right: candidates = ["right"]
            case .leftThumbstickUp: candidates = ["analogStickUp"]
            case .leftThumbstickDown: candidates = ["analogStickDown"]
            case .leftThumbstickLeft: candidates = ["analogStickLeft"]
            case .leftThumbstickRight: candidates = ["analogStickRight"]
            case .rightThumbstickUp, .rightDpadUp: candidates = ["cUp"]
            case .rightThumbstickDown, .rightDpadDown: candidates = ["cDown"]
            case .rightThumbstickLeft, .rightDpadLeft: candidates = ["cLeft"]
            case .rightThumbstickRight, .rightDpadRight: candidates = ["cRight"]
            case .a: candidates = ["a"]
            case .b: candidates = ["b"]
            case .x: candidates = ["cLeft"]
            case .y: candidates = ["cUp"]
            case .start: candidates = ["start"]
            case .l, .l1: candidates = ["l"]
            case .l2: candidates = ["z"]
            case .r, .r1: candidates = ["r"]
            case .r2: candidates = ["cDown"]
            default: candidates = [self.stringValue]
            }

        default:
            candidates = [self.stringValue]
        }

        for candidate in candidates {
            if let input = deltaCore.gameInputType.init(stringValue: candidate), input.type == .game(gameType) {
                return input
            }
        }

        return nil
    }
    
    func input(for gameType: GameType) -> Input?
    {
        if let inputMapping = StandardGameControllerInput.inputMappings[gameType]
        {
            let input = inputMapping.input(forControllerInput: self)
            return input
        }
        
        guard
            let deltaCore = ManicEmu.core(for: gameType),
            let fileURL = deltaCore.resourceBundle.url(forResource: deltaCore.name, withExtension: "keymapping")
        else {
            return fallbackInput(for: gameType)
        }
        
        do
        {
            let inputMapping = try GameControllerInputMapping(fileURL: fileURL)
            StandardGameControllerInput.inputMappings[gameType] = inputMapping
            
            let input = inputMapping.input(forControllerInput: self)
            return input
        }
        catch
        {
            return fallbackInput(for: gameType)
        }
    }
}
