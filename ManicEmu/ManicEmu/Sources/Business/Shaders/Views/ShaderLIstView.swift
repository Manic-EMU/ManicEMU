//
//  ShaderLIstView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/25.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import RealmSwift
import Fuse

typealias ShaderListSection = (sectionTitle: String, shaders: [Shader])
typealias ShaderListData = [ShaderListView.ShaderSource: [ShaderListSection]]

class ShaderListView: BaseView {
    enum ShaderSource: Int, CaseIterable {
        case `default`, retroarch, imported, custom
        
        var title: String {
            switch self {
            case .default:
                R.string.localizable.default()
            case .retroarch:
                "RetroArch"
            case .imported:
                R.string.localizable.tabbarTitleImport()
            case .custom:
                R.string.localizable.custom()
            }
        }
        
        var searchUrl: URL {
            switch self {
            case .default:
                URL(fileURLWithPath: R.Path.ShaderDefault)
            case .retroarch:
                URL(fileURLWithPath: R.Path.ShaderRetroArch)
            case .imported:
                URL(fileURLWithPath: R.Path.ShaderImported)
            case .custom:
                URL(fileURLWithPath: R.Path.Shaders)
            }
        }
        
        func belongSource(shader: Shader) -> Bool {
            switch self {
            case .default:
                return shader.filePath.contains(R.Path.ShaderDefault)
                
            case .retroarch:
                return shader.filePath.contains(R.Path.ShaderRetroArch)
                
            case .imported:
                return shader.filePath.contains(R.Path.ShaderImported)
                
            case .custom:
                let filePath = shader.filePath
                return !filePath.contains(R.Path.ShaderDefault) && !filePath.contains(R.Path.ShaderRetroArch) && !filePath.contains(R.Path.ShaderImported)
            }
        }
    }
    
    enum InitType {
        case normal, gamePlay, preview
    }
    
