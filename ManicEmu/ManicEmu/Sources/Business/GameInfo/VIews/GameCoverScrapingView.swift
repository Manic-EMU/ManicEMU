//
//  GameCoverScrapingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/28.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import RealmSwift
import IceCream
import Kingfisher
import Fuse

class GameCoverScrapingView: BaseView {
    private enum NavTool: Int {
        case apiKey = 0
        case more = 1
    }
    
    private enum ScrapeRow {
        case skipExisting
        case scrapeCover
        case scrapeIcon
        case scrapeBanner
        
        static func from(_ indexPath: IndexPath) -> ScrapeRow? {
            switch (indexPath.section, indexPath.row) {
            case (0, 0): return .skipExisting
            case (1, 0): return .scrapeCover
            case (1, 1): return .scrapeIcon
            case (1, 2): return .scrapeBanner
            default: return nil
            }
        }
    }
    
    private let games: [Game]
    private var skipExisting = true
    private var scrapeCover = false
    private var scrapeIcon = false
    private var scrapeBanner = false
    private var isScraping = false
    private var showClose: Bool
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        guard let games = parameters.compactMap({ $0 as? [Game] }).first else { return nil }
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        self.games = games
        super.init(frame: .zero)
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    convenience init(games: [Game], showClose: Bool) {
        self.init(parameters: games, showClose)!
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - Page
    
    private var canStartScraping: Bool {
        scrapeCover || scrapeIcon || scrapeBanner
    }
    
    private func getListPage() -> ASListPage {
        var navigation = ASListPage.Navigation.defaultNavigation(
            title: R.string.localizable.coverScraping(),
            titleIcon: GameOption.coverScraping.icon,
            tools: [
                .symbolImage(R.image.key_iconSymbols(), weight: .regular),
                .symbolImage(R.image.ellipsis_iconSymbols())
            ]
        )
        navigation.enableClose = showClose
        
        let listInsetBottom = (UIDevice.isPad && !showClose) ? R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceMedium : 0
        
        return ASListPage(
            navigation: navigation,
            sections: getSections(),
            bottom: getBottom(),
            backgroundColor: .clear,
            listInsets: .insets(bottom: listInsetBottom),
            pageInsets: .insets(top: showClose ? R.Size.SheetGrabberTopInset : R.Size.ContentInsetTop(window: hostingWindow))
        )
    }
    
    private func getSections() -> [ASListPage.Section] {
        let skipSection = ASListPage.Section(
            cells: [
                .iconTitleDetailSwitchCell(title: R.string.localizable.skipExistingCovers(),
                                           state: skipExisting ? .on : .off,
                                           enablePressEffect: false)
            ],
            header: .texts([.smallText(R.string.localizable.coverScrapingDesc(), numberOfLines: 0)], pin: false)
        )
        let scrapeSection = ASListPage.Section(cells: [
            .iconTitleDetailSwitchCell(title: R.string.localizable.scrapeCover(),
                                       state: scrapeCover ? .on : .off,
                                       enablePressEffect: false),
            .iconTitleDetailSwitchCell(title: R.string.localizable.scrapeIcon(),
                                       state: scrapeIcon ? .on : .off,
                                       enablePressEffect: false),
            .iconTitleDetailSwitchCell(title: R.string.localizable.scrapeBanner(),
                                       state: scrapeBanner ? .on : .off,
                                       enablePressEffect: false)
        ])
        return [skipSection, scrapeSection]
    }
    
    private func getBottom() -> ASButton {
        var button = ASButton.large(title: R.string.localizable.startScraping(),
                                    titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                    titleAlignment: .center,
                                    background: R.Color.Main)
        var disableAttributes = button.allAttributes[.normal]!
        disableAttributes.background = R.Color.BackgroundSecondary
        disableAttributes.title?.attributes?.color = R.Color.LabelTertiary
        button.allAttributes[.disabled] = disableAttributes
        button.state = canStartScraping ? .normal : .disabled
        return button
    }
    
    private func updateBottom() {
        listPageView.bottom = getBottom()
    }
    
    //MARK: - Actions
    
    private func handleAction(_ action: ASListPage.Action) {
        if let navigationValue = action.navigationValue {
            if navigationValue.isTapClose {
                hide()
            } else if let toolIndex = navigationValue.tapToolsValue {
                switch NavTool(rawValue: toolIndex) {
                case .apiKey:
                    showAPIKeyInput()
                case .more:
                    showMoreMenu()
                case .none:
                    break
                }
            }
        } else if let (indexPath, cellData, subActions) = action.normalItemValue {
            guard let isOn = subActions?.extraValue as? Bool,
                  let row = ScrapeRow.from(indexPath) else { return }
            applySwitch(row: row, isOn: isOn)
            listPageView.updateCellData(cellData.updateNormalSwitch(state: isOn ? .on : .off),
                                        indexPath: indexPath,
                                        reloadView: false)
            if row != .skipExisting {
                updateBottom()
            }
        } else if action.isBottom {
            beginScraping()
        }
    }
    
    private func applySwitch(row: ScrapeRow, isOn: Bool) {
        switch row {
        case .skipExisting: skipExisting = isOn
        case .scrapeCover: scrapeCover = isOn
        case .scrapeIcon: scrapeIcon = isOn
        case .scrapeBanner: scrapeBanner = isOn
        }
    }
    
    private func showAPIKeyInput(onSaved: ((String) -> Void)? = nil) {
        LimitedTextInputView.show(icon: .symbolImage(R.image.key_iconSymbols()),
                                  title: onSaved == nil ? "SteamGridDB API Key" : "API Key",
                                  detail: R.string.localizable.steamGridDBAPIKeyDesc() + "\n" + R.string.localizable.steamGridDBAPIKeyAlert(),
                                  limitedType: .normal(maxTextSize: 255),
                                  confirmAction: { key in
            if let key = key as? String, !key.trimmed.isEmpty {
                Settings.defalut.updateExtra(key: ExtraKey.steamGridDBAPIKey.rawValue, value: key)
                onSaved?(key.trimmed)
            } else {
                UIView.makeToast(message: R.string.localizable.steamGridDBAPIKeyAlert())
            }
        })
    }
    
    private func showMoreMenu() {
        ChevronSheetView.show(icon: .symbolImage(R.image.ellipsis_iconSymbols()),
                              title: R.string.localizable.moreSettingTitle(),
                              cellOptions: [
                                .iconTitleChevronCell(icon: .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
                                                      title: R.string.localizable.removeCover(),
                                                      titleColor: R.Color.Red),
                                .iconTitleChevronCell(icon: .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
                                                      title: R.string.localizable.removeIcon(),
                                                      titleColor: R.Color.Red),
                                .iconTitleChevronCell(icon: .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
                                                      title: R.string.localizable.removeBanner(),
                                                      titleColor: R.Color.Red),
                                .iconTitleChevronCell(icon: .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
                                                      title: R.string.localizable.removeAllArtwork(),
                                                      titleColor: R.Color.Red)
                              ]) { [weak self] index in
            guard let self, let index else { return }
            switch index {
            case 0:
                self.confirmRemove(detail: R.string.localizable.removeCoverAlert(), cover: true, icon: false, banner: false)
            case 1:
                self.confirmRemove(detail: R.string.localizable.removeIconAlert(), cover: false, icon: true, banner: false)
            case 2:
                self.confirmRemove(detail: R.string.localizable.removeBannerAlert(), cover: false, icon: false, banner: true)
            case 3:
                self.confirmRemove(detail: R.string.localizable.removeAllArtworkAlert(), cover: true, icon: true, banner: true)
            default:
                break
            }
        }
    }
    
    private func confirmRemove(detail: String, cover: Bool, icon: Bool, banner: Bool) {
        UIView.makeAlert(detail: detail,
                         confirmTitle: R.string.localizable.confirmTitle(),
                         confirmAction: { [weak self] in
            self?.removeAssets(cover: cover, icon: icon, banner: banner)
        })
    }
    
    private func removeAssets(cover: Bool, icon: Bool, banner: Bool) {
        let ids = games.map(\.id)
        Game.change { realm in
            for id in ids {
                guard let game = realm.object(ofType: Game.self, forPrimaryKey: id), !game.isDeleted else { continue }
                if cover {
                    game.gameCover?.deleteAndClean(realm: realm)
                    game.gameCover = nil
                    game.onlineCoverUrl = nil
                }
                if icon {
                    game.icon?.deleteAndClean(realm: realm)
                    game.icon = nil
                }
                if banner {
                    game.banner?.deleteAndClean(realm: realm)
                    game.banner = nil
                }
            }
        }
        NotificationCenter.default.post(name: R.NotificationName.GameCoverChange, object: nil)
    }
    
    //MARK: - Scraping
    
    private func beginScraping() {
        guard canStartScraping, !isScraping else { return }
        
        func start(apiKey: String) {
            startScraping(apiKey: apiKey)
        }
        
        if let apiKey = Settings.defalut.SteamGridDBAPIKey, !apiKey.trimmed.isEmpty {
            start(apiKey: apiKey)
        } else {
            showAPIKeyInput(onSaved: { key in
                start(apiKey: key)
            })
        }
    }
    
    private func startScraping(apiKey: String) {
        guard canStartScraping, !isScraping else { return }
        isScraping = true
        
        let snapshots = games.map { GameCoverScraper.Snapshot(game: $0) }
        let options = GameCoverScraper.Options(skipExisting: skipExisting,
                                               scrapeCover: scrapeCover,
                                               scrapeIcon: scrapeIcon,
                                               scrapeBanner: scrapeBanner)
        UIView.makeLoading()
        Task { [weak self] in
            let summary = await GameCoverScraper.scrape(snapshots: snapshots, options: options, apiKey: apiKey)
            let detail = summary.detailText(options: options)
            await MainActor.run {
                self?.isScraping = false
                if summary.didUpdateArtwork {
                    NotificationCenter.default.post(name: R.NotificationName.GameCoverChange, object: nil)
                }
                UIView.hideLoading {
                    UIView.makeAlert(title: R.string.localizable.coverScraping(),
                                     detail: detail,
                                     detailAlignment: .left,
                                     cancelTitle: R.string.localizable.confirmTitle())
                }
            }
        }
    }
}

extension GameCoverScrapingView: ShowableView {
    static func show(games: [Game]? = nil) {
        if let games {
            Self.show(parameters: games)
        } else {
            let realm = Database.realm
            let games = realm.objects(Game.self).where({ !$0.isDeleted })
            if games.count > 0 {
                Self.show(parameters: Array(games))
            } else {
                UIView.makeToast(message: R.string.localizable.transferPakNoGames())
            }
        }
    }
}

// MARK: - Scraper

private enum GameCoverScraper {
    private static let maxConcurrent = 4
    private static let jpegQuality: CGFloat = 0.7
    
