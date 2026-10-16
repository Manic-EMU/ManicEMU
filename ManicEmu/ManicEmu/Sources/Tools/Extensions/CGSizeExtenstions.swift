//
//  CGSizeExtenstions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/17.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

extension CGSize {
    init(_ size: CGFloat) {
        self.init(width: size, height: size)
    }
    
    func insetBy(dx: CGFloat, dy: CGFloat) -> CGSize {
        return CGSize(width: width - (dx * 2), height: height - (dy * 2))
    }
    
    func scaleBy(_ scale: CGFloat) -> CGSize {
        return CGSize(width: width * scale, height: height * scale)
    }
    
    var swapSide: CGSize {
        return CGSize(width: height, height: width)
    }
    
    var IsRelativelyWideRectangle: Bool {
        guard self != .zero else { return false }
        return width/height > 1.333
    }
}
