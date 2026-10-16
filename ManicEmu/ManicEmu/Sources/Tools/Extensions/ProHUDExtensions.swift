//
//  ProHUDExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/15.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import ProHUD

func proHUDWindow() -> UIWindow? {
    AppContext.appWindow ?? UIWindow.applicationWindow
}

func proHUDLayoutStyle() -> UIView.LayoutStyle {
    if let w = proHUDWindow() {
        return w.size.IsRelativelyWideRectangle ? .landscape : .portrait
    }
    return UIDevice.isLandscape ? .landscape : .portrait
}


