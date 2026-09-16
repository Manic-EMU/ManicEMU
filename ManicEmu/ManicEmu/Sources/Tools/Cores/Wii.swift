//
//  Wii.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/20.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AVFoundation

extension GameType {
    static let wii = GameType("public.aoshuang.game.wii")
}

@objc enum WiiGameInput: Int, Input, CaseIterable {
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
    case c
    case z

    case flex
    case menu

    var type: InputType {
        return .game(.wii)
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
        else if stringValue == "c" { self = .c}
        else if stringValue == "z" { self = .z}
        else { return nil }
    }
}

struct Wii: DeltaCoreProtocol {
    static let core = Wii()
    
    var name: String { "Wii" }
    var identifier: String { "com.aoshuang.WiiCore" }
    
    var gameType: GameType { GameType.wii }
    var gameInputType: Input.Type { WiiGameInput.self }
    var allInputs: [Input] { WiiGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 640, height: 480))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let actionReplay = CheatFormat(name: "Action Replay",
                                       format: "XXXXXXXX YYYYYYYY",
                                       type: .actionReplay)
        let gecko = CheatFormat(name: "Gecko",
                                format: "XXXXXXXX YYYYYYYY",
                                type: .Gecko)
        return [actionReplay, gecko]
    }
    
    var emulatorBridge: EmulatorBridging { WiiEmulatorBridge.shared }
    
    private init() {}
}


class WiiEmulatorBridge : EmulatorBridgeBase {
    static let shared = WiiEmulatorBridge()

    private var leftThumbstickPosition: CGPoint = .zero
    private var rightThumbstickPosition: CGPoint = .zero
    
    private var thumbstickPosition: CGPoint = .zero
    
    var controllerType: LibretroWiiController = .classicPro

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if input == WiiGameInput.leftThumbstickUp || input == WiiGameInput.leftThumbstickDown {
            leftThumbstickPosition.y = input == WiiGameInput.leftThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == WiiGameInput.leftThumbstickLeft || input == WiiGameInput.leftThumbstickRight {
            leftThumbstickPosition.x = input == WiiGameInput.leftThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == WiiGameInput.rightThumbstickUp || input == WiiGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = input == WiiGameInput.rightThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == WiiGameInput.rightThumbstickLeft || input == WiiGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = input == WiiGameInput.rightThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = WiiGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: WiiGameInput) -> LibretroButton? {
        switch controllerType {
        case .wiimote, .wiimoteMotionPlus:
            if gameInput == .a { return .A }
            else if gameInput == .b { return .B }
            else if gameInput == .x { return .Y }
            else if gameInput == .y { return .X }
            else if gameInput == .start { return .start }
            else if gameInput == .select { return .select }
            else if gameInput == .up { return .up }
            else if gameInput == .down { return .down }
            else if gameInput == .left { return .left }
            else if gameInput == .right { return .right }
            else if gameInput == .c { return .R2 } //shake
            else if gameInput == .z { return .R3 } //home
            
        case .wiimoteSideways, .wiimoteMotionPlusSideways:
            if gameInput == .a { return .X }
            else if gameInput == .b { return .Y }
            else if gameInput == .x { return .A }
            else if gameInput == .y { return .B }
            else if gameInput == .start { return .start }
            else if gameInput == .select { return .select }
            else if gameInput == .up { return .up }
            else if gameInput == .down { return .down }
            else if gameInput == .left { return .left }
            else if gameInput == .right { return .right }
            else if gameInput == .c { return .R2 } //shake
            else if gameInput == .z { return .R3 } //home
            
        case .wiimoteNunchuk, .wiimoteMotionPlusNunchuk:
            if gameInput == .a { return .A }
            else if gameInput == .b { return .B }
            else if gameInput == .x { return .select }
            else if gameInput == .y { return .start }
            else if gameInput == .start { return .L1 }
            else if gameInput == .select { return .R1 }
            else if gameInput == .up { return .up }
            else if gameInput == .down { return .down }
            else if gameInput == .left { return .left }
            else if gameInput == .right { return .right }
            else if gameInput == .c { return .X }
            else if gameInput == .z { return .Y }
            else if gameInput == .l2 { return .L2 } //Shake Nunchuk
            else if gameInput == .r2 { return .R2 } //Shake Wiimote
            else if gameInput == .r3 { return .R3 } //home
            
        case .classic, .wiimoteMotionPlusClassic:
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
            else if gameInput == .l1 { return .L2 }
            else if gameInput == .r1 { return .R2 }
            else if gameInput == .l2 { return .L1 }
            else if gameInput == .r2 { return .R1 }
            else if gameInput == .l3 { return .L3 }
            else if gameInput == .r3 { return .R3 }
            
        case .classicPro, .wiimoteMotionPlusClassicPro:
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
            
        case .gameCube:
            if gameInput == .a { return .A }
            else if gameInput == .b { return .B }
            else if gameInput == .x { return .X }
            else if gameInput == .y { return .Y }
            else if gameInput == .start { return .start }
            else if gameInput == .select { return nil }
            else if gameInput == .up { return .up }
            else if gameInput == .down { return .down }
            else if gameInput == .left { return .left }
            else if gameInput == .right { return .right }
            else if gameInput == .l1 { return .L2 }
            else if gameInput == .r1 { return .R2 }
            else if gameInput == .l2 { return .R1 }
            else if gameInput == .r2 { return .R1 }
            else if gameInput == .l3 { return .L3 }
            else if gameInput == .r3 { return .R3 }
            
        default:
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
        }
        
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == WiiGameInput.leftThumbstickUp || input == WiiGameInput.leftThumbstickDown {
            leftThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == WiiGameInput.leftThumbstickLeft || input == WiiGameInput.leftThumbstickRight {
            leftThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == WiiGameInput.rightThumbstickUp || input == WiiGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == WiiGameInput.rightThumbstickLeft || input == WiiGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = WiiGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
}

extension LibretroWiiController {
    /// Classic / GC pads keep the default Wii skin; Wiimote-style devices use the Wiimote skin.
    var usesWiimoteSkin: Bool {
        switch self {
        case .wiimote, .wiimoteSideways, .wiimoteNunchuk,
             .wiimoteMotionPlus, .wiimoteMotionPlusSideways, .wiimoteMotionPlusNunchuk:
            return true
        default:
            return false
        }
    }
}
