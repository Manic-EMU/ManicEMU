//
//  SaveStateListView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/30.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import RealmSwift
import UniformTypeIdentifiers
import IceCream

class SaveStateListView: BaseView {
    
    private let game: Game
    private var manualGameSaveStates: Results<GameSaveState>
    private var autoGameSaveStates: Results<GameSaveState>
    private var isEditMode: Bool = false {
        didSet {
            if isEditMode {
                updateContents()
                updateNavigation()
            } else {
                isSelectedAll = false
            }
        }
    }
    private var isSelectedAll: Bool {
        get {
            if currentGameSaveStates.count > 0 {
                return selectedSaveStateNames.count == currentGameSaveStates.count
            }
            return false
        }
        set {
            if newValue {
                selectedSaveStateNames = Set(currentGameSaveStates.map({ $0.name }))
            } else {
                selectedSaveStateNames.removeAll()
            }
        }
    }
    private var selectedSaveStateNames = Set<String>() {
        didSet {
            updateContents()
            updateTool()
            updateNavigation()
        }
    }
    private var selectedSaveState: [GameSaveState] {
        return currentGameSaveStates.filter({
            selectedSaveStateNames.contains($0.name)
        })
    }
    private var currentGameSaveStates: Results<GameSaveState> {
        segmentView.segment.index == 0 ? manualGameSaveStates : autoGameSaveStates
    }
    
    private var listPageView: ASListPageView? = nil
    
    private var segmentView = ASSegmentView(.textSegment(titles: [
        R.string.localizable.readySegmentManualSave(),
        R.string.localizable.readySegmentAutoSave()
    ]))
    
    var hideCompletion: ((GameSaveState?)->Void)? = nil
    var hasCallHideCompletion = false
    
    private var membershipNotification: Any? = nil
    
