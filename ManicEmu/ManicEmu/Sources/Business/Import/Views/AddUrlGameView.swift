//
//  AddUrlGameView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/14.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import RealmSwift
import IceCream

class AddUrlGameView: BaseView {
    
    private enum FormSection: Int {
        case name = 0
        case platform
        case url
    }
    
    private let selectableGameTypes = System.allGameTypes
    private var selectedGameType: GameType
    private var nameText = ""
    private var urlText = ""
    private let editingGame: Game?
    private var coverRemoved = false
    
    private let draftGame: Game = {
        let game = Game()
        game.id = UUID().uuidString
        game.fileExtension = Game.urlGameFileExtension
        game.gameType = .gba
        return game
    }()
    
    private lazy var coverHost: UrlGameCoverSlotView = {
        let view = UrlGameCoverSlotView()
        view.didTapEdit = { [weak self] in
            self?.pickCover()
        }
        view.apply(gameType: selectedGameType, image: nil)
        return view
    }()
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(makeListPage())
        view.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        let unpacked: [Any]
        if let nested = parameters.first as? [Any], parameters.count == 1 {
            unpacked = nested
        } else {
            unpacked = Array(parameters)
        }
        let game = unpacked.compactMap({ $0 as? Game }).first
        self.editingGame = game
        if let game {
            self.nameText = game.displayName
            self.urlText = game.urlGameLaunchURL
            self.selectedGameType = game.gameType
        } else {
            self.selectedGameType = System.allGameTypes.first ?? ._3ds
        }
        super.init(frame: .zero)
        
