//
//  SkinPreviewViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/27.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

import AVFoundation

class SkinPreviewViewController: BaseViewController {
    
    private let skin: ControllerSkin
    private let traits: ControllerSkin.Traits
    
    private let closeButtonView = ASButtonView(.smallCloseButton())
    
    private lazy var controlView: ControllerView = {
        let view = ControllerView()
        view.overrideControllerSkinTraits = traits
        view.controllerSkin = skin
        view.addReceiver(self)
        return view
    }()

    init(skin: ControllerSkin, traits: ControllerSkin.Traits, window: UIWindow) {
        self.skin = skin
        self.traits = traits
        super.init(fullScreen: true)
        
        enableBackgroundMask = false
        
        view.addSubview(controlView)
        
        var needToRotate = false
        let isLandscapeLayoutIPad = UIDevice.isPad && ((UIDevice.isFullScreenIPad(window: window) &&  UIDevice.isLandscape) || window.size.IsRelativelyWideRectangle)
        
        if UIDevice.isPhone || UIDevice.isFullScreenIPad(window: window) {
            if traits.orientation == .portrait && UIDevice.isLandscape {
                needToRotate = true
            } else if traits.orientation == .landscape && UIDevice.isPortrait {
                needToRotate = true
            }
        }
        
        if needToRotate {
            controlView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                if let aspectRatio = skin.aspectRatio(for: traits) {
                    let frame = AVMakeRect(aspectRatio: aspectRatio, insideRect: CGRect(origin: .zero, size: R.Size.ApplicationWindowSize.swapSide))
                    make.size.equalTo(frame.size)
                }
            }
            controlView.transform = .init(rotationAngle: .pi/2)
        } else {
            controlView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                if let aspectRatio = skin.aspectRatio(for: traits) {
                    let frame = AVMakeRect(aspectRatio: aspectRatio, insideRect: CGRect(origin: .zero, size: R.Size.ApplicationWindowSize))
                    make.size.equalTo(frame.size)
                }
            }
        }
        
        view.addSubview(closeButtonView)
        closeButtonView.didTapButton = { [weak self] in
            self?.dismiss(animated: true)
        }
        closeButtonView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(R.Size.ContentInsetTop(window: hostingWindow))
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceLarge)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch UIDevice.currentOrientation {
        case .portrait:
            AppDelegate.orientation = .portrait
        case .portraitUpsideDown:
            AppDelegate.orientation = .portraitUpsideDown
        case .landscapeLeft:
            AppDelegate.orientation = .landscapeLeft
        case .landscapeRight:
            AppDelegate.orientation = .landscapeRight
        default: break
        }
        if #available(iOS 26.0, tvOS 26.0, *) {
            controlView.setNeedsLayout()
            controlView.layoutIfNeeded()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppDelegate.orientation = R.Config.DefaultOrientation
    }
}

extension SkinPreviewViewController: GameControllerReceiver {
    func gameController(_ gameController: any DeltaCore.GameController, didDeactivate input: any DeltaCore.Input) {
        
    }
    
    func gameController(_ gameController: any GameController, didActivate input: any Input, value: Double) {
        Log.debug("点击 input:\(input) value:\(value)")
#if DEBUG
        UIView.makeToast(message: "\(input.stringValue)", duration: 1)
#endif
    }
}
