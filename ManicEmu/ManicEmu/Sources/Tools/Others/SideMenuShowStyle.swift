//
//  SideMenuShowStyle.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2023/5/30.
//  Copyright © 2023 Aoshuang Lee. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import SideMenu

class SideMenuShowStyle: SideMenuPresentationStyle {
    
    private class CoverView: BaseView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.backgroundColor = UIColor(.dm, light: .white.withAlphaComponent(0.35), dark: .black.withAlphaComponent(0.7))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var coverView = CoverView()

    required init() {
        super.init()
        /// Background color behind the views and status bar color
        backgroundColor = UIColor(.dm, light: .white, dark: .black)
        /// The starting alpha value of the menu before it appears
        menuStartAlpha = 1
        /// Whether or not the menu is on top. If false, the presenting view is on top. Shadows are applied to the view on top.
        menuOnTop = false
        /// The amount the menu is translated along the x-axis. Zero is stationary, negative values are off-screen, positive values are on screen.
        menuTranslateFactor = -1
        /// The amount the menu is scaled. Less than one shrinks the view, larger than one grows the view.
        menuScaleFactor = 1
        /// The color of the shadow applied to the top most view.
        onTopShadowColor = UIColor(.dm, light: .white, dark: .black)
        /// The radius of the shadow applied to the top most view.
        onTopShadowRadius = 5
        /// The opacity of the shadow applied to the top most view.
        onTopShadowOpacity = 0
        /// The offset of the shadow applied to the top most view.
        onTopShadowOffset = .zero
        /// The ending alpha of the presenting view when the menu is fully displayed.
        presentingEndAlpha = 1
        /// The amount the presenting view is translated along the x-axis. Zero is stationary, negative values are off-screen, positive values are on screen.
        presentingTranslateFactor = 1-(R.Size.ApplicationWindowSize.width*(1-0.879))/2/R.Size.ApplicationWindowSize.width
        /// The amount the presenting view is scaled. Less than one shrinks the view, larger than one grows the view.
        presentingScaleFactor = 0.879
        /// The strength of the parallax effect on the presenting view once the menu is displayed.
//        presentingParallaxStrength = CGSize(width: 100, height: 100)
    }
    
    override func presentationTransitionWillBegin(to presentedViewController: UIViewController, from presentingViewController: UIViewController) {
        if let duration = (presentedViewController as? SideMenuNavigationController)?.presentDuration {
            coverView.removeFromSuperview()
            coverView.alpha = 0
            presentingViewController.view.addSubview(coverView)
            coverView.snp.makeConstraints { make in
                make.edges.equalTo(presentingViewController.view)
            }
            UIView.animate(withDuration: duration) {
                presentingViewController.view.layerCornerRadius = 36
                self.coverView.alpha = 1
            }
        }
    }
    
    override func presentationTransitionDidEnd(to presentedViewController: UIViewController, from presentingViewController: UIViewController, _ completed: Bool) {
        if completed {
            self.coverView.alpha = 1
        }
    }
    
    override func dismissalTransitionWillBegin(to presentedViewController: UIViewController, from presentingViewController: UIViewController) {
        if let duration = (presentedViewController as? SideMenuNavigationController)?.dismissDuration {
            UIView.animate(withDuration: duration) {
                presentingViewController.view.layerCornerRadius = 0
                self.coverView.alpha = 0
            }
        }
    }
    
    override func dismissalTransitionDidEnd(to presentedViewController: UIViewController, from presentingViewController: UIViewController, _ completed: Bool) {
        if completed {
            self.coverView.removeFromSuperview()
        }
    }
    
}
