//
//  GamesViewController.swift
//  ManicEmu
//
//  Created by Max on 2025/1/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import SideMenu
import RealmSwift

class GamesViewController: BaseViewController {
    
    private lazy var gamesNavigationView: GamesNavigationView = {
        let view = GamesNavigationView()
        view.controllerButton.didTapButton = { [weak self] in
            guard let self = self else { return }
            self.showSideMenu(leftSide: true)
        }
        
        view.historyButton.didTapButton = { [weak self] in
            guard let self = self else { return }
            self.showSideMenu(leftSide: false)
        }
        
        view.scrollToTopView.addTapGesture { [weak self] gesture in
            if UIDevice.isPhone && UIDevice.isLandscape {
                self?.gamesListView?.scrollToTop()
            }
        }
        
        return view
    }()
    ///顶部工具条 搜索 选择
    private lazy var gamesToolView: GamesToolView = {
        let view = GamesToolView()
        view.isHidden = true
        ///搜索变更
        view.didSearchChange = { [weak self] string in
            guard let self = self  else { return }
            if let s = string, !s.isEmpty {
                if !view.selectIcon.isSelected, (self.gamesListView?.collectionView.indexPathsForSelectedItems ?? []).count > 0 {
                    self.gamesListView?.collectionView.selectItem(at: nil, animated: false, scrollPosition: [])
                }
                self.gamesListView?.searchDatas(string: s)
            } else {
                self.gamesListView?.stopSearch()
            }
        }
        ///选择变更
        view.didToolViewSelectionChange = { [weak self] mode in
            guard let self = self else { return }
            self.gamesListView?.selectionMode = mode
            self.gamesToolView.foldKeyboard()
        }
        view.manufacturerCategoryView.didManufacturerChange = { [weak self] manufacturer in
            guard let self else { return false }
            if let manufacturer,
                !(self.gamesListView?.isGameExist(for: manufacturer) ?? false) {
                UIView.makeToast(message: R.string.localizable.noGamesForManufacturer())
                return false
            }
            self.gamesListView?.filteredManufacturer = manufacturer
            if let manufacturer {
                return true
            }
            return false
        }
        view.didFilterVisibleChange = { [weak self] in
            guard let self else { return }
            self.gamesToolView.snp.updateConstraints { make in
                make.height.equalTo(R.Size.GamesToolViewHeight)
            }
        }
        return view
    }()
    
    private let gamesSeperatorView = UIImageView(image: R.image.gamelist_separator())
    
    private var gamesListView: GameListView?
    private func ensureGameListView() -> GameListView {
        if let gamesListView {
            return gamesListView
        }
        let view = GameListView()
        ///选择变更
        view.didListViewSelectionChange = { [weak self] selectionType in
            guard let self = self else { return }
            UIDevice.generateHaptic()
            self.gamesToolView.updateSelectIconLabel(selectionType: selectionType)
        }
        view.needsUpdateToolViewVisible = { [weak self] show in
            guard let self = self,
                  UIDevice.isPhone,
                  !UIDevice.isLandscape,
                  self.gamesToolView.isHidden != !show else { return }
            
            self.gamesListView?.snp.updateConstraints { make in
                make.top.equalTo(self.gamesNavigationView.snp.bottom).offset(show ? R.Size.GamesToolViewHeight : 0)
            }
            UIView.springAnimate {
                self.gamesToolView.isHidden = !show
                self.view.layoutIfNeeded()
            }
        }
        view.needsUpdateToolViewSelection = { [weak self] in
            guard let self else { return }
            self.gamesToolView.selectIcon.isSelected = false
            self.gamesToolView.updateSelectIconLabel(selectionType: .selectNone)
            self.gamesToolView.didToolViewSelectionChange?(.normalMode)
        }
        view.didScroll = { [weak self] in
            guard let self = self else { return }
            self.gamesToolView.foldKeyboard()
        }
        view.didDatasUpdate = { [weak self] empty in
            guard let self = self else { return }
            if empty {
                self.gamesToolView.stopSearch()
            }
            if UIDevice.isPhone && UIDevice.isLandscape {
                self.gamesToolView.isHidden = true
            } else {
                self.gamesToolView.isHidden = empty
                DispatchQueue.main.asyncAfter(delay: 0.5) {
                    self.gamesListView?.snp.updateConstraints { make in
                        make.top.equalTo(self.gamesNavigationView.snp.bottom).offset(empty ? 0 : R.Size.GamesToolViewHeight)
                    }
                }
            }
        }
        view.needToStopManufacturerFilter = { [weak self] in
            guard let self = self else { return }
            self.gamesToolView.stopFilterManufacturer()
        }
        gamesListView = view
        return view
    }
    
