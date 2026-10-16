//
//  SkinSettingsView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import RealmSwift
import UniformTypeIdentifiers
import ProHUD

class SkinSettingsView: BaseView {
    
    private var initGames = [Game]()
    private var currentGames: [Game] {
        guard let firstGame = initGames.first,
                firstGame.gameType == gameType else { return [] }
        return initGames
    }
    private var gameType: GameType = {
        System.allGameTypes.filter({ !$0.externalType }).first ?? .gba
    }()
    
    private var allSkins: Results<Skin>
    private var currentSkins: [Skin] {
        isPortraitSkinPage ? portraitSkins : landscapeSkins
    }
    private var selectedSkins: [Skin] {
        if let indexPathsForSelectedItems = collectionView.indexPathsForSelectedItems {
            return indexPathsForSelectedItems.map({ currentSkins[$0.row] })
        }
        return []
    }
    private var portraitSkins: [Skin] = []
    private var landscapeSkins: [Skin] = []
    private var currentUsingIndex: Int? {
        get {
            return isPortraitSkinPage ? portraitUsingIndex : landscapeUsingIndex
        }
        set {
            if isPortraitSkinPage {
                portraitUsingIndex = newValue
            } else {
                landscapeUsingIndex = newValue
            }
        }
    }
    private var portraitUsingIndex: Int?
    private var landscapeUsingIndex: Int?
    private var isPortraitSkinPage: Bool {
        segmentView.segment.index == 0
    }
    private let defaultTraits: ControllerSkin.Traits = ControllerSkin.Traits.defaults(for: UIWindow.applicationWindow ?? UIWindow(frame: .init(origin: .zero, size: R.Size.ApplicationWindowSize)))
    private var currentTraits: ControllerSkin.Traits {
        isPortraitSkinPage ? portraitTraits : landscapeTraits
    }
    private lazy var portraitTraits: ControllerSkin.Traits = {
        ControllerSkin.Traits(device: self.defaultTraits.device, displayType: self.defaultTraits.displayType, orientation: .portrait)
    }()
    private lazy var landscapeTraits: ControllerSkin.Traits = {
        ControllerSkin.Traits(device: self.defaultTraits.device, displayType: self.defaultTraits.displayType, orientation: .landscape)
    }()
    
    private var skinsUpdateToken: NotificationToken? = nil
    
    var didTapClose: (() -> Void)? = nil
    
    var didHideSheet: (() -> Void)? = nil
    
    private let showClose: Bool
    
    private var isEditMode: Bool = false {
        didSet {
            isSelectedAll = false
            collectionView.reloadData()
        }
    }
    private var isSelectedAll: Bool {
        get {
            guard let indexPathsForSelectedItems = collectionView.indexPathsForSelectedItems else {
                return false
            }
            if indexPathsForSelectedItems.count > 0 {
                let selectedItemsSet = Set(indexPathsForSelectedItems.map({ $0.row }))
                return currentSkins.enumerated().allSatisfy({
                    return !$1.canDeleted || selectedItemsSet.contains($0)
                })
            }
            return false
        }
        set {
            if newValue {
                selectAll()
            } else {
                deselectAll()
            }
            updateNavigation()
            updateToolView()
        }
    }
    
    private var isMoreGamesSetting = false
    /// Bumped when a skin file is rewritten (flex edit) so cells rebuild the same identifier.
    private var skinRenderGeneration = 0
    
    private var collectionViewContentInsetBottom: CGFloat {
        R.Size.ContentInsetBottom(window: hostingWindow) + ((UIDevice.isPad && !showClose) ? R.Size.HomeTabBarSize.height + R.Size.ContentSpaceMedium : 0)
    }
    
