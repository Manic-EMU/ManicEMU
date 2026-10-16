//
//  GlobalCoreSwitchView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import IceCream
import RealmSwift

class GlobalCoreSwitchView: BaseView {
    private var globalCoreConfig: GlobalCoreSwitch
    private let gameTypes: [GameType]
    private lazy var listView: ASListPageView = {
        var navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.globalCoreSwitch(),
                                                                 titleIcon: GameOption.switchCore.icon)
        navigation.enableClose = showClose
        var sections = gameTypes.map({
            let chevronTitle = globalCoreConfig.getUsingCoreName(gameType: $0) ?? $0.supportCores.first
            return ASListPage.Section(cells: [.iconTitleChevronCell(title: $0.localizedName,
                                                                    chevronTitle: chevronTitle)])
        })
        if sections.count > 0 {
            sections[0].header = ASListPage.Supplementary.texts([.smallText(R.string.localizable.globalCoreSwitchDesc(),
                                                                            numberOfLines: 0)],
                                                                pin: false)
        }
        let view = ASListPageView(ASListPage(navigation: navigation,
                                             sections: sections,
                                             backgroundColor: .clear,
                                             listInsets: .insets(bottom: UIDevice.isPad ? R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceLarge : R.Size.ContentInsetBottom(window: hostingWindow)),
                                             pageInsets: .insets(top: showClose ? R.Size.SheetGrabberTopInset : R.Size.ContentInsetTop(window: hostingWindow))))
        view.didActionOccurred = { [weak self] listAction in
            guard let self else { return }
            if let (listAndexPath, cellData, _) = listAction.normalItemValue {
                let gameType = gameTypes[listAndexPath.section]
                let supportCores = gameType.supportCores.filter({ !$0.isEmpty })
                var selectedIndexPath: Int? = nil
                if let currentCoreName = self.globalCoreConfig.getUsingCoreName(gameType: gameType) ?? gameType.supportCores.first,
                   let currentIndex = supportCores.firstIndex(where: { $0 == currentCoreName }) {
                    selectedIndexPath = currentIndex
                }
                
                OptionsSheetView.show(icon: GameOption.switchCore.icon,
                                      title: R.string.localizable.switchEmulationCore(),
                                      detail: R.string.localizable.switchEmulationCoreDetail(gameType.localizedShortName),
                                      options: supportCores,
                                      selectedIndex: selectedIndexPath, completion: { index in
                    if let index {
                        let coreName = supportCores[index]
                        guard self.globalCoreConfig.getUsingCoreName(gameType: gameType) != coreName else { return }
                        
                        self.globalCoreConfig.setUsingCoreName(gameType: gameType, coreName: coreName)
                        self.listView.updateCellData(cellData.updateNormalChevron(title: self.globalCoreConfig.getUsingCoreName(gameType: gameType)),
                                                     indexPath: listAndexPath)
                        
                        let realm = Database.realm
                        let games = realm.objects(Game.self).where({ $0.gameType == gameType })
                        if games.count > 0,
                           let coreIndex = self.globalCoreConfig.getUsingCoreIndex(gameType: gameType) {
                            UIView.makeAlert(title: R.string.localizable.allCoreSwitch(),
                                             detail: R.string.localizable.allCoreSwitchDesc(gameType.localizedShortName, coreName),
                                             confirmTitle: R.string.localizable.confirmTitle(), confirmAction: {
                                games.forEach({
                                    if !($0.isAzaharArticBase || $0.isArticBaseHomeMenu) {
                                        $0.changeDefaultCore(coreIndex: coreIndex)
                                    }
                                })
                            })
                        }
                    }
                })
            } else if let isTapClose = listAction.navigationValue?.isTapClose, isTapClose {
                self.hide()
            }
        }
        return view
    }()
    
    private let showClose: Bool
    
    required init?(parameters: Any...) {
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        self.gameTypes = System.allGameTypes.filter({ $0.supportCores.count > 0 })
        self.globalCoreConfig = GlobalCoreSwitch.getConfig()
        super.init(frame: .zero)
        
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    convenience init(showClose: Bool = true) {
        self.init(parameters: showClose)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension GlobalCoreSwitchView: ShowableView {
    
}
