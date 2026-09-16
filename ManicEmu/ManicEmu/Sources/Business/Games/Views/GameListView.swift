//
//  GameListView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift
import Fireworks

class GameListView: BaseView {
    lazy var collectionView: BlankSlateCollectionView = {
        let view = BlankSlateCollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: GameCollectionViewCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: GamesCollectionReusableView.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: RandomGameCollectionReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.allowsMultipleSelection = true
        let bottom = R.Size.ContentInsetBottom + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceLarge
        view.contentInset = .insets(bottom: bottom)
        view.blankSlateView = GamesListBlankSlateView()
        view.addLongPressGesture(handler: { [weak self] gesture in
            if gesture.state == .began {
                guard let self,
                      !self.isSelectionMode,
                      gesture.state == .began,
                      let indexPath = self.collectionView.indexPathForItem(at: gesture.location(in: self.collectionView)),
                      let game = getGame(at: indexPath) else { return }
                UIDevice.generateHaptic(style: .heavy)
                self.showGameEditSheet(game: game)
            }
        }).delegate = self
        view.isFocusable = true
        return view
    }()
    
    ///右侧索引栏
    private lazy var indexView: SectionIndexView = {
        let view = SectionIndexView()
        view.delegate = self
        view.dataSource = self
        return view
    }()
    
    ///点击随机游戏撒花效果
    private lazy var fireworks = ClassicFireworkController()
    
    private lazy var bottomToolView: ASListToolView = {
        let view = ASListToolView(.defaultTool(otherIcons: [
            .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
            .symbolImage(R.image.skin_iconSymbols())
        ]))
        view.didTapToolButtons = { [weak self] action in
            guard let self else { return }
            switch action {
            case .tapMain:
                //more
                self.showGameEditSheet()
                
            case .tapOthers(index: let index):
                if index == 0 {
                    //delete
                    if let selectedIndexPaths = self.collectionView.indexPathsForSelectedItems {
                        GameOption.delete.performAction(with: selectedIndexPaths.compactMap({ self.getGame(at: $0) }))
                    }
                } else if index == 1 {
                    //skin
                    if let selectedIndexPaths = self.collectionView.indexPathsForSelectedItems {
                        GameOption.skins.performAction(with: selectedIndexPaths.compactMap({ self.getGame(at: $0) }))
                    }
                }
            }
        }
        view.alpha = 0
        return view
    }()
    
    ///普通模式数据源
    private var normalDatas: [GameType: [Game]] = [:]
    ///当前模式下的数据个数
    var totalGamesCountForCurrentMode: Int { (isSearchMode ? searchDatas : normalDatas).values.reduce(0) { $0 + $1.count } }
    
    var isGamesExist: Bool { games.count > 0 }
    
    ///搜索模式数据源
    private lazy var searchDatas: [GameType: [Game]] = [:]
    
    private var coverSizes = [GameType: CGSize]()
    
    ///选择模式
    var isSelectionMode: Bool { selectionMode != .normalMode }
    var selectionMode: SelectionChangeMode = .normalMode {
        didSet {
            guard selectionMode != oldValue else { return }
            for (gameTypeIndex, gameType) in self.sortDatasKeys().enumerated() {
                if foldedGameTypes[gameType] ?? false {
                    continue
                }
                if let games = (isSearchMode ? searchDatas : normalDatas)[gameType] {
                    for (gameIndex, _) in games.enumerated() {
                        switch selectionMode {
                        case .normalMode, .selectionMode:
                            if selectionMode == .normalMode {
                                //退出选择模式的时候 进行复位一次
                                collectionView.allowsSelection = false
                                collectionView.allowsMultipleSelection = false
                                collectionView.allowsSelection = true
                                collectionView.allowsMultipleSelection = true
                                UIView.springAnimate { self.bottomToolView.alpha = 0 }
                            }
                            if let cell = collectionView.cellForItem(at: IndexPath(row: gameIndex, section: gameTypeIndex)) as? GameCollectionViewCell {
                                cell.updateViews(isSelect: selectionMode == .normalMode ? false : true)
                            }
                        case .selectAll:
                            collectionView.selectItem(at: IndexPath(row: gameIndex, section: gameTypeIndex), animated: true, scrollPosition: [])
                            UIView.springAnimate { self.bottomToolView.alpha = 1 }
                        case .deSelectAll:
                            collectionView.deselectItem(at: IndexPath(row: gameIndex, section: gameTypeIndex), animated: true)
                            UIView.springAnimate { self.bottomToolView.alpha = 0 }
                        }
                    }
                }
            }
        }
    }
    ///选择item回调
    var didListViewSelectionChange: ((_ selectionType: SelectionType) -> Void)?
    
    ///更新工具条回调
    var needsUpdateToolViewVisible: ((_ show: Bool) -> Void)?
    
    var needsUpdateToolViewSelection: (() -> Void)?
    
    ///开始滚动
    var didScroll: (()->Void)?
    
    ///数据更新
    var didDatasUpdate: ((_ isEmpty: Bool)->Void)? {
        didSet {
            didDatasUpdate?(normalDatas.isEmpty)
        }
    }
    
    ///need to Stop manufacturer filter
    var needToStopManufacturerFilter: (()->Void)? = nil
    
    ///搜索模式
    var isSearchMode = false
    private var searchString: String? = nil
    
    ///UI辅助
    private var lastContentOffsetY = 0.0
    private var lastToolViewScrollTimestamp: TimeInterval = 0
    private var isToolViewScrollInitialized = false
    private var lastSelectSection = 0
    private let gamesNavigationBottom = (R.Size.SafeArea.top > 0 ? R.Size.SafeArea.top : R.Size.ContentSpaceLarge) + R.Size.ItemHeightMedium
    private var gamesToolBottom: CGFloat {
        gamesNavigationBottom + R.Size.GamesToolViewHeight
    }
    
