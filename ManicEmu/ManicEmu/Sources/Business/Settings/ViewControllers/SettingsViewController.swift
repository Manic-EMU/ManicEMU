//
//  SettingsViewController.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/29.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class SettingsViewController: BaseViewController {
    
    private lazy var cornerMaskViewForiPad: TransparentHoleView = {
        let view = TransparentHoleView()
        return view
    }()
    
    private lazy var detailMaskViewForiPad: TransparentHoleView = {
        let view = TransparentHoleView()
        return view
    }()
    
    private let settingsListView = SettingsListView()
    
    private lazy var detailContentView: UIView = {
        let view = UIView()
        view.backgroundColor = R.Color.BackgroundPrimary
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if UIDevice.isPhone {
            view.addSubview(settingsListView)
            settingsListView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            }
        } else {
            view.addSubview(settingsListView)
            view.backgroundColor = UIColor(.dm, light: .white, dark: .black)
            settingsListView.backgroundColor = R.Color.BackgroundPrimary
            settingsListView.didTapDetailView = { [weak self] view in
                guard let self = self else { return }
                self.detailContentView.subviews.forEach { $0.removeFromSuperview() }
                self.detailContentView.addSubview(view)
                view.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
            }
            
            let themeView = ThemeSettingView(showClose: false)
            detailContentView.addSubview(themeView)
            themeView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if UIDevice.isPad, hostingWindow != nil {
            updateViewsForIpad()
        }
    }
    
    private func updateViewsForIpad() {
        guard UIDevice.isPad else { return }
        guard let hostingWindow else { return }
        if view.isWindowHasEnoughSpaceforIpadMultiColumnLayout {
            let sideMenuWidth = R.Size.SideMenuWidth(window: hostingWindow)*1.2
            settingsListView.snp.remakeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                if sideMenuWidth <= hostingWindow.width/2 {
                    make.width.equalTo(sideMenuWidth)
                } else {
                    make.width.equalTo(hostingWindow.width/2)
                }
            }
            
            cornerMaskViewForiPad.removeFromSuperview()
            view.addSubview(cornerMaskViewForiPad)
            cornerMaskViewForiPad.snp.remakeConstraints { make in
                make.edges.equalTo(settingsListView)
            }
            
            detailContentView.removeFromSuperview()
            view.addSubview(detailContentView)
            detailContentView.snp.remakeConstraints { make in
                make.top.trailing.bottom.equalToSuperview()
                make.leading.equalTo(settingsListView.snp.trailing).offset(R.Size.ContentSpaceMedium)
            }
            
            detailMaskViewForiPad.removeFromSuperview()
            view.addSubview(detailMaskViewForiPad)
            detailMaskViewForiPad.snp.remakeConstraints { make in
                make.edges.equalTo(detailContentView)
            }
        } else {
            settingsListView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            }
            cornerMaskViewForiPad.removeFromSuperview()
            detailContentView.removeFromSuperview()
            detailMaskViewForiPad.removeFromSuperview()
        }
    }
}
