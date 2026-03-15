//
//  N64.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ManicEmuCore
import AVFoundation

private let n64InputTraceNotification = Notification.Name("ManicN64InputTraceNotification")

private func postN64InputTrace(_ message: String) {
    NotificationCenter.default.post(name: n64InputTraceNotification, object: nil, userInfo: ["message": message])
}

extension GameType
{
    static let n64 = GameType("public.aoshuang.game.n64")
}

@objc enum N64GameInput: Int, Input, CaseIterable {
    case a
    case b
    case z
    case l
    case r
    case start
    case up
    case down
    case left
    case right
    case cUp
    case cDown
    case cLeft
    case cRight
    case analogStickUp
    case analogStickDown
    case analogStickLeft
    case analogStickRight

    case flex
    case menu

    public var type: InputType {
        return .game(.n64)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "z" { self = .z }
        else if stringValue == "l" { self = .l }
        else if stringValue == "r" { self = .r }
        else if stringValue == "start" { self = .start }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "cUp" { self = .cUp }
        else if stringValue == "cDown" { self = .cDown }
        else if stringValue == "cLeft" { self = .cLeft }
        else if stringValue == "cRight" { self = .cRight }
        else if stringValue == "analogStickUp" { self = .analogStickUp }
        else if stringValue == "analogStickDown" { self = .analogStickDown }
        else if stringValue == "analogStickLeft" { self = .analogStickLeft }
        else if stringValue == "analogStickRight" { self = .analogStickRight }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "menu" { self = .menu }
        else { return nil }
    }
}

struct N64: ManicEmuCoreProtocol {
    static let core = N64()
    
    var name: String { "N64" }
    var identifier: String { "com.aoshuang.N64Core" }
    var version: String? { "1.0.0" }
    
    var gameType: GameType { GameType.n64 }
    var gameInputType: Input.Type { N64GameInput.self }
    var allInputs: [Input] { N64GameInput.allCases }
    var gameSaveExtension: String { "srm" }
    
    let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 32768, channels: 2, interleaved: true)!
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 320, height: 240))
    
    var supportCheatFormats: Set<CheatFormat> {
        let gameSharkFormat = CheatFormat(name: NSLocalizedString("GameShark", comment: ""), format: "XXXXXXXX YYYY", type: .gameShark)
        return [gameSharkFormat]
    }
    
    var emulatorConnector: EmulatorBase { N64EmulatorBridge.shared }
    
    private init() {}
}


class N64EmulatorBridge : NSObject, EmulatorBase {
    static let shared = N64EmulatorBridge()
    
    var gameURL: URL?
    
    private(set) var frameDuration: TimeInterval = (1.0 / 60.0)
    
    var audioRenderer: (any ManicEmuCore.AudioRenderProtocol)?
    
    var videoRenderer: (any ManicEmuCore.VideoRenderProtocol)?
    
    var saveUpdateHandler: (() -> Void)?
    
    private var thumbstickPosition: CGPoint = .zero
    private var cStickPosition: CGPoint = .zero
    
    func start(withGameURL gameURL: URL) {}
    
    func stop() {}
    
    func pause() {}
    
    func resume() {}
    
    func runFrame(processVideo: Bool) {}
    
    func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }

        if input == N64GameInput.analogStickUp || input == N64GameInput.analogStickDown {
            thumbstickPosition.y = input == N64GameInput.analogStickUp ? -value : value
            postN64InputTrace("N64 left y \(thumbstickPosition.y.roundedDouble(scale: 2)) p\(playerIndex)")
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == N64GameInput.analogStickLeft || input == N64GameInput.analogStickRight {
            thumbstickPosition.x = input == N64GameInput.analogStickRight ? value : -value
            postN64InputTrace("N64 left x \(thumbstickPosition.x.roundedDouble(scale: 2)) p\(playerIndex)")
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == N64GameInput.cUp || input == N64GameInput.cDown {
            cStickPosition = CGPoint(x: 0, y: input == N64GameInput.cUp ? -value : value)
            postN64InputTrace("N64 c y \(cStickPosition.y.roundedDouble(scale: 2)) p\(playerIndex)")
            LibretroCore.sharedInstance().moveStick(false, x: cStickPosition.x, y: cStickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == N64GameInput.cLeft || input == N64GameInput.cRight {
            cStickPosition = CGPoint(x: input == N64GameInput.cRight ? value : -value, y: 0)
            postN64InputTrace("N64 c x \(cStickPosition.x.roundedDouble(scale: 2)) p\(playerIndex)")
            LibretroCore.sharedInstance().moveStick(false, x: cStickPosition.x, y: cStickPosition.y, playerIndex: UInt32(playerIndex))
        } else if let gameInput = N64GameInput(rawValue: input),
                  let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            postN64InputTrace("N64 press \(gameInput.stringValue) -> \(libretroButton.rawValue) p\(playerIndex)")
#if DEBUG
            Log.debug("\(String(describing: Self.self))点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: N64GameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
        else if gameInput == .b { return .Y }
        else if gameInput == .z { return .L2 }
        else if gameInput == .l { return .L1 }
        else if gameInput == .r { return .R1 }
        else if gameInput == .start { return .start }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == N64GameInput.analogStickUp || input == N64GameInput.analogStickDown {
            thumbstickPosition.y = 0
            postN64InputTrace("N64 left y 0 p\(playerIndex)")
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == N64GameInput.analogStickLeft || input == N64GameInput.analogStickRight {
            thumbstickPosition.x = 0
            postN64InputTrace("N64 left x 0 p\(playerIndex)")
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == N64GameInput.cUp || input == N64GameInput.cDown {
            cStickPosition.y = 0
            postN64InputTrace("N64 c y 0 p\(playerIndex)")
            LibretroCore.sharedInstance().moveStick(false, x: cStickPosition.x, y: cStickPosition.y, playerIndex: UInt32(playerIndex))
        }  else if input == N64GameInput.cLeft || input == N64GameInput.cRight {
            cStickPosition.x = 0
            postN64InputTrace("N64 c x 0 p\(playerIndex)")
            LibretroCore.sharedInstance().moveStick(false, x: cStickPosition.x, y: cStickPosition.y, playerIndex: UInt32(playerIndex))
        } else if let gameInput = N64GameInput(rawValue: input),
                  let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            postN64InputTrace("N64 release \(gameInput.stringValue) -> \(libretroButton.rawValue) p\(playerIndex)")
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func resetInputs() {}
    
    func saveSaveState(to url: URL) {}
    
    func loadSaveState(from url: URL) {}
    
    func saveGameSave(to url: URL) {}
    
    func loadGameSave(from url: URL) {}
    
    func addCheatCode(_ cheatCode: String, type: String) -> Bool {
        return false
    }
    
    func resetCheats() {}
    
    func updateCheats() {}
    
}