    private var notificationTokens = [Any]()
    
    //筛选厂商
    var filteredManufacturer: Manufacturer? = nil {
        didSet {
            guard games.count > 0 else { return }
            updateDatas()
            collectionView.reloadData()
            reloadIndexView()
            if isSearchMode, let searchString {
                searchDatas(string: searchString, forceSearch: true)
            }
        }
    }
    
    private var foldedGameTypes: [GameType: Bool] = [:]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(indexView)
        indexView.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.width.equalTo(31)
        }
        indexView.isHidden = true
        
        addSubview(bottomToolView)
        bottomToolView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(R.Size.ContentSpaceHuge)
            make.height.equalTo(R.Size.ItemHeightMedium)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(R.Size.HomeTabBarSize.height + R.Size.ContentSpaceLarge)
        }
        
        updateGames()
        setupNotifications()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        gamesUpdateToken = nil
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            reloadIndexView()
        }
    }
    
    private var gamesUpdateToken: NotificationToken? = nil
    private var games: Results<Game> = {
        //查询数据库
        let realm = Database.realm
        let games = realm.objects(Game.self).where { !$0.isDeleted }
        return games
    }()
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        var reloadDatas: [Notification.Name] = [
            R.NotificationName.GameCoverChange,
            R.NotificationName.StopPlayGame,
            R.NotificationName.HideGameRating
        ]
        if UIDevice.isPhone {
            reloadDatas += [
                .externalGameControllerDidConnect,
                .externalGameControllerDidDisconnect,
                .externalKeyboardDidConnect,
                .externalKeyboardDidDisconnect
            ]
        }
        
        for name in reloadDatas {
            notificationTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.collectionView.reloadData()
            })
        }
        
        let reloadDatasAndIndexs: [Notification.Name] = [
            R.NotificationName.PlatformOrderChange,
            R.NotificationName.GameListStyleChange,
        ]
        
        for name in reloadDatasAndIndexs {
            notificationTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.collectionView.reloadData()
                self?.reloadIndexView()
            })
        }
        
        let updateDatas: [Notification.Name] = [
            R.NotificationName.PlatformSelectionChange,
            R.NotificationName.GameSortChange,
            R.NotificationName.GameCategoryChange
        ]
        for name in updateDatas {
            notificationTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.updateDatas()
                self?.collectionView.reloadData()
                self?.reloadIndexView()
            })
        }
        
        notificationTokens.append(center.addObserver(forName: R.NotificationName.PlatformVisibleChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            if let platform = notification.object as? String,
               let gameType = GameType(shortName: platform),
               self.games.where({ $0.gameType == gameType }).count > 0 {
                self.needToStopManufacturerFilter?()
                self.updateDatas()
                self.collectionView.reloadData()
                self.reloadIndexView()
                
            }
        })
        
        notificationTokens.append(center.addObserver(forName: R.NotificationName.GameMetadataChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, !R.Style.GameHideRating else { return }
            if let gameId = notification.object as? String,
                let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId),
                let indexPath = getIndexPath(for: game) {
                self.collectionView.reloadItems(at: [indexPath])
            }
        })
    }
    
    private func updateGames() {
        //监听数据的变化
        gamesUpdateToken = games.observe(keyPaths: [
            \Game.gameCover,
             \Game.icon,
             \Game.aliasName,
             \Game.onlineCoverUrl
        ]) { [weak self] changes in
            guard let self = self else { return }
            switch changes {
            case .update(_, let deletions, let insertions, let modifications):
                Log.debug("游戏列表 游戏更新")
                //删除或新增数据
                if !deletions.isEmpty || !insertions.isEmpty {
                    self.updateDatas()
                    self.collectionView.reloadData()
                    self.reloadIndexView()
                    if !self.isGamesExist {
                        UIView.springAnimate { self.bottomToolView.alpha = 0 }
                        if self.isSelectionMode {
                            self.selectionMode = .normalMode
                        }
                    }
                    self.needToStopManufacturerFilter?()
                }
                
                //如果被修改了则更新视图
                if !modifications.isEmpty {
                    let indexPaths = modifications.compactMap({ self.getIndexPath(for: self.games[$0]) })
                    self.collectionView.reloadItems(at: indexPaths)
                }
            default:
                break
            }
        }
        //查询结束更新数据库
        updateDatas()
        if games.count > 0 {
            //更新视图
            collectionView.reloadData()
            //更新索引视图
            reloadIndexView()
        }
    }
    
    ///构造符合UI展示的数据源
    private func updateDatas() {
        let groupGames = Dictionary(grouping: games, by: {
            $0.gameType
        }).filter({
            if let filteredManufacturer {
                if filteredManufacturer == .modRetro, $0.key == .gb {
                    let gbGames = $0.value
                    return gbGames.contains(where: { gb in
                        return (gb.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) == 1
                    })
                }
                if filteredManufacturer.gameTypes.contains([$0.key]) {
                    return true
                } else {
                    return false
                }
            }
            return true
        })
        // 数据结果 [GameType: [Game]]
        let sortType = GameSortType(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.gameSortType.rawValue) ?? 0) ?? .title
        let sortOrder = GameSortOrder(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.gameSortOrder.rawValue) ?? 0) ?? .ascending
        normalDatas = groupGames.mapValues { $0.sorted(by: {
            if $0.gameType == .ds {
                //特殊处理NDS排序 总是保证Home Menu排在首位
                let priority: [String: Int] = [ Game.DsHomeMenuPrimaryKey: 0, Game.DsiHomeMenuPrimaryKey: 1 ]
                let lhsPriority = priority[$0.id] ?? Int.max
                let rhsPriority = priority[$1.id] ?? Int.max
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                } else {
                    //和其他机型一样
                    return self.sortDatas(game1: $0, game2: $1, sortType: sortType, sortOrder: sortOrder)
                }
            } else {
                return self.sortDatas(game1: $0, game2: $1, sortType: sortType, sortOrder: sortOrder)
            }
        }) }
        
        //GB games can switch categories
        if let gbGames = normalDatas[.gb], gbGames.count > 0 {
            var newGbGames = [Game]()
            var chmGames = [Game]()
            for gb in gbGames {
                if (gb.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) == 0 {
                    newGbGames.append(gb)
                } else {
                    chmGames.append(gb)
                }
            }
            var includeGB = true
            var includeCHM = true
            if let filteredManufacturer {
                if filteredManufacturer == .nintendo {
                    includeCHM = false
                } else if filteredManufacturer == .modRetro {
                    includeGB = false
                }
            }
            normalDatas[.gb] = (newGbGames.count > 0 && includeGB) ? newGbGames : nil
            normalDatas[.chm] = (chmGames.count > 0 && includeCHM) ? chmGames : nil
        }
        
        //DOS games can switch categories
        if let dosGames = normalDatas[.dos], dosGames.count > 0 {
            var newDosGames = [Game]()
            var win95Games = [Game]()
            var win98Games = [Game]()
            for dos in dosGames {
                let dosGameType = dos.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0
                if dosGameType == 0 {
                    newDosGames.append(dos)
                } else if dosGameType == 1 {
                    win95Games.append(dos)
                } else if dosGameType == 2 {
                    win98Games.append(dos)
                }
            }
            normalDatas[.dos] = newDosGames.count > 0 ? newDosGames : nil
            normalDatas[.win95] = win95Games.count > 0 ? win95Games: nil
            normalDatas[.win98] = win98Games.count > 0 ? win98Games : nil
        }
        
        //PCE games can switch categories
        if let pceGames = normalDatas[.pce], pceGames.count > 0 {
            var newPceGames = [Game]()
            var turbografx16Games = [Game]()
            var turbografxCdGames = [Game]()
            var supergrafxGames = [Game]()
            for pce in pceGames {
                let pceGameType = pce.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0
                if pceGameType == 0 {
                    newPceGames.append(pce)
                } else if pceGameType == 1 {
                    turbografx16Games.append(pce)
                } else if pceGameType == 2 {
                    turbografxCdGames.append(pce)
                } else if pceGameType == 3 {
                    supergrafxGames.append(pce)
                }
            }
            normalDatas[.pce] = newPceGames.count > 0 ? newPceGames : nil
            normalDatas[.turbografx_16] = turbografx16Games.count > 0 ? turbografx16Games : nil
            normalDatas[.turbografx_cd] = turbografxCdGames.count > 0 ? turbografxCdGames : nil
            normalDatas[.supergrafx] = supergrafxGames.count > 0 ? supergrafxGames : nil
        }
        
        //NGP games can switch categories
        if let ngpGames = normalDatas[.ngp], ngpGames.count > 0 {
            var newNgpGames = [Game]()
            var ngpcGames = [Game]()
            for ngp in ngpGames {
                let ngpGameType = ngp.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0
                if ngpGameType == 0 {
                    newNgpGames.append(ngp)
                } else if ngpGameType == 1 {
                    ngpcGames.append(ngp)
                }
            }
            normalDatas[.ngp] = newNgpGames.count > 0 ? newNgpGames : nil
            normalDatas[.ngpc] = ngpcGames.count > 0 ? ngpcGames : nil
        }
        
        // WSC games can switch to the WS subcategory
        if let wscGames = normalDatas[.wsc], wscGames.count > 0 {
            var newWscGames = [Game]()
            var wsGames = [Game]()
            for wsc in wscGames {
                let wscGameType = wsc.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0
                if wscGameType == 0 {
                    newWscGames.append(wsc)
                } else if wscGameType == 1 {
                    wsGames.append(wsc)
                }
            }
            normalDatas[.wsc] = newWscGames.count > 0 ? newWscGames : nil
            normalDatas[.ws] = wsGames.count > 0 ? wsGames : nil
        }
        
        //hide platform
        let allGameTypes = normalDatas.keys
        for gameType in allGameTypes {
            var visible = true
            var platform = gameType.localizedShortName
            if gameType == .chm {
                platform = GameType.gb.localizedShortName
            } else if gameType == .win95 || gameType == .win98 {
                platform = GameType.dos.localizedShortName
            } else if gameType == .turbografx_16 || gameType == .turbografx_cd || gameType == .supergrafx {
                platform = GameType.pce.localizedShortName
            } else if gameType == .ngpc {
                platform = GameType.ngp.localizedShortName
            } else if gameType == .ws {
                platform = GameType.wsc.localizedShortName
            }
            visible = Settings.defalut.getPlatformVisible(platform: platform)
            if !visible {
                normalDatas[gameType] = nil
            }
        }
        
        if isSearchMode {
            //如果当前处于搜索模式 则搜索数据也进行更新
            updateSearchDatas()
        }
        didDatasUpdate?(normalDatas.isEmpty)
    }
    
    private func sortDatas(game1: Game, game2: Game, sortType: GameSortType, sortOrder: GameSortOrder) -> Bool {
        switch sortType {
        case .title:
            if sortOrder == .ascending {
                return game1.name < game2.name
            } else {
                return game1.name > game2.name
            }
        case .latestPlayed:
            let game1LatestPlayTime = (game1.latestPlayDate ?? Date(timeIntervalSince1970: 0)).timeIntervalSinceNow
            let game2LatestPlayTime = (game2.latestPlayDate ?? Date(timeIntervalSince1970: 0)).timeIntervalSinceNow
            if sortOrder == .ascending {
                if game1LatestPlayTime == game2LatestPlayTime {
                    return game1.name < game2.name
                }
                return game1LatestPlayTime < game2LatestPlayTime
            } else {
                if game1LatestPlayTime == game2LatestPlayTime {
                    return game1.name > game2.name
                }
                return game1LatestPlayTime > game2LatestPlayTime
            }
        case .addTime:
            if sortOrder == .ascending {
                return game1.importDate.timeIntervalSinceNow > game2.importDate.timeIntervalSinceNow
            } else {
                return game1.importDate.timeIntervalSinceNow < game2.importDate.timeIntervalSinceNow
            }
        case .playTime:
            if sortOrder == .ascending {
                if game1.totalPlayDuration == game2.totalPlayDuration {
                    return game1.name < game2.name
                }
                return game1.totalPlayDuration < game2.totalPlayDuration
            } else {
                if game1.totalPlayDuration == game2.totalPlayDuration {
                    return game1.name > game2.name
                }
                return game1.totalPlayDuration > game2.totalPlayDuration
            }
        }
    }
    
    ///构造符合搜索UI展示的数据源
    private func updateSearchDatas() {
        if let searchString = searchString {
            searchDatas.removeAll()
            for (gameTypeSection, gameType) in sortDatasKeys().enumerated() {
                for game in getGames(at: gameTypeSection) {
                    if ((game.displayName) + game.fileExtension).contains(searchString, caseSensitive: false) {
                        var gamesList = searchDatas[gameType]
                        if gamesList == nil {
                            gamesList = []
                            searchDatas[gameType] = gamesList
                        }
                        searchDatas[gameType]?.append(game)
                    }
                }
            }
        }
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout  { [weak self] sectionIndex, env in
            guard let self = self else { return nil }
            let gameType = self.sortDatasKeys()[sectionIndex]
            let itemSpacing = R.Size.ContentSpaceMedium - R.Size.GamesListSelectionEdge*2
            let sectionInsetTop = R.Size.ContentSpaceTiny
            let sectionInsetBottom = R.Size.ContentSpaceMedium
            let hideTitle = R.Style.GamesHideTitle
            
            //group布局
            let group: NSCollectionLayoutGroup
            var column = R.Style.GamesPerRow
            if UIDevice.isPad {
                column = (UIDevice.isPadMini ? 4 : 5 )
            }
            let widthDimension: NSCollectionLayoutDimension = .fractionalWidth(1/column)
            //item布局
            let totleSpacing = (R.Size.ContentSpaceMedium-R.Size.GamesListSelectionEdge)*2 + itemSpacing*(column-1)//横向间距总和
            let itemEstimatedWidth = (env.container.contentSize.width - totleSpacing)/column //一个item的宽
            let coverWidth = itemEstimatedWidth-R.Size.GamesListSelectionEdge*2
            let coverHeight = coverWidth/R.Size.GameCoverRatio(gameType: gameType) //封面的高度
            //一个item的高度 = 间距 + 封面高度 + 间距 + title高度 + 间距
            let itemEstimatedHeight = R.Size.GamesListSelectionEdge + coverHeight + (self.isSearchMode || !hideTitle ? R.Size.ContentSpaceSmall + R.Font.Footnote().lineHeight : 0) + R.Size.GamesListSelectionEdge
            let coverSize = CGSize(width: coverWidth, height: coverHeight)
            if let size =  self.coverSizes[gameType] {
                //尺寸存在
                if size != coverSize {
                    self.coverSizes[gameType] = coverSize
                }
            } else {
                //尺寸不存在
                self.coverSizes[gameType] = coverSize
            }
            
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: widthDimension,
                                                                                 heightDimension: .absolute(itemEstimatedHeight)))
            group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                          heightDimension: .absolute(itemEstimatedHeight)),
                                                       subitem: item, count: Int(column))
            
            group.interItemSpacing = NSCollectionLayoutSpacing.fixed(itemSpacing)
            let groupHorizontalInset = R.Size.ContentSpaceMedium-R.Size.GamesListSelectionEdge
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                          leading: groupHorizontalInset,
                                                          bottom: 0,
                                                          trailing: groupHorizontalInset)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = itemSpacing
            
            section.contentInsets = NSDirectionalEdgeInsets(top: sectionInsetTop,
                                                            leading: 0,
                                                            bottom: (sectionIndex != (self.normalDatas.count - 1)) ? sectionInsetBottom : 0,
                                                            trailing: 0)
            if self.isSearchMode || !R.Style.GamesHideGroupTitle {
                //header布局
                let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                heightDimension: .estimated(R.Size.ItemHeightSmall)),
                                                                             elementKind: UICollectionView.elementKindSectionHeader,
                                                                             alignment: .top)
                headerItem.pinToVisibleBounds = true
                section.boundarySupplementaryItems = [headerItem]
            }
            
            if !self.isSearchMode && sectionIndex == self.normalDatas.count - 1 && self.collectionView.numberOfItems() > R.Numbers.RandomGameLimit {
                //最后一个section添加footer
                let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                heightDimension: .absolute(55)),
                                                                             elementKind: UICollectionView.elementKindSectionFooter,
                                                                             alignment: .bottom)
                section.boundarySupplementaryItems.append(footerItem)
            }
            
            return section
            
        }
        return layout
    }
    
    func searchDatas(string: String, forceSearch: Bool = false) {
        guard forceSearch || searchString != string else { return }
        //开始搜索前获取已经选中的games
        let games = collectionView.indexPathsForSelectedItems?.compactMap({ getGame(at: $0) })
        isSearchMode = false
        searchString = string
        updateSearchDatas()
        isSearchMode = true
        collectionView.reloadData { [weak self] in
            guard let self = self else { return }
            if let games = games {
                //重新选中搜索前选中的item
                games.forEach {
                    if let indexPath = self.getIndexPath(for: $0) {
                        self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                    }
                }
                var mode: SelectionType = .selectNone
                if games.count == self.totalGamesCountForCurrentMode, self.totalGamesCountForCurrentMode > 0 {
                    mode = .selectAll
                } else if games.count > 0 {
                    mode = .selectSome(onlyOne: games.count == 1)
                }
                //通知外部 选择类型更新
                if self.totalGamesCountForCurrentMode > 0 {
                    self.didListViewSelectionChange?(mode)
                }
            }
        }
        reloadIndexView()
    }
    
    func stopSearch() {
        if isSearchMode {
            //停止搜索前获取已经选中的games
            let games = collectionView.indexPathsForSelectedItems?.compactMap({ getGame(at: $0) })
            isSearchMode = false
            searchString = nil
            searchDatas.removeAll()
            collectionView.reloadData { [weak self] in
                guard let self = self else { return }
                if let games = games {
                    //重新选中搜索前选中的item
                    games.forEach { self.collectionView.selectItem(at: self.getIndexPath(for: $0), animated: false, scrollPosition: []) }
                    var mode: SelectionType = .selectNone
                    if games.count == self.totalGamesCountForCurrentMode {
                        mode = .selectAll
                    } else if games.count > 0 {
                        mode = .selectSome(onlyOne: games.count == 1)
                    }
                    //通知外部 选择类型更新
                    self.didListViewSelectionChange?(mode)
                }
            }
            reloadIndexView()
        }
    }
    
    private func reloadIndexView() {
        let datasCount = (isSearchMode ? searchDatas : normalDatas).count
        if datasCount == 0 {
            indexView.isHidden = true
            return
        } else {
            indexView.isHidden = false
        }
        indexView.reloadData()
        indexView.deselectCurrentItem()
        indexView.selectItem(at: 0)
        indexView.isHidden = R.Style.GamesHideScrollIndicator
    }
    
    func updateRotation() {
        if UIDevice.isPhone {
            self.collectionView.reloadData()
            self.reloadIndexView()
        }
    }
    
    func isGameExist(for manufacturer: Manufacturer) -> Bool {
        for gameType in manufacturer.gameTypes {
            if !Settings.defalut.getPlatformVisible(platform: gameType.localizedShortName) {
                continue
            }
            if gameType == .chm,
               games.where({ $0.gameType == .gb }).filter({ ($0.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) == 1 }).count > 0 {
                return true
            }
            
            if gameType == .win95,
               games.where({ $0.gameType == .dos }).filter({ ($0.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) == 1 }).count > 0 {
                return true
            }
            
            if gameType == .win98,
               games.where({ $0.gameType == .dos }).filter({ ($0.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) == 2 }).count > 0 {
                return true
            }
            
            if gameType == .turbografx_16,
               games.where({ $0.gameType == .pce }).filter({ ($0.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) == 1 }).count > 0 {
                return true
            }
            
            if gameType == .turbografx_cd,
               games.where({ $0.gameType == .pce }).filter({ ($0.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) == 2 }).count > 0 {
                return true
            }
            
            if gameType == .supergrafx,
               games.where({ $0.gameType == .pce }).filter({ ($0.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) == 3 }).count > 0 {
                return true
            }
            
            if gameType == .ngpc,
               games.where({ $0.gameType == .ngp }).filter({ ($0.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) == 1 }).count > 0 {
                return true
            }
            
            if gameType == .ws,
               games.where({ $0.gameType == .wsc }).filter({ ($0.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) == 1 }).count > 0 {
                return true
            }
            
            if games.count(where: { $0.gameType == gameType }) > 0 {
                return true
            }
        }
        return false
    }
    
    ///If the game is nil, query the selected games in collectionView
    private func showGameEditSheet(game: Game? = nil) {
        var games = [Game]()
        if let game {
            games.append(game)
        } else if let tempIndexPaths = collectionView.indexPathsForSelectedItems {
            games.append(contentsOf: tempIndexPaths.compactMap({ getGame(at: $0) }))
        }
        guard games.count > 0 else { return }
        
        GameOptionsView.show(scene: .common,
                             games: games,
                             shouldHide: {
            $0 == .genHomeMenu || $0 == .delete
        }, hideCompletion: { [weak self] in
            guard let self else { return }
            if $0 == .genHomeMenu || $0 == .delete {
                self.needsUpdateToolViewSelection?()
                UIView.springAnimate { self.bottomToolView.alpha = 0 }
            }
        })
    }
    
    private func dismissAfterHandle(item: GameOption) -> Bool {
        return Set<GameOption>([.genHomeMenu, .delete]).contains(item)
    }
    
    func scrollToLastGame() {
        guard isGamesExist else { return }
        let lastSection = collectionView.lastSection
        let itemCounts = collectionView(collectionView, numberOfItemsInSection: lastSection)
        if itemCounts > 0 {
            collectionView.safeScrollToItem(at: IndexPath(row: itemCounts-1, section: lastSection), at: .bottom, animated: true)
        }
    }
    
    func scrollToFirstGame() {
        guard isGamesExist else { return }
        collectionView.safeScrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
    }
}

