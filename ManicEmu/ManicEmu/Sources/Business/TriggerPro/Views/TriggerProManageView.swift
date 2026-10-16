//
//  TriggerProManageView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/3.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import RealmSwift

class TriggerProManageView: BaseView {
    private var allTriggers: Results<Trigger> = {
        let realm = Database.realm
        let triggers = realm.objects(Trigger.self).where { !$0.isDeleted }
        return triggers
    }()
    private var datas = [[Trigger]]()
    
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
            if datas.count > 0 {
                return selectedItems.count == datas.reduce(0, { $0 + $1.count })
            }
            return false
        }
        set {
            if newValue {
                selectedItems = Set(datas.enumerated().flatMap({ section, triggers in
                    triggers.indices.map({ row in
                        IndexPath(row: row, section: section)
                    })
                })
)
            } else {
                selectedItems.removeAll()
            }
        }
    }
    private var selectedItems = Set<IndexPath>() {
        didSet {
            updateContents()
            updateTool()
            updateNavigation()
        }
    }
    private var selectedDatas: [Trigger] {
        return selectedItems.compactMap({
            guard datas.count > $0.section else {
                return nil
            }
            guard datas[$0.section].count > $0.row else {
                return nil
            }
            return datas[$0.section][$0.row]
        })
    }
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            self.handleAction(action)
        }
        return view
    }()
    
    private var showClose: Bool
    
    private var hideCompletion: (() -> Void)? = nil
    
    private var triggersUpdateToken: NotificationToken? = nil
    
    required init?(parameters: Any...) {
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)
        
        updateDatas()
        
        triggersUpdateToken = allTriggers.observe { [weak self] changes in
            guard let self = self else { return }
            switch changes {
            case .update(_, let deletions, let insertions, let modifications):
                if deletions.count > 0 || insertions.count > 0 {
                    self.updateDatas()
                    if self.allTriggers.count == 0 {
                        self.isEditMode = false
                    } else {
                        self.isSelectedAll = false
                    }
                } else if modifications.count > 0 {
                    self.updateContents()
                }
                
            default:
                break
            }
        }
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    convenience init(showClose: Bool) {
        self.init(parameters: showClose)!
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        triggersUpdateToken = nil
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        guard let hostingWindow else { return }
        if let navigationValue = action.navigationValue {
            //navigation action
            if navigationValue.isTapClose {
                //close
                if showAsSheet {
                    hide()
                }
            } else if let _ =  navigationValue.tapToolsValue {
                //edit mode
                isEditMode = true
            } else if navigationValue.isTapEdit {
                //selected/deselected all
                isSelectedAll.toggle()
            } else if navigationValue.isTapCancel {
                //leave edit mode
                isEditMode = false
            }
        } else if let toolValue = action.toolValue {
            if toolValue.isTapMain {
                guard let trigger = self.selectedDatas.first else { return }
                
                var options = [ASListPage.Cell.iconTitleChevronCell(icon: .symbolImage(R.image.copy_iconSymbols()),
                                                                    title: R.string.localizable.copy())]
                if selectedDatas.count == 1 {
                    options.append(.iconTitleChevronCell(icon: .symbolImage(R.image.edit_iconSymbols()),
                                                         title: R.string.localizable.editTitle()))
                    
                    options.append(.iconTitleChevronCell(icon: .symbolImage(R.image.controller_iconSymbols()),
                                                         title: R.string.localizable.moreGamesSetting()))
                    
                    let triggerProValue = Prefference.defalut.getPrefference(kind: .triggerPro, storeKey: .gameType(gameType: trigger.gameType))?.triggerProValue ?? -1
                    let isSelected = triggerProValue == trigger.id
                    options.append(.iconTitleDetailCheckCell(icon: .symbolImage(R.image.category_iconSymbols()),
                                                             title: R.string.localizable.setForPlatfrom(trigger.gameType.localizedShortName),
                                                             isSelected: isSelected))
                }
                
                ChevronSheetView.show(cellOptions: options,
                                      completion: { [weak self] index in
                    guard let self, let index else { return }
                    if index == 0 {
                        //copy
                        Trigger.change { realm in
                            realm.add(self.selectedDatas.map({
                                let newTrigger = $0.copyTrigger(newId: true)
                                if let name = newTrigger.name {
                                    newTrigger.name = name + "_copy"
                                }
                                return newTrigger
                            }))
                        }
                        self.isEditMode = false
                        
                    } else if index == 1 {
                        //edit
                        topViewController(in: hostingWindowScene)?.present(TriggerProPreviewController(gameType: trigger.gameType,
                                                                                 trigger: trigger,
                                                                                 preferredSkinID: PlayViewController.currentSkinID,
                                                                                                       hideControls: PlayViewController.isHideControls,
                                                                                                       window: hostingWindow),
                                                     animated: true)
                    } else if index == 2 {
                        //set up for more games
                        let realm = Database.realm
                        let games = realm.objects(Game.self).where({ $0.gameType == trigger.gameType && !$0.isDeleted })
                        guard games.count > 0 else {
                            UIView.makeToast(message: R.string.localizable.transferPakNoGames())
                            return
                        }
                        let prefference = Prefference.defalut.getGamePrefference(kind: .triggerPro)
                        
                        var cells = [[ASListPage.Cell]]()
                        
                        for game in games {
                            var isSelected = false
                            if let prefference,
                               let key = Prefference.StoreKey.game(gameId: game.id).key,
                               let triggerId = prefference[key],
                               Int(triggerId) == trigger.id {
                                isSelected = true
                            }
                            
                            cells.append([ASListPage.Cell.iconTitleDetailRadioCell(icon: game.gameCoverIcon,
                                                                                   iconSize: R.Size.ButtonMedium,
                                                                                   title: game.displayName,
                                                                                   isSelected: isSelected)])
                        }

                        var sheetStyle: ASSheet.Style = .simpleList(icon: .symbolImage(R.image.controller_iconSymbols()),
                                                                    title: R.string.localizable.moreGamesSetting(),
                                                                    detail: .smallText(R.string.localizable.moreGamesSettingDesc(trigger.name ?? "\(trigger.id)"),
                                                                                       numberOfLines: 0),
                                                                    options: cells)
                        
                        ASSheetView.show(.init(style: sheetStyle), action: { action, updation in
                            if let normalItemValue = action.listPageValue?.normalItemValue {
                                let index = normalItemValue.indexPath.section
                                let game = games[index]
                                let storeKey = Prefference.StoreKey.game(gameId: game.id)
                                let isSelected: Bool
                                if Prefference.defalut.getPrefference(kind: .triggerPro,
                                                                      storeKey: storeKey)?.triggerProValue == trigger.id {
                                    //unselected
                                    Prefference.defalut.deletePrefference(kind: .triggerPro,
                                                                          storeKey: storeKey)
                                    isSelected = false
                                } else {
                                    //selected
                                    Prefference.defalut.storePrefference(kind: .triggerPro,
                                                                         storeKey: storeKey,
                                                                         storeValue: "\(trigger.id)")
                                    isSelected = true
                                }
                                
                                if case let .simpleList(icon, title, detail, options, cancelEnable) = sheetStyle {
                                    var cells = options
                                    cells[index][0] = normalItemValue.cellData.updateNormalRadio(isSelected: isSelected)
                                    sheetStyle = .simpleList(icon: icon, title: title, detail: detail, options: cells, cancelEnable: cancelEnable)
                                    updation?(sheetStyle)
                                }
                                return .none
                            }
                            return .dismiss()
                        })
                        
                    } else if index == 3 {
                        //set up for gameType
                        if Prefference.defalut.getPrefference(kind: .triggerPro,
                                                              storeKey: .gameType(gameType: trigger.gameType))?.triggerProValue == trigger.id {
                            //unset
                            Prefference.defalut.deletePrefference(kind: .triggerPro,
                                                                  storeKey: .gameType(gameType: trigger.gameType))
                        } else {
                            //set
                            Prefference.defalut.storePrefference(kind: .triggerPro,
                                                                 storeKey: .gameType(gameType: trigger.gameType),
                                                                 storeValue: "\(trigger.id)")
                        }
                    }
                    
                })
                
            } else if let _ = toolValue.tapOthersValue {
                //delete
                let deleteIds = selectedDatas.map({ "\($0.id)" })
                if isSelectedAll {
                    //delete all
                    UIView.makeAlert(detail: R.string.localizable.removeAllAlert(),
                                     confirmTitle: R.string.localizable.removeTitle(),
                                     confirmAction: { [weak self] in
                        guard let self else { return }
                        self.deleteSelectedTriggers()
                    })
                } else {
                    deleteSelectedTriggers()
                }
                
                deleteIds.forEach({
                    Prefference.defalut.deletePrefference(kind: .triggerPro, value: $0)
                })
            }
            
        } else if let indexPath = action.normalItemValue?.indexPath {
            let trigger = datas[indexPath.section][indexPath.row]
            if isEditMode {
                if selectedItems.contains(indexPath) {
                    //deselected save state
                    selectedItems.remove(indexPath)
                } else {
                    //selected save state
                    selectedItems.insert(indexPath)
                }
            } else {
                topViewController(in: hostingWindowScene)?.present(TriggerProPreviewController(gameType: trigger.gameType,
                                                                                               trigger: trigger,
                                                                                               preferredSkinID: PlayViewController.currentSkinID,
                                                                                               hideControls: PlayViewController.isHideControls,
                                                                                               window: hostingWindow),
                                                                   animated: true)
            }
        } else  if action.isBottom {
            //add trigger
            if !PurchaseManager.isMember, allTriggers.count >= R.Numbers.NonMemberTriggerProCount {
                topViewController(in: hostingWindowScene)?.present(PurchaseViewController(), animated: true)
                return
            }
            
            let allGameTypes = System.allGameTypes.filter({ !$0.externalType })
            ChevronSheetView.show(icon: .symbolImage(R.image.category_iconSymbols()),
                                  title: R.string.localizable.platformSelectionTitle(),
                                  stringOptions: allGameTypes.map({ $0.localizedShortName }),
                                  completion: { [weak self] index in
                guard let self else { return }
                guard let index else { return }
                topViewController(in: self.hostingWindowScene)?.present(TriggerProPreviewController(gameType: allGameTypes[index],
                                                                                                    preferredSkinID: PlayViewController.currentSkinID,
                                                                                                    hideControls: PlayViewController.isHideControls,
                                                                                                    window: hostingWindow),
                                                                        animated: true)
            })
        } else if let indexPath = action.longPressValue {
            guard !isEditMode else { return }
            isEditMode = true
            selectedItems.insert(indexPath)
        }
    }
    
    private func getSections() -> [ASListPage.Section] {
        if isEditMode {
            return datas.enumerated().map({ section, triggers in
                ASListPage.Section(cells: triggers.enumerated().map({ row, trigger in
                    ASListPage.Cell.iconTitleDetailRadioCell(title: trigger.triggerProName,
                                                             isSelected: selectedItems.contains(IndexPath(row: row, section: section)))
                }), header: .defaultHeader(title: triggers.first?.gameType.localizedShortName ?? ""))
            })
        } else {
            return datas.enumerated().map({ section, triggers in
                ASListPage.Section(cells: triggers.enumerated().map({ row, trigger in
                    ASListPage.Cell.iconTitleChevronCell(title: trigger.triggerProName)
                }), header: .defaultHeader(title: triggers.first?.gameType.localizedShortName ?? ""))
            })
        }
    }
    
    private func getToolView() -> ASListPage.Tool? {
        if selectedItems.count > 0 {
            return ASListPage.Tool.defaultTool(otherIcons: [
                .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red])
            ])
        }
        return nil
    }
    
    private func getNavigation() -> ASListPage.Navigation {
        var navigation = ASListPage.Navigation.defaultNavigation(title: "TriggerPro",
                                                                 titleIcon: .symbolImage(R.image.triggerpro_iconSymbols()),
                                                                 tools: datas.count > 0 ? [.symbolImage(R.image.selectedit_iconSymbols())] : [],
                                                                 edit: R.string.localizable.selectAll())
        navigation.enableClose = showClose
        return navigation
    }
    
    private func getListPage() -> ASListPage {
        let listInsetBottom = (UIDevice.isPad && !showClose) ? R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceMedium : 0
        
        return ASListPage(navigation: getNavigation(),
                          sections: getSections(),
                          bottom: .large(title: R.string.localizable.addTriggerPro(),
                                                             titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                                             titleAlignment: .center,
                                                             background: R.Color.Main),
                          blankSlate: .init(),
                          backgroundColor: .clear,
                          listInsets: .insets(bottom: listInsetBottom),
                          pageInsets: .insets(top: showClose ? R.Size.SheetGrabberTopInset : R.Size.ContentInsetTop(window: hostingWindow)),
                          enableLongPress: true)
    }
    
    private func updateDatas() {
        let predefinedOrder = System.allGameTypes.filter({ !$0.externalType })
        datas = allTriggers.grouped(by: { $0.gameType }).sorted(by: {
            if let lTrigger = $0.first,
               let rTrigger = $1.first,
               let left = predefinedOrder.firstIndex(of: lTrigger.gameType),
               let right = predefinedOrder.firstIndex(of: rTrigger.gameType) {
                return left < right
            }
            return false
        })
    }
    
    private func updateContents() {
        listPageView.sections = getSections()
    }
    
    private func updateTool() {
        listPageView.tool = getToolView()
    }
    
    private func updateNavigation() {
        var navigation = getNavigation()
        navigation.state = isEditMode ? .edit : .normal
        navigation.edit = isSelectedAll ? R.string.localizable.deSelectAll() : R.string.localizable.selectAll()
        listPageView.navigation = navigation
    }
    
    private func deleteSelectedTriggers() {
        Trigger.change { realm in
            if Settings.defalut.iCloudSyncEnable {
                selectedDatas.forEach({ triger in
                    triger.isDeleted = true
                    triger.items.forEach({
                        $0.customImage?.deleteAndClean(realm: realm)
                        $0.isDeleted = true
                    })
                })
            } else {
                selectedDatas.forEach({ trigger in
                    trigger.items.forEach({ $0.customImage?.deleteAndClean(realm: realm) })
                    realm.delete(trigger.items)
                })
                realm.delete(selectedDatas)
            }
        }
    }
}

extension TriggerProManageView: ShowableView {
    static func show(hideCompletion: (() -> Void)?) {
        Self.show()?.hideCompletion = hideCompletion
    }
    
    func didHide() {
        hideCompletion?()
    }
}
