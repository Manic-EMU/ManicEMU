//
//  GameInfoView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift

class GameInfoView: BaseView {
    private lazy var gameCoverView: GameInfoCoverView = {
        let view = GameInfoCoverView(game: game)
        return view
    }()
    
    private lazy var navigationView: GameInfoNavigationView = {
        let view = GameInfoNavigationView()
        view.gameCover.setGameCover(game: game, size: CGSize(R.Size.ItemHeightLarge - R.Size.ContentSpaceSmall*2))
        view.closeButton.didTapButton = { [weak self] in
            guard let self = self else { return }
            UIDevice.generateHaptic()
            self.hide()
        }
        view.toolsView.didTapButton = { [weak self] index in
            guard let self else { return }
            if index == 0 {
                //game info
                if !UserDefaults.standard.bool(forKey: R.DefaultKey.HasShowJumpGameInfoAlert) {
                    UIView.makeAlert(title: R.string.localizable.jumpTips(),
                                     detail: R.string.localizable.thirdPartGameInfoTips(),
                                     cancelTitle: R.string.localizable.gotIt(),
                                     hideAction: { _ in
                        UserDefaults.standard.set(true, forKey: R.DefaultKey.HasShowJumpGameInfoAlert)
                        ASWebView.show(searchGame: self.game)
                    })
                } else {
                    ASWebView.show(searchGame: self.game)
                }
            } else {
                // more
                ChevronSheetView.show(detail: R.string.localizable.metadataDesc(),
                                      stringOptions: [R.string.localizable.checkMetadata()], completion: { [weak self] index in
                    guard let self, let _ = index else { return }
                    GameMetadataView.show(game: self.game)
                })
            }
        }
        return view
    }()
    
    private lazy var gameInfoDetailView: GameInfoDetailView = {
        let view = GameInfoDetailView(game: game)
        let width = UIDevice.isPhone ? R.Size.ApplicationWindowSize.width : (proHUDLayoutStyle() == .landscape ? R.Size.SheetFullScreenForIpadLandscape.width : R.Size.SheetWindowMaxSize.width)
        view.frame = CGRect(origin: .zero,
                            size: CGSize(width: width/(proHUDLayoutStyle() == .landscape ? 2 : 1),
                                         height: gameInfoDetailHeight))
        return view
    }()
    
    private lazy var gameOptionView: GameOptionsView = {
        let view = GameOptionsView(scene: .gameInfo, game: game)
        view.listPageView.listInsets = gameOptionViewInsets
        view.didUpdateContents = { [weak self] listPage in
            guard let self else { return listPage }
            var temp = listPage
            temp.listInsets = self.gameOptionViewInsets
            return temp
        }
        view.didScroll = { [weak self] scrollView in
            guard let self else { return }
            guard self.prefferedLayoutStyle == .portrait else { return }
            let contentOffsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            //Make the gameInfoDetailView pin to the top of the gameOptionView content.
            if contentOffsetY >= scrollView.adjustedContentInset.top - self.gameInfoDetailHeight + R.Size.ContentSpaceSmall {
                self.gameInfoDetailView.y = self.gameOptionView.y
            } else {
                self.gameInfoDetailView.y = self.gameInfoDetailMaxY - contentOffsetY
            }
            
            //During the sliding process, the alpha and background of each view will change accordingly.
            let topInset = scrollView.adjustedContentInset.top
            if contentOffsetY < topInset {
                let alphaProgress = 1 - ((topInset - contentOffsetY)/topInset)
                self.gameCoverView.maskTopView.alpha = alphaProgress < 0 ? 0 : alphaProgress
                //The alpha value below changes later than the one on the cover.
                let navigationChangeOffset = topInset - contentOffsetY
                if  navigationChangeOffset < R.Size.NavigationHeight {
                    let alphaProgress = (R.Size.NavigationHeight - navigationChangeOffset)/R.Size.NavigationHeight
                    self.navigationView.backgroundColor = R.Color.BackgroundPrimary.withAlphaComponent(alphaProgress)
                    self.navigationView.gameCover.alpha = alphaProgress
                    self.gameInfoDetailView.backgroundColor = R.Color.BackgroundPrimary.withAlphaComponent(alphaProgress)
                } else {
                    self.navigationView.backgroundColor = .clear
                    self.navigationView.gameCover.alpha = 0
                    self.gameInfoDetailView.backgroundColor = .clear
                }
            } else {
                self.gameCoverView.maskTopView.alpha = 1
                self.gameInfoDetailView.backgroundColor = R.Color.BackgroundPrimary
            }
        }
        return view
    }()
    
    private let game: Game
    private var gameUpdateToken: NotificationToken? = nil
    private let readyAction: ReadyAction
    private let gameInfoDetailMaxY = 292.0
    private let gameInfoDetailHeight = 162.0
    private var gameOptionViewInsets: UIEdgeInsets {
        .insets(top: proHUDLayoutStyle() == .landscape ? 0 : R.Size.GameInfoGameOptionsTopInsets,
                bottom: R.Size.ContentSpaceLarge)
    }
    private var gameMetadataChange: Any? = nil
    
    enum ReadyAction {
        case `default`, rename
    }
    
