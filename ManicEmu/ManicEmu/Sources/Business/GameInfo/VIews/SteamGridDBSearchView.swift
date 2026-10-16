//
//  SteamGridDBSearchView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/8.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import Kingfisher

class SteamGridDBSearchView: BaseView {
    
    private var apiKey: String
    private let game: Game
    private var preferredAssetType: SteamGridDBContentsView.AssetType = .grids
    private var games = [SteamGridDBGame]()
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        view.didScroll = { [weak self] _ in
            self?.searchInputView.resignFirstResponder()
        }
        return view
    }()
    
    var didSelectImage: ((UIImage?) -> Void)?
    
    private lazy var searchInputView: ASListInputView = {
        var input = ASInput.large(
            text: game.displayName,
            placeholder: R.string.localizable.gamesSearchPlaceHolder(),
            icon: .symbolImage(R.image.searchRegular_iconSymbols())
        )
        input.returnKeyType = .search
        let view = ASListInputView(input)
        view.didTapReturn = { [weak self] searchText in
            guard let self else { return }
            self.searchInputView.resignFirstResponder()
            self.searchGames(text: searchText)
        }
        return view
    }()
    
    private lazy var topView: UIView = {
        let view = UIView()
        view.addSubview(searchInputView)
        searchInputView.snp.makeConstraints { make in
            make.top.equalTo(R.Size.ContentSpaceLarge)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightSmall)
            make.bottom.equalToSuperview().inset(R.Size.ContentSpaceSmall)
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        guard let apiKey = parameters.compactMap({ $0 as? String }).first else { return nil }
        guard let game = parameters.compactMap({ $0 as? Game }).first else { return nil }
        self.apiKey = apiKey
        self.game = game
        if let assetType = parameters.compactMap({ $0 as? SteamGridDBContentsView.AssetType }).first {
            self.preferredAssetType = assetType
        }
        super.init(frame: .zero)

        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if let navigationValue = action.navigationValue {
            if navigationValue.isTapClose {
                self.hide()
            } else if let _ = navigationValue.tapToolsValue {
                LimitedTextInputView.show(icon: .symbolImage(R.image.key_iconSymbols()),
                                          title: "SteamGridDB API Key",
                                          detail: R.string.localizable.steamGridDBAPIKeyDesc() + "\n" + R.string.localizable.steamGridDBAPIKeyAlert(),
                                          limitedType: .normal(maxTextSize: 255), confirmAction: { [weak self] key in
                    guard let self else { return }
                    if let key = key as? String, !key.trimmed.isEmpty {
                        Settings.defalut.updateExtra(key: ExtraKey.steamGridDBAPIKey.rawValue, value: key)
                        self.apiKey = key.trimmed
                    } else {
                        UIView.makeToast(message: R.string.localizable.steamGridDBAPIKeyAlert())
                    }
                })
            }
        } else if let index = action.normalItemValue?.indexPath.section {
            let selectedGame = games[index]
            SteamGridDBContentsView.show(
                sgdbGame: selectedGame,
                game: game,
                apiKey: apiKey,
                preferredAssetType: preferredAssetType,
                didSelectImage: { [weak self] image in
                    guard let self else { return }
                    self.didSelectImage?(image)
                    if self.showAsSheet {
                        self.hide()
                    }
                }
            )
        }
    }
    
    private func searchGames(text: String?) {
        guard let text = text?.trimmed, !text.isEmpty else {
            games = []
            updateContents()
            return
        }
        
        if !PurchaseManager.isMember, !text.isEnglishLanguage() {
            UIView.makeAlert(identifier: R.Strings.PlayPurchaseAlertIdentifier,
                             detail: R.string.localizable.aiCoverSearchDesc(),
                             confirmTitle: R.string.localizable.goToUpgrade(),
                             confirmAutoHide: false,
                             confirmAction: { [weak self] in
                guard let self else { return }
                topViewController(in: self.hostingWindowScene)?.present(PurchaseViewController(), animated: true)
            })
            return
        }
        
        UIView.makeLoading()
        if text.isEnglishLanguage() {
            performSearch(query: text)
        } else {
            OnlineCoverManager.translateGameName(text, gameID: game.id) { [weak self] translated in
                self?.performSearch(query: translated)
            }
        }
    }
    
    private func performSearch(query: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { UIView.hideLoading() }
            do {
                let results = try await SteamGridDBKit.searchGame(apiKey: self.apiKey, query: query)
                self.games = results
                self.updateContents()
                self.listPageView.collectionView.scrollToTop()
            } catch {
                self.games = []
                self.updateContents()
                UIView.makeToast(message: error.localizedDescription)
            }
        }
    }
    
    private func getResultsSections() -> [ASListPage.Section] {
        return games.map { item in
            ASListPage.Section(cells: [.iconTitleDetailChevronCell(
                title: item.name,
                detail: item.listDetailText.isEmpty ? nil : item.listDetailText
            )])
        }
    }
    
    private func getListPage() -> ASListPage {
        return ASListPage(
            navigation: .defaultNavigation(
                title: "SteamGridDB",
                titleIcon: .image(R.image.steamGridDB_icon()),
                tools: [.symbolImage(R.image.key_iconSymbols(), weight: .regular)]
            ),
            top: (topView, .fixedHeight(R.Size.ItemHeightExtraLarge), true),
            sections: games.isEmpty ? [] : getResultsSections(),
            blankSlate: .init(detail: R.string.localizable.noGameCoverResult()),
            backgroundColor: .clear,
            pageInsets: .insets(top: R.Size.SheetGrabberTopInset)
        )
    }
    
    private func updateContents() {
        listPageView.sections = games.isEmpty ? [] : getResultsSections()
        listPageView.blankSlate = .init(title: R.string.localizable.noGameCoverResult())
    }
}

extension SteamGridDBSearchView: ShowableView {
    static func show(apiKey: String,
                     game: Game,
                     preferredAssetType: SteamGridDBContentsView.AssetType = .grids,
                     didSelectImage: ((UIImage?) -> Void)? = nil) {
        let view = Self.show(parameters: apiKey, game, preferredAssetType)
        view?.didSelectImage = didSelectImage
    }
    
    func didShowUp() {
        searchInputView.becomeFirstResponder()
    }
}
