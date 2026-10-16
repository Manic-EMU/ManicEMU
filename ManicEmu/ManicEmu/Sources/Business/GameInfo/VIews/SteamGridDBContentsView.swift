//
//  SteamGridDBContentsView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/8.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import Kingfisher

class SteamGridDBContentsView: BaseView {
    
    enum AssetType: Int, CaseIterable {
        case grids
        case heroes
        case logos
        case icons
        
        var title: String {
            switch self {
            case .grids: return "GRIDS"
            case .heroes: return "HEROES"
            case .logos: return "LOGOS"
            case .icons: return "ICONS"
            }
        }
    }
    
    private let sgdbGame: SteamGridDBGame
    private let game: Game?
    private let apiKey: String
    private let preferredAssetType: AssetType
    
    private var imagePage = SteamGridDBImagePage()
    private var listPageView: ASListPageView?
    private var lastKnownWidth: CGFloat = 0
    
    var didSelectImage: ((UIImage?) -> Void)?
    var didTapClose: (() -> Void)?
    
    private lazy var segmentView: ASSegmentView = {
        let view = ASSegmentView(.textSegment(titles: AssetType.allCases.map { $0.title }))
        view.didSelectIndex = { [weak self] _ in
            guard let self else { return }
            self.loadImages(page: 0)
        }
        return view
    }()
    
    private lazy var topView: UIView = {
        let view = UIView()
        view.addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.top.equalTo(R.Size.ContentSpaceLarge)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightExtraSmall)
            make.bottom.equalToSuperview().inset(R.Size.ContentSpaceSmall)
        }
        return view
    }()
    
    private lazy var imageGridView: SteamGridDBImageGridView = {
        let view = SteamGridDBImageGridView()
        view.didSelectImage = { [weak self] image in
            self?.handleImageSelection(image)
        }
        return view
    }()
    
    private lazy var paginationView: SteamGridDBPaginationView = {
        let view = SteamGridDBPaginationView()
        view.didTapPrevious = { [weak self] in
            guard let self, self.imagePage.hasPreviousPage else { return }
            self.loadImages(page: self.imagePage.page - 1)
        }
        view.didTapNext = { [weak self] in
            guard let self, self.imagePage.hasNextPage else { return }
            self.loadImages(page: self.imagePage.page + 1)
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        let values = parameters.compactMap { $0 }
        guard let sgdbGame = values.compactMap({ $0 as? SteamGridDBGame }).first,
              let apiKey = values.compactMap({ $0 as? String }).first else { return nil }
        self.sgdbGame = sgdbGame
        self.apiKey = apiKey
        self.game = values.compactMap({ $0 as? Game }).first
        self.preferredAssetType = values.compactMap({ $0 as? AssetType }).first ?? .grids
        super.init(frame: .zero)
        
        let listView = ASListPageView(getListPage())
        listView.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        listPageView = listView
        
        segmentView.setIndex(preferredAssetType.rawValue, callback: false)
        loadImages(page: 0)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 0, abs(width - lastKnownWidth) > 0.5 else { return }
        lastKnownWidth = width
        guard !imagePage.images.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.updateContents()
        }
    }
    
    private func resolvedContainerWidth() -> CGFloat {
        if bounds.width > 1 { return bounds.width }
        if R.Size.ApplicationWindowSize.width > 1 { return R.Size.ApplicationWindowSize.width }
        return 390
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if action.navigationValue?.isTapClose == true {
            if showAsSheet {
                hide()
            }
            didTapClose?()
        }
    }
    
    private func currentAssetType() -> AssetType {
        AssetType(rawValue: segmentView.segment.index) ?? .grids
    }
    
    private func loadImages(page: Int) {
        let options = SteamGridDBImageOptions(type: "game", id: sgdbGame.id, page: page)
        UIView.makeLoading()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { UIView.hideLoading() }
            do {
                let result: SteamGridDBImagePage
                switch self.currentAssetType() {
                case .grids:
                    result = try await SteamGridDBKit.getGrids(apiKey: self.apiKey, options: options)
                case .heroes:
                    result = try await SteamGridDBKit.getHeroes(apiKey: self.apiKey, options: options)
                case .logos:
                    result = try await SteamGridDBKit.getLogos(apiKey: self.apiKey, options: options)
                case .icons:
                    result = try await SteamGridDBKit.getIcons(apiKey: self.apiKey, options: options)
                }
                self.imagePage = result
                self.updateContents()
                self.listPageView?.collectionView.scrollToTop()
            } catch {
                self.imagePage = SteamGridDBImagePage(page: page, total: 0, limit: self.imagePage.limit, images: [])
                self.updateContents()
                UIView.makeToast(message: error.localizedDescription)
            }
        }
    }
    
    private func handleImageSelection(_ image: SteamGridDBImage) {
        guard let url = URL(string: image.url) else {
            UIView.makeToast(message: R.string.localizable.onlineCoverFetchFailed())
            return
        }
        UIView.makeLoading()
        let scene = hostingWindowScene
        KingfisherManager.shared.retrieveImage(with: url) { [weak self] result in
            Task { @MainActor in
                UIView.hideLoading()
            }
            guard let self else { return }
            switch result {
            case .success(let imageResult):
                ImageFetcher.edit(image: imageResult.image, in: scene) { editedImage in
                    Task { @MainActor in
                        self.didSelectImage?(editedImage)
                        if self.showAsSheet {
                            self.hide()
                        }
                        self.didTapClose?()
                    }
                }
            case .failure:
                Task { @MainActor in
                    UIView.makeToast(message: R.string.localizable.onlineCoverFetchFailed())
                }
            }
        }
    }
    
    private func getContentSection() -> ASListPage.Section? {
        guard !imagePage.images.isEmpty else { return nil }
        
        let width = resolvedContainerWidth()
        let assetType = currentAssetType()
        let gameType = game?.gameType ?? .unknown
        
        paginationView.update(page: imagePage)
        
        imageGridView.update(
            images: imagePage.images,
            layoutMode: assetType,
            gameType: gameType,
            containerWidth: width
        )
        
        let sectionHeight = max(
            SteamGridDBImageGridView.preferredContentHeight(
                images: imagePage.images,
                layoutMode: assetType,
                gameType: gameType,
                containerWidth: width
            ),
            1
        )
        
        return ASListPage.Section(
            cells: [.custom(imageGridView)],
            footer: .custom(paginationView, pin: false, height: R.Size.ItemHeightLarge),
            decoration: ASListPage.Section.Decoration(enable: false),
            itemLayout: .fixedHeight(sectionHeight)
        )
    }
    
    private func contentSections() -> [ASListPage.Section] {
        guard let section = getContentSection() else { return [] }
        return [section]
    }
    
    private func getListPage() -> ASListPage {
        return ASListPage(
            navigation: .defaultNavigation(
                title: sgdbGame.name,
                titleIcon: .image(R.image.steamGridDB_icon())
            ),
            top: (topView, .fixedHeight(R.Size.ItemHeightExtraLarge), true),
            sections: contentSections(),
            blankSlate: .init(detail: R.string.localizable.noGameCoverResult()),
            backgroundColor: .clear,
            listInsets: .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow)),
            pageInsets: .insets(top: R.Size.SheetGrabberTopInset)
        )
    }
    
    private func updateContents() {
        guard let listPageView else { return }
        listPageView.sections = contentSections()
    }
}

