//
//  CheatCodeListView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift
import UniformTypeIdentifiers

class CheatCodeListView: BaseView {
    private let game: Game
    private let isFBNeoGame: Bool
    private let gameCheats: Results<GameCheat>?
    private var fbNeoCheats = [GameCheat]()
    private var datas: [GameCheat] {
        if isFBNeoGame {
            return sortCheats(fbNeoCheats)
        } else if let gameCheats {
            return sortCheats(Array(gameCheats))
        } else {
            return []
        }
    }
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
                return selectedItems.count == datas.count
            }
            return false
        }
        set {
            if newValue {
                selectedItems = Set(datas.map({ $0.id }))
            } else {
                selectedItems.removeAll()
            }
        }
    }
    private var selectedItems = Set<Int>() {
        didSet {
            updateContents()
            updateTool()
            updateNavigation()
        }
    }
    private var selectedDatas: [GameCheat] {
        return datas.filter({
            selectedItems.contains($0.id)
        })
    }
    
    private var hideCompletion: (() -> Void)? = nil
    
    private var listPageView: ASListPageView? = nil
    
    private var gamesCheatsUpdateToken: NotificationToken? = nil
    
    required init?(parameters: Any...) {
        guard let game = parameters.compactMap({ $0 as? Game }).first else { return nil }
        self.game = game
        let isFBNeo = game.gameType == .arcade && game.defaultCore == 1
        if isFBNeo {
            if let configs = LibretroCore.sharedInstance().getConfigs(EmulationCore.FinalBurnNeo.name),
               PlayViewController.isGaming {
                var tuples = [(key: String, enable: Bool, name: String)]()
                configs.enumerateLines { line, stop in
                    if line.hasPrefix("fbneo-cheat-") {
                        let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                        if parts.count == 2 {
                            let key = parts[0]
                            let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            let keyComponents = key.split(separator: "-")
                            if keyComponents.count >= 4 {
                                tuples.append((key: key, enable: value != "0 - Disabled", name: String(keyComponents[4])))
                            }
                        }
                    }
                }
                
                self.fbNeoCheats = tuples.map({
                    let cheatCode = GameCheat()
                    cheatCode.name = $0.name
                    cheatCode.code = $0.key
                    cheatCode.activate = $0.enable
                    return cheatCode
                })
            }
            self.gameCheats = nil
        } else {
            self.gameCheats = game.gameCheats.where({ !$0.isDeleted })
        }
        self.isFBNeoGame = isFBNeo
        super.init(frame: .zero)
        
        if !isFBNeoGame {
            gamesCheatsUpdateToken = gameCheats?.observe { [weak self] changes in
                guard let self = self else { return }
                switch changes {
                case .update(_, let deletions, let insertions, let modifications):
                    if !deletions.isEmpty || !insertions.isEmpty || !modifications.isEmpty {
                        self.updateNavigation()
                        self.updateContents()
                        DolphinCheatINI.sync(game: self.game)
                    }
                default:
                    break
                }
            }
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
        DolphinCheatINI.sync(game: game)
    }
    
    convenience init(game: Game) {
        self.init(parameters: game)!
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let gamesCheatsUpdateToken = gamesCheatsUpdateToken {
            NotificationCenter.default.removeObserver(gamesCheatsUpdateToken)
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
                if datas.count > 0, index == 0 {
                    //edit mode
                    isEditMode = true
                } else if index == 1 {
                    //sort
                    var selectedIndex: Int? = nil
                    let options = GameCheatSortType.allCases.enumerated().map({ index, type in
                        let currentType = GameCheatSortType(rawValue: Settings.defalut.getExtraInt(key: ExtraKey.cheatSort.rawValue) ?? 0) ?? .dateAscending
                        if currentType == type {
                            selectedIndex = index
                        }
                        return type.title
                    })
                    
                    OptionsSheetView.show(icon: .symbolImage(R.image.sort_iocnSymbols()),
                                          title: R.string.localizable.gameSortType(),
                                          options: options,
                                          selectedIndex: selectedIndex, completion: { [weak self] optionIndex in
                        guard let self, let optionIndex else { return }
                        Settings.defalut.updateExtra(key: ExtraKey.cheatSort.rawValue, value: optionIndex)
                        self.updateContents()
                    })
                } else if (datas.count == 0 && index == 0) || index == 2 {
                    //search
                    UIView.makeAlert(title: R.string.localizable.searchCheatCodes(),
                                     detail: R.string.localizable.jumpThirdPartAlert(),
                                     cancelTitle: R.string.localizable.gotIt(),
                                     cancelAction: { [weak self] in
                        guard let self else { return }
                        GamehackingView.show(game: self.game)
                    })
                    
                } else if (datas.count == 0 && index == 2) || index == 3 {
                    //more...
                    var cheatFileExtension = ""
                    var supportFileExtensions: [UTType] = []
                    if game.gameType == ._3ds {
                        cheatFileExtension = ".txt"
                        supportFileExtensions.append(UTType(filenameExtension: "txt")!)
                    } else if game.gameType == .psp {
                        cheatFileExtension = ".db .ini"
                        supportFileExtensions.append(UTType(filenameExtension: "db")!)
                        supportFileExtensions.append(UTType(filenameExtension: "ini")!)
                    }
                    ChevronSheetView.show(stringOptions: [R.string.localizable.tabbarTitleImport() + " \(cheatFileExtension)"], completion: { [weak self] optionIndex in
                        guard let self, optionIndex != nil else { return }
                        FilesImporter.shared.presentImportController(supportedTypes: supportFileExtensions, manualHandle: { [weak self] urls in
                            guard let self else { return }
                            self.parseImportCheatFiles(urls: urls)
                        }, in: self.hostingWindowScene)
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
                ChevronSheetView.show(stringOptions: [
                    R.string.localizable.enableSelectedCheatCodes(),
                    R.string.localizable.disableSelectedCheatCodes(),
                ], completion: { [weak self] index in
                    guard let self, let index else { return }
                    self.setCheats(self.selectedDatas, activate: index == 0)
                    self.isEditMode = false
                })
                
            } else if let index = toolValue.tapOthersValue {
                if index == 0 {
                    //delete
                    if selectedItems.count == datas.count {
                        //delete all
                        UIView.makeAlert(detail: R.string.localizable.removeAllCheatsAlert(),
                                         confirmTitle: R.string.localizable.removeTitle(),
                                         confirmAction: { [weak self] in
                            guard let self else { return }
                            self.deleteSelectedCheats()
                        })
                        
                    } else {
                        //delete some
                        deleteSelectedCheats()
                    }
                } else if index == 1 {
                    //edit
                    guard let cheat = selectedDatas.first else { return }
                    AddCheatCodeView.show(game: game, editGameCheat: cheat)
                }
            }
            
        } else if let index = action.normalItemValue?.indexPath.section {
            let cheat = datas[index]
            if let switchState = action.normalItemValue?.subActions?.itemStyle.switchValue?.state {
                setCheats([cheat], activate: switchState == .on ? true : false, notifying: false)
            } else if action.normalItemValue?.subActions == nil {
                if isEditMode {
                    if selectedItems.contains(cheat.id) {
                        //deselected save state
                        selectedItems.remove(cheat.id)
                    } else {
                        //selected save state
                        selectedItems.insert(cheat.id)
                    }
                } else {
                    AddCheatCodeView.show(game: game, editGameCheat: cheat)
                }
            }
        } else  if action.isBottom {
            if !PurchaseManager.isMember, datas.count >= R.Numbers.NonMemberCheatCodeCount {
                topViewController(in: hostingWindowScene)?.present(PurchaseViewController(), animated: true)
                return
            }
            AddCheatCodeView.show(game: game)
        } else if let index = action.longPressValue?.section {
            guard !isEditMode else { return }
            let cheat = datas[index]
            isEditMode = true
            selectedItems.insert(cheat.id)
        }
    }
    
    private func getSections() -> [ASListPage.Section] {
        if isEditMode {
            return datas.map({
                ASListPage.Section(cells: [
                    .iconTitleDetailRadioCell(title: $0.name,
                                              isSelected: selectedItems.contains($0.id))
                ])
            })
        } else {
            return datas.map({
                ASListPage.Section(cells: [
                    .iconTitleDetailSwitchCell(title: $0.name,
                                               state: $0.activate ? .on : .off)
                ])
            })
        }
    }
    
    private func getToolView() -> ASListPage.Tool? {
        if selectedItems.count > 0 {
            if selectedItems.count == 1 {
                return ASListPage.Tool.defaultTool(otherIcons: [
                    .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
                    .symbolImage(R.image.edit_iconSymbols())
                ])
            } else {
                return ASListPage.Tool.defaultTool(otherIcons: [
                    .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red])
                ])
            }
        }
        return nil
    }
    
    private func getBlankSlate() -> ASListPage.BlankSlate? {
        guard datas.count == 0 else { return nil }
        
        if isFBNeoGame {
            return .init(icon: .image(R.image.cheatcode_empty_icon()),
                         title: R.string.localizable.fbNeoNoCheats())
            
        } else {
            return .init(icon: .image(R.image.cheatcode_empty_icon()),
                         title: R.string.localizable.cheatCodeEmptyTitle(),
                         detail: R.string.localizable.addCheatCodesDesc(),
                         layoutInsets: .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.ButtonExtraLarge))
        }
    }
    
    private func getNavigation() -> ASListPage.Navigation {
        var tools: [ASIcon]
        if isFBNeoGame {
            tools = []
        } else if datas.count == 0 {
            tools = [.symbolImage(R.image.searchRegular_iconSymbols())]
        } else {
            tools = [.symbolImage(R.image.selectedit_iconSymbols()),
                     .symbolImage(R.image.sort_iocnSymbols()),
                     .symbolImage(R.image.searchRegular_iconSymbols())]
        }
        
        if game.gameType == ._3ds || game.gameType == .psp {
            tools.append(.symbolImage(R.image.ellipsis_iconSymbols()))
        }
        let navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.gamesCheatCode(),
                                                                 titleIcon: .symbolImage(R.image.cheat_iconSymbols()),
                                                                 tools: tools,
                                                                 edit: isFBNeoGame ? nil : R.string.localizable.selectAll())
        return navigation
    }
    
    private func getListPage() -> ASListPage {
        return ASListPage(navigation: getNavigation(),
                          sections: getSections(),
                          bottom: isFBNeoGame ? nil : .large(title: R.string.localizable.addCheatCodes(),
                                                             titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                                             titleAlignment: .center,
                                                             background: R.Color.Main),
                          blankSlate: getBlankSlate(),
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset),
                          enableLongPress: true)
    }
    
    private func updateContents() {
        guard let listPageView else { return }
        listPageView.sections = getSections()
        listPageView.blankSlate = getBlankSlate()
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
    
    private func sortCheats(_ cheats: [GameCheat]) -> [GameCheat] {
        let sortType = GameCheatSortType(rawValue: Settings.defalut.getExtraInt(key: ExtraKey.cheatSort.rawValue) ?? 0) ?? .dateAscending
        return  cheats.sorted(by: {
            switch sortType {
            case .nameAscending:
                return $0.name <= $1.name
            case .nameDescending:
                return $0.name > $1.name
            case .dateAscending:
                return $0.id <= $1.id
            case .dateDescending:
                return $0.id > $1.id
            case .status:
                if $0.activate, !$1.activate {
                    return true
                } else {
                    return false
                }
            }
        })
    }
    
    private func deleteSelectedCheats() {
        Game.change { realm in
            if Settings.defalut.iCloudSyncEnable {
                selectedDatas.forEach({ $0.isDeleted = true })
            } else {
                realm.delete(selectedDatas)
            }
        }
        if datas.count == 0, isEditMode {
            isEditMode = false
        }
    }
    
    private func setCheats(_ cheats: [GameCheat], activate: Bool, notifying: Bool = true) {
        func updateGameCheat() {
            if notifying {
                Game.change { realm in
                    cheats.forEach({
                        $0.activate = activate
                    })
                }
            } else if let token = gamesCheatsUpdateToken {
                let realm = Database.realm
                try? realm.write(withoutNotifying: [token], {
                    cheats.forEach({
                        $0.activate = activate
                    })
                })
            }
            DolphinCheatINI.sync(game: game)
        }
        
        if !UserDefaults.standard.bool(forKey: R.DefaultKey.HasShowCheatCodeWarning), activate {
            UIView.makeAlert(title: R.string.localizable.enableCheatCodeAlertTitle(),
                             detail: R.string.localizable.enableCheatCodeAlertDetail(),
                             cancelTitle: R.string.localizable.confirmTitle(),
                             hideAction: { _ in
                UserDefaults.standard.setValue(true, forKey: R.DefaultKey.HasShowCheatCodeWarning)
                updateGameCheat()
            })
        } else {
            updateGameCheat()
        }
    }
    
    private func parseImportCheatFiles(urls: [URL]) {
        guard let gameCheats = gameCheats else { return }
        if game.gameType == ._3ds {
            UIView.makeLoading()
            //解析txt
            var newCheats: [GameCheat] = []
            let supportedCheatFormats = Array(game.gameType.manicEmuCore?.supportedCheatFormats ?? Set())
            var index: Int = 0
            for url in urls {
                if let txt = try? String(contentsOf: url, encoding: .utf8) {
                    let cheats = ThreeDS.parseCheatFile(txt)
                    for cheat in cheats {
                        if !gameCheats.contains(where: { $0.code == cheat.code }),
                           !newCheats.contains(where: { $0.code == cheat.code }),
                           let result = AddCheatCodeView.checkCheat(cheatCode: cheat.code, supportedCheatFormats: supportedCheatFormats) {
                            let gameCheat = GameCheat()
                            gameCheat.id += index
                            gameCheat.name = cheat.name
                            gameCheat.code = result.formatString
                            gameCheat.type = result.cheatFormat.type.rawValue
                            newCheats.append(gameCheat)
                            index += 1
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                UIView.hideLoading()
            }
            if newCheats.count > 0 {
                Game.change { realm in
                    game.gameCheats.append(objectsIn: newCheats)
                }
            } else {
                UIView.makeToast(message: R.string.localizable.cheatImportFailed())
            }
            
        } else if game.gameType == .psp {
            guard let gameCodeForPSP = game.gameCodeForPSP else {
                UIView.makeToast(message: R.string.localizable.cheatImportFailed())
                return
            }
            UIView.makeLoading()
            var cheats: [PSP.GameCheat] = []
            for url in urls {
                if let txt = try? String(contentsOf: url, encoding: .utf8) {
                    cheats.append(contentsOf: PSP.parseCheatFiles(content: txt))
                }
            }
            if cheats.count > 0 {
                for cheat in cheats {
                    if cheat.gameCode.trimedExceptNumberAndLetters() == gameCodeForPSP {
                        var newCheats: [GameCheat] = []
                        var index = 0
                        for c in cheat.cheats {
                            if !gameCheats.contains(where: { $0.code == c.code }),
                               !newCheats.contains(where: { $0.code == c.code }) {
                                let gameCheat = GameCheat()
                                gameCheat.id += index
                                gameCheat.name = c.name
                                gameCheat.code = c.code
                                gameCheat.type = CheatType.cwCheat.rawValue
                                newCheats.append(gameCheat)
                                index += 1
                            }
                        }
                        if newCheats.count > 0 {
                            Game.change { realm in
                                game.gameCheats.append(objectsIn: newCheats)
                            }
                        }
                        
                        break
                    }
                }
            }
            
            DispatchQueue.main.async {
                UIView.hideLoading()
            }
            if cheats.count == 0 {
                UIView.makeToast(message: R.string.localizable.cheatImportFailed())
            }
        }
    }
    
}

extension CheatCodeListView: ShowableView {
    static func show(game: Game, hideCompletion: (() -> Void)? = nil) {
        let view = Self.show(parameters: game)
        view?.hideCompletion = hideCompletion
        
    }
    
    func didHide() {
        hideCompletion?()
    }
}
