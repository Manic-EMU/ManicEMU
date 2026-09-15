//
//  FLASH.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/12.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import UIKit
import zlib

extension GameType {
    static let flash = GameType("public.aoshuang.game.flash")
}

/// Skin face buttons that can be remapped to a `FLASHKey`.
enum FLASHSkinButton: String, CaseIterable {
    case up, down, left, right
    case a, b, x, y
    case start, select
    case l1, r1, l2, r2, l3, r3

    var title: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .start: return "Start"
        case .select: return "Select"
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2"
        case .r2: return "R2"
        case .l3: return "L3"
        case .r3: return "R3"
        }
    }

    var icon: ASIcon {
        switch self {
        case .up: return .symbol(.arrowUp)
        case .down: return .symbol(.arrowDown)
        case .left: return .symbol(.arrowLeft)
        case .right: return .symbol(.arrowRight)
        default: return .symbolImage(R.image.controller_iconSymbols())
        }
    }

    /// Keyboard-only Flash defaults: arrows to move, Space as jump/primary,
    /// Z/X/C as extra actions, Enter/Esc for start/pause, Shift/Ctrl as modifiers.
    var defaultKey: FLASHKey {
        switch self {
        case .up: return .arrowUp
        case .down: return .arrowDown
        case .left: return .arrowLeft
        case .right: return .arrowRight
        case .a: return .space
        case .b: return .keyZ
        case .x: return .keyX
        case .y: return .keyC
        case .start: return .enter
        case .select: return .escape
        case .l1: return .shiftLeft
        case .r1: return .controlLeft
        case .l2: return .digit1
        case .r2: return .digit2
        case .l3: return .keyQ
        case .r3: return .keyE
        }
    }

    init?(gameInput: FLASHGameInput) {
        switch gameInput {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .a: self = .a
        case .b: self = .b
        case .x: self = .x
        case .y: self = .y
        case .start: self = .start
        case .select: self = .select
        case .l1: self = .l1
        case .r1: self = .r1
        case .l2: self = .l2
        case .r2: self = .r2
        case .l3: self = .l3
        case .r3: self = .r3
        default: return nil
        }
    }

    static var defaultMapping: [FLASHSkinButton: FLASHKey] {
        var result: [FLASHSkinButton: FLASHKey] = [:]
        for button in allCases {
            result[button] = button.defaultKey
        }
        return result
    }

    /// Stored extras recipe, or `nil` when the game still uses defaults.
    static func recipe(from game: Game) -> [String: String]? {
        guard let json = game.getExtraString(key: ExtraKey.skinButtonBinding.rawValue),
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              !dict.isEmpty else {
            return nil
        }
        return dict
    }

    static func mapping(from game: Game?) -> [FLASHSkinButton: FLASHKey] {
        var result = defaultMapping
        guard let game, let dict = recipe(from: game) else { return result }
        for (rawButton, rawKey) in dict {
            if let button = FLASHSkinButton(rawValue: rawButton),
               let key = FLASHKey(rawValue: rawKey) {
                result[button] = key
            }
        }
        return result
    }

    /// Shared mapping for one or more games. Mixed extras fall back to defaults.
    static func mapping(from games: [Game]) -> [FLASHSkinButton: FLASHKey] {
        let recipes = games.map { recipe(from: $0) }
        guard let first = recipes.first, recipes.allSatisfy({ $0 == first }) else {
            return defaultMapping
        }
        return mapping(from: games.first)
    }

    static func persist(_ mapping: [FLASHSkinButton: FLASHKey], to game: Game) {
        var dict: [String: String] = [:]
        for button in allCases {
            dict[button.rawValue] = (mapping[button] ?? button.defaultKey).rawValue
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else { return }
        game.updateExtra(key: ExtraKey.skinButtonBinding.rawValue, value: json)
    }

    static func persist(_ mapping: [FLASHSkinButton: FLASHKey], to games: [Game]) {
        for game in games {
            persist(mapping, to: game)
        }
    }

    static func clear(from games: [Game]) {
        for game in games {
            game.updateExtra(key: ExtraKey.skinButtonBinding.rawValue, value: nil)
        }
    }
}

