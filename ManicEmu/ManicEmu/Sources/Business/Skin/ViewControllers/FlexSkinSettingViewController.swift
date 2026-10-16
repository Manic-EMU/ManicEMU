//
//  FlexSkinSettingViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/26.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import ZIPFoundation
import RealmSwift
import IceCream
import Haptica

class FlexSkinSettingViewController: BaseViewController {
    static var isShow = false
    
    private var screensViews: [UIView] = []
    private var initFrames: [CGRect] = []
    private var initScreens: [ControllerSkin.Screen] = []
    
    private var itemViews: [FlexItemView] = []
    private var initItemFrames: [CGRect] = []
    private var initItems: [ControllerSkin.Item] = []
    private var itemGestureStartStates = [ObjectIdentifier: (center: CGPoint, transform: CGAffineTransform, frame: CGRect)]()
    private struct ItemResizeState {
        let anchor: CGPoint
        let aspectRatio: CGFloat
    }
    private var itemResizeStates = [ObjectIdentifier: ItemResizeState]()
    
    private let minDistanceToEdge: CGFloat = 10
    private let minDistanceToCenter: CGFloat = 15
    private let minDistanceToAnotherView: CGFloat = 10
    private let minEdgeSize: CGFloat = 50 // 最小尺寸限制
    
    private let itemMinDistanceToEdge: CGFloat = 5
    private let itemMinDistanceToCenter: CGFloat = 8
    private let itemMinDistanceToAnotherView: CGFloat = 5
    private let minItemSize: CGFloat = 24
    private var lastHapticTime: TimeInterval = 0
    private let hapticThrottleInterval: TimeInterval = 0.3
    
    private let gameId: String?
    private let gameType: GameType
    private let skin: Skin
    private let traits: ControllerSkin.Traits
    private var isLandscapeTraits: Bool { traits.orientation == .landscape }
    
    private let images: [UIImage?]
    
    private var isModified: Bool = false
    
    var didCompletion: ((Bool)->Void)? = nil
    
    private lazy var background: FlexBackgroundImage? = {
        if let result = Prefference.defalut.getPrefference(kind: .flexBackground,
                                                           storeKey: backgroundBaseStoreKey,
                                                           bestEfforts: true),
           case let .flexBackground(bg) = result {
            return bg
        }
        return nil
    }() {
        didSet {
            backgroundImageView.image = background?.image
        }
    }
    
