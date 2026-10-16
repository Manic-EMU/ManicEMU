//
//  GameOptionsView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/2.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import RealmSwift

class GameOptionsView: BaseView {
    private let scene: GameOption.Scene
    private var game: Game
    private var games: [Game]
    private var optionGroups: [[GameOption]]
    private var gameUpdateToken: NotificationToken? = nil
    
    private var gameOptionsSortChange: Any? = nil
    private var shortcuts = [GameOption]()
    private var gameShortcutsChange: Any? = nil
    
    private var shouldHideBlock: ((GameOption) -> Bool)? = nil
    @discardableResult
    func shouldHide(_ block: ((GameOption) -> Bool)? = nil) -> Self {
        shouldHideBlock = block
        return self
    }
    
    private var alreadyHide: Bool = false
    private var hideCompletionBlock: ((GameOption?) -> Void)? = nil
    @discardableResult
    func hideCompletion(_ block: ((GameOption?) -> Void)? = nil) -> Self {
        hideCompletionBlock = block
        return self
    }
    
    var didUpdateContents: ((ASListPage) -> ASListPage)? = nil
    
    var didScroll: ((UIScrollView)->Void)? = nil
    
    private var metadataExistInGameInfo: Bool = false
    private var gameMetadataChange: Any? = nil
    
    lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            self.handleAction(action)
        }
        view.didScroll = { [weak self] in
            guard let self else { return }
            self.didScroll?($0)
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        guard parameters.count > 1 else {
            assertionFailure("Incorrect construction parameters! init(scene: GameOption.Scene, games: [Game])")
            return nil
        }
        guard let scene = parameters[0] as? GameOption.Scene else {
            return nil
        }
        self.scene = scene
        var games = [Game]()
        if let parameters = Array(parameters[1...]) as? [[Game]] {
            games = parameters.flatMap({ $0 })
        } else if let parameters = Array(parameters[1...]) as? [Game] {
            games = parameters
        }
        guard games.count > 0 else { return nil }
        self.game = games.first!
        self.games = games
        self.optionGroups = GameOption.groupAndSortOptions(GameOption.availableOptions(games: games, scene: scene))
        super.init(frame: .zero)
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if games.count == 1 {
            gameUpdateToken = self.game.observe(keyPaths: [\Game.aliasName], { [weak self] changes in
                guard let self else { return }
                switch changes {
                case .change(_, let properties):
                    for propertie in properties {
                        if propertie.name == "aliasName", var navigation = self.listPageView.navigation {
                            navigation.title = .init(attributes: .init(text: self.game.displayName,
                                                                       font: R.Font.Headline(emphasis: true)))
                            self.listPageView.navigation = navigation
                        }
                    }
                    
                default:
                    break
                }
            })
        }
        
        if scene == .gaming {
            gameShortcutsChange = NotificationCenter.default.addObserver(forName: R.NotificationName.ShortcutsChange, object: nil, queue: .main) { [weak self] notification in
                guard let self else { return }
                self.listPageView.navigation = self.getNavigation()
            }
        }
        
        gameOptionsSortChange = NotificationCenter.default.addObserver(forName: R.NotificationName.GameOptionsSortChange, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            self.updateContents()
        }
        
        if scene == .gameInfo {
            gameMetadataChange = NotificationCenter.default.addObserver(forName: R.NotificationName.GameMetadataChange, object: nil, queue: .main) { [weak self] notification in
                guard let self, let gameId = notification.object as? String else { return }
                if self.game.id == gameId {
                    self.updateContents()
                }
            }
        }
    }
    
    convenience init(scene: GameOption.Scene, game: Game) {
        self.init(parameters: scene, game)!
    }
    
    convenience init(scene: GameOption.Scene, games: [Game]) {
        self.init(parameters: scene, games)!
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        gameUpdateToken = nil
        if let gameShortcutsChange {
            NotificationCenter.default.removeObserver(gameShortcutsChange)
        }
        if let gameOptionsSortChange {
            NotificationCenter.default.removeObserver(gameOptionsSortChange)
        }
        if let gameMetadataChange {
            NotificationCenter.default.removeObserver(gameMetadataChange)
        }
    }
    
    private func getCells() -> [[ASListPage.Cell]] {
        return optionGroups.compactMap({ options in
            return options.map({ getCell(option: $0) })
        })
    }
    
    private func getCell(option: GameOption) -> ASListPage.Cell {
        let accessory = option.accessory(for: games)
        let detail: String?
        if case .chevron = accessory {
            detail = nil
        } else {
            detail = option.detail
        }
        
        if let chevronValue = accessory.chevronValue {
            return ASListPage.Cell.iconTitleDetailChevronCell(icon: option.icon,
                                                              title: option.title,
                                                              titleColor: (option == .delete || option == .quit) ? R.Color.Red : R.Color.LabelPrimary,
                                                              detail: detail,
                                                              chevronTitle: chevronValue.string)
            
        } else if let switchValue = accessory.switchValue {
            return ASListPage.Cell.iconTitleDetailSwitchCell(icon: option.icon,
                                                             title: option.title,
                                                             detail: detail,
                                                             state: switchValue,
                                                             enablePressEffect: false)
            
            
        } else if let imageValue = accessory.imageValue {
            return ASListPage.Cell.iconTitleImageChevronCell(icon: option.icon,
                                                             title: option.title,
                                                             image: imageValue)
        }
        
        return ASListPage.Cell.iconTitleDetailChevronCell(icon: option.icon,
                                                          title: option.title,
                                                          detail: detail)
    }
    
    private func getNavigation() -> ASListPage.Navigation? {
        guard scene == .gaming else { return nil }
        shortcuts = Prefference.defalut.getPrefference(kind: .gameShortcut,
                                                       storeKey: .game(gameId: game.id),
                                                       bestEfforts: true)?.gameShortcutValue ?? GameOption.defaultShortcutOptions(for: game)
        let availableOptions = Set(GameOption.availableOptions(game: game, scene: .gaming))
        shortcuts = shortcuts.filter({ availableOptions.contains($0) })
        
        let tools = shortcuts.map({ $0.icon })
        let navigation = ASListPage.Navigation.defaultNavigation(title: "MENU",
                                                                 tools: tools)
        return navigation
    }
    
    private func getListPage() -> ASListPage {
        switch scene {
        case .common:
            var listPage = ASListPage.simpleList(icon: .symbolImage(R.image.settings_iconSymbols()),
                                                 title: games.count > 1 ? R.string.localizable.gameSettings() : (game.displayName),
                                                 options: getCells())
            listPage.pageInsets = .insets(top: R.Size.SheetGrabberTopInset)
            return listPage
            
        case .gameInfo:
            var sections = getCells().map({ ASListPage.Section(cells: $0)})
            var metadata: GameMetadata? = nil
            if let data = GameMetadata.getGameMetadata(game: game) {
                metadata = data
            }
            
            if let metadata, !metadata.overview.isEmpty {
                let metadataView = GameMetadataView(overview: metadata.overview)
                metadataView.didTapMoreMetadata = { [weak self] in
                    guard let self else { return }
                    GameMetadataView.show(game: self.game)
                }
                sections.insert(.init(cells: [.custom(metadataView)],
                                      itemLayout: .autoLayout),
                                at: 0)
            }
            return ASListPage(sections: sections,
                              backgroundColor: .clear)
            
        case .gaming:
            return ASListPage(navigation: getNavigation(),
                              sections: getCells().map({ ASListPage.Section(cells: $0)}),
                              backgroundColor: .clear,
                              pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
        }
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if let normalItemValue = action.normalItemValue {
            let indexPath = normalItemValue.indexPath
            var groupIndex = indexPath
            if scene == .gameInfo,
               let overview = GameMetadata.getGameMetadata(game: game)?.overview,
               !overview.isEmpty {
                groupIndex = IndexPath(row: indexPath.row, section: indexPath.section - 1)
            }
            
            let option = optionGroups[groupIndex.section][groupIndex.row]
            
            let shouldHide = shouldHideBlock?(option) ?? false
            option.performAction(with: games,
                                 in: hostingWindowScene,
                                 accessoryChange: { [weak self] in
                guard let self, !shouldHide else { return }
                self.listPageView.updateCellData(self.getCell(option: option), indexPath: indexPath)
            }, reloadAll: { [weak self] in
                guard let self, !shouldHide else { return }
                self.updateContents()
            })
            if shouldHide {
                if showAsSheet {
                    alreadyHide = true
                    hide()
                    hideCompletionBlock?(option)
                }
            }
        } else if let navigationValue = action.navigationValue {
            if navigationValue.isTapClose {
                if showAsSheet {
                    hide()
                }
            } else if let index = navigationValue.tapToolsValue {
                if shortcuts.count > index {
                    shortcuts[index].performAction(with: games, in: hostingWindowScene)
                }
            }
        }
    }
    
    func reloadOptionsView(games: [Game]) {
        guard games.count > 0 else { return }
        self.game = games.first!
        self.games = games
        updateContents()
    }
    
    func updateContents() {
        optionGroups = GameOption.groupAndSortOptions(GameOption.availableOptions(games: games, scene: scene))
        if let didUpdateContents {
            listPageView.updatePage(didUpdateContents(getListPage()))
        } else {
            listPageView.updatePage(getListPage())
        }
    }
}