    private lazy var navigation: ASListPage.Navigation = {
        let titleString = gameType.localizedShortName
        let titleIcons: [ASText.Icon] = [.init(icon: .symbolImage(R.image.chevronUpdown_iconSymbols()),
                                               position: UInt(titleString.count))]
        let title = ASText(attributes: .init(text: titleString,
                                             font: R.Font.Headline(emphasis: true)),
                           textIcons: titleIcons)
        
        return ASListPage.Navigation(title: title,
                                     detail: getNavigationDetail(),
                                     tools: [
                                        .symbolImage(R.image.selectedit_iconSymbols()),
                                        .symbolImage(R.image.faq_iconSymbols()),
                                        .symbolImage(R.image.ellipsis_iconSymbols()),
                                     ],
                                     edit: R.string.localizable.selectAll(),
                                     enableClose: showClose)
    }()
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(navigation)
        view.didTapClose = { [weak self] in
            guard let self else { return }
            if self.showAsSheet {
                self.hide()
            }
            self.didTapClose?()
        }
        view.didTapEdit = { [weak self] in
            guard let self else { return }
            self.isSelectedAll = !self.isSelectedAll
        }
        view.didTapCancel = { [weak self] in
            guard let self else { return }
            self.isEditMode = false
        }
        view.didTapTools = { [weak self] toolIndex in
            guard let self else { return }
            if toolIndex == 0 {
                //edit mode
                self.isEditMode = true
            } else if toolIndex == 1 {
                //how to fetch
                ASWebView.show(url: R.URLs.SkinUsageGuide)
            } else if toolIndex == 2 {
                //more...
                var cells = [ASListPage.Cell]()
                cells.append(.iconTitleChevronCell(icon: .symbolImage(R.image.refresh_iconSymbols()),
                                                   title: R.string.localizable.skinResetForAll()))
                cells.append(.iconTitleChevronCell(icon: .symbolImage(R.image.refresh_iconSymbols()),
                                                   title: R.string.localizable.skinResetForPlatform(self.gameType.localizedShortName)))
                cells.append(.iconTitleChevronCell(icon: .symbolImage(R.image.clean_iconSymbols()),
                                                   title: R.string.localizable.cleanUnsupportSkins()))
                //                cells.append(.iconTitleChevronCell(icon: .symbolImage(R.image.skin_iconSymbols()),
                //                                                   title: R.string.localizable.skinDebug()))
                ChevronSheetView.show(cellOptions: cells, completion: { [weak self] optionIndex in
                    guard let self else { return }
                    if optionIndex == 0 {
                        self.resetSkin()
                    } else if optionIndex == 1 {
                        self.resetSkin(gameType: self.gameType)
                    } else if optionIndex == 2 {
                        self.cleanUnsupportSkins()
                    } else if optionIndex == 3 {
                        UIView.makeToast(message: "Coming Soon...")
                    }
                })
            }
        }
        view.didTapTitle = { [weak self] in
            guard let self else { return }
            let allGameTypes = System.allGameTypes.filter({ !$0.externalType })
            OptionsSheetView.show(icon: .symbolImage(R.image.controller_iconSymbols()),
                                  title: R.string.localizable.changeGameType(),
                                  options: allGameTypes.map({ $0.localizedShortName }),
                                  selectedIndex: allGameTypes.firstIndex(of: self.gameType),
                                  groupTogether: true,
                                  completion: { index in
                if let index {
                    self.gameType = allGameTypes[index]
                    self.isEditMode = false
                    self.landscapeUsingIndex = nil
                    self.portraitUsingIndex = nil
                    self.updateDatas()
                }
            })
        }
        return view
    }()
    
    private lazy var segmentView: ASSegmentView = {
        let view = ASSegmentView(.textSegment(titles: [
            R.string.localizable.skinSegmentPortraitTitle(),
            R.string.localizable.skinSegmentLandscapeTitle()
        ]))
        view.didSelectIndex = { [weak self] _ in
            guard let self = self else { return }
            self.isSelectedAll = false
            self.collectionView.reloadData()
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: SkinCollectionViewCell.self)
        view.register(cellWithClass: AddSkinCollectionViewCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                      withClass: ASListSupplementaryReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.allowsSelection = true
        view.allowsMultipleSelection = true
        view.contentInset = .insets(bottom: collectionViewContentInsetBottom)
        view.addLongPressGesture(handler: { [weak self] gesture in
            if gesture.state == .began {
                guard let self,
                      !self.isEditMode,
                      let indexPath = self.collectionView.indexPathForItem(at: gesture.location(in: self.collectionView)),
                      indexPath.row != self.currentSkins.count else { return }
                self.isEditMode = true
                if self.collectionView(self.collectionView, shouldSelectItemAt: indexPath) {
                    self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                    self.updateNavigation()
                    self.updateToolView()
                } else {
                    self.isEditMode = false
                }
            }
        }).delegate = self
        return view
    }()
    
    private lazy var toolView: ASListToolView = {
        let view = ASListToolView(.defaultTool(otherIcons: [.symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red])]))
        view.didTapToolButtons = { [weak self] action in
            guard let self else { return }
            if action.isTapMain {
                //more...
                if self.selectedSkins.count == 1 {
                    let selectedSkin = self.selectedSkins.first!
                    
                    ChevronSheetView.show(cellOptions: [
                        .iconTitleChevronCell(icon: .symbolImage(R.image.controller_iconSymbols()),
                                              title: R.string.localizable.moreGamesSetting()),
                        .iconTitleDetailCheckCell(icon: .symbolImage(R.image.category_iconSymbols()),
                                                  title: R.string.localizable.platformDefaultSkin(self.gameType.localizedShortName),
                                                  isSelected: self.isGameTypeSetingSkin(selectedSkin))
                    ], completion: { [weak self] index in
                        guard let self else { return }
                        if index == 0 {
                            //set up for more games
                            let realm = Database.realm
                            let games = realm.objects(Game.self).where({ $0.gameType == self.gameType })
                            guard games.count > 0 else {
                                UIView.makeToast(message: R.string.localizable.transferPakNoGames())
                                return
                            }
                            
                            let prefference = Prefference.defalut.getGamePrefference(kind: .skin)
                            
                            var cells = [[ASListPage.Cell]]()
                            
                            for game in games {
                                var isSelected = false
                                if let prefference,
                                   let key = Prefference.StoreKey.orientationKey(gameId: game.id, isLandScape: !self.isPortraitSkinPage).key,
                                   let skinId = prefference[key],
                                   skinId == selectedSkin.id {
                                    isSelected = true
                                }
                                
                                cells.append([.iconTitleDetailRadioCell(icon: game.gameCoverIcon,
                                                                        iconSize: R.Size.ButtonMedium,
                                                                        title: game.displayName,
                                                                        isSelected: isSelected)])
                                
                            }
                            
                            var sheetStyle: ASSheet.Style = .simpleList(icon: .symbolImage(R.image.controller_iconSymbols()),
                                                                        title: R.string.localizable.moreGamesSetting(),
                                                                        detail: .smallText(R.string.localizable.moreGamesSettingDesc(selectedSkin.name),
                                                                                           numberOfLines: 0),
                                                                        options: cells)
                            
                            ASSheetView.show(.init(style: sheetStyle), action: { [weak self] action, updation in
                                guard let self else { return .dismiss() }
                                if let normalItemValue = action.listPageValue?.normalItemValue {
                                    
                                    let index = normalItemValue.indexPath.section
                                    let game = games[index]
                                    let storeKey = Prefference.StoreKey.orientationKey(gameId: game.id, isLandScape: !self.isPortraitSkinPage)
                                    let isSelected: Bool
                                    if let _ = Prefference.defalut.getPrefference(kind: .skin,
                                                                                  storeKey: storeKey)?.skinValue?.skinId {
                                        //unselected
                                        Prefference.defalut.deletePrefference(kind: .skin,
                                                                              storeKey: storeKey)
                                        isSelected = false
                                    } else {
                                        //selected
                                        Prefference.defalut.storePrefference(kind: .skin,
                                                                             storeKey: storeKey,
                                                                             storeValue: selectedSkin.id)
                                        isSelected = true
                                    }
                                    if case let .simpleList(icon, title, detail, options, cancelEnable) = sheetStyle {
                                        var cells = options
                                        cells[index][0] = normalItemValue.cellData.updateNormalRadio(isSelected: isSelected)
                                        sheetStyle = .simpleList(icon: icon, title: title, detail: detail, options: cells, cancelEnable: cancelEnable)
                                        updation?(sheetStyle)
                                    }
                                    self.isMoreGamesSetting = true
                                    return .none
                                }
                                return .dismiss(completion: { [weak self] in
                                    guard let self else { return }
                                    if self.isMoreGamesSetting {
                                        self.isEditMode = false
                                        self.currentUsingIndex = nil
                                        self.updateDatas()
                                        self.isMoreGamesSetting = false
                                    }
                                })
                            })
                            
                            
                        } else if index == 1 {
                            //set gameType Skin
                            let storeKey = Prefference.StoreKey.orientationKey(gameType: self.gameType, isLandScape: !self.isPortraitSkinPage)
                            if self.isGameTypeSetingSkin(selectedSkin) {
                                Prefference.defalut.deletePrefference(kind: .skin,
                                                                      storeKey: storeKey)
                            } else {
                                Prefference.defalut.storePrefference(kind: .skin,
                                                                     storeKey: storeKey,
                                                                     storeValue: selectedSkin.id)
                            }
                            self.isEditMode = false
                            self.currentUsingIndex = nil
                            self.updateDatas()
                        }
                    })
                }
                
            } else if let index = action.tapOthersValue {
                if self.selectedSkins.count == 1,
                   let flexSkin = self.selectedSkins.first,
                   flexSkin.isFlexSkin {
                    //flex edit
                    let vc = FlexSkinSettingViewController(skin: flexSkin,
                                                           traits: self.currentTraits,
                                                           images: [],
                                                           gameId: self.currentGames.count == 1 ? self.currentGames.first!.id : nil,
                                                           gameType: self.gameType)
                    vc.didCompletion = { [weak self] isModified in
                        if isModified {
                            flexSkin.controllerSkin = ControllerSkin(fileURL: flexSkin.fileURL)
                            self?.skinRenderGeneration += 1
                            self?.collectionView.reloadData()
                        }
                    }
                    topViewController(in: hostingWindowScene)?.present(vc, animated: true)
                    
                } else {
                    //delete
                    guard self.selectedSkins.count > 0 else { return }
                    
                    UIView.makeAlert(title: R.string.localizable.skinDelete(),
                                     detail: R.string.localizable.deleteSkinAlertDetail(),
                                     confirmTitle: R.string.localizable.confirmDelte(),
                                     confirmAction: { [weak self] in
                        guard let self else { return }
                        self.currentUsingIndex = nil
                        Skin.change { realm in
                            self.selectedSkins.forEach({
                                $0.skinData?.deleteAndClean(realm: realm)
                                if Settings.defalut.iCloudSyncEnable {
                                    $0.isDeleted = true
                                } else {
                                    realm.delete($0)
                                }
                            })
                        }
                        self.deselectAll()
                        self.updateToolView()
                        self.updateNavigation()
                    })
                }
            }
        }
        view.isHidden = true
        return view
    }()
    
    required init?(parameters: Any...) {
        let realm = Database.realm
        self.allSkins = realm.objects(Skin.self).where({ !$0.isDeleted })
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)
        
        let gameType = parameters.first(where: { $0 is GameType }) as? GameType
        var games = parameters.compactMap({ $0 as? Game })
        games += (parameters.compactMap({ $0 as? [Game] }).first ?? [])
        if let gameType {
            self.initGames = games.filter({ $0.gameType == gameType })
            self.gameType = gameType
        } else if let firstGame = games.first {
            self.initGames = games.filter({ $0.gameType == firstGame.gameType })
            self.gameType = firstGame.gameType
        } else {
            self.initGames = []
        }
        
        skinsUpdateToken = allSkins.observe { [weak self] changes in
            guard let self = self else { return }
            if case .update(_, let deletions, let insertions, _) = changes {
                Log.debug("皮肤更新")
                //新增数据
                if !insertions.isEmpty || !deletions.isEmpty {
                    self.updateDatas()
                }
            }
        }
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            if showClose {
                make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            } else {
                make.top.equalToSuperview().offset(R.Size.ContentInsetTop(window: hostingWindow))
            }
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightExtraSmall)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(segmentView.snp.bottom).offset(R.Size.ContentSpaceSmall)
        }
        
        addSubview(toolView)
        toolView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            make.bottom.equalToSuperview().inset(collectionViewContentInsetBottom)
            make.height.equalTo(R.Size.ButtonLarge)
        }
        
        if proHUDLayoutStyle() == .landscape {
            segmentView.segment.index = 1
        }
        
        updateDatas()
    }
    
    convenience init(gameType: GameType? = nil, games: [Game] = [], showClose: Bool = true) {
        if let gameType {
            self.init(parameters: gameType, games, showClose)!
        } else {
            self.init(parameters: games, showClose)!
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout  { [weak self] sectionIndex, env in
            guard let self else { return nil }
            
            var column: CGFloat = self.isPortraitSkinPage ? 2.0 : 1.0
            if UIDevice.isPad, self.prefferedLayoutStyle == .landscape {
                column = self.isPortraitSkinPage ? 3.0 : 2.0
            }
            
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/column), heightDimension: .fractionalHeight(1)))
            
            let screenRation: CGFloat
            if let screen = self.hostingWindow?.screen {
                screenRation = screen.bounds.size.maxDimension/screen.bounds.size.minDimension
            } else {
                screenRation = R.Size.ApplicationWindowSize.maxDimension/R.Size.ApplicationWindowSize.minDimension
            }
             
            let itemWidth = (env.container.contentSize.width - R.Size.ContentSpaceMedium*4 - ((column-1)*R.Size.ContentSpaceMedium))/column
            let itemHeight = self.isPortraitSkinPage ? itemWidth*screenRation : itemWidth/screenRation
            
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(itemHeight)), subitem: item, count: Int(column))
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: R.Size.ContentSpaceMedium, bottom: 0, trailing: R.Size.ContentSpaceMedium)
            group.interItemSpacing = NSCollectionLayoutSpacing.fixed(R.Size.ContentSpaceMedium)
            
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = R.Size.ContentSpaceMedium
            
            section.decorationItems = [NSCollectionLayoutDecorationItem.background(elementKind: String(describing: SkinDecorationCollectionReusableView.self))]
            section.contentInsets = NSDirectionalEdgeInsets(top: R.Size.ContentSpaceMedium, leading: R.Size.ContentSpaceMedium, bottom: R.Size.ContentSpaceMedium, trailing: R.Size.ContentSpaceMedium)
            
            return section
        }
        layout.register(SkinDecorationCollectionReusableView.self, forDecorationViewOfKind: String(describing: SkinDecorationCollectionReusableView.self))
        return layout
    }
    
    class SkinDecorationCollectionReusableView: UICollectionReusableView {
        var backgroundView: UIView = {
            let view = UIView()
            view.layerCornerRadius = R.Size.CornerRadiusLarge
            view.backgroundColor = R.Color.BackgroundSecondary
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(backgroundView)
            backgroundView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private func updateDatas() {
        portraitSkins.removeAll()
        landscapeSkins.removeAll()
        //添加皮肤
        let reuseSkinGameType = self.gameType.reuseSkinGameType
        let skins = allSkins.filter({
            if !$0.isFileExtsts {
                return false
            }
            if reuseSkinGameType.contains([$0.gameType]) {
                if $0.gameType != self.gameType && ($0.skinType == .default || $0.skinType == .buildIn || $0.skinType == .playcase) {
                    //皮肤的游戏类型与当前选中的游戏类型不一致 则需要排除掉default和manic的皮肤
                    return false
                } else {
                    return true
                }
            }
            return false
        }).sorted {
            if $0.skinType == .default {
                return true
            } else if $1.skinType == .default {
                return false
            } else if $0.skinType == .buildIn {
                return true
            } else if $1.skinType == .buildIn {
                return false
            } else if $0.skinType == .playcase {
                return true
            } else if $1.skinType == .playcase {
                return false
            }
            return true
        }
        
        for skin in skins {
            if var controllerSkin = skin.controllerSkin {
                if skin.skinType == .playcase {
                    controllerSkin.isPlayCase = true
                    skin.controllerSkin = controllerSkin
                }
                if controllerSkin.supports(portraitTraits) {
                    portraitSkins.append(skin)
                }
                if controllerSkin.supports(landscapeTraits) {
                    landscapeSkins.append(skin)
                }
            }
        }
        
        func getUsingSkinIndex(gameId: String? = nil, isLandScape: Bool) -> Int? {
            let storeKey: Prefference.StoreKey
            if let gameId {
                storeKey = .orientationKey(gameId: gameId, isLandScape: isLandScape)
            } else {
                storeKey = .orientationKey(gameType: gameType, isLandScape: isLandScape)
            }
            let result = Prefference.defalut.getPrefference(kind: .skin,
                                                            storeKey: storeKey,
                                                            bestEfforts: true)
            guard let skinId = result?.skinValue?.skinId else { return nil }
            return (isLandScape ? landscapeSkins : portraitSkins).firstIndex(where: { $0.id == skinId })
        }
        
        if let firstGame = currentGames.first {
            if currentGames.count == 1 {
                portraitUsingIndex = getUsingSkinIndex(gameId: firstGame.id, isLandScape: false)
                landscapeUsingIndex = getUsingSkinIndex(gameId: firstGame.id, isLandScape: true)
            } else {
                if let firstGameUsingSkinIndex = getUsingSkinIndex(gameId: firstGame.id, isLandScape: false) {
                    if currentGames.allSatisfy({ firstGameUsingSkinIndex == getUsingSkinIndex(gameId: $0.id, isLandScape: false) }) {
                        portraitUsingIndex = firstGameUsingSkinIndex
                    }
                }
                
                if let firstGameUsingSkinIndex = getUsingSkinIndex(gameId: firstGame.id, isLandScape: true) {
                    if currentGames.allSatisfy({ firstGameUsingSkinIndex == getUsingSkinIndex(gameId: $0.id, isLandScape: true) }) {
                        landscapeUsingIndex = firstGameUsingSkinIndex
                    }
                }
            }
        } else {
            portraitUsingIndex = getUsingSkinIndex(isLandScape: false)
            landscapeUsingIndex = getUsingSkinIndex(isLandScape: true)
        }
        
        if portraitUsingIndex == nil, currentGames.count <= 1 {
            portraitUsingIndex = 0
        }
        
        if landscapeUsingIndex == nil, currentGames.count <= 1 {
            landscapeUsingIndex = 0
        }
        
        collectionView.reloadData()
    }
    
    private func updateToolView() {
        func hideToolView() {
            toolView.isHidden = true
            collectionView.contentInset.bottom = collectionViewContentInsetBottom
        }
        
        guard selectedSkins.count > 0 else {
            hideToolView()
            return
        }
        
        if selectedSkins.count > 0 {
            toolView.isHidden = false
            if selectedSkins.count == 1, selectedSkins.first!.isFlexSkin {
                //flex skin
                toolView.tool = .defaultTool(otherIcons: [
                    .symbolImage(R.image.flexFill_iconSymbols())
                ])
            } else {
                toolView.tool = .defaultTool(otherIcons: [
                    .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red])
                ], hideMainIcon: selectedSkins.count > 1)
            }
            collectionView.contentInset.bottom = collectionViewContentInsetBottom + R.Size.ButtonLarge + R.Size.ContentSpaceSmall
        } else {
            hideToolView()
        }
        
    }
    
    private func cleanUnsupportSkins() {
        let realm = Database.realm
        let skins = realm.objects(Skin.self).where({ $0.skinType == .import })
        var unsupportSkins: [Skin] = []
        var unsupportSkinNames: String = ""
        for skin in skins {
            if let controllerSkin = ControllerSkin(fileURL: skin.fileURL) {
                if !controllerSkin.supports(landscapeTraits) &&
                    !controllerSkin.supports(portraitTraits) {
                    //获取不支持当前设备的皮肤
                    unsupportSkins.append(skin)
                    unsupportSkinNames.append(controllerSkin.name + "\n")
                }
            }
        }
        
        if unsupportSkins.count == 0 {
            UIView.makeToast(message: R.string.localizable.notFoundUnsupportSkins())
            return
        }
        
        UIView.makeAlert(title: R.string.localizable.skinDelete(),
                         detail: R.string.localizable.unsupportSkinsDesc(unsupportSkinNames),
                         confirmTitle: R.string.localizable.confirmDelte(),
                         confirmAction: {
            for skin in unsupportSkins {
                Skin.change { realm in
                    skin.skinData?.deleteAndClean(realm: realm)
                    if Settings.defalut.iCloudSyncEnable {
                        skin.isDeleted = true
                    } else {
                        realm.delete(skin)
                    }
                }
            }
            UIView.makeToast(message: R.string.localizable.unsupportSkinsRemoveSuccess())
        })
    }
    
    private func updateNavigation() {
        navigation.state = isEditMode ? .edit : .normal
        navigation.edit = isSelectedAll ? R.string.localizable.deSelectAll() : R.string.localizable.selectAll()
        let titleString = gameType.localizedShortName
        let titleIcons: [ASText.Icon] = [.init(icon: .symbolImage(R.image.chevronUpdown_iconSymbols()),
                                               position: UInt(titleString.count))]
        let title = ASText(attributes: .init(text: titleString,
                                             font: R.Font.Headline(emphasis: true)),
                           textIcons: titleIcons)
        navigation.title = title
        navigation.detail = getNavigationDetail()
        navigationView.navigation = navigation
    }
    
    private func getNavigationDetail() -> ASText {
        if currentGames.count > 0 {
            let firstGame = currentGames.first!
            let name = firstGame.displayName + (currentGames.count > 1 ? "..." : "")
            var text: ASText = .extraSmallTextStartingWithIcon(icon: .symbol(.megaphone),
                                                               text: R.string.localizable.skinNavigationSubTitleSpecifiedGame(" \(name) "))
            text.attributes?.lineBreakMode = .byTruncatingMiddle
            return text
        }
        return .extraSmallTextStartingWithIcon(text: R.string.localizable.skinSupport())
    }
    
    private func isGameTypeSetingSkin( _ skin: Skin) -> Bool {
        if let result = Prefference.defalut.getPrefference(kind: .skin,
                                                           storeKey: .orientationKey(gameType: gameType,
                                                                              isLandScape: !isPortraitSkinPage)),
           let currentGameTypeSkinId = result.skinValue?.skinId {
            return currentGameTypeSkinId == skin.id
        }
        return false
    }
}