    struct Snapshot {
        let id: String
        let displayName: String
        let hasCover: Bool
        let hasIcon: Bool
        let hasBanner: Bool
        
        init(game: Game) {
            id = game.id
            displayName = game.displayName
            let onlineCover = game.onlineCoverUrl?.trimmed ?? ""
            hasCover = game.gameCover != nil || !onlineCover.isEmpty
            hasIcon = game.icon != nil
            hasBanner = game.banner != nil
        }
    }
    
    struct Options {
        let skipExisting: Bool
        let scrapeCover: Bool
        let scrapeIcon: Bool
        let scrapeBanner: Bool
    }
    
    struct AssetCount {
        var updated = 0
        var skipped = 0
        var failed = 0
        
        mutating func add(_ result: AssetResult) {
            switch result {
            case .unused: break
            case .skipped: skipped += 1
            case .updated: updated += 1
            case .failed: failed += 1
            }
        }
    }
    
    enum AssetResult {
        case unused, skipped, updated, failed
    }
    
    struct GameOutcome {
        var cover: AssetResult = .unused
        var icon: AssetResult = .unused
        var banner: AssetResult = .unused
    }
    
    struct Summary {
        var cover = AssetCount()
        var icon = AssetCount()
        var banner = AssetCount()
        
        var didUpdateArtwork: Bool {
            cover.updated > 0 || icon.updated > 0 || banner.updated > 0
        }
        