    private var gameListLandscapeView: GameListLandscapeView?
    private func ensureGameListLandscapeView() -> GameListLandscapeView {
        if let gameListLandscapeView {
            return gameListLandscapeView
        }
        
        let view = GameListLandscapeView()
        gameListLandscapeView = view
        return view
    }
    
    private weak var sideMenu: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.updateViews()
        //处理Launch Link
        if let launchGameID = ApplicationSceneDelegate.launchGameID {
            ApplicationSceneDelegate.launchGameID = nil
            let realm = Database.realm
            if let game = realm.object(ofType: Game.self, forPrimaryKey: launchGameID) {
                game.handleTapAction(forceQuick: true)
            }
        } else {
            DispatchQueue.main.asyncAfter(delay: 5, execute: {
                //show changelog view
                let appVersion = R.Config.AppVersion
                let defaultKey = appVersion + "Updation"
                if !UserDefaults.standard.bool(forKey: defaultKey) {
                    let detail: String
#if SIDE_LOAD
                    detail = R.string.whatsNewSideload.whatsNewDetail()
#else
                    detail = R.string.whatsNewAppStore.whatsNewDetail()
#endif
                    ASSheetView.show(.init(style: .updation(title: R.string.localizable.whatsNew(appVersion), detail: detail)),
                                     action: { _, _ in
                        return .dismiss()
                    })
                    UserDefaults.standard.setValue(true, forKey: defaultKey)
                }
            })
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        //侧栏关闭不阻塞视图交接 否则横屏视图会先被压到竖屏宽度再卸载
        hideSideMenu()
        
        let isTargetLandscape = size.width > size.height
        if isTargetLandscape {
            //竖→横：等父容器已经是横屏尺寸后再挂上横屏视图 避免导航栏在430宽度下约束冲突
            coordinator.animate(alongsideTransition: { [weak self] _ in
                self?.updateViews(isLandscape: true)
            })
        } else {
            //横→竖：必须在旋转布局把宽度压到竖屏之前卸掉横屏视图
            removeLandscapeListIfNeeded()
            coordinator.animate(alongsideTransition: { [weak self] _ in
                //必须在alongsideTransition中进行更新，因为这个时候window size才是正确的，否则可能布局错误
                self?.updateViews(isLandscape: false)
            })
        }
    }
    
    override func handleScreenPanGesture(edges: UIRectEdge, gesture: UIScreenEdgePanGestureRecognizer) {
        if UIDevice.isPhone || (UIDevice.isPad && !UIDevice.isLandscape) {
            if edges == .left {
                showSideMenu(leftSide: true)
            } else if edges == .right {
                showSideMenu(leftSide: false)
            }
        }
    }
    