    private lazy var navigationView: ASNavigationView = {
        let navigation = ASListPage.Navigation(tools: [.symbolImage(R.image.refresh_iconSymbols()), .symbolImage(R.image.cover_iconSymbols())])
        let view = ASNavigationView(navigation)
        view.backgroundColor = R.Color.BackgroundPrimary
        view.layerCornerRadius = R.Size.NavigationHeight/2
        view.didTapClose = { [weak self] in
            guard let self = self else { return }
            self.saveSettings {
                DispatchQueue.main.async {
                    self.dismiss(animated: true)
                }
            }
        }
        view.didTapTools = { [weak self] index in
            guard let self else { return }
            if index == 0 {
                //reset
                self.resetSettings()
            } else if index == 1 {
                //background
                self.showBackgroundOptions()
            }
        }
        
        let segmentView = ASSegmentView(.textSegment(titles: [
            R.string.localizable.screen(),
            R.string.localizable.button()
        ]))
        segmentView.didSelectIndex = { [weak self] index in
            guard let self else { return }
            if index == 0 {
                self.buttonsContainerView.alpha = 0.2
                self.buttonsContainerView.isUserInteractionEnabled = false
                self.screensContainerView.alpha = 1
                self.screensContainerView.isUserInteractionEnabled = true
            } else if index == 1 {
                self.buttonsContainerView.alpha = 1
                self.buttonsContainerView.isUserInteractionEnabled = true
                self.screensContainerView.alpha = 0.2
                self.screensContainerView.isUserInteractionEnabled = false
            }
        }
        
        view.addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightTiny)
            make.trailing.equalTo(view.toolButtonView.snp.leading).offset(-R.Size.ContentSpaceSmall)
        }
        
        return view
    }()
    
    private lazy var controlView: ControllerView = {
        let view = ControllerView()
        view.controllerSkin = ControllerSkin(fileURL: skin.fileURL)
        view.alpha = 0
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let crosshairGuideView: AuxiliaryLineView = {
        let view = AuxiliaryLineView(enableCrosshair: true, enableBorder: false)
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let screensContainerView = UIView()
    
    private let buttonsContainerView = UIView()
    
    private lazy var backgroundImageView: UIImageView = {
        let view = UIImageView(image: background?.image)
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    init(skin: Skin,
         traits: ControllerSkin.Traits,
         images: [UIImage?],
         gameId: String? = nil,
         gameType: GameType) {
        self.skin = skin
        self.traits = traits
        self.images = images
        self.gameId = gameId
        self.gameType = gameType
        super.init(fullScreen: true)
        FlexSkinSettingViewController.isShow = true
        enableBackgroundMask = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        view.addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if let controllerSkin = controlView.controllerSkin as? ControllerSkin,
           let hostingWindow,
           let frames = controllerSkin.getFrames(window: hostingWindow) {
            
            if let screens = controllerSkin.screens(for: traits) {
                for (index, screen) in screens.enumerated() {
                    if let outputFrame = screen.outputFrame {
                        let scaledFrame = outputFrame.applying(.init(scaleX: frames.skinFrame.width, y: frames.skinFrame.height))
                        let view = createInteractiveScreenView(frame: scaledFrame, image: index < images.count ? images[index] : nil)
                        screensViews.append(view)
                        initFrames.append(scaledFrame)
                        initScreens.append(screen)
                    }
                }
                
                screensContainerView.frame = frames.skinFrame
                view.addSubview(screensContainerView)
                screensViews.forEach { screensContainerView.addSubview($0) }
            }
            
            view.addSubview(controlView)
            controlView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(frames.skinFrame.size)
            }
            
            if let items = controllerSkin.items(for: traits) {
                buttonsContainerView.frame = frames.skinFrame
                buttonsContainerView.alpha = 0.2
                buttonsContainerView.isUserInteractionEnabled = false
                view.addSubview(buttonsContainerView)
                setupItemViews(controllerSkin: controllerSkin, items: items)
            }
        }
        
        view.addSubview(crosshairGuideView)
        crosshairGuideView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        view.addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(R.Size.NavigationHeight)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        FlexSkinSettingViewController.isShow = false
        didCompletion?(isModified)
    }
    
    private func updatedTopViewVisual(toneDown: Bool) {
        navigationView.alpha = toneDown ? 0.2 : 1.0
    }
    
    private func resetSettings() {
        if let skinPath = skin.skinData?.filePath {
            do {
                guard let traits = controlView.controllerSkinTraits,
                      initFrames.count == screensViews.count,
                      initItemFrames.count == itemViews.count else {
                    UIView.makeToast(message: "Reset failed, skin file error!")
                    return
                }
                Log.debug("开始重置皮肤")
                let archive = try Archive(url: skinPath, accessMode: .update)
                
                //获取备份数据
                if let originalInfoEntry = archive["info_flex.json"] {
                    
                    //获取原始info.json
                    var originalInfoData = Data()
                    try _ = archive.extract(originalInfoEntry) { originalInfoData.append($0) }
                    
                    var resetInfoPath = [String]()
                    resetInfoPath.append("representations")
                    resetInfoPath.append(traits.device == .iphone ? "iphone" : "ipad")
                    resetInfoPath.append(traits.displayType == .standard ? "standard" : "edgeToEdge")
                    resetInfoPath.append(isLandscapeTraits ? "landscape" : "portrait")
                    Log.debug("重置路径:\(resetInfoPath)")
                    
                    if let originalDataForCurrentTraits = try getValueFromJSON(originalInfoData, keyPath: resetInfoPath), let currentInfoEntry = archive["info.json"] {
                        //获取当前的info.json
                        var currentInfoData = Data()
                        try _ = archive.extract(currentInfoEntry) { currentInfoData.append($0) }
                        
                        //获取需要重置的数据
                        let resetInfoData = try modifyJSONData(currentInfoData, keyPath: resetInfoPath, newValue: originalDataForCurrentTraits)
                        
                        try archive.remove(currentInfoEntry)
                        try archive.addEntry(with: "info.json", type: .file, uncompressedSize: Int64(resetInfoData.count)) { position, size in
                            return resetInfoData.subdata(in: Data.Index(position)..<Int(position)+size)
                        }
                        
                        let tempUrl = URL(fileURLWithPath: R.Path.Temp.appendingPathComponent(skinPath.lastPathComponent))
                        try FileManager.safeCopyItem(at: skinPath, to: tempUrl)
                        
                        Skin.change { realm in
                            skin.skinData?.deleteAndClean(realm: realm)
                            skin.skinData = CreamAsset.create(objectID: skin.id, propName: "skinData", url: tempUrl)
                        }
                        
                        try FileManager.safeRemoveItem(at: tempUrl)
                        
                        if let newSkinPath = skin.skinData?.filePath {
                            controlView.controllerSkin = ControllerSkin(fileURL: newSkinPath)
                            if let screens = controlView.controllerSkin?.screens(for: traits) {
                                initFrames.removeAll()
                                initScreens.removeAll()
                                for (index, screen) in screens.enumerated() {
                                    if let outputFrame = screen.outputFrame,
                                       let controllerSkin = controlView.controllerSkin as? ControllerSkin,
                                       let hostingWindow,
                                       let frames = controllerSkin.getFrames(window: hostingWindow)  {
                                        let scaledFrame = outputFrame.applying(.init(scaleX: frames.skinFrame.width, y: frames.skinFrame.height))
                                        screensViews[index].frame = scaledFrame
                                        initFrames.append(scaledFrame)
                                        initScreens.append(screen)
                                    }
                                }
                            }
                            if let controllerSkin = controlView.controllerSkin as? ControllerSkin,
                               let items = controllerSkin.items(for: traits) {
                                reloadItemViews(controllerSkin: controllerSkin, items: items)
                            }
                        }
                    }
                } else {
                    Log.debug("还没有修改过，直接恢复视图的frame即可")
                    for (index, view) in screensViews.enumerated() {
                        view.frame = initFrames[index]
                        view.transform = .identity
                    }
                    for (index, view) in itemViews.enumerated() {
                        view.frame = initItemFrames[index]
                        view.transform = .identity
                    }
                }
                isModified = false
            } catch {
                Log.debug("重置出错了 error:\(error)")
                UIView.makeToast(message: "Reset failed, skin file error!")
                return
            }
        } else {
            UIView.makeToast(message: "Reset failed, the skin file has been deleted!")
            return
        }
    }
    
    private func saveSettings(completion: (()->Void)? = nil) {
        
        //先判断一下有没有修改
        if let skinPath = skin.skinData?.filePath {
            do {
                
                guard let traits = controlView.controllerSkinTraits,
                      initFrames.count == screensViews.count,
                      initItemFrames.count == itemViews.count else {
                    UIView.makeToast(message: "Modification failed, skin file error!")
                    completion?()
                    return
                }
                
                //判断一下是否进行了修改
                var isModified = false
                for (index, view) in screensViews.enumerated() {
                    if initFrames[index].rounded() != view.frame.rounded() {
                        Log.debug("初始frame:\(initFrames[index]) view的frame:\(view.frame) 有变更，进行皮肤更新")
                        isModified = true
                    }
                }
                for (index, view) in itemViews.enumerated() {
                    if initItemFrames[index].rounded() != view.frame.rounded() {
                        Log.debug("初始item frame:\(initItemFrames[index]) view的frame:\(view.frame) 有变更，进行皮肤更新")
                        isModified = true
                    }
                }
                
                guard isModified else {
                    Log.debug("没有有变更，不进行皮肤更新")
                    completion?()
                    return
                }
                self.isModified = isModified
                
                //开始修改皮肤
                let archive = try Archive(url: skinPath, accessMode: .update)
                
                guard let infoEntry = archive["info.json"] else {
                    UIView.makeToast(message: "Modification failed, skin file error!")
                    completion?()
                    return
                }
                
                //解压info.json
                var infoData = Data()
                try _ = archive.extract(infoEntry) { infoData.append($0) }
                
                if let _ = archive["info_flex.json"] {} else {
                    //备份不存在 先创建一个备份
                    Log.debug("备份info.json为info_flex.json")
                    try archive.addEntry(with: "info_flex.json", type: .file, uncompressedSize: Int64(infoData.count)) { position, size in
                        return infoData.subdata(in: Data.Index(position)..<Int(position)+size)
                    }
                }
                
                var infoPath = [String]()
                infoPath.append("representations")
                infoPath.append(traits.device == .iphone ? "iphone" : "ipad")
                infoPath.append(traits.displayType == .standard ? "standard" : "edgeToEdge")
                infoPath.append(isLandscapeTraits ? "landscape" : "portrait")
                Log.debug("生成info.json的访问路径:\(infoPath)")
                
                //需要修改screens和item里面的touchScreen
                var newScreens = [[String: Any]]()
                var touchScreenFrame: CGRect? = nil
                for (index, screen) in initScreens.enumerated() {
                    
                    var inputFrameDict = [String: CGFloat]()
                    var outputFrameDict = [String: CGFloat]()
                    if let inputFrame = screen.inputFrame?.rounded() {
                        inputFrameDict["x"] = inputFrame.origin.x
                        inputFrameDict["y"] = inputFrame.origin.y
                        inputFrameDict["width"] = inputFrame.width
                        inputFrameDict["height"] = inputFrame.height
                    }
                    
                    let modifierView = screensViews[index]
                    
                    if let skinMappingSize = controlView.controllerSkin?.aspectRatio(for: traits) {
                        let outputFrame = modifierView.frame.applying(.init(scaleX: skinMappingSize.width/screensContainerView.width, y: skinMappingSize.height/screensContainerView.height)).rounded()
                        outputFrameDict["x"] = outputFrame.origin.x
                        outputFrameDict["y"] = outputFrame.origin.y
                        outputFrameDict["width"] = outputFrame.width
                        outputFrameDict["height"] = outputFrame.height
                        
                        if screen.isTouchScreen {
                            touchScreenFrame = outputFrame
                        }
                    }
                    if inputFrameDict.count == 0 {
                        newScreens.append(["outputFrame": outputFrameDict])
                    } else {
                        newScreens.append(["inputFrame": inputFrameDict, "outputFrame": outputFrameDict])
                    }
                    
                }
                
                Log.debug("生成screens信息:\(newScreens)")
                
                //修改screen信息
                Log.debug("修改screens的路径是:\(infoPath + ["screens"])")
                var newInfoData = try modifyJSONData(infoData, keyPath: infoPath + ["screens"], newValue: newScreens)
                
                //修改touchScreen信息
                if let touchScreenFrame, var items = try getValueFromJSON(newInfoData, keyPath: infoPath + ["items"]) as? [[String: Any]] {
                    Log.debug("修改触屏信息")
                    for (index , item) in items.enumerated() {
                        if let inputs = item["inputs"] as? [String: String], let x = inputs["x"], x == "touchScreenX", let y = inputs["y"], y == "touchScreenY" {
                            items.remove(at: index)
                            Log.debug("移除旧的触屏信息:\(item)")
                            break
                        }
                    }
                    var frameDict = [String: CGFloat]()
                    frameDict["x"] = touchScreenFrame.origin.x
                    frameDict["y"] = touchScreenFrame.origin.y
                    frameDict["width"] = touchScreenFrame.width
                    frameDict["height"] = touchScreenFrame.height
                    
                    var inputs = [String: String]()
                    inputs["x"] = "touchScreenX"
                    inputs["y"] = "touchScreenY"
                    
                    let newItem = ["frame": frameDict, "inputs": inputs] as [String : Any]
                    items.append(newItem)
                    Log.debug("创建新的触屏信息:\(newItem)")
                    
                    newInfoData = try modifyJSONData(newInfoData, keyPath: infoPath + ["items"], newValue: items)
                    Log.debug("写入触屏信息路径:\(infoPath + ["items"])")
                }
                
                // 更新可编辑 item 的 frame（thumbstick 同步缩放摇杆头尺寸）
                if var items = try getValueFromJSON(newInfoData, keyPath: infoPath + ["items"]) as? [[String: Any]],
                   let skinMappingSize = controlView.controllerSkin?.aspectRatio(for: traits) {
                    for (viewIndex, itemView) in itemViews.enumerated() {
                        let jsonIndex = itemView.itemJSONIndex
                        guard jsonIndex < items.count else { continue }
                        
                        let mappingFrame = itemView.frame.applying(.init(scaleX: skinMappingSize.width / buttonsContainerView.width,
                                                                         y: skinMappingSize.height / buttonsContainerView.height)).rounded()
                        var frameDict = [String: CGFloat]()
                        frameDict["x"] = mappingFrame.origin.x
                        frameDict["y"] = mappingFrame.origin.y
                        frameDict["width"] = mappingFrame.width
                        frameDict["height"] = mappingFrame.height
                        items[jsonIndex]["frame"] = frameDict
                        
                        if itemView.item.kind == .thumbstick,
                           let initialKnob = itemView.initialKnobMappingSize {
                            let initMappingFrame = initItemFrames[viewIndex].applying(.init(scaleX: skinMappingSize.width / buttonsContainerView.width,
                                                                                            y: skinMappingSize.height / buttonsContainerView.height))
                            guard initMappingFrame.width > 0, initMappingFrame.height > 0 else { continue }
                            
                            let scaleX = mappingFrame.width / initMappingFrame.width
                            let scaleY = mappingFrame.height / initMappingFrame.height
                            if var thumbstick = items[jsonIndex]["thumbstick"] as? [String: Any] {
                                thumbstick["width"] = initialKnob.width * scaleX
                                thumbstick["height"] = initialKnob.height * scaleY
                                items[jsonIndex]["thumbstick"] = thumbstick
                            }
                        }
                    }
                    newInfoData = try modifyJSONData(newInfoData, keyPath: infoPath + ["items"], newValue: items)
                    Log.debug("写入items信息路径:\(infoPath + ["items"])")
                }
                
                try archive.remove(infoEntry)
                
                try archive.addEntry(with: "info.json", type: .file, uncompressedSize: Int64(newInfoData.count)) { position, size in
                    return newInfoData.subdata(in: Data.Index(position)..<Int(position)+size)
                }
                
                let tempUrl = URL(fileURLWithPath: R.Path.Temp.appendingPathComponent(skinPath.lastPathComponent))
                try FileManager.safeCopyItem(at: skinPath, to: tempUrl)
                
                Skin.change { realm in
                    skin.skinData?.deleteAndClean(realm: realm)
                    skin.skinData = CreamAsset.create(objectID: skin.id, propName: "skinData", url: tempUrl)
                }
                
                try FileManager.safeRemoveItem(at: tempUrl)
                
                completion?()
            } catch {
                UIView.makeToast(message: "Modification failed, skin cannot be operated!")
            }
            
        } else {
            UIView.makeToast(message: "Modification failed—this skin cannot be modified!")
        }
    }
    
    private func modifyJSONData(_ jsonData: Data, keyPath: [String], newValue: Any) throws -> Data {
        // 1. 解析成 Dictionary
        guard var jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw NSError(domain: "Invalid JSON", code: -1)
        }
        
        // 2. 递归修改
        func modify(object: inout [String: Any], keys: ArraySlice<String>, newValue: Any) {
            guard let key = keys.first else { return }
            if keys.count == 1 {
                object[key] = newValue
            } else if var nested = object[key] as? [String: Any] {
                modify(object: &nested, keys: keys.dropFirst(), newValue: newValue)
                object[key] = nested
            }
        }
        
        modify(object: &jsonObject, keys: keyPath[...], newValue: newValue)
        
        // 3. 转回Data
        let updatedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        return updatedData
    }
    
    private func getValueFromJSON(_ jsonData: Data, keyPath: [String]) throws -> Any? {
        // 1. 解析 JSON 为 Dictionary
        guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw NSError(domain: "Invalid JSON", code: -1)
        }
        
        // 2. 遍历 keyPath
        var current: Any = jsonObject
        for key in keyPath {
            if let dict = current as? [String: Any], let next = dict[key] {
                current = next
            } else {
                return nil
            }
        }
        
        return current
    }
    
    
}