/// KeyboardEvent.code values Ruffle accepts. Display labels match `LibretroKeyboardCode.getAllKeyboarLabels()`.
enum FLASHKey: String, CaseIterable {
    case digit1 = "Digit1", digit2 = "Digit2", digit3 = "Digit3", digit4 = "Digit4"
    case digit5 = "Digit5", digit6 = "Digit6", digit7 = "Digit7", digit8 = "Digit8"
    case digit9 = "Digit9", digit0 = "Digit0"
    case keyA = "KeyA", keyB = "KeyB", keyC = "KeyC", keyD = "KeyD", keyE = "KeyE"
    case keyF = "KeyF", keyG = "KeyG", keyH = "KeyH", keyI = "KeyI", keyJ = "KeyJ"
    case keyK = "KeyK", keyL = "KeyL", keyM = "KeyM", keyN = "KeyN", keyO = "KeyO"
    case keyP = "KeyP", keyQ = "KeyQ", keyR = "KeyR", keyS = "KeyS", keyT = "KeyT"
    case keyU = "KeyU", keyV = "KeyV", keyW = "KeyW", keyX = "KeyX", keyY = "KeyY"
    case keyZ = "KeyZ"
    case f1 = "F1", f2 = "F2", f3 = "F3", f4 = "F4", f5 = "F5", f6 = "F6"
    case f7 = "F7", f8 = "F8", f9 = "F9", f10 = "F10", f11 = "F11", f12 = "F12"
    case f13 = "F13", f14 = "F14", f15 = "F15"
    case escape = "Escape"
    case backspace = "Backspace"
    case backquote = "Backquote"
    case minus = "Minus"
    case equal = "Equal"
    case insert = "Insert"
    case home = "Home"
    case end = "End"
    case pageUp = "PageUp"
    case pageDown = "PageDown"
    case printScreen = "PrintScreen"
    case scrollLock = "ScrollLock"
    case pause = "Pause"
    case delete = "Delete"
    case tab = "Tab"
    case backslash = "Backslash"
    case bracketRight = "BracketRight"
    case bracketLeft = "BracketLeft"
    case capsLock = "CapsLock"
    case quote = "Quote"
    case semicolon = "Semicolon"
    case enter = "Enter"
    case shiftLeft = "ShiftLeft"
    case shiftRight = "ShiftRight"
    case period = "Period"
    case slash = "Slash"
    case comma = "Comma"
    case controlLeft = "ControlLeft"
    case controlRight = "ControlRight"
    case metaLeft = "MetaLeft"
    case metaRight = "MetaRight"
    case altLeft = "AltLeft"
    case altRight = "AltRight"
    case arrowUp = "ArrowUp"
    case space = "Space"
    case arrowDown = "ArrowDown"
    case arrowLeft = "ArrowLeft"
    case arrowRight = "ArrowRight"
    case numLock = "NumLock"
    case numpad0 = "Numpad0", numpad1 = "Numpad1", numpad2 = "Numpad2"
    case numpad3 = "Numpad3", numpad4 = "Numpad4", numpad5 = "Numpad5"
    case numpad6 = "Numpad6", numpad7 = "Numpad7", numpad8 = "Numpad8", numpad9 = "Numpad9"
    case numpadAdd = "NumpadAdd"
    case numpadSubtract = "NumpadSubtract"
    case numpadMultiply = "NumpadMultiply"
    case numpadDivide = "NumpadDivide"
    case numpadDecimal = "NumpadDecimal"
    case numpadEnter = "NumpadEnter"
    case numpadEqual = "NumpadEqual"
    case intlBackslash = "IntlBackslash"

    /// KeyboardEvent.key
    var eventKey: String {
        if rawValue.hasPrefix("Key"), let last = rawValue.last {
            return String(last).lowercased()
        }
        if rawValue.hasPrefix("Digit"), let last = rawValue.last {
            return String(last)
        }
        if rawValue.hasPrefix("F"), Int(rawValue.dropFirst()) != nil {
            return rawValue
        }
        switch self {
        case .escape: return "Escape"
        case .backspace: return "Backspace"
        case .backquote: return "`"
        case .minus: return "-"
        case .equal: return "="
        case .insert: return "Insert"
        case .home: return "Home"
        case .end: return "End"
        case .pageUp: return "PageUp"
        case .pageDown: return "PageDown"
        case .printScreen: return "PrintScreen"
        case .scrollLock: return "ScrollLock"
        case .pause: return "Pause"
        case .delete: return "Delete"
        case .tab: return "Tab"
        case .backslash: return "\\"
        case .bracketRight: return "]"
        case .bracketLeft: return "["
        case .capsLock: return "CapsLock"
        case .quote: return "'"
        case .semicolon: return ";"
        case .enter: return "Enter"
        case .shiftLeft, .shiftRight: return "Shift"
        case .period: return "."
        case .slash: return "/"
        case .comma: return ","
        case .controlLeft, .controlRight: return "Control"
        case .metaLeft, .metaRight: return "Meta"
        case .altLeft, .altRight: return "Alt"
        case .arrowUp, .arrowDown, .arrowLeft, .arrowRight: return rawValue
        case .space: return " "
        case .numLock: return "NumLock"
        case .numpad0, .numpad1, .numpad2, .numpad3, .numpad4,
             .numpad5, .numpad6, .numpad7, .numpad8, .numpad9:
            return String(rawValue.last!)
        case .numpadAdd: return "+"
        case .numpadSubtract: return "-"
        case .numpadMultiply: return "*"
        case .numpadDivide: return "/"
        case .numpadDecimal: return "."
        case .numpadEnter: return "Enter"
        case .numpadEqual: return "="
        case .intlBackslash: return "\\"
        default: return rawValue
        }
    }

    /// Legacy KeyboardEvent.keyCode / which, used by many AVM1 games.
    var keyCode: Int {
        if rawValue.hasPrefix("Digit"), let last = rawValue.last, let digit = Int(String(last)) {
            return 48 + digit
        }
        if rawValue.hasPrefix("Key"), let scalar = rawValue.last?.asciiValue {
            return Int(scalar)
        }
        if rawValue.hasPrefix("F"), let n = Int(rawValue.dropFirst()) {
            return 111 + n
        }
        switch self {
        case .escape: return 27
        case .backspace: return 8
        case .backquote: return 192
        case .minus: return 189
        case .equal: return 187
        case .insert: return 45
        case .home: return 36
        case .end: return 35
        case .pageUp: return 33
        case .pageDown: return 34
        case .printScreen: return 44
        case .scrollLock: return 145
        case .pause: return 19
        case .delete: return 46
        case .tab: return 9
        case .backslash: return 220
        case .bracketRight: return 221
        case .bracketLeft: return 219
        case .capsLock: return 20
        case .quote: return 222
        case .semicolon: return 186
        case .enter: return 13
        case .shiftLeft, .shiftRight: return 16
        case .period: return 190
        case .slash: return 191
        case .comma: return 188
        case .controlLeft, .controlRight: return 17
        case .metaLeft, .metaRight: return 91
        case .altLeft, .altRight: return 18
        case .arrowLeft: return 37
        case .arrowUp: return 38
        case .arrowRight: return 39
        case .arrowDown: return 40
        case .space: return 32
        case .numLock: return 144
        case .numpad0: return 96
        case .numpad1: return 97
        case .numpad2: return 98
        case .numpad3: return 99
        case .numpad4: return 100
        case .numpad5: return 101
        case .numpad6: return 102
        case .numpad7: return 103
        case .numpad8: return 104
        case .numpad9: return 105
        case .numpadMultiply: return 106
        case .numpadAdd: return 107
        case .numpadSubtract: return 109
        case .numpadDecimal: return 110
        case .numpadDivide: return 111
        case .numpadEnter: return 13
        case .numpadEqual: return 187
        case .intlBackslash: return 226
        default: return 0
        }
    }