        mutating func merge(_ outcome: GameOutcome) {
            cover.add(outcome.cover)
            icon.add(outcome.icon)
            banner.add(outcome.banner)
        }
        
        func detailText(options: Options) -> String {
            var lines = [R.string.localizable.coverScrapingComplete()]
            if options.scrapeCover {
                lines.append(R.string.localizable.coverScrapingStat(R.string.localizable.boxArt(),
                                                                   cover.updated,
                                                                   cover.skipped,
                                                                   cover.failed))
            }
            if options.scrapeIcon {
                lines.append(R.string.localizable.coverScrapingStat(R.string.localizable.icon(),
                                                                   icon.updated,
                                                                   icon.skipped,
                                                                   icon.failed))
            }
            if options.scrapeBanner {
                lines.append(R.string.localizable.coverScrapingStat(R.string.localizable.banner(),
                                                                   banner.updated,
                                                                   banner.skipped,
                                                                   banner.failed))
            }
            return lines.joined(separator: "\n")
        }
    }
    
    static func scrape(snapshots: [Snapshot], options: Options, apiKey: String) async -> Summary {
        var summary = Summary()
        await withTaskGroup(of: GameOutcome.self) { group in
            var nextIndex = 0
            func enqueue() {
                guard nextIndex < snapshots.count else { return }
                let snapshot = snapshots[nextIndex]
                nextIndex += 1
                group.addTask {
                    await scrapeOne(snapshot: snapshot, options: options, apiKey: apiKey)
                }
            }
            for _ in 0..<min(maxConcurrent, snapshots.count) {
                enqueue()
            }
            for await outcome in group {
                summary.merge(outcome)
                enqueue()
            }
        }
        return summary
    }
    