extension GameListView: UICollectionViewDataSource {
    private func sortDatasKeys() -> [GameType] {
        var predefinedOrder = System.allGameTypes
        predefinedOrder.append(.unknown)
        predefinedOrder.insert(.chm, at: predefinedOrder.firstIndex(of: .gb)!)
        predefinedOrder.insert(.win95, at: predefinedOrder.firstIndex(of: .dos)!)
        predefinedOrder.insert(.win98, at: predefinedOrder.firstIndex(of: .win95)!)
        predefinedOrder.insert(.turbografx_16, at: predefinedOrder.firstIndex(of: .pce)!)
        predefinedOrder.insert(.turbografx_cd, at: predefinedOrder.firstIndex(of: .turbografx_16)!)
        predefinedOrder.insert(.supergrafx, at: predefinedOrder.firstIndex(of: .turbografx_cd)!)
        predefinedOrder.insert(.ngpc, at: predefinedOrder.firstIndex(of: .ngp)!)
        predefinedOrder.insert(.ws, at: predefinedOrder.firstIndex(of: .wsc)! + 1)
        let sortedKeys: [GameType] = predefinedOrder.filter { (isSearchMode ? searchDatas : normalDatas).keys.contains($0) }
        return sortedKeys
    }
    
    private func getGames(at section: Int) -> [Game] {
        let gameTypes = sortDatasKeys()
        let gameType = gameTypes[section]
        if let results = (isSearchMode ? searchDatas : normalDatas)[gameType] {
            return results
        }
        return []
    }
    
