//
//  GamesNavigationView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/25.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class GamesNavigationView: BaseView {
    private var appTitle: ASIconView = {
        let view = ASIconView(.image(R.image.app_title()!))
        return view
    }()
    
    var controllerButton: ASButtonView = {
        let view = ASButtonView(.iconOnlyWithSmallSize(icon: .symbolImage(R.image.controller_iconSymbols())).enableGlass(true))
        return view
    }()
    
    var historyButton: ASButtonView = {
        let view = ASButtonView(.iconOnlyWithSmallSize(icon: .symbolImage(R.image.history_iconSymbols())).enableGlass(true))
        return view
    }()
    
    var scrollToTopView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubviews([scrollToTopView, controllerButton, appTitle, historyButton])
        scrollToTopView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalToSuperview().dividedBy(2)
        }
        
        appTitle.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        controllerButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
        }
        
        historyButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