///Background
extension FlexSkinSettingViewController {
    private func showBackgroundOptions() {
        let isLandScape = traits.orientation == .landscape
        var sections = [ASListPage.Section]()
        //section 0 fetch images
        sections.append(.init(cells: [.iconTitleChevronCell(icon: .symbolImage(R.image.cover_iconSymbols()),
                                                            title: isLandScape ?
                                                            R.string.localizable.addBackgroundForLandscape() :
                                                               R.string.localizable.addBackgroundForPortrait())]))
        
        if let background {
            //section 1 setting background
            var settingBackgroundCells = [ASListPage.Cell]()
            settingBackgroundCells.append(.iconTitleDetailRadioCell(icon: .symbolImage(R.image.language_iconSymbols()),
                                                                    title: R.string.localizable.updateBackgroundForGlobal(),
                                                                    isSelected: background.storeLevel == .global))
            settingBackgroundCells.append(.iconTitleDetailRadioCell(icon: .symbolImage(R.image.category_iconSymbols()),
                                                                    title: R.string.localizable.updateBackgroundForConsole(gameType.localizedShortName),
                                                                    isSelected: background.storeLevel == .gameType))
            if let _ = gameId {
                settingBackgroundCells.append(.iconTitleDetailRadioCell(icon: .symbolImage(R.image.controller_iconSymbols()),
                                                                        title: R.string.localizable.updateBackgroundForGame(),
                                                                        isSelected: background.storeLevel == .game))
            }
            sections.append(.init(cells: settingBackgroundCells,
                                  header: .defaultHeader(title: R.string.localizable.updateBackground())))
            
            //section 2 delete
            let deleteTitle: String
            switch background.storeLevel {
            case .game:
                deleteTitle = R.string.localizable.removeBackgroundForGame()
            case .gameType:
                deleteTitle = R.string.localizable.removeBackgroundForConsole(gameType.localizedShortName)
            case .global:
                deleteTitle = R.string.localizable.removeBackgroundForGlobal()
            }
            sections.append(.init(cells: [.iconTitleChevronCell(icon: .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
                                                                title: deleteTitle,
                                                                titleColor: R.Color.Red)]))
        }
        
        let listPage = ASListPage(navigation: .defaultNavigation(title: R.string.localizable.background(),
                                                                 titleIcon: .symbolImage(R.image.cover_iconSymbols())),
                                  sections: sections)
        
        ASSheetView.show(.init(style: .listPage(listPage)), action: { [weak self] action, _ in
            guard let self else { return .dismiss() }
            if let indexPath = action.listPageValue?.normalItemValue?.indexPath {
                return .dismiss(completion: { [weak self] in
                    guard let self else { return }
                    if indexPath.section == 0 {
                        //section 0 fetch images
                        var sources: [ImageFetcher.Source] = [.capture, .library, .file]
                        
                        if let gameId = self.gameId,
                           let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId) {
                            sources += [.libretro(game), .steamGridDB(game, preferredAssetType: .grids)]
                        }
                        
                        if let image = background?.image {
                            sources += [.editImage(image)]
                        }
                        ImageFetcher.showCommonFetcher(sources: sources,
                                                       in: hostingWindowScene,
                                                       completion: { [weak self] image, source in
                            guard let self, let image else { return }
                            if case .editImage = source {
                                self.updateBackgroundImage(image)
                            } else {
                                self.addBackground(image: image)
                            }
                            self.updateGamingBackgroundIfNeed()
                        })
                    } else if indexPath.section == 1 {
                        //section 1 setting background
                        if indexPath.row == 0 {
                            self.updateBackgroundStoreLevel(.global)
                            
                        } else if indexPath.row == 1 {
                            self.updateBackgroundStoreLevel(.gameType)
                            
                        } else if indexPath.row == 2 {
                            self.updateBackgroundStoreLevel(.game)
                        }
                        self.updateGamingBackgroundIfNeed()
                    } else if indexPath.section == 2 {
                        //section 2 delete
                        self.removeBackground()
                        self.updateGamingBackgroundIfNeed()
                    }
                })
            }
            return .dismiss()
        })
    }
    
    private func addBackground(image: UIImage) {
        //Default to adding to the game
        if let gameId,
           let result = Prefference.defalut.getPrefference(kind: .flexBackground,
                                                           storeKey: .orientationKey(gameId: gameId, isLandScape: isLandscapeTraits)),
           case let .flexBackground(background) = result {
            try? FileManager.default.removeItem(at: background.imageUrl)
        }
        
        var currentIndex: Int = 0
        if let imageNames = try? FileManager.default.contentsOfDirectory(atPath: R.Path.Assets),
           let lastName = imageNames.filter({ $0.hasPrefix("flex_background_")}).sorted(by: < ).last {
            let regex = try! NSRegularExpression(pattern: "(\\d+)(?=\\.[^.]+$)")
            if let match = regex.firstMatch(in: lastName, range: NSRange(lastName.startIndex..., in: lastName)),
               let range = Range(match.range(at: 1), in: lastName), let index = Int(lastName[range]) {
                currentIndex = index + 1
            }
        }
        
        if let data = image.jpegData(compressionQuality: 0.9) {
            let imageUrl = URL(fileURLWithPath: R.Path.Assets.appendingPathComponent("flex_background_\(isLandscapeTraits ? "landscape" : "portrait")_\(currentIndex).jpg"))
            try? data.writeWithCompletePath(to: imageUrl)
            if FileManager.default.fileExists(atPath: imageUrl.path) {
                
                let storeKey: Prefference.StoreKey
                if let gameId {
                    storeKey = .orientationKey(gameId: gameId, isLandScape: isLandscapeTraits)
                } else {
                    storeKey = .orientationKey(gameType: gameType, isLandScape: isLandscapeTraits)
                }
                Prefference.defalut.storePrefference(kind: .flexBackground,
                                                     storeKey: storeKey,
                                                     storeValue: imageUrl.lastPathComponent)
                background = FlexBackgroundImage(name: imageUrl.lastPathComponent, storeLevel: gameId == nil ? .gameType : .game)
            }
        }
    }
    
    private func updateBackgroundImage(_ image: UIImage) {
        guard let background else { return }
        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.writeWithCompletePath(to: background.imageUrl)
            backgroundImageView.image = image
        }
    }
    
    private func updateBackgroundStoreLevel(_ level: Prefference.StoreLevel) {
        guard let background else { return }
        switch level {
        case .game:
            if let gameId {
                Prefference.defalut.storePrefference(kind: .flexBackground,
                                                     storeKey: .orientationKey(gameId: gameId, isLandScape: isLandscapeTraits),
                                                     storeValue: background.name)
                self.background?.storeLevel = .game
            }
            
        case .gameType:
            Prefference.defalut.storePrefference(kind: .flexBackground,
                                                 storeKey: .orientationKey(gameType: gameType, isLandScape: isLandscapeTraits),
                                                 storeValue: background.name)
            self.background?.storeLevel = .gameType
            
        case .global:
            Prefference.defalut.storePrefference(kind: .flexBackground,
                                                 storeKey: .orientationKey(isLandScape: isLandscapeTraits),
                                                 storeValue: background.name)
            self.background?.storeLevel = .global
        }
    }
    
    var backgroundBaseStoreKey: Prefference.StoreKey {
        let storeKey: Prefference.StoreKey
        if let gameId {
            storeKey = .orientationKey(gameId: gameId,
                                       isLandScape: isLandscapeTraits)
        } else {
            storeKey = .orientationKey(gameType: gameType,
                                       isLandScape: isLandscapeTraits)
        }
        return storeKey
    }
    
    private func removeBackground() {
        guard let background else { return }
        let storeKey: Prefference.StoreKey
        switch background.storeLevel {
        case .game:
            guard let gameId else { return }
            storeKey = .orientationKey(gameId: gameId, isLandScape: isLandscapeTraits)
        case .gameType:
            storeKey = .orientationKey(gameType: gameType, isLandScape: isLandscapeTraits)
        case .global:
            storeKey = .orientationKey(isLandScape: isLandscapeTraits)
        }
        Prefference.defalut.deletePrefference(kind: .flexBackground, storeKey: storeKey)
        
        if !Prefference.defalut.valueExists(kind: .flexBackground, value: background.name) {
            try? FileManager.safeRemoveItem(at: background.imageUrl)
        }
        
        if let result = Prefference.defalut.getPrefference(kind: .flexBackground,
                                                           storeKey: backgroundBaseStoreKey,
                                                           bestEfforts: true),
           case let .flexBackground(background: bg) = result {
            self.background = bg
        } else {
            self.background = nil
        }
    }
    
    private func updateGamingBackgroundIfNeed() {
        guard PlayViewController.isGaming else { return }
        if let gameId, PlayViewController.currentGame?.id == gameId {
            PlayViewController.updateBackground()
        } else if self.gameType == PlayViewController.currentGameType {
            PlayViewController.updateBackground()
        }
    }
}

