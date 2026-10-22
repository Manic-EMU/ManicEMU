//
//  ImportViewController.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/29.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import SideMenu

class ImportViewController: BaseViewController {
    private var cornerMaskViewForiPad: TransparentHoleView = {
        let view = TransparentHoleView()
        return view
    }()
    
    private lazy var importServiceListView: ImportServiceListView = {
        let view = ImportServiceListView()
        view.didTapAddService = { [weak self] in
            guard let self = self else { return }
            self.showSideMenu()
        }
        return view
    }()
    
    private lazy var addImportServiceView: AddImportServiceView = {
        let view = AddImportServiceView()
        view.requireToHideSideMenu = { [weak self] in
            guard let self = self else { return }
            self.hideSideMenu()
        }
        return view
    }()
    
    private weak var sideMenu: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if (UIDevice.isPad || UIDevice.isPhoneDuoInnerFullScreen), hostingWindow != nil {
            updateViewsForLargeScreen()
        } else if UIDevice.isPhoneDuo {
            addImportServiceView.removeFromSuperview()
            cornerMaskViewForiPad.removeFromSuperview()
            
            importServiceListView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                if UIDevice.isPhoneDuoCompactWidth {
                    make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
                } else {
                    make.leading.trailing.equalToSuperview()
                }
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self else { return }
            if UIDevice.isPhone || (UIDevice.isPad && self.view.isWindowHasEnoughSpaceforIpadMultiColumnLayout) {
                self.hideSideMenu()
            }
        }
    }
    
    private func setupViews() {
        if UIDevice.isPhone {
            view.addSubview(importServiceListView)
            importServiceListView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            }
        } else {
            view.backgroundColor = UIColor(.dm, light: .white, dark: .black)
            importServiceListView.backgroundColor = R.Color.BackgroundPrimary
            view.addSubview(importServiceListView)
        }
    }
    
    private func updateViewsForLargeScreen() {
        guard UIDevice.isPad || UIDevice.isPhoneDuoInnerFullScreen else { return }
        guard let hostingWindow else { return }
        if view.isWindowHasEnoughSpaceforIpadMultiColumnLayout || UIDevice.isPhoneDuoInnerFullScreen {
            let sideMenuWidth = R.Size.SideMenuWidth(window: hostingWindow)*(UIDevice.isPhoneDuoInnerFullScreen ? 1.0 : 1.2)
            importServiceListView.snp.remakeConstraints { make in
                make.top.bottom.trailing.equalToSuperview()
                if sideMenuWidth <= hostingWindow.width/2 {
                    make.width.equalToSuperview().offset(-sideMenuWidth)
                } else {
                    make.width.equalToSuperview().offset(-hostingWindow.width/2)
                }
            }
            
            addImportServiceView.removeFromSuperview()
            view.addSubview(addImportServiceView)
            
            addImportServiceView.snp.remakeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                make.trailing.equalTo(importServiceListView.snp.leading)
            }
            
            if UIDevice.isPad {
                cornerMaskViewForiPad.removeFromSuperview()
                view.addSubview(cornerMaskViewForiPad)
                cornerMaskViewForiPad.snp.remakeConstraints { make in
                    make.edges.equalTo(importServiceListView)
                }
            }
        } else {
            importServiceListView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            }
            addImportServiceView.removeFromSuperview()
            cornerMaskViewForiPad.removeFromSuperview()
        }
    }
    
    override func handleScreenPanGesture(edges: UIRectEdge, gesture: UIScreenEdgePanGestureRecognizer) {
        if (UIDevice.isPhone && !UIDevice.isPhoneDuoInnerFullScreen) || (UIDevice.isPad && view.preferredLayoutStyle == .portrait && !view.isWindowHasEnoughSpaceforIpadMultiColumnLayout) {
            if edges == .left {
                showSideMenu()
            }
        }
    }
    
    private func showSideMenu() {
        UIDevice.generateHaptic()
        let containerVC = BaseViewController()
        containerVC.enableBackgroundMask = false
        containerVC.view.backgroundColor = .clear
        containerVC.view.addSubview(addImportServiceView)
        addImportServiceView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        let menu = SideMenuNavigationController(rootViewController: containerVC)
        menu.navigationBar.isHidden = true
        menu.presentDuration = R.Numbers.LongAnimationDuration
        menu.dismissDuration = R.Numbers.LongAnimationDuration
        menu.leftSide = !Locale.isRTLLanguage
        menu.menuWidth = R.Size.SideMenuWidth(window: hostingWindow)
        menu.presentationStyle = SideMenuShowStyle()
        topViewController(in: hostingWindowScene)?.present(menu, animated: true)
        sideMenu = menu
    }
    
    private func hideSideMenu() {
        sideMenu?.dismiss(animated: true)
    }
}

