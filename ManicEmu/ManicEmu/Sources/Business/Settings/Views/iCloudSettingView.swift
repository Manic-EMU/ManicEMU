//
//  iCloudSettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import RealmSwift

#if !SIDE_LOAD
class ICloudSettingView: BaseView {
    
    private enum MainRow {
        case master
        case progress
        case platform
        case games
        case repair
    }
    
    private let showClose: Bool
    private var iCloudDriveSyncChangeNotification: Any?
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        return view
    }()
    
    deinit {
        if let iCloudDriveSyncChangeNotification {
            NotificationCenter.default.removeObserver(iCloudDriveSyncChangeNotification)
        }
    }
    
    required init?(parameters: Any...) {
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        iCloudDriveSyncChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.iCloudDriveSyncChange, object: nil, queue: .main) { [weak self] notification in
            self?.handleProgressNotification(notification)
        }
    }
    
    convenience init(showClose: Bool = true) {
        self.init(parameters: showClose)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func reloadList() {
        listPageView.updatePage(getListPage())
    }
    
    private var isSyncEnabled: Bool {
        Settings.defalut.iCloudSyncEnable && PurchaseManager.isMember
    }
    
    private func getListPage() -> ASListPage {
        var navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.iCloudTitle(),
                                                                 titleIcon: .symbolImage(R.image.icloudsync_iconSymbols()))
        navigation.enableClose = showClose
        
        var sections: [ASListPage.Section] = [
            ASListPage.Section(cells: [masterCell()],
                               footer: .texts([.smallText(R.string.localizable.iCloudDesc(), numberOfLines: 0)], pin: false))
        ]
        if isSyncEnabled {
            var progressSection = ASListPage.Section(cells: [progressCell(FilesSyncManager.shared.progress)])
            progressSection.itemLayout = .fixedHeight(R.Size.ItemHeightExtraLarge)
            sections.append(progressSection)
            sections.append(ASListPage.Section(cells: [
                .iconTitleDetailChevronCell(icon: .symbolImage(R.image.category_iconSymbols()),
                                            title: R.string.localizable.iCloudROMPlatformConfig()),
                .iconTitleDetailChevronCell(icon: .symbolImage(R.image.games_iconSymbols()),
                                            title: R.string.localizable.iCloudROMGameConfig())
            ], header: .defaultHeader(title: R.string.localizable.iCloudROMSyncSetting()),
               footer: .texts([.smallText(R.string.localizable.iCloudROMSyncDesc(), numberOfLines: 0)], pin: false)))
            sections.append(ASListPage.Section(cells: [
                .iconTitleDetailChevronCell(icon: .symbolImage(R.image.refresh_iconSymbols()),
                                            title: R.string.localizable.iCloudRepairSync())
            ], footer: .texts([.smallText(R.string.localizable.iCloudRepairSyncDesc(), numberOfLines: 0)], pin: false)))
        }
        
        let listInsetBottom = (UIDevice.isPad && !showClose) ? R.Size.ContentInsetBottom + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceMedium : 0
        return ASListPage(navigation: navigation,
                          sections: sections,
                          backgroundColor: .clear,
                          listInsets: .insets(bottom: listInsetBottom),
                          pageInsets: .insets(top: showClose ? R.Size.SheetGrabberTopInset : R.Size.ContentInsetTop))
    }
    
    private func masterCell() -> ASListPage.Cell {
        let enabled = Settings.defalut.iCloudSyncEnable
        let state: ASSwitch.State
        if !PurchaseManager.isMember {
            state = .disabled
        } else {
            state = enabled ? .on : .off
        }
        let detail: String
        if enabled && PurchaseManager.isMember {
            if let iCloudPath = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.path {
                detail = FileType.humanReadableFileSize(CacheManager.folderSize(atPath: iCloudPath)) ?? R.string.localizable.iCloudSynced()
            } else {
                detail = R.string.localizable.iCloudSynced()
            }
        } else {
            detail = R.string.localizable.iCloudNotEnable()
        }
        return .iconTitleDetailSwitchCell(icon: .symbolImage(R.image.icloudsync_iconSymbols()),
                                          title: R.string.localizable.iCloudTitle(),
                                          detail: detail,
                                          state: state,
                                          enablePressEffect: false)
    }
    
    private func progressCell(_ progress: FilesSyncProgress) -> ASListPage.Cell {
        let title: String
        switch progress.phase {
        case .idle:
            title = R.string.localizable.iCloudSynced()
        case .paused:
            title = R.string.localizable.iCloudSyncPaused()
        case .unavailable:
            title = R.string.localizable.iCloudNotEnable()
        case .scanning, .syncing:
            if let name = progress.currentFileName?.components(separatedBy: "/").last, !name.isEmpty {
                title = R.string.localizable.iCloudSyncing() + " · " + name
            } else {
                title = R.string.localizable.iCloudSyncing()
            }
        }
        let total = max(progress.totalCount, 0)
        let completed = min(progress.completedCount, total)
        return .iconTitleProgressCell(icon: .symbolImage(R.image.icloudsync_iconSymbols()),
                                      title: title,
                                      progress: .init(value: progress.fraction,
                                                      interaction: .disabled(.small)))
    }
    
    private func handleProgressNotification(_ notification: Notification) {
        guard isSyncEnabled else { return }
        let progress = (notification.object as? FilesSyncProgress) ?? FilesSyncManager.shared.progress
        guard listPageView.sections.count > 1 else {
            reloadList()
            return
        }
        listPageView.updateCellData(progressCell(progress), indexPath: IndexPath(row: 0, section: 1))
    }
    
    private func row(at indexPath: IndexPath) -> MainRow? {
        if indexPath.section == 0 { return .master }
        if !isSyncEnabled { return nil }
        if indexPath.section == 1 { return .progress }
        if indexPath.section == 2 {
            return indexPath.row == 0 ? .platform : .games
        }
        if indexPath.section == 3 { return .repair }
        return nil
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if action.navigationValue?.isTapClose == true {
            hide()
            return
        }
        guard let value = action.normalItemValue, let row = row(at: value.indexPath) else { return }
        switch row {
        case .master:
            if value.subActions?.extraValue == nil {
                topViewController()?.present(PurchaseViewController(featuresType: .iCloud), animated: true)
                return
            }
            guard let isOn = value.subActions?.extraValue as? Bool else { return }
            if isOn {
                UIView.makeAlert(title: R.string.localizable.iCloudTipsTitle(),
                                 detail: R.string.localizable.iCloudTipsDetail(),
                                 confirmTitle: R.string.localizable.iCloudConfirm(),
                                 cancelAction: { [weak self] in
                    self?.listPageView.updateCellData(value.cellData.updateNormalSwitch(state: .off), indexPath: value.indexPath)
                }, confirmAction: { [weak self] in
                    Settings.defalut.iCloudSyncEnable = true
                    if let iCloudServiceEnable = SyncManager.shared.iCloudServiceEnable, !iCloudServiceEnable {
                        UIView.makeAlert(title: R.string.localizable.iCloudDisableTitle(),
                                         detail: R.string.localizable.iCloudDisableDetail(),
                                         cancelTitle: R.string.localizable.confirmTitle())
                    }
                    self?.reloadList()
                }, tapBackgroundAction: { [weak self] in
                    self?.listPageView.updateCellData(value.cellData.updateNormalSwitch(state: .off), indexPath: value.indexPath)
                })
            } else {
                Settings.defalut.iCloudSyncEnable = false
                reloadList()
            }
        case .progress:
            break
        case .platform:
            showPlatformConfig()
        case .games:
            showGameConfig()
        case .repair:
            repairSync()
        }
    }
    
    private func showPlatformConfig() {
        let gameTypes = FilesSyncPolicy.configurableROMGameTypes()
        guard gameTypes.count > 0 else { return }
        
        let cells: [[ASListPage.Cell]] = gameTypes.map { gameType in
            if R.Style.GamesGroupTitleStyle == .brand {
                let icon: ASIcon
                let iconSize: ASListPage.Cell.Style.IconSize
                if let image = gameType.brandImage {
                    icon = .image(image)
                    iconSize = .fixHeight(gameType == .lynx ? 16 : 20)
                } else {
                    icon = .symbolImage(R.image.category_iconSymbols())
                    iconSize = .fixSize(CGSize(R.Size.ButtonExtraExtraSmall))
                }
                return [.iconTitleDetailSwitchCell(icon: icon,
                                                   iconSize: iconSize,
                                                   state: FilesSyncPolicy.isPlatformROMSyncEnabled(gameType) ? .on : .off,
                                                   enablePressEffect: false)]
            } else {
                let title = R.Style.GamesGroupTitleStyle == .fullName ? gameType.localizedName : gameType.localizedShortName
                return [.iconTitleDetailSwitchCell(title: title,
                                                   state: FilesSyncPolicy.isPlatformROMSyncEnabled(gameType) ? .on : .off,
                                                   enablePressEffect: false)]
            }
        }
        
        var sheetStyle: ASSheet.Style = .simpleList(icon: .symbolImage(R.image.category_iconSymbols()),
                                                    title: R.string.localizable.iCloudROMPlatformConfig(),
                                                    detail: .smallText(R.string.localizable.iCloudROMSyncDesc(), numberOfLines: 0),
                                                    options: cells)
        
        ASSheetView.show(.init(style: sheetStyle), action: { action, updation in
            guard let normalItemValue = action.listPageValue?.normalItemValue else {
                return .dismiss()
            }
            guard let isOn = normalItemValue.subActions?.extraValue as? Bool else {
                return .none
            }
            let index = normalItemValue.indexPath.section
            guard index < gameTypes.count else { return .dismiss() }
            let gameType = gameTypes[index]
            Self.applyPlatformROMSync(gameType: gameType, enabled: isOn)
            if case let .simpleList(icon, title, detail, options, cancelEnable) = sheetStyle {
                var next = options
                next[index][0] = normalItemValue.cellData.updateNormalSwitch(state: isOn ? .on : .off)
                sheetStyle = .simpleList(icon: icon, title: title, detail: detail, options: next, cancelEnable: cancelEnable)
                updation?(sheetStyle)
            }
            return .none
        })
    }
    
    private func showGameConfig() {
        let realm = Database.realm
        let games = realm.objects(Game.self).where({ !$0.isDeleted && $0.gameType != .symbian })
        let configurable = Set(FilesSyncPolicy.configurableROMGameTypes())
        guard games.contains(where: { configurable.contains($0.gameType) }) else {
            UIView.makeToast(message: R.string.localizable.transferPakNoGames())
            return
        }
        
        var datas = [[Game]]()
        var sections = [ASListPage.Section]()
        let groupGames = Dictionary(grouping: Array(games), by: { $0.gameType })
        System.allGameTypes.forEach { sortGameType in
            guard configurable.contains(sortGameType), let games = groupGames[sortGameType] else { return }
            datas.append(games)
            let cells = games.map { game in
                ASListPage.Cell.iconTitleDetailSwitchCell(icon: game.gameCoverIcon,
                                                          iconSize: .fixSize(CGSize(R.Size.ButtonMedium)),
                                                          title: game.displayName,
                                                          detail: game.fileName,
                                                          state: FilesSyncPolicy.shouldSyncROM(game) ? .on : .off,
                                                          enablePressEffect: false)
            }
            var headerTitle = sortGameType.localizedShortName
            if R.Style.GamesGroupTitleStyle == .fullName {
                headerTitle = sortGameType.localizedName
            }
            sections.append(ASListPage.Section(cells: cells, header: .defaultHeader(title: headerTitle)))
        }
        
        let navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.iCloudROMGameConfig(),
                                                                 titleIcon: .symbolImage(R.image.games_iconSymbols()))
        let listPage = ASListPage(navigation: navigation, sections: sections)
        var sheetStyle: ASSheet.Style = .listPage(listPage)
        
        ASSheetView.show(.init(style: sheetStyle), action: { action, updation in
            if action.listPageValue?.navigationValue?.isTapClose == true {
                return .dismiss()
            }
            guard let normalItemValue = action.listPageValue?.normalItemValue else {
                return .dismiss()
            }
            guard let isOn = normalItemValue.subActions?.extraValue as? Bool else {
                return .none
            }
            let indexPath = normalItemValue.indexPath
            guard indexPath.section < datas.count, indexPath.row < datas[indexPath.section].count else {
                return .dismiss()
            }
            let game = datas[indexPath.section][indexPath.row]
            Self.applyGameROMSync(game: game, enabled: isOn)
            if case var .listPage(listPage) = sheetStyle {
                listPage.sections[indexPath.section].cells[indexPath.row] = normalItemValue.cellData.updateNormalSwitch(state: isOn ? .on : .off)
                sheetStyle = .listPage(listPage)
                updation?(sheetStyle)
            }
            return .none
        })
    }
    
    private static func applyPlatformROMSync(gameType: GameType, enabled: Bool) {
        let wasEnabled = FilesSyncPolicy.isPlatformROMSyncEnabled(gameType)
        guard wasEnabled != enabled else { return }
        FilesSyncPolicy.setPlatformROMSyncEnabled(gameType, enabled: enabled)
        var targets: [Game] = []
        Game.change { realm in
            let games = realm.objects(Game.self).where { !$0.isDeleted && $0.gameType == gameType }
            for game in games {
                FilesSyncPolicy.setGameROMSyncEnabled(game, enabled: enabled)
                targets.append(game)
            }
        }
        guard FilesSyncPolicy.isDriveSyncAvailable, !targets.isEmpty else { return }
        if enabled {
            for game in targets {
                FilesSyncManager.shared.uploadROMFiles(for: game)
            }
        } else {
            confirmRemoveCloudROMs(games: targets)
        }
    }
    
    private static func confirmRemoveCloudROMs(games: [Game]) {
        guard !games.isEmpty, FilesSyncPolicy.isDriveSyncAvailable else { return }
        let ids = games.map(\.id)
        UIView.makeAlert(title: R.string.localizable.iCloudROMRemoveDriveTitle(),
                         detail: R.string.localizable.iCloudROMRemoveDriveDetail(),
                         cancelTitle: R.string.localizable.iCloudROMKeepDrive(),
                         confirmTitle: R.string.localizable.iCloudROMRemoveDriveConfirm(),
                         confirmAction: {
            let realm = Database.realm
            let targets = ids.compactMap { id -> Game? in
                guard let game = realm.object(ofType: Game.self, forPrimaryKey: id), !game.isDeleted else { return nil }
                return game
            }
            FilesSyncManager.shared.excludeCloudROMs(for: targets)
        })
    }
    
    private func repairSync() {
        let started = FilesSyncManager.shared.repair { [weak self] event in
            self?.handleRepairEvent(event)
        }
        if started {
            UIView.makeLoading()
        }
    }
    
    private func handleRepairEvent(_ event: FilesSyncRepairEvent) {
        switch event {
        case .alreadyRunning:
            UIView.makeToast(message: R.string.localizable.iCloudRepairSyncInProgress())
        case .notStarted:
            UIView.hideLoading {
                UIView.makeToast(message: R.string.localizable.iCloudRepairSyncNotReady())
            }
        case .scanFinished(let stats):
            UIView.hideLoading {
                if stats.queued == 0 {
                    UIView.makeToast(message: R.string.localizable.iCloudRepairSyncAlreadyDone())
                }
            }
        case .completed(let uploaded, let downloaded, let remaining):
            if uploaded == 0 && downloaded == 0 && remaining == 0 {
                return
            }
            if remaining > 0 {
                UIView.makeToast(message: R.string.localizable.iCloudRepairSyncResultPending(uploaded, downloaded, remaining))
            } else {
                UIView.makeToast(message: R.string.localizable.iCloudRepairSyncResult(uploaded, downloaded))
            }
        }
    }
    
    private static func applyGameROMSync(game: Game, enabled: Bool) {
        Game.change { _ in
            FilesSyncPolicy.setGameROMSyncEnabled(game, enabled: enabled)
        }
        guard FilesSyncPolicy.isDriveSyncAvailable else { return }
        if enabled {
            FilesSyncManager.shared.uploadROMFiles(for: game)
        } else {
            confirmRemoveCloudROMs(games: [game])
        }
    }
}

extension ICloudSettingView: ShowableView {}
#endif
