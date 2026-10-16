//
//  LibretroCoverSearchView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import Kingfisher

class LibretroCoverSearchView: BaseView {
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation(title: R.string.localizable.searchCover(),
                                                       titleIcon: .image(R.image.libretro_icon())))
        view.didTapClose = { [weak self] in
            guard let self = self else { return }
            if self.showAsSheet {
                self.hide()
            }
            self.didTapClose?()
        }
        return view
    }()
    
    private lazy var searchView: ASListInputView = {
        var input = ASInput.large(text: game.displayName,
                                  placeholder: R.string.localizable.gamesSearchPlaceHolder(),
                                  icon: .symbolImage(R.image.searchRegular_iconSymbols()))
        input.returnKeyType = .search
        let view = ASListInputView(input)
        view.didTapReturn = { [weak self] searchText in
            guard let self else { return }
            self.searchView.resignFirstResponder()
            if let text = searchText?.trimmed,
                !PurchaseManager.isMember,
                !text.isEnglishLanguage() {
                UIView.makeAlert(identifier: R.Strings.PlayPurchaseAlertIdentifier,
                                 detail: R.string.localizable.aiCoverSearchDesc(),
                                 confirmTitle: R.string.localizable.goToUpgrade(),
                                 confirmAutoHide: false,
                                 confirmAction: { [weak self] in
                    guard let self else { return }
                    topViewController(in: self.hostingWindowScene)?.present(PurchaseViewController(), animated: true)
                })
            } else {
                self.searchCover(text: searchText)
            }
        }
        return view
    }()
    
    lazy var collectionView: BlankSlateCollectionView = {
        let view = BlankSlateCollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: GameCollectionViewCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.allowsMultipleSelection = true
        view.contentInset = .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        view.blankSlateView = BlankSlateEmptyView(title: R.string.localizable.noGameCoverResult())
        return view
    }()

    private var datas = [Game]()
    
    private var coverSizes = [GameType: CGSize]()
    
    ///点击关闭按钮回调
    var didTapClose: (()->Void)? = nil
    
    var didSelectIamge: ((UIImage?)->Void)? = nil
    
    var game: Game
    
    required init?(parameters: Any...) {
        guard let game = parameters.first as? Game else { return nil }
        self.game = game
        super.init(frame: .zero)
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightSmall)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
    
    convenience init(game: Game) {
        self.init(parameters: game)!
    }
    
    private func searchCover(text: String?) {
        if let text = text?.trimmed {
            UIView.makeLoading()
            let gameType = game.effectiveGameType
            let id = game.id
            let fileExtension = game.fileExtension
            DispatchQueue.global().async { [weak self] in
                guard let self else { return }
                OnlineCoverManager.MatchOperation.searchCovers(coverMatch: OnlineCoverManager.CoverMatch(gameType: gameType,
                                                                                                         gameID: id,
                                                                                                         gameName: text,
                                                                                                         fileExtension: fileExtension),
                                                               persistentedTranslation: false,
                                                               isCallBackMain: true, completion: { [weak self] urls, _ in
                    UIView.hideLoading()
                    guard let self = self else { return }
                    let games = urls.map {
                        let game = Game()
                        game.name = $0.lastPathComponent.deletingPathExtension
                        game.gameType = gameType
                        game.fileExtension = fileExtension
                        game.onlineCoverUrl = $0.absoluteString
                        return game
                    }
                    
                    self.datas = games
                    self.collectionView.reloadData()
                    self.collectionView.scrollToTop()
                })
            }
        } else {
            self.datas = []
            self.collectionView.reloadData()
            self.collectionView.scrollToTop()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout  { [weak self] sectionIndex, env in
            guard let self = self else { return nil }
            //section的边距
            let sectionInset = R.Size.ContentSpaceHuge
            let itemSpacing = R.Size.ContentSpaceLarge - R.Size.GamesListSelectionEdge*2
            let column = 3.0
            let widthDimension: NSCollectionLayoutDimension = .fractionalWidth(1/column)
            //item布局
            let totleSpacing = (R.Size.ContentSpaceHuge-R.Size.GamesListSelectionEdge)*2 + itemSpacing*(column-1)//横向间距总和
            let itemEstimatedWidth = (env.container.contentSize.width - totleSpacing)/column //一个item的宽
            let coverWidth = itemEstimatedWidth-R.Size.GamesListSelectionEdge*2
            let coverHeight = (itemEstimatedWidth-R.Size.GamesListSelectionEdge*2)/R.Size.GameCoverRatio(gameType: self.game.gameType) //书籍封面的高度
            //一个item的高度 = 间距 + 封面高度 + 间距 + title高度 + 间距 + subtitle高度 + 间距
            let itemEstimatedHeight = R.Size.GamesListSelectionEdge + coverHeight + R.Size.ContentSpaceSmall + R.Font.Footnote().lineHeight + R.Size.GamesListSelectionEdge
            let coverSize = CGSize(width: coverWidth, height: coverHeight)
            if let size =  self.coverSizes[self.game.gameType] {
                //尺寸存在
                if size != coverSize {
                    self.coverSizes[self.game.gameType] = coverSize
                }
            } else {
                //尺寸不存在
                self.coverSizes[self.game.gameType] = coverSize
            }
            
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: widthDimension,
                                                                                 heightDimension: .absolute(itemEstimatedHeight)))
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                              heightDimension: .absolute(itemEstimatedHeight)),
                                                           subitem: item, count: Int(column))
            group.interItemSpacing = NSCollectionLayoutSpacing.fixed(itemSpacing)
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                          leading: sectionInset-R.Size.GamesListSelectionEdge,
                                                          bottom: 0,
                                                          trailing: sectionInset-R.Size.GamesListSelectionEdge)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = itemSpacing
            section.contentInsets = NSDirectionalEdgeInsets(top: R.Size.ContentSpaceTiny,
                                                            leading: 0,
                                                            bottom: 0,
                                                            trailing: 0)
            return section
            
        }
        return layout
    }
}

extension LibretroCoverSearchView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return datas.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: GameCollectionViewCell.self, for: indexPath)
        let game = datas[indexPath.row]
        cell.setData(game: game, coverSize: coverSizes[game.gameType] ?? .zero, indexPath: indexPath)
        return cell
    }
}

extension LibretroCoverSearchView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let game = self.datas[indexPath.row]
        if let url = URL(string: game.onlineCoverUrl) {
            let scene = hostingWindowScene
            KingfisherManager.shared.retrieveImage(with: url) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let imageResult):
                    ImageFetcher.edit(image: imageResult.image, in: scene) { [weak self] image in
                        guard let self = self else { return }
                        Task { @MainActor in
                            self.didSelectIamge?(image)
                            if self.showAsSheet {
                                self.hide()
                            }
                            self.didTapClose?()
                        }
                    }
                case .failure(_):
                    Task { @MainActor in
                        UIView.makeToast(message: R.string.localizable.onlineCoverFetchFailed())
                    }
                }
            }
        } else {
            UIView.makeToast(message: R.string.localizable.onlineCoverFetchFailed())
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        searchView.resignFirstResponder()
    }
}

extension LibretroCoverSearchView: ShowableView {
    func didShowUp() {
        searchView.becomeFirstResponder()
    }
}

extension LibretroCoverSearchView: ViewTransition {
    func viewWillTransition() {
        collectionView.reloadData()
    }
}