    private static func scrapeOne(snapshot: Snapshot, options: Options, apiKey: String) async -> GameOutcome {
        var outcome = GameOutcome()
        
        // Skip Existing Covers applies to every enabled asset that is already present.
        let needCover = options.scrapeCover && !(options.skipExisting && snapshot.hasCover)
        let needIcon = options.scrapeIcon && !(options.skipExisting && snapshot.hasIcon)
        let needBanner = options.scrapeBanner && !(options.skipExisting && snapshot.hasBanner)
        
        if options.scrapeCover, options.skipExisting, snapshot.hasCover {
            outcome.cover = .skipped
        }
        if options.scrapeIcon, options.skipExisting, snapshot.hasIcon {
            outcome.icon = .skipped
        }
        if options.scrapeBanner, options.skipExisting, snapshot.hasBanner {
            outcome.banner = .skipped
        }
        
        guard needCover || needIcon || needBanner else { return outcome }
        
        let query = snapshot.displayName.trimmed
        guard !query.isEmpty else {
            if needCover { outcome.cover = .failed }
            if needIcon { outcome.icon = .failed }
            if needBanner { outcome.banner = .failed }
            return outcome
        }
        
        let matches: [SteamGridDBGame]
        do {
            matches = try await SteamGridDBKit.searchGame(apiKey: apiKey, query: query)
        } catch {
            if needCover { outcome.cover = .failed }
            if needIcon { outcome.icon = .failed }
            if needBanner { outcome.banner = .failed }
            return outcome
        }
        
        guard let sgdbGame = bestMatch(query: query, in: matches) else {
            if needCover { outcome.cover = .failed }
            if needIcon { outcome.icon = .failed }
            if needBanner { outcome.banner = .failed }
            return outcome
        }
        
        async let coverImage = fetchImageIfNeeded(needCover, apiKey: apiKey, gameId: sgdbGame.id, kind: .cover)
        async let iconImage = fetchImageIfNeeded(needIcon, apiKey: apiKey, gameId: sgdbGame.id, kind: .icon)
        async let bannerImage = fetchImageIfNeeded(needBanner, apiKey: apiKey, gameId: sgdbGame.id, kind: .banner)
        let images = await (cover: coverImage, icon: iconImage, banner: bannerImage)
        
        let coverData = imageData(images.cover)
        let iconData = imageData(images.icon)
        let bannerData = imageData(images.banner)
        
        if needCover, coverData == nil { outcome.cover = .failed }
        if needIcon, iconData == nil { outcome.icon = .failed }
        if needBanner, bannerData == nil { outcome.banner = .failed }
        
        guard coverData != nil || iconData != nil || bannerData != nil else { return outcome }
        
        let persisted = await MainActor.run {
            persist(gameID: snapshot.id, coverData: coverData, iconData: iconData, bannerData: bannerData)
        }
        if needCover, coverData != nil {
            outcome.cover = persisted.cover ? .updated : .failed
        }
        if needIcon, iconData != nil {
            outcome.icon = persisted.icon ? .updated : .failed
        }
        if needBanner, bannerData != nil {
            outcome.banner = persisted.banner ? .updated : .failed
        }
        return outcome
    }
    