    required init?(parameters: Any...) {
        if let game = parameters.first as? Game {
            self.game = game
            self.manualGameSaveStates = game.gameSaveStates.sorted(by: \GameSaveState.date, ascending: false).where {
                $0.type == .manualSaveState && !$0.isDeleted
            }
            self.autoGameSaveStates = game.gameSaveStates.sorted(by: \GameSaveState.date, ascending: false).where {
                $0.type == .autoSaveState && !$0.isDeleted
            }
            super.init(frame: .zero)
            
            segmentView.didSelectIndex = { [weak self] index in
                guard let self else { return }
                if self.currentGameSaveStates.count == 0, self.isEditMode {
                    self.isEditMode = false
                } else {
                    self.selectedSaveStateNames.removeAll()
                }
            }
            if manualGameSaveStates.count == 0, autoGameSaveStates.count > 0 {
                segmentView.segment.index = 1
            }
            
            let listView = ASListPageView(getListPage())
            listView.didActionOccurred = { [weak self] action in
                guard let self else { return }
                self.handleAction(action)
                
            }
            addSubview(listView)
            listView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            listPageView = listView
            
            membershipNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.MembershipChange, object: nil, queue: .main) { [weak self] notification in
                self?.updateContents()
            }
            
        } else {
            return nil
        }
    }
    
    convenience init(game: Game) {
        self.init(parameters: game)!
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let membershipNotification = membershipNotification {
            NotificationCenter.default.removeObserver(membershipNotification)
        }
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if let navigationValue = action.navigationValue {
            //navigation action
            if navigationValue.isTapClose {
                //close
                if showAsSheet {
                    hide()
                }
            } else if let index =  navigationValue.tapToolsValue {
                if currentGameSaveStates.count > 0, index == 0 {
                    //enter edit mode
                    if currentGameSaveStates.count == 0 {
                        UIView.makeToast(message: R.string.localizable.readyGameSaveStatesEmpty())
                        return
                    }
                    isEditMode = true
                } else if (currentGameSaveStates.count == 0 && index == 0) || index == 1 {
                    //Import Save State
                    UIView.makeAlert(title: R.string.localizable.importSaveState(),
                                     detail: R.string.localizable.saveStateDesc(),
                                     cancelTitle: R.string.localizable.gotIt(),
                                     hideAction: { [weak self] _ in
                        if let utype = UTType(filenameExtension: "savestate") {
                            guard let self else { return }
                            FilesImporter.shared.presentImportController(supportedTypes: [utype], manualHandle: { [weak self] urls in
                                guard let self else { return }
                                let group = DispatchGroup()
                                for url in urls {
                                    group.enter()
                                    let now = Date.now
                                    let state = GameSaveState()
                                    state.name = self.importedSaveStateName(url: url, timestamp: now)
                                    state.type = .manualSaveState
                                    state.date = now
                                    self.game.getCoverImage(completion: { image in
                                        if let imageData = image?.scaled(toHeight: 150)?.jpegData(compressionQuality: 0.7) {
                                            state.stateCover = CreamAsset.create(objectID: state.name, propName: "stateCover", data: imageData)
                                        }
                                        state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", url: url)
                                        Game.change { realm in
                                            self.game.gameSaveStates.append(state)
                                        }
                                        state.updateExtra(key: ExtraKey.saveStateCore.rawValue, value: self.game.defaultCore)
                                        group.leave()
                                    })
                                }
                                if urls.count > 0 {
                                    group.notify(queue: .main, execute: { [weak self] in
                                        self?.updateContents()
                                    })
                                }
                            })
                        }
                    })
                }
            } else if navigationValue.isTapEdit {
                //selected/deselected all
                isSelectedAll.toggle()
            } else if navigationValue.isTapCancel {
                //leave edit mode
                isEditMode = false
            }
        } else if let toolValue = action.toolValue {
            if toolValue.isTapMain {
                //more settings
                ChevronSheetView.show(detail: R.string.localizable.saveStateDesc(),
                                      cellOptions: [
                                        .iconTitleChevronCell(icon: GameOption.shareSave.icon,
                                                              title: R.string.localizable.shareSaveState())
                                      ],
                                      completion: { [weak self] index in
                    guard let self, let index, index == 0 else { return }
                    let saveStateFileUrls = selectedSaveState.compactMap({
                        $0.stateData?.filePath
                    })
                    guard saveStateFileUrls.count > 0 else { return }
                    var cacheUrls = [URL]()
                    saveStateFileUrls.forEach({
                        let cacheUrl = URL(fileURLWithPath: R.Path.ShareWorkSpace.appendingPathComponent($0.lastPathComponent.deletingPathExtension + ".savestate"))
                        cacheUrls.append(cacheUrl)
                        try? FileManager.safeCopyItem(at: $0, to: cacheUrl, shouldReplace: true)
                    })
                    ShareManager.shareFiles(fileUrls: cacheUrls)
                })
                
            } else if let _ = toolValue.tapOthersValue {
                //delete
                UIView.makeAlert(title: R.string.localizable.saveStateRemove(),
                                 detail: R.string.localizable.deleteGameGameStateAlertDetail(),
                                 confirmTitle: R.string.localizable.confirmDelte(),
                                 confirmAction: { [weak self] in
                    guard let self else { return }
                    Game.change { [weak self] realm in
                        guard let self else { return }
                        self.currentGameSaveStates.filter({
                            self.selectedSaveStateNames.contains($0.name)
                        }).forEach({
                            $0.stateCover?.deleteAndClean(realm: realm)
                            $0.stateData?.deleteAndClean(realm: realm)
                            if Settings.defalut.iCloudSyncEnable {
                                //iCloud同步删除
                                $0.isDeleted = true
                            } else {
                                //本地删除
                                realm.delete($0)
                            }
                        })
                    }
                    if self.currentGameSaveStates.count > 0 {
                        self.isSelectedAll = false
                    } else {
                        self.isEditMode = false
                    }
                })
            }
        } else if let index = action.normalItemValue?.indexPath.row {
            let state = currentGameSaveStates[index]
            if let _ = action.normalItemValue?.subActions?.itemStyle.buttonValue {
                //load game with state
                func loadState() {
                    let supportCores = self.game.gameType.supportCores
                    let saveSateCore = state.getExtraInt(key: ExtraKey.saveStateCore.rawValue) ?? 0
                    if supportCores.count > 0,
                       saveSateCore != game.defaultCore {
                        //由不同核心创建的state 需要提示
                        UIView.makeAlert(title: R.string.localizable.gameSaveUnCompatibleTitle(),
                                         detail: R.string.localizable.saveStateCoreUnCompatible(supportCores[saveSateCore], supportCores[game.defaultCore]),
                                         confirmTitle: R.string.localizable.gameSaveStateForceLoad(), confirmAction: {
                            
                            if PlayViewController.isGaming {
                                self.hideCompletion?(state)
                                self.hasCallHideCompletion = true
                            } else {
                                self.game.handleTapAction(forceQuick: true)
                            }
                        })
                    } else {
                        if PlayViewController.isGaming {
                            self.hideCompletion?(state)
                            self.hasCallHideCompletion = true
                        } else {
                            self.game.handleTapAction(forceQuick: true, saveState: state)
                        }
                    }
                }
                
                if self.game.enableHarcore {
                    UIView.makeToast(message: R.string.localizable.notAllowHardcore())
                    return
                }
                
                if state.isCompatible {
                    loadState()
                } else {
                    UIView.makeAlert(title: R.string.localizable.gameSaveUnCompatibleTitle(),
                                     detail: R.string.localizable.gameSaveUnCompatibleDetail(state.gameSaveStateDeviceInfo, state.currentDeviceInfo), confirmTitle: R.string.localizable.gameSaveStateForceLoad(), confirmAction: {
                        loadState()
                    })
                }
            } else if action.normalItemValue?.subActions == nil {
                if selectedSaveStateNames.contains(state.name) {
                    //deselected save state
                    selectedSaveStateNames.remove(state.name)
                } else {
                    //selected save state
                    selectedSaveStateNames.insert(state.name)
                }
            }
        } else if let index = action.longPressValue?.row {
            guard !isEditMode else { return }
            let state = currentGameSaveStates[index]
            isEditMode = true
            selectedSaveStateNames.insert(state.name)
        }
    }
    
    /// Citra load reads the slot from `name.deletingPathExtension.pathExtension`.
    /// Native files are `{titleId}.{slot:02d}.cst`; keep that stem so in-game load can copy into the slot.
    private func importedSaveStateName(url: URL, timestamp: Date) -> String {
        let timePrefix = timestamp.string(withFormat: R.Strings.FileNameTimeFormat)
        guard game.isCitra3DS else {
            return "\(timePrefix)_" + game.fileName
        }
        let imported = url.lastPathComponent
        let slot: UInt32
        if let parsed = UInt32(imported.deletingPathExtension.pathExtension), (1...50).contains(parsed) {
            slot = parsed
        } else {
            slot = 1
        }
        let titleId = String(format: "%016llX", game.identifierFor3DS)
        return "\(timePrefix)_\(titleId).\(String(format: "%02d", slot)).cst"
    }
    
    private func getSaveStatesSection() -> ASListPage.Section {
        var cells = [ASListPage.Cell]()
        for (index, saveState) in currentGameSaveStates.enumerated() {
            var styles = [ASListPage.Cell.Style]()
            styles.append(.icon(.image(.tryDataImageOrPlaceholder(tryData: saveState.stateCover?.storedData()),
                                       cornerStyle: .radius(R.Size.CornerRadiusMicro)),
                                iconSize: .fixSize(CGSize(R.Size.ButtonMedium))))
            if saveState.isCompatible {
                styles.append(.title(.largeText(R.string.localizable.gameSaveTitle(index))))
            } else {
                styles.append(.title(.largeTextFolowedByIcon(icon: .symbolImage(R.image.infoFill_iconSymbols(),
                                                                                colors: [R.Color.Yellow]),
                                                             text: R.string.localizable.gameSaveTitle(index))))
            }
            styles.append(.detail(.extraSmallText(saveState.date.dateTimeString(ofStyle: .short))))
            if isEditMode {
                styles.append(.check(.init(isSelected: selectedSaveStateNames.contains(saveState.name) ? true : false)))
            } else {
                styles.append(.button(.chevron(icon: .symbol(.playFill,
                                                             weight: .regular,
                                                             colors: [R.Color.LabelPrimary]),
                                               title: R.string.localizable.gameSaveContinue(),
                                               titleColor: R.Color.LabelPrimary,
                                               titleFont: R.Font.Caption(),
                                               background: R.Color.BackgroundQuaternary,
                                               sizeStyle: .fixHeight(R.Size.ButtonExtraExtraSmall,
                                                                     insets: UIEdgeInsets(top: R.Size.ContentSpaceTiny,
                                                                                          //The icons will have some spacing to keep the visual balance.
                                                                                          left: R.Size.ContentSpaceExtraSmall + 2,
                                                                                          bottom: R.Size.ContentSpaceTiny,
                                                                                          right: R.Size.ContentSpaceExtraSmall))).enableGlass(true)))
            }
            cells.append(.normal(styles, enablePressEffect: isEditMode ? true : false))
        }
        return .init(cells: cells)
    }
    
    private func getToolView() -> ASListPage.Tool? {
        if selectedSaveStateNames.count > 0 {
            return ASListPage.Tool.defaultTool(otherIcons: [.symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red])])
        }
        return nil
    }
    
    private func getBlankSlateSection() -> ASListPage.Section? {
        if currentGameSaveStates.count == 0 {
            let blankSpace = R.Size.SheetWindowMaxSize.height -
            R.Size.SheetGrabberTopInset -
            R.Size.NavigationHeight -
            R.Size.ContentSpaceLarge -
            R.Size.ItemHeightExtraSmall -
            R.Size.ContentSpaceLarge -
            R.Size.ContentSpaceLarge -
            R.Size.ContentInsetBottom
            
            return .init(cells: [.custom(ASBlankSlateView(.init(title: R.string.localizable.readyGameSaveStatesEmpty())))],
                         decoration: .init(enable: false),
                         itemLayout: .fixedHeight(blankSpace))
        }
        
        if !PurchaseManager.isMember {
            return .init(cells: [.custom(GameSavePurchaseGuideView(hideSeperator: false))],
                         decoration: .init(enable: false),
                         itemLayout: .fixedHeight(224))
            
        }
        
        return nil
    }
    
    private func getNavigation() -> ASListPage.Navigation {
        let tools: [ASIcon]
        if currentGameSaveStates.count == 0 {
            if segmentView.segment.index == 0 {
                tools = [.symbolImage(R.image.importgamesave_iconSymbols())]
            } else {
                tools = []
            }
        } else {
            if segmentView.segment.index == 0 {
                tools = [
                    .symbolImage(R.image.selectedit_iconSymbols()),
                    .symbolImage(R.image.importgamesave_iconSymbols())
                ]
            } else {
                tools = [.symbolImage(R.image.selectedit_iconSymbols())]
            }
        }
        return ASListPage.Navigation.defaultNavigation(title: R.string.localizable.gameSaveListTitle(),
                                                       titleIcon: .symbolImage(R.image.viewsavestates_iconSymbols()),
                                                       tools: tools,
                                                       edit: R.string.localizable.selectAll())
    }
    
    private func getListPage() -> ASListPage {
        var sections = [ASListPage.Section]()
        //segment
        let segmentContainerView = UIView()
        segmentContainerView.addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(R.Size.ContentSpaceLarge)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightExtraSmall)
        }
        
        //save states
        sections.append(getSaveStatesSection())
            
        //blankSlate
        if let blankSlateSection = getBlankSlateSection() {
            sections.append(blankSlateSection)
        }
        
        
        return ASListPage(navigation: getNavigation(),
                          top: (segmentContainerView, .fixedHeight(R.Size.ContentSpaceLarge + R.Size.ItemHeightExtraSmall), false),
                          sections: sections,
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset),
                          enableLongPress: true)
    }
    
    private func updateContents() {
        guard let listPageView else { return }
        
        var newSections = [ASListPage.Section]()
        
        newSections.append(getSaveStatesSection())
        if let blankSlateSection = getBlankSlateSection() {
            newSections.append(blankSlateSection)
        }
        listPageView.sections = newSections
    }
    
    private func updateTool() {
        guard let listPageView else { return }
        
        listPageView.tool = getToolView()
    }
    
    private func updateNavigation() {
        guard let listPageView else { return }
        
        var navigation = getNavigation()
        navigation.state = isEditMode ? .edit : .normal
        navigation.edit = isSelectedAll ? R.string.localizable.deSelectAll() : R.string.localizable.selectAll()
        listPageView.navigation = navigation
    }
    
}


extension SaveStateListView: ShowableView {
    static func show(game: Game, hideCompletion: ((GameSaveState?)->Void)? = nil) {
        Self.show(parameters: game)?.hideCompletion = hideCompletion
    }
    
    func didHide() {
        if !hasCallHideCompletion {
            hideCompletion?(nil)
        }
    }
}

extension SaveStateListView: ViewTransition {
    func viewDidTransition() {
        guard let _ = listPageView else { return }
        updateContents()
    }
}