extension SteamGridDBContentsView: ShowableView {
    static func show(
        sgdbGame: SteamGridDBGame,
        game: Game?,
        apiKey: String,
        preferredAssetType: AssetType = .grids,
        didSelectImage: ((UIImage?) -> Void)? = nil
    ) {
        if let game {
            Self.show(parameters: sgdbGame, apiKey, preferredAssetType, game)?.didSelectImage = didSelectImage
        } else {
            Self.show(parameters: sgdbGame, apiKey, preferredAssetType)?.didSelectImage = didSelectImage
        }
    }
}

extension SteamGridDBContentsView: ViewTransition {
    func viewWillTransition() {
        updateContents()
    }
}

// MARK: - Image Grid

private extension SteamGridDBImage {
    /// width / height
    var aspectRatioWH: CGFloat {
        guard width > 0, height > 0 else { return 1 }
        return CGFloat(width) / CGFloat(height)
    }
}

private class SteamGridDBVariableHeightLayout: UICollectionViewLayout {
    
    var frameProvider: ((CGFloat) -> [CGRect])?
    
    private var cache = [UICollectionViewLayoutAttributes]()
    private var contentHeight: CGFloat = 1
    private var preparedWidth: CGFloat = 0
    
    override var collectionViewContentSize: CGSize {
        CGSize(width: max(preparedWidth, 1), height: max(contentHeight, 1))
    }
    
    override func prepare() {
        cache.removeAll()
        contentHeight = 1
        let width = collectionView?.bounds.width ?? 0
        preparedWidth = width
        guard width > 1, let frameProvider else { return }
        
        for (index, frame) in frameProvider(width).enumerated() {
            let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: index, section: 0))
            attributes.frame = frame
            cache.append(attributes)
            contentHeight = max(contentHeight, frame.maxY)
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cache.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < cache.count else { return nil }
        return cache[indexPath.item]
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.width > 1 && abs(newBounds.width - preparedWidth) > 0.5
    }
}

