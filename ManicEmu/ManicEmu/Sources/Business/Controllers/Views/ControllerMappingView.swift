//
//  ControllerMappingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift

class ControllerMappingView: BaseView {
    private lazy var controllerView: ControllerView = {
        let view = ControllerView()
        view.layerCornerRadius = R.Size.CornerRadiusMedium
        view.addReceiver(self)
        return view
    }()
    
    private var inputPopupView = MappingInputPopupView()
    
    private lazy var tipsView: ASNavigationView = {
        let view = ASNavigationView(getTips(.normal))
        view.didTapClose = { [weak self] in
            guard let self else { return }
            self.stopMapping()
        }
        view.layerCornerRadius = R.Size.CornerRadiusMedium
        return view
    }()
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(getNavigation())
        view.didTapClose = { [weak self] in
            guard let self = self else { return }
            self.saveMappings()
            self.didTapClose?()
        }
        view.didTapTools = { [weak self] index in
            guard let self = self else { return }
            self.stopMapping()
            if index == 0 {
                //keyboard input mapping
                var allKeyboadInputs = LibretroKeyboardCode.getAllKeyboarLabels()
                var options = allKeyboadInputs.map({ label in
                    var mappingInfo = ""
                    if let mappingKey = self.currentGameTypeMapping.inputMappings.first(where: { $1.stringValue == label })?.key,
                        mappingKey != label {
                        mappingInfo = " ( \(mappingKey) ➔ \(label) )"
                    }
                    return label + mappingInfo
                })
                ChevronSheetView.show(icon: .symbolImage(R.image.keyboard_iconSymbols()),
                                      title: R.string.localizable.mappingKeyboardInput(),
                                      detail: R.string.localizable.mappingKeyboardInputDesc(),
                                      stringOptions: options, completion: { [weak self] optionIndex in
                    guard let self else { return }
                    if let optionIndex {
                        self.startMapping(input: AnyInput(stringValue: allKeyboadInputs[optionIndex],
                                                          intValue: nil,
                                                          type: .controller(GameControllerInputType("directKeyboard"))))
                    }
                })
                
                
            } else if index == 1 {
                //reload
                self.resetMapping()
                self.updateDatas()
            }
        }
        if games.count == 0 {
            view.didTapTitle = { [weak self] in
                guard let self = self else { return }
                //change gameTypes
                let allGameTypes = System.allGameTypes.filter({ !$0.externalType })
                OptionsSheetView.show(icon: .symbolImage(R.image.controller_iconSymbols()),
                                      title: R.string.localizable.changeGameType(),
                                      options: allGameTypes.map({ $0.localizedShortName }),
                                      selectedIndex: allGameTypes.firstIndex(of: self.gameType),
                                      groupTogether: true,
                                      completion: { index in
                    if let index {
                        self.stopMapping()
                        self.gameType = allGameTypes[index]
                        self.navigationView.navigation = self.getNavigation()
                        self.updateDatas()
                    }
                })
            }
        }
        
        view.layerCornerRadius = R.Size.NavigationHeight/2
        
