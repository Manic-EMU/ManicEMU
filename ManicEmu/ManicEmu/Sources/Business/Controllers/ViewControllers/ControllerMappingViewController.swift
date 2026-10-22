//
//  ControllerMappingViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit


class ControllerMappingViewController: BaseViewController {
    private static weak var capturingInstance: ControllerMappingViewController?
    static var isCapturingInput: Bool { capturingInstance != nil }
    
    private var controllerMappingView: ControllerMappingView
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init() is unavailable")
    }
    
    init(gameType: GameType, controller: GameController) {
        self.controllerMappingView = ControllerMappingView(gameType: gameType, controller: controller)
        super.init(fullScreen: true)
        self.controllerMappingView.didTapClose = { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true)
        }
    }
    
    init(games: [Game], controller: GameController) {
        self.controllerMappingView = ControllerMappingView(games: games, controller: controller)
        super.init(fullScreen: true)
        self.controllerMappingView.didTapClose = { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(controllerMappingView)
        controllerMappingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override var shouldManageFocusContext: Bool { false }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Self.capturingInstance = self
        PlayViewController.refreshExternalInputSink()
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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if Self.capturingInstance === self {
            Self.capturingInstance = nil
        }
        PlayViewController.refreshExternalInputSink()
        AppDelegate.orientation = R.Config.DefaultOrientation
    }
    
    override var prefersStatusBarHidden: Bool {
        if UIDevice.isPhoneDuo {
             return true
        }
        return super.prefersStatusBarHidden
    }
}