private final class SteamGridDBImageGridView: BaseView {
    
    static let itemSpacing = R.Size.ContentSpaceMedium
    
    var didSelectImage: ((SteamGridDBImage) -> Void)?
    
    private var images = [SteamGridDBImage]()
    private var layoutMode: SteamGridDBContentsView.AssetType = .grids
    private var gameType: GameType = .unknown
    private var containerWidth: CGFloat = 0
    
    private lazy var variableLayout: SteamGridDBVariableHeightLayout = {
        SteamGridDBVariableHeightLayout()
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.register(cellWithClass: SteamGridDBImageCell.self)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func effectiveContentWidth(for containerWidth: CGFloat) -> CGFloat {
        max(containerWidth - R.Size.ContentSpaceMedium * 2, 1)
    }
    
    static func preferredContentHeight(
        images: [SteamGridDBImage],
        layoutMode: SteamGridDBContentsView.AssetType,
        gameType: GameType,
        containerWidth: CGFloat
    ) -> CGFloat {
        guard !images.isEmpty else { return 1 }
        let contentWidth = effectiveContentWidth(for: containerWidth)
        switch layoutMode {
        case .grids:
            return gridsItemHeight(gameType: gameType, contentWidth: contentWidth).sectionHeight(imageCount: images.count)
        case .heroes:
            return max(heroesFrames(images: images, contentWidth: contentWidth).map(\.maxY).max() ?? 1, 1)
        case .logos:
            return max(waterfallFrames(images: images, contentWidth: contentWidth).map(\.maxY).max() ?? 1, 1)
        case .icons:
            return iconsItemHeight(contentWidth: contentWidth).sectionHeight(imageCount: images.count)
        }
    }
    
    private struct UniformGridMetrics {
        let columns: Int
        let itemSpacing: CGFloat
        let itemHeight: CGFloat
        
        func sectionHeight(imageCount: Int) -> CGFloat {
            let rows = max(Int(ceil(Double(imageCount) / Double(max(columns, 1)))), 1)
            return CGFloat(rows) * itemHeight + CGFloat(max(rows - 1, 0)) * itemSpacing
        }
    }
    
    private static func gridsItemHeight(gameType: GameType, contentWidth: CGFloat) -> UniformGridMetrics {
        let column = 3.0
        let itemSpacing = R.Size.ContentSpaceMedium - R.Size.GamesListSelectionEdge * 2
        let totalSpacing = (R.Size.ContentSpaceMedium - R.Size.GamesListSelectionEdge) * 2 + itemSpacing * (column - 1)
        let itemEstimatedWidth = max((max(contentWidth, 1) - totalSpacing) / column, 1)
        let coverWidth = max(itemEstimatedWidth - R.Size.GamesListSelectionEdge * 2, 1)
        let coverRatio = max(R.Size.GameCoverRatio(gameType: gameType, ignoreForceSquare: true), 0.01)
        let coverHeight = coverWidth / coverRatio
        let itemEstimatedHeight = max(R.Size.GamesListSelectionEdge * 2 + coverHeight, 1)
        return UniformGridMetrics(columns: max(Int(column), 1), itemSpacing: itemSpacing, itemHeight: itemEstimatedHeight)
    }
    
    private static func iconsItemHeight(contentWidth: CGFloat) -> UniformGridMetrics {
        let columns = 3
        let itemWidth = max((max(contentWidth, 1) - itemSpacing * CGFloat(columns - 1)) / CGFloat(columns), 1)
        return UniformGridMetrics(columns: columns, itemSpacing: itemSpacing, itemHeight: itemWidth)
    }
    
    private static func heroesFrames(images: [SteamGridDBImage], contentWidth: CGFloat) -> [CGRect] {
        let width = max(contentWidth, 1)
        var y: CGFloat = 0
        return images.map { image in
            let height = max(width / max(image.aspectRatioWH, 0.01), 1)
            let frame = CGRect(x: 0, y: y, width: width, height: height)
            y += height + itemSpacing
            return frame
        }
    }
    
    private static func waterfallFrames(images: [SteamGridDBImage], contentWidth: CGFloat) -> [CGRect] {
        let columns = 3
        let width = max(contentWidth, 1)
        let itemWidth = max((width - itemSpacing * CGFloat(columns - 1)) / CGFloat(columns), 1)
        var columnHeights = Array(repeating: CGFloat(0), count: columns)
        return images.map { image in
            let itemHeight = max(itemWidth / max(image.aspectRatioWH, 0.01), 1)
            let column = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let frame = CGRect(
                x: CGFloat(column) * (itemWidth + itemSpacing),
                y: columnHeights[column],
                width: itemWidth,
                height: itemHeight
            )
            columnHeights[column] = frame.maxY + itemSpacing
            return frame
        }
    }
    
    func update(
        images: [SteamGridDBImage],
        layoutMode: SteamGridDBContentsView.AssetType,
        gameType: GameType,
        containerWidth: CGFloat
    ) {
        self.images = images
        self.layoutMode = layoutMode
        self.gameType = gameType
        self.containerWidth = max(containerWidth, 1)
        let layout = makeLayout()
        if collectionView.collectionViewLayout !== layout {
            collectionView.setCollectionViewLayout(layout, animated: false)
        } else {
            layout.invalidateLayout()
        }
        collectionView.reloadData()
    }
    
    private func makeLayout() -> UICollectionViewLayout {
        switch layoutMode {
        case .heroes:
            variableLayout.frameProvider = { [weak self] width in
                guard let self else { return [] }
                return Self.heroesFrames(images: self.images, contentWidth: width)
            }
            return variableLayout
        case .logos:
            variableLayout.frameProvider = { [weak self] width in
                guard let self else { return [] }
                return Self.waterfallFrames(images: self.images, contentWidth: width)
            }
            return variableLayout
        case .grids, .icons:
            return createCompositionalLayout()
        }
    }
    
    private func createCompositionalLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, env in
            guard let self else { return nil }
            let contentWidth = max(env.container.effectiveContentSize.width, 1)
            switch self.layoutMode {
            case .grids:
                return self.makeGridsSection(contentWidth: contentWidth)
            case .icons:
                return self.makeIconsSection(contentWidth: contentWidth)
            case .heroes, .logos:
                return nil
            }
        }
    }
    
    private func makeGridsSection(contentWidth: CGFloat) -> NSCollectionLayoutSection {
        let metrics = Self.gridsItemHeight(gameType: gameType, contentWidth: contentWidth)
        let itemHeight = max(metrics.itemHeight, 1)
        let columns = max(metrics.columns, 1)
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1 / CGFloat(columns)),
                heightDimension: .absolute(itemHeight)
            )
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(itemHeight)
            ),
            subitem: item,
            count: columns
        )
        group.interItemSpacing = .fixed(metrics.itemSpacing)
        let groupHorizontalInset = R.Size.ContentSpaceMedium - R.Size.GamesListSelectionEdge
        group.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: groupHorizontalInset,
            bottom: 0,
            trailing: groupHorizontalInset
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = metrics.itemSpacing
        return section
    }
    
    private func makeIconsSection(contentWidth: CGFloat) -> NSCollectionLayoutSection {
        let metrics = Self.iconsItemHeight(contentWidth: contentWidth)
        let itemHeight = max(metrics.itemHeight, 1)
        let columns = max(metrics.columns, 1)
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1 / CGFloat(columns)),
                heightDimension: .absolute(itemHeight)
            )
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(itemHeight)
            ),
            subitem: item,
            count: columns
        )
        group.interItemSpacing = .fixed(metrics.itemSpacing)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = metrics.itemSpacing
        return section
    }
    
    private func cellDisplayStyle() -> SteamGridDBImageCell.DisplayStyle {
        switch layoutMode {
        case .grids: return .grid
        case .heroes: return .hero
        case .logos: return .logo
        case .icons: return .icon
        }
    }
}