    private func getGame(at indexPath: IndexPath) -> Game? {
        let games = getGames(at: indexPath.section)
        if games.count > indexPath.row {
            return games[indexPath.row]
        }
        return nil
    }
    
    private func getIndexPath(for game: Game) -> IndexPath? {
        if let results = (isSearchMode ? searchDatas : normalDatas)[game.effectiveGameType] {
            if let section = sortDatasKeys().firstIndex(of: game.effectiveGameType), let row = results.firstIndex(of: game) {
                return IndexPath(row: row, section: section)
            }
        }
        return nil
    }
    
    private func deleteGames(indexPaths: [IndexPath]) {
        var sectionRowsDict: [Int: [Int]] = [:]
        for indexPath in indexPaths {
            if sectionRowsDict[indexPath.section] != nil {
                sectionRowsDict[indexPath.section]?.append(indexPath.row)
            } else {
                sectionRowsDict[indexPath.section] = [indexPath.row]
            }
        }
        
        let sortDatasKeys = sortDatasKeys()
        for (key, value) in sectionRowsDict {
            if var games = normalDatas[sortDatasKeys[key]] {
                games.remove(atOffsets: IndexSet(value))
                normalDatas[sortDatasKeys[key]] = games.count == 0 ? nil : games
            }
        }
        
        collectionView.reloadData()
        didDatasUpdate?(normalDatas.isEmpty)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        (isSearchMode ? searchDatas : normalDatas).count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let gameType = sortDatasKeys()[section]
        if foldedGameTypes[gameType] ?? false {
            return 0
        }
        return getGames(at: section).count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: GameCollectionViewCell.self, for: indexPath)
        if let game = getGame(at: indexPath) {
            var coverGameType = game.gameType
            
            if game.supportChangeCategory {
                let gameTypeCategory = game.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0
                if gameTypeCategory > 0 {
                    if game.gameType == .gb {
                        coverGameType = .chm
                    } else if game.gameType == .dos {
                        if gameTypeCategory == 1 {
                            coverGameType = .win95
                        } else if gameTypeCategory == 2 {
                            coverGameType = .win98
                        }
                    } else if game.gameType == .pce {
                        if gameTypeCategory == 1 {
                            coverGameType = .turbografx_16
                        } else if gameTypeCategory == 2 {
                            coverGameType = .turbografx_cd
                        } else if gameTypeCategory == 3 {
                            coverGameType = .supergrafx
                        }
                    } else if game.gameType == .ngp {
                        if gameTypeCategory == 1 {
                            coverGameType = .ngpc
                        }
                    } else if game.gameType == .wsc {
                        if gameTypeCategory == 1 {
                            coverGameType = .ws
                        }
                    }
                }
            }
            
            cell.setData(game: game,
                         isSelect: isSelectionMode,
                         highlightString: searchString,
                         coverSize: coverSizes[coverGameType] ?? .zero,
                         showTitle: !R.Style.GamesHideTitle || isSearchMode,
                         indexPath: indexPath)
        }
        