///Screens
extension FlexSkinSettingViewController {
    
    private func triggerThrottledHaptic(style: HapticFeedbackStyle = .soft) {
        let now = Date().timeIntervalSince1970
        if now - lastHapticTime >= hapticThrottleInterval {
            lastHapticTime = now
            UIDevice.generateHaptic(style: style)
        }
    }
    
    // MARK: - 创建可拖动缩放的子视图
    private func createInteractiveScreenView(frame: CGRect, image: UIImage?) -> UIView {
        let container = AuxiliaryLineView(frame: frame, enableCrosshair: false, enableBorder: true)
        container.isUserInteractionEnabled = true
        
        let imageView = UIImageView(frame: container.bounds)
        imageView.backgroundColor = R.Color.BackgroundSecondary
        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        container.insertSubview(imageView, at: 0)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(1)
        }
        
        // 添加手势
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        
        container.addGestureRecognizer(pan)
        container.addGestureRecognizer(pinch)
        
        // 为边缘手柄添加拖动手势
        setupEdgeHandleGestures(for: container)
        
        return container
    }
    
    // MARK: - 设置边缘手柄手势
    private func setupEdgeHandleGestures(for container: AuxiliaryLineView) {
        let topPan = UIPanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        container.topHandle.addGestureRecognizer(topPan)
        container.topHandle.tag = 1 // top
        
        let bottomPan = UIPanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        container.bottomHandle.addGestureRecognizer(bottomPan)
        container.bottomHandle.tag = 2 // bottom
        
        let leftPan = UIPanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        container.leftHandle.addGestureRecognizer(leftPan)
        container.leftHandle.tag = 3 // left
        
        let rightPan = UIPanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        container.rightHandle.addGestureRecognizer(rightPan)
        container.rightHandle.tag = 4 // right
    }
    
    // MARK: - 拖动
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        
        let translation = gesture.translation(in: self.view)
        view.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
        gesture.setTranslation(.zero, in: self.view)
        
        if gesture.state == .changed {
            updatedTopViewVisual(toneDown: true)
            let center = view.center
            let screenCenter = CGPoint(x: screensContainerView.frame.midX, y: screensContainerView.frame.midY)
            
            // 屏幕中心震动
            if abs(center.x - screenCenter.x) <= minDistanceToCenter/2 ||
                abs(center.y - screenCenter.y) <= minDistanceToCenter/2 {
                triggerThrottledHaptic(style: .light)
            }
            
            // 边缘移出检测震动（实时）
            let frame = view.frame
            if frame.minX < 0 || frame.maxX > screensContainerView.frame.width ||
                frame.minY < 0 || frame.maxY > screensContainerView.frame.height {
                triggerThrottledHaptic(style: .medium)
            }
            
            // 视图间边缘碰撞震动（仅当存在两个视图）
            if screensViews.count == 2 {
                let other = screensViews.first { $0 != view }!
                let f1 = frame
                let f2 = other.frame
                
                let horizontalNear = abs(f1.maxX - f2.minX) <= minDistanceToAnotherView ||
                abs(f1.minX - f2.maxX) <= minDistanceToAnotherView
                
                let verticalOverlap = f1.maxY > f2.minY && f1.minY < f2.maxY
                
                let verticalNear = abs(f1.maxY - f2.minY) <= minDistanceToAnotherView ||
                abs(f1.minY - f2.maxY) <= minDistanceToAnotherView
                
                let horizontalOverlap = f1.maxX > f2.minX && f1.minX < f2.maxX
                
                if (horizontalNear && verticalOverlap) || (verticalNear && horizontalOverlap) {
                    triggerThrottledHaptic()
                }
                
                if f2.contains(f1) || f2.intersects(f1) {
                    let cornerPoints: [CGPoint] = [
                        CGPoint(x: f2.minX + f1.width / 2, y: f2.minY + f1.height / 2), // 左上角
                        CGPoint(x: f2.maxX - f1.width / 2, y: f2.minY + f1.height / 2), // 右上角
                        CGPoint(x: f2.minX + f1.width / 2, y: f2.maxY - f1.height / 2), // 左下角
                        CGPoint(x: f2.maxX - f1.width / 2, y: f2.maxY - f1.height / 2)  // 右下角
                    ]
                    
                    for point in cornerPoints {
                        let dx = abs(center.x - point.x)
                        let dy = abs(center.y - point.y)
                        if dx <= minDistanceToAnotherView {
                            //吸附横向
                            triggerThrottledHaptic()
                            
                        } else if dy <= minDistanceToAnotherView {
                            //吸附纵向
                            triggerThrottledHaptic()
                        }
                    }
                }
            }
        }
        
        if gesture.state == .ended {
            optimizePosition(for: view)
            updatedTopViewVisual(toneDown: false)
        }
    }
    
    // MARK: - 缩放
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let view = gesture.view else { return }
        view.transform = view.transform.scaledBy(x: gesture.scale, y: gesture.scale)
        gesture.scale = 1
        
        if gesture.state == .changed {
            updatedTopViewVisual(toneDown: true)
            // 边缘移出检测震动（实时）
            let frame = view.frame
            if frame.minX < 0 || frame.maxX > screensContainerView.frame.width ||
                frame.minY < 0 || frame.maxY > screensContainerView.frame.height {
                triggerThrottledHaptic(style: .medium)
            }
        }
        
        if gesture.state == .ended {
            optimizeScale(for: view)
            updatedTopViewVisual(toneDown: false)
        }
    }
    
    // MARK: - 边缘拖动（非比例缩放）
    @objc private func handleEdgePan(_ gesture: UIPanGestureRecognizer) {
        guard let handle = gesture.view,
              let gameView = handle.superview else { return }
        
        updatedTopViewVisual(toneDown: true)
        
        let translation = gesture.translation(in: self.view)
        var newFrame = gameView.frame
        
        // 根据手柄tag确定调整哪个边
        switch handle.tag {
        case 1: // top
            let newHeight = newFrame.height - translation.y
            let newY = newFrame.origin.y + translation.y
            if newHeight >= minEdgeSize {
                newFrame.origin.y = newY
                newFrame.size.height = newHeight
            }
            
        case 2: // bottom
            let newHeight = newFrame.height + translation.y
            if newHeight >= minEdgeSize {
                newFrame.size.height = newHeight
            }
            
        case 3: // left
            let newWidth = newFrame.width - translation.x
            let newX = newFrame.origin.x + translation.x
            if newWidth >= minEdgeSize {
                newFrame.origin.x = newX
                newFrame.size.width = newWidth
            }
            
        case 4: // right
            let newWidth = newFrame.width + translation.x
            if newWidth >= minEdgeSize {
                newFrame.size.width = newWidth
            }
            
        default:
            break
        }
        
        gameView.frame = newFrame
        gesture.setTranslation(.zero, in: self.view)
        
        if gesture.state == .ended {
            // 执行优化
            optimizeScale(for: gameView)
            updatedTopViewVisual(toneDown: false)
        }
    }
    
    // MARK: - 优化缩放（限制最大尺寸不超出屏幕）
    private func optimizeScale(for view: UIView) {
        let currentFrame = view.frame
        
        func fixPosition() {
            let maxWidth = screensContainerView.frame.width
            let maxHeight = screensContainerView.frame.height
            
            let edgeMinX = UIScreen.main.bounds.minX - screensContainerView.frame.minX
            let edgeMaxX = UIScreen.main.bounds.width - screensContainerView.frame.maxX
            
            let edgeMinY = UIScreen.main.bounds.minY - screensContainerView.frame.minY
            let edgeMaxY = UIScreen.main.bounds.height - screensContainerView.frame.maxY
            
            // 保证位置在屏幕范围内
            var newFrame = view.frame
            var newOrigin = newFrame.origin
            
            if newFrame.minX < edgeMinX {
                newOrigin.x = edgeMinX
            } else if newFrame.maxX > maxWidth + edgeMaxX {
                newOrigin.x = maxWidth - newFrame.width + edgeMaxX
            }
            
            if newFrame.minY < edgeMinY {
                newOrigin.y = edgeMinY
            } else if newFrame.maxY > maxHeight + edgeMaxY {
                newOrigin.y = maxHeight - newFrame.height + edgeMaxY
            }
            
            newFrame.origin = newOrigin
            
            UIView.animate(withDuration: 0.25) {
                view.frame = newFrame
            }
        }
        
        let maxWidth = UIScreen.main.bounds.width
        let maxHeight = UIScreen.main.bounds.height
        
        // 如果视图超出屏幕边界，需要缩小
        if currentFrame.width > maxWidth || currentFrame.height > maxHeight {
            // 计算需要缩放到屏幕宽度和高度的比例
            let widthScale = maxWidth / currentFrame.width
            let heightScale = maxHeight / currentFrame.height
            
            // 取较小的比例，确保视图不会超出任何一边
            let scale = min(widthScale, heightScale)
            
            // 计算目标尺寸
            let targetSize = CGSize(
                width: currentFrame.width * scale,
                height: currentFrame.height * scale
            )
            
            // 计算相对于当前frame的缩放比例
            let scaleX = targetSize.width / currentFrame.width
            let scaleY = targetSize.height / currentFrame.height
            
            UIView.animate(withDuration: 0.25, animations: {
                view.transform = view.transform.scaledBy(x: scaleX, y: scaleY)
            }, completion: { _ in
                fixPosition()
            })
        } else {
            fixPosition()
        }
    }
    
    
    // MARK: - 优化位置（边缘吸附、居中吸附、两个View靠近吸附）
    private func optimizePosition(for view: UIView) {
        let frame = view.frame
        var finalCenter = view.center
        
        var isFixScreenOutside = false
        
        let edgeMinX = UIScreen.main.bounds.minX - screensContainerView.frame.minX
        let edgeMaxX = UIScreen.main.bounds.width - screensContainerView.frame.maxX
        
        // Step 1: 超出屏幕边缘 - 调整回可见区域（最高优先）
        if frame.minX < edgeMinX {
            finalCenter.x += (-frame.minX + edgeMinX)
            isFixScreenOutside = true
        } else if frame.maxX > screensContainerView.frame.width + edgeMaxX {
            finalCenter.x -= (frame.maxX - screensContainerView.frame.width - edgeMaxX)
            isFixScreenOutside = true
        }
        
        let edgeMinY = UIScreen.main.bounds.minY - screensContainerView.frame.minY
        let edgeMaxY = UIScreen.main.bounds.height - screensContainerView.frame.maxY
        
        if frame.minY < edgeMinY {
            finalCenter.y += (-frame.minY + edgeMinY)
            isFixScreenOutside = true
        } else if frame.maxY > screensContainerView.frame.height + edgeMaxY {
            finalCenter.y -= (frame.maxY - screensContainerView.frame.height - edgeMaxY)
            isFixScreenOutside = true
        }
        
        if !isFixScreenOutside {
            // Step 2: 视图与视图边缘吸附（增强版）
            var isFixViewEdge = false
            if screensViews.count == 2 {
                let otherView = screensViews.first { $0 != view }!
                let f1 = view.frame
                let f2 = otherView.frame
                
                // --- 横向边缘吸附 ---
                let yOverlap = (f1.maxY > f2.minY || abs(f1.maxY - f2.minY) < minDistanceToAnotherView) && (f1.minY < f2.maxY || abs(f1.minY - f2.maxY) < minDistanceToAnotherView)
                if yOverlap {
                    if abs(f1.maxX - f2.minX) <= minDistanceToAnotherView {
                        finalCenter.x = f2.minX - f1.width / 2
                        isFixViewEdge = true
                    } else if abs(f1.minX - f2.maxX) <= minDistanceToAnotherView {
                        finalCenter.x = f2.maxX + f1.width / 2
                        isFixViewEdge = true
                    } else if abs(f1.maxX - f2.maxX) < minDistanceToAnotherView {
                        finalCenter.x = f2.maxX - f1.width / 2
                        isFixViewEdge = true
                    }  else if abs(f1.minX - f2.minX) < minDistanceToAnotherView {
                        finalCenter.x = f2.minX + f1.width / 2
                        isFixViewEdge = true
                    }
                }
                
                // --- 纵向边缘吸附 ---
                let xOverlap = (f1.maxX > f2.minX || abs(f1.maxX - f2.minX) < minDistanceToAnotherView) && (f1.minX < f2.maxX || abs(f1.minX - f2.maxX) < minDistanceToAnotherView)
                if xOverlap {
                    if abs(f1.maxY - f2.minY) <= minDistanceToAnotherView {
                        finalCenter.y = f2.minY - f1.height / 2
                        isFixViewEdge = true
                    } else if abs(f1.minY - f2.maxY) <= minDistanceToAnotherView {
                        finalCenter.y = f2.maxY + f1.height / 2
                        isFixViewEdge = true
                    } else if abs(f1.maxY - f2.maxY) < minDistanceToAnotherView {
                        finalCenter.y = f2.maxY - f1.height / 2
                        isFixViewEdge = true
                    }  else if abs(f1.minY - f2.minY) < minDistanceToAnotherView {
                        finalCenter.y = f2.minY + f1.height / 2
                        isFixViewEdge = true
                    }
                }
                
                // --- 覆盖吸附：如果当前视图在另一个视图内部，则吸附其四角 ---
                if f2.contains(f1) || f2.intersects(f1) {
                    let cornerPoints: [CGPoint] = [
                        CGPoint(x: f2.minX + f1.width / 2, y: f2.minY + f1.height / 2), // 左上角
                        CGPoint(x: f2.maxX - f1.width / 2, y: f2.minY + f1.height / 2), // 右上角
                        CGPoint(x: f2.minX + f1.width / 2, y: f2.maxY - f1.height / 2), // 左下角
                        CGPoint(x: f2.maxX - f1.width / 2, y: f2.maxY - f1.height / 2)  // 右下角
                    ]
                    
                    for point in cornerPoints {
                        let dx = abs(finalCenter.x - point.x)
                        let dy = abs(finalCenter.y - point.y)
                        if dx <= minDistanceToAnotherView {
                            //吸附横向
                            var newPoint = finalCenter
                            newPoint.x = point.x
                            finalCenter = newPoint
                            isFixViewEdge = true
                        } else if dy <= minDistanceToAnotherView {
                            //吸附纵向
                            var newPoint = finalCenter
                            newPoint.y = point.y
                            finalCenter = newPoint
                            isFixViewEdge = true
                        }
                    }
                }
            }
            
            if !isFixViewEdge {
                // Step 3: 屏幕边缘 & 居中吸附
                let adjustedFrame = CGRect(origin: CGPoint(x: finalCenter.x - frame.width / 2,
                                                           y: finalCenter.y - frame.height / 2),
                                           size: frame.size)
                
                // 屏幕边缘吸附
                if abs(adjustedFrame.minX) <= minDistanceToEdge {
                    finalCenter.x = frame.width / 2
                } else if abs(adjustedFrame.maxX - screensContainerView.frame.width) <= minDistanceToEdge {
                    finalCenter.x = screensContainerView.frame.width - frame.width / 2
                }
                
                if abs(adjustedFrame.minY) <= minDistanceToEdge {
                    finalCenter.y = frame.height / 2
                } else if abs(adjustedFrame.maxY - screensContainerView.frame.height) <= minDistanceToEdge {
                    finalCenter.y = screensContainerView.frame.height - frame.height / 2
                }
                
                // 居中吸附
                let screenCenter = CGPoint(x: screensContainerView.frame.midX, y: screensContainerView.frame.midY)
                if abs(finalCenter.x - screenCenter.x) <= minDistanceToCenter {
                    finalCenter.x = screenCenter.x
                }
                if abs(finalCenter.y - screenCenter.y) <= minDistanceToCenter {
                    finalCenter.y = screenCenter.y
                }
            }
        }
        
        // 执行动画
        UIView.springAnimate {
            view.center = finalCenter
        }
    }
}

