//
//  GameListLandscapeView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import RealmSwift
import CollectionViewPagingLayout
import UniformTypeIdentifiers
import IceCream

///横屏专属的游戏列表首页
///布局从上到下分为两个部分：navigation（筛选器/功能菜单/状态信息）、content（游戏轮播+聚焦信息）
class GameListLandscapeView: BaseView {
    
    //MARK: - navigation区
    ///筛选器 两级筛选：厂商→GameType
    private lazy var filterButton: LandscapeFilterView = {
        let view = LandscapeFilterView()
        view.addTapGesture { [weak self] gesture in
            self?.showManufacturerFilterSheet()
        }
        view.isFocusable = true
        view.onFocusConfirm = { [weak self] in
            self?.showManufacturerFilterSheet()
            return true
        }
        return view
    }()
    
    private lazy var historyButton: ASButtonView = {
        let view = ASButtonView(.iconOnlyWithSmallSize(icon: .symbolImage(R.image.history_iconSymbols())).enableGlass(true))
        view.didTapButton = { [weak self] in
            guard let self = self else { return }
            guard let view = PlayHistoryView.show() else { return }
            view.didTapGame = { [weak self] game in
                guard let self else { return }
                game.handleTapAction()
            }
        }
        return view
    }()
    
    private lazy var searchButton: ASButtonView = {
        let view = ASButtonView(.iconOnlyWithSmallSize(icon: .symbolImage(R.image.searchRegular_iconSymbols())).enableGlass(true))
        view.didTapButton = { [weak self] in
            //search
        }
        return view
    }()
    
    private lazy var importButton: ASButtonView = {
        let view = ASButtonView(.iconOnlyWithSmallSize(icon: .symbolImage(R.image.import_iconSymbols())).enableGlass(true))
        view.didTapButton = { [weak self] in
            NotificationCenter.default.post(name: R.NotificationName.HomeSelectionChange, object: HomeTabBar.BarSelection.imports)
        }
        return view
    }()
    
    private lazy var settingsButton: ASButtonView = {
        let view = ASButtonView(.iconOnlyWithSmallSize(icon: .symbolImage(R.image.settings_iconSymbols())).enableGlass(true))
        view.didTapButton = { [weak self] in
            NotificationCenter.default.post(name: R.NotificationName.HomeSelectionChange, object: HomeTabBar.BarSelection.settings)
        }
        return view
    }()
    
    /// Theme: carousel style, background music, and sound effects
    private lazy var themeButton: ASButtonView = {
        let view = ASButtonView(.iconOnlyWithSmallSize(icon: .symbol(.paintpalette)).enableGlass(true))
        view.didTapButton = { [weak self] in
            guard let self else { return }
            self.showThemeSheet()
        }
        return view
    }()
    
    private lazy var statusView: LandscapeStatusView = {
        let view = LandscapeStatusView()
        view.didTapController = {
            ControllersSettingView.show()
        }
        return view
    }()
    
    //MARK: - content区（轮播）
    private lazy var carouselLayout: CollectionViewPagingLayout = {
        let layout = CollectionViewPagingLayout()
        layout.numberOfVisibleItems = 20
        layout.scrollDirection = .horizontal
        layout.delegate = self
        return layout
    }()
    