extension SkinSettingsView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        currentSkins.count + (isEditMode ? 0 : 1)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.row == currentSkins.count {
            return collectionView.dequeueReusableCell(withClass: AddSkinCollectionViewCell.self, for: indexPath)
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: SkinCollectionViewCell.self, for: indexPath)
            let skin = currentSkins[indexPath.row]
            let traits = currentTraits
            var isUsing: Bool = false
            if let currentUsingIndex, currentUsingIndex == indexPath.row {
                isUsing = true
            }
            cell.setData(controllerSkin: skin.controllerSkin,
                         traits: traits,
                         subscriptTitle: skin.gameType == gameType ? nil : skin.gameType.localizedShortName,
                         isEditMode: isEditMode,
                         isUsing: isUsing,
                         isEditable: skin.isEditable,
                         renderGeneration: skinRenderGeneration)
            cell.onPreview = { [weak self] in
                guard let self else { return }
                if let controllerSkin = skin.controllerSkin, let w = self.hostingWindow {
                    topViewController(in: self.hostingWindowScene)?.present(SkinPreviewViewController(skin: controllerSkin,
                                                                                                      traits: traits,
                                                                                                      window: w),
                                                 animated: true)
                }
            }
            cell.onPlaycaseTap = {
                PlayCasePromoView.show(showDontShow: false)
            }
            cell.onFocusConfirm = { [weak self] in
                guard let self else { return false }
                if self.isEditMode {
                    if let selectedItems = self.collectionView.indexPathsForSelectedItems,
                        selectedItems.contains(where: { $0 == indexPath }) {
                        //deselected
                        self.collectionView.deselectItem(at: indexPath, animated: true)
                        self.deselectItem(at: indexPath)
                    } else {
                        //selected
                        if self.collectionView(self.collectionView, shouldSelectItemAt: indexPath) {
                            self.collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
                            self.selectItem(at: indexPath)
                        }
                    }
                } else {
                    let _ = self.collectionView(self.collectionView, shouldSelectItemAt: indexPath)
                }
                return true
            }
            return cell
        }
    }
}