        cell.onFocusConfirm = { [weak self] in
            guard let self else { return false }
            if self.isSelectionMode {
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
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            //header
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: GamesCollectionReusableView.self, for: indexPath)
            let gameType = sortDatasKeys()[indexPath.section]
            header.setData(gameType: gameType,
                           highlightString: searchString,
                           gamesCount: getGames(at: indexPath.section).count,
                           isFolded: foldedGameTypes[gameType] ?? false)
            
            header.backgroundColor = R.Color.BackgroundPrimary
            header.didTapGameCount = { [weak self] in
                guard let self else { return }
                if self.foldedGameTypes[gameType] ?? false {
                    //展开
                    self.foldedGameTypes[gameType] = false
                } else {
                    //折叠
                    self.foldedGameTypes[gameType] = true
                }
                self.collectionView.reloadSections([indexPath.section])
            }
            header.didTapPlatform = {
                if gameType != .unknown {
                    ASWebView.show(url: R.URLs.History(gameType: gameType))
                }
            }
            return header
        } else {
            //随机游戏footer
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: RandomGameCollectionReusableView.self, for: indexPath)
            header.randomButton.didTapButton = { [weak self, weak header] in
                guard let self = self else { return }
                guard let header = header else { return }
                self.fireworks.addFireworks(count: 4, around: header.randomButton)
                let randomSection = Int(arc4random()) % self.normalDatas.count
                if let games = self.normalDatas[self.sortDatasKeys()[randomSection]] {
                    let randomGame = games[Int(arc4random()) % games.count]
                    randomGame.handleTapAction(forceQuick: true)
                }
            }
            return header
        }
    }
}