        draftGame.name = nameText
        draftGame.gameType = selectedGameType
        if let game {
            draftGame.id = game.id
        }
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if let game {
            if let data = game.gameCover?.storedData(), let image = UIImage(data: data) {
                coverHost.apply(gameType: selectedGameType, image: image)
            } else {
                coverHost.apply(gameType: selectedGameType, image: nil, previewGame: game)
            }
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func coverSize(for gameType: GameType) -> CGSize {
        let size = CGSize(UIDevice.isPhone ? 180 : 160)
        let ratio = R.Size.GameCoverRatio(gameType: gameType)
        if ratio == 1 {
            return size
        } else if ratio < 1 {
            return CGSize(width: size.height * ratio, height: size.height)
        }
        return CGSize(width: size.width, height: size.width / max(ratio, 0.01))
    }
    
    private func coverHostHeight(for gameType: GameType) -> CGFloat {
        coverSize(for: gameType).height + R.Size.ContentSpaceLarge * 2
    }
    
    private func makeNameInput() -> ASInput {
        var input = ASInput.large(text: nameText,
                                  placeholder: R.string.localizable.addUrlGameNamePlaceholder())
        input.returnKeyType = .next
        input.autocapitalizationType = .words
        return input
    }
    
    private func makeURLInput() -> ASInput {
        var input = ASInput.large(text: urlText,
                                  placeholder: "delta://game/...")
        input.keyboardType = .URL
        input.returnKeyType = .done
        input.autocapitalizationType = .none
        input.autocorrectionType = .no
        return input
    }
    
    private func gameTypeTitle(_ gameType: GameType) -> String {
        R.Style.GamesGroupTitleStyle == .fullName ? gameType.localizedName : gameType.localizedShortName
    }
    
    private func gameTypeBrandIcon(_ gameType: GameType) -> (ASIcon, ASListPage.Cell.Style.IconSize) {
        if let image = gameType.brandImage {
            return (.image(image), .fixHeight(gameType == .lynx ? 16 : 20))
        }
        return (.symbolImage(R.image.category_iconSymbols()), .fixSize(CGSize(R.Size.ButtonExtraExtraSmall)))
    }
    
    private func gameTypeContentStyles(_ gameType: GameType) -> [ASListPage.Cell.Style] {
        if R.Style.GamesGroupTitleStyle == .brand {
            let (icon, iconSize) = gameTypeBrandIcon(gameType)
            return [.icon(icon, iconSize: iconSize)]
        }
        return [.title(.largeText(gameTypeTitle(gameType)))]
    }
    
    private func makePlatformCell() -> ASListPage.Cell {
        var styles = gameTypeContentStyles(selectedGameType)
        styles.append(.chevron(.init()))
        return .normal(styles)
    }
    
    private func makeListPage() -> ASListPage {
        ASListPage(navigation: .defaultNavigation(title: editingGame == nil
                                                  ? R.string.localizable.addGameLink()
                                                  : R.string.localizable.editLink(),
                                                  titleIcon: .symbolImage(R.image.link_iconSymbols()),
                                                  tools: [.symbolImage(R.image.faq_iconSymbols())]),
                   top: (coverHost, .fixedHeight(coverHostHeight(for: selectedGameType)), false),
                   sections: [
                    .init(cells: [.input(makeNameInput())],
                          header: .defaultHeader(title: R.string.localizable.addUrlGameName()),
                          decoration: .init(style: .primary)),
                    .init(cells: [makePlatformCell()],
                          header: .defaultHeader(title: R.string.localizable.addUrlGamePlatform()),
                          decoration: .init(style: .primary)),
                    .init(cells: [.input(makeURLInput())],
                          header: .defaultHeader(title: R.string.localizable.addUrlGameUrl()),
                          decoration: .init(style: .primary))
                   ],
                   bottom: makeBottom(isValid: isFormFilled),
                   backgroundColor: .clear,
                   pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
    }
    
    private var isFormFilled: Bool {
        !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func makeBottom(isValid: Bool) -> ASButton {
        var button = ASButton.large(title: editingGame == nil
                                    ? R.string.localizable.addUrlGameAdd()
                                    : R.string.localizable.saveTitle(),
                                    titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                    titleAlignment: .center,
                                    background: R.Color.Main)
        var disableAttributes = button.allAttributes[.normal]!
        disableAttributes.background = R.Color.BackgroundSecondary
        disableAttributes.title?.attributes?.color = R.Color.LabelTertiary
        button.allAttributes[.disabled] = disableAttributes
        button.state = isValid ? .normal : .disabled
        return button
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if let inputValue = action.inputValue {
            switch inputValue.action {
            case .textChange(let text):
                if inputValue.indexPath.section == FormSection.name.rawValue {
                    nameText = text ?? ""
                    draftGame.name = nameText
                } else if inputValue.indexPath.section == FormSection.url.rawValue {
                    urlText = text ?? ""
                }
                listPageView.bottom = makeBottom(isValid: isFormFilled)
                
            case .tapReturn(_):
                let isLast = inputValue.indexPath.section == FormSection.url.rawValue
                if isLast {
                    listPageView.collectionView.endEditing(true)
                } else if let cell = listPageView.collectionView.cellForItem(at: IndexPath(row: 0, section: FormSection.url.rawValue)) as? ASListInputCollectionCell {
                    cell.becomeFirstResponder()
                }
                
            default:
                break
            }
            return
        }
        
        if let indexPath = action.normalItemValue?.indexPath,
           indexPath.section == FormSection.platform.rawValue {
            showPlatformPicker()
            return
        }
        
        if action.isBottom {
            listPageView.collectionView.endEditing(true)
            addGame()
            return
        }
        
        if action.navigationValue?.isTapClose == true {
            hide()
            return
        }
        
        if action.navigationValue?.tapToolsValue != nil {
            let desc = EmulatorInteractionKit.supportedLaunchers.reduce("") { result, launcher in
                result + (result.isEmpty ? "" : "   ") + "\(launcher.name)(\(launcher.scheme))"
            }
            UIView.makeAlert(detail: R.string.localizable.addGameLinkDesc(desc),
                             cancelTitle: R.string.localizable.gotIt())
        }
    }
    
    private func showPlatformPicker() {
        let cells = selectableGameTypes.map { gameType -> ASListPage.Cell in
            var styles = gameTypeContentStyles(gameType)
            styles.append(.radio(.init(isSelected: gameType == selectedGameType)))
            return .normal(styles)
        }
        ASSheetView.show(.init(style: .simpleList(icon: .symbolImage(R.image.category_iconSymbols()),
                                                  title: R.string.localizable.changeGameType(),
                                                  options: [cells])),
                         action: { [weak self] sheetAction, _ in
            guard let self else { return .dismiss() }
            if let indexPath = sheetAction.listPageValue?.normalItemValue?.indexPath,
               self.selectableGameTypes.indices.contains(indexPath.row) {
                return .dismiss {
                    self.applySelectedGameType(self.selectableGameTypes[indexPath.row])
                }
            }
            return .dismiss()
        })
    }
    
    private func applySelectedGameType(_ gameType: GameType) {
        guard gameType != selectedGameType else { return }
        selectedGameType = gameType
        draftGame.gameType = gameType
        coverHost.apply(gameType: gameType,
                        image: coverHost.pickedImage,
                        previewGame: (coverHost.pickedImage == nil && !coverRemoved) ? editingGame : nil)
        listPageView.top = (coverHost, .fixedHeight(coverHostHeight(for: gameType)), false)
        listPageView.updateCellData(makePlatformCell(),
                                    indexPath: IndexPath(row: 0, section: FormSection.platform.rawValue))
    }
    
    private func pickCover() {
        draftGame.name = nameText
        draftGame.gameType = selectedGameType
        
        var sources: [ImageFetcher.Source] = [.capture, .library, .file]
        let trimmedName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            sources.append(.libretro(draftGame))
            sources.append(.steamGridDB(draftGame, preferredAssetType: .grids))
        }
        if canDeleteCover {
            sources.append(.delete)
        }
        
        ImageFetcher.showCommonFetcher(sources: sources) { [weak self] image, source in
            guard let self else { return }
            if case .delete = source {
                self.coverRemoved = true
                self.coverHost.apply(gameType: self.selectedGameType, image: nil)
                return
            }
            guard let image else { return }
            self.coverRemoved = false
            self.coverHost.apply(gameType: self.selectedGameType, image: image)
        }
    }
    
    private var canDeleteCover: Bool {
        if coverRemoved { return false }
        if coverHost.pickedImage != nil { return true }
        if let game = editingGame, game.gameCover != nil || game.onlineCoverUrl != nil {
            return true
        }
        return false
    }
    
    private func addGame() {
        let name = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            UIView.makeToast(message: R.string.localizable.addUrlGameNamePlaceholder())
            return
        }
        
        switch EmulatorInteractionKit.validateLaunchURL(urlText) {
        case .invalid:
            UIView.makeToast(message: R.string.localizable.addUrlGameInvalidUrl())
            return
        case .unsupportedScheme:
            UIView.makeToast(message: R.string.localizable.addUrlGameUnsupportedScheme())
            return
        case .ok(let url):
            guard UIApplication.shared.canOpenURL(url) else {
                UIView.makeToast(message: R.string.localizable.notInstall(url.scheme ?? ""))
                return
            }
            let urlString = url.absoluteString
            let gameID = Game.urlGamePrimaryKey(for: urlString)
            let realm = Database.realm
            // Hash id is the current key; URL-as-id is only for rows created before this change.
            if let existing = realm.object(ofType: Game.self, forPrimaryKey: gameID)
                ?? realm.object(ofType: Game.self, forPrimaryKey: urlString) {
                if existing.id == editingGame?.id {
                    persist(name: name, urlString: urlString, existing: existing)
                } else if existing.isDeleted, editingGame == nil {
                    persist(name: name, urlString: urlString, existing: existing)
                } else {
                    UIView.makeToast(message: R.string.localizable.addUrlGameAlreadyExists())
                }
                return
            }
            persist(name: name, urlString: urlString, existing: editingGame)
        }
    }
    
    private func creamAssetObjectID(for gameID: String) -> String {
        gameID.contains("://") ? Game.urlGamePrimaryKey(for: gameID) : gameID
    }
    
    private func persist(name: String, urlString: String, existing: Game?) {
        let coverData = coverHost.pickedImage?.jpegData(compressionQuality: 0.7)
            ?? coverHost.pickedImage?.pngData()
        let gameType = selectedGameType
        let extras = [
            ExtraKey.isUrlGame.rawValue: true,
            ExtraKey.urlGameURL.rawValue: urlString
        ].jsonData()
        let isLiveEdit = existing.map { !$0.isDeleted } ?? false
        let gameID = existing?.id ?? Game.urlGamePrimaryKey(for: urlString)
        let assetID = creamAssetObjectID(for: gameID)
        
        Game.change { realm in
            let game: Game
            if let existing {
                game = existing
                game.isDeleted = false
            } else {
                game = Game()
                game.id = gameID
                realm.add(game)
            }
            game.name = name
            game.aliasName = nil
            game.fileExtension = Game.urlGameFileExtension
            game.gameType = gameType
            if !isLiveEdit {
                game.importDate = Date()
            }
            game.extras = extras
            if coverRemoved {
                game.gameCover?.deleteAndClean(realm: realm)
                game.gameCover = nil
                game.onlineCoverUrl = nil
                game.hasCoverMatch = true
            } else if let coverData {
                game.gameCover?.deleteAndClean(realm: realm)
                game.gameCover = CreamAsset.create(objectID: assetID, propName: "gameCover", data: coverData)
                game.onlineCoverUrl = nil
                game.hasCoverMatch = true
            } else if !isLiveEdit {
                game.hasCoverMatch = false
            }
        }
        
        let saved = existing ?? Database.realm.object(ofType: Game.self, forPrimaryKey: gameID)
        if let saved, saved.gameCover == nil, !coverRemoved {
            OnlineCoverManager.shared.addCoverMatch(.init(game: saved))
        }
        NotificationCenter.default.post(name: R.NotificationName.GameCoverChange, object: nil)
        
        UIDevice.generateHaptic()
        hide()
        UIView.makeToast(message: isLiveEdit
                         ? R.string.localizable.addUrlGameUpdated()
                         : R.string.localizable.addUrlGameSuccess())
    }
}

extension AddUrlGameView: ShowableView {
    static func show(game: Game) {
        self.show(parameters: game)
    }
}

private final class UrlGameCoverSlotView: BaseView {
    var pickedImage: UIImage?
    var didTapEdit: (() -> Void)?
    
