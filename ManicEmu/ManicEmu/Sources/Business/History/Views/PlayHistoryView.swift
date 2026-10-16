//
//  PlayHistoryView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import RealmSwift
import UniformTypeIdentifiers
import VisualEffectView

class PlayHistoryView: BaseView {
    
    private lazy var navigationView: ASNavigationView = {
        var navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.historyHeaderTitle())
        navigation.enableClose = !asSideMenu
        let view = ASNavigationView(navigation)
        view.didTapClose = { [weak self] in
            guard let self else { return }
            if self.showAsSheet {
                self.hide()
            } else {
                self.needToHideSideMenu?()
            }
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = BlankSlateCollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: PlayHistoryFavouriteCollectionCell.self)
        view.register(cellWithClass: PlayHistoryItemCollectionCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.contentInset = .insets(top: R.Size.ContentSpaceSmall,
                                    bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        view.blankSlateView = PlayHistoryBlankSlateView(tapAction: { [weak self] type in
            guard let self = self else { return }
            if type == .importGame {
                FilesImporter.shared.presentImportController(supportedTypes: UTType.gameTypes, in: self.hostingWindowScene)
            } else if type == .startGame {
                if self.showAsSheet {
                    self.hide()
                } else {
                    self.needToHideSideMenu?()
                }
            }
        })
        return view
    }()
    
    
    private var histories: [Game] = []
    private var favouriteGame: Game? = nil
    var needToHideSideMenu: (()->Void)? = nil
    var didTapGame:((Game)->Void)? = nil
    private let asSideMenu: Bool
    
    required init?(parameters: Any...) {
        self.asSideMenu = parameters.compactMap({ $0 as? Bool }).first ?? false
        super.init(frame: CGRect(origin: .zero, size: R.Size.ApplicationWindowSize))
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(R.Size.SheetGrabberTopInset)
            make.leading.trailing.equalTo(self.safeAreaLayoutGuide)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }
        
        updateGames()
    }
    
    convenience init(asSideMenu: Bool) {
        self.init(parameters: asSideMenu)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout  { sectionIndex, env in
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                              heightDimension: .absolute(sectionIndex == 0 ? 238*(UIDevice.isPad ? 0.8 : 1) : 64)),
                                                           subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: R.Size.ContentSpaceLarge, bottom: 0, trailing: R.Size.ContentSpaceLarge)
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = R.Size.ContentSpaceLarge
            section.contentInsets = NSDirectionalEdgeInsets(top: R.Size.ContentSpaceSmall,
                                                            leading: 0,
                                                            bottom: 0,
                                                            trailing: 0)
            return section
            
        }
        return layout
    }
    
    private var gamesUpdateToken: NotificationToken? = nil
    private func updateGames() {
        let realm = Database.realm
        let games = realm.objects(Game.self).where { $0.totalPlayDuration > 0 && !$0.isDeleted }
        //监听数据的变化
        gamesUpdateToken = games.observe(keyPaths: [
            \Game.aliasName,
             \Game.gameCover,
             \Game.onlineCoverUrl,
             \Game.latestPlayDate,
             \Game.latestPlayDuration,
             \Game.totalPlayDuration
        ]) { [weak self] changes in
            guard let self = self else { return }
            if case .update(_, let deletes, let insertions, let modifications) = changes {
                if !deletes.isEmpty || !insertions.isEmpty || !modifications.isEmpty {
                    Log.debug("游戏历史 游戏更新")
                    //刷新视图
                    self.updateDatas(games: games)
                }
            }
        }
        updateDatas(games: games)
    }
    
    ///构造符合UI展示的数据源
    private func updateDatas(games: Results<Game>) {
        let datas = games.sorted {
            if let date1 = $0.latestPlayDate, let date2 = $1.latestPlayDate {
                return date1 > date2
            }
            return true
        }
        histories = datas
        favouriteGame = games.sorted(by: { $0.totalPlayDuration > $1.totalPlayDuration }).first
        collectionView.reloadData()
    }
    
}

extension PlayHistoryView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return favouriteGame == nil ? 0 : 1
        } else {
            return histories.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: PlayHistoryFavouriteCollectionCell.self, for: indexPath)
            cell.setData(game: favouriteGame!)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: PlayHistoryItemCollectionCell.self, for: indexPath)
            let game = histories[indexPath.row]
            cell.setData(game: game)
            return cell
        }
    }
}

extension PlayHistoryView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let game = indexPath.section == 0 ? favouriteGame : histories[indexPath.row] {
            didTapGame?(game)
        }
    }
}

extension PlayHistoryView: ShowableView {
    
}
