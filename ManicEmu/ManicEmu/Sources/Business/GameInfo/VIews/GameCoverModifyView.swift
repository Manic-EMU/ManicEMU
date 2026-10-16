//
//  GameCoverModifyView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/12.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Kingfisher
import IceCream

class GameCoverModifyView: BaseView {
    private let game: Game
    private var lastKnownWidth: CGFloat = 0
    
    private lazy var boxArtSlot = CoverSlotView(kind: .boxArt, game: game) { [weak self] in
        self?.pickImage(for: .boxArt)
    }
    private lazy var logoSlot = CoverSlotView(kind: .icon, game: game) { [weak self] in
        self?.pickImage(for: .icon)
    }
    private lazy var bannerSlot = CoverSlotView(kind: .banner, game: game) { [weak self] in
        self?.pickImage(for: .banner)
    }
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(makeListPage())
        view.didActionOccurred = { [weak self] action in
            if action.navigationValue?.isTapClose == true {
                self?.hide()
            }
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        guard let game = parameters.compactMap({ $0 as? Game }).first else { return nil }
        self.game = game
        super.init(frame: .zero)
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 0, abs(width - lastKnownWidth) > 0.5 else { return }
        lastKnownWidth = width
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.listPageView.updatePage(self.makeListPage())
        }
    }
    
    private func makeListPage() -> ASListPage {
        // 横屏时 WindowSize.width 会变成长边，不能拿来当容器宽；未布局时用短边兜底。
        let availableWidth = bounds.width > 0 ? bounds.width : R.Size.ApplicationWindowSize.minDimension
        return ASListPage(
            navigation: .defaultNavigation(title: R.string.localizable.gamesModifyCover(),
                                           titleIcon: .symbolImage(R.image.cover_iconSymbols())),
            sections: [
                makeSection(title: R.string.localizable.boxArt(),
                            detail: R.string.localizable.boxArtDesc(),
                            slot: boxArtSlot,
                            availableWidth: availableWidth),
                makeSection(title: R.string.localizable.icon(),
                            detail: R.string.localizable.iconDesc(),
                            slot: logoSlot,
                            availableWidth: availableWidth),
                makeSection(title: R.string.localizable.banner(),
                            detail: R.string.localizable.bannerDesc(),
                            slot: bannerSlot,
                            availableWidth: availableWidth)
            ],
            backgroundColor: .clear,
            pageInsets: .insets(top: R.Size.SheetGrabberTopInset)
        )
    }
    
    private func makeSection(title: String, detail: String, slot: CoverSlotView, availableWidth: CGFloat) -> ASListPage.Section {
        let imageSize = CoverSlotKind.imageSize(for: slot.kind, availableWidth: availableWidth, gameType: game.gameType)
        slot.applyImageSize(imageSize)
        slot.reloadImage()
        let cellHeight = imageSize.height + R.Size.ContentSpaceMedium * 2
        return .init(cells: [.custom(slot)],
                     header: .texts([
                        .init(attributes: .init(text: title,
                                                color: R.Color.LabelSecondary,
                                                font: R.Font.Subheadline(emphasis: true))),
                        .init(attributes: .init(text: detail,
                                                color: R.Color.LabelSecondary,
                                                font: R.Font.Footnote(),
                                                numberOfLines: 0))
                      ], pin: false),
                     decoration: .init(style: .primary),
                     itemLayout: .fixedHeight(cellHeight))
    }
    
    private func pickImage(for kind: CoverSlotKind) {
        var sources: [ImageFetcher.Source] = [
            .capture,
            .library,
            .file,
            .libretro(game),
            .steamGridDB(game, preferredAssetType: kind.steamGridAssetType)
        ]
        
        if let current = kind.currentEditableImage(game: game) {
            sources.append(.editImage(current))
        } else if kind == .boxArt,
                  let urlString = game.onlineCoverUrl,
                  let url = URL(string: urlString),
                  game.gameCover == nil {
            sources.append(.editImageUrl(url))
        }
        
        if kind.hasRemovableImage(game: game) {
            sources.append(.delete)
        }
        
        ImageFetcher.showCommonFetcher(sources: sources,
                                       in: hostingWindowScene,
                                       completion: { [weak self] image, source in
            guard let self else { return }
            if case .delete = source {
                self.removeImage(for: kind)
                return
            }
            guard let image else { return }
            self.persist(image: image, for: kind)
        })
    }
    
    private func persist(image: UIImage, for kind: CoverSlotKind) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        Game.change { realm in
            switch kind {
            case .boxArt:
                self.game.gameCover?.deleteAndClean(realm: realm)
                self.game.gameCover = CreamAsset.create(objectID: self.game.id, propName: "gameCover", data: data)
                self.game.onlineCoverUrl = nil
            case .icon:
                self.game.icon?.deleteAndClean(realm: realm)
                self.game.icon = CreamAsset.create(objectID: self.game.id, propName: "icon", data: data)
            case .banner:
                self.game.banner?.deleteAndClean(realm: realm)
                self.game.banner = CreamAsset.create(objectID: self.game.id, propName: "banner", data: data)
            }
        }
        slot(for: kind).reloadImage()
        if kind == .boxArt {
            NotificationCenter.default.post(name: R.NotificationName.GameCoverChange, object: nil)
        }
    }
    
    /// Clears the selected artwork. Box art leaves `hasCoverMatch` unchanged so auto-match will not refill it.
    private func removeImage(for kind: CoverSlotKind) {
        Game.change { realm in
            switch kind {
            case .boxArt:
                self.game.gameCover?.deleteAndClean(realm: realm)
                self.game.gameCover = nil
                self.game.onlineCoverUrl = nil
            case .icon:
                self.game.icon?.deleteAndClean(realm: realm)
                self.game.icon = nil
            case .banner:
                self.game.banner?.deleteAndClean(realm: realm)
                self.game.banner = nil
            }
        }
        slot(for: kind).reloadImage()
        NotificationCenter.default.post(name: R.NotificationName.GameCoverChange, object: nil)
    }
    
    private func slot(for kind: CoverSlotKind) -> CoverSlotView {
        switch kind {
        case .boxArt: return boxArtSlot
        case .icon: return logoSlot
        case .banner: return bannerSlot
        }
    }
}