    private lazy var carouselView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: carouselLayout)
        view.backgroundColor = .clear
        view.isPagingEnabled = LandscapeCarouselStyle.current.usesSystemPaging
        view.showsHorizontalScrollIndicator = false
        view.clipsToBounds = false
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: GameLandscapeScaleCell.self)
        view.register(cellWithClass: GameLandscapeStackCell.self)
        view.register(cellWithClass: GameLandscapeSnapshotCell.self)
        view.dataSource = self
        view.delegate = self
        return view
    }()
    
    //MARK: - 聚焦信息面板
    private let titleLabel: ASLabelView = {
        let view = ASLabelView(text: ASText(attributes: .init(text: "",
                                                              color: R.Color.LabelPrimary.forceStyle(.dark),
                                                              font: R.Font.LargeTitle(emphasis: true)),
                                            shadow: ASText.Shadow()))
        return view
    }()
    
    private let subTitleLabel: ASLabelView = {
        var text: ASText = .smallText("", color: R.Color.LabelSecondary)
        text.shadow = ASText.Shadow(shadowOpacity: 0.2)
        let view = ASLabelView(text: text)
        return view
    }()
    
    private lazy var playButton: ASButtonView = {
        var button = ASButton.large(icon: .symbol(.playFill),
                                    title: "PLAY",
                                    sizeStyle: .fixHeight(R.Size.ButtonLarge,
                                                          insets: UIEdgeInsets(horizontal: R.Size.ContentSpaceHuge*2, vertical: R.Size.ContentSpaceTiny*2))).enableGlass(true)
        let view = ASButtonView(button)
        view.didTapButton = { [weak self] in
            guard let self, let game = self.focusedGame else { return }
            game.handleTapAction(forceQuick: true)
        }
        return view
    }()
    
    private lazy var moreButton: ASButtonView = {
        let view = ASButtonView(.iconOnly(icon: .symbolImage(R.image.ellipsis_iconSymbols()),
                                          iconSize: CGSize(R.Size.ButtonLarge),
                                          background: R.Color.BackgroundSecondary,
                                          insets: .init(inset: R.Size.ContentSpaceSmall)).enableGlass(true))
        view.didTapButton = { [weak self] in
            guard let self, let game = self.focusedGame else { return }
            GameOptionsView.show(scene: .common,
                                 games: [game],
                                 shouldHide: {
                $0 == .genHomeMenu || $0 == .delete
            })
        }
        return view
    }()
    
    private lazy var tipsButton: ASButtonView = {
        // Visual hint only; hold Command / Select to show the cheatsheet.
        var button = ASButton.extraSmall(icon: .symbol(.command, colors: [R.Color.LabelSecondary]),
                                         title: R.string.localizable.focusShortcutsTips(),
                                         titleColor: R.Color.LabelSecondary).enableGlass(true)
        button.state = .disabled
        let view = ASButtonView(button)
        view.isFocusable = false
        view.isHidden = true
        return view
    }()
    
    ///聚焦信息面板容器 跟随聚焦cell封面底部并相对封面居中
    private lazy var infoPanelView: UIStackView = {
        let playStack = UIStackView(arrangedSubviews: [playButton, moreButton])
        playStack.axis = .horizontal
        playStack.spacing = R.Size.ContentSpaceSmall
        playButton.snp.makeConstraints { make in
            make.height.equalTo(R.Size.ButtonLarge)
        }
        
        let view = UIStackView(arrangedSubviews: [titleLabel, subTitleLabel, playStack])
        view.axis = .vertical
        view.alignment = .center
        view.spacing = R.Size.ContentSpaceTiny
        view.setCustomSpacing(R.Size.ContentSpaceMedium, after: subTitleLabel)
        return view
    }()
    
    //MARK: - 数据
    private var gamesUpdateToken: NotificationToken? = nil
    private var games: Results<Game> = {
        let realm = Database.realm
        return realm.objects(Game.self).where { !$0.isDeleted }
    }()
    
    ///选中的厂商 nil表示全部
    private(set) var selectedManufacturer: Manufacturer? = nil
    ///选中的游戏类型 nil表示全部
    private(set) var selectedGameType: GameType? = nil
    ///当前厂商下可筛选的游戏类型
    private var availableGameTypes: [GameType] = []
    ///content区展示的游戏
    private var displayGames: [Game] = []
    ///搜索关键字
    private var searchString: String? = nil
    
    private var focusedGame: Game? {
        let index = carouselLayout.currentPage
        guard index >= 0, index < displayGames.count else { return nil }
        return displayGames[index]
    }
    
    private var lastLayoutSize: CGSize = .zero
    /// Last info-panel anchor; skip constraint updates when unchanged.
    private var lastPanelAnchor: CGPoint = .zero
    /// Scale/Stack flick in progress; focus info waits until the snap finishes.
    private var isCarouselUserScrolling = false
    private var isCarouselSnapping = false
    
    private var notificationTokens = [Any]()
    
    private var usesSystemCarouselPaging: Bool {
        LandscapeCarouselStyle.current.usesSystemPaging
    }
    
    //MARK: - 生命周期
    override init(frame: CGRect) {
        super.init(frame: frame)
        LandscapeCarouselStyle.applyPersistedOptions()
        setupViews()
        setupDatas()
        setupNotifications()
        BackgroundMusicKit.shared.setLandscapeHomeVisible(true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        gamesUpdateToken = nil
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    /// Call before tearing down on rotation so collectionView cannot batch-update during the bounds animation.
    func prepareForRemoval() {
        BackgroundMusicKit.shared.setLandscapeHomeVisible(false)
        carouselView.dataSource = nil
        carouselView.delegate = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard window != nil, superview != nil else { return }
        if bounds.size != lastLayoutSize, bounds.size != .zero {
            lastLayoutSize = bounds.size
            //尺寸变化时轮播cell的封面尺寸需要重新计算
            carouselView.reloadData()
        }
        updateInfoPanelPosition()
    }
    
    
    //MARK: - Setup
    private func setupViews() {
        //背景由HomeViewController的LandscapeBackgroundView透出 自身保持透明
        backgroundColor = .clear
        
        //navigation区
        let navigationView = UIView()
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(R.Size.NavigationHeight)
            make.top.equalToSuperview().offset(R.Size.ContentInsetTop)
        }
        
        navigationView.addSubview(filterButton)
        filterButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
            make.height.equalTo(R.Size.ButtonSmall)
        }
        
        let functionStack = UIStackView(arrangedSubviews: [historyButton, themeButton, importButton, settingsButton])
        functionStack.axis = .horizontal
        functionStack.spacing = R.Size.ContentSpaceSmall
        navigationView.addSubview(functionStack)
        functionStack.snp.makeConstraints { make in
            make.leading.equalTo(filterButton.snp.trailing).offset(R.Size.ContentSpaceLarge)
            make.centerY.equalToSuperview()
        }
        
        navigationView.addSubview(statusView)
        statusView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
            make.height.equalTo(R.Size.ButtonSmall)
        }
        
        //content区轮播 置于最底层
        insertSubview(carouselView, at: 0)
        carouselView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(filterButton.snp.bottom).offset(R.Size.ContentSpaceMedium)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
        
        addSubview(tipsButton)
        tipsButton.snp.makeConstraints { make in
            make.trailing.equalTo(safeAreaLayoutGuide).inset(R.Size.ContentSpaceHuge)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(R.Size.ContentSpaceLarge)
        }
        updateTipsButton()
        
        // Info panel tracks the focused cover; offsets are updated in updateInfoPanelPosition.
        addSubview(infoPanelView)
        infoPanelView.snp.makeConstraints { make in
            make.centerX.equalTo(self.snp.leading).offset(0)
            make.top.equalTo(self.snp.top).offset(0)
            make.width.lessThanOrEqualToSuperview().offset(-R.Size.ContentSpaceLarge*2)
        }
        
        applyCarouselPagingMode()
    }
    
    private func setupDatas() {
        gamesUpdateToken = games.observe(keyPaths: [
            \Game.gameCover,
             \Game.icon,
             \Game.banner,
             \Game.aliasName,
             \Game.onlineCoverUrl,
             \Game.latestPlayDate,
             \Game.latestPlayDuration,
             \Game.totalPlayDuration
        ]) { [weak self] changes in
            guard let self else { return }
            switch changes {
            case .update(_, let deletions, let insertions, let modifications):
                if !deletions.isEmpty {
                    self.reloadAll(keepFocus: false)
                } else if !insertions.isEmpty || !modifications.isEmpty {
                    self.reloadAll(keepFocus: true)
                }
            default:
                break
            }
        }
        reloadAll(keepFocus: false)
    }
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        let reloadNames: [Notification.Name] = [
            R.NotificationName.PlatformVisibleChange,
            R.NotificationName.GameSortChange,
            R.NotificationName.GameCategoryChange,
            R.NotificationName.PlatformOrderChange,
            R.NotificationName.PlatformSelectionChange,
            R.NotificationName.GameCoverChange
        ]
        for name in reloadNames {
            notificationTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.reloadAll(keepFocus: true)
            })
        }
        
        //结束游戏后刷新游玩时长信息
        notificationTokens.append(center.addObserver(forName: R.NotificationName.StopPlayGame, object: nil, queue: .main) { [weak self] _ in
            self?.updateFocusedGameInfo()
        })
        
        //厂商排序变化
        notificationTokens.append(center.addObserver(forName: R.NotificationName.ManufacturerOrderUpdate, object: nil, queue: .main) { [weak self] _ in
            self?.reloadAll(keepFocus: true)
        })
        
        notificationTokens.append(center.addObserver(forName: R.NotificationName.GameMetadataChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, !R.Style.GameHideRating else { return }
            if let gameId = notification.object as? String,
               let row = self.displayGames.firstIndex(where: { $0.id == gameId }) {
                self.carouselView.reloadItems(at: [IndexPath(row: row, section: 0)])
            }
        })

        let inputChange: (Notification) -> Void = { [weak self] _ in
            self?.updateTipsButton()
        }
        notificationTokens.append(center.addObserver(forName: .externalGameControllerDidConnect, object: nil, queue: .main, using: inputChange))
        notificationTokens.append(center.addObserver(forName: .externalGameControllerDidDisconnect, object: nil, queue: .main, using: inputChange))
        notificationTokens.append(center.addObserver(forName: .externalKeyboardDidConnect, object: nil, queue: .main, using: inputChange))
        notificationTokens.append(center.addObserver(forName: .externalKeyboardDidDisconnect, object: nil, queue: .main, using: inputChange))
    }

    /// Hide when nothing is connected; Command glyph for keyboard-only, Select glyph when a gamepad is present.
    private func updateTipsButton() {
        let connected = ExternalGameControllerManager.shared.connectedControllers
        guard !connected.isEmpty else {
            tipsButton.isHidden = true
            return
        }
        tipsButton.isHidden = false
        let hasGamepad = connected.contains { $0.inputType != .keyboard }
        let icon: ASIcon = hasGamepad
            ? .symbolImage(R.image.sel_iconSymbols(), colors: [R.Color.LabelSecondary])
            : .symbol(.command, colors: [R.Color.LabelSecondary])
        tipsButton.setIcon(icon)
    }
    
    //MARK: - 数据管线
    
    ///平台是否可见 虚拟类型映射回原平台配置
    private static func isPlatformVisible(_ gameType: GameType) -> Bool {
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
        return Settings.defalut.getPlatformVisible(platform: platform)
    }
    
    ///厂商是否包含该类型（含虚拟类型的特殊映射）
    private static func manufacturerAllows(_ gameType: GameType, manufacturer: Manufacturer) -> Bool {
        switch gameType {
        case .chm:
            return manufacturer == .modRetro
        case .win95, .win98:
            return manufacturer.gameTypes.contains(.dos)
        case .turbografx_16, .turbografx_cd, .supergrafx:
            return manufacturer.gameTypes.contains(.pce)
        case .ngpc:
            return manufacturer.gameTypes.contains(.ngp)
        case .ws:
            return manufacturer.gameTypes.contains(.wsc)
        default:
            return manufacturer.gameTypes.contains(gameType)
        }
    }
    
    ///与GameListView一致的平台展示顺序
    private static func predefinedGameTypeOrder() -> [GameType] {
        var order = System.allGameTypes
        order.append(.unknown)
        order.insert(.chm, at: order.firstIndex(of: .gb)!)
        order.insert(.win95, at: order.firstIndex(of: .dos)!)
        order.insert(.win98, at: order.firstIndex(of: .win95)!)
        order.insert(.turbografx_16, at: order.firstIndex(of: .pce)!)
        order.insert(.turbografx_cd, at: order.firstIndex(of: .turbografx_16)!)
        order.insert(.supergrafx, at: order.firstIndex(of: .turbografx_cd)!)
        order.insert(.ngpc, at: order.firstIndex(of: .ngp)!)
        order.insert(.ws, at: order.firstIndex(of: .wsc)! + 1)
        return order
    }
    
    private func sortGames(_ list: [Game]) -> [Game] {
        let sortType = GameSortType(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.gameSortType.rawValue) ?? 0) ?? .title
        let sortOrder = GameSortOrder(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.gameSortOrder.rawValue) ?? 0) ?? .ascending
        return list.sorted { game1, game2 in
            switch sortType {
            case .title:
                return sortOrder == .ascending ? game1.name < game2.name : game1.name > game2.name
            case .latestPlayed:
                let time1 = (game1.latestPlayDate ?? Date(timeIntervalSince1970: 0)).timeIntervalSinceNow
                let time2 = (game2.latestPlayDate ?? Date(timeIntervalSince1970: 0)).timeIntervalSinceNow
                if time1 == time2 {
                    return sortOrder == .ascending ? game1.name < game2.name : game1.name > game2.name
                }
                return sortOrder == .ascending ? time1 < time2 : time1 > time2
            case .addTime:
                return sortOrder == .ascending ?
                game1.importDate.timeIntervalSinceNow > game2.importDate.timeIntervalSinceNow :
                game1.importDate.timeIntervalSinceNow < game2.importDate.timeIntervalSinceNow
            case .playTime:
                if game1.totalPlayDuration == game2.totalPlayDuration {
                    return sortOrder == .ascending ? game1.name < game2.name : game1.name > game2.name
                }
                return sortOrder == .ascending ?
                game1.totalPlayDuration < game2.totalPlayDuration :
                game1.totalPlayDuration > game2.totalPlayDuration
            }
        }
    }
    
    ///重建数据源 厂商→gameType→扁平游戏数组
    private func rebuildDatas() {
        //按虚拟类型分组
        var grouped: [GameType: [Game]] = [:]
        for game in games {
            grouped[game.effectiveGameType, default: []].append(game)
        }
        
        //平台可见性过滤
        for type in Array(grouped.keys) where !Self.isPlatformVisible(type) {
            grouped[type] = nil
        }
        
        //厂商过滤
        if let manufacturer = selectedManufacturer {
            grouped = grouped.filter { Self.manufacturerAllows($0.key, manufacturer: manufacturer) }
        }
        
        availableGameTypes = Self.predefinedGameTypeOrder().filter { grouped.keys.contains($0) }
        
        //类型筛选失效时重置
        if let selectedGameType, !availableGameTypes.contains(selectedGameType) {
            self.selectedGameType = nil
        }
        
        //扁平化 保持组内排序与组间顺序
        var list: [Game]
        if let selectedGameType {
            list = sortGames(grouped[selectedGameType] ?? [])
        } else {
            list = availableGameTypes.flatMap { sortGames(grouped[$0] ?? []) }
        }
        
        //搜索过滤
        if let searchString, !searchString.isEmpty {
            list = list.filter { ($0.displayName + $0.fileExtension).contains(searchString, caseSensitive: false) }
        }
        
        displayGames = list
    }
    
    private func reloadAll(keepFocus: Bool) {
        let focusId = keepFocus ? focusedGame?.id : nil
        rebuildDatas()
        applyCarouselPagingMode()
        carouselLayout.invalidateLayoutInBatchUpdate()
        carouselView.reloadData()
        
        if let focusId, let index = displayGames.firstIndex(where: { $0.id == focusId }) {
            carouselLayout.setCurrentPage(index, animated: false)
        } else if carouselView.numberOfItems(inSection: 0) > 0 {
            carouselLayout.setCurrentPage(0, animated: false)
        }
        updateFocusedGameInfo()
        // Cell frames are ready on the next cycle; snap the info panel then.
        DispatchQueue.main.async { [weak self] in
            self?.updateInfoPanelPosition()
            self?.syncCarouselFocusTargets()
        }
    }
    
    //MARK: - navigation交互
    
    ///筛选第一级：选择厂商 选中具体厂商后接着弹出GameType筛选
    private func showManufacturerFilterSheet() {
        //只展示有游戏的厂商
        let manufacturers = Theme.defalut.manufacturerOrder.filter { manufacturer in
            games.contains { game in
                let type = game.effectiveGameType
                return Self.isPlatformVisible(type) && Self.manufacturerAllows(type, manufacturer: manufacturer)
            }
        }
        guard manufacturers.count > 0 else { return }
        
        let options = [R.string.localizable.all()] + manufacturers.map { $0.title }
        var selectedIndex = 0
        if let selectedManufacturer, let index = manufacturers.firstIndex(of: selectedManufacturer) {
            selectedIndex = index + 1
        }
        
        OptionsSheetView.show(icon: .symbol(.line3HorizontalDecrease),
                              title: R.string.localizable.filterTitle(),
                              options: options,
                              selectedIndex: selectedIndex) { [weak self] index in
            guard let self, let index else { return }
            let manufacturer: Manufacturer? = index == 0 ? nil : manufacturers[index - 1]
            if let manufacturer {
                let manufacturerChanged = manufacturer != self.selectedManufacturer
                self.selectedManufacturer = manufacturer
                if manufacturerChanged {
                    self.selectedGameType = nil
                    self.reloadAll(keepFocus: false)
                }
                self.updateFilterButton()
                //第二级：该厂商下有多个GameType时弹出类型筛选
                if self.availableGameTypes.count > 1 {
                    self.showGameTypeFilterSheet(manufacturer: manufacturer)
                }
            } else {
                //选择All清空所有筛选
                guard self.selectedManufacturer != nil || self.selectedGameType != nil else { return }
                self.selectedManufacturer = nil
                self.selectedGameType = nil
                self.updateFilterButton()
                self.reloadAll(keepFocus: false)
            }
        }
    }
    
    ///筛选第二级：选择GameType
    private func showGameTypeFilterSheet(manufacturer: Manufacturer) {
        let gameTypes = availableGameTypes
        let options = [R.string.localizable.all()] + gameTypes.map { $0.localizedShortName }
        var selectedIndex = 0
        if let selectedGameType, let index = gameTypes.firstIndex(of: selectedGameType) {
            selectedIndex = index + 1
        }
        
        OptionsSheetView.show(icon: .symbol(.line3HorizontalDecrease),
                              title: manufacturer.title,
                              options: options,
                              selectedIndex: selectedIndex) { [weak self] index in
            guard let self, let index else { return }
            let gameType: GameType? = index == 0 ? nil : gameTypes[index - 1]
            if gameType != self.selectedGameType {
                self.selectedGameType = gameType
                self.reloadAll(keepFocus: false)
            }
            self.updateFilterButton()
        }
    }
    
    private func updateFilterButton() {
        if let selectedGameType {
            filterButton.setGameType(selectedGameType)
        } else if let selectedManufacturer {
            filterButton.setManufacturer(selectedManufacturer)
        } else {
            filterButton.resetDefault()
        }
    }
    
    private func startSearch(text: String) {
        searchString = text.isEmpty ? nil : text
        reloadAll(keepFocus: false)
    }
    
    private func stopSearch() {
        if searchString != nil {
            searchString = nil
            reloadAll(keepFocus: false)
        }
    }
    
    //MARK: - 聚焦信息与背景联动
    
    func updateFocusedGameInfo() {
        guard let game = focusedGame else {
            infoPanelView.isHidden = true
            NotificationCenter.default.post(name: R.NotificationName.LandscapeBackgroundChange,
                                            object: LandscapeBackgroundView.Background.shader(reload: false))
            DispatchQueue.main.async { [weak self] in
                self?.syncCarouselFocusTargets()
            }
            return
        }
        
        infoPanelView.isHidden = false
        
        titleLabel.title = game.displayName
        if let timeAgo = game.latestPlayDate?.timeAgo() {
            subTitleLabel.title = R.string.localizable.readyGameInfoSubTitle(timeAgo, Date.timeDuration(milliseconds: Int(game.totalPlayDuration)))
        } else {
            subTitleLabel.title = R.string.localizable.readyGameInfoNeverPlayed()
        }
        
        updateBackground(for: game)
        DispatchQueue.main.async { [weak self] in
            self?.syncCarouselFocusTargets()
        }
    }
    
    ///聚焦游戏有横幅背景图时展示静态图 否则回落到动态Shader背景
    private func updateBackground(for game: Game) {
        let background: LandscapeBackgroundView.Background
        if let bannerImage = game.bannerImage {
            background = .image(bannerImage, effects: .default)
        } else {
            background = .shader(reload: false)
        }
        NotificationCenter.default.post(name: R.NotificationName.LandscapeBackgroundChange,
                                        object: background)
    }
    
    private func showThemeSheet() {
        ChevronSheetView.show(icon: .symbolImage(R.image.themeRegular_iconSymbols()),
                              title: R.string.localizable.themeSettingTitle(),
                              cellOptions: [
                                .iconTitleChevronCell(icon: .symbolImage(R.image.advance_shader_iconSymbols()),
                                                      title: R.string.localizable.dynamicBackground(),
                                                      chevronTitle: ShaderToy.getUsingShaderToy().title),
                                .iconTitleChevronCell(icon: .symbol(.squareStack),
                                                      title: R.string.localizable.carouselStyle()),
                                .iconTitleChevronCell(icon: .symbol(.musicNote),
                                                      title: R.string.localizable.backgroundMusic(),
                                                      chevronTitle: BackgroundMusicKit.shared.displayName),
                                .iconTitleChevronCell(icon: .symbol(.speakerWave2),
                                                      title: R.string.localizable.soundEffects(),
                                                      chevronTitle: FocusSoundEffects.shared.displayName),
                                .iconTitleChevronCell(icon: .symbolImage(R.image.themeRegular_iconSymbols()),
                                                      title: R.string.localizable.moreSettingTitle()),
                              ], completion: { [weak self] index in
                                  guard let self, let index else { return }
                                  if index == 0 {
                                      self.showDynamicBackgroundSheet()
                                  } else if index == 1 {
                                      self.showCarouselStyleSheet()
                                  } else if index == 2 {
                                      self.showBackgroundMusicSheet()
                                  } else if index == 3 {
                                      self.showSoundEffectsSheet()
                                  } else if index == 4 {
                                      ThemeSettingView.show()
                                  }
                              })
    }
    
    private func showDynamicBackgroundSheet() {
        let usingShaderToy = ShaderToy.getUsingShaderToy()
        var sections = [ASListPage.Section]()
        let buildInShaderToys = ShaderToy.getBuildInShaderToys()
        sections.append(.init(cells: buildInShaderToys.map({
            var isSelected = false
            if usingShaderToy.style == $0.style {
                if usingShaderToy.style == .custom, usingShaderToy.customFileName == $0.customFileName {
                    isSelected = true
                } else if usingShaderToy.style != .custom {
                    isSelected = true
                }
            }
            return .iconTitleDetailRadioCell(icon: $0.icon,
                                             iconSize: R.Size.ButtonSmall,
                                             title: $0.title,
                                             detail: $0.author == nil ? nil : "@\($0.author!)",
                                             isSelected: isSelected)
        }), header: .texts([.smallText(R.string.localizable.dynamicBackgroundDesc(), numberOfLines: 0)], pin: false)))
        
        let customShaderToys = ShaderToy.getCustomShaderToys()
        if customShaderToys.count > 0 {
            sections.append(.init(cells: customShaderToys.map({
                var isSelected = false
                if usingShaderToy.style == $0.style, usingShaderToy.customFileName == $0.customFileName {
                    isSelected = true
                }
                return .iconTitleDetailRadioCell(icon: $0.icon,
                                                 iconSize: R.Size.ButtonSmall,
                                                 title: $0.title,
                                                 isSelected: isSelected)
            })))
        }
        
        let listPage = ASListPage(navigation: .defaultNavigation(title: R.string.localizable.dynamicBackground(),
                                                                 titleIcon: .symbolImage(R.image.advance_shader_iconSymbols())),
                                  sections: sections,
                                  bottom: .large(title: R.string.localizable.addDynamicBackground(),
                                                 titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                                 titleAlignment: .center,
                                                 background: R.Color.Main),
                                  backgroundColor: .clear)
        
        ASSheetView.show(.init(style: .listPage(listPage)), action: { [weak self] action, updation in
            guard let self else { return .dismiss() }
            
            if action.isTapBackground || action.listPageValue?.navigationValue?.isTapClose == true {
                self.showThemeSheet()
                return .dismiss()
            }
            
            if let indexPath = action.listPageValue?.normalItemValue?.indexPath {
                if indexPath.section == 0 {
                    //build in
                    let shaderToy = buildInShaderToys[indexPath.row]
                    Settings.defalut.updateExtra(key: ExtraKey.landscapeShaderToy.rawValue, value: shaderToy.style.rawValue)
                    NotificationCenter.default.post(name: R.NotificationName.LandscapeBackgroundChange,
                                                    object: LandscapeBackgroundView.Background.shader(reload: true))
                } else if indexPath.section == 1 {
                    //custom
                    let shaderToy = customShaderToys[indexPath.row]
                    if let shaderToyFileName = shaderToy.customFileName {
                        Settings.defalut.updateExtra(key: ExtraKey.landscapeShaderToy.rawValue, value: shaderToyFileName)
                        NotificationCenter.default.post(name: R.NotificationName.LandscapeBackgroundChange,
                                                        object: LandscapeBackgroundView.Background.shader(reload: true))
                    }
                }
            } else if action.listPageValue?.isBottom == true {
                //add Shader
                guard let uttype = UTType(filenameExtension: "glsl") else { return .none }
                return .dismiss(completion: { [weak self] in
                    guard let self else { return }
                    FilesImporter.shared.presentImportController(supportedTypes: [uttype], manualHandle: { [weak self] urls in
                        guard let self else { return }
                        urls.forEach({
                            let toUrl = URL(fileURLWithPath: R.Path.Assets.appendingPathComponent($0.lastPathComponent))
                            try? FileManager.safeCopyItem(at: $0, to: toUrl, shouldReplace: true)
                        })
                        self.showDynamicBackgroundSheet()
                    }, cancelHandle: { [weak self] in
                        self?.showDynamicBackgroundSheet()
                    })
                })
            }
            return .dismiss()
        })
        
    }
    
    private func showBackgroundMusicSheet() {
        let builtInTracks = BackgroundMusicKit.shared.builtInTracks
        let customTracks = BackgroundMusicKit.shared.customTracks
        let selectedTitle = BackgroundMusicKit.shared.selectedTitle
        
        func radioCell(for track: BackgroundMusicKit.Track) -> ASListPage.Cell {
            .iconTitleDetailRadioCell(title: track.title,
                                      detail: track.author.isEmpty ? nil : "@\(track.author) · CC0",
                                      isSelected: selectedTitle == track.title)
        }
        
        var sections = [ASListPage.Section]()
        var builtInCells = [ASListPage.Cell]()
        builtInCells.append(.iconTitleDetailRadioCell(title: R.string.localizable.off(),
                                                      isSelected: selectedTitle == nil))
        builtInCells.append(contentsOf: builtInTracks.map { radioCell(for: $0) })
        sections.append(.init(cells: builtInCells,
                              header: .texts([.smallText(R.string.localizable.backgroundMusicDesc(), numberOfLines: 0)], pin: false)))
        if !customTracks.isEmpty {
            sections.append(.init(cells: customTracks.map { radioCell(for: $0) }))
        }
        
        let listPage = ASListPage(navigation: .defaultNavigation(title: R.string.localizable.backgroundMusic(),
                                                                 titleIcon: .symbol(.musicNote)),
                                  sections: sections,
                                  bottom: .large(title: R.string.localizable.addBackgroundMusic(),
                                                 titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                                 titleAlignment: .center,
                                                 background: R.Color.Main),
                                  backgroundColor: .clear)
        
        ASSheetView.show(.init(style: .listPage(listPage)), action: { [weak self] action, _ in
            guard let self else { return .dismiss() }
            
            if action.isTapBackground || action.listPageValue?.navigationValue?.isTapClose == true {
                self.showThemeSheet()
                return .dismiss()
            }
            
            if let indexPath = action.listPageValue?.normalItemValue?.indexPath {
                if indexPath.section == 0 {
                    if indexPath.row == 0 {
                        BackgroundMusicKit.shared.select(title: nil)
                    } else if builtInTracks.indices.contains(indexPath.row - 1) {
                        BackgroundMusicKit.shared.select(title: builtInTracks[indexPath.row - 1].title)
                    }
                } else if indexPath.section == 1, customTracks.indices.contains(indexPath.row) {
                    BackgroundMusicKit.shared.select(title: customTracks[indexPath.row].title)
                }
            } else if action.listPageValue?.isBottom == true {
                return .dismiss(completion: { [weak self] in
                    guard let self else { return }
                    FilesImporter.shared.presentImportController(supportedTypes: BackgroundMusicKit.importTypes, manualHandle: { [weak self] urls in
                        guard let self else { return }
                        try? FileManager.default.createDirectory(atPath: R.Path.Assets, withIntermediateDirectories: true)
                        urls.forEach {
                            let fileName = BackgroundMusicKit.resolvedImportFileName(for: $0)
                            let toUrl = URL(fileURLWithPath: R.Path.Assets.appendingPathComponent(fileName))
                            try? FileManager.safeCopyItem(at: $0, to: toUrl, shouldReplace: true)
                        }
                        self.showBackgroundMusicSheet()
                    }, cancelHandle: { [weak self] in
                        self?.showBackgroundMusicSheet()
                    })
                })
            }
            return .dismiss()
        })
    }
    
    private func showSoundEffectsSheet() {
        let packs = FocusSoundEffects.shared.packs
        let selectedName = FocusSoundEffects.shared.selectedPackName
        var cells = [ASListPage.Cell]()
        cells.append(.iconTitleDetailRadioCell(title: R.string.localizable.off(),
                                               isSelected: selectedName == nil))
        cells.append(contentsOf: packs.map { pack in
            .iconTitleDetailRadioCell(title: pack.name,
                                      detail: FocusSoundEffects.licenseDetail,
                                      isSelected: selectedName == pack.name)
        })
        let listPage = ASListPage(navigation: .defaultNavigation(title: R.string.localizable.soundEffects(),
                                                                 titleIcon: .symbol(.speakerWave2)),
                                  sections: [.init(cells: cells)],
                                  backgroundColor: .clear)
        ASSheetView.show(.init(style: .listPage(listPage)), action: { action, _ in
            if action.listPageValue?.navigationValue?.isTapClose == true {
                return .dismiss()
            }
            guard let indexPath = action.listPageValue?.normalItemValue?.indexPath else {
                return .dismiss()
            }
            if indexPath.row == 0 {
                FocusSoundEffects.shared.select(packName: nil)
            } else if packs.indices.contains(indexPath.row - 1) {
                FocusSoundEffects.shared.select(packName: packs[indexPath.row - 1].name)
            }
            return .dismiss()
        }, dismiss: { [weak self] in
            self?.showThemeSheet()
        })
    }
    
    //MARK: - 主题（轮播样式切换）
    
    private func showCarouselStyleSheet() {
        let scaleLayouts = ScaleTransformViewOptions.Layout.allCases.filter({ $0 != .blur })
        let stackLayouts = StackTransformViewOptions.Layout.allCases.filter({ $0 != .blur })
        let snapshotLayouts = SnapshotTransformViewOptions.Layout.allCases
        let currentStyle = LandscapeCarouselStyle.current
        
        func radioCell(icon: ASIcon, title: String, selected: Bool) -> ASListPage.Cell {
            .normal([
                .icon(icon, iconSize: .fixSize(CGSize(R.Size.ButtonSmall))),
                .title(.largeText(title)),
                .radio(.init(isSelected: selected))
            ])
        }
        
        let sections: [ASListPage.Section] = [
            .init(cells: scaleLayouts.map {
                radioCell(icon: $0.icon,
                          title: LandscapeCarouselStyle.displayTitle(for: $0.rawValue),
                          selected: currentStyle == .scale && LandscapeCarouselStyle.currentScaleLayout == $0)
            }, header: .defaultHeader(title: "Scale")),
            .init(cells: stackLayouts.map {
                radioCell(icon: $0.icon,
                          title: LandscapeCarouselStyle.displayTitle(for: $0.rawValue),
                          selected: currentStyle == .stack && LandscapeCarouselStyle.currentStackLayout == $0)
            }, header: .defaultHeader(title: "Stack")),
            .init(cells: snapshotLayouts.map {
                radioCell(icon: $0.icon,
                          title: LandscapeCarouselStyle.displayTitle(for: $0.rawValue),
                          selected: currentStyle == .snapshot && LandscapeCarouselStyle.currentSnapshotLayout == $0)
            }, header: .defaultHeader(title: "Snapshot"))
        ]
        
        let listPage = ASListPage(navigation: .defaultNavigation(title: R.string.localizable.carouselStyle(),
                                                                 titleIcon: .symbol(.squareStack),
                                                                 tools: [.symbol(.sliderHorizontal3)]),
                                  sections: sections,
                                  backgroundColor: .clear)
        
        ASSheetView.show(.init(style: .listPage(listPage)), action: { [weak self] action, _ in
            guard let self else { return .dismiss() }
            if action.listPageValue?.navigationValue?.isTapClose == true || action.isTapBackground {
                self.showThemeSheet()
                return .dismiss()
            }
            
            if let _ = action.listPageValue?.navigationValue?.tapToolsValue {
                self.showCarouselConfigSheet()
                return .dismiss()
            }
            
            guard let indexPath = action.listPageValue?.normalItemValue?.indexPath else { return .none }
            
            switch indexPath.section {
            case 0:
                let layout = scaleLayouts[indexPath.row]
                guard !(currentStyle == .scale && LandscapeCarouselStyle.currentScaleLayout == layout) else {
                    return .dismiss()
                }
                LandscapeCarouselStyle.select(style: .scale, scaleLayout: layout)
            case 1:
                let layout = stackLayouts[indexPath.row]
                guard !(currentStyle == .stack && LandscapeCarouselStyle.currentStackLayout == layout) else {
                    return .dismiss()
                }
                LandscapeCarouselStyle.select(style: .stack, stackLayout: layout)
            case 2:
                let layout = snapshotLayouts[indexPath.row]
                guard !(currentStyle == .snapshot && LandscapeCarouselStyle.currentSnapshotLayout == layout) else {
                    return .dismiss()
                }
                LandscapeCarouselStyle.select(style: .snapshot, snapshotLayout: layout)
                //Snapshot切片在生成时固化 切换Layout需提升版本强制重建
                LandscapeCarouselStyle.snapshotOptionsVersion += 1
            default:
                return .dismiss()
            }
            
            return .dismiss { [weak self] in
                self?.reloadAll(keepFocus: true)
            }
        })
    }
    
    //MARK: - 配置（轮播样式options调整）
    
    ///配置入口：单层listPage平铺当前样式全部options
    private func showCarouselConfigSheet() {
        let style = LandscapeCarouselStyle.current
        let flatItems = Self.flatCarouselOptionItems(style: style)
        let listPage = makeCarouselOptionsListPage(style: style, flatItems: flatItems)
        
        ASSheetView.show(.init(style: .listPage(listPage),
                               panGestureShouldBegin: { gesture in
            //避免拖动slider时触发sheet下滑关闭
            return !(gesture.view is UISlider)
        }), action: { [weak self] action, updation in
            guard let self else { return .dismiss() }
            
            if action.listPageValue?.navigationValue?.isTapClose == true {
                return .dismiss()
            }
            
            guard let normal = action.listPageValue?.normalItemValue else { return .none }
            let indexPath = normal.indexPath
            
            //最后一节为Reset：清除当前Layout持久化并恢复出厂值
            if indexPath.section >= flatItems.count {
                style.resetOptions()
                self.refreshCarouselForOptionChange()
                let refreshed = Self.flatCarouselOptionItems(style: style)
                updation?(.listPage(self.makeCarouselOptionsListPage(style: style, flatItems: refreshed)))
                return .none
            }
            
            let entry = flatItems[indexPath.section]
            let item = entry.item
            
            //slider / switch 子控件回调
            if let subActions = normal.subActions {
                switch item.kind {
                case .number:
                    if let progress = subActions.extraValue as? Float,
                       let value = item.numberValue(fromProgress: progress) {
                        item.update(number: value)
                        self.refreshCarouselForOptionChange()
                    }
                    return .none
                case .toggle:
                    if let isOn = subActions.extraValue as? Bool {
                        item.update(toggle: isOn)
                        //3D等Enabled开关重新开启会以默认值新建子结构 重放持久化子项
                        style.applyPersistedOptions()
                        self.refreshCarouselForOptionChange()
                    }
                    return .none
                default:
                    return .none
                }
            }
            
            //optionalNumber / selection 保持二级弹窗
            switch item.kind {
            case .optionalNumber:
                return .dismiss { [weak self] in
                    self?.showCarouselOptionalPicker(item: item)
                }
            case .selection(let titles, _, _):
                return .dismiss { [weak self] in
                    self?.showCarouselSelectionSheet(item: item, titles: titles)
                }
            default:
                return .none
            }
        }, dismiss: { [weak self] in
            self?.showCarouselStyleSheet()
        })
    }
    
    ///将分组options展平为「一节一项」并在分组首项附带header标题
    private static func flatCarouselOptionItems(style: LandscapeCarouselStyle) -> [(item: LandscapeCarouselOptionItem, header: String?)] {
        var result = [(item: LandscapeCarouselOptionItem, header: String?)]()
        for section in style.optionSections {
            for (index, item) in section.items.enumerated() {
                result.append((item, index == 0 ? section.title : nil))
            }
        }
        return result
    }
    
    ///构建配置用listPage：number用slider、toggle用switch、其余用chevron二级入口
    private func makeCarouselOptionsListPage(style: LandscapeCarouselStyle,
                                             flatItems: [(item: LandscapeCarouselOptionItem, header: String?)]) -> ASListPage {
        var sections = flatItems.map { entry -> ASListPage.Section in
            let cell: ASListPage.Cell
            let itemLayout: ASViewLayout
            switch entry.item.kind {
            case .number:
                let item = entry.item
                cell = .iconTitleProgressCell(title: item.title,
                                              progress: .init(value: item.numberProgress,
                                                              interaction: .enabled,
                                                              showValue: true,
                                                              valueDisplayFormatter: { item.numberDisplayFormatter($0) }))
                itemLayout = .fixedHeight(R.Size.ItemHeightExtraLarge)
            case .toggle:
                cell = .iconTitleDetailSwitchCell(title: entry.item.title,
                                                  state: entry.item.currentBool ? .on : .off,
                                                  enablePressEffect: false)
                itemLayout = .fixedHeight(R.Size.ItemHeightLarge)
            case .optionalNumber, .selection:
                cell = .iconTitleChevronCell(title: entry.item.title,
                                             chevronTitle: entry.item.displayValue)
                itemLayout = .fixedHeight(R.Size.ItemHeightLarge)
            }
            return .init(cells: [cell],
                         header: entry.header.map { .defaultHeader(title: $0) },
                         itemLayout: itemLayout)
        }
        
        sections.append(.init(cells: [.iconTitleChevronCell(title: "Reset to Default",
                                                            titleColor: R.Color.Red)],
                              header: .defaultHeader(title: "Reset"),
                              itemLayout: .fixedHeight(R.Size.ItemHeightLarge)))
        
        return ASListPage(navigation: .defaultNavigation(title: "\(style.layoutTitle) Options",
                                                         titleIcon: .symbol(.sliderHorizontal3)),
                          sections: sections,
                          backgroundColor: .clear)
    }
    
    ///可空数值配置项的picker 首行None表示不设置
    private func showCarouselOptionalPicker(item: LandscapeCarouselOptionItem) {
        guard case .optionalNumber(let values, _, let decimals, _) = item.kind else { return }
        let datas = ["None"] + values.map { LandscapeCarouselOptionItem.format($0, decimals: decimals) }
        var selectedIndex = 0
        if let currentValue = item.currentOptionalNumber,
           let index = values.firstIndex(where: { abs($0 - currentValue) < 0.00001 }) {
            selectedIndex = index + 1
        }
        
        ASSheetView.show(.init(style: .picker(title: item.title,
                                              datas: datas,
                                              selectedIndex: selectedIndex)),
                         action: { [weak self] action, _ in
            guard let self else { return .dismiss() }
            if let pickerValue = action.pickerValue {
                item.update(optionalNumber: pickerValue.index == 0 ? nil : values[pickerValue.index - 1])
                self.refreshCarouselForOptionChange()
            }
            return .none
        }, dismiss: { [weak self] in
            self?.showCarouselConfigSheet()
        })
    }
    
    ///枚举单选配置项
    private func showCarouselSelectionSheet(item: LandscapeCarouselOptionItem, titles: [String]) {
        OptionsSheetView.show(icon: .symbol(.sliderHorizontal3),
                              title: item.title,
                              options: titles,
                              selectedIndex: item.currentSelectionIndex) { [weak self] index in
            guard let self else { return }
            if let index {
                item.update(selection: index)
                self.refreshCarouselForOptionChange()
            }
            self.showCarouselConfigSheet()
        }
    }
    
    ///配置变化后实时刷新轮播效果
    private func refreshCarouselForOptionChange() {
        if LandscapeCarouselStyle.current == .snapshot {
            //Snapshot的切片在快照生成时固化 需要提升版本号并重建
            LandscapeCarouselStyle.snapshotOptionsVersion += 1
            reloadAll(keepFocus: true)
        } else {
            carouselLayout.invalidateLayoutInBatchUpdate()
        }
    }
    
    //MARK: - Carousel paging & info panel
    
    /// Snapshot keeps system paging. Scale/Stack allow inertial flicks that snap onto a card.
    private func applyCarouselPagingMode() {
        let paging = usesSystemCarouselPaging
        carouselView.isPagingEnabled = paging
        isCarouselUserScrolling = false
        isCarouselSnapping = false
        infoPanelView.alpha = 1
        infoPanelView.isUserInteractionEnabled = true
    }
    
    /// Maps pan velocity (pt/ms) to pages.
    /// Light/normal → 1 page; a mid skip sits between that and a firm flick; hardest → first/last.
    private func carouselFlickSpeed(_ velocityX: CGFloat) -> CGFloat {
        var speed = abs(velocityX)
        // Documented as pt/ms; if a build reports pt/s the values are hundreds+.
        if speed > 20 {
            speed /= 1000
        }
        return speed
    }
    
    private func carouselPagesForVelocity(_ velocityX: CGFloat, pageCount: Int) -> Int {
        let speed = carouselFlickSpeed(velocityX)
        if speed < 0.50 {
            return 0
        }
        if speed < 2.5 {
            return 1
        }
        if speed < 3.0 {
            return 2
        }
        if speed < 3.5 {
            let t = (speed - 3.0) / 0.40
            return min(1 + Int((2.0 * t).rounded()), pageCount)
        }
        if speed < 4.0 {
            let t = (speed - 3.5) / 0.50
            return min(2 + Int((4.0 * t).rounded()), pageCount)
        }
        if speed < 4.50 {
            let t = (speed - 4.0) / 0.60
            return min(4 + Int((8.0 * t).rounded()), pageCount)
        }
        if speed < 5.0 {
            let t = (speed - 4.50) / 0.70
            return min(8 + Int((20.0 * t).rounded()), pageCount)
        }
        return pageCount
    }
    
    private func carouselTargetPage(offset: CGFloat,
                                    proposedOffset: CGFloat,
                                    velocityX: CGFloat,
                                    pageWidth: CGFloat,
                                    pageCount: Int) -> Int {
        guard pageCount > 0, pageWidth > 0 else { return 0 }
        let fractional = offset / pageWidth
        let pages = carouselPagesForVelocity(velocityX, pageCount: pageCount)
        let direction: Int
        if pages == 0 {
            direction = 0
        } else if abs(proposedOffset - offset) > 0.5 {
            direction = proposedOffset > offset ? 1 : -1
        } else {
            // Full-width pages often project ~0; pan-right decreases contentOffset.
            direction = velocityX > 0 ? -1 : 1
        }
        
        let raw: Int
        if direction == 0 {
            raw = Int(fractional.rounded())
        } else if direction > 0 {
            raw = Int(floor(fractional)) + pages
        } else {
            raw = Int(ceil(fractional)) - pages
        }
        return min(max(raw, 0), pageCount - 1)
    }
    
    private func settleCarouselAfterUserScroll() {
        guard isCarouselUserScrolling || isCarouselSnapping else { return }
        isCarouselUserScrolling = false
        isCarouselSnapping = false
        infoPanelView.alpha = 1
        infoPanelView.isUserInteractionEnabled = true
        updateFocusedGameInfo()
        updateInfoPanelPosition()
        syncCarouselFocusTargets()
        transferCarouselCardFocusIfNeeded()
    }
    
    /// Info panel follows the focused cover's bottom edge and stays centered under it.
    private func updateInfoPanelPosition() {
        let index = carouselLayout.currentPage
        guard index >= 0, index < displayGames.count,
              let cell = carouselView.cellForItem(at: IndexPath(item: index, section: 0)) as? GameLandscapeCarouselCell,
              let cardSuperview = cell.cardView.superview else { return }
        
        // cardView.frame is the post-transform bounds; the focused card is near identity.
        let cardFrame = convert(cell.cardView.frame, from: cardSuperview)
        guard cardFrame.width > 0, cardFrame.height > 0 else { return }
        
        let anchor = CGPoint(x: cardFrame.midX, y: cardFrame.maxY + R.Size.ContentSpaceMedium)
        guard anchor != lastPanelAnchor else { return }
        lastPanelAnchor = anchor
        
        infoPanelView.snp.updateConstraints { make in
            make.centerX.equalTo(self.snp.leading).offset(anchor.x)
            make.top.equalTo(self.snp.top).offset(anchor.y)
        }
    }
    // MARK: - Carousel FocusKit

    private var currentCarouselFocusView: UIView? {
        let index = carouselLayout.currentPage
        guard index >= 0,
              carouselView.numberOfItems(inSection: 0) > index,
              let cell = carouselView.cellForItem(at: IndexPath(item: index, section: 0)) as? GameLandscapeCarouselCell else {
            return nil
        }
        return cell.focusContentView
    }

    /// Current cover is the only focusable target. Left/right change pages via the paging layout.
    /// Do not put press/focus lift on `cardView` — the carousel layout owns that transform.
    private func syncCarouselFocusTargets() {
        let current = carouselLayout.currentPage
        for indexPath in carouselView.indexPathsForVisibleItems {
            guard let cell = carouselView.cellForItem(at: indexPath) as? GameLandscapeCarouselCell else { continue }
            let isCurrent = indexPath.item == current
            if cell.enablePressEffect != isCurrent {
                cell.enablePressEffect = isCurrent
            }
            cell.isFocusable = false

            let focusView = cell.focusContentView
            focusView.isFocusable = isCurrent
            if isCurrent {
                bindCarouselCardFocus(focusView)
            } else {
                focusView.focusCommands = []
                focusView.onFocusConfirm = nil
            }
        }
    }

    private func bindCarouselCardFocus(_ cardView: UIView) {
        let moveTitle = R.string.localizable.focusHintMove()
        cardView.focusCommands = [
            FocusCommand(key: .left, title: moveTitle, handler: { [weak self] in
                guard let self else { return true }
                return self.shiftCarouselPage(Locale.isRTLLanguage ? 1 : -1)
            }),
            FocusCommand(key: .right, title: moveTitle, handler: { [weak self] in
                guard let self else { return true }
                return self.shiftCarouselPage(Locale.isRTLLanguage ? -1 : 1)
            })
        ]
        cardView.onFocusConfirm = { [weak self] in
            self?.confirmCurrentCarouselItem()
            return true
        }
    }

    @discardableResult
    private func shiftCarouselPage(_ offset: Int) -> Bool {
        let count = carouselView.numberOfItems(inSection: 0)
        let next = carouselLayout.currentPage + offset
        guard count > 0, next >= 0, next < count else { return false }
        carouselLayout.setCurrentPage(next, animated: true)
        return true
    }

    private func confirmCurrentCarouselItem() {
        let index = max(carouselLayout.currentPage, 0)
        collectionView(carouselView, didSelectItemAt: IndexPath(item: index, section: 0))
    }

    private func transferCarouselCardFocusIfNeeded() {
        guard let focused = FocusSystem.shared.currentFocusedView, isCarouselCard(focused) else { return }
        guard let card = currentCarouselFocusView, card !== focused else { return }
        FocusSystem.shared.focus(card)
    }

    private func isCarouselCard(_ view: UIView) -> Bool {
        var node: UIView? = view
        while let current = node {
            if current is GameLandscapeCarouselCell { return true }
            node = current.superview
        }
        return false
    }
}