    /// Primary label shown in the mapping UI (aligned with `getAllKeyboarLabels`).
    var title: String {
        libretroLabels.first ?? rawValue
    }

    var libretroLabels: [String] {
        switch self {
        case .digit1: return ["1"]
        case .digit2: return ["2"]
        case .digit3: return ["3"]
        case .digit4: return ["4"]
        case .digit5: return ["5"]
        case .digit6: return ["6"]
        case .digit7: return ["7"]
        case .digit8: return ["8"]
        case .digit9: return ["9"]
        case .digit0: return ["0"]
        case .keyA: return ["a"]
        case .keyB: return ["b"]
        case .keyC: return ["c"]
        case .keyD: return ["d"]
        case .keyE: return ["e"]
        case .keyF: return ["f"]
        case .keyG: return ["g"]
        case .keyH: return ["h"]
        case .keyI: return ["i"]
        case .keyJ: return ["j"]
        case .keyK: return ["k"]
        case .keyL: return ["l"]
        case .keyM: return ["m"]
        case .keyN: return ["n"]
        case .keyO: return ["o"]
        case .keyP: return ["p"]
        case .keyQ: return ["q"]
        case .keyR: return ["r"]
        case .keyS: return ["s"]
        case .keyT: return ["t"]
        case .keyU: return ["u"]
        case .keyV: return ["v"]
        case .keyW: return ["w"]
        case .keyX: return ["x"]
        case .keyY: return ["y"]
        case .keyZ: return ["z"]
        case .f1: return ["f1"]
        case .f2: return ["f2"]
        case .f3: return ["f3"]
        case .f4: return ["f4"]
        case .f5: return ["f5"]
        case .f6: return ["f6"]
        case .f7: return ["f7"]
        case .f8: return ["f8"]
        case .f9: return ["f9"]
        case .f10: return ["f10"]
        case .f11: return ["f11"]
        case .f12: return ["f12"]
        case .f13: return ["f13"]
        case .f14: return ["f14"]
        case .f15: return ["f15"]
        case .escape: return ["escape"]
        case .backspace: return ["backspace"]
        case .backquote: return ["backquote"]
        case .minus: return ["minus"]
        case .equal: return ["equals"]
        case .insert: return ["insert"]
        case .home: return ["home"]
        case .end: return ["end"]
        case .pageUp: return ["pageup"]
        case .pageDown: return ["pagedown"]
        case .printScreen: return ["print"]
        case .scrollLock: return ["scrolllock"]
        case .pause: return ["pause"]
        case .delete: return ["delete"]
        case .tab: return ["tab"]
        case .backslash: return ["backslash"]
        case .bracketRight: return ["rightbracket"]
        case .bracketLeft: return ["leftbracket"]
        case .capsLock: return ["capslock"]
        case .quote: return ["quote"]
        case .semicolon: return ["semicolon"]
        case .enter: return ["return"]
        case .shiftLeft: return ["lshift", "shift"]
        case .shiftRight: return ["rshift"]
        case .period: return ["period"]
        case .slash: return ["slash"]
        case .comma: return ["comma"]
        case .controlLeft: return ["lctrl", "ctrl"]
        case .controlRight: return ["rctrl"]
        case .metaLeft: return ["lmeta", "meta"]
        case .metaRight: return ["rmeta"]
        case .altLeft: return ["lalt", "alt"]
        case .altRight: return ["ralt"]
        case .arrowUp: return ["up"]
        case .space: return ["space"]
        case .arrowDown: return ["down"]
        case .arrowLeft: return ["left"]
        case .arrowRight: return ["right"]
        case .numLock: return ["numlock"]
        case .numpad0: return ["kp0"]
        case .numpad1: return ["kp1"]
        case .numpad2: return ["kp2"]
        case .numpad3: return ["kp3"]
        case .numpad4: return ["kp4"]
        case .numpad5: return ["kp5"]
        case .numpad6: return ["kp6"]
        case .numpad7: return ["kp7"]
        case .numpad8: return ["kp8"]
        case .numpad9: return ["kp9"]
        case .numpadAdd: return ["kpplus", "plus"]
        case .numpadSubtract: return ["kpminus"]
        case .numpadMultiply: return ["kpmultiply", "asterisk"]
        case .numpadDivide: return ["kpdivide"]
        case .numpadDecimal: return ["kpperiod"]
        case .numpadEnter: return ["kpenter"]
        case .numpadEqual: return ["kpequals"]
        case .intlBackslash: return ["oem102", "bar"]
        }
    }

    private static let labelIndex: [String: FLASHKey] = {
        var map: [String: FLASHKey] = [:]
        for key in allCases {
            for label in key.libretroLabels {
                map[label] = key
            }
        }
        return map
    }()

    static func fromLibretroLabel(_ label: String) -> FLASHKey? {
        labelIndex[label]
    }
}

