//
//  ControllerSkinExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension ControllerSkinProtocol {
    /// Traits this skin is drawn with for the given screen traits.
    /// iPhone Duo screens (inner/outer/splitView/cover) fall back to other representations the way DeltaCore does,
    /// because most skins have no Duo representations. Other devices keep the exact match.
    func resolvedTraits(for traits: ControllerSkin.Traits) -> ControllerSkin.Traits? {
        if traits.device == .iphone, traits.displayType != .standard, traits.displayType != .edgeToEdge {
            return supportedTraits(for: traits)
        }
        return supports(traits) ? traits : nil
    }
}

extension ControllerSkin.Traits {
    /// iPhone skin for a small screen: a standard (home button) iPhone or the iPhone Duo outer screen.
    var isSmallPhoneScreen: Bool {
        device == .iphone && (displayType == .standard || displayType == .outer)
    }
}

extension UIScreen {
    /// The screen showing the app's window. On iPhone Duo `UIScreen.main` stays the outer screen
    /// while the app runs on the inner one; on other devices this is `UIScreen.main`.
    static var current: UIScreen { UIWindow.applicationWindow?.screen ?? UIScreen.main }
}

extension ControllerSkin {
    func getFrames(traits: ControllerSkin.Traits = ControllerSkin.Traits.defaults(for: UIWindow.applicationWindow ?? UIWindow(frame: .init(origin: .zero, size: R.Size.WindowSize))), scale: CGFloat = 1) -> (skinFrame: CGRect, mainGameViewFrame: CGRect, touchGameViewFrame: CGRect?)? {
        let traits = resolvedTraits(for: traits) ?? traits
        if let screens = self.screens(for: traits), let aspectRatio = self.aspectRatio(for: traits) {
            var skinFrame = AVMakeRect(aspectRatio: aspectRatio, insideRect: UIScreen.current.bounds).rounded()
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