extension SteamGridDBImageGridView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: SteamGridDBImageCell.self, for: indexPath)
        let image = images[indexPath.item]
        cell.applyDisplayStyle(cellDisplayStyle())
        cell.configure(with: image, targetSize: estimatedItemSize(at: indexPath.item))
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didSelectImage?(images[indexPath.item])
    }
    
    private func estimatedItemSize(at index: Int) -> CGSize {
        let contentWidth = Self.effectiveContentWidth(for: containerWidth > 1 ? containerWidth : max(bounds.width, 1))
        switch layoutMode {
        case .grids:
            let metrics = Self.gridsItemHeight(gameType: gameType, contentWidth: contentWidth)
            let coverHeight = max(metrics.itemHeight - R.Size.GamesListSelectionEdge * 2, 1)
            let coverWidth = max(coverHeight * max(R.Size.GameCoverRatio(gameType: gameType, ignoreForceSquare: true), 0.01), 1)
            return CGSize(width: coverWidth, height: coverHeight)
        case .heroes:
            guard images.indices.contains(index) else { return CGSize(width: 1, height: 1) }
            let height = max(contentWidth / max(images[index].aspectRatioWH, 0.01), 1)
            return CGSize(width: contentWidth, height: height)
        case .logos:
            let frames = Self.waterfallFrames(images: images, contentWidth: contentWidth)
            guard frames.indices.contains(index) else { return CGSize(width: 1, height: 1) }
            return frames[index].size
        case .icons:
            let side = Self.iconsItemHeight(contentWidth: contentWidth).itemHeight
            return CGSize(width: side, height: side)
        }
    }
}