    private var initType: InitType
    private var isGlsl: Bool
    private var usingShader: Shader? = nil
    private var previewShader: Shader? = nil {
        didSet {
            previewView.shader = previewShader
        }
    }
    private var showClose: Bool = true
    private var games = [Game]()
    private var gameplaySnapshot: UIImage? = nil
    private var isSearch: Bool = false
    private var normalShaderData = ShaderListData()
    private var searchShaderData = ShaderListData()
    private var currentSource: ShaderSource {
        return ShaderSource(rawValue: segmentView.segment.index) ?? .default
    }
    private var currentShaderData: ShaderListData {
        return isSearch ? searchShaderData : normalShaderData
    }
    private var currentShaderSections: [ShaderListSection] {
        currentShaderData[currentSource] ?? []
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
            let shadersCount = currentShaderSections.reduce(0, { $0 + $1.shaders.count })
            if shadersCount > 0 {
                return selectedItems.count == shadersCount
            }
            return false
        }
        set {
            if newValue {
                selectedItems = Set(currentShaderSections.enumerated().flatMap({ sectionIndex, section in
                    section.shaders.indices.map({ shaderIndex in
                        IndexPath(row: shaderIndex, section: sectionIndex)
                    })
                }))
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
    private var selectedShaders: [Shader] {
        return selectedItems.compactMap({
            guard currentShaderSections.count > $0.section else {
                return nil
            }
            guard currentShaderSections[$0.section].shaders.count > $0.row else {
                return nil
            }
            return currentShaderSections[$0.section].shaders[$0.row]
        })
    }
    
    private var beginDownloadNotification: Any? = nil
    private var stopDownloadNotification: Any? = nil
    private var retroArchShadersDownloadSuccess: Any? = nil
    
    var didSelectShaderForPreview: ((Shader)->Void)? = nil
    var hideCompletion: (() -> Void)? = nil
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(getNavigation())
        view.didTapClose = { [weak self] in
            guard let self else { return }
            self.hide()
        }
        view.didTapTools = { [weak self] index in
            guard let self else { return }
            switch currentSource {
            case .default:
                //edit
                isEditMode = true
                
            case .retroarch:
                if index == 0 && currentShaderSections.count > 0 {
                    //edit
                    isEditMode = true
                } else if (index == 1 && currentShaderSections.count > 0) ||
                            (index == 0 && currentShaderSections.count == 0) {
                    //refresh retroarch shaders
                    downloadRetroarchShaders()
                    
                } else if (index == 2 && currentShaderSections.count > 0) ||
                            (index == 1 && currentShaderSections.count == 0) {
                    //download manager
                    DownloadManageView.show()
                }
                
            case .imported:
                if index == 0 && currentShaderSections.count > 0 {
                    //edit
                    isEditMode = true
                } else if index == 1 || (currentShaderSections.count == 0 && index == 0) {
                    //import
                    UIView.makeAlert(detail: R.string.localizable.importShader(), cancelTitle: R.string.localizable.confirmTitle())
                }
                
            case .custom:
                if currentShaderSections.count > 0 {
                    isEditMode = true
                }
            }
        }
        view.didTapEdit = { [weak self] in
            guard let self else { return }
            self.isSelectedAll.toggle()
        }
        view.didTapCancel = { [weak self] in
            guard let self else { return }
            self.isEditMode = false
        }
        return view
    }()
    
    private lazy var searchView: ASListInputView = {
        var input = ASInput.small(placeholder: R.string.localizable.readyEditCoverSearch() + R.string.localizable.shaders(),
                                  icon: .symbolImage(R.image.searchRegular_iconSymbols()))
        input.returnKeyType = .search
        let view = ASListInputView(input)
        view.didTapClear = { [weak self] in
            guard let self = self else { return }
            self.stopSearchShaders()
        }
        view.didTapReturn = { [weak self] text in
            guard let self = self else { return }
            self.searchView.resignFirstResponder()
            if let text = text?.trimmed, !text.isEmpty {
                self.startSearchShaders()
            } else {
                self.stopSearchShaders()
            }
        }
        return view
    }()
    
    private lazy var segmentView: ASSegmentView = {
        let view = ASSegmentView(.textSegment(titles: ShaderSource.allCases.map({ $0.title })))
        view.didSelectIndex = { [weak self] index in
            guard let self, let source = ShaderSource(rawValue: index) else { return }
            if self.currentShaderData[source] == nil {
                self.isEditMode = false
                self.loadShader()
            } else {
                if self.currentShaderSections.count == 0, self.isEditMode {
                    self.isEditMode = false
                } else {
                    self.selectedItems.removeAll()
                }
            }
        }
        return view
    }()
    
    private lazy var previewView: ShaderPreviewView = {
        var dimensions: CGSize? = nil
        if games.count > 0 {
            dimensions = games.first?.gameType.manicEmuCore?.videoFormat.dimensions
        }
        let view = ShaderPreviewView(dimensions: dimensions, image: gameplaySnapshot, shader: previewShader)
        return view
    }()
    
    private lazy var topView: UIView = {
        let topView = UIView()
        topView.addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.top.equalTo(R.Size.ContentSpaceExtraSmall)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightTiny)
        }
        
