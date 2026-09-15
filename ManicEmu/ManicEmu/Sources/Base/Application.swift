//
//  Application.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class ManicApplication: UIApplication {
    //Keyboard events are now uniformly captured by DeltaCore's KeyboardGameController (GCKeyboard),
    //and the private API path via handleKeyUIEvent is no longer used.
    
    override func sendEvent(_ event: UIEvent) {
        // When the user touches the screen, it signals a switch to touch-based interaction, removing FocusKit's current focus (the position is remembered and can be restored with the arrow keys).
        if event.type == .touches,
           let touches = event.allTouches,
           touches.contains(where: { $0.phase == .began }) {
            FocusSystem.shared.userDidTouchScreen()
        }
        super.sendEvent(event)
    }
    
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let event, PlayViewController.isGaming,
            let gameType = PlayViewController.currentGameType,
           (gameType.supportsKeyboardSkin || gameType == .symbian) {
            for press in presses {
                LibretroCore.sharedInstance().handle(press, with: event, down: true)
            }
            super.pressesBegan(presses, with: event)
            return
        }
        // Gamepad UIPress on iPad drives system focus on the main thread (Metal hitch).
        // Keyboard keys while typing must still reach the text field.
        if shouldForwardPressesToUIKit(presses) {
            super.pressesBegan(presses, with: event)
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let event, PlayViewController.isGaming,
            let gameType = PlayViewController.currentGameType,
           (gameType.supportsKeyboardSkin || gameType == .symbian) {
            for press in presses {
                LibretroCore.sharedInstance().handle(press, with: event, down: false)
            }
            super.pressesEnded(presses, with: event)
            return
        }
        if shouldForwardPressesToUIKit(presses) {
            super.pressesEnded(presses, with: event)
        }
    }
    
    private func shouldForwardPressesToUIKit(_ presses: Set<UIPress>) -> Bool {
        let hasKeyboardKey = presses.contains { $0.key != nil }
        return hasKeyboardKey && FocusSystem.shared.isEditingText
    }
    
}