@objc enum FLASHGameInput: Int, Input, CaseIterable {
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
        return .game(.flash)
    }

    var isContinuous: Bool {
        switch self {
        case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight: return true
        case .rightThumbstickUp, .rightThumbstickDown, .rightThumbstickLeft, .rightThumbstickRight: return true
        default: return false
        }
    }

    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "l2" { self = .l2 }
        else if stringValue == "r2" { self = .r2 }
        else if stringValue == "l3" { self = .l3 }
        else if stringValue == "r3" { self = .r3 }
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp }
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown }
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft }
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight }
        else if stringValue == "rightThumbstickUp" { self = .rightThumbstickUp }
        else if stringValue == "rightThumbstickDown" { self = .rightThumbstickDown }
        else if stringValue == "rightThumbstickLeft" { self = .rightThumbstickLeft }
        else if stringValue == "rightThumbstickRight" { self = .rightThumbstickRight }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct FLASH: DeltaCoreProtocol {
    static let core = FLASH()

    var name: String { "Flash" }
    var identifier: String { "com.aoshuang.FlashCore" }

    var gameType: GameType { GameType.flash }
    var gameInputType: Input.Type { FLASHGameInput.self }
    var allInputs: [Input] { FLASHGameInput.allCases }
    var gameSaveFileExtension: String { "json" }

    /// Classic Flash Player default stage.
    let videoFormat = VideoFormat(format: .bitmap(.rgba8), dimensions: CGSize(width: 550, height: 400))

    var supportedCheatFormats: Set<CheatFormat> {
        return []
    }

    var emulatorBridge: EmulatorBridging { FLASHEmulatorBridge.shared }

    private init() {}
}

class FLASHEmulatorBridge: EmulatorBridgeBase {
    static let shared = FLASHEmulatorBridge()

    private var leftThumbstickPosition: CGPoint = .zero
    private var stickDpad = AnalogDpadBits()
    private var buttonDpad = AnalogDpadBits()
    private var sentKeys: Set<FLASHKey> = []
    private var skinToKey: [FLASHSkinButton: FLASHKey] = FLASHSkinButton.mapping(from: nil)

    private let analogPressThreshold = 0.40
    private let analogReleaseThreshold = 0.22

    func reloadKeyMapping(from game: Game?) {
        skinToKey = FLASHSkinButton.mapping(from: game)
        syncKeys()
    }

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0,
              let gameInput = FLASHGameInput(rawValue: input) else { return }

        if handleAnalog(gameInput, value: value, pressed: true) {
            return
        }

        if applyButtonDpad(gameInput, pressed: true) {
            return
        }

        if let key = mappedKey(for: gameInput) {
            press(key, pressed: true)
        }
    }

    override func deactivateInput(_ input: Int, playerIndex: Int) {
        guard playerIndex >= 0,
              let gameInput = FLASHGameInput(rawValue: input) else { return }

        if handleAnalog(gameInput, value: 0, pressed: false) {
            return
        }

        if applyButtonDpad(gameInput, pressed: false) {
            return
        }

        if let key = mappedKey(for: gameInput) {
            press(key, pressed: false)
        }
    }

    /// Keep opposite-axis values when only one thumbstick direction deactivates.
    @discardableResult
    private func handleAnalog(_ input: FLASHGameInput, value: Double, pressed: Bool) -> Bool {
        switch input {
        case .leftThumbstickUp:
            if pressed {
                leftThumbstickPosition.y = value
            } else if leftThumbstickPosition.y > 0 {
                leftThumbstickPosition.y = 0
            }
        case .leftThumbstickDown:
            if pressed {
                leftThumbstickPosition.y = -value
            } else if leftThumbstickPosition.y < 0 {
                leftThumbstickPosition.y = 0
            }
        case .leftThumbstickRight:
            if pressed {
                leftThumbstickPosition.x = value
            } else if leftThumbstickPosition.x > 0 {
                leftThumbstickPosition.x = 0
            }
        case .leftThumbstickLeft:
            if pressed {
                leftThumbstickPosition.x = -value
            } else if leftThumbstickPosition.x < 0 {
                leftThumbstickPosition.x = 0
            }
        default:
            return false
        }
        refreshStickDpad()
        return true
    }

    private func refreshStickDpad() {
        let x = leftThumbstickPosition.x
        let y = leftThumbstickPosition.y
        stickDpad.up.applyHysteresis(sample: y, press: analogPressThreshold, release: analogReleaseThreshold)
        stickDpad.down.applyHysteresis(sample: -y, press: analogPressThreshold, release: analogReleaseThreshold)
        stickDpad.right.applyHysteresis(sample: x, press: analogPressThreshold, release: analogReleaseThreshold)
        stickDpad.left.applyHysteresis(sample: -x, press: analogPressThreshold, release: analogReleaseThreshold)
        syncKeys()
    }

    @discardableResult
    private func applyButtonDpad(_ input: FLASHGameInput, pressed: Bool) -> Bool {
        switch input {
        case .up: buttonDpad.up = pressed
        case .down: buttonDpad.down = pressed
        case .left: buttonDpad.left = pressed
        case .right: buttonDpad.right = pressed
        default: return false
        }
        syncKeys()
        return true
    }

    /// OR analog + digital D-pad, then emit one keydown/keyup per mapped FLASHKey.
    private func syncKeys() {
        var wanted: Set<FLASHKey> = []
        if buttonDpad.up || stickDpad.up, let key = mappedKey(for: .up) { wanted.insert(key) }
        if buttonDpad.down || stickDpad.down, let key = mappedKey(for: .down) { wanted.insert(key) }
        if buttonDpad.left || stickDpad.left, let key = mappedKey(for: .left) { wanted.insert(key) }
        if buttonDpad.right || stickDpad.right, let key = mappedKey(for: .right) { wanted.insert(key) }

        for key in sentKeys.subtracting(wanted) {
            press(key, pressed: false)
        }
        for key in wanted.subtracting(sentKeys) {
            press(key, pressed: true)
        }
        sentKeys = wanted
    }

    private func press(_ key: FLASHKey, pressed: Bool) {
        PlayViewController.ruffleView?.pressButton(key, pressed: pressed)
    }

    private func mappedKey(for input: FLASHGameInput) -> FLASHKey? {
        guard let skin = FLASHSkinButton(gameInput: input) else { return nil }
        return mappedKey(for: skin)
    }

    private func mappedKey(for skin: FLASHSkinButton) -> FLASHKey {
        skinToKey[skin] ?? skin.defaultKey
    }
}