        topView.addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom).offset(R.Size.ContentSpaceMedium)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightExtraSmall)
        }
        
        return topView
    }()
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            self.handleAction(action)
        }
        return view
    }()
    
    deinit {
        if let beginDownloadNotification = beginDownloadNotification {
            NotificationCenter.default.removeObserver(beginDownloadNotification)
        }
        if let stopDownloadNotification = stopDownloadNotification {
            NotificationCenter.default.removeObserver(stopDownloadNotification)
        }
        if let retroArchShadersDownloadSuccess {
            NotificationCenter.default.removeObserver(retroArchShadersDownloadSuccess)
        }
    }
    
    required init?(parameters: Any...) {
        guard let initType = parameters.compactMap({ $0 as? InitType }).first else { return nil }
        self.initType = initType
        let bools = parameters.compactMap({ $0 as? Bool })
        guard let isGlsl = bools.first else { return nil }
        self.isGlsl = isGlsl
        super.init(frame: .zero)
        var games = parameters.compactMap({ $0 as? Game })
        games += (parameters.compactMap({ $0 as? [Game] }).first ?? [])
        self.games = games
        self.gameplaySnapshot = parameters.compactMap({ $0 as? UIImage }).first
        self.showClose = bools.count > 1 ? (bools.last ?? true) : true
        
        updateUsingShader(reloadViews: false)
        if let usingShader {
            self.previewShader = usingShader
        } else {
            self.previewShader = ShaderManager.genOriginalShader()
        }
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            if showClose {
                make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            } else {
                make.top.equalToSuperview().offset(R.Size.ContentInsetTop(window: hostingWindow))
            }
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(listPageView)
        
        loadShader { [weak self] in
            self?.updateNavigation()
        }
        
        beginDownloadNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.BeginDownload, object: nil, queue: .main) { [weak self] notification in
            guard let self, self.currentSource == .retroarch else { return }
            self.updateNavigation()
        }
        
        stopDownloadNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.StopDownload, object: nil, queue: .main) { [weak self] notification in
            guard let self, self.currentSource == .retroarch else { return }
            self.updateNavigation()
        }
        
        retroArchShadersDownloadSuccess = NotificationCenter.default.addObserver(forName: R.NotificationName.RetroArchShadersDownloadSuccess, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.normalShaderData[.retroarch] = nil
            if self.currentSource == .retroarch {
                self.loadShader()
            }
        }
    }
    
    convenience init(initType: InitType,
                     isGlsl: Bool = false,
                     showClose: Bool = true) {
        self.init(parameters: initType, isGlsl, showClose)!
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateViewsContraits()
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if let toolValue = action.toolValue {
            if toolValue.isTapMain {
                //more settings
                // set for more games
                // set for platform
                // set for global
                guard selectedShaders.count > 0 else { return }
                let selectedShader = selectedShaders.first!
                let globalShader = Prefference.defalut.getPrefference(kind: .shader, storeKey: .shaderKey(isGlsl: isGlsl))?.shaderValue
                var isGlobalSetting = false
                if selectedShader.relativePath == globalShader {
                    isGlobalSetting = true
                }
                
                ChevronSheetView.show(cellOptions: [
                    .iconTitleChevronCell(icon: .symbolImage(R.image.controller_iconSymbols()),
                                          title: R.string.localizable.moreGamesSetting()),
                    .iconTitleChevronCell(icon: .symbolImage(R.image.category_iconSymbols()),
                                          title: R.string.localizable.morePlatformSetting()),
                    .iconTitleDetailCheckCell(icon: .symbolImage(R.image.language_iconSymbols()),
                                              title: R.string.localizable.updateBackgroundForGlobal(),
                                              isSelected: isGlobalSetting)
                ], completion: { [weak self] index in
                    guard let self else { return }
                    if index == 0 {
                        // set for more games
                        self.showMoreGamesSetting(selectedShader: selectedShader)
                        
                    } else if index == 1 {
                        // set for platform
                        self.showPlatformSetting(selectedShader: selectedShader)
                        
                    } else if index == 2 {
                        // set for global
                        Prefference.defalut.storePrefference(kind: .shader,
                                                             storeKey: .shaderKey(isGlsl: self.isGlsl),
                                                             storeValue: selectedShader.relativePath)
                        self.updateUsingShader(reloadViews: true)
                        
                    }
                })
            } else if let index = toolValue.tapOthersValue {
                if (currentSource == .default && index == 0) || index == 1 {
                    //edit shader
                    guard selectedShaders.count > 0 else { return }
                    let selectedShader = selectedShaders.first!
                    showShaderInfoView(shader: selectedShader)
                    
                } else if index == 0 && currentSource != .default {
                    //delete selected shaders
                    guard selectedShaders.count > 0 else { return }
                    selectedShaders.forEach({
                        try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: $0.filePath))
                    })
                    loadShader()
                }
            }
        } else if let indexPath = action.normalItemValue?.indexPath {
            let shader = currentShaderSections[indexPath.section].shaders[indexPath.row]
            if let _ = action.normalItemValue?.subActions?.itemStyle.buttonValue {
                //preview
                if let previewShader {
                    if previewShader.relativePath != shader.relativePath {
                        self.previewShader = shader
                    }
                } else {
                    previewShader = shader
                }
                updateContents()
                
            } else if action.normalItemValue?.subActions == nil {
                if isEditMode {
                    if selectedItems.contains(indexPath) {
                        //deselected
                        selectedItems.remove(indexPath)
                    } else {
                        //selected
                        selectedItems.insert(indexPath)
                    }
                } else {
                    switch initType {
                    case .normal, .gamePlay:
                        if games.count > 0 {
                            //set games shader
                            games.forEach({
                                Prefference.defalut.storePrefference(kind: .shader,
                                                                     storeKey: .shaderKey(gameId: $0.id, isGlsl: isGlsl),
                                                                     storeValue: shader.relativePath)
                            })
                            updateUsingShader(reloadViews: true)
                            
                        } else {
                            //set global shader
                            UIView.makeAlert(detail: R.string.localizable.globalSettingAlert(),
                                             confirmTitle: R.string.localizable.confirmTitle(),
                                             confirmAction: { [weak self] in
                                guard let self else { return }
                                Prefference.defalut.storePrefference(kind: .shader,
                                                                     storeKey: .shaderKey(isGlsl: self.isGlsl),
                                                                     storeValue: shader.relativePath)
                                updateUsingShader(reloadViews: true)
                            })
                        }
                        
                    case .preview:
                        //select shader
                        didSelectShaderForPreview?(shader)
                        if showAsSheet {
                            self.hide()
                        }
                    }
                }
            }
        } else if action.isBlankSlate {
            switch currentSource {
            case .retroarch:
                downloadRetroarchShaders()
            default:
                break
            }
        } else if let indexPath = action.longPressValue {
            guard !isEditMode else { return }
            isEditMode = true
            selectedItems.insert(indexPath)
        }
    }
    
    private func showMoreGamesSetting(selectedShader: Shader) {
        //set up for more games
        let realm = Database.realm
        let games = realm.objects(Game.self).where({ !$0.isDeleted })
        guard games.count > 0 else {
            UIView.makeToast(message: R.string.localizable.transferPakNoGames())
            return
        }
        
        let prefference = Prefference.defalut.getGamePrefference(kind: .shader)
        
        var datas = [[Game]]()
        var sections = [ASListPage.Section]()
        let groupGames = Dictionary(grouping: games, by: {
            $0.gameType
        })
        System.allGameTypes.forEach({ sortGameType in
            if let games = groupGames[sortGameType] {
                datas.append(games)
                let cells = games.map({ game in
                    var isSelected = false
                    if let prefference,
                       let key = Prefference.StoreKey.shaderKey(gameId: game.id, isGlsl: self.isGlsl).key,
                       let shaderPath = prefference[key],
                       shaderPath == selectedShader.relativePath {
                        isSelected = true
                    }
                    
                    return ASListPage.Cell.iconTitleDetailRadioCell(icon: game.gameCoverIcon,
                                                                    iconSize: R.Size.ButtonMedium,
                                                                    title: game.displayName,
                                                                    isSelected: isSelected)
                })
                var headerTitle = sortGameType.localizedShortName
                if R.Style.GamesGroupTitleStyle == .fullName {
                    headerTitle = sortGameType.localizedName
                }
                sections.append(ASListPage.Section(cells: cells, header: .defaultHeader(title: headerTitle)))
            }
        })
        
        let navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.moreGamesSetting(),
                                                                 titleIcon: .symbolImage(R.image.controller_iconSymbols()))
        let topView = ASLabelView(text: .smallText("\(R.string.localizable.moreGamesSettingDesc(selectedShader.title))\n",
                                                    numberOfLines: 0))
        let listPage = ASListPage(navigation: navigation,
                                  top: (topView, .autoLayout , true),
                                  sections: sections)
        var sheetStyle: ASSheet.Style = .listPage(listPage)
        
        ASSheetView.show(.init(style: sheetStyle), action: { [weak self] action, updation in
            guard let self else { return .dismiss() }
            if let normalItemValue = action.listPageValue?.normalItemValue {
                let indexPath = normalItemValue.indexPath
                let game = datas[indexPath.section][indexPath.row]
                let storeKey = Prefference.StoreKey.shaderKey(gameId: game.id, isGlsl: self.isGlsl)
                let isSelected: Bool
                if Prefference.defalut.getPrefference(kind: .shader, storeKey: storeKey)?.shaderValue == selectedShader.relativePath {
                    //unselected
                    Prefference.defalut.deletePrefference(kind: .shader, storeKey: storeKey)
                    isSelected = false
                } else {
                    //selected
                    Prefference.defalut.storePrefference(kind: .shader, storeKey: storeKey, storeValue: selectedShader.relativePath)
                    isSelected = true
                }
                
                if case var .listPage(listPage) = sheetStyle {
                    listPage.sections[indexPath.section].cells[indexPath.row] = normalItemValue.cellData.updateNormalRadio(isSelected: isSelected)
                    sheetStyle = .listPage(listPage)
                    updation?(sheetStyle)
                }
                return .none
            }
            return .dismiss(completion: { [weak self] in
                guard let self else { return }
                self.updateUsingShader(reloadViews: true)
            })
        })
    }
    
    private func showPlatformSetting(selectedShader: Shader) {
        //set for platform
        let gameTypes = System.allGameTypes.filter({
            if isGlsl {
                return $0 == .n64
            } else {
                return !$0.externalType
            }
        })
        
        guard gameTypes.count > 0 else { return }
        
        let prefference = Prefference.defalut.getGameTypePrefference(kind: .shader)
        
        let cells: [[ASListPage.Cell]] = gameTypes.map({
            var isSelected = false
            if let prefference,
               let key = Prefference.StoreKey.shaderKey(gameType: $0, isGlsl: isGlsl).key {
                let shaderPath = prefference[key]
                if shaderPath == selectedShader.relativePath {
                    isSelected = true
                }
            }
            return [.iconTitleDetailRadioCell(title: $0.localizedShortName,
                                              isSelected: isSelected)]
        })
        
        var sheetStyle: ASSheet.Style = .simpleList(icon: .symbolImage(R.image.category_iconSymbols()),
                                                    title: R.string.localizable.morePlatformSetting(),
                                                    detail: .smallText(R.string.localizable.morePlatformSettingDesc(selectedShader.title),
                                                                       numberOfLines: 0),
                                                    options: cells)
        
        ASSheetView.show(.init(style: sheetStyle), action: { [weak self] action, updation in
            guard let self else { return .dismiss() }
            if let normalItemValue = action.listPageValue?.normalItemValue {
                
                let index = normalItemValue.indexPath.section
                let gameType = gameTypes[index]
                let storeKey = Prefference.StoreKey.shaderKey(gameType: gameType, isGlsl: self.isGlsl)
                let isSelected: Bool
                if Prefference.defalut.getPrefference(kind: .shader, storeKey: storeKey)?.shaderValue == selectedShader.relativePath {
                    //unselected
                    Prefference.defalut.deletePrefference(kind: .shader, storeKey: storeKey)
                    isSelected = false
                } else {
                    //selected
                    Prefference.defalut.storePrefference(kind: .shader, storeKey: storeKey, storeValue: selectedShader.relativePath)
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
            return .dismiss(completion: { [weak self] in
                guard let self else { return }
                self.updateUsingShader(reloadViews: true)
            })
        })
    }
    
    func updateUsingShader(reloadViews: Bool) {
        guard initType != .preview else { return }
        
        var resolvedShaderPath: String? = nil
        if games.count == 1 {
            resolvedShaderPath = Prefference.defalut.getPrefference(kind: .shader,
                                                                    storeKey: .shaderKey(gameId: games.first!.id,
                                                                                         isGlsl: isGlsl))?.shaderValue
        }
        
        if resolvedShaderPath == nil, games.count > 0 {
            resolvedShaderPath = Prefference.defalut.getPrefference(kind: .shader,
                                                                    storeKey: .shaderKey(gameType: games.first!.gameType,
                                                                                         isGlsl: isGlsl),
                                                                    bestEfforts: true)?.shaderValue
        }
        
        if resolvedShaderPath == nil {
            resolvedShaderPath = Prefference.defalut.getPrefference(kind: .shader, storeKey: .shaderKey(isGlsl: isGlsl))?.shaderValue
        }
        
        var didUsingShaderChange = false
        if resolvedShaderPath == nil || resolvedShaderPath == "" {
            //original shader
            if let usingShader {
                if !usingShader.isOriginal {
                    self.usingShader = ShaderManager.genOriginalShader()
                    didUsingShaderChange = true
                }
            } else {
                usingShader = ShaderManager.genOriginalShader()
                didUsingShaderChange = true
            }
            
        } else if let resolvedShaderPath {
            if let usingShader {
                if usingShader.relativePath != resolvedShaderPath {
                    self.usingShader = Shader(title: resolvedShaderPath.lastPathComponent.deletingPathExtension,
                                              relativePath: resolvedShaderPath)
                    didUsingShaderChange = true
                }
            } else {
                usingShader = Shader(title: resolvedShaderPath.lastPathComponent.deletingPathExtension,
                                     relativePath: resolvedShaderPath)
                didUsingShaderChange = true
            }
        }
        
        if didUsingShaderChange {
            previewShader = usingShader
        }
        
        if didUsingShaderChange, reloadViews {
            updateContents()
        }
    }
    
    private func showShaderInfoView(shader: Shader) {
        var newShader = shader
#if DEBUG
        Log.debug("[Shader] read shader:\n\((try? String(contentsOfFile: newShader.filePath, encoding: .utf8)) ?? "NULL")\n")
#endif
        if currentSource == .custom {
            if let content = try? String(contentsOfFile: newShader.filePath, encoding: .utf8) {
                if let reference = content.lines().first(where: { $0.contains("#reference") }) {
                    var baseRelativePath = reference.replacingOccurrences(of: "#reference", with: "").trimmed.replacingOccurrences(of: "\"", with: "")
                    let pathMatch = "/Library/Libretro/shaders/"
                    while let range = baseRelativePath.range(of: pathMatch)  {
                        baseRelativePath = String(baseRelativePath[range.upperBound...])
                    }
                    newShader.baseRelativePath = baseRelativePath
                }
                
                if let forceBaseString = content.lines().first(where: { $0.contains(R.Strings.ShaderForceBase) }) {
                    let components = forceBaseString.components(separatedBy: "=")
                    if components.count == 2 {
                        newShader.forceBase = components[1].trimmed.replacingOccurrences(of: "\"", with: "")
                    }
                }
            }
        }
        ShaderInfoView.show(shader: newShader, didSavedShader: { [weak self] modifiedShader in
            guard let self else { return }
            self.normalShaderData[.custom] = nil
            self.searchShaderData[.custom] = nil
            self.segmentView.setIndex(ShaderSource.custom.rawValue, callback: true) 
            if let previewShader = self.previewShader,
                previewShader.relativePath == modifiedShader.relativePath {
                self.previewShader = modifiedShader
            }
        })
    }
    
    private func loadShader(completion: (() -> Void)? = nil) {
        if currentSource == .retroarch {
            UIView.makeLoading()
        }
        
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let results = ShaderManager.getShaders(source: self.currentSource,
                                                   isGlsl: self.isGlsl,
                                                   includeOriginal: self.initType != .preview)
            self.normalShaderData[currentSource] = results[currentSource]
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.currentSource == .retroarch {
                    UIView.hideLoading()
                }
                if self.isEditMode, self.currentShaderSections.count == 0 {
                    self.isEditMode = false
                } else {
                    self.updateContents()
                    self.updateNavigation()
                }
                if self.isSearch {
                    self.startSearchShaders()
                }
                self.scrollToUsingShader()
                completion?()
            }
        }
    }
    
    private func scrollToUsingShader() {
        guard let usingShader, currentSource.belongSource(shader: usingShader) else { return }
        var indexPath: IndexPath? = nil
        loop: for (section, sectionData) in currentShaderSections.enumerated() {
            for (row, shader) in sectionData.shaders.enumerated() {
                if shader.relativePath == usingShader.relativePath {
                    indexPath = IndexPath(row: row, section: section)
                    break loop
                }
            }
        }
        if let indexPath {
            listPageView.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        }
    }
    
    private func getNavigation() -> ASListPage.Navigation {
        var tools = [ASIcon]()
        if currentShaderSections.count > 0 {
            tools.append(.symbolImage(R.image.selectedit_iconSymbols()))
        }
        if currentSource == .retroarch {
            tools.append(.symbolImage(R.image.refresh_iconSymbols()))
            tools.append(.symbolImage(R.image.cloudDownload_iconSymbols(),
                                      animated: DownloadManager.shared.hasDownloadTask))
        }
        var navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.shaders(),
                                                                 titleIcon: .symbolImage(R.image.shaders_iconSymbols()),
                                                                 tools: tools)
        navigation.enableClose = showClose
        return navigation
    }
    
    private func getTop() -> (UIView, ASViewLayout, Bool) {
        return (topView, .fixedHeight(prefferedLayoutStyle == .landscape && showClose ? 116 : 318), true)
    }
    
    private func getCell(shader: Shader, isSelected: Bool) -> ASListPage.Cell {
        var previewButtonColor: UIColor = R.Color.LabelTertiary
        if let previewShader, previewShader.relativePath == shader.relativePath {
            previewButtonColor = R.Color.Main
        }
        
        if isEditMode {
            return .iconTitleDetailCheckCell(title: shader.title, isSelected: isSelected)
            
        } else {
            if initType == .preview {
                return .iconTitleIconButtonChevronCell(title: shader.title,
                                                       iconButton: .symbolImage(R.image.show_iconSymbols(),
                                                                                colors: [previewButtonColor]),
                                                       iconButtonBackground: .clear,
                                                       iconInset: .init(inset: R.Size.ContentSpaceExtraExtraSmall))
            } else {
                var isSelected = false
                if let usingShader, usingShader.relativePath == shader.relativePath {
                    isSelected = true
                }

                return .iconTitleIconButtonRadioCell(title: shader.title,
                                                     button: .iconOnly(icon: .symbolImage(R.image.show_iconSymbols(),
                                                                                          colors: [previewButtonColor]),
                                                                       iconSize: CGSize(R.Size.ButtonExtraExtraSmall)),
                                                     isSelected: isSelected)
            }
        }
        
        
    }
    
    private func getSections() -> [ASListPage.Section] {
        currentShaderSections.enumerated().map({ sectionIndex, section in
            ASListPage.Section(cells: section.shaders.enumerated().map({ shaderIndex, shader in
                getCell(shader: shader, isSelected: isEditMode ? selectedItems.contains(IndexPath(row: shaderIndex, section: sectionIndex)) : false)
            }), header: section.sectionTitle.isEmpty ? nil : .defaultHeader(title: section.sectionTitle))
        })
    }
    
    private func getTool() -> ASListPage.Tool? {
        if currentSource == .default {
            if selectedShaders.count > 1 {
                return nil
            } else if selectedShaders.count == 1, selectedShaders.first!.isOriginal {
                return ASListPage.Tool.defaultTool(otherIcons: [])
            }
        }
        
        if selectedItems.count > 0 {
            var icons = [ASIcon]()
            if currentSource != .default {
                icons.append(.symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]))
            }
            if selectedItems.count == 1 {
                icons.append(.symbolImage(R.image.edit_iconSymbols()))
            }
            return ASListPage.Tool.defaultTool(otherIcons: icons, hideMainIcon: selectedItems.count > 1)
        }
        return nil
    }
    
    private func getBlankSlate() -> ASListPage.BlankSlate? {
        guard currentShaderSections.count == 0 else { return nil }
        switch currentSource {
        case .default:
            return nil
        case .retroarch:
            return .init(title: R.string.localizable.noShaders(),
                         detail: R.string.localizable.downloadRetroArchSahders(),
                         button: .large(icon: .symbolImage(R.image.cloudDownload_iconSymbols(),
                                                           colors: [R.Color.LabelPrimary.forceStyle(.dark)]),
                                        title: R.string.localizable.cloudDriveBrowserDownload(),
                                        titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                        background: R.Color.Main),
                         layoutInsets: .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow)))
            
        case .imported:
            return .init(title: R.string.localizable.noShaders(),
                         detail: R.string.localizable.importShader(),
                         layoutInsets: .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow)))
            
        case .custom:
            return .init(title: R.string.localizable.noShaders(),
                         detail: R.string.localizable.customShaderDesc(),
                         layoutInsets: .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow)))
            
        }
    }
    
    private func getListPage() -> ASListPage {
        let listInsetBottom = (UIDevice.isPad && !showClose) ? R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceMedium : 0
        
        return ASListPage(top: getTop(),
                          sections: getSections(),
                          blankSlate: getBlankSlate(),
                          listInsets: .insets(bottom: listInsetBottom),
                          enableLongPress: true)
    }
    
    private func updateNavigation() {
        var navigation = getNavigation()
        navigation.state = isEditMode ? .edit : .normal
        navigation.edit = isSelectedAll ? R.string.localizable.deSelectAll() : R.string.localizable.selectAll()
        navigationView.navigation = navigation
    }
    
    private func updateContents() {
        listPageView.blankSlate = getBlankSlate()
        listPageView.sections = getSections()
        if currentShaderSections.count > 3 &&
            (currentSource == .retroarch || currentSource == .imported) {
            listPageView.enableIndexView = true
        } else {
            listPageView.enableIndexView = false
        }
    }
    
    private func updateTool() {
        listPageView.tool = getTool()
    }
    
    private func startSearchShaders() {
        guard let searchWord = searchView.text?.trimmed else { return }
        isSearch = true
        if !searchWord.isEmpty {
            UIView.makeLoading()
            DispatchQueue.global().async { [weak self] in
                guard let self else { return }
                let fuse = Fuse()
                let pattern = fuse.createPattern(from: searchWord)
                
                var result = ShaderListData()
                self.normalShaderData.forEach { source, list in
                    var listResult = [(String, [Shader])]()
                    list.forEach { item in
                        var shadersResult = [Shader]()
                        item.shaders.forEach { shader in
                            if let score = fuse.search(pattern, in: shader.title)?.score, score < 0.2 {
                                shadersResult.append(shader)
                            }
                        }
                        if shadersResult.count > 0 {
                            listResult.append((item.sectionTitle, shadersResult))
                        }
                    }
                    if listResult.count > 0 {
                        result[source] = listResult
                    }
                }
                self.searchShaderData = result
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    UIView.hideLoading()
                    self.updateContents()
                }
            }
        } else {
            isSearch = false
        }
    }
    
    private func stopSearchShaders() {
        isSearch = false
        searchShaderData = ShaderListData()
        updateContents()
    }
    
    private func downloadRetroarchShaders() {
        UIView.makeAlert(detail: R.string.localizable.downloadRetroArchShaders(),
                         confirmTitle: R.string.localizable.cloudDriveBrowserDownload(),
                         confirmAction: {
            DownloadManager.shared.downloads(urls: [R.URLs.SlangShaders, R.URLs.GLSLShaders],
                                             fileNames: [R.Strings.SlangShader, R.Strings.GLSLShader])
        })
    }
    
    private func updateViewsContraits() {
        previewView.removeFromSuperview()
        if prefferedLayoutStyle == .landscape, showClose {
            addSubview(previewView)
            previewView.snp.remakeConstraints { make in
                make.top.equalTo(navigationView.snp.bottom)
                make.leading.equalTo(navigationView)
                make.bottom.equalTo(safeAreaLayoutGuide)
            }
            listPageView.top = getTop()
            
            listPageView.snp.remakeConstraints { make in
                make.top.equalTo(navigationView.snp.bottom)
                make.leading.equalTo(previewView.snp.trailing)
                make.width.equalTo(previewView)
                make.trailing.equalTo(safeAreaLayoutGuide)
                make.bottom.equalToSuperview()
            }
            
        } else {
            topView.addSubview(previewView)
            previewView.snp.remakeConstraints { make in
                make.top.equalTo(segmentView.snp.bottom).offset(R.Size.ContentSpaceMedium)
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                make.height.equalTo(182)
            }
            listPageView.top = getTop()
            
            listPageView.snp.remakeConstraints { make in
                make.top.equalTo(navigationView.snp.bottom)
                make.leading.equalTo(safeAreaLayoutGuide)
                make.trailing.equalTo(safeAreaLayoutGuide)
                make.bottom.equalToSuperview()
            }
        }
    }
}

extension ShaderListView: ShowableView {
    @discardableResult
    static func show(initType: InitType,
                     isGlsl: Bool = false,
                     games: [Game] = [],
                     previewImage: UIImage? = nil,
                     hideCompletion: (() -> Void)? = nil) -> Self {
        if let previewImage {
            let view = Self.show(parameters: initType, isGlsl, games, previewImage)!
            view.hideCompletion = hideCompletion
            return view
        } else {
            let view = Self.show(parameters: initType, isGlsl, games)!
            view.hideCompletion = hideCompletion
            return view
        }
    }
    
    func didHide() {
        hideCompletion?()
    }
    
    func dataForShow(_ defaultData: ASSheet) -> ASSheet {
        var sheetData = defaultData
        sheetData.fullScreenForLandscape = true
        sheetData.panGestureShouldBegin = { [weak self] gesture in
            guard let self else { return true }
            if currentSource == .retroarch || currentSource == .imported {
                if let gestureView = gesture.view {
                    let locationInView = gesture.location(in: gestureView)
                    if locationInView.x > gestureView.width - 30 {
                        //When swiping through the index View, the ASSheetView gesture is disabled.
                        return false
                    }
                }
            }
            return true
        }
        return sheetData
    }
}