//MARK: - UICollectionViewDataSource
extension GameListLandscapeView: UICollectionViewDataSource {
    ///轮播cell的封面尺寸 底部为聚焦信息面板预留空间
    private var carouselCoverHeight: CGFloat {
        if UIDevice.isPhone {
            let carouselHeight = carouselView.bounds.height > 0 ? carouselView.bounds.height : 300
            return max(carouselHeight - GameLandscapeCarouselCell.infoPanelReserve - R.Size.ContentSpaceLarge, 100)
        } else {
            return R.Size.WindowHeight/3
        }
    }
    
    private func sizedCard(ratio: CGFloat) -> CGSize {
        let coverHeight = carouselCoverHeight
        var coverWidth = coverHeight * ratio
        let maxWidth = max(bounds.width * 0.4, 100)
        coverWidth = min(coverWidth, maxWidth)
        return CGSize(width: coverWidth, height: coverHeight)
    }
    
    private func cardSize(for game: Game) -> CGSize {
        sizedCard(ratio: R.Size.GameCoverRatio(gameType: game.effectiveGameType))
    }
    
    private var showsEmptyCard: Bool { displayGames.isEmpty }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return showsEmptyCard ? 1 : displayGames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: LandscapeCarouselStyle.current.cellClass, for: indexPath)
        if showsEmptyCard {
            cell.setEmptyPlaceholder(cardSize: sizedCard(ratio: 0.7))
        } else {
            cell.setData(game: displayGames[indexPath.row], cardSize: cardSize(for: displayGames[indexPath.row]))
        }
        return cell
    }
}