    required init?(parameters: Any...) {
        guard parameters.count > 1 else {
            assertionFailure("Incorrect construction parameters! init(scene: GameOption.Scene, game: Game)")
            return nil
        }
        guard let readyAction = parameters[0] as? ReadyAction else {
            return nil
        }
        
        guard let game = parameters[1] as? Game else {
            return nil
        }
        self.game = game
        self.readyAction = readyAction
        super.init(frame: .zero)
        
        addSubviews([gameCoverView, gameOptionView, navigationView, gameInfoDetailView])
        updateViewsConstraints()
        
        gameUpdateToken = game.observe(keyPaths: [\Game.gameCover, \Game.icon, \Game.onlineCoverUrl, \Game.isDeleted], { [weak self] changes in
            guard let self else { return }
            switch changes {
            case .change(_, let properties):
                if properties.contains(where: { $0.name == "isDeleted"} ) {
                    self.hide()
                    return
                }
                
                var image: UIImage? = nil
                if R.Style.GameCoverForceSquare,
                   let imageData = self.game.icon?.storedData() {
                    image = UIImage(data: imageData)
                } else if let imageData = self.game.gameCover?.storedData() {
                    image = UIImage(data: imageData)
                }
                if let image {
                    self.gameCoverView.updateImage(image)
                    self.navigationView.gameCover.image = image.scaled(toSize: CGSize(R.Size.ItemHeightLarge - R.Size.ContentSpaceSmall*2))
                } else if let _ = self.game.onlineCoverUrl {
                    self.game.getCoverImage(completion: { [weak self] image in
                        guard let self else { return }
                        if let image {
                            self.gameCoverView.updateImage(image)
                            self.navigationView.gameCover.image = image.scaled(toSize: CGSize(R.Size.ItemHeightLarge - R.Size.ContentSpaceSmall*2))
                        }
                    })
                } else {
                    let placeHolder = UIImage.placeHolder(preferenceSize: self.gameCoverView.size)
                    self.gameCoverView.updateImage(placeHolder)
                    self.navigationView.gameCover.image = placeHolder.scaled(toSize: CGSize(R.Size.ItemHeightLarge - R.Size.ContentSpaceSmall*2))
                }
            
            case .deleted:
                self.hide()
                
            default:
                break
            }
        })
        
        gameMetadataChange = NotificationCenter.default.addObserver(forName: R.NotificationName.GameMetadataChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                    !R.Style.GameHideRating,
                    let gameId = notification.object as? String else { return }
            if self.game.id == gameId {
                self.gameCoverView.updateRating()
            }
        }
        
        DispatchQueue.main.asyncAfter(delay: 0.35, execute: { [weak self] in
            if readyAction == .rename {
                self?.gameInfoDetailView.beginRename()
            }
        })
        
        let hasQueryMetadata = game.getExtraBool(key: ExtraKey.hasQueryMetadata.rawValue) ?? false
        if !hasQueryMetadata {
            let gameId = game.id
            DispatchQueue.global().async { [weak self] in
                guard let self else { return }
                let realm = Database.realm
                if let tempGame = realm.object(ofType: Game.self, forPrimaryKey: gameId),
                    let data = GameMetadataKit.getGameInfo(game: tempGame) {
                    data.persist(to: tempGame)
                    realm.refresh()
                    //Allow a little grace period for cross-thread data updates.
                    DispatchQueue.main.asyncAfter(delay: 1, execute: { [weak self] in
                        guard let self else { return }
                        self.gameOptionView.reloadOptionsView(games: [self.game])
                    })
                }
            }
        }
    }
    
    convenience init(readyAction: ReadyAction = .default, game: Game) {
        self.init(parameters: readyAction, game)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        gameUpdateToken = nil
        if let gameMetadataChange {
            NotificationCenter.default.removeObserver(gameMetadataChange)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard width > 0 else { return }
        guard let window = hostingWindow else { return }
        if window.size.IsRelativelyWideRectangle {
            gameInfoDetailView.frame = CGRect(origin: CGPoint(x: 0, y: height - gameInfoDetailHeight),
                                              size: CGSize(width: width/2, height: gameInfoDetailHeight))
        } else {
            gameInfoDetailView.frame = CGRect(origin: CGPoint(x: 0, y: gameInfoDetailMaxY), size: CGSize(width: width, height: gameInfoDetailHeight))
        }
    }
    
    func updateViewsConstraints() {
        guard let window = proHUDWindow() else { return }
        if window.size.IsRelativelyWideRectangle {
            gameCoverView.snp.remakeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                make.width.equalToSuperview().multipliedBy(0.5)
            }
            
            gameOptionView.snp.remakeConstraints { make in
                make.bottom.top.trailing.equalToSuperview()
                make.leading.equalTo(gameCoverView.snp.trailing)
            }
            
        } else {
            gameCoverView.snp.remakeConstraints { make in
                make.leading.top.trailing.equalToSuperview()
                make.height.equalTo(378)
            }
            
            gameOptionView.snp.remakeConstraints { make in
                make.top.equalTo(navigationView.snp.bottom)
                make.leading.bottom.trailing.equalToSuperview()
            }
        }
        
        
        navigationView.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(R.Size.NavigationHeight)
        }
    }
}

extension GameInfoView: ShowableView {
    static func show(readyAction: ReadyAction = .default, game: Game) {
        Self.show(parameters: readyAction, game)
    }
    
    func dataForShow(_ defaultData: ASSheet) -> ASSheet {
        var sheetData = defaultData
        sheetData.enableBackgroundDecoration = false
        sheetData.fullScreenForLandscape = true
        return sheetData
    }
    
    func preferredFocusView() -> UIView? {
        return gameInfoDetailView.startGameButton
    }
}

extension GameInfoView: ViewTransition {
    func viewWillTransition() {
        gameOptionView.listPageView.listInsets = gameOptionViewInsets
        gameOptionView.listPageView.collectionView.scrollToTop(animated: false)
        updateViewsConstraints()
        gameCoverView.maskTopView.alpha = 0
        navigationView.backgroundColor = .clear
        navigationView.gameCover.alpha = 0
        gameInfoDetailView.backgroundColor = .clear
        navigationView.closeButton.setBackgroundColor(proHUDLayoutStyle() == .landscape ? R.Color.BackgroundTertiary : R.Color.BackgroundSecondary)
    }
}