        return view
    }()
    
    private lazy var mappingOptionsView: MappingOptionsView = {
        let view = MappingOptionsView()
        view.didTapOption = { [weak self] option in
            guard let self else { return }
            self.startMapping(input: AnyInput(stringValue: option.rawValue, intValue: nil, type: .controller(.standard)))
        }
        return view
    }()
    
    private let games: [Game]
    private var gameType: GameType {
        didSet {
            let core = Delta.core(for: gameType)
            let fileURL = core!.resourceBundle.url(forResource: core!.name, withExtension: "keymapping")
            skinInputMapping = try! GameControllerInputMapping(fileURL: fileURL!)
        }
    }
    private var gameController: GameController
    private var selectedSkinInput: Input? = nil
    private var modifiedList = [GameType]()
    private var isKeyMapping = false
    ///修改过的控制器映射
    private var modifiedControllerMappings: [GameType: GameControllerInputMapping] = [:]
    ///默认控制器映射
    private lazy var defaultControllerMapping: GameControllerInputMapping = {
        return (gameController.defaultInputMapping as! GameControllerInputMapping)
    }()
    ///获取当前gameType的控制器映射
    private var currentGameTypeMapping: GameControllerInputMapping {
        if let inputMapping = modifiedControllerMappings[gameType] {
            return inputMapping
        } else {
            let realm = Database.realm
            if let object = realm.objects(ControllerMapping.self).first(where: { $0.controllerName == gameController.name && $0.gameType == gameType && !$0.isDeleted }), let inputMapping = try? GameControllerInputMapping(mapping: object.mapping) {
                modifiedControllerMappings[gameType] = inputMapping
                return inputMapping
            } else {
                let inputMapping = gameController.defaultInputMapping! as! GameControllerInputMapping
                modifiedControllerMappings[gameType] = inputMapping
                return inputMapping
            }
        }
    }
    private lazy var skinInputMapping: GameControllerInputMapping = {
        let core = Delta.core(for: gameType)
        let fileURL = core!.resourceBundle.url(forResource: core!.name, withExtension: "keymapping")
        let mapping = try! GameControllerInputMapping(fileURL: fileURL!)
        return mapping
    }()
    
    ///点击关闭按钮回调
    var didTapClose: (()->Void)? = nil
    
    deinit {
        gameController.removeReceiver(self)
    }
    
    init(games: [Game], controller: GameController) {
        self.games = games
        self.gameType = games.first?.gameType ?? System.allGameTypes.first!
        self.gameController = controller
        super.init(frame: .zero)
        setupInit()
    }
    
    init(gameType: GameType, controller: GameController) {
        self.gameType = gameType
        self.gameController = controller
        self.games = []
        super.init(frame: .zero)
        setupInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateDatas()
    }
    
    private func setupInit() {
        self.backgroundColor = .black
        
        if gameController.inputType == .keyboard, let keyboardController = gameController as? KeyboardGameController {
            //如果是键盘的话 需要特殊处理 监听键盘的按键
            keyboardController.keyboardPress = { [weak self] pressKey in
                guard let self = self else { return }
                self.mapKeyboard(pressKey: pressKey)
            }
        } else {
            gameController.addReceiver(self)
        }
        
        
        addSubview(controllerView)
        controllerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(inputPopupView)
        inputPopupView.snp.makeConstraints { make in
            make.edges.equalTo(controllerView)
        }
        
        addSubview(mappingOptionsView)
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(R.Size.SafeArea.top)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(R.Size.ContentSpaceHuge)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(tipsView)
        tipsView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(navigationView)
            make.height.equalTo(R.Size.NavigationHeight)
        }
    }
    
    private func updateDatas() {
        if let controlerSkin = ControllerSkin.standardControllerSkin(for: gameType),
            let frames = controlerSkin.getFrames() {
            controllerView.controllerSkin = controlerSkin
            controllerView.snp.remakeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(frames.skinFrame.size)
            }
            
            if gameController.inputType == .keyboard {
                controllerView.becomeFirstResponder()
            }
            
            setupMappingBubble()
            
            if games.count > 0 {
                mappingOptionsView.updateContents(games: games)
            } else {
                let game = Game()
                game.gameType = gameType
                mappingOptionsView.updateContents(games: [game])
            }
            let navigationBottom = navigationView.frame.maxY + R.Size.ContentSpaceLarge
            let controllerViewTop = frames.mainGameViewFrame.minY + controllerView.frame.minY
            let y = max(navigationBottom, controllerViewTop)
            var height = frames.mainGameViewFrame.height
            if navigationBottom > controllerViewTop {
                height -= (navigationBottom - controllerViewTop)
            }
            mappingOptionsView.frame = CGRect(x: frames.mainGameViewFrame.minX + controllerView.frame.minX,
                                           y: y,
                                           width: frames.mainGameViewFrame.width,
                                           height: height)
            
            tipsView.snp.remakeConstraints { make in
                var moreOffset = 0.0
                if gameType.usesDOSSkinLayout {
                    moreOffset = R.Size.ContentSpaceExtraSmall
                }
                make.top.equalTo(frames.mainGameViewFrame.maxY + R.Size.ContentSpaceExtraSmall + moreOffset)
                make.height.equalTo(R.Size.NavigationHeight)
                make.width.equalTo(frames.mainGameViewFrame.width - R.Size.ContentSpaceMedium*2)
                make.centerX.equalToSuperview()
            }
        }
    }
    
    enum TipsType {
        case normal
        case mapping(String)
    }
    
    private func getTips(_ type: TipsType) -> ASListPage.Navigation {
        let title: ASText
        let enableClose: Bool
        switch type {
        case .normal:
            title = .init(attributes: .init(text: R.string.localizable.controllerMappingGuideTitle(),
                                            font: R.Font.Headline(emphasis: true),
                                            alignment: .center))
            enableClose = false
            
            
        case .mapping(let string):
            title = .init(attributes: .init(text: R.string.localizable.controllerMappingGuideBegin(string),
                                            font: R.Font.Body(emphasis: true),
                                            alignment: .left,
                                            numberOfLines: 0))
            enableClose = true
        }
        
        return ASListPage.Navigation(title: title,
                                     backgroundColor: R.Color.BackgroundPrimary,
                                     enableClose: enableClose,
                                     closeBackground: R.Color.Red)
    }
    
    private func getNavigation() -> ASListPage.Navigation {
        let title: ASText
        if games.count == 1, let game = games.first {
            title = .extraLargeText(game.displayName)
        } else {
            let titleString = gameType.localizedShortName
            let titleIcons: [ASText.Icon] = [.init(icon: .symbolImage(R.image.chevronUpdown_iconSymbols()),
                                                   position: UInt(titleString.count))]
            title = ASText(attributes: .init(text: titleString,
                                             font: R.Font.Headline(emphasis: true)),
                           textIcons: titleIcons)
        }
        
        return ASListPage.Navigation(title: title,
                                     tools: [
                                        .symbolImage(R.image.keyboard_iconSymbols()),
                                        .symbolImage(R.image.refresh_iconSymbols()),
                                     ],
                                     backgroundColor: R.Color.BackgroundPrimary)
    }
    
    private func mapKeyboard(pressKey: String) {
        //进行键盘映射
        if let selectedSkinInput,
            !isKeyMapping {
            //记录修改过
            if !modifiedList.contains([gameType]) {
                modifiedList.append(gameType)
            }
            
            isKeyMapping = true
            defer {
                DispatchQueue.main.asyncAfter(delay: 0.1) {
                    self.isKeyMapping = false
                    self.stopMapping()
                }
            }
            
            Log.debug("[ControllerMappingView] 点击键盘:\(pressKey)")
            Log.debug("[ControllerMappingView] 开始添加映射 [\(pressKey)] -> [\(selectedSkinInput.stringValue)]")
            
            var mapping = currentGameTypeMapping
            var inputMappings = mapping.inputMappings
            var occupiedInputMappings = [String: AnyInput]()
            for (keyboardInputString, mappingInput) in inputMappings {
                if mappingInput.stringValue == selectedSkinInput.stringValue {
                    Log.debug("[ControllerMappingView] 皮肤按键 [\(selectedSkinInput.stringValue)] 被键盘按键 [\(keyboardInputString)] 占用")
                    occupiedInputMappings[keyboardInputString] = mappingInput
                }
            }
            
            if occupiedInputMappings.count > 0 {
                occupiedInputMappings.forEach { keyboardInputString, mappingInput in
                    Log.debug("[ControllerMappingView] 移除被占用的映射 [\(keyboardInputString)] -> [\(selectedSkinInput.stringValue)]")
                    inputMappings[keyboardInputString] = nil
                }
            }
            
            inputMappings[pressKey] = AnyInput(selectedSkinInput)
            mapping.inputMappings = inputMappings
            modifiedControllerMappings[gameType] = mapping
            Log.debug("[ControllerMappingView] 完成添加映射 [\(pressKey)] -> [\(selectedSkinInput.stringValue)]")
            Log.debug("[ControllerMappingView] \(gameType) 完整映射列表:\(mapping.inputMappings.reduce("", { $0 + "\n" + "\($1.key) -> \($1.value.stringValue)"}))\n\n")
            setupMappingBubble()
        }
    }
    
    private func getSkinInput(_ skinInput: Input) -> (key: String, input: AnyInput)? {
        if let input = skinInputMapping.inputMappings[skinInput.stringValue] {
            return (skinInput.stringValue, input)
        } else {
            for (key, value) in skinInputMapping.inputMappings {
                if value.stringValue == skinInput.stringValue {
                    return (key, value)
                }
            }
        }
        if skinInput.stringValue.lowercased() == "menu" {
            return ("menu", AnyInput(skinInput))
        }
        //Check if it's a function key.
        if let _ = MappingOption(rawValue: skinInput.stringValue) {
            return (skinInput.stringValue, AnyInput(skinInput))
        }
        return nil
    }
    
    private func shortName(for controllerInputString: String) -> String? {
        var inputString: String? = nil
        
        for (s, i) in currentGameTypeMapping.inputMappings {
            if i.stringValue == controllerInputString {
                inputString = s
                break
            }
        }
        
        guard let inputString else { return nil }
        
        if inputString == "leftShoulder" {
            return "L1"
        } else if inputString == "leftThumbstickDown" {
            return "L↓"
        } else if inputString == "leftThumbstickLeft" {
            return "L←"
        } else if inputString == "leftThumbstickRight" {
            return "L→"
        } else if inputString == "leftThumbstickUp" {
            return "L↑"
        } else if inputString == "leftTrigger" {
            return "L2"
        } else if inputString == "leftThumbstickButton" {
            return "L3"
        }  else if inputString == "rightShoulder" {
            return "R1"
        } else if inputString == "rightThumbstickDown" {
            return "R↓"
        } else if inputString == "rightThumbstickLeft" {
            return "R←"
        } else if inputString == "rightThumbstickRight" {
            return "R→"
        } else if inputString == "rightThumbstickUp" {
            return "R↑"
        } else if inputString == "rightTrigger" {
            return "R2"
        } else if inputString == "rightThumbstickButton" {
            return "R3"
        } else {
            if let firstUppercased = inputString.first?.uppercased() {
                return firstUppercased + inputString.dropFirst()
            }
        }
        return inputString
    }
    
    private func setupMappingBubble() {
        inputPopupView.subviews.forEach { $0.removeFromSuperview() }
        let defaultTraits = ControllerSkin.Traits.defaults(for: UIWindow.applicationWindow ?? UIWindow(frame: .init(origin: .zero, size: R.Size.WindowSize)))
        let traits = controllerView.controllerSkin?.resolvedTraits(for: defaultTraits) ?? defaultTraits
        if let items = controllerView.controllerSkin?.items(for: traits) {
            for item in items {
                let scaledFrame = item.frame.applying(.init(scaleX: inputPopupView.width, y: inputPopupView.height))
                
                switch item.kind {
                case .button, .switchButton:
                    //不支持组合键
                    if let input = item.inputs.allInputs.first {
                        inputPopupView.updateTip(kind: item.kind, inputString: shortName(for: input.stringValue), position: CGPoint(x: scaledFrame.center.x, y: scaledFrame.center.y))
                    }
                case .dPad, .thumbstick:
                    if case .directional(let up, let down, let left, let right) = item.inputs {
                        let minSize = CGSize(width: R.Size.ItemHeightMedium, height: R.Size.ItemHeightTiny)
                        let upFrame = CGRect(center: CGPoint(x: scaledFrame.midX, y: scaledFrame.minY), size: minSize)
                        let downFrame = CGRect(center: CGPoint(x: scaledFrame.midX, y: scaledFrame.maxY), size: minSize)
                        let leftFrame = CGRect(center: CGPoint(x: scaledFrame.minX, y: scaledFrame.midY), size: minSize)
                        let rightFrame = CGRect(center: CGPoint(x: scaledFrame.maxX, y: scaledFrame.midY), size: minSize)
                        let adjustFrames = adjustFrames(up: upFrame, down: downFrame, left: leftFrame, right: rightFrame)
                        inputPopupView.updateTip(kind: item.kind, inputString: shortName(for: up.stringValue), position: adjustFrames.up.center)
                        inputPopupView.updateTip(kind: item.kind, inputString: shortName(for: down.stringValue), position: adjustFrames.down.center)
                        inputPopupView.updateTip(kind: item.kind, inputString: shortName(for: left.stringValue), position: adjustFrames.left.center)
                        inputPopupView.updateTip(kind: item.kind, inputString: shortName(for: right.stringValue), position: adjustFrames.right.center)
                    }
                default: break
                }
            }
        }
    }
    
    func adjustFrames(up: CGRect, down: CGRect, left: CGRect, right: CGRect) -> (up: CGRect, down: CGRect, left: CGRect, right: CGRect) {
        var upFrame = up
        var downFrame = down
        var leftFrame = left
        var rightFrame = right
        
        let minSpacing: CGFloat = R.Size.ItemHeightMicro

        // 垂直方向
        let verticalDistance = downFrame.minY - upFrame.maxY
        if verticalDistance < minSpacing {
            let move = (minSpacing - verticalDistance) / 2
            upFrame.origin.y -= move
            downFrame.origin.y += move
        }

        // 水平方向
        let horizontalDistance = rightFrame.minX - leftFrame.maxX
        if horizontalDistance < minSpacing {
            let move = (minSpacing - horizontalDistance) / 2
            leftFrame.origin.x -= move
            rightFrame.origin.x += move
        }

        return (up: upFrame, down: downFrame, left: leftFrame, right: rightFrame)
    }
    
    private func saveMappings() {
        let realm = Database.realm
        var needToNotify = false
        for (gameType, mapping) in modifiedControllerMappings {
            guard modifiedList.contains([gameType]) else { continue }
            
            if let object = realm.objects(ControllerMapping.self).first(where: { $0.controllerName == gameController.name && $0.gameType == gameType && !$0.isDeleted }) {
                //更新数据库
                ControllerMapping.change { realm in
                    object.mapping = mapping.genMapping()
                }
                needToNotify = true
            } else {
                //插入数据库
                let storeObject = ControllerMapping()
                storeObject.controllerName = gameController.name
                storeObject.gameType = gameType
                storeObject.mapping = mapping.genMapping()
                ControllerMapping.change { realm in
                    realm.add(storeObject)
                }
                needToNotify = true
            }
        }
        if needToNotify {
            NotificationCenter.default.post(name: R.NotificationName.ControllerMapping, object: nil)
        }
    }
    
    private func startMapping(input: DeltaCore.Input) {
        selectedSkinInput = input
        tipsView.navigation = getTips(.mapping(input.stringValue))
        controllerView.isUserInteractionEnabled = false
        if gameController.inputType == .keyboard {
            controllerView.becomeFirstResponder()
        }
    }
    
    private func stopMapping() {
        self.selectedSkinInput = nil
        controllerView.isUserInteractionEnabled = true
        tipsView.navigation = getTips(.normal)
    }
    
    private func resetMapping() {
        modifiedControllerMappings.removeValue(forKey: self.gameType)
        let realm = Database.realm
        if let object = realm.objects(ControllerMapping.self).first(where: { $0.controllerName == gameController.name && $0.gameType == gameType && !$0.isDeleted }) {
            //删除数据
            ControllerMapping.change { realm in
                if Settings.defalut.iCloudSyncEnable {
                    //iCloud同步删除
                    object.isDeleted = true
                } else {
                    //本地删除
                    realm.delete(object)
                }
            }
            NotificationCenter.default.post(name: R.NotificationName.ControllerMapping, object: nil)
        }
        stopMapping()
    }
}

