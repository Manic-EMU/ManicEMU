//
//  DC.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/9/4.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType
{
    static let dc = GameType("public.aoshuang.game.dc")
}

@objc enum DCGameInput: Int, Input, CaseIterable {
    case a
    case b
    case x
    case y
    case l1
    case r1
    case start
    case up
    case down
    case left
    case right
    case leftThumbstickUp
    case leftThumbstickDown
    case leftThumbstickLeft
    case leftThumbstickRight
    case select

    case flex
    case menu

    var type: InputType {
        return .game(.dc)
    }
    
    var isContinuous: Bool {
        switch self
        {
        case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight: return true
        default: return false
        }
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "start" { self = .start }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp }
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown }
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft }
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "select" { self = .select }
        else { return nil }
    }
}

struct DC: DeltaCoreProtocol {
    static let core = DC()
    
    var name: String { "DC" }
    var identifier: String { "com.aoshuang.DCCore" }
    
    var gameType: GameType { GameType.dc }
    var gameInputType: Input.Type { DCGameInput.self }
    var allInputs: [Input] { DCGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 640, height: 480))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let actionReplayFormat = CheatFormat(name: NSLocalizedString("Action Replay", comment: ""), format: "XXXXXXXX", type: .actionReplay)
        return [actionReplayFormat]
    }
    
    var emulatorBridge: EmulatorBridging { DCEmulatorBridge.shared }
        
    private init()
    {
    }
}


class DCEmulatorBridge : EmulatorBridgeBase {
    static let shared = DCEmulatorBridge()

    private var thumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        
        if input == DCGameInput.leftThumbstickUp || input == DCGameInput.leftThumbstickDown {
            thumbstickPosition.y = input == DCGameInput.leftThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DCGameInput.leftThumbstickLeft || input == DCGameInput.leftThumbstickRight {
            thumbstickPosition.x = input == DCGameInput.leftThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = DCGameInput(rawValue: input),
               let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
                Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: DCGameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
        else if gameInput == .b { return .A }
        else if gameInput == .x { return .Y }
        else if gameInput == .y { return .X }
        else if gameInput == .l1 { return .L2 }
        else if gameInput == .r1 { return .R2 }
        else if gameInput == .start { return .start }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .select { return .select }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == DCGameInput.leftThumbstickUp || input == DCGameInput.leftThumbstickDown {
            thumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DCGameInput.leftThumbstickLeft || input == DCGameInput.leftThumbstickRight {
            thumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = DCGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
}