private struct AnalogDpadBits {
    var up = false
    var down = false
    var left = false
    var right = false
}

private extension Bool {
    mutating func applyHysteresis(sample: Double, press: Double, release: Double) {
        if self {
            if sample < release { self = false }
        } else if sample > press {
            self = true
        }
    }
}

/// Pulls a cover JPEG from embedded SWF bitmaps. Vector-only movies have nothing to extract.
enum FLASHCover {
    private static let maxFileBytes = 80 * 1024 * 1024
    private static let minSide = 48
    private static let maxPixels = 8_000_000
    private static let maxCoverSide: CGFloat = 900

    static func extractJPEGData(from url: URL) -> Data? {
        guard let file = try? Data(contentsOf: url, options: [.mappedIfSafe]),
              file.count >= 8, file.count <= maxFileBytes else { return nil }
        guard let movie = Movie.parse(file) else { return nil }
        return movie.bestCoverJPEG()
    }

    private struct Movie {
        var stageWidth: Int
        var stageHeight: Int
        var images: [RawImage]
        var firstFrameIds: Set<UInt16>

        static func parse(_ file: Data) -> Movie? {
            guard let uncompressed = decompressSWF(file) else { return nil }
            var offset = 8
            guard let stage = readRECT(uncompressed, offset: &offset),
                  offset + 4 <= uncompressed.count else { return nil }
            offset += 4

            var jpegTables = Data()
            var images: [RawImage] = []
            var sprites: [UInt16: Set<UInt16>] = [:]
            var rootPlaced = Set<UInt16>()
            parseTagList(
                uncompressed,
                start: offset,
                jpegTables: &jpegTables,
                images: &images,
                sprites: &sprites,
                firstFramePlaced: &rootPlaced
            )

            var expanded = Set<UInt16>()
            var stack = Array(rootPlaced)
            while let id = stack.popLast() {
                if !expanded.insert(id).inserted { continue }
                if let children = sprites[id] {
                    stack.append(contentsOf: children)
                }
            }

            return Movie(
                stageWidth: max(stage.width, 1),
                stageHeight: max(stage.height, 1),
                images: images,
                firstFrameIds: expanded
            )
        }

        func bestCoverJPEG() -> Data? {
            let ranked = images.compactMap { image -> (RawImage, Double)? in
                let score = FLASHCover.score(
                    width: image.width,
                    height: image.height,
                    stageWidth: stageWidth,
                    stageHeight: stageHeight,
                    onStage: firstFrameIds.contains(image.id)
                )
                return score > 0 ? (image, score) : nil
            }
            .sorted { $0.1 > $1.1 }

            for (image, _) in ranked.prefix(6) {
                if let jpeg = FLASHCover.decodeCoverJPEG(image) {
                    return jpeg
                }
            }
            return nil
        }
    }

    private struct RawImage {
        let id: UInt16
        let width: Int
        let height: Int
        let payload: Payload
    }

    private enum Payload {
        case jpeg(Data)
        case lossless(version: Int, format: UInt8, colorTableSize: UInt8?, zlibData: Data)
    }

    private static func score(width: Int, height: Int, stageWidth: Int, stageHeight: Int, onStage: Bool) -> Double {
        if width < 1 || height < 1 {
            return onStage ? 0.1 : -1
        }
        guard width >= minSide, height >= minSide, width * height <= maxPixels else { return -1 }
        let aspect = Double(width) / Double(height)
        guard aspect >= 0.25, aspect <= 4 else { return -1 }
        let stageAspect = Double(stageWidth) / Double(stageHeight)
        let aspectFit = 1.0 / (1.0 + abs(log(aspect / stageAspect)))
        let area = Double(width * height)
        let stageArea = Double(stageWidth * stageHeight)
        let sizeFit = 1.0 / (1.0 + abs(log(area / stageArea)))
        var value = log(max(area, 2)) * aspectFit * sizeFit
        if onStage { value *= 4 }
        return value
    }

    private static func decodeCoverJPEG(_ image: RawImage) -> Data? {
        switch image.payload {
        case .jpeg(let data):
            guard let uiImage = UIImage(data: data), isCoverSized(uiImage) else { return nil }
            return jpegCover(from: uiImage)
        case .lossless(let version, let format, let colorTableSize, let zlibData):
            guard let rgba = decodeLossless(
                version: version,
                format: format,
                width: image.width,
                height: image.height,
                colorTableSize: colorTableSize,
                zlibData: zlibData
            ), let uiImage = imageFromRGBA(
                width: image.width,
                height: image.height,
                rgba: rgba,
                premultiplied: version == 2 && format == 5
            ), isCoverSized(uiImage) else {
                return nil
            }
            return jpegCover(from: uiImage)
        }
    }

    private static func isCoverSized(_ image: UIImage) -> Bool {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        return width >= CGFloat(minSide) && height >= CGFloat(minSide)
    }