extension SkinSettingsView: UICollectionViewDelegate {
    func selectAll() {
        if currentSkins.contains(where: { $0.skinType == .import || $0.skinType == .playcase }) {
            currentSkins.enumerated().forEach({
                if $1.canDeleted {
                    collectionView.selectItem(at: IndexPath(row: $0, section: 0), animated: false, scrollPosition: [])
                } else {
                    collectionView.deselectItem(at: IndexPath(row: $0, section: 0), animated: false)
                }
            })
        } else {
            currentSkins.enumerated().forEach({
                if $1.skinType == .buildIn {
                    collectionView.selectItem(at: IndexPath(row: $0, section: 0), animated: false, scrollPosition: [])
                } else {
                    collectionView.deselectItem(at: IndexPath(row: $0, section: 0), animated: false)
                }
            })
        }
    }
    
    func deselectAll() {
        collectionView.indexPathsForSelectedItems?.forEach({
            collectionView.deselectItem(at: $0, animated: false)
        })
    }
    
    func deselectBuildIn() {
        collectionView.indexPathsForSelectedItems?.forEach({
            if currentSkins[$0.row].skinType == .buildIn {
                collectionView.deselectItem(at: $0, animated: false)
            }
        })
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if isEditMode {
            let skin = currentSkins[indexPath.row]
            if !skin.isEditable {
                UIView.makeToast(message: R.string.localizable.defaultSkinCannotEdit())
                return false
            } else if skin.skinType == .buildIn {
                deselectAll()
            } else  {
                deselectBuildIn()
            }
            return true
        } else {
            if indexPath.row == currentSkins.count {
                UIView.makeAlert(title: R.string.localizable.skinAddTitle(), detail: R.string.localizable.newSkinDesc(), cancelTitle: R.string.localizable.visitSite("DELTASTYLES"), confirmTitle: R.string.localizable.openFile(), cancelAction: { [weak self] in
                    guard let self else { return }
                    ASWebView.show(url: R.URLs.DeltaStyles(gameType: self.gameType))
                }, confirmAction: { [weak self] in
                    guard let self else { return }
                    FilesImporter.shared.presentImportController(supportedTypes: UTType.skinTypes, in: self.hostingWindowScene)
                })
            } else {
                if let currentUsingIndex, currentUsingIndex == indexPath.row {
                    return false
                }
                
                if currentGames.count > 0 {
                    currentGames.forEach({
                        Prefference.defalut.storePrefference(kind: .skin,
                                                             storeKey: .orientationKey(gameId: $0.id, isLandScape: !isPortraitSkinPage),
                                                             storeValue: currentSkins[indexPath.row].id)
                    })
                    
                    if currentGames.count == 1 {
                        NotificationCenter.default.post(name: R.NotificationName.SkinChange, object: currentGames.first!.id)
                    }
                    
                } else {
                    Prefference.defalut.storePrefference(kind: .skin,
                                                         storeKey: .orientationKey(gameType: gameType, isLandScape: !isPortraitSkinPage),
                                                         storeValue: currentSkins[indexPath.row].id)
                }
                
                let oldUsingIndex = currentUsingIndex
                currentUsingIndex = indexPath.row
                UIView.performWithoutAnimation {
                    var reloadItems = [indexPath]
                    if let oldUsingIndex {
                        reloadItems.append(IndexPath(row: oldUsingIndex, section: 0))
                    }
                    collectionView.reloadItems(at: reloadItems)
                }
#if !SIDE_LOAD
                if currentSkins[indexPath.row].skinType == .playcase,
                   !PlayViewController.isGaming,
                   !UserDefaults.standard.bool(forKey: R.DefaultKey.HasShowPlayCasePromo) {
                    PlayCasePromoView.show()
                }
#endif
            }
            return false
        }
    }
    
