//
//  OnlinePlaySettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit


class OnlinePlaySettingView: BaseView {
    
    private enum SectionIndex: Int, CaseIterable {
        case ds, psp, pretendo, libretro
        var title: String {
            switch self {
            case .ds: R.string.localizable.nintendoWFC()
            case .psp: R.string.localizable.pspNetworking()
            case .pretendo: GameType._3ds.localizedShortName + " " + R.string.localizable.pretendo()
            case .libretro: R.string.localizable.othreNetworking()
            }
        }
    }
    
    private let showClose: Bool
    
    private lazy var listPageView: ASListPageView = {
        var navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.onlinePlaySetting(),
                                                                 titleIcon: .symbolImage(R.image.online_iconSymbols()))
        navigation.enableClose = showClose
        
        let sections = SectionIndex.allCases.enumerated().map({
            var header: ASListPage.Supplementary? = nil
            if $0 == 0 {
                header = .texts([.smallText(R.string.localizable.onlinePlaySettingDesc(),
                                            numberOfLines: 0)],
                                pin: false)
            }
            return ASListPage.Section(cells: [.iconTitleChevronCell(title: $1.title)],
                                      header: header)
            
        })
        let view = ASListPageView(.init(navigation: navigation,
                                        sections: sections,
                                        backgroundColor: .clear,
                                        pageInsets: .insets(top: showClose ? R.Size.SheetGrabberTopInset : R.Size.ContentInsetTop(window: hostingWindow))))
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            if let navigationValue = action.navigationValue {
                if navigationValue.isTapClose {
                    self.hide()
                }
            } else if let section = action.normalItemValue?.indexPath.section {
                if section == 0 {
                    //NDS
                    WFCSettingView.show()
                } else if section == 1 {
                    //PSP
                    PSPNetworkingView.show()
                } else if section == 2 {
                    //3DS
                    PretendoNetworkingView.show()
                } else if section == 3 {
                    //Other
                    LibretroNetplayView.show()
                }
            }
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    convenience init(showClose: Bool) {
        self.init(parameters: showClose)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension OnlinePlaySettingView: ShowableView {
    
}