    private static func jpegCover(from image: UIImage) -> Data? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > 0 else { return nil }
        if longest <= maxCoverSide {
            return image.jpegData(compressionQuality: 0.7)
        }
        let ratio = maxCoverSide / longest
        let size = CGSize(width: pixelWidth * ratio / image.scale, height: pixelHeight * ratio / image.scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.7)
    }

    private static func decompressSWF(_ file: Data) -> Data? {
        let bytes = [UInt8](file)
        guard bytes.count >= 8 else { return nil }
        let sig0 = bytes[0], sig1 = bytes[1], sig2 = bytes[2]
        let fileLength = intU32(bytes, 4)
        guard fileLength >= 8, fileLength <= maxFileBytes else { return nil }

        if sig0 == 0x46, sig1 == 0x57, sig2 == 0x53 { // FWS
            return file
        }
        if sig0 == 0x43, sig1 == 0x57, sig2 == 0x53 { // CWS
            let compressed = Data(bytes.dropFirst(8))
            let expected = fileLength - 8
            guard let inflated = inflateZlib(compressed, limit: expected) ?? inflateRaw(compressed, limit: expected) else {
                return nil
            }
            var result = Data(bytes.prefix(8))
            result.append(inflated)
            return result
        }
        // ZWS (LZMA) is uncommon for classic Flash games and needs a raw LZMA decoder.
        return nil
    }

    private static func parseTagList(
        _ data: Data,
        start: Int,
        jpegTables: inout Data,
        images: inout [RawImage],
        sprites: inout [UInt16: Set<UInt16>],
        firstFramePlaced: inout Set<UInt16>
    ) {
        let bytes = [UInt8](data)
        var offset = start
        var placed = Set<UInt16>()
        var sawFrame = false
        while let tag = readTag(bytes, offset: &offset) {
            if tag.code == 0 { break }
            if tag.code == 1 {
                if !sawFrame {
                    sawFrame = true
                    firstFramePlaced = placed
                }
                continue
            }
            let payload = Array(bytes[tag.range])
            switch tag.code {
            case 4, 26, 70:
                if !sawFrame, let id = placedCharacterId(tag: tag.code, payload: payload) {
                    placed.insert(id)
                }
            case 8:
                jpegTables = Data(payload)
            case 6:
                appendJPEG(idAtStart: payload, tables: jpegTables, images: &images)
            case 21:
                appendJPEG(idAtStart: payload, tables: nil, images: &images)
            case 35, 90:
                appendJPEG3(payload, version: tag.code == 90 ? 4 : 3, images: &images)
            case 20, 36:
                appendLossless(payload, version: tag.code == 36 ? 2 : 1, images: &images)
            case 39:
                parseSprite(payload, jpegTables: &jpegTables, images: &images, sprites: &sprites)
            default:
                break
            }
        }
        if !sawFrame {
            firstFramePlaced = placed
        }
    }

    private static func parseSprite(
        _ payload: [UInt8],
        jpegTables: inout Data,
        images: inout [RawImage],
        sprites: inout [UInt16: Set<UInt16>]
    ) {
        guard payload.count >= 4, let spriteId = u16(payload, 0) else { return }
        var offset = 4
        var placed = Set<UInt16>()
        var sawFrame = false
        while let tag = readTag(payload, offset: &offset) {
            if tag.code == 0 { break }
            if tag.code == 1 {
                if !sawFrame { sawFrame = true }
                continue
            }
            let body = Array(payload[tag.range])
            switch tag.code {
            case 4, 26, 70:
                if !sawFrame, let id = placedCharacterId(tag: tag.code, payload: body) {
                    placed.insert(id)
                }
            case 8:
                jpegTables = Data(body)
            case 6:
                appendJPEG(idAtStart: body, tables: jpegTables, images: &images)
            case 21:
                appendJPEG(idAtStart: body, tables: nil, images: &images)
            case 35, 90:
                appendJPEG3(body, version: tag.code == 90 ? 4 : 3, images: &images)
            case 20, 36:
                appendLossless(body, version: tag.code == 36 ? 2 : 1, images: &images)
            default:
                break
            }
        }
        sprites[spriteId] = placed
    }

    private static func appendJPEG(idAtStart payload: [UInt8], tables: Data?, images: inout [RawImage]) {
        guard payload.count > 2, let id = u16(payload, 0) else { return }
        var jpeg = Data(payload.dropFirst(2))
        if let tables, !tables.isEmpty {
            jpeg = tables + jpeg
        }
        jpeg = sanitizeFlashJPEG(jpeg)
        let size = imageSize(of: jpeg) ?? (0, 0)
        images.append(RawImage(id: id, width: size.0, height: size.1, payload: .jpeg(jpeg)))
    }

    private static func appendJPEG3(_ payload: [UInt8], version: Int, images: inout [RawImage]) {
        guard payload.count >= 6, let id = u16(payload, 0) else { return }
        let dataSize = Int(intU32(payload, 2))
        var header = 6
        if version >= 4 { header += 2 }
        guard dataSize >= 0, header + dataSize <= payload.count else { return }
        let jpeg = sanitizeFlashJPEG(Data(payload[header..<(header + dataSize)]))
        let size = imageSize(of: jpeg) ?? (0, 0)
        images.append(RawImage(id: id, width: size.0, height: size.1, payload: .jpeg(jpeg)))
    }

    private static func appendLossless(_ payload: [UInt8], version: Int, images: inout [RawImage]) {
        guard payload.count >= 7, let id = u16(payload, 0) else { return }
        let format = payload[2]
        guard let width = u16(payload, 3), let height = u16(payload, 5) else { return }
        var offset = 7
        var colorTableSize: UInt8?
        if format == 3 {
            guard offset < payload.count else { return }
            colorTableSize = payload[offset]
            offset += 1
        }
        guard offset < payload.count else { return }
        images.append(RawImage(
            id: id,
            width: Int(width),
            height: Int(height),
            payload: .lossless(
                version: version,
                format: format,
                colorTableSize: colorTableSize,
                zlibData: Data(payload[offset...])
            )
        ))
    }

    private static func placedCharacterId(tag: Int, payload: [UInt8]) -> UInt16? {
        switch tag {
        case 4:
            return u16(payload, 0)
        case 26:
            guard payload.count >= 5, payload[0] & 0x02 != 0 else { return nil }
            return u16(payload, 3)
        case 70:
            guard payload.count >= 4 else { return nil }
            let flags = UInt16(payload[0]) | UInt16(payload[1]) << 8
            let hasCharacter = flags & (1 << 1) != 0
            let hasClassName = flags & (1 << 11) != 0
            let hasImage = flags & (1 << 12) != 0
            var offset = 4
            if hasClassName || (hasImage && !hasCharacter) {
                while offset < payload.count, payload[offset] != 0 { offset += 1 }
                offset += 1
            }
            guard hasCharacter else { return nil }
            return u16(payload, offset)
        default:
            return nil
        }
    }

    private struct TagSlice {
        let code: Int
        let range: Range<Int>
    }

    private static func readTag(_ bytes: [UInt8], offset: inout Int) -> TagSlice? {
        guard offset + 2 <= bytes.count else { return nil }
        let header = Int(u16(bytes, offset) ?? 0)
        offset += 2
        let code = header >> 6
        var length = header & 0x3F
        if length == 0x3F {
            guard offset + 4 <= bytes.count else { return nil }
            length = Int(intU32(bytes, offset))
            offset += 4
        }
        guard length >= 0, offset + length <= bytes.count else { return nil }
        let range = offset..<(offset + length)
        offset += length
        return TagSlice(code: code, range: range)
    }

    private static func readRECT(_ data: Data, offset: inout Int) -> (width: Int, height: Int)? {
        let bytes = [UInt8](data)
        guard offset < bytes.count else { return nil }
        var cursor = BitCursor(bytes: bytes, bitOffset: offset * 8)
        guard let nBits = cursor.readUB(5),
              let xMin = cursor.readSB(nBits),
              let xMax = cursor.readSB(nBits),
              let yMin = cursor.readSB(nBits),
              let yMax = cursor.readSB(nBits) else { return nil }
        cursor.align()
        offset = cursor.bitOffset / 8
        let width = max((xMax - xMin) / 20, 1)
        let height = max((yMax - yMin) / 20, 1)
        return (width, height)
    }

    private struct BitCursor {
        let bytes: [UInt8]
        var bitOffset: Int

        var remainingBits: Int { bytes.count * 8 - bitOffset }

        mutating func readUB(_ count: Int) -> Int? {
            guard count >= 0, remainingBits >= count else { return nil }
            var value = 0
            for _ in 0..<count {
                let byte = bytes[bitOffset / 8]
                let bit = 7 - (bitOffset % 8)
                value = (value << 1) | Int((byte >> bit) & 1)
                bitOffset += 1
            }
            return value
        }

        mutating func readSB(_ count: Int) -> Int? {
            guard count > 0, let unsigned = readUB(count) else { return count == 0 ? 0 : nil }
            let sign = 1 << (count - 1)
            if unsigned & sign != 0 {
                return unsigned - (1 << count)
            }
            return unsigned
        }

        mutating func align() {
            if bitOffset % 8 != 0 {
                bitOffset += 8 - bitOffset % 8
            }
        }
    }

    private static func decodeLossless(
        version: Int,
        format: UInt8,
        width: Int,
        height: Int,
        colorTableSize: UInt8?,
        zlibData: Data
    ) -> Data? {
        guard width > 0, height > 0, width * height <= maxPixels else { return nil }
        guard let raw = inflateZlib(zlibData) ?? inflateRaw(zlibData) else { return nil }
        let pixels = [UInt8](raw)
        var rgba = [UInt8](repeating: 0, count: width * height * 4)

        switch format {
        case 3:
            let count = Int(colorTableSize ?? 0) + 1
            let entry = version == 2 ? 4 : 3
            let tableBytes = count * entry
            let stride = (width + 3) & ~3
            guard tableBytes + stride * height <= pixels.count else { return nil }
            for y in 0..<height {
                for x in 0..<width {
                    let index = Int(pixels[tableBytes + y * stride + x])
                    guard index < count else { continue }
                    let base = index * entry
                    let dest = (y * width + x) * 4
                    rgba[dest] = pixels[base]
                    rgba[dest + 1] = pixels[base + 1]
                    rgba[dest + 2] = pixels[base + 2]
                    rgba[dest + 3] = entry == 4 ? pixels[base + 3] : 255
                }
            }
        case 4:
            let stride = (width * 2 + 3) & ~3
            guard stride * height <= pixels.count else { return nil }
            for y in 0..<height {
                for x in 0..<width {
                    let i = y * stride + x * 2
                    let pix = UInt16(pixels[i]) | UInt16(pixels[i + 1]) << 8
                    let r5 = (pix >> 10) & 0x1F
                    let g5 = (pix >> 5) & 0x1F
                    let b5 = pix & 0x1F
                    let dest = (y * width + x) * 4
                    rgba[dest] = UInt8((r5 << 3) | (r5 >> 2))
                    rgba[dest + 1] = UInt8((g5 << 3) | (g5 >> 2))
                    rgba[dest + 2] = UInt8((b5 << 3) | (b5 >> 2))
                    rgba[dest + 3] = 255
                }
            }
        case 5:
            guard pixels.count >= width * height * 4 else { return nil }
            for i in 0..<(width * height) {
                let src = i * 4
                let dest = src
                if version == 2 {
                    rgba[dest] = pixels[src + 1]
                    rgba[dest + 1] = pixels[src + 2]
                    rgba[dest + 2] = pixels[src + 3]
                    rgba[dest + 3] = pixels[src]
                } else {
                    rgba[dest] = pixels[src + 1]
                    rgba[dest + 1] = pixels[src + 2]
                    rgba[dest + 2] = pixels[src + 3]
                    rgba[dest + 3] = 255
                }
            }
        default:
            return nil
        }
        return Data(rgba)
    }

    private static func imageFromRGBA(width: Int, height: Int, rgba: Data, premultiplied: Bool) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let alpha: CGImageAlphaInfo = premultiplied ? .premultipliedLast : .last
        let bitmapInfo = CGBitmapInfo(rawValue: alpha.rawValue)
        guard let provider = CGDataProvider(data: rgba as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func sanitizeFlashJPEG(_ data: Data) -> Data {
        let bytes = [UInt8](data)
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) || bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return data
        }
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            if i + 3 < bytes.count,
               bytes[i] == 0xFF, bytes[i + 1] == 0xD9,
               bytes[i + 2] == 0xFF, bytes[i + 3] == 0xD8 {
                i += 4
                continue
            }
            out.append(bytes[i])
            i += 1
        }
        if out.count >= 2, out[0] == 0xFF, out[1] == 0xD8 {
            return Data(out)
        }
        return Data([0xFF, 0xD8] + out)
    }

    private static func imageSize(of data: Data) -> (Int, Int)? {
        let bytes = [UInt8](data)
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), bytes.count >= 24 {
            let width = (Int(bytes[16]) << 24) | (Int(bytes[17]) << 16) | (Int(bytes[18]) << 8) | Int(bytes[19])
            let height = (Int(bytes[20]) << 24) | (Int(bytes[21]) << 16) | (Int(bytes[22]) << 8) | Int(bytes[23])
            return (width, height)
        }
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]), bytes.count >= 10 {
            let width = Int(bytes[6]) | Int(bytes[7]) << 8
            let height = Int(bytes[8]) | Int(bytes[9]) << 8
            return (width, height)
        }
        return jpegSize(bytes)
    }

    private static func jpegSize(_ bytes: [UInt8]) -> (Int, Int)? {
        guard bytes.count >= 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { return nil }
        var i = 2
        while i + 1 < bytes.count {
            guard bytes[i] == 0xFF else { return nil }
            var j = i + 1
            while j < bytes.count, bytes[j] == 0xFF { j += 1 }
            guard j < bytes.count else { return nil }
            let marker = bytes[j]
            if marker == 0xD8 || marker == 0xD9 || marker == 0x01 || (0xD0...0xD7).contains(marker) {
                i = j + 1
                continue
            }
            guard j + 2 < bytes.count else { return nil }
            let length = (Int(bytes[j + 1]) << 8) | Int(bytes[j + 2])
            if (0xC0...0xC3).contains(marker) {
                guard j + 7 < bytes.count else { return nil }
                let height = (Int(bytes[j + 4]) << 8) | Int(bytes[j + 5])
                let width = (Int(bytes[j + 6]) << 8) | Int(bytes[j + 7])
                return (width, height)
            }
            i = j + 1 + max(length, 2)
        }
        return nil
    }

    private static func inflateZlib(_ data: Data, limit: Int? = nil) -> Data? {
        inflate(data, windowBits: MAX_WBITS, limit: limit)
    }

    private static func inflateRaw(_ data: Data, limit: Int? = nil) -> Data? {
        inflate(data, windowBits: -MAX_WBITS, limit: limit)
    }

    private static func inflate(_ data: Data, windowBits: Int32, limit: Int?) -> Data? {
        guard !data.isEmpty else { return nil }
        let maxOutput = min(limit ?? maxFileBytes, maxFileBytes)
        return data.withUnsafeBytes { inputBuffer -> Data? in
            guard let inputBase = inputBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else { return nil }
            var stream = z_stream()
            stream.next_in = UnsafeMutablePointer(mutating: inputBase)
            stream.avail_in = uInt(data.count)
            guard inflateInit2_(&stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                return nil
            }
            defer { inflateEnd(&stream) }

            var output = Data()
            output.reserveCapacity(min(maxOutput, 64 * 1024))
            var buffer = [UInt8](repeating: 0, count: 16 * 1024)
            var status: Int32 = Z_OK
            repeat {
                if output.count >= maxOutput { break }
                let produced = buffer.withUnsafeMutableBufferPointer { pointer -> Int in
                    let avail = uInt(min(pointer.count, maxOutput - output.count))
                    stream.next_out = pointer.baseAddress
                    stream.avail_out = avail
                    status = zlib.inflate(&stream, Z_SYNC_FLUSH)
                    return Int(avail) - Int(stream.avail_out)
                }
                if produced > 0 {
                    output.append(buffer, count: produced)
                }
            } while status == Z_OK

            if status == Z_STREAM_END || (limit != nil && output.count >= min(limit ?? 0, maxOutput)) || !output.isEmpty && status == Z_BUF_ERROR {
                return output.isEmpty ? nil : output
            }
            return status == Z_OK || status == Z_STREAM_END ? output : nil
        }
    }

    private static func u16(_ bytes: [UInt8], _ index: Int) -> UInt16? {
        guard index + 1 < bytes.count else { return nil }
        return UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8
    }

    private static func intU32(_ bytes: [UInt8], _ index: Int) -> Int {
        guard index + 3 < bytes.count else { return 0 }
        let value = UInt32(bytes[index])
            | UInt32(bytes[index + 1]) << 8
            | UInt32(bytes[index + 2]) << 16
            | UInt32(bytes[index + 3]) << 24
        return Int(value)
    }
}