    func deselectItem(at indexPath: IndexPath) {
        guard isEditMode else { return }
        updateNavigation()
        updateToolView()
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        deselectItem(at: indexPath)
    }
    
    func selectItem(at indexPath: IndexPath) {
        guard isEditMode else { return }
        updateNavigation()
        updateToolView()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectItem(at: indexPath)
    }
    
    private func resetSkin(gameType: GameType? = nil) {
        if let gameType {
            Prefference.defalut.deletePrefference(kind: .skin,
                                                  storeKey: .orientationKey(gameType: gameType,
                                                                     isLandScape: !isPortraitSkinPage))
            let realm = Database.realm
            let games = realm.objects(Game.self).where({ $0.gameType == gameType })
            let storeKeys = games.map({ Prefference.StoreKey.orientationKey(gameId: $0.id,
                                                                     isLandScape: !self.isPortraitSkinPage) })
            storeKeys.forEach({
                Prefference.defalut.deletePrefference(kind: .skin, storeKey: $0)
            })
            
        } else {
            Prefference.defalut.deletePrefference(kind: .skin,
                                                  level: .game,
                                                  extra: Prefference.StoreKey.orientationExtraKey(isLandScape: true))
            Prefference.defalut.deletePrefference(kind: .skin,
                                                  level: .game,
                                                  extra: Prefference.StoreKey.orientationExtraKey(isLandScape: false))
            Prefference.defalut.deletePrefference(kind: .skin,
                                                  level: .gameType,
                                                  extra: Prefference.StoreKey.orientationExtraKey(isLandScape: true))
            Prefference.defalut.deletePrefference(kind: .skin,
                                                  level: .gameType,
                                                  extra: Prefference.StoreKey.orientationExtraKey(isLandScape: false))
        }
        
        landscapeUsingIndex = 0
        portraitUsingIndex = 0
        collectionView.reloadData()
        
        if PlayViewController.isGaming {
            if let gameType {
                if PlayViewController.currentGameType == gameType {
                    PlayViewController.updateSkin()
                }
            } else {
                PlayViewController.updateSkin()
            }   
        }
    }
}

extension SkinSettingsView: ShowableView {
    static func show(gameType: GameType? = nil,
                     games: [Game] = [],
                     hideCompletion: (() -> Void)? = nil) {
        if let gameType {
            Self.show(parameters: gameType, games)?.didHideSheet = hideCompletion
        } else {
            Self.show(parameters: games)?.didHideSheet = hideCompletion
        }
    }
    
    func didHide() {
        if showAsSheet {
            didHideSheet?()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension SkinSettingsView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        //When long-press is triggered, disable the cell's tap response.
        return false
    }
}