extension ControllerMappingView: GameControllerReceiver {
    //这里只处理mfi控制器
    func gameController(_ gameController: any DeltaCore.GameController, didActivate input: any DeltaCore.Input, value: Double) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.gameController(gameController, didActivate: input, value: value)
            }
            return
        }
        guard gameController.inputType != .keyboard else { return }
        if gameController.inputType == .controllerSkin, selectedSkinInput == nil {
            if input.stringValue.contains("touchScreenX", caseSensitive: false) ||
                input.stringValue.contains("touchScreenY", caseSensitive: false) {
                return
            }
            Log.debug("[ControllerMappingView] 点击皮肤:\(input)")
            startMapping(input: input)
        } else if let selectedSkinInput, gameController.inputType != .controllerSkin, !isKeyMapping {
            
            let isThumbStick = (input.stringValue == "leftThumbstickLeft" ||
                                input.stringValue == "leftThumbstickRight" ||
                                input.stringValue == "leftThumbstickUp" ||
                                input.stringValue == "leftThumbstickDown" ||
                                input.stringValue == "rightThumbstickLeft" ||
                                input.stringValue == "rightThumbstickRight" ||
                                input.stringValue == "rightThumbstickUp" ||
                                input.stringValue == "rightThumbstickDown")
            if isThumbStick, value < 0.5 {
                return
            }
            
            //记录修改过
            if !modifiedList.contains([gameType]) {
                modifiedList.append(gameType)
            }
            
            isKeyMapping = true
            defer {
                DispatchQueue.main.asyncAfter(delay: 0.1) {
                    self.isKeyMapping = false
                    self.stopMapping()
                }
            }
            
            //find real controller key
            guard let realControllerInputString = defaultControllerMapping.inputMappings.first(where: {
                $0.value.stringValue == input.stringValue
            })?.key else {
                UIView.makeToast(message: R.string.localizable.controllerMappingNoFouond())
                return
            }
            
            let controllerInput = AnyInput(stringValue: realControllerInputString, intValue: input.intValue, type: input.type)
            
            Log.debug("[ControllerMappingView] 点击控制器:\(controllerInput)")
            Log.debug("[ControllerMappingView] 开始添加映射 [\(controllerInput.stringValue)] -> [\(selectedSkinInput.stringValue)]")
            
            var mapping = currentGameTypeMapping
            var inputMappings = mapping.inputMappings
            var occupiedInputMappings = [String: AnyInput]()
            for (controllerInputString, mappingInput) in inputMappings {
                if mappingInput.stringValue == selectedSkinInput.stringValue {
                    Log.debug("[ControllerMappingView] 皮肤按键 [\(selectedSkinInput.stringValue)] 被控制器按键 [\(controllerInputString)] 占用")
                    occupiedInputMappings[controllerInputString] = mappingInput
                }
            }
            
            if occupiedInputMappings.count > 0 {
                occupiedInputMappings.forEach { controllerInputString, mappingInput in
                    Log.debug("[ControllerMappingView] 移除被占用的映射 [\(controllerInputString)] -> [\(selectedSkinInput.stringValue)]")
                    inputMappings[controllerInputString] = nil
                }
            }
            
            inputMappings[controllerInput.stringValue] = AnyInput(selectedSkinInput)
            mapping.inputMappings = inputMappings
            modifiedControllerMappings[gameType] = mapping
            Log.debug("[ControllerMappingView] 完成添加映射 [\(controllerInput.stringValue)] -> [\(selectedSkinInput.stringValue)]")
            Log.debug("[ControllerMappingView] \(gameType) 完整映射列表:\(mapping.inputMappings.reduce("", { $0 + "\n" + "\($1.key) -> \($1.value.stringValue)"}))\n\n")
            setupMappingBubble()
        } else {
            Log.debug("[ControllerMappingView] 点击:\(input)")
        }
    }
    
    func gameController(_ gameController: any DeltaCore.GameController, didDeactivate input: any DeltaCore.Input) {
        
    }
}
