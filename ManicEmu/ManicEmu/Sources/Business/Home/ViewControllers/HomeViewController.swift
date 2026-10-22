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

class HomeViewController: BaseViewController {
    
    private let gamesViewController = GamesViewController()
    
    private let importViewController = ImportViewController()
    
    private let settingsViewController = SettingsViewController()
    
    private lazy var childControllers: [BaseViewController] = {
        if Locale.isRTLLanguage {
            [settingsViewController, importViewController, gamesViewController]
        } else {
            [gamesViewController, importViewController, settingsViewController]
        }
        
    }()
    
    private lazy var pageViewManager: PageViewManager = {
        let style = PageStyle()
        style.contentViewBackgroundColor = UIDevice.isPad ? UIColor(.dm, light: .white, dark: .black) : .clear
        let manager = PageViewManager(style: style, titles: HomeTabBar.BarSelection.allCases.map { String($0.rawValue) }, childViewControllers: childControllers)
        if UIDevice.isPhone {
            manager.contentView.backgroundColor = R.Color.BackgroundPrimary
            let backgroundMask = PageBackgroundMaskView()
            manager.contentView.insertSubview(backgroundMask, at: 0)
            backgroundMask.snp.makeConstraints { make in
                make.leading.top.trailing.equalToSuperview()
                make.height.equalTo(R.Size.PageBackgroundMaskHeight(window: hostingWindow))
            }
        }
        childControllers.forEach {
            addChild($0)
            $0.didMove(toParent: self)
        }
        return manager
    }()
    
    lazy var homeTabBar: HomeTabBar = {
        let view = HomeTabBar(orientation: UIDevice.isPhoneDuoCompactWidth ? .portrait : .landscape)
        view.selectionChange = { [weak self] selection in
            guard let self else { return }
            var selection = selection
            if Locale.isRTLLanguage {
                if selection == .games {
                    selection = .settings
                } else if selection == .settings {
                    selection = .games
                }
            }
            self.pageViewManager.setCurrentPage(selection.rawValue)
            switch selection {
            case .games:
                Log.debug("切换到游戏")
                if UIDevice.isPhone, self.view.preferredLayoutStyle == .landscape {
                    self.gamesViewController.view.masksToBounds = false
                }
                
            case .imports:
                Log.debug("切换到导入")
                if UIDevice.isPhone, self.view.preferredLayoutStyle == .landscape {
                    self.gamesViewController.view.masksToBounds = true
                }
                
            case .settings:
                Log.debug("切换到设置")
            }
            self.updateLandscapeBackgroundVisible()
            self.activateCurrentTabFocusContext()
        }
        view.isHidden = UIDevice.isPhone && !UIDevice.isPhoneDuo && self.view.preferredLayoutStyle == .landscape
        return view
    }()
    