    private func showSideMenu(leftSide: Bool) {
        var leftSide = leftSide
        if Locale.isRTLLanguage {
            leftSide = !leftSide
        }
        
        let containerVC = BaseViewController()
        containerVC.enableBackgroundMask = false
        containerVC.view.backgroundColor = .clear
        if leftSide {
            let view = ControllersSettingView(asSideMenu: true)
            containerVC.view.addSubview(view)
            view.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
            view.updateTopInsets()
        } else {
            let view = PlayHistoryView(asSideMenu: true)
            view.needToHideSideMenu = { [weak self] in
                guard let self = self else { return }
                self.hideSideMenu()
            }
            view.didTapGame = { [weak self] game in
                guard let self = self else { return }
                if Settings.defalut.quickGame {
                    self.hideSideMenu(completion: {
                        game.handleTapAction(forceQuick: true)
                    })
                } else {
                    // Wait for side menu dismiss before presenting GameInfo; overlapping
                    // presentation can trigger UITextField/UIFieldEditor layout crashes.
                    self.hideSideMenu(completion: {
                        GameInfoView.show(readyAction: .default, game: game)
                    })
                }
            }
            containerVC.view.addSubview(view)
            view.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        UIDevice.generateHaptic()
        let menu = SideMenuNavigationController(rootViewController: containerVC)
        menu.navigationBar.isHidden = true
        menu.presentDuration = R.Numbers.LongAnimationDuration
        menu.dismissDuration = R.Numbers.LongAnimationDuration
        menu.leftSide = leftSide
        menu.menuWidth = R.Size.SideMenuWidth
        menu.presentationStyle = SideMenuShowStyle()
        sideMenu = menu
        topViewController()?.present(menu, animated: true)
    }
    
    private func hideSideMenu(completion: (()->Void)? = nil) {
        if let sideMenu = sideMenu {
            sideMenu.dismiss(animated: true, completion: completion)
        } else {
            completion?()
        }
    }
    
    ///按目标方向交接横竖屏列表 先挂上新视图再卸掉旧视图 避免露出底层背景
    private func updateViews(isLandscape: Bool = UIDevice.isLandscape) {
        if isLandscape {
            if gameListLandscapeView?.superview != nil { return }
            
            let landscapeListView = ensureGameListLandscapeView()
            view.addSubview(landscapeListView)
            landscapeListView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
            //仅在替换已有竖屏列表时强制布局；首次启动不要 layoutIfNeeded
            //否则 collectionView 会在最终尺寸前创建/复用 cell，异步封面回调会把缺省图盖成其他游戏封面
            if gamesListView != nil {
                view.layoutIfNeeded()
            }
            removePortraitListIfNeeded()
        } else {
            if gamesListView?.superview != nil {
                removeLandscapeListIfNeeded()
                gamesListView?.collectionView.reloadData()
                return
            }
            
            gamesNavigationView.isHidden = false
            if gamesNavigationView.superview == nil {
                view.addSubview(gamesNavigationView)
            }
            gamesNavigationView.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(R.Size.ContentInsetTop)
                make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
                make.height.equalTo(R.Size.ItemHeightMedium)
            }
            
            if Theme.defalut.enableManufacturerFilter {
                gamesToolView.stopFilterManufacturer()
            }
            gamesToolView.isHidden = false
            if gamesToolView.superview == nil {
                view.addSubview(gamesToolView)
            }
            gamesToolView.snp.remakeConstraints { make in
                make.top.equalTo(gamesNavigationView.snp.bottom)
                make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
                make.height.equalTo(R.Size.GamesToolViewHeight)
            }
            
            let portraitListView = ensureGameListView()
            let gamesToolViewIsHidden = !portraitListView.isGamesExist
            if portraitListView.superview == nil {
                view.addSubview(portraitListView)
            }
            portraitListView.snp.remakeConstraints { make in
                make.top.equalTo(gamesNavigationView.snp.bottom).offset(gamesToolViewIsHidden ? 0 : R.Size.GamesToolViewHeight)
                make.leading.bottom.trailing.equalToSuperview()
            }
            
            if gamesSeperatorView.superview == nil {
                view.addSubview(gamesSeperatorView)
            }
            gamesSeperatorView.snp.remakeConstraints { make in
                make.leading.trailing.equalTo(portraitListView)
                make.bottom.equalTo(portraitListView.snp.top).offset(5)
                make.height.equalTo(10)
            }
            if gameListLandscapeView != nil {
                view.layoutIfNeeded()
            }
            removeLandscapeListIfNeeded()
        }
    }
    
    private func removePortraitListIfNeeded() {
        gamesNavigationView.isHidden = true
        gamesToolView.isHidden = true
        gamesSeperatorView.isHidden = true
        if let gamesListView {
            gamesListView.removeFromSuperview()
            self.gamesListView = nil
        }
    }
    
    private func removeLandscapeListIfNeeded() {
        guard let gameListLandscapeView else { return }
        //先断开 dataSource，避免旋转 bounds 动画期间 CollectionViewPagingLayout
        //异步 performBatchUpdates 读到 nil dataSource 导致闪退
        gameListLandscapeView.prepareForRemoval()
        gameListLandscapeView.removeFromSuperview()
        self.gameListLandscapeView = nil
    }
    
    func updateLandscapeBackgroundIfNeed() {
        guard UIDevice.isLandscape else { return }
        gameListLandscapeView?.updateFocusedGameInfo()
    }
    
    func scrollToLastGame() {
        if UIDevice.isLandscape {
            gameListLandscapeView?.scrollToLastGame()
        } else {
            gamesListView?.scrollToLastGame()
        }
    }
    
    func scrollToFirstGame() {
        if UIDevice.isLandscape {
            gameListLandscapeView?.scrollToFirstGame()
        } else {
            gamesListView?.scrollToFirstGame()
        }
    }
}