extension UIView {
    func rotateShake(
        duration: TimeInterval = 1,
        completion: (() -> Void)? = nil) {
            CATransaction.begin()
            let animation = CAKeyframeAnimation(keyPath: "transform.rotation")
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
            CATransaction.setCompletionBlock(completion)
            animation.duration = duration
            
            animation.values = [-.pi/4.0, .pi/4.0, -.pi/6.0, .pi/6.0, -.pi/8.0, .pi/8.0, -.pi/10.0, .pi/10.0, 0.0]
            layer.add(animation, forKey: "rotateShake")
            CATransaction.commit()
        }
}

extension GameListView: UICollectionViewDelegate {
    func selectItem(at indexPath: IndexPath) {
        if isSelectionMode {
            if let selectedItems = collectionView.indexPathsForSelectedItems?.count {
                if selectedItems == totalGamesCountForCurrentMode && selectedItems > 1 {
                    //全部选中了
                    didListViewSelectionChange?(.selectAll);
                } else if selectedItems > 0 {
                    didListViewSelectionChange?(.selectSome(onlyOne: selectedItems == 1));
                }
            }
            UIView.springAnimate { self.bottomToolView.alpha = 1 }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectItem(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if isSelectionMode {
            if let game = getGame(at: indexPath) {
                if game.gameType == .unknown {
                    UIView.makeToast(message: R.string.localizable.unknownPlatformGameSelectWarn())
                    return false
                } else if game.id == Game.DsHomeMenuPrimaryKey || game.id == Game.DsiHomeMenuPrimaryKey {
                    UIView.makeToast(message: R.string.localizable.homeMenuSelectWarn())
                    return false
                }
            }
            return true
        }
        
        if let game = getGame(at: indexPath) {
            game.handleTapAction()
        }
        return false
    }
    
    func deselectItem(at indexPath: IndexPath) {
        if let selectCount = collectionView.indexPathsForSelectedItems?.count {
            didListViewSelectionChange?(selectCount > 0 ? .selectSome(onlyOne: selectCount == 1) : .selectNone);
            if selectCount == 0 {
                UIView.springAnimate { self.bottomToolView.alpha = 0 }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        deselectItem(at: indexPath)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScroll?()
        
        let contentOffsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        updateToolViewVisibility(for: scrollView)
        
        // indexView变更
        guard !indexView.isTouching else { return }
        let sections = collectionView.numberOfSections
        var pinnedSection: Int?
        for section in 0..<sections {
            if let layoutAttributes = collectionView.layoutAttributesForSupplementaryElement(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: section)
            ) {
                let headerFrame = layoutAttributes.frame
                if contentOffsetY + 5 >= floor(headerFrame.origin.y) {
                    pinnedSection = section
                } else {
                    break
                }
            }
        }
        
        if let pinnedSection = pinnedSection {
            guard let item = self.indexView.item(at: pinnedSection), item.bounds != .zero  else { return }
            guard !(self.indexView.selectedItem?.isEqual(item) ?? false) else { return }
            self.indexView.deselectCurrentItem()
            self.indexView.selectItem(at: pinnedSection)
            self.lastSelectSection = pinnedSection
        }
    }
    
    func scrollToTop() {
        collectionView.scrollToTop()
    }
}

// MARK: - ToolView Scroll Visibility
private extension GameListView {
    enum ToolViewScroll {
        /// The offset threshold considered as "at the top"
        static let topThreshold: CGFloat = 1
        /// The minimum displacement for determining the scroll direction
        static let directionThreshold: CGFloat = 1.5
        /// When not at the top, the minimum speed required to swipe down and show the ToolView.
        static let showVelocityThreshold: CGFloat = 1200
        /// If the displacement exceeds this limit, it is considered a bounce / release rebound and will not be included in the show/hide judgment.
        static let maxDirectionDelta: CGFloat = 50
    }
    
    func clampedContentOffsetY(for scrollView: UIScrollView) -> CGFloat {
        let raw = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let maxOffsetY = max(
            0,
            scrollView.contentSize.height
            + scrollView.adjustedContentInset.top
            + scrollView.adjustedContentInset.bottom
            - scrollView.bounds.height
        )
        return min(max(raw, 0), maxOffsetY)
    }
    
    func updateToolViewVisibility(for scrollView: UIScrollView) {
        guard UIDevice.isPhone,
        scrollView.contentSize.height >= R.Size.WindowHeight else { return }
        
        let contentOffsetY = clampedContentOffsetY(for: scrollView)
        let now = CACurrentMediaTime()
        
        if isSearchMode || isSelectionMode {
            needsUpdateToolViewVisible?(true)
            syncToolViewScrollBaseline(offset: contentOffsetY, time: now)
            return
        }
        
        if !isToolViewScrollInitialized {
            syncToolViewScrollBaseline(offset: contentOffsetY, time: now)
            isToolViewScrollInitialized = true
            return
        }
        
        let deltaY = contentOffsetY - lastContentOffsetY
        let timeDelta = now - lastToolViewScrollTimestamp
        // Instantaneous speed (pt/s) between two consecutive scroll callbacks, recalculated per frame without cross-frame accumulation.
        let scrollVelocity = timeDelta > 0 ? deltaY / CGFloat(timeDelta) : 0
        
        defer {
            syncToolViewScrollBaseline(offset: contentOffsetY, time: now)
        }
        
        // Force display the list when it's at the top
        if contentOffsetY <= ToolViewScroll.topThreshold {
            needsUpdateToolViewVisible?(true)
            return
        }
        
        // Ignore the minor jitters when the direction is unclear.
        guard abs(deltaY) >= ToolViewScroll.directionThreshold else { return }
        
        // Ignore large jumps caused by edge bounce or snap-back.
        guard abs(deltaY) <= ToolViewScroll.maxDirectionDelta else { return }
        
        if deltaY > 0 {
            // Swipe up to force hide
            needsUpdateToolViewVisible?(false)
            return
        }
        
        // Swipe down to reveal: Use the pan gesture speed while dragging, and use the instantaneous speed between frames when decelerating.
        let downwardSpeed: CGFloat
        if scrollView.isDragging {
            // When dragging your finger downward, velocity.y is positive, measured in pt/s.
            downwardSpeed = scrollView.panGestureRecognizer.velocity(in: scrollView).y
        } else {
            // When offset decreases, scrollVelocity becomes negative. Inverting it gives the downward scrolling speed.
            downwardSpeed = -scrollVelocity
        }
        
        if downwardSpeed >= ToolViewScroll.showVelocityThreshold {
            needsUpdateToolViewVisible?(true)
        }
    }
    
    func syncToolViewScrollBaseline(offset: CGFloat, time: TimeInterval) {
        lastContentOffsetY = offset
        lastToolViewScrollTimestamp = time
    }
}

// MARK: - SectionIndexViewDataSource/SectionIndexViewDelegate
extension GameListView: SectionIndexViewDataSource, SectionIndexViewDelegate {
    func numberOfScetions(in sectionIndexView: SectionIndexView) -> Int {
        (isSearchMode ? searchDatas : normalDatas).count
    }
    
    func sectionIndexView(_ sectionIndexView: SectionIndexView, itemAt section: Int) -> any SectionIndexViewItem {
        let item = SectionIndexViewItemView()
        let gameType = sortDatasKeys()[section]
        if let title = (R.Style.GamesGroupTitleStyle == .abbr ? gameType.localizedShortName : gameType.localizedName).first?.uppercased() {
            item.title = title
        } else {
            item.title = "?"
        }
        item.titleColor = R.Color.LabelTertiary
        item.titleSelectedColor = R.Color.LabelPrimary.forceStyle(.dark)
        item.selectedColor = R.Color.Main
        item.titleFont = R.Font.Caption2(emphasis: true)
        
        var indicatorContentView: UIView? = nil
        switch R.Style.GamesGroupTitleStyle {
        case .abbr:
            indicatorContentView = ASLabelView(text: .extraLargeText(gameType.localizedShortName))
        case .fullName:
            indicatorContentView = ASLabelView(text: .extraLargeText(gameType.localizedName))
        case .brand:
            if let brandImage = gameType.brandImage {
                indicatorContentView = ASIconView(.image(brandImage))
            } else {
                indicatorContentView = ASLabelView(text: .extraLargeText(gameType.localizedShortName))
            }
        }
        
        if let indicatorContentView {
            let indicatorView = UIView()
            indicatorView.backgroundColor = R.Color.BackgroundPrimary
            indicatorView.layerCornerRadius = R.Size.ItemHeightSmall/2
            indicatorView.addSubview(indicatorContentView)
            indicatorContentView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(R.Size.ContentSpaceSmall)
                make.height.equalTo(R.Size.IconMedium)
            }
            indicatorView.overrideUserInterfaceStyle = UIDevice.isDarkMode ? .light : .dark
            item.indicator = indicatorView
        }
        
        return item
    }
    
    func sectionIndexView(_ sectionIndexView: SectionIndexView, didSelect section: Int) {
        sectionIndexView.hideCurrentItemIndicator()
        sectionIndexView.deselectCurrentItem()
        sectionIndexView.selectItem(at: section)
        sectionIndexView.showCurrentItemIndicator()
        sectionIndexView.impact()
        collectionView.panGestureRecognizer.isEnabled = false
        let numberOfSections = collectionView.numberOfSections
        if numberOfSections < section {
            return
        }
        if collectionView.numberOfItems(inSection: section) == 0 {
            if let sectionWithItems = nearestSectionWithItems(from: section) {
                collectionView.scrollToItem(at: IndexPath(row: 0, section: sectionWithItems), at: .top, animated: true)
            }
            return
        }
        collectionView.scrollToItem(at: IndexPath(row: 0, section: section), at: .top, animated: true)
    }
    
    func sectionIndexViewToucheEnded(_ sectionIndexView: SectionIndexView) {
        UIView.animate(withDuration: 0.3) {
            sectionIndexView.hideCurrentItemIndicator()
        }
        collectionView.panGestureRecognizer.isEnabled = true
    }
    
    func sectionIndexViewDidSelectSearch(_ sectionIndexView: SectionIndexView) {
        scrollToTop()
    }
    
    //从指定 section 向两边扩散查找最近的非空 section（双向 BFS）
    private func nearestSectionWithItems(from section: Int) -> Int? {
        let total = collectionView.numberOfSections
        guard total > 0, section >= 0, section < total else { return nil }
        
        // 如果当前 section 本身就有
        if collectionView.numberOfItems(inSection: section) > 0 {
            return section
        }
        
        var offset = 1
        
        while section - offset >= 0 || section + offset < total {
            
            // 左边
            let left = section - offset
            if left >= 0,
               collectionView.numberOfItems(inSection: left) > 0 {
                return left
            }
            
            // 右边
            let right = section + offset
            if right < total,
               collectionView.numberOfItems(inSection: right) > 0 {
                return right
            }
            
            offset += 1
        }
        
        return nil
    }
}

// MARK: - UIGestureRecognizerDelegate
extension GameListView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        //When long-press is triggered, disable the cell's tap response.
        return false
    }
}