/// Items
extension FlexSkinSettingViewController {
    
    private func setupItemViews(controllerSkin: ControllerSkin, items: [ControllerSkin.Item]) {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews.removeAll()
        initItemFrames.removeAll()
        initItems.removeAll()
        
        let containerSize = buttonsContainerView.bounds.size
        let preferredSize = controlView.controllerSkinSize ?? .medium
        
        for (jsonIndex, item) in items.enumerated() {
            guard shouldCreateFlexItem(item, controllerSkin: controllerSkin) else { continue }
            
            let scaledFrame = item.frame.applying(.init(scaleX: containerSize.width, y: containerSize.height))
            let itemView = FlexItemView(item: item,
                                        itemJSONIndex: jsonIndex,
                                        frame: scaledFrame,
                                        controllerSkin: controllerSkin,
                                        traits: traits,
                                        preferredSize: preferredSize)
            
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleItemPan(_:)))
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleItemPinch(_:)))
            let resizePan = UIPanGestureRecognizer(target: self, action: #selector(handleItemResizePan(_:)))
            itemView.addGestureRecognizer(pan)
            itemView.addGestureRecognizer(pinch)
            itemView.resizeHandle.addGestureRecognizer(resizePan)
            
            buttonsContainerView.addSubview(itemView)
            itemViews.append(itemView)
            initItemFrames.append(scaledFrame)
            initItems.append(item)
        }
    }
    
    private func reloadItemViews(controllerSkin: ControllerSkin, items: [ControllerSkin.Item]) {
        setupItemViews(controllerSkin: controllerSkin, items: items)
    }
    
    private func shouldCreateFlexItem(_ item: ControllerSkin.Item, controllerSkin: ControllerSkin) -> Bool {
        switch item.kind {
        case .touchScreen:
            return false
        case .thumbstick:
            return controllerSkin.thumbstick(for: item, traits: traits, preferredSize: .medium) != nil
        case .button:
            guard let asset = item.asset, case .button(let normal, let selected) = asset else { return false }
            return normal != nil || selected != nil
        case .dPad:
            guard let asset = item.asset, case .dpad(let normal) = asset else { return false }
            return normal != nil
        case .switchButton:
            guard let asset = item.asset, case .switch(let on, let off) = asset else { return false }
            return on != nil || off != nil
        }
    }
    
    private func recordItemGestureStart(for view: UIView) {
        itemGestureStartStates[ObjectIdentifier(view)] = (view.center, view.transform, view.frame)
    }
    
    private func restoreItemGestureStart(for view: UIView) {
        guard let state = itemGestureStartStates[ObjectIdentifier(view)] else { return }
        UIView.springAnimate {
            view.transform = .identity
            view.frame = state.frame
        }
    }
    
    private func bakeItemTransform(into view: UIView) {
        guard view.transform != .identity else { return }
        let bakedFrame = view.frame
        view.transform = .identity
        view.frame = bakedFrame
    }
    
    private func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard intersection.width > 0, intersection.height > 0 else { return 0 }
        return intersection.width * intersection.height
    }
    
    /// 重叠面积小于被遮挡 item 面积的 1/3 时允许重叠
    private func isForbiddenOverlap(movingFrame: CGRect, otherFrame: CGRect) -> Bool {
        let area = overlapArea(movingFrame, otherFrame)
        guard area > 0 else { return false }
        
        let otherArea = otherFrame.width * otherFrame.height
        guard otherArea > 0 else { return false }
        
        return area >= otherArea / 3.0
    }
    
    private func itemHasForbiddenOverlap(_ view: UIView, center: CGPoint? = nil, size: CGSize? = nil) -> Bool {
        let itemSize = size ?? view.frame.size
        var frame: CGRect
        if let center {
            frame = CGRect(x: center.x - itemSize.width / 2,
                           y: center.y - itemSize.height / 2,
                           width: itemSize.width,
                           height: itemSize.height)
        } else {
            frame = view.frame
        }
        
        for other in itemViews where other !== view {
            if isForbiddenOverlap(movingFrame: frame, otherFrame: other.frame) {
                return true
            }
        }
        return false
    }
    
    private func clampItemCenter(_ center: CGPoint, size: CGSize) -> CGPoint {
        let edgeMinX = UIScreen.main.bounds.minX - buttonsContainerView.frame.minX
        let edgeMaxX = UIScreen.main.bounds.width - buttonsContainerView.frame.maxX
        let edgeMinY = UIScreen.main.bounds.minY - buttonsContainerView.frame.minY
        let edgeMaxY = UIScreen.main.bounds.height - buttonsContainerView.frame.maxY
        
        let maxWidth = buttonsContainerView.frame.width
        let maxHeight = buttonsContainerView.frame.height
        
        var center = center
        let halfW = size.width / 2
        let halfH = size.height / 2
        
        center.x = max(halfW + edgeMinX, min(center.x, maxWidth - halfW + edgeMaxX))
        center.y = max(halfH + edgeMinY, min(center.y, maxHeight - halfH + edgeMaxY))
        return center
    }
    
    /// 在目标位置附近寻找满足叠放规则且尽量靠近目标的合法位置
    private func resolveNearestValidItemCenter(for view: UIView, proposed: CGPoint) -> CGPoint {
        let size = view.frame.size
        let clampedProposed = clampItemCenter(proposed, size: size)
        
        if !itemHasForbiddenOverlap(view, center: clampedProposed, size: size) {
            return clampedProposed
        }
        
        let startCenter = itemGestureStartStates[ObjectIdentifier(view)]?.center ?? view.center
        var candidates = [CGPoint]()
        
        // 沿拖动路径从目标向起点回退，取最靠近目标的合法点
        for step in 0...20 {
            let t = CGFloat(step) / 20.0
            let point = CGPoint(x: proposed.x + (startCenter.x - proposed.x) * t,
                                y: proposed.y + (startCenter.y - proposed.y) * t)
            candidates.append(clampItemCenter(point, size: size))
        }
        
        // 尝试贴靠在各冲突 item 的四边外侧
        let proposedFrame = CGRect(x: clampedProposed.x - size.width / 2,
                                   y: clampedProposed.y - size.height / 2,
                                   width: size.width,
                                   height: size.height)
        for other in itemViews where other !== view {
            guard isForbiddenOverlap(movingFrame: proposedFrame, otherFrame: other.frame) else { continue }
            
            let f2 = other.frame
            candidates.append(clampItemCenter(CGPoint(x: f2.minX - size.width / 2, y: clampedProposed.y), size: size))
            candidates.append(clampItemCenter(CGPoint(x: f2.maxX + size.width / 2, y: clampedProposed.y), size: size))
            candidates.append(clampItemCenter(CGPoint(x: clampedProposed.x, y: f2.minY - size.height / 2), size: size))
            candidates.append(clampItemCenter(CGPoint(x: clampedProposed.x, y: f2.maxY + size.height / 2), size: size))
            
            candidates.append(clampItemCenter(CGPoint(x: f2.minX - size.width / 2, y: f2.minY - size.height / 2), size: size))
            candidates.append(clampItemCenter(CGPoint(x: f2.maxX + size.width / 2, y: f2.minY - size.height / 2), size: size))
            candidates.append(clampItemCenter(CGPoint(x: f2.minX - size.width / 2, y: f2.maxY + size.height / 2), size: size))
            candidates.append(clampItemCenter(CGPoint(x: f2.maxX + size.width / 2, y: f2.maxY + size.height / 2), size: size))
        }
        
        let validCandidates = candidates.filter { !itemHasForbiddenOverlap(view, center: $0, size: size) }
        if let best = validCandidates.min(by: {
            hypot($0.x - proposed.x, $0.y - proposed.y) < hypot($1.x - proposed.x, $1.y - proposed.y)
        }) {
            return best
        }
        
        return clampItemCenter(startCenter, size: size)
    }
    
    private func finalizeItemPlacement(for view: UIView, proposedCenter: CGPoint) {
        let resolved = resolveNearestValidItemCenter(for: view, proposed: proposedCenter)
        if itemHasForbiddenOverlap(view, center: resolved, size: view.frame.size) {
            restoreItemGestureStart(for: view)
        } else {
            UIView.springAnimate {
                view.center = resolved
            }
        }
    }
    
    private func createItemFrame(for view: UIView, center: CGPoint) -> CGRect {
        CGRect(origin: CGPoint(x: center.x - view.frame.width / 2, y: center.y - view.frame.height / 2),
               size: view.frame.size)
    }
    
    // MARK: - 创建与手势
    
    @objc private func handleItemResizePan(_ gesture: UIPanGestureRecognizer) {
        guard let handle = gesture.view,
              let itemView = handle.superview as? FlexItemView else { return }
        
        switch gesture.state {
        case .began:
            bakeItemTransform(into: itemView)
            recordItemGestureStart(for: itemView)
            let frame = itemView.frame
            guard frame.width > 0, frame.height > 0 else { return }
            itemResizeStates[ObjectIdentifier(itemView)] = ItemResizeState(
                anchor: CGPoint(x: frame.minX, y: frame.minY),
                aspectRatio: frame.width / frame.height
            )
            updatedTopViewVisual(toneDown: true)
            
        case .changed:
            guard let state = itemResizeStates[ObjectIdentifier(itemView)] else { return }
            
            let location = gesture.location(in: buttonsContainerView)
            var newWidth = location.x - state.anchor.x
            var newHeight = location.y - state.anchor.y
            
            // 保持宽高比，跟随拖动幅度较大的轴向
            if newWidth / state.aspectRatio > newHeight {
                newHeight = newWidth / state.aspectRatio
            } else {
                newWidth = newHeight * state.aspectRatio
            }
            
            if newWidth < minItemSize {
                newWidth = minItemSize
                newHeight = newWidth / state.aspectRatio
            }
            if newHeight < minItemSize {
                newHeight = minItemSize
                newWidth = newHeight * state.aspectRatio
            }
            
            let edgeMinX = UIScreen.main.bounds.minX - buttonsContainerView.frame.minX
            let edgeMaxX = UIScreen.main.bounds.width - buttonsContainerView.frame.maxX
            //            let edgeMinY = UIScreen.main.bounds.minY - buttonsContainerView.frame.minY
            let edgeMaxY = UIScreen.main.bounds.height - buttonsContainerView.frame.maxY
            
            let maxWidth = buttonsContainerView.frame.width + edgeMaxX - state.anchor.x
            let maxHeight = buttonsContainerView.frame.height + edgeMaxY - state.anchor.y
            
            if newWidth > maxWidth {
                newWidth = maxWidth
                newHeight = newWidth / state.aspectRatio
            }
            if newHeight > maxHeight {
                newHeight = maxHeight
                newWidth = newHeight * state.aspectRatio
            }
            
            if state.anchor.x < edgeMinX {
                let limitWidth = buttonsContainerView.frame.width + edgeMaxX - edgeMinX
                if newWidth > limitWidth {
                    newWidth = limitWidth
                    newHeight = newWidth / state.aspectRatio
                }
            }
            
            itemView.frame = CGRect(x: state.anchor.x, y: state.anchor.y, width: newWidth, height: newHeight)
            
            let frame = itemView.frame
            if frame.minX < 0 || frame.maxX > buttonsContainerView.frame.width ||
                frame.minY < 0 || frame.maxY > buttonsContainerView.frame.height {
                triggerThrottledHaptic(style: .medium)
            }
            
        case .ended, .cancelled:
            itemResizeStates.removeValue(forKey: ObjectIdentifier(itemView))
            
            if itemView.frame.width < minItemSize || itemView.frame.height < minItemSize {
                restoreItemGestureStart(for: itemView)
            } else {
                finalizeItemPlacement(for: itemView, proposedCenter: itemView.center)
            }
            updatedTopViewVisual(toneDown: false)
            
        default:
            break
        }
    }
    
    @objc private func handleItemPan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        
        switch gesture.state {
        case .began:
            recordItemGestureStart(for: view)
        case .changed:
            updatedTopViewVisual(toneDown: true)
            let translation = gesture.translation(in: self.view)
            view.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
            gesture.setTranslation(.zero, in: self.view)
            
            let center = view.center
            let containerCenter = CGPoint(x: buttonsContainerView.frame.midX, y: buttonsContainerView.frame.midY)
            
            if abs(center.x - containerCenter.x) <= itemMinDistanceToCenter / 2 ||
                abs(center.y - containerCenter.y) <= itemMinDistanceToCenter / 2 {
                triggerThrottledHaptic(style: .light)
            }
            
            let frame = view.frame
            if frame.minX < 0 || frame.maxX > buttonsContainerView.frame.width ||
                frame.minY < 0 || frame.maxY > buttonsContainerView.frame.height {
                triggerThrottledHaptic(style: .medium)
            }
            
            for other in itemViews where other !== view {
                let f1 = frame
                let f2 = other.frame
                
                let horizontalNear = abs(f1.maxX - f2.minX) <= itemMinDistanceToAnotherView ||
                abs(f1.minX - f2.maxX) <= itemMinDistanceToAnotherView
                let verticalOverlap = f1.maxY > f2.minY && f1.minY < f2.maxY
                let verticalNear = abs(f1.maxY - f2.minY) <= itemMinDistanceToAnotherView ||
                abs(f1.minY - f2.maxY) <= itemMinDistanceToAnotherView
                let horizontalOverlap = f1.maxX > f2.minX && f1.minX < f2.maxX
                
                if (horizontalNear && verticalOverlap) || (verticalNear && horizontalOverlap) {
                    triggerThrottledHaptic()
                }
            }
            
        case .ended, .cancelled:
            let proposedCenter = proposedItemCenter(for: view)
            finalizeItemPlacement(for: view, proposedCenter: proposedCenter)
            updatedTopViewVisual(toneDown: false)
        default:
            break
        }
    }
    
    @objc private func handleItemPinch(_ gesture: UIPinchGestureRecognizer) {
        guard let view = gesture.view else { return }
        
        switch gesture.state {
        case .began:
            recordItemGestureStart(for: view)
        case .changed:
            updatedTopViewVisual(toneDown: true)
            view.transform = view.transform.scaledBy(x: gesture.scale, y: gesture.scale)
            gesture.scale = 1
            
            let frame = view.frame
            if frame.minX < 0 || frame.maxX > buttonsContainerView.frame.width ||
                frame.minY < 0 || frame.maxY > buttonsContainerView.frame.height {
                triggerThrottledHaptic(style: .medium)
            }
        case .ended, .cancelled:
            optimizeItemScale(for: view) { [weak self, weak view] in
                guard let self, let view else { return }
                self.bakeItemTransform(into: view)
                self.finalizeItemPlacement(for: view, proposedCenter: view.center)
                self.updatedTopViewVisual(toneDown: false)
            }
        default:
            break
        }
    }
    
    // MARK: - 优化缩放
    
    private func optimizeItemScale(for view: UIView, completion: (() -> Void)? = nil) {
        let currentFrame = view.frame
        
        func fixPosition() {
            let maxWidth = buttonsContainerView.frame.width
            let maxHeight = buttonsContainerView.frame.height
            
            let edgeMinX = UIScreen.main.bounds.minX - buttonsContainerView.frame.minX
            let edgeMaxX = UIScreen.main.bounds.width - buttonsContainerView.frame.maxX
            let edgeMinY = UIScreen.main.bounds.minY - buttonsContainerView.frame.minY
            let edgeMaxY = UIScreen.main.bounds.height - buttonsContainerView.frame.maxY
            
            var newFrame = view.frame
            var newOrigin = newFrame.origin
            
            if newFrame.minX < edgeMinX {
                newOrigin.x = edgeMinX
            } else if newFrame.maxX > maxWidth + edgeMaxX {
                newOrigin.x = maxWidth - newFrame.width + edgeMaxX
            }
            
            if newFrame.minY < edgeMinY {
                newOrigin.y = edgeMinY
            } else if newFrame.maxY > maxHeight + edgeMaxY {
                newOrigin.y = maxHeight - newFrame.height + edgeMaxY
            }
            
            newFrame.origin = newOrigin
            
            UIView.animate(withDuration: 0.25) {
                view.frame = newFrame
            } completion: { _ in
                completion?()
            }
        }
        
        if currentFrame.width < minItemSize || currentFrame.height < minItemSize {
            restoreItemGestureStart(for: view)
            completion?()
            return
        }
        
        let maxWidth = UIScreen.main.bounds.width
        let maxHeight = UIScreen.main.bounds.height
        
        if currentFrame.width > maxWidth || currentFrame.height > maxHeight {
            let widthScale = maxWidth / currentFrame.width
            let heightScale = maxHeight / currentFrame.height
            let scale = min(widthScale, heightScale)
            let targetSize = CGSize(width: currentFrame.width * scale, height: currentFrame.height * scale)
            let scaleX = targetSize.width / currentFrame.width
            let scaleY = targetSize.height / currentFrame.height
            
            UIView.animate(withDuration: 0.25, animations: {
                view.transform = view.transform.scaledBy(x: scaleX, y: scaleY)
            }, completion: { _ in
                fixPosition()
            })
        } else {
            fixPosition()
        }
    }
    
    // MARK: - 优化位置
    
    private func proposedItemCenter(for view: UIView) -> CGPoint {
        let frame = view.frame
        var finalCenter = view.center
        var isFixScreenOutside = false
        
        let edgeMinX = UIScreen.main.bounds.minX - buttonsContainerView.frame.minX
        let edgeMaxX = UIScreen.main.bounds.width - buttonsContainerView.frame.maxX
        let edgeMinY = UIScreen.main.bounds.minY - buttonsContainerView.frame.minY
        let edgeMaxY = UIScreen.main.bounds.height - buttonsContainerView.frame.maxY
        
        if frame.minX < edgeMinX {
            finalCenter.x += (-frame.minX + edgeMinX)
            isFixScreenOutside = true
        } else if frame.maxX > buttonsContainerView.frame.width + edgeMaxX {
            finalCenter.x -= (frame.maxX - buttonsContainerView.frame.width - edgeMaxX)
            isFixScreenOutside = true
        }
        
        if frame.minY < edgeMinY {
            finalCenter.y += (-frame.minY + edgeMinY)
            isFixScreenOutside = true
        } else if frame.maxY > buttonsContainerView.frame.height + edgeMaxY {
            finalCenter.y -= (frame.maxY - buttonsContainerView.frame.height - edgeMaxY)
            isFixScreenOutside = true
        }
        
        if !isFixScreenOutside {
            var isFixViewEdge = false
            
            for otherView in itemViews where otherView !== view {
                let f1 = createItemFrame(for: view, center: finalCenter)
                let f2 = otherView.frame
                
                let yOverlap = (f1.maxY > f2.minY || abs(f1.maxY - f2.minY) < itemMinDistanceToAnotherView) &&
                (f1.minY < f2.maxY || abs(f1.minY - f2.maxY) < itemMinDistanceToAnotherView)
                if yOverlap {
                    if abs(f1.maxX - f2.minX) <= itemMinDistanceToAnotherView {
                        finalCenter.x = f2.minX - f1.width / 2
                        isFixViewEdge = true
                    } else if abs(f1.minX - f2.maxX) <= itemMinDistanceToAnotherView {
                        finalCenter.x = f2.maxX + f1.width / 2
                        isFixViewEdge = true
                    } else if abs(f1.maxX - f2.maxX) < itemMinDistanceToAnotherView {
                        finalCenter.x = f2.maxX - f1.width / 2
                        isFixViewEdge = true
                    } else if abs(f1.minX - f2.minX) < itemMinDistanceToAnotherView {
                        finalCenter.x = f2.minX + f1.width / 2
                        isFixViewEdge = true
                    }
                }
                
                let xOverlap = (f1.maxX > f2.minX || abs(f1.maxX - f2.minX) < itemMinDistanceToAnotherView) &&
                (f1.minX < f2.maxX || abs(f1.minX - f2.maxX) < itemMinDistanceToAnotherView)
                if xOverlap {
                    if abs(f1.maxY - f2.minY) <= itemMinDistanceToAnotherView {
                        finalCenter.y = f2.minY - f1.height / 2
                        isFixViewEdge = true
                    } else if abs(f1.minY - f2.maxY) <= itemMinDistanceToAnotherView {
                        finalCenter.y = f2.maxY + f1.height / 2
                        isFixViewEdge = true
                    } else if abs(f1.maxY - f2.maxY) < itemMinDistanceToAnotherView {
                        finalCenter.y = f2.maxY - f1.height / 2
                        isFixViewEdge = true
                    } else if abs(f1.minY - f2.minY) < itemMinDistanceToAnotherView {
                        finalCenter.y = f2.minY + f1.height / 2
                        isFixViewEdge = true
                    }
                }
            }
            
            if !isFixViewEdge {
                let adjustedFrame = createItemFrame(for: view, center: finalCenter)
                
                if abs(adjustedFrame.minX) <= itemMinDistanceToEdge {
                    finalCenter.x = frame.width / 2
                } else if abs(adjustedFrame.maxX - buttonsContainerView.frame.width) <= itemMinDistanceToEdge {
                    finalCenter.x = buttonsContainerView.frame.width - frame.width / 2
                }
                
                if abs(adjustedFrame.minY) <= itemMinDistanceToEdge {
                    finalCenter.y = frame.height / 2
                } else if abs(adjustedFrame.maxY - buttonsContainerView.frame.height) <= itemMinDistanceToEdge {
                    finalCenter.y = buttonsContainerView.frame.height - frame.height / 2
                }
                
                let containerCenter = CGPoint(x: buttonsContainerView.frame.midX, y: buttonsContainerView.frame.midY)
                if abs(finalCenter.x - containerCenter.x) <= itemMinDistanceToCenter {
                    finalCenter.x = containerCenter.x
                }
                if abs(finalCenter.y - containerCenter.y) <= itemMinDistanceToCenter {
                    finalCenter.y = containerCenter.y
                }
            }
        }
        
        return finalCenter
    }
}