extension GameOptionsView: ShowableView {
    ///Expected menu height when displaying the game Option View
    static var MaxHeightForGaming: CGFloat? = nil
    
    static func show(scene: GameOption.Scene,
                     games: [Game],
                     shouldHide: ((GameOption) -> Bool)? = nil,
                     hideCompletion: ((GameOption?) -> Void)? = nil) {
        Self.show(parameters: scene, games)?.shouldHide(shouldHide).hideCompletion(hideCompletion)
    }
    
    func didHide() {
        if !alreadyHide {
            hideCompletionBlock?(nil)
        }
    }
    
    var prefferdConstraintHeight: CGFloat? {
        if scene == .gaming,
           UIDevice.isPhone,
           proHUDLayoutStyle() == .portrait,
           PlayViewController.menuInsets == nil {
            return Self.MaxHeightForGaming ?? R.Size.SheetWindowMaxSize.height
        } else if scene == .common {
            var height = R.Size.SheetGrabberTopInset + R.Size.NavigationHeight
            optionGroups.forEach({ options in
                height += R.Size.ContentSpaceLarge
                height += options.reduce(0.0, { result, _ in result + R.Size.ItemHeightLarge })
            })
            height += R.Size.ContentSpaceLarge
            height += R.Size.ContentInsetBottom(window: hostingWindow)
            return height
        }
        return R.Size.SheetWindowMaxSize.height
    }
}
