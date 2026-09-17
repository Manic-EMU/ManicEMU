//
//  RetroAchievementListView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class RetroAchievementListView: BaseView {
    private let backgroundImageView: UIImageView = {
        let view = UIImageView(image: R.image.retro_bg())
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    private lazy var collectionView: BlankSlateCollectionView = {
        let view = BlankSlateCollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: RetroAchievementsListCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.contentInset = .insets(top: 90,
                                    bottom: R.Size.ContentInsetBottom)
        let blankView = BlankSlateEmptyView(image: .symbolImage(.gamecontrollerFill).applySymbolConfig(size: 70, color: R.Color.LabelSecondary), title: R.string.localizable.achievementsNotSupport(game.displayName))
        blankView.label.isHidden = true
        view.blankSlateView = blankView
        
        return view
    }()
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation())
        view.didTapClose = { [weak self] in
            guard let self else { return }
            if self.showAsSheet {
                self.hide()
            }
        }
        return view
    }()
    
    private var game: Game
    private var cheevosGame: CheevosGame? = nil
    private var quitGamingNotification: Any? = nil
    private var didClose: (()->Void)? = nil
    
    required init?(parameters: Any...) {
        guard let game = parameters.compactMap({ $0 as? Game }).first else {
            return nil
        }
        self.game = game
        super.init(frame: .zero)
        
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.lessThanOrEqualToSuperview()
            make.trailing.greaterThanOrEqualToSuperview()
            make.centerX.equalToSuperview()
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(R.Size.ItemHeightMedium)
        }
        
        let gamePath = game.romUrl.path
        let didShowLoading: Bool
        if let cached = CheevosBridge.cachedGameInfo(forPath: gamePath) {
            cheevosGame = cached
            collectionView.reloadData()
            didShowLoading = false
        } else {
            UIView.makeLoading()
            didShowLoading = true
        }
        
        CheevosBridge.getCheevosGameInfo(gamePath,
                                         consoleId: game.retroAchievementsConsoleId,
                                         reuseInGameClient: PlayViewController.isGaming) { [weak self] result, cheevosGame in
            guard let self else { return }
            if didShowLoading {
                UIView.hideLoading()
            }
            if let cheevosGame {
                self.cheevosGame = cheevosGame
                self.collectionView.reloadData()
                return
            }
            // Keep a stale cache on screen; only show errors when nothing is available.
            guard self.cheevosGame == nil, let blankView = self.collectionView.blankSlateView as? BlankSlateEmptyView else {
                return
            }
            blankView.label.isHidden = false
            if result == GetGameInfoResult.noLoaded {
                blankView.label.text = R.string.localizable.achievementsNotSupport(self.game.displayName)
            } else if result == GetGameInfoResult.noLogin {
                blankView.label.text = R.string.localizable.achievementsLoginFail()
            } else if result == GetGameInfoResult.serverError {
                blankView.label.text = R.string.localizable.achievementsServerError()
            } else if result == GetGameInfoResult.unknown {
                blankView.label.text = R.string.localizable.errorUnknown()
            }
            
            if let _ = AchievementsUser.getUser(),
               result != GetGameInfoResult.serverError,
               self.game.enableAchievements {
                UIView.makeAlert(detail: R.string.localizable.achievementsDataLoadFail() + "\n" + R.string.localizable.disableAchievementsAlert(),
                                 confirmTitle: R.string.localizable.confirmTitle(),
                                 confirmAction: {
                    if PlayViewController.isGaming {
                        UIView.makeAlert(detail: R.string.localizable.toggleAchievementsAlert(),
                                         confirmTitle: R.string.localizable.confirmTitle(),
                                         confirmAction: {
                            self.game.enableAchievements = false
                            NotificationCenter.default.post(name: R.NotificationName.QuitGaming, object: nil)
                        })
                    } else {
                        self.game.enableAchievements = false
                    }
                })
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let quitGamingNotification {
            NotificationCenter.default.removeObserver(quitGamingNotification)
        }
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(1098)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            
            return section
        }
        return layout
    }
}

extension RetroAchievementListView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cheevosGame == nil ? 0 : 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: RetroAchievementsListCell.self, for: indexPath)
        cell.setDatas(game: game, retroGame: cheevosGame)
        cell.enableSwitchButton.onChange { [weak self] value in
            guard let self else { return }
            if PlayViewController.isGaming {
                UIView.makeAlert(detail: R.string.localizable.toggleAchievementsAlert(),
                                 confirmTitle: R.string.localizable.confirmTitle(),
                                 enableForceHide: false, cancelAction: {
                    self.collectionView.reloadData()
                }, confirmAction: {
                    self.game.enableAchievements = value
                    NotificationCenter.default.post(name: R.NotificationName.QuitGaming, object: nil)
                })
            } else {
                self.game.enableAchievements = value
            }
        }
        cell.hardcoreSwitchButton.onChange { [weak self] value in
            guard let self else { return }
            if PlayViewController.isGaming {
                //游戏中
                if value {
                    //开启硬核
                    if self.game.enableAchievements {
                        //从软核切换到硬核 需要重置游戏
                        UIView.makeAlert(detail: R.string.localizable.toggleHardcoreAlert(),
                                         confirmTitle: R.string.localizable.confirmTitle(),
                                         enableForceHide: false, cancelAction: {
                            self.collectionView.reloadData()
                        }, confirmAction: {
                            self.game.enableHarcore = value
                            NotificationCenter.default.post(name: R.NotificationName.QuitGaming, object: nil)
                        })
                    } else {
                        //未启用RetroAchievements
                        UIView.makeAlert(detail: R.string.localizable.toggleAchievementsAlert(),
                                         confirmTitle: R.string.localizable.confirmTitle(),
                                         enableForceHide: false, cancelAction: {
                            self.collectionView.reloadData()
                        }, confirmAction: {
                            self.game.enableAchievements = value
                            NotificationCenter.default.post(name: R.NotificationName.QuitGaming, object: nil)
                        })
                    }
                } else {
                    //关闭硬核
                    UIView.makeAlert(detail: R.string.localizable.turnOffHardcoreAlert(),
                                     confirmTitle: R.string.localizable.confirmTitle(),
                                     enableForceHide: false, cancelAction: {
                        self.collectionView.reloadData()
                    } ,confirmAction: {
                        self.game.enableHarcore = false
                        NotificationCenter.default.post(name: R.NotificationName.TurnOffHardcore, object: nil)
                    })
                }
            } else {
                self.game.enableHarcore = value
                if !self.game.enableAchievements, value {
                    self.game.enableAchievements = true
                    self.collectionView.reloadData()
                }
            }
        }
        cell.alwaysShowProgressButton.onChange { [weak self] value in
            guard let self else { return }
            self.game.updateExtra(key: ExtraKey.alwaysShowProgress.rawValue, value: value)
            if !value {
                //关闭了进度常驻 则需要发送通知
                NotificationCenter.default.post(name: R.NotificationName.TurnOffAlwaysShowProgress, object: nil)
            }
        }
        return cell
    }
}

extension RetroAchievementListView: ShowableView {
    static func show(game: Game, didClose: (() -> Void)? = nil) {
        let view = Self.show(parameters: game)
        view?.didClose = didClose
    }
    
    func dataForShow(_ defaultData: ASSheet) -> ASSheet {
        var sheet = defaultData
        sheet.enableBackgroundDecoration = false
        sheet.fullScreenForLandscape = true
        return sheet
    }
    
    func didHide() {
        didClose?()
    }
}