extension GameCoverModifyView: ShowableView {
    static func show(game: Game) {
        self.show(parameters: game)
    }
}

// MARK: - Slot kinds

private enum CoverSlotKind {
    case boxArt
    case icon
    case banner
    
    var steamGridAssetType: SteamGridDBContentsView.AssetType {
        switch self {
        case .boxArt: return .grids
        case .icon: return .icons
        case .banner: return .heroes
        }
    }
    
    static func imageSize(for kind: CoverSlotKind, availableWidth: CGFloat, gameType: GameType) -> CGSize {
        let inset = R.Size.ContentSpaceMedium * 2
        switch kind {
        case .boxArt:
            let shortest: CGFloat = 130
            let ratio = R.Size.GameCoverRatio(gameType: gameType, ignoreForceSquare: true)
            if ratio >= 1 {
                return CGSize(width: shortest * ratio, height: shortest)
            }
            return CGSize(width: shortest, height: shortest / max(ratio, 0.01))
        case .icon:
            return CGSize(width: 130, height: 130)
        case .banner:
            let width = max(availableWidth - inset, 1)
            // 始终按设备横向屏幕尺寸（长边 x 短边），不随当前方向宽高互换。
            let landscapeWidth = R.Size.ApplicationWindowSize.maxDimension
            let landscapeHeight = R.Size.ApplicationWindowSize.minDimension
            let landscapeAspect = landscapeWidth / max(landscapeHeight, 1)
            return CGSize(width: width, height: width / max(landscapeAspect, 0.01))
        }
    }
    
    func hasRemovableImage(game: Game) -> Bool {
        switch self {
        case .boxArt:
            return game.gameCover != nil || game.onlineCoverUrl != nil
        case .icon:
            return game.icon != nil
        case .banner:
            return game.banner != nil
        }
    }
    
    func currentEditableImage(game: Game) -> UIImage? {
        switch self {
        case .boxArt:
            if let data = game.gameCover?.storedData(), let image = UIImage(data: data) {
                return image
            }
            return nil
        case .icon:
            if let data = game.icon?.storedData(), let image = UIImage(data: data) {
                return image
            }
            return nil
        case .banner:
            if let data = game.banner?.storedData(), let image = UIImage(data: data) {
                return image
            }
            return nil
        }
    }
}

// MARK: - CoverSlotView

private final class CoverSlotView: BaseView {
    let kind: CoverSlotKind
    private let game: Game
    private var didTapEdit: (() -> Void)?
    private var imageSize: CGSize = .zero
    
    private lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = R.Color.CoverEmpty
        return view
    }()
    
    private lazy var editButton: ASButtonView = {
        let view = ASButtonView(.smallIconButton(icon: .symbolImage(R.image.camera_iconSymbols(), colors: [R.Color.Main]),
                                                 background: R.Color.BackgroundTertiary).enableGlass(true))
        view.didTapButton = { [weak self] in
            self?.didTapEdit?()
        }
        return view
    }()
    
    init(kind: CoverSlotKind, game: Game, didTapEdit: @escaping () -> Void) {
        self.kind = kind
        self.game = game
        self.didTapEdit = didTapEdit
        super.init(frame: .zero)
        
        isUserInteractionEnabled = true
        addSubview(imageView)
        addSubview(editButton)
        
        applyImageSize(CGSize(width: 130, height: 130))
        
        editButton.snp.makeConstraints { make in
            make.top.trailing.equalTo(imageView).inset(R.Size.ContentSpaceExtraSmall)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.layerCornerRadius = R.Size.CornerRadiusMedium
    }
    
    func applyImageSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        imageSize = size
        // Banner 宽度应等于 cell 内容宽 − 左右 inset；若再写死 width + centerX + leading≥inset，
        // 会与 UIView-Encapsulated-Layout-Width 冲突（视觉靠打断约束才“看起来对”）。
        imageView.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(R.Size.ContentSpaceMedium).priority(.high)
            switch kind {
            case .banner:
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                make.height.equalTo(size.height)
            case .boxArt, .icon:
                make.centerX.equalToSuperview()
                make.leading.greaterThanOrEqualToSuperview().inset(R.Size.ContentSpaceMedium)
                make.trailing.lessThanOrEqualToSuperview().inset(R.Size.ContentSpaceMedium)
                make.size.equalTo(size)
            }
        }
    }
    
    func reloadImage() {
        let size = imageSize.width > 0 ? imageSize : CGSize(width: 130, height: 130)
        let placeholder = UIImage.placeHolder(preferenceSize: size)
        
        switch kind {
        case .boxArt:
            imageView.setGameCover(game: game, size: size)
        case .icon:
            imageView.kf.cancelDownloadTask()
            if let data = game.icon?.storedData(), let image = UIImage(data: data) {
                imageView.contentMode = .scaleAspectFill
                imageView.image = image
            } else {
                imageView.contentMode = .scaleAspectFit
                imageView.image = placeholder
            }
        case .banner:
            imageView.kf.cancelDownloadTask()
            if let data = game.banner?.storedData(), let image = UIImage(data: data) {
                imageView.contentMode = .scaleAspectFill
                imageView.image = image
            } else {
                imageView.contentMode = .scaleAspectFit
                imageView.image = placeholder
            }
        }
    }
}
