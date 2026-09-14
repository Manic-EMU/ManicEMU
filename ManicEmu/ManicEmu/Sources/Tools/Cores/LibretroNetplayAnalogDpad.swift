//
//  LibretroNetplayAnalogDpad.swift
//  ManicEmu
//
//  RetroArch netplay only serializes JOYPAD bits. Analog axes from moveStick
//  are dropped. This helper mirrors one analog stick onto D-pad while netplay
//  is active, OR'd with the physical D-pad so they do not cancel each other.
//

import CoreGraphics
import Foundation

final class LibretroNetplayAnalogDpad {
    var threshold: CGFloat = 0.35

    private struct DpadBits {
        var up = false
        var down = false
        var left = false
        var right = false
    }

    private var stick = CGPoint.zero
    private var dpadFromButtons = DpadBits()
    private var dpadFromStick = DpadBits()
    private var dpadSent = DpadBits()
    private var playerIndex = 0
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: Notification.Name(rawValue: "LibretroNetplayEventNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshStickDpad()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Always sends analog via `moveStick`. During netplay, also maps the stick onto D-pad.
    func moveStick(isLeft: Bool, x: CGFloat, y: CGFloat, playerIndex: Int, forceSyncDpad: Bool = false) {
        self.playerIndex = playerIndex
        stick = CGPoint(x: x, y: y)
        LibretroCore.sharedInstance().moveStick(isLeft, x: x, y: y, playerIndex: UInt32(playerIndex))
        refreshStickDpad(forceSyncDpad: forceSyncDpad)
    }

    /// Returns `true` when `button` is a D-pad direction (already applied).
    @discardableResult
    func handleDpad(_ button: LibretroButton, pressed: Bool, playerIndex: Int) -> Bool {
        switch button {
        case .up: dpadFromButtons.up = pressed
        case .down: dpadFromButtons.down = pressed
        case .left: dpadFromButtons.left = pressed
        case .right: dpadFromButtons.right = pressed
        default: return false
        }
        self.playerIndex = playerIndex
        syncDpad()
        return true
    }

    private func refreshStickDpad(forceSyncDpad: Bool = false) {
        if LibretroNetplaySession.shared.isNetplay || forceSyncDpad {
            dpadFromStick.up = stick.y > threshold
            dpadFromStick.down = stick.y < -threshold
            dpadFromStick.left = stick.x < -threshold
            dpadFromStick.right = stick.x > threshold
        } else {
            dpadFromStick = DpadBits()
        }
        syncDpad()
    }

    private func syncDpad() {
        let player = UInt32(playerIndex)
        func apply(_ on: Bool, _ was: inout Bool, _ button: LibretroButton) {
            guard on != was else { return }
            was = on
            if on {
                LibretroCore.sharedInstance().press(button, playerIndex: player)
            } else {
                LibretroCore.sharedInstance().release(button, playerIndex: player)
            }
        }
        apply(dpadFromButtons.up || dpadFromStick.up, &dpadSent.up, .up)
        apply(dpadFromButtons.down || dpadFromStick.down, &dpadSent.down, .down)
        apply(dpadFromButtons.left || dpadFromStick.left, &dpadSent.left, .left)
        apply(dpadFromButtons.right || dpadFromStick.right, &dpadSent.right, .right)
    }
}