private final class SteamGridDBImageCell: UICollectionViewCell {
    
    enum DisplayStyle {
        case grid
        case hero
        case logo
        case icon
    }
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = R.Color.BackgroundSecondary
        return view
    }()
    
    private var currentStyle: DisplayStyle?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        applyDisplayStyle(.grid)
        enablePressEffect = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
    }
    
    func applyDisplayStyle(_ style: DisplayStyle) {
        guard currentStyle != style else { return }
        currentStyle = style
        switch style {
        case .logo:
            imageView.layer.cornerRadius = R.Size.CornerRadiusMicro
        case .grid, .hero, .icon:
            imageView.layer.cornerRadius = R.Size.CornerRadiusMedium
        }
        imageView.snp.remakeConstraints { make in
            switch style {
            case .grid:
                make.edges.equalToSuperview().inset(R.Size.GamesListSelectionEdge)
            case .hero, .logo, .icon:
                make.edges.equalToSuperview()
            }
        }
    }
    
    func configure(with image: SteamGridDBImage, targetSize: CGSize) {
        let thumbURLString = image.thumb.isEmpty ? image.url : image.thumb
        guard let url = URL(string: thumbURLString) else {
            imageView.image = nil
            return
        }
        let processSize = CGSize(
            width: max(targetSize.width * UIScreen.main.scale, 1),
            height: max(targetSize.height * UIScreen.main.scale, 1)
        )
        imageView.kf.setImage(
            with: url,
            options: [
                .processor(DownsamplingImageProcessor(size: processSize)),
                .scaleFactor(UIScreen.main.scale),
                .transition(.fade(0.15)),
                .cacheOriginalImage
            ]
        )
    }
}

// MARK: - Pagination

private final class SteamGridDBPaginationView: BaseView {
    
    var didTapPrevious: (() -> Void)?
    var didTapNext: (() -> Void)?
    
    private let pageLabel = ASLabelView(text: .mediumText(""))
    private lazy var previousButtonView: ASButtonView = {
        let button = ASButton.chevron(
            icon: .symbol(.chevronLeft, colors: [R.Color.LabelPrimary]),
            title: "Previous",
            titleColor: R.Color.LabelPrimary,
            titleFont: R.Font.Body2(),
            titlePosition: .right,
            background: R.Color.BackgroundQuaternary,
            sizeStyle: .fixHeight(R.Size.ButtonSmall)
        ).enableGlass(true)
        let view = ASButtonView(button)
        view.didTapButton = { [weak self] in
            self?.didTapPrevious?()
        }
        return view
    }()
    
    private lazy var nextButtonView: ASButtonView = {
        let button = ASButton.chevron(
            icon: .symbol(.chevronRight, colors: [R.Color.LabelPrimary]),
            title: "Next",
            titleColor: R.Color.LabelPrimary,
            titleFont: R.Font.Body2(),
            background: R.Color.BackgroundQuaternary,
            sizeStyle: .fixHeight(R.Size.ButtonSmall)
        ).enableGlass(true)
        let view = ASButtonView(button)
        view.didTapButton = { [weak self] in
            self?.didTapNext?()
        }
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(previousButtonView)
        addSubview(pageLabel)
        addSubview(nextButtonView)
        
        pageLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        previousButtonView.snp.makeConstraints { make in
            make.trailing.equalTo(pageLabel.snp.leading).offset(-R.Size.ContentSpaceHuge)
            make.centerY.equalToSuperview()
        }
        
        nextButtonView.snp.makeConstraints { make in
            make.leading.equalTo(pageLabel.snp.trailing).offset(R.Size.ContentSpaceHuge)
            make.centerY.equalToSuperview()
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(page: SteamGridDBImagePage) {
        let current = page.totalPages > 0 ? page.page + 1 : 0
        let total = max(page.totalPages, 0)
        pageLabel.title = total > 0 ? "\(current) / \(total)" : "0 / 0"
        previousButtonView.alpha = page.hasPreviousPage ? 1 : 0.35
        nextButtonView.alpha = page.hasNextPage ? 1 : 0.35
        previousButtonView.isUserInteractionEnabled = page.hasPreviousPage
        nextButtonView.isUserInteractionEnabled = page.hasNextPage
    }
}