    private enum ArtworkKind {
        case cover, icon, banner
    }
    
    /// Fuse scores are lower when closer; pick the closest title among SteamGridDB hits.
    private static func bestMatch(query: String, in games: [SteamGridDBGame]) -> SteamGridDBGame? {
        guard !games.isEmpty else { return nil }
        let fuse = Fuse()
        let pattern = fuse.createPattern(from: query)
        let scored = games.compactMap { game -> (SteamGridDBGame, Double)? in
            guard let score = fuse.search(pattern, in: game.name)?.score else { return nil }
            return (game, score)
        }
        if let best = scored.min(by: { $0.1 < $1.1 }) {
            return best.0
        }
        return games.first
    }
    
    private static func fetchImageIfNeeded(_ need: Bool, apiKey: String, gameId: Int, kind: ArtworkKind) async -> UIImage? {
        guard need else { return nil }
        return await firstImage(apiKey: apiKey, gameId: gameId, kind: kind)
    }
    
    private static func imageData(_ image: UIImage?) -> Data? {
        guard let image else { return nil }
        return image.jpegData(compressionQuality: jpegQuality) ?? image.pngData()
    }
    
    private static func firstImage(apiKey: String, gameId: Int, kind: ArtworkKind) async -> UIImage? {
        let page: SteamGridDBImagePage
        do {
            switch kind {
            case .cover:
                page = try await SteamGridDBKit.getGridsById(apiKey: apiKey, id: gameId)
            case .icon:
                page = try await SteamGridDBKit.getIconsById(apiKey: apiKey, id: gameId)
            case .banner:
                page = try await SteamGridDBKit.getHeroesById(apiKey: apiKey, id: gameId)
            }
        } catch {
            return nil
        }
        guard let image = page.images.first else { return nil }
        if let downloaded = await downloadImage(image.url) {
            return downloaded
        }
        return await downloadImage(image.thumb)
    }
    
    private static func downloadImage(_ urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString), !urlString.isEmpty else { return nil }
        return await withCheckedContinuation { continuation in
            KingfisherManager.shared.retrieveImage(with: url) { result in
                switch result {
                case .success(let imageResult):
                    continuation.resume(returning: imageResult.image)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    @MainActor
    private static func persist(gameID: String, coverData: Data?, iconData: Data?, bannerData: Data?) -> (cover: Bool, icon: Bool, banner: Bool) {
        var coverOK = false
        var iconOK = false
        var bannerOK = false
        Game.change { realm in
            guard let game = realm.object(ofType: Game.self, forPrimaryKey: gameID), !game.isDeleted else { return }
            if let coverData {
                game.gameCover?.deleteAndClean(realm: realm)
                game.gameCover = CreamAsset.create(objectID: game.id, propName: "gameCover", data: coverData)
                game.onlineCoverUrl = nil
                coverOK = true
            }
            if let iconData {
                game.icon?.deleteAndClean(realm: realm)
                game.icon = CreamAsset.create(objectID: game.id, propName: "icon", data: iconData)
                iconOK = true
            }
            if let bannerData {
                game.banner?.deleteAndClean(realm: realm)
                game.banner = CreamAsset.create(objectID: game.id, propName: "banner", data: bannerData)
                bannerOK = true
            }
        }
        return (coverOK, iconOK, bannerOK)
    }
}