    private let coverContainerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = R.Size.CornerRadiusLarge
        view.makeShadow(ofColor: R.Color.BackgroundPrimary.forceStyle(.dark), radius: 30)
        return view
    }()
    
    private let coverView = GameCoverView()
    
    private lazy var cameraButton: ASButtonView = {
        let view = ASButtonView(.smallIconButton(icon: .symbolImage(R.image.camera_iconSymbols(), colors: [R.Color.Main]),
                                                 background: R.Color.BackgroundTertiary).enableGlass(true))
        view.didTapButton = { [weak self] in
            self?.didTapEdit?()
        }
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(coverContainerView)
        coverContainerView.addSubview(coverView)
        coverView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(cameraButton)
        
        coverContainerView.isUserInteractionEnabled = true
        coverContainerView.addTapGesture { [weak self] _ in
            self?.didTapEdit?()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func apply(gameType: GameType, image: UIImage?, previewGame: Game? = nil) {
        pickedImage = image
        let size = coverSize(for: gameType)
        coverContainerView.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(size)
        }
        cameraButton.snp.remakeConstraints { make in
            make.top.trailing.equalTo(coverContainerView).inset(R.Size.ContentSpaceExtraSmall)
        }
        
        let displayGame: Game
        if let previewGame, image == nil {
            displayGame = previewGame
        } else {
            let placeholderGame = Game()
            placeholderGame.gameType = gameType
            placeholderGame.fileExtension = Game.urlGameFileExtension
            displayGame = placeholderGame
        }
        coverView.setData(game: displayGame,
                          coverSize: size,
                          style: R.Style.GameCoverStyle,
                          scalePlatform: false)
        if let image {
            coverView.imageView.image = image
            coverView.imageView.contentMode = .scaleAspectFill
        }
        coverView.layoutSubviews()
    }
    
    private func coverSize(for gameType: GameType) -> CGSize {
        let size = CGSize(UIDevice.isPhone ? 180 : 160)
        let ratio = R.Size.GameCoverRatio(gameType: gameType)
        if ratio == 1 {
            return size
        } else if ratio < 1 {
            return CGSize(width: size.height * ratio, height: size.height)
        }
        return CGSize(width: size.width, height: size.width / max(ratio, 0.01))
    }
}
