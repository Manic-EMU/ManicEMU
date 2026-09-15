//
//  HomeViewController.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/25.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import SideMenu
import DNSPageView
import ColorfulX

import UniformTypeIdentifiers
import BlurUIKit
import KeyboardKit

class HomeViewController: BaseViewController {
    private lazy var gamesViewController: GamesViewController = {
        let controller = GamesViewController()
        controller.setHomeTabBar = { [weak self] show in
            UIView.springAnimate(enable: show) { 
                self?.homeTabBar.alpha = show ? 1 : 0
                self?.homeTabBarBlurView.isHidden = !show
            }
        }
        return controller
    }()
    
    private var importViewController: ImportViewController = {
        let controller = ImportViewController()
        return controller
    }()
    
    private var settingsViewController: SettingsViewController = {
        let controller = SettingsViewController()
        return controller
    }()
    
    private lazy var childControllers: [BaseViewController] = {
        if Locale.isRTLLanguage {
            [settingsViewController, importViewController, gamesViewController]
        } else {
            [gamesViewController, importViewController, settingsViewController]
        }
        
    }()
    
    private lazy var pageViewManager: PageViewManager = {
        let style = PageStyle()
        style.contentViewBackgroundColor = UIDevice.isPad ? UIColor(.dm, light: .white, dark: .black) : Constants.Color.Background
        let manager = PageViewManager(style: style, titles: HomeTabBar.BarSelection.allCases.map { String($0.rawValue) }, childViewControllers: childControllers)
        manager.contentView.getContentEdgeInsets = {
            if UIDevice.isPhone, UIDevice.isLandscape {
                return .init(top: 0, left: Constants.Size.SafeAera.left, bottom: 0, right: Constants.Size.SafeAera.right)
            } else {
                return .zero
            }
        }
        childControllers.forEach {
            addChild($0)
            $0.didMove(toParent: self)
        }
        return manager
    }()
    
    lazy var homeTabBar: HomeTabBar = {
        let view = HomeTabBar()
        view.selectionChange = { [weak self] selection in
            var selection = selection
            if Locale.isRTLLanguage {
                if selection == .games {
                    selection = .settings
                } else if selection == .settings {
                    selection = .games
                }
            }
            self?.pageViewManager.setCurrentPage(selection.rawValue)
            switch selection {
            case .games:
                Log.debug("切换到游戏")
                if UIDevice.isPhone, UIDevice.isLandscape {
                    self?.gamesViewController.view.masksToBounds = false
                }
                self?.gamesViewController.becomeFirstResponder()
            case .imports:
                Log.debug("切换到导入")
                if UIDevice.isPhone, UIDevice.isLandscape {
                    self?.gamesViewController.view.masksToBounds = true
                }
                self?.importViewController.becomeFirstResponder()
            case .settings:
                Log.debug("切换到设置")
                self?.settingsViewController.becomeFirstResponder()
            }
        }
        return view
    }()
    