    private lazy var homeTabBarBlurView: UIView = {
        let view = BlurUIKit.VariableBlurView()
        view.direction = .up
        view.maximumBlurRadius = 1
        view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.05, darkModeAlpha: 0.05)
        view.dimmingTintColor = R.Color.BackgroundPrimary
        view.isHidden = self.view.preferredLayoutStyle == .landscape || UIDevice.isPhoneDuoCompactWidth
        return view
    }()
    
    ///横屏动态背景 所有tab横屏时可见 层级高于BaseViewController的PageBackgroundMaskView
    private lazy var landscapeBackgroundView: LandscapeBackgroundView = {
        let view = LandscapeBackgroundView()
        view.isHidden = true
        view.pauseRendering()
        return view
    }()
    
    private var homeSelectionChangeNotification: Any? = nil
    
    private var landscapeBackgroundNotification: Any? = nil
    
    /// D-pad ran off a tab edge; the following selection change should restore focus in the new tab.
    private var shouldHandoffTabFocus = false
    
    /// Last compact-width tab bar frame. Avoids rebuilding constraints every layout pass.
    private var appliedPhoneDuoTabBarFrame: CGRect?
    
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
        if let homeSelectionChangeNotification {
            NotificationCenter.default.removeObserver(homeSelectionChangeNotification)
        }
        if let landscapeBackgroundNotification {
            NotificationCenter.default.removeObserver(landscapeBackgroundNotification)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(.dm, light: .white, dark: .black)
        
        self.setupViews()
        
        //GameListLandscapeView上报的背景变更 只有横屏可见时才实时应用 否则先记录待横屏时应用
        landscapeBackgroundNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.LandscapeBackgroundChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            if let background = notification.object as? LandscapeBackgroundView.Background {
                self.landscapeBackgroundView.setBackground(background)
            }
        }
        
        updateLandscapeBackgroundVisible()
        
        homeSelectionChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.HomeSelectionChange, object: nil, queue: .main) { [weak self] notification in
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        landscapeBackgroundView.setHomeVisible(true)
        if let coordinator = transitionCoordinator,
            let size = view.hostingWindow?.size {
            viewWillTransition(to: size, with: coordinator)
            childControllers.forEach { $0.viewWillTransition(to: size, with: coordinator) }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activateCurrentTabFocusContext()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if currentChildViewController.hasFocusContext {
            currentChildViewController.popFocusContext()
        }
        landscapeBackgroundView.setHomeVisible(false)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if UIDevice.isPhoneDuo {
            refreshPhoneDuoTabBarPlacementIfNeeded()
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        appliedPhoneDuoTabBarFrame = nil
        if UIDevice.isPhoneDuo {
            refreshPhoneDuoTabBarPlacementIfNeeded()
            homeTabBarBlurView.isHidden = self.view.preferredLayoutStyle == .landscape || UIDevice.isPhoneDuoCompactWidth
        }
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
        if !UIDevice.isIOS15 {
            NotificationCenter.default.post(name: R.NotificationName.ViewWillTransition, object: nil)
        }
        if currentChildViewController is GamesViewController {
            updateGamesFocusCommands(focusContext: currentChildViewController.focusContext)
        }
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.homeTabBarBlurView.isHidden = self.view.preferredLayoutStyle == .landscape || UIDevice.isPhoneDuoCompactWidth
            if UIDevice.isPhone {
                if let pageBackgroundMaskView = self.pageViewManager.contentView.subviews.first(where: { $0.isKind(of: PageBackgroundMaskView.self) }) {
                    pageBackgroundMaskView.snp.updateConstraints { make in
                        make.height.equalTo(R.Size.PageBackgroundMaskHeight(window: self.hostingWindow))
                    }
                }
            }
            self.updateLandscapeBackgroundVisible()
            if UIDevice.isIOS15 {
                NotificationCenter.default.post(name: R.NotificationName.ViewWillTransition, object: nil)
            }
            NotificationCenter.default.post(name: R.NotificationName.ViewAlongsideTransition, object: nil)
            self.homeTabBar.isHidden = UIDevice.isPhone && !UIDevice.isPhoneDuo && self.view.preferredLayoutStyle == .landscape
            if UIDevice.isPhoneDuo {
                self.updateHomeTabBarConstraints()
            }
        }, completion: { _ in
            NotificationCenter.default.post(name: R.NotificationName.ViewDidTransition, object: nil)
        })
    }
    
    override func handleScreenPanGesture(edges: UIRectEdge, gesture: UIScreenEdgePanGestureRecognizer) {
        childControllers[self.pageViewManager.currentIndex].handleScreenPanGesture(edges: edges, gesture: gesture)
    }
    
    private func setupViews() {
        //横屏动态背景 插在自身PageBackgroundMaskView之上 分页内容之下
        if let backgroundMaskView {
            view.insertSubview(landscapeBackgroundView, aboveSubview: backgroundMaskView)
        } else {
            view.insertSubview(landscapeBackgroundView, at: 0)
        }
        landscapeBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
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
            make.top.equalTo(homeTabBar).offset(-R.Size.ContentSpaceLarge)
        }
        
        updateHomeTabBarConstraints()
    }
    
    ///根据横竖屏更新动态背景显隐 横屏时透明化分页容器与子页面使背景透出
    private func updateLandscapeBackgroundVisible() {
        let landscape = view.preferredLayoutStyle == .landscape
        if landscape {
            if UIDevice.isPhone {
                if landscapeBackgroundView.isHidden {
                    landscapeBackgroundView.isHidden = false
                }
                
                if getSelection() == .games {
                    gamesViewController.updateLandscapeBackgroundIfNeed()
                } else if !landscapeBackgroundView.isShaderMode {
                    landscapeBackgroundView.setBackground(LandscapeBackgroundView.Background.shader(reload: false), animated: false)
                }
                
                landscapeBackgroundView.resumeRendering()
            } else if UIDevice.isPad {
                if getSelection() == .games, landscapeBackgroundView.isHidden {
                    landscapeBackgroundView.isHidden = false
                    landscapeBackgroundView.resumeRendering()
                } else if getSelection() != .games, !landscapeBackgroundView.isHidden {
                    landscapeBackgroundView.isHidden = true
                    landscapeBackgroundView.pauseRendering()
                }
            }
        } else {
            landscapeBackgroundView.isHidden = true
            landscapeBackgroundView.pauseRendering()
        }
        
        //横屏时分页容器与已加载的子页面透明化 并隐藏各自的PageBackgroundMaskView 使动态背景透出
        if UIDevice.isPad {
            pageViewManager.contentView.collectionView.backgroundColor = landscape ? .clear : UIColor(.dm, light: .white, dark: .black)
        } else {
            pageViewManager.contentView.backgroundColor = landscape ? .clear : R.Color.BackgroundPrimary
            if let pageMaskView = pageViewManager.contentView.subviews.first(where: { $0.isKind(of: PageBackgroundMaskView.self) }) {
                pageMaskView.isHidden = landscape
            }
        }
        childControllers.filter { $0.isViewLoaded }.forEach {
            if UIDevice.isPad {
                if $0 is GamesViewController {
                    $0.view.backgroundColor = landscape ? .clear : R.Color.BackgroundPrimary
                }
            } else {
                $0.view.backgroundColor = landscape ? .clear : R.Color.BackgroundPrimary
                $0.backgroundMaskView?.isHidden = landscape ? true : !$0.enableBackgroundMask
            }
        }
    }
    
    private func updateHomeTabBarConstraints() {
        if !UIDevice.isPhoneDuoCompactWidth {
            appliedPhoneDuoTabBarFrame = nil
        }
        let duoFrame = UIDevice.isPhoneDuoCompactWidth ? (appliedPhoneDuoTabBarFrame ?? phoneDuoTabBarFrame()) : nil
        homeTabBar.snp.remakeConstraints { make in
            if UIDevice.isPhoneDuoCompactWidth {
                make.size.equalTo(R.Size.HomeTabBarSizeVertical)
                if let duoFrame {
                    make.leading.equalToSuperview().offset(duoFrame.minX)
                    make.top.equalToSuperview().offset(duoFrame.minY)
                } else {
                    make.centerY.equalToSuperview()
                    make.trailing.equalToSuperview()
                }
            } else {
                make.size.equalTo(R.Size.HomeTabBarSize)
                make.centerX.equalTo(self.view)
                if self.view.safeAreaInsets.bottom == 0 && !UIDevice.isPhoneDuo {
                    make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow))
                } else if UIDevice.isPhoneDuo {
                    make.bottom.equalToSuperview().inset(R.Size.ContentSpaceLarge)
                } else {
                    make.bottom.equalTo(view.safeAreaLayoutGuide)
                }
            }
        }
        homeTabBar.orientation = UIDevice.isPhoneDuoCompactWidth ? .portrait : .landscape
    }
    
    /// Keeps the vertical tab bar centered in the side strip, shifting down only when that frame hits an occlusion.
    private func refreshPhoneDuoTabBarPlacementIfNeeded() {
        guard UIDevice.isPhoneDuoCompactWidth || UIDevice.isPhoneDuoSplitView, view.bounds.width > 1, view.bounds.height > 1 else { return }
        let frame = phoneDuoTabBarFrame()
        func framesDiffer(_ lhs: CGRect?, _ rhs: CGRect?) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil):
                return false
            case let (lhs?, rhs?):
                return abs(lhs.minX - rhs.minX) > 0.5
                    || abs(lhs.minY - rhs.minY) > 0.5
                    || abs(lhs.width - rhs.width) > 0.5
                    || abs(lhs.height - rhs.height) > 0.5
            default:
                return true
            }
        }
        guard framesDiffer(appliedPhoneDuoTabBarFrame, frame) else { return }
        appliedPhoneDuoTabBarFrame = frame
        updateHomeTabBarConstraints()
    }
    
    /// `nil` until the side strip can be measured. Centering with no occlusion is the strip helper's own default.
    private func phoneDuoTabBarFrame() -> CGRect? {
        DuoLayoutKit.sideStrip(in: view)?.frame(fitting: R.Size.HomeTabBarSizeVertical)
    }
    
    // MARK: - Tab FocusKit
    
    /// Make the selected child VC the focus root so search stays inside that tab.
    private func activateCurrentTabFocusContext() {
        let viewController = currentChildViewController
        let handoff = shouldHandoffTabFocus
        shouldHandoffTabFocus = false
        viewController.activateFocusRoot { [weak self] context in
            guard let self else { return }
            // Tab bar lives on HomeViewController; include it in this tab's page-level search.
            context.addAdditionalSearchRoot(self.homeTabBar)
            context.addCommands([
                FocusCommand(key: FocusKey("control+1"), title: R.string.localizable.tabbarTitleGames(), action: { [weak self] in
                    self?.homeTabBar.currentSelection = .games
                }),
                FocusCommand(key: FocusKey("control+2"), title: R.string.localizable.tabbarTitleImport(), action: { [weak self] in
                    self?.homeTabBar.currentSelection = .imports
                }),
                FocusCommand(key: FocusKey("control+3"), title: R.string.localizable.tabbarTitleSettings(), action: { [weak self] in
                    self?.homeTabBar.currentSelection = .settings
                }),
                FocusCommand(key: FocusKey("l2"), title: R.string.localizable.nextTap(), action: { [weak self] in
                    self?.homeTabBar.previousSelection()
                }),
                FocusCommand(key: FocusKey("r2"), title: R.string.localizable.previousTap(), action: { [weak self] in
                    self?.homeTabBar.nextSelection()
                })
            ])
            
            if self.homeTabBar.currentSelection == .games {
                let commands = [FocusCommand(key: FocusKey("l1"), title: R.string.localizable.scrollToFirstGame(), action: { [weak self] in
                    self?.gamesViewController.scrollToFirstGame()
                }),
                 FocusCommand(key: FocusKey("r1"), title: R.string.localizable.scrollToLastGame(), action: { [weak self] in
                    self?.gamesViewController.scrollToLastGame()
                })]
                self.updateGamesFocusCommands(focusContext: context)
                context.addCommands(commands)
            }
            
            context.onFocusChange = { [weak self] focusView, attemptedDirection in
                guard let self, focusView == nil, let attemptedDirection else { return }
                self.handleTabFocusExit(attemptedDirection)
            }
        }
        if handoff, FocusSystem.shared.hasExternalInput {
            let context = viewController.focusContext
            DispatchQueue.main.async {
                guard FocusSystem.shared.currentContext === context else { return }
                FocusSystem.shared.updateFocusIfNeeded()
            }
        }
    }
    
    /// Horizontal search found no target in this tab: move to the adjacent sibling tab.
    private func handleTabFocusExit(_ direction: FocusDirection) {
        guard direction.isHorizontal else { return }
        var offset = direction == .right ? 1 : -1
        if Locale.isRTLLanguage {
            offset = -offset
        }
        guard let newSelection = HomeTabBar.BarSelection(rawValue: homeTabBar.currentSelection.rawValue + offset) else {
            return
        }
        shouldHandoffTabFocus = true
        homeTabBar.currentSelection = newSelection
    }
    
    private func updateGamesFocusCommands(focusContext: FocusContext) {
        guard currentChildViewController is GamesViewController else { return }
        if view.preferredLayoutStyle == .landscape {
            focusContext.addCommand(FocusCommand(key: FocusKey("l3"), title: R.string.localizable.filterTitle(), action: {
                NotificationCenter.default.post(name: R.NotificationName.ShowFilterForLandscapeMode, object: nil)
            }))
        } else {
            focusContext.removeCommands(for: FocusKey("l3"))
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
        if let selection = getSelection(for: index) {
            homeTabBar.currentSelection = selection
        }
    }
    
    func contentView(_ contentView: DNSPageView.PageContentView, scrollingWith sourceIndex: Int, targetIndex: Int, progress: CGFloat) {
        guard UIDevice.isPad else { return }
        if let sourceSelection = getSelection(for: sourceIndex), let targetSelection = getSelection(for: targetIndex) {
            if sourceSelection == .imports,
               targetSelection == .games,
               landscapeBackgroundView.isHidden {
                landscapeBackgroundView.isHidden = false
                landscapeBackgroundView.resumeRendering()
            }
        }
    }
    
    private func getSelection(for index: Int? = nil) -> HomeTabBar.BarSelection? {
        if let index {
            var realIndex = index
            if Locale.isRTLLanguage {
                if index == HomeTabBar.BarSelection.games.rawValue {
                    realIndex = HomeTabBar.BarSelection.settings.rawValue
                } else if index == HomeTabBar.BarSelection.settings.rawValue {
                    realIndex = HomeTabBar.BarSelection.games.rawValue
                }
            }
            return HomeTabBar.BarSelection(rawValue: realIndex)
        } else {
            return homeTabBar.currentSelection
        }
    }
}
