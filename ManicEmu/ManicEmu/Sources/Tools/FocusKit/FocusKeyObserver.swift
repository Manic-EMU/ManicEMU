//
//  FocusKeyObserver.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation

/// Converts game-controller and keyboard events into FocusKey input.
///
/// Both come from DeltaCore `externalGameControllerDidPress/DidRelease`.
/// Keyboard is captured by KeyboardGameController via GCKeyboard (raw HID),
/// bypassing UIKit UIKeyCommand / system shortcut consumption (except reserved chords such as ⌃⌘F).
///
/// Only handles events while `ExternalInputDispatch.sink == .focusKit` (not playing, or paused).
/// In-game keys go to PlayViewController and the core, not this class.
///
/// This class only:
/// 1. Deduplicates held stick directions
/// 2. Combines keyboard modifiers into a chord in fixed order control → option → shift → command,
///    independent of press order; releasing a modifier emits the full chord from before the release
///    so press/release stay paired.
class FocusKeyObserver {
    static let shared = FocusKeyObserver()
    
    private var externalGameControllerDidPress: Any? = nil
    private var externalGameControllerDidRelease: Any? = nil
    private var externalGameControllerDidDisconnect: Any? = nil
    private var externalKeyboardDidDisconnect: Any? = nil
    
    // MARK: - Keyboard state
    
    /// Canonical modifier order for chords, independent of press order.
    private static let modifierOrder = ["control", "option", "shift", "command"]
    /// Left/right RETROK names fold into the same FocusKit modifier.
    private static let modifierAliases: [String: String] = [
        "control": "control", "ctrl": "control", "lctrl": "control", "rctrl": "control",
        "option": "option", "alt": "option", "lalt": "option", "ralt": "option",
        "shift": "shift", "lshift": "shift", "rshift": "shift",
        "command": "command", "meta": "command", "lmeta": "command", "rmeta": "command"
    ]
    private static var heldModifiers = Set<String>()
    /// Non-modifier key → composed chord at press time; replayed on release.
    private static var activeComposedKeys = [String: String]()
    
    func start() {
        _ = FocusSystem.shared
        externalGameControllerDidPress = NotificationCenter.default.addObserver(forName: .externalGameControllerDidPress, object: nil, queue: .main) { notification in
            guard ExternalInputDispatch.sink == .focusKit else { return }
            
            if let userInfo = notification.userInfo,
               let input = userInfo["input"] as? any Input {
                guard input.type != .controller(.controllerSkin) else { return }
                if input.type == .controller(.keyboard) {
                    if FocusSystem.shared.isEditingText {
                        // Letters stay with the field; Escape still ends editing.
                        if input.stringValue == "escape" {
                            Self.handleKeyboard(input.stringValue, isPressed: true)
                        }
                        return
                    }
                    Self.handleKeyboard(input.stringValue, isPressed: true)
                    return
                }
                
                Self.activateKey(input.stringValue)
            }
        }
        
        externalGameControllerDidRelease = NotificationCenter.default.addObserver(forName: .externalGameControllerDidRelease, object: nil, queue: .main) { notification in
            guard ExternalInputDispatch.sink == .focusKit else { return }
            
            if let userInfo = notification.userInfo,
               let input = userInfo["input"] as? any Input {
                guard input.type != .controller(.controllerSkin) else { return }
                if input.type == .controller(.keyboard) {
                    Self.handleKeyboard(input.stringValue, isPressed: false)
                    return
                }
                
                Self.deactivateKey(input.stringValue)
            }
        }
        
        // Controller or hardware keyboard disconnected: clear focus highlight when no devices remain.
        let onDisconnect: (Notification) -> Void = { notification in
            if notification.object is KeyboardGameController {
                Self.resetKeyboardState()
            }
            FocusSystem.shared.handleExternalInputDidChange()
        }
        externalGameControllerDidDisconnect = NotificationCenter.default.addObserver(
            forName: .externalGameControllerDidDisconnect,
            object: nil,
            queue: .main,
            using: onDisconnect
        )
        externalKeyboardDidDisconnect = NotificationCenter.default.addObserver(
            forName: .externalKeyboardDidDisconnect,
            object: nil,
            queue: .main,
            using: onDisconnect
        )
    }
    
    // MARK: - Keyboard handling
    
    func handleTextEditingDidBegin() {
        Self.resetKeyboardState()
    }
    
    private static func resetKeyboardState() {
        heldModifiers.removeAll()
        activeComposedKeys.removeAll()
    }
    
    private static func handleKeyboard(_ keyName: String, isPressed: Bool) {
        let keyName = modifierAliases[keyName] ?? keyName
        let isModifier = modifierOrder.contains(keyName)
        
        if isPressed {
            if isModifier {
                guard !heldModifiers.contains(keyName) else { return }
                heldModifiers.insert(keyName)
                // Modifier down: emit the full held-modifier chord in fixed order.
                activateKey(composedChord())
            } else {
                guard activeComposedKeys[keyName] == nil else { return }
                let composed = composedKey(with: keyName)
                activeComposedKeys[keyName] = composed
                activateKey(composed)
            }
        } else {
            if isModifier {
                guard heldModifiers.contains(keyName) else { return }
                // Modifier up: emit the chord from before the release so it pairs with activate.
                // Holding control+shift+command and releasing one-by-one:
                // control+shift+command → control+command → command
                let composed = composedChord()
                heldModifiers.remove(keyName)
                deactivateKey(composed)
            } else {
                guard let composed = activeComposedKeys.removeValue(forKey: keyName) else { return }
                deactivateKey(composed)
            }
        }
    }
    
    /// Held modifiers joined in fixed order, e.g. "control+shift+command".
    private static func composedChord() -> String {
        return modifierOrder.filter { heldModifiers.contains($0) }.joined(separator: "+")
    }
    
    /// Non-modifier plus current modifiers, e.g. "control+command+f".
    private static func composedKey(with keyName: String) -> String {
        var parts = modifierOrder.filter { heldModifiers.contains($0) }
        parts.append(keyName)
        return parts.joined(separator: "+")
    }
    
    // MARK: - Output
    
    private static func activateKey(_ key: String) {
        FocusSystem.shared.keyDown(mappingKey(key))
    }
    
    private static func deactivateKey(_ key: String) {
        // Same mapping on release so keyDown/keyUp stay paired.
        FocusSystem.shared.keyUp(mappingKey(key))
    }
    
    private static func mappingKey(_ key: String) -> FocusKey {
        if key == "leftThumbstickLeft" {
            return .left
        } else if key == "leftThumbstickRight" {
            return .right
        } else if key == "leftThumbstickUp" {
            return .up
        } else if key == "leftThumbstickDown" {
            return .down
        } else if key == "rightThumbstickLeft" {
            return .left
        } else if key == "rightThumbstickRight" {
            return .right
        } else if key == "rightThumbstickUp" {
            return .up
        } else if key == "rightThumbstickDown" {
            return .down
        } else if key == "return" {
            return .a
        } else if key == "escape" {
            return .b
        } else if key == "leftShoulder" {
            return FocusKey("l1")
        } else if key == "rightShoulder" {
            return FocusKey("r1")
        } else if key == "leftTrigger" {
            return FocusKey("l2")
        } else if key == "rightTrigger" {
            return FocusKey("r2")
        } else if key == "leftThumbstickButton" {
            return FocusKey("l3")
        } else if key == "rightThumbstickButton" {
            return FocusKey("r3")
        }
        return FocusKey(key)
    }
    
}
