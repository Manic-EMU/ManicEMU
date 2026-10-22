//
//  ControllersSettingView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class ControllersSettingView: BaseView {
    private var iconImageView: UIImageView = {
        let view = UIImageView()
        view.image = R.image.controller_background()
        return view
    }()
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            self.handleAction(action)
        }
        return view
    }()
    
    private lazy var controllers: [GameController] = {
        var controllers: [GameController] = []
        //获取已连接的游戏控制器
        for gameController in ExternalGameControllerManager.shared.connectedControllers {
            controllers.append(gameController)
        }
        //屏幕控制器默认排在第一位
        let touch = TouchController()
        touch.playerIndex = PlayViewController.skinControllerPlayerIndex
        controllers.insert(touch, at: 0)
        return controllers
    }()
    
    private let asSideMenu: Bool
    private let games: [Game]
    private let gameType: GameType
    private var hideCompletion: (()->Void)? = nil
    
    private var gameControllerDidConnectNotification: Any? = nil
    private var gameControllerDidDisConnectNotification: Any? = nil
    private var keyboardDidConnectNotification: Any? = nil
    private var keyboardDidDisConnectNotification: Any? = nil
    
    deinit {
        if let gameControllerDidConnectNotification = gameControllerDidConnectNotification {
            NotificationCenter.default.removeObserver(gameControllerDidConnectNotification)
        }
        if let gameControllerDidDisConnectNotification = gameControllerDidDisConnectNotification {
            NotificationCenter.default.removeObserver(gameControllerDidDisConnectNotification)
        }
        if let keyboardDidConnectNotification = keyboardDidConnectNotification {
            NotificationCenter.default.removeObserver(keyboardDidConnectNotification)
        }
        if let keyboardDidDisConnectNotification = keyboardDidDisConnectNotification {
            NotificationCenter.default.removeObserver(keyboardDidDisConnectNotification)
        }
    }
    
    required init?(parameters: Any...) {
        self.asSideMenu = parameters.compactMap({ $0 as? Bool}).first ?? false
        if let games = parameters.compactMap({ $0 as? [Game] }).first {
            self.games = games
        } else {
            self.games = []
        }
        if let gameType = parameters.compactMap({ $0 as? GameType }).first {
            self.gameType = gameType
        } else if self.games.count > 0 {
            self.gameType = self.games.first!.gameType
        } else {
            self.gameType = System.allGameTypes.first!
        }
        super.init(frame: .zero)
        
        addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        gameControllerDidConnectNotification = NotificationCenter.default.addObserver(forName: .externalGameControllerDidConnect, object: nil, queue: .main) { [weak self] notification in
            //手柄连接
            self?.updateExtenalControllers()
        }
        gameControllerDidDisConnectNotification = NotificationCenter.default.addObserver(forName: .externalGameControllerDidDisconnect, object: nil, queue: .main) { [weak self] notification in
            //手柄断开连接
            self?.updateExtenalControllers()
        }
        keyboardDidConnectNotification = NotificationCenter.default.addObserver(forName: .externalKeyboardDidConnect, object: nil, queue: .main) { [weak self] notification in
            //键盘连接
            self?.updateExtenalControllers()
        }
        keyboardDidDisConnectNotification = NotificationCenter.default.addObserver(forName: .externalKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] notification in
            //键盘断开连接
            self?.updateExtenalControllers()
        }
    }
    
    convenience init(asSideMenu: Bool, gameType: GameType? = nil) {
        if let gameType {
            self.init(parameters: asSideMenu, gameType)!
        } else {
            self.init(parameters: asSideMenu)!
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateExtenalControllers() {
        controllers.removeAll { $0.inputType != .controllerSkin }
        controllers.append(contentsOf: ExternalGameControllerManager.shared.connectedControllers)
        updateContents()
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if let navigationValue = action.navigationValue {
            if navigationValue.isTapClose {
                //close
                self.hide()
                
            } else if let index = navigationValue.tapToolsValue {
                if index == 0 {
                    //faq
                    ASWebView.show(url: R.URLs.ControllerUsageGuide)
                    
                } else if index == 1 {
                    //more
                    ChevronSheetView.show(stringOptions: [R.string.localizable.deadZoneSetting()],
                                          completion: { index in
                        if let _ = index {
                            DeadZoneControl.show()
                        }
                    })
                }
            }
        } else if let normalItemValue = action.normalItemValue {
            let index = normalItemValue.indexPath.section
            let controller = controllers[index]
            if let _ = normalItemValue.subActions {
                //show player index
                OptionsSheetView.show(icon: .symbolImage(R.image.controller_iconSymbols()),
                                      title: R.string.localizable.playerIndexChange(),
                                      detail: R.string.localizable.playerIndexDesc(),
                                      options: PlayerIndex.playerCases.map({
                    R.string.localizable.controllersPlayerIndex($0.rawValue+1)
                }), selectedIndex: PlayerIndex.playerCases.firstIndex(where: {
                    if let controllerPlayerIndex = controller.playerIndex,
                       controllerPlayerIndex == $0.rawValue {
                        return true
                    }
                    return false
                }), completion: { [weak self] selectedPlayerIndex in
                    guard let self else { return }
                    if let selectedPlayerIndex,
                       controller.playerIndex != selectedPlayerIndex  {
                        //change player index
                        
                        if !PurchaseManager.isMember {
                            topViewController(in: self.hostingWindowScene)?.present(PurchaseViewController(featuresType: .controler), animated: true)
                            return
                        }
                        
                        if controller.inputType == .controllerSkin {
                            PlayViewController.skinControllerPlayerIndex = selectedPlayerIndex
                        } else {
                            self.controllers.forEach {
                                if $0.playerIndex == selectedPlayerIndex &&
                                    $0.inputType != .controllerSkin {
                                    $0.playerIndex = nil
                                }
                            }
                        }
                        controller.playerIndex = selectedPlayerIndex
                        self.updateContents()
                    }
                })
            } else {
                let vc: ControllerMappingViewController
                if games.count > 0 {
                    vc = .init(games: games, controller: controller)
                } else {
                    vc = .init(gameType: gameType, controller: controller)
                }
                topViewController(in: hostingWindowScene)?.present(vc, animated: true)
            }
        }
    }
    
    private func getListPage() -> ASListPage {
        var navigation = ASListPage.Navigation.defaultNavigation(title: GameOption.controllerSetting.title,
                                                                 titleIcon: GameOption.controllerSetting.icon,
                                                                 tools: [
                                                                    .symbolImage(R.image.faq_iconSymbols()),
                                                                    .symbolImage(R.image.ellipsis_iconSymbols())
                                                                 ])
        navigation.enableClose = !asSideMenu
        navigation.toolsBackground = asSideMenu ? R.Color.BackgroundPrimary : R.Color.BackgroundSecondary
        
        return ASListPage(navigation: navigation,
                          sections: getSections(),
                          backgroundColor: .clear,
                          pageInsets: .insets(top: asSideMenu ? R.Size.ContentInsetTop(window: hostingWindow) : R.Size.SheetGrabberTopInset),
                          enableSafeAreaLeftInsets: UIDevice.isPhoneDuo ? false : true,
                          enableSafeAreaRightInsets: UIDevice.isPhoneDuo ? false : true)
    }
    
    private func getSections() -> [ASListPage.Section] {
        return controllers.map({
            var styles = [ASListPage.Cell.Style]()
            styles.append(.icon($0.icon))
            styles.append(.title(.largeText($0.name)))
            let playerIndexString: String
            if let playerIndex = $0.playerIndex {
                playerIndexString = R.string.localizable.controllersPlayerIndex(playerIndex+1)
            } else {
                playerIndexString = R.string.localizable.controllersPlayerUnset()
            }
            styles.append(.button(.medium(icon: .symbolImage(R.image.chevronUpdown_iconSymbols()),
                                          title: playerIndexString,
                                          titlePosition: .left,
                                          background: asSideMenu ? R.Color.BackgroundSecondary : R.Color.BackgroundTertiary,
                                          sizeStyle: .fixHeight(R.Size.ButtonSmall)).enableGlass(true)))
            if $0.inputType != .controllerSkin {
                styles.append(.chevron(.init()))
            }
            return ASListPage.Section(cells: [ASListPage.Cell.normal(styles, enablePressEffect: $0.inputType != .controllerSkin)],
                                      decoration: .init(enable: true, style: asSideMenu ? .primary : .secondary))
        })
    }
    
    private func updateContents() {
        listPageView.sections = getSections()
    }
    
    func updateTopInsets() {
        guard asSideMenu else { return }
        guard listPageView.pageInsets.top != R.Size.ContentInsetTop(window: hostingWindow) else { return }
        listPageView.pageInsets = .insets(top: R.Size.ContentInsetTop(window: hostingWindow))
    }
}

extension ControllersSettingView: ShowableView {
    static func show(games: [Game], hideCompletion: (()->Void)? = nil) {
        let asSideMenu = false
        Self.show(parameters: asSideMenu, games)?.hideCompletion = hideCompletion
    }
    
    func didHide() {
        hideCompletion?()
    }
}
