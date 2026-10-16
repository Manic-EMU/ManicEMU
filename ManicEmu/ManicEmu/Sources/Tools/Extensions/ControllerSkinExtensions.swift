//
//  ControllerSkinExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension ControllerSkin {
    func getFrames(window: UIWindow, scale: CGFloat = 1) -> (skinFrame: CGRect, mainGameViewFrame: CGRect, touchGameViewFrame: CGRect?)? {
        let traits: ControllerSkin.Traits = ControllerSkin.Traits.defaults(for: window)
        if let screens = self.screens(for: traits), let aspectRatio = self.aspectRatio(for: traits) {
            var skinFrame = AVMakeRect(aspectRatio: aspectRatio, insideRect: window.bounds).rounded()
            if scale != 1 {
                skinFrame = skinFrame.applying(CGAffineTransform(scaleX: scale, y: scale))
            }
            var mainGameViewFrame: CGRect = .zero
            var touchGameViewFrame: CGRect? = nil
            for screen in screens {
                if let outputFrame = screen.outputFrame {
                    if screen.isTouchScreen {
                        touchGameViewFrame = outputFrame.applying(.init(scaleX: skinFrame.width, y: skinFrame.height)).rounded()
                    } else {
                        mainGameViewFrame = outputFrame.applying(.init(scaleX: skinFrame.width, y: skinFrame.height)).rounded()
                    }
                }
            }
            return (skinFrame, mainGameViewFrame, touchGameViewFrame)
        }
        return nil
    }
}