//MARK: - UICollectionViewDelegate
extension GameListLandscapeView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if showsEmptyCard {
            UIDevice.generateHaptic()
            NotificationCenter.default.post(name: R.NotificationName.HomeSelectionChange, object: HomeTabBar.BarSelection.imports)
            return
        }
        // Tap a side card to focus it; tap the focused card to start the game.
        if indexPath.row != carouselLayout.currentPage {
            carouselLayout.setCurrentPage(indexPath.row)
        } else if let game = focusedGame {
            UIDevice.generateHaptic()
            game.handleTapAction()
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === carouselView, !usesSystemCarouselPaging else { return }
        isCarouselUserScrolling = true
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView === carouselView, !usesSystemCarouselPaging, !showsEmptyCard else { return }
        let pageWidth = scrollView.bounds.width
        let pageCount = carouselView.numberOfItems(inSection: 0)
        guard pageWidth > 0, pageCount > 0 else { return }
        
        let targetPage = carouselTargetPage(offset: scrollView.contentOffset.x,
                                            proposedOffset: targetContentOffset.pointee.x,
                                            velocityX: velocity.x,
                                            pageWidth: pageWidth,
                                            pageCount: pageCount)
        let targetX = CGFloat(targetPage) * pageWidth
        let distancePages = abs(scrollView.contentOffset.x - targetX) / pageWidth
        
        // Same settle path as tapping a card: system setContentOffset animation.
        targetContentOffset.pointee = scrollView.contentOffset
        
        if distancePages < 0.002 {
            carouselLayout.setCurrentPage(targetPage, animated: false)
            settleCarouselAfterUserScroll()
            return
        }
        
        isCarouselSnapping = true
        carouselLayout.setCurrentPage(targetPage, animated: true) { [weak self] in
            self?.settleCarouselAfterUserScroll()
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === carouselView, !usesSystemCarouselPaging else { return }
        if !decelerate && !isCarouselSnapping {
            settleCarouselAfterUserScroll()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === carouselView, !usesSystemCarouselPaging else { return }
        if !isCarouselSnapping {
            settleCarouselAfterUserScroll()
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === carouselView, !usesSystemCarouselPaging else { return }
        settleCarouselAfterUserScroll()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === carouselView else { return }
        updateInfoPanelPosition()
    }
}

//MARK: - CollectionViewPagingLayoutDelegate
extension GameListLandscapeView: CollectionViewPagingLayoutDelegate {
    func onCurrentPageChanged(layout: CollectionViewPagingLayout, currentPage: Int) {
        if isCarouselUserScrolling || isCarouselSnapping {
            return
        }
        updateFocusedGameInfo()
        updateInfoPanelPosition()
        syncCarouselFocusTargets()
        transferCarouselCardFocusIfNeeded()
    }
}