    private var homeTabBarBlurView: UIView = {
        let view = BlurUIKit.VariableBlurView()
        view.direction = .up
        view.maximumBlurRadius = 1
        view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.05, darkModeAlpha: 0.05)
        view.dimmingTintColor = Constants.Color.Background
        return view
    }()
    
    private var homeSelectionChangeNotification: Any? = nil
    
    private var currentChildViewController: BaseViewController {
        switch homeTabBar.currentSelection {
        case .games:
            return gamesViewController
        case .imports:
            return importViewController
        case .settings:
            return settingsViewController
        }
    }
    
    deinit {
        if let homeSelectionChangeNotification = homeSelectionChangeNotification {
            NotificationCenter.default.removeObserver(homeSelectionChangeNotification)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(.dm, light: .white, dark: .black)
        
        self.setupViews()

        RommSyncManager.shared.syncAllOnLaunch()

        homeSelectionChangeNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.HomeSelectionChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            if let selection = notification.object as? HomeTabBar.BarSelection {
                if self.presentedViewController == nil {
                    if self.homeTabBar.currentSelection != selection {
                        self.homeTabBar.currentSelection = selection
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.becomeFirstResponder()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.resignFirstResponder()
    }
    
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        super.present(viewControllerToPresent, animated: flag, completion: completion)
        self.resignFirstResponder()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if UIDevice.isPhone {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.pageViewManager.contentView.updateContentEdgeInsets()
            }
        }
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        currentChildViewController.becomeFirstResponder()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        currentChildViewController.resignFirstResponder()
    }
    
    private func setupViews() {
        view.addScreenEdgePanGesture(edges: .left, handler: { [weak self] gesture in
            if gesture.state == .began {
                guard let self = self else { return }
                self.childControllers[self.pageViewManager.currentIndex].handleScreenPanGesture(edges: .left)
            }
        }).delegate = self
        
        view.addScreenEdgePanGesture(edges: .right, handler: { [weak self] gesture in
            if gesture.state == .began {
                guard let self = self else { return }
                self.childControllers[self.pageViewManager.currentIndex].handleScreenPanGesture(edges: .right)
            }
        }).delegate = self
        
        view.addSubview(pageViewManager.contentView)
        pageViewManager.contentView.delegate = self
        pageViewManager.contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        if Locale.isRTLLanguage {
            DispatchQueue.main.asyncAfter(delay: 0.35) { [weak self] in
                self?.pageViewManager.setCurrentPage(HomeTabBar.BarSelection.settings.rawValue)
            }
        }
        
        view.addSubview(homeTabBarBlurView)
        view.addSubview(homeTabBar)
        homeTabBarBlurView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(homeTabBar).offset(-20)
        }
        
        homeTabBar.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.HomeTabBarSize)
            make.centerX.equalTo(self.view)
            let safeAeraBottom = Constants.Size.SafeAera.bottom
            make.bottom.equalTo(safeAeraBottom > 0 ? -safeAeraBottom: -Constants.Size.ContentSpaceMax)
        }
    }
}

extension HomeViewController: UIGestureRecognizerDelegate {
    // 让 UICollectionView 的手势在 EdgePan 失败后才识别
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIScreenEdgePanGestureRecognizer,
           let scrollView = otherGestureRecognizer.view as? UIScrollView,
           otherGestureRecognizer == scrollView.panGestureRecognizer {
            return true // 先执行 EdgePan，失败后才允许 UICollectionView 滚动
        }
        return false
    }
}

extension HomeViewController: PageContentViewDelegate {
    func contentView(_ contentView: DNSPageView.PageContentView, didEndScrollAt index: Int) {
        var index = index
        if Locale.isRTLLanguage {
            if index == HomeTabBar.BarSelection.games.rawValue {
                index = HomeTabBar.BarSelection.settings.rawValue
            } else if index == HomeTabBar.BarSelection.settings.rawValue {
                index = HomeTabBar.BarSelection.games.rawValue
            }
        }
        if let selection = HomeTabBar.BarSelection(rawValue: index) {
            homeTabBar.currentSelection = selection
        }
    }
    
    func contentView(_ contentView: DNSPageView.PageContentView, scrollingWith sourceIndex: Int, targetIndex: Int, progress: CGFloat) {
        
    }
}

extension HomeViewController: UIControllerPressable {
    override var keyCommands: [UIKeyCommand]? {
        var commands = super.keyCommands ?? []
        commands.append(UIKeyCommand(input: "1", modifierFlags: .control, action: #selector(didHomeViewKeyboardPress)))
        commands.append(UIKeyCommand(input: "2", modifierFlags: .control, action: #selector(didHomeViewKeyboardPress)))
        commands.append(UIKeyCommand(input: "3", modifierFlags: .control, action: #selector(didHomeViewKeyboardPress)))
        return commands
    }
    
    func didControllerPress(key: KeyboardKit.UIControllerKey) {
        if key == .l1 {
            homeTabBar.currentSelection = homeTabBar.currentSelection.previous()
        } else if key == .r1 {
            homeTabBar.currentSelection = homeTabBar.currentSelection.next()
        }
    }
    
    @objc func didHomeViewKeyboardPress(_ sender: UIKeyCommand) {
        if let inputString = sender.input, sender.modifierFlags == .control {
            if inputString == "1" {
                homeTabBar.currentSelection = .games
            } else if inputString == "2" {
                homeTabBar.currentSelection = .imports
            } else if inputString == "3" {
                homeTabBar.currentSelection = .settings
            }
        }
    }
    
}
