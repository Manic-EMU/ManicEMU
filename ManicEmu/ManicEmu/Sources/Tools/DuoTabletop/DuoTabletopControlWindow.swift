//
//  DuoTabletopControlWindow.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

/// Receives the bottom-pane touches without becoming the key window.
@available(iOS 27.1, *)
final class DuoTabletopControlWindow: UIWindow {
    override var canBecomeKey: Bool { false }
}
