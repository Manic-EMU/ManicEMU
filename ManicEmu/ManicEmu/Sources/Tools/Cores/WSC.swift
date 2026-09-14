//
//  WSC.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType {
    static let wsc = GameType("public.aoshuang.game.wsc")
    static let ws = GameType("public.aoshuang.game.ws")
}

@objc enum WSCGameInput: Int, Input, CaseIterable {
    case a
    case b
    case x
    case y
    case start
    case select
    case up
    case down
    case left
    case right
    case l1
    case r1
    case l2
    case r2
    case l3
    case r3
    case leftThumbstickUp
    case leftThumbstickDown
    case leftThumbstickLeft
    case leftThumbstickRight
    case rightThumbstickUp
    case rightThumbstickDown
    case rightThumbstickLeft
    case rightThumbstickRight

    case flex
    case menu

    var type: InputType {
        return .game(.wsc)
    }
    
    var isContinuous: Bool {
        switch self
        {
        case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight: return true
        case .rightThumbstickUp, .rightThumbstickDown, .rightThumbstickLeft, .rightThumbstickRight: return true
        default: return false
        }
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a}
        else if stringValue == "b" { self = .b}
        else if stringValue == "x" { self = .x}
        else if stringValue == "y" { self = .y}
        else if stringValue == "start" { self = .start}
        else if stringValue == "select" { self = .select}
        else if stringValue == "up" { self = .up}
        else if stringValue == "down" { self = .down}
        else if stringValue == "left" { self = .left}
        else if stringValue == "right" { self = .right}
        else if stringValue == "l1" { self = .l1}
        else if stringValue == "r1" { self = .r1}
        else if stringValue == "l2" { self = .l2}
        else if stringValue == "r2" { self = .r2}
        else if stringValue == "l3" { self = .l3}
        else if stringValue == "r3" { self = .r3}
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp}
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown}
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft}
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight}
        else if stringValue == "rightThumbstickUp" { self = .rightThumbstickUp}
        else if stringValue == "rightThumbstickDown" { self = .rightThumbstickDown}
        else if stringValue == "rightThumbstickLeft" { self = .rightThumbstickLeft}
        else if stringValue == "rightThumbstickRight" { self = .rightThumbstickRight}
        else { return nil }
    }
}

struct WSC: DeltaCoreProtocol {
    static let core = WSC()
    
    var name: String { "WSC" }
    var identifier: String { "com.aoshuang.WSCCore" }
    
    var gameType: GameType { GameType.wsc }
    var gameInputType: Input.Type { WSCGameInput.self }
    var allInputs: [Input] { WSCGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 224, height: 144))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let beetleRawFormat = CheatFormat(name: "Beetle RAW", format: "AAAA:VV", type: .beetleRaw)
        return [beetleRawFormat]
    }
    
    var emulatorBridge: EmulatorBridging { WSCEmulatorBridge.shared }
    
    private init() {}
}


class WSCEmulatorBridge : EmulatorBridgeBase {
    static let shared = WSCEmulatorBridge()

    private var leftThumbstickPosition: CGPoint = .zero
    private var rightThumbstickPosition: CGPoint = .zero
    
    private var thumbstickPosition: CGPoint = .zero

    private let analogDpad = LibretroNetplayAnalogDpad()

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if input == WSCGameInput.leftThumbstickUp || input == WSCGameInput.leftThumbstickDown {
            leftThumbstickPosition.y = input == WSCGameInput.leftThumbstickUp ? value : -value
            analogDpad.moveStick(isLeft: true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: playerIndex)
        } else if input == WSCGameInput.leftThumbstickLeft || input == WSCGameInput.leftThumbstickRight {
            leftThumbstickPosition.x = input == WSCGameInput.leftThumbstickRight ? value : -value
            analogDpad.moveStick(isLeft: true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: playerIndex)
        } else if input == WSCGameInput.rightThumbstickUp || input == WSCGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = input == WSCGameInput.rightThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == WSCGameInput.rightThumbstickLeft || input == WSCGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = input == WSCGameInput.rightThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if let gameInput = WSCGameInput(rawValue: input),
                  let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            if analogDpad.handleDpad(libretroButton, pressed: true, playerIndex: playerIndex) {
                return
            }
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: WSCGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .l2 { return .L2 }
        else if gameInput == .r2 { return .R2 }
        else if gameInput == .l3 { return .L3 }
        else if gameInput == .r3 { return .R3 }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == WSCGameInput.leftThumbstickUp || input == WSCGameInput.leftThumbstickDown {
            leftThumbstickPosition.y = 0
            analogDpad.moveStick(isLeft: true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: playerIndex)
        } else if input == WSCGameInput.leftThumbstickLeft || input == WSCGameInput.leftThumbstickRight {
            leftThumbstickPosition.x = 0
            analogDpad.moveStick(isLeft: true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: playerIndex)
        } else if input == WSCGameInput.rightThumbstickUp || input == WSCGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == WSCGameInput.rightThumbstickLeft || input == WSCGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if let gameInput = WSCGameInput(rawValue: input),
                  let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            if analogDpad.handleDpad(libretroButton, pressed: false, playerIndex: playerIndex) {
                return
            }
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
