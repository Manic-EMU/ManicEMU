//
//  PlayViewController.swift
//  ManicEmu
//
//  Created by Max on 2025/1/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

import Schedule
import Haptica
import RealmSwift
import ProHUD
import IceCream
import StoreKit
import AVFoundation
import Kingfisher
import MetalKit

//MARK: 主类
class PlayViewController: GameViewController {
    //游戏 业务层定义 注意和core里面定义的Game区分
    private let manicGame: Game
    //默认加载的即时存档
    private var loadSaveState: GameSaveState? = nil
    //MARK: 通知定义
    private var gameControllerDidConnectNotification: Any? = nil
    private var gameControllerDidDisConnectNotification: Any? = nil
    private var keyboardDidConnectNotification: Any? = nil
    private var keyboardDidDisConnectNotification: Any? = nil
    private var sceneWillConnectNotification: Any? = nil
    private var sceneDidDisconnectNotification: Any? = nil
    private var scenewillDeactivateNotification: Any? = nil
    private var sceneDidActivateNotification: Any? = nil
    private var windowDidBecomeKeyNotification: Any? = nil
    private var membershipNotification: Any? = nil
    private var controllerMappingNotification: Any? = nil
    private var wfcConnectNotification: Any? = nil
    private var wfcDisconnectNotification: Any? = nil
    private var emulationDidQuitNotification: Any? = nil
    private var motionShakeNotification: Any? = nil
    private var achievementsNotification: Any? = nil
    private var quitGamingNotification: Any? = nil
    private var turnOffHardcoreNotification: Any? = nil
    private var turnOffAlwaysShowProgressNotification: Any? = nil
    private var mameGameFileMissingNotification: Any? = nil
    private var resetGamingNotification: Any? = nil
    
    //每分钟执行一次
    private lazy var repeatTimer: Schedule.Task = {
        if let task = TaskCenter.default.tasks(forTag: String(describing: Self.self)).first {
            return task
        } else {
            let task = Plan.every(Constants.Numbers.AutoSaveGameDuration.seconds).do(queue: .global()) { [weak self] in
                guard let self = self else { return }
                //每分钟记录一次游戏时间
                self.calculatePlayTime()
                //每分钟保存一次存档
                DispatchQueue.main.async { [weak self] in
                    guard Settings.defalut.autoSaveState, let self = self else { return }
                    if self.manicGame.isLibretroType {
                        self.saveStateForLibretro(type: .autoSaveState)
                    } else if self.manicGame.isJGenesisCore {
                        self.saveStateForJGenesis(type: .autoSaveState)
                    }
                }
            }
            TaskCenter.default.addTag(String(describing: Self.self), to: task)
            return task
        }
    }()
    //默认皮肤控制玩家1
    static var skinControllerPlayerIndex = 0 {
        didSet {
            if let currentPlayViewController = currentPlayViewController {
                currentPlayViewController.controllerView.playerIndex = skinControllerPlayerIndex
            }
        }
    }
    //游戏控制器，如果游戏在运行中则有值，没有进行游戏的时候则为nil
    static weak var currentPlayViewController: PlayViewController? = nil
    //屏幕上的功能按钮容器
    private var functionButtonContainer = FunctionButtonContainerView()
    //渲染视图
    private var gameMetalView: UIView? = nil
    //3DS核心
    private var citraCore: ThreeDSEmulatorBridge? = nil
    //JGenesis核心
    private var jGenesisCore: JGenesisView? {
        if manicGame.isJGenesisCore {
            return gameMetalView as? JGenesisView
        }
        return nil
    }
    //J2ME核心
    private var j2meCore: J2MEView? {
        if manicGame.isJ2MECore {
            return gameMetalView as? J2MEView
        }
        return nil
    }
    //监听静音键变化
    private lazy var muteSwitchMonitor = DLTAMuteSwitchMonitor()
    //kvo监听
    private var kvoContext = 0
    //排行榜控件
    private var leaderboardView: LeaderboardView? = nil
    //进度控件
    private var cheevosProgressView: CheevosProgressView? = nil
    //挑战控件
    private var cheevosChallengeView: CheevosChallengeView? = nil
    //游戏过程中接收到的leaderboard
    private var leaderboards: [CheevosLeaderboard] = []
    //解锁进展中的成就
    private var progressAchievements: [CheevosAchievement] = []
    //挑战中的成就
    private var challengeAchievements: [CheevosAchievement] = []
    ///TriggerProView
    private var triggerProView: TriggerProView?
    ///背景图片
    private var backgroundImageView: UIImageView? = nil
    private var background: FlexBackground? = nil
    private var backgroundType: FlexBackground.BackgroundType? = nil
    ///flex皮肤的menu和flex按钮
    private weak var flexMenuButton: UIView? = nil
    private weak var flexButton: UIView? = nil
    ///PscxReArmed init device
    private var pscxReArmedDeviceType = Constants.Strings.PSXController
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
        if let gameControllerDidConnectNotification {
            NotificationCenter.default.removeObserver(gameControllerDidConnectNotification)
        }
        if let gameControllerDidDisConnectNotification {
            NotificationCenter.default.removeObserver(gameControllerDidDisConnectNotification)
        }
        if let keyboardDidConnectNotification {
            NotificationCenter.default.removeObserver(keyboardDidConnectNotification)
        }
        if let keyboardDidDisConnectNotification {
            NotificationCenter.default.removeObserver(keyboardDidDisConnectNotification)
        }
        if let sceneWillConnectNotification {
            NotificationCenter.default.removeObserver(sceneWillConnectNotification)
        }
        if let sceneDidDisconnectNotification {
            NotificationCenter.default.removeObserver(sceneDidDisconnectNotification)
        }
        if let scenewillDeactivateNotification {
            NotificationCenter.default.removeObserver(scenewillDeactivateNotification)
        }
        if let sceneDidActivateNotification {
            NotificationCenter.default.removeObserver(sceneDidActivateNotification)
        }
        if let windowDidBecomeKeyNotification {
            NotificationCenter.default.removeObserver(windowDidBecomeKeyNotification)
        }
        if let membershipNotification {
            NotificationCenter.default.removeObserver(membershipNotification)
        }
        if let controllerMappingNotification {
            NotificationCenter.default.removeObserver(controllerMappingNotification)
        }
        if let wfcConnectNotification {
            NotificationCenter.default.removeObserver(wfcConnectNotification)
        }
        if let wfcDisconnectNotification {
            NotificationCenter.default.removeObserver(wfcDisconnectNotification)
        }
        if let emulationDidQuitNotification {
            NotificationCenter.default.removeObserver(emulationDidQuitNotification)
        }
        if let motionShakeNotification {
            NotificationCenter.default.removeObserver(motionShakeNotification)
        }
        if let achievementsNotification {
            NotificationCenter.default.removeObserver(achievementsNotification)
        }
        if let quitGamingNotification {
            NotificationCenter.default.removeObserver(quitGamingNotification)
        }
        if let turnOffHardcoreNotification {
            NotificationCenter.default.removeObserver(turnOffHardcoreNotification)
        }
        if let turnOffAlwaysShowProgressNotification {
            NotificationCenter.default.removeObserver(turnOffAlwaysShowProgressNotification)
        }
        if let mameGameFileMissingNotification {
            NotificationCenter.default.removeObserver(mameGameFileMissingNotification)
        }
        if SyncManager.shared.hasDownloadTask {
            UIView.makeLoadingToast(message: R.string.localizable.loadingTitle())
        }
        if let resetGamingNotification {
            NotificationCenter.default.removeObserver(resetGamingNotification)
        }
    }
    
    //数据库变化通知
    private var gameUpdateToken: Any? = nil
    private var cheatCodeUpdateToken: Any? = nil
    private var settingsUpdateToken: Any? = nil
    private var triggerProUpdateToken: Any? = nil
    
    private var lastSaveDate: Date? = nil
    private var lastLoadDate: Date? = nil
    
    private var isFullScreen = false
    
    private var lastPSPCheatCode: String = ""
    ///WFC是否处于连接
    private var isWFCConnect = false
    ///是否处于硬核模式
    private var isHardcoreMode = false
    ///是否是首次设置GB的调色盘
    private var isFirstTimeSetGBPalette = true;
    
    private var aiplayScaledDimensions: CGSize = .zero
    
    //皮肤中的Switch绑定数据
    private var skinSwitchBindDatas = [String: Bool]()
    
    static func startGame(game: Game, saveState: GameSaveState? = nil) {
        if game.gameType == .ns {
            EmulatorInteractionKit.startGame(type: .meloNX, id: game.id)
            return
        } else if game.gameType == .xbox360 {
            EmulatorInteractionKit.startGame(type: .xeniOS, id: game.id)
            return
        }
        if game.isRomExtsts || game.isNDSHomeMenuGame || game.isDOSHomeMenuGame {
            UIView.hideLoadingToast(forceHide: true)
            func showPlayView() {
                if game.isBIOSMissing() {
                    //检查是否缺失BIOS
                    topViewController(appController: true)?.present(BIOSSelectionViewController(gameType: game.gameType), animated: true)
                    return
                }
                if game.gameType == .unknown {
                    PlatformSelectionView.show(game: game)
                    return
                }
                func launchGameByDismissOtherVC() {
                    //游戏控制器和rootVC之间存在控制器则会导致游戏卡顿异常 估计是iOS的bug，导致了Main Run Loop调度异常
                    if game.isLibretroType {
                        LibretroCore.sharedInstance().workspace = Constants.Path.Libretro
                    }
                    if let homeVC = topViewController(appController: true),
                        (homeVC is HomeViewController || homeVC is PretendoNetworkingViewController) {
                        topViewController(appController: true)?.present(PlayViewController(game: game, saveState: saveState), animated: true)
                    } else if let homeVC = ApplicationSceneDelegate.applicationWindow?.rootViewController as? HomeViewController {
                        if let vc = homeVC.presentedViewController {
                            vc.dismiss(animated: true) {
                                topViewController(appController: true)?.present(PlayViewController(game: game, saveState: saveState), animated: true)
                            }
                        } else {
                            topViewController(appController: true)?.present(PlayViewController(game: game, saveState: saveState), animated: true)
                        }
                    } else {
                        topViewController(appController: true)?.present(PlayViewController(game: game, saveState: saveState), animated: true)
                    }
                }
                if game.gameType == ._3ds, !UIDevice.current.hasA11ProcessorOrBetter, !UserDefaults.standard.bool(forKey: Constants.DefaultKey.HasShow3DSNotSupportAlert) {
                    UIView.makeAlert(title: R.string.localizable.threeDSNoSupportDeviceTitle(), detail: R.string.localizable.threeDSNoSupportDeviceDetail(), confirmTitle: R.string.localizable.gameSaveContinue(), confirmAction: {
                        UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShow3DSNotSupportAlert)
                        launchGameByDismissOtherVC()
                    })
                }  else if game.gameType == .ps1, !UserDefaults.standard.bool(forKey: Constants.DefaultKey.HasShowPS1PlayAlert) {
                    UIView.makeAlert(title: R.string.localizable.psxRunAlert(),
                                     detail: R.string.localizable.sbiImportDesc(),
                                     detailAlignment: .left,
                                     cancelTitle: R.string.localizable.confirmTitle(), hideAction: {
                        UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShowPS1PlayAlert)
                        launchGameByDismissOtherVC()
                    });
                } else if game.gameType == ._3ds, game.identifierFor3DS == Constants.Numbers.PKSMIdentifier {
                    if Settings.defalut.getExtraBool(key: ExtraKey.globalAchievements.rawValue) ?? false {
                        UIView.makeAlert(title: R.string.localizable.retroAchievements(), detail: R.string.localizable.forbitPKSM(), cancelTitle: R.string.localizable.confirmTitle())
                    } else {
                        launchGameByDismissOtherVC()
                    }
                } else if game.isJGenesisCore, game.gameType == .mcd, game.fileExtension.lowercased() != "chd" {
                    UIView.makeToast(message: R.string.localizable.jGenesisAlert())
                } else {
                    launchGameByDismissOtherVC()
                }
            }
            if game.gameType == .ss, !UserDefaults.standard.bool(forKey: Constants.DefaultKey.HasShowSSPlayAlert), game.isBIOSMissing(required: false), game.defaultCore == 1 {
                UIView.makeAlert(title: R.string.localizable.saturnBiosAlertTitle(),
                                 detail: R.string.localizable.saturnBiosAlertDetail(),
                                 detailAlignment: .left,
                                 cancelTitle: R.string.localizable.startGameWithoutBiosTitle(),
                                 confirmTitle: R.string.localizable.biosAddTitle(), cancelAction: {
                    UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShowSSPlayAlert)
                    showPlayView()
                }, confirmAction: {
                    UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShowSSPlayAlert)
                    topViewController(appController: true)?.present(BIOSSelectionViewController(gameType: .ss), animated: true)
                }, hideAction: {
                    UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShowSSPlayAlert)
                });
            } else if game.gameType == .j2me, game.defaultCore == 1, !UserDefaults.standard.bool(forKey: Constants.DefaultKey.HasShowFreeJ2meAlert) {
                UIView.makeAlert(title: R.string.localizable.headsUp(),
                                 detail: R.string.localizable.freej2meAlert(),
                                 detailAlignment: .left,
                                 cancelTitle: R.string.localizable.confirmTitle(),
                                 cancelAction: {
                    UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShowFreeJ2meAlert)
                    showPlayView()
                });
            } else {
                showPlayView()
            }
        } else {
            UIView.makeLoading()
            SyncManager.isiCloudFileExist(localFilePath: game.romUrl.path) { fileExists in
                UIView.hideLoading()
                if fileExists {
                    //rom存在iCloud上
                    //rom还没离线下来
                    UIView.makeLoadingToast(message: R.string.localizable.loadingTitle())
                    SyncManager.download(to: game.romUrl.path) { error in
                        UIView.hideLoadingToast()
                        UIView.makeToast(message: R.string.localizable.loadRomSuccess(game.aliasName ?? game.name))
                    }
                } else {
                    UIView.makeToast(message: R.string.localizable.loadGameErrorRomNotExist())
                }
            }
        }
    }
    
    //MARK: 生命周期
    private init(game: Game, saveState: GameSaveState? = nil) {
        manicGame = game
        super.init()
        Log.debug("\(String(describing: Self.self)) init")
        loadSaveState = saveState
        modalPresentationStyle = .fullScreen
        delegate = self
        self.game = DeltaCore.Game(fileURL: game.romUrl, type: game.gameType)
        
        //MARK: 通知监听
        ///管理控制外设的连接
        gameControllerDidConnectNotification = NotificationCenter.default.addObserver(forName: .externalGameControllerDidConnect, object: nil, queue: .main) { [weak self] notification in
            //手柄连接
            self?.updateExternalGameController()
            self?.updateSkin()
        }
        gameControllerDidDisConnectNotification = NotificationCenter.default.addObserver(forName: .externalGameControllerDidDisconnect, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            //手柄断开连接
            if ExternalGameControllerManager.shared.connectedControllers.count == 0 {
                self.manicGame.forceFullSkin = false
                self.updateSkin()
                self.updateNDSCursor()
            }
        }
        keyboardDidConnectNotification = NotificationCenter.default.addObserver(forName: .externalKeyboardDidConnect, object: nil, queue: .main) { [weak self] notification in
            //键盘连接
            self?.updateExternalGameController()
            self?.updateSkin()
        }
        keyboardDidDisConnectNotification = NotificationCenter.default.addObserver(forName: .externalKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] notification in
            //键盘断开连接
            if ExternalGameControllerManager.shared.connectedControllers.count == 0 {
                self?.manicGame.forceFullSkin = false
                self?.updateSkin()
            }
        }
        ///投屏监听
        sceneWillConnectNotification = NotificationCenter.default.addObserver(forName: UIScene.willConnectNotification, object: nil, queue: .main) { [weak self] notification in
            //投屏开始
            self?.updateAirPlay()
        }
        sceneDidDisconnectNotification = NotificationCenter.default.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { [weak self] notification in
            //投屏结束
            self?.updateAirPlay()
        }
        
        scenewillDeactivateNotification = NotificationCenter.default.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: .main) { [weak self] notification in
            //进入后台
            guard let self = self else { return }
            self.pauseEmulationIfNeed()
        }
        
        sceneDidActivateNotification = NotificationCenter.default.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] notification in
            //从后台回到前台
            self?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            guard let self = self else { return }
            if self.gameViewControllerShouldResume(self) {
                self.resumeEmulationAndHandleAudio()
            }
        }
        
        //keywindow变化
        windowDidBecomeKeyNotification = NotificationCenter.default.addObserver(forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] notification in
            self?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        }
        
        //购买会员成功
        membershipNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.MembershipChange, object: nil, queue: .main) { [weak self] notification in
            if PurchaseManager.isMember {
                UIView.hideAllAlert { [weak self] in
                    if ExternalSceneDelegate.isAirPlaying {
                        if Settings.defalut.airPlay {
                            self?.updateAirPlay()
                        } else {
                            //如果在AirPlay 并且还没有设置开启AirPlay 则询问是否开启全屏
                            UIView.makeAlert(detail: R.string.localizable.turnOnAirPlayAsk(), confirmTitle: R.string.localizable.confirmTitle(), confirmAction: { [weak self] in
                                Settings.change { realm in
                                    Settings.defalut.airPlay = true
                                }
                                self?.updateAirPlay()
                            }, hideAction: { [weak self] in
                                self?.resumeEmulationAndHandleAudio()
                            })
                        }
                    } else {
                        self?.resumeEmulationAndHandleAudio()
                    }
                }
            }
        }
        
        //监听控制器映射变化
        controllerMappingNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.ControllerMapping, object: nil, queue: .main) { [weak self] notification in
            self?.updateExternalGameController()
        }
        
        //监听WFC连接
        wfcConnectNotification = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "DidConnectToWFCNotification"), object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            //            //在线游戏 禁用加速 禁用金手指
            UIView.makeToast(message: R.string.localizable.wfcConnectDesc())
            self.isWFCConnect = true
            self.updateFastforward(speed: .one)
        }
        
        //监听WFC断开连接
        wfcDisconnectNotification = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "DidDisconnectFromWFCNotification"), object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            UIView.makeToast(message: R.string.localizable.wfcDisconnectDesc())
            self.isWFCConnect = false
            self.updateFastforward(speed: self.manicGame.speed)
        }
        
        //核心请求退出
        emulationDidQuitNotification = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "LibretroDidShutdownNotification"), object: nil, queue: .main) { [weak self] notification in
            self?.dismiss(animated: true)
        }
        
        //设备晃动通知
        motionShakeNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.MotionShake, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            if self.manicGame.gameType == .pm {
                LibretroCore.sharedInstance().press(.L1, playerIndex: 0)
                DispatchQueue.main.asyncAfter(delay: 0.1) {
                    LibretroCore.sharedInstance().release(.L1, playerIndex: 0)
                }
            }
        }
        
        //RetroAchievements通知
        achievementsNotification = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "RetroAchievementsNotification"), object: nil, queue: .main, using: { [weak self] notification in
            guard let self else { return }
            if let achievement = notification.object as? CheevosAchievement {
                if achievement.isProgressAchievement {
                    //成就进度更新
                    if let progressView = self.cheevosProgressView {
                        if achievement.show {
                            progressView.updateProgress(achievement)
                            if let measuredProgress = achievement.measuredProgress {
                                //缓存进度
                                let achievementProgress = AchievementProgress(id: achievement._id, measuredProgress: measuredProgress, measuredPercent: achievement.measuredPercent)
                                self.manicGame.updateAchievementProgress(achievementProgress)
                            }
                            //如果隐藏通知没有过来 则需自动隐藏进度
                            DispatchQueue.main.asyncAfter(delay: 3.5) { [weak self] in
                                self?.hideAchievementProgressIfNeed()
                            }
                            
                            //临时存储进度 用于popup展示
                            if let cacheAchievement = self.progressAchievements.first(where: { $0._id == achievement._id }) {
                                cacheAchievement.measuredProgress = achievement.measuredProgress
                                cacheAchievement.measuredPercent = achievement.measuredPercent
                            } else {
                                self.progressAchievements.append(achievement)
                            }
                            if let challenge = self.challengeAchievements.first(where: { $0._id == achievement._id }) {
                                challenge.measuredProgress = achievement.measuredProgress
                                challenge.measuredPercent = achievement.measuredPercent
                            }
                            
                        } else {
                            self.hideAchievementProgressIfNeed(forceHide: true)
                        }
                    }
                } else if achievement.isChallengeAchievement {
                    //挑战相关
                    if let challengeView = self.cheevosChallengeView {
                        if achievement.show {
                            challengeView.updateChallenge(achievement)
                            //临时存储进度 用于popup展示
                            if !self.challengeAchievements.contains(where: { $0._id == achievement._id }) {
                                self.challengeAchievements.append(achievement)
                            }
                            
                            self.showRetroAchievements(badgeUrl: achievement.unlockedBadgeUrl,
                                                       title: R.string.localizable.achievementsChallenge(),
                                                       message: achievement._description,
                                                       hideIcon: true)
                            
                        } else {
                            challengeView.removeChallenge(id: achievement._id)
                            self.challengeAchievements.removeAll(where: { $0._id == achievement._id } )
                        }
                    }
                } else {
                    //获得成就
                    self.showRetroAchievements(badgeUrl: achievement.unlockedBadgeUrl,
                                               title: R.string.localizable.achievementUnlocked(),
                                               message: achievement.title) { [weak self] in
                        guard let self else { return }
                        //尝试读取缓存中的解锁进度
                        if achievement.measuredProgress == nil,
                           let achievementProgress = self.manicGame.getAchievementProgress(id: achievement._id) {
                            achievement.measuredPercent = achievementProgress.measuredPercent
                            achievement.measuredProgress = achievementProgress.measuredProgress
                        }
                        topViewController(appController: true)?.present(RetroAchievementsDetailViewController(achievement: achievement), animated: true)
                        self.pauseEmulationIfNeed()
                    }
                    UIDevice.generateAchievementHaptic()
                    //删除缓存的解锁进度
                    self.manicGame.removeAchievementProgress(id: achievement._id)
                    //删除解锁进度
                    self.cheevosProgressView?.removeProgress(id: achievement._id)
                    self.progressAchievements.removeAll(where: { $0._id == achievement._id })
                }
                
            } else if let summary = notification.object as? CheevosSummary {
                //启动RetroAchievements
                self.showRetroAchievements(badgeUrl: summary.badgeUrl,
                                           title: summary.title ?? R.string.localizable.achievementsGo() + " (\(self.isHardcoreMode ? R.string.localizable.hardcore() : R.string.localizable.softcore()))",
                                           message: R.string.localizable.achievementsSummary(summary.unlockedAchievementsNum, summary.coreAchievementsNum),
                                           hideIcon: true);
            } else if let _ = notification.object as? CheevosCompletion {
                //解锁完成
                var message: String = ""
                if let user = AchievementsUser.getUser() {
                    message = user.username + " | "
                }
                message = R.string.localizable.gameSortPlayTime() + Date.timeDuration(milliseconds: Int(self.manicGame.totalPlayDuration))
                self.showRetroAchievements(title: self.isHardcoreMode ?  R.string.localizable.achievementsMastered(self.manicGame.aliasName ?? self.manicGame.name) : R.string.localizable.achievementsCompleted(),
                                           message: message);
                CheersView.makeNormalCheers()
                UIDevice.generateAchievementHaptic()
                
            } else if let leaderboardTracker = notification.object as? CheevosLeaderboardTracker {
                //排行榜追踪
                if let leaderboardView = self.leaderboardView {
                    if leaderboardTracker.show, let content = leaderboardTracker.display {
                        leaderboardView.updateLeaderboard(id: leaderboardTracker._id, content: content)
                    } else {
                        leaderboardView.removeLeaderboard(id: leaderboardTracker._id)
                    }
                }
            } else if let leaderboard = notification.object as? CheevosLeaderboard {
                //排行榜提示
                if let title = leaderboard.title, let description = leaderboard._description {
                    self.showRetroAchievements(title: R.string.localizable.leaderboardStart() + title, message: description, hideIcon: true);
                }
                if let coverUrl = manicGame.onlineCoverUrl, manicGame.gameCover == nil {
                    leaderboard.badgeUrl = coverUrl
                } else if let data = manicGame.gameCover?.storedData() {
                    leaderboard.image = UIImage.tryDataImageOrPlaceholder(tryData: data, preferenceSize: .init(40))
                }
                self.leaderboards.append(leaderboard)
                
            } else if let message = notification.object as? String {
                UIView.makeToast(message: message)
            }
        })
        
        //退出游戏
        quitGamingNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.QuitGaming, object: nil, queue: .main, using: { [weak self] notification in
            guard let self else { return }
            UIView.hideAllAlert()
            self.handleMenuGameSetting(GameSetting(type: .quit), nil)
        })
        
        //关闭硬核模式
        turnOffHardcoreNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.TurnOffHardcore, object: nil, queue: .main, using: { [weak self] notification in
            guard let self else { return }
            self.isHardcoreMode = false
            LibretroCore.sharedInstance().updateLibretroConfig("cheevos_hardcore_mode_enable", value: "false")
            LibretroCore.sharedInstance().turnOffHardcode()
            if self.manicGame.gameType == .psp {
                LibretroCore.sharedInstance().updateRunningCoreConfigs(["ppsspp_cheats": "enabled"], flush: false)
            }
        })
        
        //关闭进度常驻
        turnOffAlwaysShowProgressNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.TurnOffAlwaysShowProgress, object: nil, queue: .main, using: { [weak self] notification in
            guard let self else { return }
            self.hideAchievementProgressIfNeed()
        })
        
        //MAME游戏文件缺失
        mameGameFileMissingNotification = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "MAMEGameFileMissingNotification"), object: nil, queue: .main) { notification in
            var extraInfo = ""
            if let log = notification.object as? String {
                var result = Set<String>()
                // Regex: Capture the last YYY in "tried in XXX YYY"
                let pattern = #"tried in\s+\S+\s+([^\s\)]+)"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    log.enumerateLines { line, _ in
                        let range = NSRange(line.startIndex..., in: line)
                        if let match = regex.firstMatch(in: line, range: range),
                           let yyyRange = Range(match.range(at: 1), in: line) {
                            result.insert(String(line[yyyRange]))
                        }
                    }
                }
                if result.count > 0 {
                    extraInfo = result.reduce("", { $0 + ($0.isEmpty ? "" : " ") + $1 + ".zip"}) + "\n\n"
                }
                extraInfo += (log + "\n")
            }
            
            UIView.makeAlert(title: R.string.localizable.mameFileMissingTitle(), detail: extraInfo + R.string.localizable.mameFileMissingDesc(), cancelTitle: R.string.localizable.confirmTitle())
        }
        
        //重置游戏通知
        quitGamingNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.ResetImmediately, object: nil, queue: .main, using: { [weak self] notification in
            guard let self else { return }
            UIView.hideAllAlert()
            self.handleMenuGameSetting(GameSetting(type: .reload), nil)
        })
        
        //更新最新游戏时间
        updateLatestPlayDate()
        
        //开始计时器
        repeatTimer.resume()
        
        //监听作弊码变化
        cheatCodeUpdateToken = manicGame.gameCheats.observe { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .update(_ , let deletions, let insertions, let modifications):
                if !deletions.isEmpty || !insertions.isEmpty || !modifications.isEmpty {
                    self.updateCheatCodes()
                }
            default:
                break
            }
        }
        
        //监听游戏变化
        gameUpdateToken = manicGame.observe(keyPaths: [\Game.portraitSkin, \Game.landscapeSkin, \Game.filterName, \Game.orientation, \Game.haptic, \Game.volume]) { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .change(_, let properties):
                Log.debug("游戏运行中，游戏更新")
                for property in properties {
                    if property.name == "filterName" {
                        //滤镜更新了
                        self.updateFilter()
                    } else if property.name == "portraitSkin" || property.name == "landscapeSkin" {
                        //暂停所有游戏画面
                        self.gameViews.forEach { gameView in
                            gameView.isEnabled = false
                        }
                        //皮肤更新
                        self.updateSkin()
                    } else if property.name == "orientation" {
                        //更新屏幕方向
                        self.startOrientation()
                    } else if property.name == "haptic" {
                        //修改震感
                        self.updateHaptic()
                    }
                    //如果快捷功能的图标会变化 也需要更新
                    if property.name == "volume" ||  property.name == "haptic" {
                        let settings = Settings.defalut
                        if let controllerSkin = controllerView.controllerSkin,
                           let skin = Database.realm.objects(Skin.self).first(where: { $0.identifier == controllerSkin.identifier }),
                           skin.skinType == .default,
                           settings.displayGamesFunctionCount > 0 {
                            if property.name == "volume", settings.gameFunctionList.prefix(settings.displayGamesFunctionCount).contains(where: { $0 == GameSetting.ItemType.volume.rawValue }) {
                                self.updateFunctionButton()
                            } else if property.name == "haptic", settings.gameFunctionList.prefix(settings.displayGamesFunctionCount).contains(where: { $0 == GameSetting.ItemType.haptic.rawValue }) {
                                self.updateFunctionButton()
                            }
                        }
                    }
                    
                    Log.debug("设置更新 Property '\(property.name)' changed from \(property.oldValue == nil ? "nil" : property.oldValue!) to '\(property.newValue!)'")
                }
            default:
                break
            }
        }
        
        //监听设置变化
        settingsUpdateToken = Settings.defalut.observe(keyPaths: [\Settings.gameFunctionList, \Settings.displayGamesFunctionCount]) { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .change(_, _):
                self.updateFunctionButton()
            default:
                break
            }
        }
    }
    
    @MainActor required init() {
        fatalError("init() has not been implemented")
    }
    
    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        PlayViewController.currentPlayViewController = self
        
        //发送开始游戏通知
        NotificationCenter.default.post(name: Constants.NotificationName.StartPlayGame, object: nil)
        
        //添加功能按钮容器按钮
        functionButtonContainer.isHidden = true
        view.addSubview(functionButtonContainer)
        functionButtonContainer.snp.makeConstraints { make in
            if manicGame.gameType == .n64 && UIDevice.isPad {
                make.top.equalTo(gameView.snp.bottom).offset(-9)
            } else if manicGame.gameType == .j2me {
                make.top.equalTo(gameView.snp.bottom).offset(2)
            } else if manicGame.gameType == .dos || manicGame.gameType == .doom {
                if UIDevice.isPad {
                    make.top.equalTo(gameView.snp.bottom).offset(UIDevice.isLandscape ? 30 : 40)
                } else if UIDevice.isSmallScreenPhone {
                    make.top.equalTo(gameView.snp.bottom).offset(17)
                } else if UIDevice.isProMaxPhone {
                    make.top.equalTo(gameView.snp.bottom).offset(22)
                } else {
                    make.top.equalTo(gameView.snp.bottom).offset(19)
                }
            } else {
                make.top.equalTo(gameView.snp.bottom)
            }
            if manicGame.gameType == .pm && !UIDevice.isLandscape {
                make.leading.trailing.equalTo(gameView).inset(50)
            } else {
                make.leading.trailing.equalTo(gameView)
            }
            if manicGame.gameType == .j2me || manicGame.gameType == .dos || manicGame.gameType == .doom {
                make.height.equalTo(30)
            } else {
                make.height.equalTo(Constants.Size.ItemHeightMid)
            }
            
        }
        //设置外设控制器
        updateExternalGameController()
        //如果需要加载默认配置
        LibretroCore.sharedInstance().forbitJIT = manicGame.safeMode
        if manicGame.safeMode {
            loadMinimalConfig()
        } else {
            loadConfig()
        }
        //更新皮肤
        updateSkin()
        //更新TriggerPro
        if !manicGame.safeMode {
            updateTriggerPro()
        }
        //全屏模式的时候点击屏幕临时展示menu和flex按钮
        view.addTapGesture(handler: { [weak self] _ in
            guard let self, self.isFullScreen else { return }
            self.showFlexButtonsTemporarily()
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        setOrientationConfig()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //更新皮肤
        updateSkin()
        //更新声音
        updateAudio()
        functionButtonContainer.isHidden = false
        //游戏启动稳定后禁用安全模式
        if manicGame.safeMode {
            DispatchQueue.main.asyncAfter(delay: 5, execute: { [weak self] in
                self?.manicGame.safeMode = false
            })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resetOrientationConfig()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        repeatTimer.suspend()
        //清理AirPlay画面
        if let airPlayViewController = ExternalSceneDelegate.airPlayViewController, let airPlayGameView = airPlayViewController.libretroView {
            if manicGame.isLibretroType || manicGame.isJGenesisCore || manicGame.isJ2MECore {
                airPlayGameView.parentViewController?.removeFromParent()
                airPlayGameView.removeFromSuperview()
                airPlayViewController.libretroView = nil
            }
        }
        
#if !SIDE_LOAD
        if manicGame.totalPlayDuration > 30 * 60 * 1000 { //玩超过30分钟 尝试弹起评价
            if let scene = ApplicationSceneDelegate.applicationScene {
                if let showDate = UserDefaults.standard.date(forKey: Constants.DefaultKey.ShowRequestReviewDate), showDate.isInToday {
                    
                } else {
                    SKStoreReviewController.requestReview(in: scene)
                    UserDefaults.standard.set(Date(), forKey: Constants.DefaultKey.ShowRequestReviewDate)
                }
            }
        }
#endif
        
        if manicGame.isCitra3DS {
            citraCore?.destory()
        }
        
        PlayViewController.currentPlayViewController = nil
        
        //发送结束游戏通知
        NotificationCenter.default.post(name: Constants.NotificationName.StopPlayGame, object: nil)

        //We Sync saves when a user closes a game
        RommSyncManager.shared.syncOnClose(game: manicGame)

        //取消静音监听
        muteSwitchMonitor.stopMonitoring()
        
        //通知游戏列表更新
        if let gameSortType = GameSortType(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.gameSortType.rawValue) ?? 0),
           (gameSortType == .latestPlayed || gameSortType == .playTime) {
            NotificationCenter.default.post(name: Constants.NotificationName.GameSortChange, object: nil)
        }
        //Libretro已经停止，不要在这里进行注销事项，应该在stop()函数中完成
        
#if SIDE_LOAD
        if #available(iOS 26.0, *),
            (manicGame.gameType == .dos || manicGame.gameType == .dc),
            (LibretroCore.jitAvailable() && manicGame.jit) {
            if UIApplication.shared.canOpenURL(Constants.URLs.EnableJITUrl) {
                UIApplication.shared.open(Constants.URLs.EnableJITUrl)
            }
        }
#endif
        
        //如果是Artic Base配置 离开这个页面的时候需要进行一些清理
        if manicGame.isAzaharArticBase {
            Game.change { realm in
                realm.delete(manicGame)
            }
        }
        
        //If it's an operation on AzaharArticBase, note that manicGame has been deleted above 👆. Any further operations involving manicGame could cause serious issues.
    }
    
    /// 进入默认显示的方向
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        if manicGame.orientation == .landscape {
            return .landscapeRight
        } else if manicGame.orientation == .portrait {
            return .portrait
        }
        return super.preferredInterfaceOrientationForPresentation
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        let fromSize = Constants.Size.WindowSize
        let toSize = size
        if manicGame.orientation == .portrait {
            //当前设置为竖屏，只允许从横屏旋转到竖屏
            if fromSize.height > fromSize.width && toSize.height < toSize.width {
                return
            }
        } else if manicGame.orientation == .landscape {
            //当前设置为横屏，允许横屏旋转 或者竖屏到横屏
            if fromSize.height < fromSize.width && toSize.height > toSize.width {
                return
            }
        }
        UIView.hideAllAlert()
        super.viewWillTransition(to: size, with: coordinator)
        guard UIApplication.shared.applicationState != .background else { return }
        
        coordinator.animate(alongsideTransition: { [weak self] (context) in
            guard let self = self else { return }
            self.updateSkin()
            self.view.setNeedsLayout()
        }) { [weak self] _ in
            guard let self = self else { return }
            self.resumeEmulationAndHandleAudio()
            if self.manicGame.isLibretroType {
                self.updateFastforward(speed: self.manicGame.speed)
            }
        }
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
    }
    
    override func gameController(_ gameController: any GameController, didActivate input: any Input, value: Double) {
        if let directKeyboardInput = input as? AnyInput,
           directKeyboardInput.type == .controller(GameControllerInputType("directKeyboard")),
            manicGame.isLibretroType,
            let keyCode = LibretroKeyboardCode.createCode(withLabel: directKeyboardInput.stringValue) {
            LibretroCore.sharedInstance().pressKeyboard(keyCode)
        } else {
            handleGameInput(input.stringValue)
        }
    }
    
    override func gameController(_ gameController: any GameController, didDeactivate input: any Input) {
        if let directKeyboardInput = input as? AnyInput,
           directKeyboardInput.type == .controller(GameControllerInputType("directKeyboard")),
           manicGame.isLibretroType,
           let keyCode = LibretroKeyboardCode.createCode(withLabel: directKeyboardInput.stringValue) {
            LibretroCore.sharedInstance().releaseKeyboard(keyCode)
        } else if input.stringValue == "fastForward" ||
                    input.stringValue == "fastForward2x" ||
                    input.stringValue == "fastForward3x" ||
                    input.stringValue == "fastForward4x" {
            updateFastforward(speed: manicGame.speed)
            Log.debug("长按结束，恢复原速度")
        }
        
    }
}

//MARK: 私有方法
extension PlayViewController {
    /// 计算游戏时间
    private func calculatePlayTime() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let latestPlayDate =  manicGame.latestPlayDate {
                Game.change { realm in
                    self.manicGame.latestPlayDuration = Date().timeIntervalSince1970ms - latestPlayDate.timeIntervalSince1970ms
                    self.manicGame.totalPlayDuration += Double(Constants.Numbers.AutoSaveGameDuration*1000)
                }
                Log.debug("记录游戏时间")
            }
        }
    }
    
    private func saveStateFor3DS(type: GameSaveStateType) {
        let now = Date.now
        if type == .manualSaveState, let lastSaveDate = lastSaveDate, now.timeIntervalSince1970ms - lastSaveDate.timeIntervalSince1970ms < 5000 {
            UIView.makeToast(message: R.string.localizable.saveStateTooFrequent(), identifier: "saveStateTooFrequent")
            return
        }
        
        if let citraCore {
            let now = Date()
            //存档 并获取存档路径
            let result = citraCore.saveState()
            if result.isSuccess {
                var image: UIImage? = nil
                if let tempImage = snapShotFor3DS(topOnly: true)?.first {
                    image = tempImage.scaled(toHeight: 150)
                }
                DispatchQueue.main.asyncAfter(delay: 2) {
                    let state = GameSaveState()
                    state.name = "\(now.string(withFormat: Constants.Strings.FileNameTimeFormat))_" + result.path.lastPathComponent
                    state.type = type
                    state.date = now
                    if let imageData = image?.jpegData(compressionQuality: 0.7) {
                        state.stateCover = CreamAsset.create(objectID: state.name, propName: "stateCover", data: imageData)
                    }
                    state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", url: URL(fileURLWithPath: result.path))
                    let autoSaveStates = self.manicGame.gameSaveStates.where({ $0.type == .autoSaveState }).sorted(by: \GameSaveState.date)
                    Game.change { realm in
                        //自动保存的数量最多只能保存AutoSaveGameCount个
                        if autoSaveStates.count >= Constants.Numbers.AutoSaveGameCount {
                            let needToDeletes = autoSaveStates.prefix(autoSaveStates.count - Constants.Numbers.AutoSaveGameCount + 1)
                            CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateCover }), realm: realm)
                            CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateData }), realm: realm)
                            if Settings.defalut.iCloudSyncEnable {
                                needToDeletes.forEach { $0.isDeleted = true }
                            } else {
                                realm.delete(needToDeletes)
                            }
                        }
                        self.manicGame.gameSaveStates.append(state)
                    }
                    if type == .manualSaveState {
                        self.lastSaveDate = Date.now
                        UIView.makeToast(message: R.string.localizable.gameSaveStateSuccess(), identifier: "gameSaveStateSuccess")
                    }
                    Log.debug("保存即时存档")
                }
            }
        }
    }
    
    private func saveStateForLibretro(type: GameSaveStateType) {
        let now = Date.now
        if type == .manualSaveState, let lastSaveDate = lastSaveDate, now.timeIntervalSince1970ms - lastSaveDate.timeIntervalSince1970ms < 3000 {
            UIView.makeToast(message: R.string.localizable.saveStateTooFrequent(), identifier: "saveStateTooFrequent")
            return
        }
        LibretroCore.sharedInstance().snapshot { snapshot in
            var image = snapshot
            if (self.manicGame.gameType == .ds || self.manicGame.isAzahar3DS), let i = image {
                image = self.snapShotForDualScreen(topOnly: true, source: i)?.first
            }
            let submitSuccess = LibretroCore.sharedInstance().saveState { statePath in
                if let statePath {
                    let now = Date.now
                    let state = GameSaveState()
                    state.name = "\(now.string(withFormat: Constants.Strings.FileNameTimeFormat))_" + self.manicGame.fileName
                    state.type = type
                    state.date = now
                    if let imageData = image?.scaled(toHeight: 150)?.jpegData(compressionQuality: 0.7) {
                        state.stateCover = CreamAsset.create(objectID: state.name, propName: "stateCover", data: imageData)
                    }
                    state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", url: URL(fileURLWithPath: statePath))
                    let autoSaveStates = self.manicGame.gameSaveStates.where({ $0.type == .autoSaveState }).sorted(by: \GameSaveState.date)
                    Game.change { realm in
                        //自动保存的数量最多只能保存AutoSaveGameCount个
                        if autoSaveStates.count >= Constants.Numbers.AutoSaveGameCount {
                            let needToDeletes = autoSaveStates.prefix(autoSaveStates.count - Constants.Numbers.AutoSaveGameCount + 1)
                            CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateCover }), realm: realm)
                            CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateData }), realm: realm)
                            if Settings.defalut.iCloudSyncEnable {
                                needToDeletes.forEach { $0.isDeleted = true }
                            } else {
                                realm.delete(needToDeletes)
                            }
                        }
                        self.manicGame.gameSaveStates.append(state)
                    }
                    state.updateExtra(key: ExtraKey.saveStateCore.rawValue, value: self.manicGame.defaultCore)
                    if type == .manualSaveState {
                        self.lastSaveDate = Date.now
                    }
                    Log.debug("保存即时存档")
                }
            }
            if submitSuccess && type != .autoSaveState {
                UIView.makeToast(message: R.string.localizable.gameSaveStateSuccess(), identifier: "gameSaveStateSuccess")
            }
        }
    }
    
    private func saveStateForJGenesis(type: GameSaveStateType) {
        let now = Date.now
        if type == .manualSaveState, let lastSaveDate = lastSaveDate, now.timeIntervalSince1970ms - lastSaveDate.timeIntervalSince1970ms < 3000 {
            UIView.makeToast(message: R.string.localizable.saveStateTooFrequent(), identifier: "saveStateTooFrequent")
            return
        }
        
        let image = jGenesisCore?.snapShot()
        jGenesisCore?.saveState { [weak self] data in
            guard let self else { return }
            if let data {
                let now = Date.now
                let state = GameSaveState()
                state.name = "\(now.string(withFormat: Constants.Strings.FileNameTimeFormat))_" + self.manicGame.fileName
                state.type = type
                state.date = now
                if let imageData = image?.scaled(toHeight: 150)?.jpegData(compressionQuality: 0.7) {
                    state.stateCover = CreamAsset.create(objectID: state.name, propName: "stateCover", data: imageData)
                }
                
                state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", data: data)
                let autoSaveStates = self.manicGame.gameSaveStates.where({ $0.type == .autoSaveState }).sorted(by: \GameSaveState.date)
                Game.change { realm in
                    //自动保存的数量最多只能保存AutoSaveGameCount个
                    if autoSaveStates.count >= Constants.Numbers.AutoSaveGameCount {
                        let needToDeletes = autoSaveStates.prefix(autoSaveStates.count - Constants.Numbers.AutoSaveGameCount + 1)
                        CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateCover }), realm: realm)
                        CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateData }), realm: realm)
                        if Settings.defalut.iCloudSyncEnable {
                            needToDeletes.forEach { $0.isDeleted = true }
                        } else {
                            realm.delete(needToDeletes)
                        }
                    }
                    self.manicGame.gameSaveStates.append(state)
                }
                state.updateExtra(key: ExtraKey.saveStateCore.rawValue, value: self.manicGame.defaultCore)
                if type == .manualSaveState {
                    self.lastSaveDate = Date.now
                }
                Log.debug("保存即时存档")
                if type != .autoSaveState {
                    UIView.makeToast(message: R.string.localizable.gameSaveStateSuccess(), identifier: "gameSaveStateSuccess")
                }
            }
        }
    }
    
    private func quickLoadStateForCitra3DS(_ state: GameSaveState?) {
        let now = Date.now
        if let lastLoadDate = lastLoadDate, now.timeIntervalSince1970ms - lastLoadDate.timeIntervalSince1970ms < 5000 {
            UIView.makeToast(message: R.string.localizable.loadStateTooFrequent(), identifier: "loadStateTooFrequent")
            return
        }
        //如果传入即时存档就尝试去加载 如果没有传入则选最新的手动即时存档进行读取
        if let state = state ?? manicGame.gameSaveStates.last(where: { $0.type == .manualSaveState }),
           let citraCore,
           let slot = UInt32(state.name.deletingPathExtension.pathExtension) {
            //现将存档移到模拟器工作目录
            if let fileUrl = state.stateData?.filePath {
                citraCore.addSaveState(fileUrl: fileUrl, slot: slot)
            }
            citraCore.loadState(slot)
            UIView.makeToast(message: R.string.localizable.gameSaveStateLoadSuccess())
            lastLoadDate = Date.now
            updateCheatCodes()
        } else {
            UIView.makeToast(message: R.string.localizable.gameSaveStateQuickLoadFailed())
        }
    }
    
    private func quickLoadStateForLibretro(_ state: GameSaveState?) {
        let now = Date.now
        if let lastLoadDate = lastLoadDate, now.timeIntervalSince1970ms - lastLoadDate.timeIntervalSince1970ms < 1000 {
            UIView.makeToast(message: R.string.localizable.loadStateTooFrequent(), identifier: "loadStateTooFrequent")
            return
        }
        //如果传入即时存档就尝试去加载 如果没有传入则选最新的手动即时存档进行读取
        if let state = state ?? manicGame.gameSaveStates.last(where: { $0.type == .manualSaveState }),
           let statePath = state.stateData?.filePath.path,
           LibretroCore.sharedInstance().loadState(statePath) {
            if manicGame.gameType != .dc, (state.getExtraInt(key: ExtraKey.saveStateCore.rawValue) ?? 0) != manicGame.defaultCore {
                UIView.makeToast(message: R.string.localizable.latestSaveStateUnCompatible())
            } else {
                resumeEmulationAndHandleAudio()
                UIView.makeToast(message: R.string.localizable.gameSaveStateLoadSuccess())
                lastLoadDate = Date.now
                updateCheatCodes()
            }
        } else {
            UIView.makeToast(message: R.string.localizable.gameSaveStateQuickLoadFailed())
        }
    }

    private func quickLoadStateForJGenesis(_ state: GameSaveState?) {
        let now = Date.now
        if let lastLoadDate = lastLoadDate, now.timeIntervalSince1970ms - lastLoadDate.timeIntervalSince1970ms < 1000 {
            UIView.makeToast(message: R.string.localizable.loadStateTooFrequent(), identifier: "loadStateTooFrequent")
            return
        }
        //如果传入即时存档就尝试去加载 如果没有传入则选最新的手动即时存档进行读取
        if let state = state ?? manicGame.gameSaveStates.last(where: { $0.type == .manualSaveState }),
           let statePath = state.stateData?.filePath.path {
            jGenesisCore?.loadSaveState(path: statePath) { [weak self] isSuccess in
                guard let self else { return }
                if isSuccess {
                    if (state.getExtraInt(key: ExtraKey.saveStateCore.rawValue) ?? 0) != self.manicGame.defaultCore {
                        UIView.makeToast(message: R.string.localizable.latestSaveStateUnCompatible())
                    } else {
                        self.resumeEmulationAndHandleAudio()
                        UIView.makeToast(message: R.string.localizable.gameSaveStateLoadSuccess())
                        self.lastLoadDate = Date.now
                        self.updateCheatCodes()
                    }
                } else {
                    UIView.makeToast(message: R.string.localizable.gameSaveStateQuickLoadFailed())
                }
            }
            
        }
    }

    private func handleGameInput(_ inputStringValue: String) {
        //点击menu弹出菜单
        if inputStringValue == "menu" {
            if GameSettingView.isShow {
                UIView.hideAllAlert { [weak self] in
                    self?.resumeEmulationAndHandleAudio()
                }
            } else {
                pauseEmulationIfNeed()
                GameSettingView.show(game: manicGame,
                                     didSelectItem: { [weak self] item, sheet in
                    //点击菜单选项
                    guard let self = self else { return true }
                    return self.handleMenuGameSetting(item, sheet)
                }, hideCompletion: { [weak self] in
                    //隐藏菜单回调
                    guard let self = self else { return }
                    self.resumeEmulationAndHandleAudio()
                })
            }
        } else if inputStringValue == "flex" {
            //缩放游戏画面
            guard gameViews.count > 0 else {
                UIView.makeToast(message: R.string.localizable.flexSkinSettingError())
                return
            }
            
            pauseEmulationIfNeed()
            
            func updateFlex(images: [UIImage?]) {
                if let controllerSkin = controllerView.controllerSkin, let traits = controllerView.controllerSkinTraits,
                   let skin = Database.realm.objects(Skin.self).first(where: { $0.identifier == controllerSkin.identifier }) {
                    fixedOrientationConfig()
                    let vc = FlexSkinSettingViewController(skin: skin,
                                                           traits: traits,
                                                           images: images,
                                                           game: manicGame,
                                                           background: background,
                                                           backgroundImage: backgroundImageView?.image,
                                                           backgroundType: backgroundType)
                    vc.didCompletion = { [weak self] in
                        guard let self = self else { return }
                        self.setOrientationConfig()
                        self.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
                        //更新皮肤
                        self.updateSkin()
                        //更新声音
                        self.updateAudio()
                        //设置速度
                        self.updateFastforward(speed: self.manicGame.speed)
                        
                        self.resumeEmulationAndHandleAudio()
                    }
                    topViewController()?.present(vc, animated: true)
                }
            }
            
            var images = [UIImage?]()
            if manicGame.isCitra3DS, let snapShots = snapShotFor3DS() {
                images = snapShots
                updateFlex(images: images)
            } else if manicGame.isLibretroType {
                LibretroCore.sharedInstance().snapshot { [weak self] image in
                    guard let self else { return }
                    if self.manicGame.gameType == .ds || self.manicGame.isAzahar3DS {
                        if let image {
                            updateFlex(images: self.snapShotForDualScreen(source: image) ?? [])
                        } else {
                            updateFlex(images: [])
                        }
                    } else {
                        updateFlex(images: [image])
                    }
                }
            } else if manicGame.isJGenesisCore {
                updateFlex(images: [jGenesisCore?.snapShot()])
            } else if manicGame.isJ2MECore {
                updateFlex(images: [j2meCore?.snapShot()])
            } else {
                let mainGameView = gameViews.first!
                let secondGameView: GameView? = gameViews.count > 1 ? gameViews[1] : nil
                images.append(mainGameView.snapshot())
                if let secondGameView {
                    images.append(secondGameView.snapshot())
                }
                updateFlex(images: images)
            }
        } else if inputStringValue == "quickSave" {
            handleMenuGameSetting(GameSetting(type: .saveState), nil)
        } else if inputStringValue == "quickLoad" {
            handleMenuGameSetting(GameSetting(type: .quickLoadState), nil)
        } else if inputStringValue == "fastForward" ||
                    inputStringValue == "fastForward2x" ||
                    inputStringValue == "fastForward3x" ||
                    inputStringValue == "fastForward4x" {
            if !PurchaseManager.isMember {
                updateFastforward(speed: .two)
            } else {
                if manicGame.speed.rawValue < GameSetting.FastForwardSpeed.five.rawValue {
                    let speed: GameSetting.FastForwardSpeed
                    if inputStringValue == "fastForward2x" {
                        speed = .two
                    } else if inputStringValue == "fastForward3x" {
                        speed = .three
                    } else if inputStringValue == "fastForward4x" {
                        speed = .four
                    } else {
                        speed = .five
                    }
                    Log.debug("长按速度: \(speed.rawValue)x")
                    updateFastforward(speed: speed)
                }
            }
        } else if inputStringValue == "toggleFastForward" {
            handleMenuGameSetting(GameSetting(type: .fastForward, fastForwardSpeed: manicGame.speed.next), nil)
        } else if inputStringValue == "reverseScreens" {
            handleMenuGameSetting(GameSetting(type: .swapScreen), nil)
        } else if inputStringValue == "volume" {
            handleMenuGameSetting(GameSetting(type: .volume, volumeOn: !manicGame.volume), nil)
        } else if inputStringValue == "saveStates" {
            handleMenuGameSetting(GameSetting(type: .stateList), nil)
        } else if inputStringValue == "cheatCodes" {
            handleMenuGameSetting(GameSetting(type: .cheatCode), nil)
        } else if inputStringValue == "skins" {
            handleMenuGameSetting(GameSetting(type: .skins), nil)
        } else if inputStringValue == "filters" {
            handleMenuGameSetting(GameSetting(type: .filter), nil)
        } else if inputStringValue == "screenshot" {
            handleMenuGameSetting(GameSetting(type: .screenShot), nil)
        } else if inputStringValue == "haptics" {
            handleMenuGameSetting(GameSetting(type: .haptic, hapticType: manicGame.haptic.next), nil)
        } else if inputStringValue == "controllers" {
            handleMenuGameSetting(GameSetting(type: .controllerSetting), nil)
        } else if inputStringValue == "orientation" {
            handleMenuGameSetting(GameSetting(type: .orientation, orientation: manicGame.orientation.next), nil)
        } else if inputStringValue == "functionLayout" {
            handleMenuGameSetting(GameSetting(type: .functionSort), nil)
        } else if inputStringValue == "restart" {
            handleMenuGameSetting(GameSetting(type: .reload), nil)
        } else if inputStringValue == "resolution" {
            handleMenuGameSetting(GameSetting(type: .resolution, resolution: manicGame.resolution.next), nil)
        } else if inputStringValue == "quit" {
            UIView.makeAlert(detail: R.string.localizable.quitGameAlert(), confirmTitle: R.string.localizable.confirmTitle(), confirmAction: { [weak self] in
                self?.handleMenuGameSetting(GameSetting(type: .quit), nil)
            })
        } else if inputStringValue == "amiibo" {
            handleMenuGameSetting(GameSetting(type: .amiibo), nil)
        } else if inputStringValue == "homeMenu" {
            handleMenuGameSetting(GameSetting(type: .consoleHome), nil)
        } else if inputStringValue == "airplay" {
            handleMenuGameSetting(GameSetting(type: .airplay), nil)
        } else if inputStringValue == "toggleControlls" {
            handleMenuGameSetting(GameSetting(type: .toggleFullscreen, isFullScreen: !manicGame.forceFullSkin), nil)
        } else if inputStringValue == "blowing" {
            handleMenuGameSetting(GameSetting(type: .simBlowing), nil)
        } else if inputStringValue == "palette" {
            if manicGame.gameType == .nes || manicGame.gameType == .fds {
                handleMenuGameSetting(GameSetting(type: .palette, nesPalette: manicGame.nextNesPalette), nil)
            } else {
                handleMenuGameSetting(GameSetting(type: .palette, palette: manicGame.pallete.next), nil)
            }
        } else if inputStringValue == "swapDisk" {
            if manicGame.gameType == .fds {
                handleMenuGameSetting(GameSetting(type: .swapDisk, currentDiskIndex: 0), nil)
            } else {
                if let diskInfo = manicGame.diskInfo {
                    let currentIndex = diskInfo.currentDiskIndex
                    let totalCount = diskInfo.diskCount
                    let nextIndex = currentIndex + 1 < totalCount ? currentIndex + 1 : 0
                    handleMenuGameSetting(GameSetting(type: .swapDisk, currentDiskIndex: UInt(nextIndex)), nil)
                }
            }
        } else if inputStringValue == "toggleAnalog" {
            handleMenuGameSetting(GameSetting(type: .toggleAnalog), nil)
        } else if inputStringValue == "retroAchievements" {
            handleMenuGameSetting(GameSetting(type: .retro), nil)
        } else if inputStringValue == "airPlayScaling" {
            handleMenuGameSetting(GameSetting(type: .airPlayScaling, airPlayScaling: Settings.defalut.airPlayScaling.next), nil)
        } else if inputStringValue == "airPlayLayout" {
            handleMenuGameSetting(GameSetting(type: .airPlayLayout, airPlayLayout: Settings.defalut.airPlayLayout.next), nil)
        } else if inputStringValue == "gameplayManuals" {
            handleMenuGameSetting(GameSetting(type: .gameplayManuals), nil)
        } else if inputStringValue == "triggerPro" {
            var id: Int?
            if let currentID = manicGame.getExtraInt(key: ExtraKey.triggerProID.rawValue), currentID != -1 {
                id = Trigger.nextTriggerID(gameType: manicGame.gameType, currentID: currentID)
            } else {
                id = Trigger.nextTriggerID(gameType: manicGame.gameType, currentID: nil)
            }
            handleMenuGameSetting(GameSetting(type: .triggerPro, triggerProID: id), nil)
        } else if inputStringValue == "tvType" {
            update2600TvColor(isInit: false)
        } else if inputStringValue == "leftDifficulty" {
            update2600LeftDifficulty(isInit: false)
        } else if  inputStringValue == "rightDifficulty" {
            update2600RightDifficulty(isInit: false)
        } else if inputStringValue == "screenScaling" {
            handleMenuGameSetting(GameSetting(type: .screenScaling, screenScaling: manicGame.screenScaling.next), nil)
        } else if inputStringValue == "j2meSettings" {
            handleMenuGameSetting(GameSetting(type: .j2meSettings), nil)
        } else if inputStringValue == "dosSettings" {
            handleMenuGameSetting(GameSetting(type: .dosSettings), nil)
        } else if inputStringValue == "insertDisc" {
            handleMenuGameSetting(GameSetting(type: .insertDisc), nil)
        } else if inputStringValue == "useKeyboardSkin" {
            guard manicGame.gameType == .dos else {
                UIView.makeToast(message: R.string.localizable.notSupportGameSetting(manicGame.gameType.localizedShortName))
                return
            }
            let realm = Database.realm
            if let skin = realm.objects(Skin.self).where({
                $0.gameType == .dos &&
                $0.skinType == .buildIn &&
                $0.identifier == Constants.Strings.DOSKeyboardSkinID
            }).first {
                try? realm.write {
                    manicGame.portraitSkin = skin
                    manicGame.landscapeSkin = skin
                }
            }
        } else if inputStringValue == "useJoypadSkin" {
            guard manicGame.gameType == .dos else {
                UIView.makeToast(message: R.string.localizable.notSupportGameSetting(manicGame.gameType.localizedShortName))
                return
            }
            let realm = Database.realm
            if let skin = realm.objects(Skin.self).where({ $0.gameType == .dos && $0.skinType == .default }).first {
                try? realm.write {
                    manicGame.portraitSkin = skin
                    manicGame.landscapeSkin = skin
                }
            }
        }
    }
    
    /// 处理菜单点击
    /// - Parameter item: 菜单选项
    /// - Returns: 是否关闭菜单
    @discardableResult
    private func handleMenuGameSetting(_ item: GameSetting, _ menuSheet: SheetTarget?) -> Bool {
        if let _ = topViewController() as? ControllerMappingViewController {
            //如果当前正在映射按键 则不能进行功能响应
            return false
        }
        
        guard item.enable(for: manicGame.gameType, defaultCore: manicGame.defaultCore, onlyQuit: manicGame.isAzaharArticBase) else {
            UIView.makeToast(message: R.string.localizable.notSupportGameSetting(manicGame.gameType.localizedShortName + manicGame.coreNameForMultiSupport))
            return false
        }
        switch item.type {
        case .saveState:
            //MARK: handleMenuGameSetting.saveState
            guard !isWFCConnect else {
                UIView.makeToast(message: R.string.localizable.notAllowOnlineGame())
                return true
            }
            //快速存档
            if !PurchaseManager.isMember && manicGame.gameSaveStates.filter({ $0.type == .manualSaveState }).count >= Constants.Numbers.NonMemberManualSaveGameCount {
                //超限了
                if menuSheet == nil {
                    pauseEmulationIfNeed()
                }
                UIView.makeAlert(identifier: Constants.Strings.PlayPurchaseAlertIdentifier,
                                 detail: R.string.localizable.manualGameSaveCountLimit(),
                                 confirmTitle: R.string.localizable.goToUpgrade(),
                                 confirmAutoHide: false,
                                 confirmAction: {
                    topViewController()?.present(PurchaseViewController(), animated: true)
                }, hideAction: { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                })
                return false
            }
            
            //没有超限 则继续存储
            if manicGame.isCitra3DS {
                saveStateFor3DS(type: .manualSaveState)
            } else if manicGame.isLibretroType {
                saveStateForLibretro(type: .manualSaveState)
            } else if manicGame.isJGenesisCore {
                saveStateForJGenesis(type: .manualSaveState)
            }
        case .quickLoadState:
            //MARK: handleMenuGameSetting.quickLoadState
            guard !isWFCConnect else {
                UIView.makeToast(message: R.string.localizable.notAllowOnlineGame())
                return true
            }
            guard !isHardcoreMode else {
                UIView.makeToast(message: R.string.localizable.notAllowHardcore())
                return true
            }
            //快速读档
            if manicGame.isCitra3DS {
                quickLoadStateForCitra3DS(item.loadState)
            } else if manicGame.isLibretroType {
                quickLoadStateForLibretro(item.loadState)
            } else if manicGame.isJGenesisCore {
                quickLoadStateForJGenesis(item.loadState)
            }
        case .volume:
            //MARK: handleMenuGameSetting.volume
            //声音设置
            //恢复游戏的时候会直接使用新配置
            Game.change { realm in
                manicGame.volume = item.volumeOn
            }
            skinSwitchBindDatas["volume"] = manicGame.volume
            
            if menuSheet == nil {
                //说明这里不是由menu菜单进行设置的 则不存在恢复游戏的过程 所以需要手动更新声音
                updateAudio()
            }
            UIView.makeToast(message: item.volumeOn ? R.string.localizable.volumeOn(): R.string.localizable.volumeOff(), identifier: "gameVolume")
        case .fastForward:
            //MARK: handleMenuGameSetting.fastForward
            guard !isWFCConnect else {
                UIView.makeToast(message: R.string.localizable.notAllowOnlineGame())
                return true
            }
            //快进
            if !PurchaseManager.isMember && item.fastForwardSpeed.rawValue > GameSetting.FastForwardSpeed.two.rawValue {
                //超限了
                if menuSheet == nil {
                    pauseEmulationIfNeed()
                }
                UIView.makeAlert(identifier: Constants.Strings.PlayPurchaseAlertIdentifier,
                                 detail: R.string.localizable.fastForwardSpeedLimit(),
                                 cancelTitle: R.string.localizable.resetSpeed(),
                                 confirmTitle: R.string.localizable.goToUpgrade(),
                                 confirmAutoHide: false, cancelAction: { [weak self] in
                    guard let self = self else { return }
                    self.updateFastforward(speed: .one)
                    Game.change { realm in
                        self.manicGame.speed = .one
                    }
                    UIView.makeToast(message: R.string.localizable.gameSettingFastForwardResume())
                }, confirmAction: {
                    topViewController()?.present(PurchaseViewController(), animated: true)
                }, hideAction: { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                })
            } else {
                if manicGame.speed.rawValue == 0 || manicGame.speed != item.fastForwardSpeed {
                    if manicGame.gameType == .ps1, manicGame.defaultCore == 0, menuSheet == nil {
                        pauseEmulationIfNeed()
                    }
                    updateFastforward(speed: item.fastForwardSpeed)
                    if manicGame.gameType == .ps1, manicGame.defaultCore == 0, menuSheet == nil {
                        resumeEmulationAndHandleAudio()
                    }
                    Game.change { realm in
                        manicGame.speed = item.fastForwardSpeed
                    }
                }
                UIView.makeToast(message: item.fastForwardSpeed == .one ? R.string.localizable.gameSettingFastForwardResume() : item.fastForwardSpeed.title, identifier: "gameSpeed")
            }
            return false
        case .stateList:
            //MARK: handleMenuGameSetting.stateList
            guard !isWFCConnect else {
                UIView.makeToast(message: R.string.localizable.notAllowOnlineGame())
                return true
            }
            guard !isHardcoreMode else {
                UIView.makeToast(message: R.string.localizable.notAllowHardcore())
                return true
            }
            if menuSheet == nil {
                pauseEmulationIfNeed()
            }
            GameInfoView.show(game: manicGame, selection: { [weak self, weak menuSheet] saveState in
                guard let self = self else { return }
                func loadSave() {
                    if self.manicGame.isCitra3DS {
                        DispatchQueue.main.asyncAfter(delay: 1) {
                            self.resumeEmulationAndHandleAudio()
                            self.quickLoadStateForCitra3DS(saveState)
                        }
                    } else if self.manicGame.isLibretroType {
                        self.quickLoadStateForLibretro(saveState)
                    } else if self.manicGame.isJGenesisCore {
                        self.quickLoadStateForJGenesis(saveState)
                    }
                }
                if menuSheet == nil {
                    loadSave()
                } else {
                    if self.manicGame.isLibretroType {
                        loadSave()
                        menuSheet?.pop()
                    } else {
                        menuSheet?.pop {
                            loadSave()
                        }
                    }
                }
            }, hideCompletion: { [weak self] in
                if menuSheet == nil {
                    self?.resumeEmulationAndHandleAudio()
                }
            })
            return false
        case .cheatCode:
            //MARK: handleMenuGameSetting.cheatCode
            guard !isWFCConnect else {
                UIView.makeToast(message: R.string.localizable.notAllowOnlineGame())
                return true
            }
            guard !isHardcoreMode else {
                UIView.makeToast(message: R.string.localizable.notAllowHardcore())
                return true
            }
            if manicGame.gameType == .ss && manicGame.defaultCore == 0 {
                UIView.makeToast(message: R.string.localizable.beetleSaturnNoSupportCheat())
            } else if manicGame.gameType == .arcade, manicGame.defaultCore == 0 {
                UIView.makeAlert(detail: R.string.localizable.mameCheatCodeDesc(), cancelTitle: R.string.localizable.confirmTitle())
            } else {
                if menuSheet == nil {
                    pauseEmulationIfNeed()
                }
                if manicGame.gameType == .arcade, manicGame.defaultCore == 1 {
                    FBNeoCheatCodeListView.show(game: manicGame, hideCompletion: { [weak self] in
                        if menuSheet == nil {
                            self?.resumeEmulationAndHandleAudio()
                        }
                    })
                } else {
                    CheatCodeListView.show(game: manicGame, hideCompletion: { [weak self] in
                        if menuSheet == nil {
                            self?.resumeEmulationAndHandleAudio()
                        }
                    })
                }
            }
            return false
        case .skins:
            //MARK: handleMenuGameSetting.skins
            if menuSheet == nil {
                pauseEmulationIfNeed()
            }
            SkinSettingsView.show(game: manicGame, hideCompletion: { [weak self] in
                if menuSheet == nil {
                    self?.resumeEmulationAndHandleAudio()
                }
            })
            return false
        case .filter:
            //MARK: handleMenuGameSetting.filter
            guard !manicGame.isCitra3DS else { return true }
            if menuSheet == nil {
                pauseEmulationIfNeed()
            }
            if manicGame.isLibretroType {
                ShadersListView.show(game: self.manicGame,
                                     ignoreShaderConfig: manicGame.getExtraBool(key: ExtraKey.ignoreShaderConfig.rawValue) ?? false,
                                     hideCompletion: { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                }, didSelectShader: { [weak self] shader in
                    guard let self else { return }
                    //该游戏是否需要忽略核心和全局着色器的配置
                    self.manicGame.updateExtra(key: ExtraKey.ignoreShaderConfig.rawValue, value: shader.isOriginal)
                    Game.change { [weak self] realm in
                        guard let self = self else { return }
                        if shader.isOriginal {
                            self.manicGame.filterName = nil
                        } else {
                            self.manicGame.filterName = shader.relativePath
                        }
                    }
                }, didUpdateShaderConfig: { [weak self] type in
                    guard let self else { return }
                    switch type {
                    case .setGlobal:
                        self.manicGame.updateExtra(key: ExtraKey.ignoreShaderConfig.rawValue, value: false)
                    case .removeGlobal:
                        self.manicGame.updateExtra(key: ExtraKey.ignoreShaderConfig.rawValue, value: false)
                    case .setCore(let coreName):
                        if self.manicGame.gameType.localizedShortName == coreName {
                            self.manicGame.updateExtra(key: ExtraKey.ignoreShaderConfig.rawValue, value: false)
                        }
                    case .removeCore(let coreName):
                        if self.manicGame.gameType.localizedShortName == coreName {
                            self.manicGame.updateExtra(key: ExtraKey.ignoreShaderConfig.rawValue, value: false)
                        }
                    }
                    self.updateFilter()
                })
            }
            return false
        case .screenShot:
            //MARK: handleMenuGameSetting.screenShot
            //截屏
            if manicGame.isCitra3DS {
                if let images = self.snapShotFor3DS() {
                    DispatchQueue.global().asyncAfter(delay: menuSheet == nil ? 0 : 1, execute: {
                        var imageDatas = [Data]()
                        for image in images {
                            if let imageData = image.jpegData(compressionQuality: 0.7) {
                                imageDatas.append(imageData)
                            }
                        }
                        if imageDatas.count > 0 {
                            PhotoSaver.save(datas: imageDatas)
                        }
                    })
                }
            } else if manicGame.isLibretroType {
                DispatchQueue.main.asyncAfter(delay: menuSheet == nil ? 0 : 1, execute: {
                    LibretroCore.sharedInstance().snapshot { image in
                        if (self.manicGame.gameType == .ds || self.manicGame.isAzahar3DS), let i = image, let images = self.snapShotForDualScreen(source: i) {
                            var imageDatas = [Data]()
                            for image in images {
                                if let imageData = image.jpegData(compressionQuality: 0.7) {
                                    imageDatas.append(imageData)
                                }
                            }
                            if imageDatas.count > 0 {
                                PhotoSaver.save(datas: imageDatas)
                            }
                        } else {
                            if let image {
                                PhotoSaver.save(image: image);
                            }
                        }
                    }
                })
            } else if manicGame.isJGenesisCore {
                if let image = jGenesisCore?.snapShot() {
                    PhotoSaver.save(image: image)
                }
                return false
            } else if manicGame.isJ2MECore {
                if let image = j2meCore?.snapShot() {
                    PhotoSaver.save(image: image)
                }
                return false
            } else {
                PhotoSaver.save(datas: gameViews.compactMap { $0.snapshot()?.processGameSnapshop() })
                return false
            }
        case .haptic:
            //MARK: handleMenuGameSetting.haptic
            switch item.hapticType {
            case .off:
                break
            case .soft:
                Haptic.impact(.soft).generate()
            case .light:
                Haptic.impact(.light).generate()
            case .medium:
                Haptic.impact(.medium).generate()
            case .heavy:
                Haptic.impact(.heavy).generate()
            case .rigid:
                Haptic.impact(.rigid).generate()
            }
            if manicGame.haptic != item.hapticType {
                Game.change { realm in
                    manicGame.haptic = item.hapticType
                }
            }
            UIView.makeToast(message: item.hapticType.title, identifier: "hapticType")
            return false
        case .airplay:
            //MARK: handleMenuGameSetting.airplay
            if menuSheet == nil {
                pauseEmulationIfNeed()
            }
            let vc = WebViewController(url: Constants.URLs.AirPlayUsageGuide, isShow: true, bottomInset: getMenuInsets()?.bottom ?? nil)
            vc.didClose = { [weak self] in
                if menuSheet == nil {
                    self?.resumeEmulationAndHandleAudio()
                }
            }
            topViewController()?.present(vc, animated: true)
            return false
        case .controllerSetting:
            //MARK: handleMenuGameSetting.controllerSetting
            if menuSheet == nil {
                pauseEmulationIfNeed()
            }
            ControllersSettingView.show(gameType: manicGame.gameType, hideCompletion: { [weak self] in
                if menuSheet == nil {
                    self?.resumeEmulationAndHandleAudio()
                }
            })
            return false
        case .orientation:
            //MARK: handleMenuGameSetting.orientation
            if manicGame.orientation != item.orientation {
                Game.change { realm in
                    manicGame.orientation = item.orientation
                }
                //旋转需要时间 旋转结束再弹出toast
                DispatchQueue.main.asyncAfter(delay: 0.5) {
                    UIView.makeToast(message: item.orientation.title)
                }
            } else {
                UIView.makeToast(message: item.orientation.title)
            }
            return true
        case .functionSort:
            //MARK: handleMenuGameSetting.functionSort
            if menuSheet == nil {
                pauseEmulationIfNeed()
            }
            GameSettingView.show(game: manicGame, isEditingMode: true, hideCompletion: { [weak self] in
                if menuSheet == nil {
                    self?.resumeEmulationAndHandleAudio()
                }
            })
            return false
        case .reload:
            //MARK: handleMenuGameSetting.reload
            if manicGame.isCitra3DS {
                citraCore?.reload()
            } else if manicGame.isLibretroType {
                LibretroCore.sharedInstance().reload()
                updateFilter()
            } else if manicGame.isJGenesisCore {
                jGenesisCore?.reset()
            } else if manicGame.isJ2MECore {
                j2meCore?.reset(screenSize: manicGame.j2meScreenSize, rotation: manicGame.j2meScreenRotation) { [weak self] success in
                    guard let self = self else { return }
                    if success {
                        self.updateFastforward(speed: self.manicGame.speed)
                        self.updateAudio()
                        self.updateScreenScaling(self.manicGame.screenScaling)
                    }
                }
            }
        case .quit:
            //MARK: handleMenuGameSetting.quit
            if manicGame.isCitra3DS {
                citraCore?.stop()
                DispatchQueue.main.asyncAfter(delay: 0.5) {
                    self.dismiss(animated: true)
                }
            } else if manicGame.isLibretroType {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.LibretroSavePath.libretroPath)
                LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: Constants.Path.System.libretroPath)
                LibretroCore.sharedInstance().stop()
                gameMetalView = nil;
                DispatchQueue.main.asyncAfter(delay: 0.5) {
                    self.dismiss(animated: true)
                }
            } else if manicGame.isJGenesisCore {
                gameMetalView = nil
                DispatchQueue.main.asyncAfter(delay: 0.5) {
                    self.dismiss(animated: true)
                }
            } else if manicGame.isJ2MECore {
                gameMetalView = nil
                DispatchQueue.main.asyncAfter(delay: 0.5) {
                    self.dismiss(animated: true)
                }
            }
        case .resolution:
            //MARK: handleMenuGameSetting.resolution
            guard manicGame.gameType == ._3ds ||
                    manicGame.gameType == .psp ||
                    manicGame.gameType == .n64 ||
                    (manicGame.gameType == .ps1 && manicGame.defaultCore == 0) ||
                    manicGame.gameType == .dc ||
                    (manicGame.gameType == .ds && manicGame.defaultCore == 1) ||
                    manicGame.gameType == .doom else { return true }
            Log.debug("设置分辨率")
            if manicGame.resolution != item.resolution {
                Game.change { realm in
                    manicGame.resolution = item.resolution
                }
                if manicGame.gameType == ._3ds {
                    if manicGame.isCitra3DS {
                        citraCore?.setResolution(resolution: item.resolution)
                    } else {
                        let resolutionRaw = item.resolution == .undefine ? 1 : item.resolution.rawValue
                        LibretroCore.sharedInstance().updateRunningCoreConfigs(["citra_resolution_factor": "\(resolutionRaw)"], flush: false)
                    }
                } else if manicGame.gameType == .psp {
                    updatePSPResolution(item.resolution, reload: true)
                } else if manicGame.gameType == .n64 {
                    updateN64Resolution(item.resolution, reload: true)
                } else if manicGame.gameType == .ps1 && manicGame.defaultCore == 0 {
                    LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetlePSXHW.name, key: "beetle_psx_hw_internal_resolution", value: item.resolution.resolutionTitleForPS1, reload: true)
                } else if manicGame.gameType == .dc {
                    updateDCResolution(item.resolution, reload: true)
                } else if manicGame.gameType == .ds {
                    let scale = UInt32(item.resolution == .undefine ? 1 : item.resolution.rawValue)
                    let option = "\(256*scale)x\(192*scale)"
                    LibretroCore.sharedInstance().updateRunningCoreConfigs(["desmume_internal_resolution": option], flush: false)
                } else if manicGame.gameType == .doom {
                    let scale = UInt32(item.resolution == .undefine ? 1 : item.resolution.rawValue)
                    let option = "\(320*scale)x\(200*scale)"
                    LibretroCore.sharedInstance().updateRunningCoreConfigs(["prboom-resolution": option], flush: true)
                    LibretroCore().reload(byKeepState: true)
                }
            }
            let message: String
            if manicGame.gameType == .ps1 && manicGame.defaultCore == 0 {
                message = R.string.localizable.gameSettingResolution(item.resolution.resolutionTitleForPS1)
            } else if manicGame.isN64ParaLLEl {
                message = R.string.localizable.gameSettingResolution(item.resolution.resolutionTitleForN64ParaLLEl)
            } else {
                message = item.resolution.title
            }
            UIView.makeToast(message: message, identifier: "resolution")
            return manicGame.gameType == .psp //psp需要隐藏菜单(恢复游戏) 才能生效
        case .swapScreen:
            //MARK: handleMenuGameSetting.swapScreen
            if enableSwapScreen() {
                Game.change { realm in
                    manicGame.swapScreen = !manicGame.swapScreen
                }
                skinSwitchBindDatas["reverseScreens"] = manicGame.swapScreen
                updateSkin()
            }
        case .consoleHome:
            //MARK: handleMenuGameSetting.consoleHome
            //回到主页
            if manicGame.gameType == ._3ds {
                if manicGame.isCitra3DS {
                    if manicGame.is3DSHomeMenuGame {
                        DispatchQueue.main.asyncAfter(delay: 0.5) {
                            self.citraCore?.jumpToHome()
                        }
                    } else {
                        UIView.makeToast(message: R.string.localizable.threeDSHomeMenuNotRunning())
                    }
                } else {
                    //TODO: azahar 返回主页
                }
            }
        case .amiibo:
            //MARK: handleMenuGameSetting.amiibo
            //加载amiibo
            if manicGame.gameType == ._3ds {
                let isSearchingAmiibo = (manicGame.isCitra3DS && (citraCore?.isAmiiboSearching() ?? false)) || (manicGame.isAzahar3DS && LibretroCore.sharedInstance().isSearchingAmiibo())
                if isSearchingAmiibo {
                    if menuSheet == nil {
                        pauseEmulationIfNeed()
                    }
                    Log.debug("amiibo正在搜索中")
                    FilesImporter.shared.presentImportController(supportedTypes: UTType.binTypes, allowsMultipleSelection: false) { [weak self] urls in
                        guard let self = self else { return }
                        self.resumeEmulationAndHandleAudio()
                        UIView.hideAllAlert { [weak self] in
                            guard let self = self else { return }
                            if let url = urls.first {
                                DispatchQueue.main.asyncAfter(delay: 1) {
                                    if self.manicGame.isCitra3DS {
                                        self.citraCore?.loadAmiibo(path: url.path)
                                    } else {
                                        LibretroCore.sharedInstance().loadAmiibo(url.path)
                                    }
                                }
                            }
                        }
                    }
                    return false
                } else {
                    Log.debug("amiibo没有搜索")
                    UIView.makeToast(message: R.string.localizable.amiiboNotSearching())
                }
            }
        case .toggleFullscreen:
            //MARK: handleMenuGameSetting.toggleFullscreen
            manicGame.forceFullSkin = item.isFullScreen
            skinSwitchBindDatas["toggleControlls"] = manicGame.forceFullSkin
            manicGame.updateExtra(key: ExtraKey.forceFullSkin.rawValue, value: item.isFullScreen)
            updateSkin()
            
        case .simBlowing:
            //MARK: handleMenuGameSetting.simBlowing
            if manicGame.gameType == ._3ds {
                if manicGame.isCitra3DS {
                    citraCore?.setSimBlowing(start: true)
                    DispatchQueue.main.asyncAfter(delay: 5) { [weak self] in
                        self?.citraCore?.setSimBlowing(start: false)
                    }
                } else {
                    LibretroCore.sharedInstance().updateRunningCoreConfigs(["citra_input_type": "static_noise"], flush: false)
                    DispatchQueue.main.asyncAfter(delay: 5) {
                        LibretroCore.sharedInstance().updateRunningCoreConfigs(["citra_input_type": "frontend"], flush: false)
                    }
                }
            } else if manicGame.gameType == .ds {
                if manicGame.defaultCore == 0 {
                    //melonDSDS
                    LibretroCore.sharedInstance().updateRunningCoreConfigs(["melonds_mic_input": "blow"], flush: false)
                    DispatchQueue.main.asyncAfter(delay: 5) { [weak self] in
                        var restoreInput = "silence"
                        if self?.manicGame.getExtraBool(key: ExtraKey.microphone.rawValue) ?? false {
                            restoreInput = "microphone"
                        }
                        LibretroCore.sharedInstance().updateRunningCoreConfigs(["melonds_mic_input": restoreInput], flush: false)
                    }
                } else {
                    //DeSmuME
                    DispatchQueue.main.asyncAfter(delay: 1) {
                        LibretroCore.sharedInstance().press(.L3, playerIndex: 0)
                        DispatchQueue.main.asyncAfter(delay: 5) {
                            LibretroCore.sharedInstance().release(.L3, playerIndex: 0)
                        }
                    }
                }
                
            } else if manicGame.gameType == .nes || manicGame.gameType == .fds {
                DispatchQueue.main.asyncAfter(delay: 1) {
                    LibretroCore.sharedInstance().press(.L3, playerIndex: 0)
                    DispatchQueue.main.asyncAfter(delay: 0.1) {
                        LibretroCore.sharedInstance().release(.L3, playerIndex: 0)
                    }
                }
            }
            
        case .palette:
            //MARK: handleMenuGameSetting.palette
            if manicGame.gameType == .nes || manicGame.gameType == .fds {
                updateNESPalette(item.nesPalette)
                return true
            }
            
            guard (manicGame.gameType == .gb || manicGame.gameType == .vb || manicGame.gameType == .pm) else { return false }
            if manicGame.pallete != item.palette {
                Game.change { realm in
                    manicGame.pallete = item.palette
                }
                if manicGame.gameType == .vb {
                    LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetleVB.name, key: "vb_color_mode", value: item.palette.paletteTitleForVB, reload: true)
                } else if manicGame.gameType == .pm {
                    LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PokeMini.name, key: "pokemini_palette", value: item.palette.paletteTitleForPM, reload: true)
                } else if manicGame.gameType == .gb {
                    if manicGame.defaultCore == 0 {
                        //Gambatte
                        LibretroCore.sharedInstance().updateRunningCoreConfigs([
                            "gambatte_gb_colorization": item.palette == .None ? "disabled" : "internal",
                            "gambatte_gb_internal_palette": item.palette.optionForGambatte
                        ], flush: false)
                    } else if manicGame.defaultCore == 1 {
                        //mGBA
                        LibretroCore.sharedInstance().updateRunningCoreConfigs([
                            "mgba_gb_colors": item.palette.optionForMGBA
                        ], flush: false)
                    } else if manicGame.defaultCore == 2 {
                        LibretroCore.sharedInstance().updateRunningCoreConfigs([
                            "vbam_palettes": item.palette.optionForVBAM
                        ], flush: false)
                    }
                }
            }
        case .swapDisk:
            //MARK: handleMenuGameSetting.swapDisk
            if manicGame.gameType == .fds {
                if item.currentDiskIndex == 0 {
                    //(FDS) Disk Side Change
                    UIView.makeToast(message: R.string.localizable.diskSideChange())
                    DispatchQueue.main.asyncAfter(delay: 1) {
                        LibretroCore.sharedInstance().press(.L1, playerIndex: 0)
                        DispatchQueue.main.asyncAfter(delay: 0.1) {
                            LibretroCore.sharedInstance().release(.L1, playerIndex: 0)
                        }
                    }
                } else {
                    //(FDS) Eject Disk
                    UIView.makeToast(message: R.string.localizable.ejectDisk())
                    DispatchQueue.main.asyncAfter(delay: 1) {
                        LibretroCore.sharedInstance().press(.R1, playerIndex: 0)
                        DispatchQueue.main.asyncAfter(delay: 0.1) {
                            LibretroCore.sharedInstance().release(.R1, playerIndex: 0)
                        }
                    }
                }
                return true
            }
            
            guard manicGame.gameType == .mcd || manicGame.gameType == .ss || manicGame.gameType == .ps1 || manicGame.gameType == .dc || manicGame.gameType == .dos else { return false }
            if manicGame.supportSwapDisc {
                LibretroCore.sharedInstance().setDiskIndex(UInt32(item.currentDiskIndex), delay: manicGame.gameType == .ps1 ? true : false)
                UIView.makeToast(message: R.string.localizable.discInsert(Int(item.currentDiskIndex + 1)))
            } else {
                UIView.makeToast(message: R.string.localizable.notSupportSwapDisk())
            }
            return false
        case .retro:
            //MARK: handleMenuGameSetting.retro
            if menuSheet == nil {
                pauseEmulationIfNeed()
            }
            func openRetroAchievementsList() {
                let vc = RetroAchievementsListViewController(game: manicGame, bottomInset: getMenuInsets()?.bottom ?? nil)
                vc.didClose = { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                }
                topViewController()?.present(vc, animated: true)
            }
            
            if let _ = AchievementsUser.getUser() {
                openRetroAchievementsList()
            } else {
                //先进行登录
                let vc = RetroAchievementsViewController()
                vc.dismissAfterLoginSuccess = {
                    openRetroAchievementsList()
                }
                topViewController()?.present(vc, animated: true)
            }
            
            return false
            
        case .airPlayScaling:
            //MARK: handleMenuGameSetting.airPlayScaling
            if item.airPlayScaling != Settings.defalut.airPlayScaling {
                Settings.defalut.updateExtra(key: ExtraKey.airPlayScaling.rawValue, value: item.airPlayScaling.rawValue)
                //如果当前正处于AirPlay状态 则更新AirPlay的缩放模式
                updateAirPlay()
            }
            UIView.makeToast(message: R.string.localizable.airPlayScaling() + ": " + item.airPlayScaling.title)
            
        case .airPlayLayout:
            //MARK: handleMenuGameSetting.airPlayLayout
            if item.airPlayLayout != Settings.defalut.airPlayLayout {
                Settings.defalut.updateExtra(key: ExtraKey.airPlayLayout.rawValue, value: item.airPlayLayout.rawValue)
                //如果当前正处于AirPlay状态 则更新AirPlay的布局
                updateAirPlay()
            }
            UIView.makeToast(message: R.string.localizable.airPlayLayout() + ": " + item.airPlayLayout.title)
            
        case .toggleAnalog:
            //MARK: handleMenuGameSetting.toggleAnalog
            if manicGame.gameType == .ps1 {
                DispatchQueue.main.asyncAfter(delay: manicGame.defaultCore == 0 ? 0 : 1, execute: { [weak self] in
                    guard let self else { return }
                    self.updateAnalogMode(toastAllow: true, toggle: true);
                })
                
            }
            
        case .gameplayManuals:
            //MARK: handleMenuGameSetting.gameplayManuals
            if menuSheet == nil {
                pauseEmulationIfNeed()
            }
            
            func showManualsView() {
                GameplayManualsView.show(game: manicGame, hideCompletion: { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                })
            }
            
            if manicGame.isManualsExists {
                showManualsView()
            } else {
                UIView.makeAlert(title: R.string.localizable.gameplayManualsNoExists(),
                                 detail: R.string.localizable.gameplayManualsDesc(),
                                 confirmTitle: R.string.localizable.gameListBackgroundUpload(),
                                 cancelAction: { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                }, confirmAction: {
                    DispatchQueue.main.asyncAfter(delay: 0.35) {
                        FilesImporter.shared.presentImportController(supportedTypes: [UTType.pdf], allowsMultipleSelection: false) { [weak self] urls in
                            guard let self else { return }
                            if let pdfUrl = urls.first {
                                do {
                                    let pdfName = pdfUrl.lastPathComponent
                                    try FileManager.safeCopyItem(at: pdfUrl, to: URL(fileURLWithPath: Constants.Path.GameplayManuals.appendingPathComponent(pdfName)), shouldReplace: true)
                                    self.manicGame.updateExtra(key: ExtraKey.manualFileName.rawValue, value: pdfName)
                                    showManualsView()
                                } catch {}
                            }
                        }
                    }
                })
            }
            return false
        case .triggerPro:
            //MARK: handleMenuGameSetting.triggerPro
            guard !isHardcoreMode else {
                UIView.makeToast(message: R.string.localizable.notAllowHardcore())
                return false
            }
            let triggers = Trigger.supportTriggers(gameType: manicGame.gameType)
            if triggers.count == 0 {
                UIView.makeToast(message: R.string.localizable.noTriggerPro())
                return false
            }
            
            if let fromID = item.triggerProID {
                manicGame.updateExtra(key: ExtraKey.triggerProID.rawValue, value: fromID)
            } else {
                //关闭TriggerPro
                manicGame.updateExtra(key: ExtraKey.triggerProID.rawValue, value: -1)
            }
            self.updateTriggerPro(showToast: true)
            return true
            
        case .screenScaling:
            //MARK: handleMenuGameSetting.screenScaling
            if item.screenScaling != manicGame.screenScaling {
                manicGame.updateExtra(key: ExtraKey.screenScaling.rawValue, value: item.screenScaling.rawValue)
                updateScreenScaling(item.screenScaling)
            }
            UIView.makeToast(message: R.string.localizable.screenScaling() + ": " + item.screenScaling.title)
            
        case .j2meSettings:
            //MARK: handleMenuGameSetting.j2meSettings
            J2MESettingView.show(game: manicGame)
            return false
        case .dosSettings:
            //MARK: handleMenuGameSetting.dosSettings
            CoreConfigsView.show(game: manicGame, configChange: {
                Log.debug("change DOS config:\($0)")
                LibretroCore.sharedInstance().updateRunningCoreConfigs($0, flush: false)
            })
            return false
        case .insertDisc:
            //MARK: handleMenuGameSetting.insertDisc
            UIView.makeAlert(title: R.string.localizable.insertDisc(),
                             detail: R.string.localizable.insertDiscAlert(),
                             cancelTitle: R.string.localizable.transferPakFromLibrary(),
                             confirmTitle: R.string.localizable.transferPakFromFiles(), cancelAction: { [weak self] in
                guard let self else { return }
                let realm = Database.realm
                let objects = realm.objects(Game.self).where({ $0.gameType == self.manicGame.gameType && !$0.isDeleted })
                var games = [Game]()
                games.append(contentsOf: objects)
                if games.count > 0 {
                    GameSaveMatchGameView.show(showGames: games,
                                               title: R.string.localizable.insertDisc(),
                                               detail: "",
                                               cancelTitle: R.string.localizable.cancelTitle(), completion: { game in
                        if let path = game?.romUrl.path {
                            if LibretroCore.sharedInstance().insertDisk(path) {
                                UIView.makeToast(message: R.string.localizable.discInsert(self.manicGame.diskInfo?.currentDiskIndex ?? 0))
                            } else {
                                UIView.makeToast(message: R.string.localizable.insertDiscFailed())
                            }
                        } else {
                            UIView.makeToast(message: R.string.localizable.transferPakNoGames())
                        }
                    })
                } else {
                    UIView.makeToast(message: R.string.localizable.transferPakNoGames())
                }
            }, confirmAction: { [weak self] in
                guard let self else { return }
                let types = UTType.getGameTypes(gameType: self.manicGame.gameType)
                DispatchQueue.main.asyncAfter(delay: 1) {
                    FilesImporter.shared.presentImportController(supportedTypes: types,
                                                                 allowsMultipleSelection: false,
                                                                 manualHandle: { urls in
                        if let url = urls.first {
                            let toCachePath = Constants.Path.Cache.appendingPathComponent(url.lastPathComponent)
                            if !FileManager.default.fileExists(atPath: toCachePath) {
                                UIView.makeLoading()
                                try? FileManager.safeCopyItem(at: url, to: URL(fileURLWithPath: toCachePath))
                                DispatchQueue.main.async {
                                    UIView.hideLoading()
                                }
                            }
                            if LibretroCore.sharedInstance().insertDisk(toCachePath) {
                                UIView.makeToast(message: R.string.localizable.discInsert(self.manicGame.diskInfo?.currentDiskIndex ?? 0))
                            } else {
                                UIView.makeToast(message: R.string.localizable.insertDiscFailed())
                            }
                        }
                    })
                }
            })
            return false
        }
        //默认关闭菜单
        return true
    }
    
    //更新外设控制器
    private func updateExternalGameController() {
        if let emulatorCore = self.emulatorCore {
            let realm = Database.realm
            for controler in ExternalGameControllerManager.shared.connectedControllers {
                var mapping: GameControllerInputMapping? = nil
                if let object = realm.objects(ControllerMapping.self).first(where: { $0.controllerName == controler.name && $0.gameType == manicGame.gameType && !$0.isDeleted }) {
                    mapping = try? GameControllerInputMapping(mapping: object.mapping)
                }
                if let mapping {
                    controler.addReceiver(self, inputMapping: mapping)
                    controler.addReceiver(emulatorCore, inputMapping: mapping)
                } else {
                    controler.addReceiver(self)
                    controler.addReceiver(emulatorCore)
                }
                if let mfi = controler as? MFiGameController, manicGame.isLibretroType, let playerIndex = mfi.playerIndex {
                    if LibretroCore.sharedInstance().getSensorEnable(Int32(playerIndex)) {
                        mfi.controller.motion?.sensorsActive = true
                    } else {
                        mfi.controller.motion?.sensorsActive = false
                    }
                }
            }
            if ExternalGameControllerManager.shared.connectedControllers.count > 0 && Settings.defalut.fullScreenWhenConnectController {
                self.manicGame.forceFullSkin = true
            }
            updateNDSCursor()
        }
    }
    
    /// 更新最近游戏时间
    private func updateLatestPlayDate() {
        let date = Date()
        Log.debug("开始游戏: \(date.timeIntervalSince1970ms)")
        Game.change { _ in
            self.manicGame.latestPlayDate = date
        }
    }
    
    @discardableResult
    private func pauseEmulationIfNeed() -> Bool {
        guard !isWFCConnect else {
            return false
        }
        if manicGame.isCitra3DS {
            citraCore?.pause()
            return true
        } else if manicGame.isLibretroType {
            LibretroCore.sharedInstance().pause()
            return true
        } else if manicGame.isJGenesisCore {
            jGenesisCore?.pause()
            return true
        } else if manicGame.isJ2MECore {
            j2meCore?.pause()
            return true
        }
        return false
    }
    
    private func resumeEmulationAndHandleAudio() {
        if manicGame.isCitra3DS {
            citraCore?.resume()
            updateAudio()
        } else if manicGame.isLibretroType {
            LibretroCore.sharedInstance().resume()
            updateAudio()
        } else if manicGame.isJGenesisCore {
            jGenesisCore?.resume()
            updateAudio()
        } else if manicGame.isJ2MECore {
            j2meCore?.resume()
            updateAudio()
        }
    }

    private func updateAudio() {
        if manicGame.isCitra3DS {
            if manicGame.volume {
                if Settings.defalut.respectSilentMode, muteSwitchMonitor.isMonitoring, muteSwitchMonitor.isMuted {
                    citraCore?.disableVolume()
                } else {
                    citraCore?.enableVolume()
                }
            } else {
                citraCore?.disableVolume()
            }
        } else if manicGame.isLibretroType {
            if Settings.defalut.respectSilentMode, muteSwitchMonitor.isMonitoring, muteSwitchMonitor.isMuted {
                LibretroCore.sharedInstance().mute(false)
            } else {
                LibretroCore.sharedInstance().mute(manicGame.volume)
            }
        } else if manicGame.isJGenesisCore {
            if Settings.defalut.respectSilentMode, muteSwitchMonitor.isMonitoring, muteSwitchMonitor.isMuted {
                jGenesisCore?.setMute(true)
            } else {
                jGenesisCore?.setMute(!manicGame.volume)
            }
        } else if manicGame.isJ2MECore {
            if Settings.defalut.respectSilentMode, muteSwitchMonitor.isMonitoring, muteSwitchMonitor.isMuted {
                j2meCore?.setMute(true)
            } else {
                j2meCore?.setMute(!manicGame.volume)
            }
        }
    }
    
    private func updateCheatCodes(firstInit: Bool = false) {
        guard !manicGame.safeMode else { return }
        guard !isWFCConnect else { return }
        guard !isHardcoreMode else { return }
        if manicGame.gameType == ._3ds {
            if manicGame.isCitra3DS {
                let identifier = manicGame.identifierFor3DS
                if identifier != 0 {
                    var cheatsTxt = ""
                    var enableCheats: [String] = []
                    for cheatCode in manicGame.gameCheats {
                        cheatsTxt += "[\(cheatCode.name)]\n\(cheatCode.code)\n"
                        if cheatCode.activate {
                            enableCheats.append("\(cheatCode.name)")
                        }
                    }
                    if !cheatsTxt.isEmpty  {
                        ThreeDS.setupCheats(identifier: identifier, cheatsTxt: cheatsTxt, enableCheats: enableCheats)
                        if enableCheats.count > 0 {
                            UIView.makeToast(message: R.string.localizable.gameCheatActivateSuccess(String.successMessage(from: enableCheats)))
                        }
                    }
                }
            } else if manicGame.isAzahar3DS {
                let identifier = manicGame.identifierFor3DS
                if identifier != 0 {
                    var cheatsTxt = ""
                    var enableCheats: [String] = []
                    for cheatCode in manicGame.gameCheats {
                        if cheatCode.activate {
                            cheatsTxt += "[\(cheatCode.name)]\n*manic_enabled\n\(cheatCode.code)\n\n"
                            enableCheats.append("\(cheatCode.name)")
                        }
                    }
                    let cheatFilePath = Constants.Path.ThreeDS.appendingPathComponent("cheats/\(String(format: "%016llX.txt", identifier))")
                    if cheatsTxt.isEmpty  {
                        try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: cheatFilePath))
                    } else {
                        try? cheatsTxt.write(toFile: cheatFilePath, atomically: true, encoding: .utf8)
                        UIView.makeToast(message: R.string.localizable.gameCheatActivateSuccess(String.successMessage(from: enableCheats)))
                    }
                }
            }
        } else if manicGame.gameType == .psp {
            if let gameCode = manicGame.gameCodeForPSP {
                var cheatsTxt = ""
                for cheatCode in manicGame.gameCheats {
                    if cheatCode.activate {
                        cheatsTxt += "_C1 \(cheatCode.name)\n\(cheatCode.code)\n"
                    }
                }
                let cheatFilePath = Constants.Path.PSPCheat(gameCode: gameCode)
                if firstInit {
                    LibretroCore.sharedInstance().updatePSPCheat(cheatsTxt, cheatFilePath: cheatFilePath, reloadGame: false)
                    lastPSPCheatCode = cheatsTxt
                } else if cheatsTxt != lastPSPCheatCode {
                    LibretroCore.sharedInstance().updatePSPCheat(cheatsTxt, cheatFilePath: cheatFilePath, reloadGame: true)
                    lastPSPCheatCode = cheatsTxt
                }
            }
        } else if manicGame.isLibretroType {
            DispatchQueue.main.asyncAfter(delay: manicGame.isPicodriveCore && firstInit ? 1 : 0) {
                if self.manicGame.gameType == .arcade, self.manicGame.defaultCore == 1, firstInit, !self.isHardcoreMode {
                    //FBNeo激活作弊码
                    if let configs = LibretroCore.sharedInstance().getConfigs(LibretroCore.Cores.FinalBurnNeo.name) {
                        var needToActivedKeys = [String]()
                        configs.enumerateLines { line, stop in
                            if line.hasPrefix("fbneo-cheat-") {
                                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                                if parts.count == 2 {
                                    let key = parts[0]
                                    let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                                    if value != "0 - Disabled" {
                                        needToActivedKeys.append(key)
                                    }
                                }
                            }
                        }
                        if needToActivedKeys.count > 0 {
                            LibretroCore.sharedInstance().updateFBNeoCheatCode(needToActivedKeys, enable: true)
                        }
                    }
                } else {
                    LibretroCore.sharedInstance().resetCheatCode()
                    for (index, cheatCode) in self.manicGame.gameCheats.enumerated() {
                        if cheatCode.activate {
                            // Convert newline separators to '+' (libretro standard for multi-line cheats)
                            let coreCode: String
                            if CheatType(cheatCode.type) == .actionReplay16, self.manicGame.isPicodriveCore, cheatCode.code.count > 6 {
                                //MD不支持0123456789格式的作弊码，需要转换成012345:6789格式
                                coreCode = cheatCode.code[...5] + ":" + cheatCode.code[6...]
                            } else {
                                coreCode = cheatCode.code.replacingOccurrences(of: "\n", with: "+")
                            }
                            LibretroCore.sharedInstance().addCheatCode(String(coreCode), index: UInt32(index), enable: true)
                        }
                    }
                }
            }
            
        } else if manicGame.isJGenesisCore {

        } else if manicGame.isJ2MECore {
            // J2ME does not support cheat codes
        }
    }

    private func updateFilter() {
        guard !manicGame.safeMode else { return }
        guard !manicGame.isCitra3DS, !manicGame.isJGenesisCore, !manicGame.isJ2MECore else { return }
        
        if manicGame.isLibretroType {
            //Libretro filterName是滤镜的路径
            var shaderPath: String?
            if manicGame.getExtraBool(key: ExtraKey.ignoreShaderConfig.rawValue) ?? false {
                shaderPath = nil
            } else {
                shaderPath = manicGame.libretroShaderPath
                if shaderPath == nil, let shaderConfig = ShaderConfig.getConfig() {
                    if let coreShaderPath = shaderConfig.coreConfigs[manicGame.gameType.localizedShortName] {
                        shaderPath = Constants.Path.Shaders.appendingPathComponent(coreShaderPath)
                    } else if let globalShaderPath = shaderConfig.globalConfig {
                        shaderPath = Constants.Path.Shaders.appendingPathComponent(globalShaderPath)
                    }
                }
            }
            LibretroCore.sharedInstance().setShader(shaderPath)
            updateDualScreenViews()
        }
    }
    
    //加载默认配置
    private func loadConfig() {
        //设置按钮隐藏
        if let forceFullSkin = manicGame.getExtraBool(key: ExtraKey.forceFullSkin.rawValue), forceFullSkin {
            manicGame.forceFullSkin = forceFullSkin
        }
        
        //加载存档
        if let saveState = loadSaveState {
            DispatchQueue.main.asyncAfter(delay: 1) { [weak self] in
                guard let self = self else { return }
                //模拟器如果没有加载好 直接加载存档可能会导致闪退
                if self.manicGame.isCitra3DS {
                    DispatchQueue.main.asyncAfter(delay: 5) {
                        self.quickLoadStateForCitra3DS(saveState)
                    }
                } else if self.manicGame.isLibretroType {
                    var delay = 0.0
                    if self.manicGame.gameType == .arcade || self.manicGame.isAzahar3DS {
                        delay = 4.0
                    }
                    DispatchQueue.main.asyncAfter(delay: delay) {
                        self.quickLoadStateForLibretro(saveState)
                    }
                }
            }
        }
        //设置触感
        updateHaptic()
        
        DispatchQueue.main.asyncAfter(delay: (manicGame.isCitra3DS || manicGame.gameType == .psp) ? 0 : 1) { [weak self] in
            //加载作弊码
            self?.updateCheatCodes(firstInit: true)
            //设置AirPlay
            self?.updateAirPlay()
        }
        if manicGame.gameType == .psp {
            let languages = ["Automatic", "English", "Japanese", "French", "Spanish", "German", "Italian", "Dutch", "Portuguese", "Russian", "Korean", "Chinese Traditional", "Chinese Simplified"]
            var backend = "auto"
            let backendType = manicGame.getExtraInt(key: ExtraKey.pspRenderer.rawValue) ?? 0
            if backendType == 1 {
                backend = "vulkan"
            } else if backendType == 2 {
                backend = "opengl"
            }
            let networkingConfig = PSPNetworkingConfig.getConfig()
            var networkingConfigs = [String: String]()
            LibretroCore.sharedInstance().setPSPCustomServerAddress(nil)
            LibretroCore.sharedInstance().setPSPCustomServerPort(nil)
            if networkingConfig.enable, networkingConfig.type == .local, networkingConfig.asHost {
                //本地网络 作为主机
                networkingConfigs += ["ppsspp_enable_wlan": "enabled",
                                      "ppsspp_enable_builtin_pro_ad_hoc_server": "enabled",
                                      "ppsspp_change_pro_ad_hoc_server_address": "IP address"]
                if let ipAddress = BonjourKit.shared.currentIPAddress, let hostResult = (ipAddress+":\(networkingConfig.asHostPort)").parseIPv4() {
                    for (index, ip) in hostResult.ips.enumerated() {
                        networkingConfigs["ppsspp_pro_ad_hoc_server_address" + (index < 9 ? "0\(index+1)" : "\(index+1)")] = "\(ip)"
                    }
                    networkingConfigs["ppsspp_port_offset"] = "\(hostResult.port)"
                    LibretroCore.sharedInstance().setPSPCustomServerPort("\(hostResult.port)")
                }
                LibretroCore.sharedInstance().setPSPCustomServerPort("\(networkingConfig.asHostPort)")
            } else if networkingConfig.enable, networkingConfig.type == .local, !networkingConfig.asHost, let ip = networkingConfig.connectedLocalIP {
                //本地网络 作为从机
                networkingConfigs += ["ppsspp_enable_wlan": "enabled",
                                      "ppsspp_enable_builtin_pro_ad_hoc_server": "disabled",
                                      "ppsspp_change_pro_ad_hoc_server_address": "IP address"]
                if let hostResult = ip.parseIPv4() {
                    for (index, ip) in hostResult.ips.enumerated() {
                        networkingConfigs["ppsspp_pro_ad_hoc_server_address" + (index < 9 ? "0\(index+1)" : "\(index+1)")] = "\(ip)"
                    }
                    networkingConfigs["ppsspp_port_offset"] = "\(hostResult.port)"
                    LibretroCore.sharedInstance().setPSPCustomServerPort("\(hostResult.port)")
                } else {
                    networkingConfigs["ppsspp_change_pro_ad_hoc_server_address"] = ip
                    LibretroCore.sharedInstance().setPSPCustomServerAddress(ip)
                }
            } else if networkingConfig.enable, networkingConfig.type == .online {
                //互联网络
                networkingConfigs += ["ppsspp_enable_wlan": "enabled",
                                      "ppsspp_enable_builtin_pro_ad_hoc_server": "disabled",
                                      "ppsspp_change_pro_ad_hoc_server_address": networkingConfig.connectedHost]
                if !["socom.cc", "psp.gameplayer.club", "myneighborsushicat.com"].contains(where: { $0 == networkingConfig.connectedHost }) {
                    LibretroCore.sharedInstance().setPSPCustomServerAddress(networkingConfig.connectedHost)
                }
            } else {
                //禁用网络
                networkingConfigs += ["ppsspp_enable_wlan": "disabled"]
            }
            
            //jit
            let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
            if enableJIT {
                setupUniversalScript(gameType: .psp)
            }
            let jitValue = ((manicGame.getExtraInt(key: ExtraKey.jitType.rawValue) ?? 0) == 0) ? "JIT" : "IR JIT"
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PPSSPP.name, configs: [
                "ppsspp_cheats": "enabled",
                "ppsspp_language": languages[manicGame.region],
                "ppsspp_backend": backend,
                "ppsspp_texture_replacement": (manicGame.getExtraBool(key: ExtraKey.pspTexture.rawValue) ?? false) ? "enabled" : "disabled",
                "ppsspp_cpu_core" : enableJIT ? jitValue : "Interpreter"
            ] + networkingConfigs, reload: false)
            updatePSPResolution(manicGame.resolution, reload: false)
        } else if manicGame.gameType == .nes || manicGame.gameType == .fds {
            updateNESPalette(manicGame.currentNesPalette, firstInit: true)
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Nestopia.name, key: "nestopia_aspect", value: "uncorrected", reload: false)
        } else if manicGame.gameType == .snes {
            let snesVRAM = manicGame.getExtraBool(key: ExtraKey.snesVRAM.rawValue) ?? false
            if manicGame.defaultCore == 0 {
                if snesVRAM {
                    LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.bsnes.name, key: "bsnes_ppu_no_vram_blocking", value: "ON", reload: false)
                }
            } else if manicGame.defaultCore == 1 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Snes9x.name, key: "snes9x_block_invalid_vram_access", value: snesVRAM ? "disabled" : "enabled", reload: false)
            }
        } else if manicGame.isPicodriveCore {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PicoDrive.name, key: "picodrive_input1", value: "6 button pad", reload: false)
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PicoDrive.name, key: "picodrive_input2", value: "6 button pad", reload: false)
        } else if manicGame.isClownMDEmuCore {
            let tvStandard = (manicGame.getExtraInt(key: ExtraKey.tvStandard.rawValue) ?? 0) == 0 ? "ntsc" : "pal"
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.ClownMDEmu.name, key: "clownmdemu_tv_standard", value: tvStandard, reload: false)
            if manicGame.gameType == .mcd {
                MCD.isJGenesisCore = false
            }
        } else if manicGame.gameType == .ss {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Yabause.name, key: "yabause_addon_cartridge", value: "4M_ram", reload: false)
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetleSaturn.name, key: "beetle_saturn_cart", value: "Extended RAM (4MB)", reload: false)
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetleSaturn.name, key: "beetle_saturn_region", value: Constants.Strings.SaturnConsoleLanguage[manicGame.region], reload: false)
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetleSaturn.name, key: "beetle_saturn_horizontal_overscan", value: "20", reload: false)
        } else if manicGame.gameType == .ds {
            if manicGame.defaultCore == 0 {
                //语言选项
                let dsLanguageOptions = ["auto", "ja", "en", "fr", "de", "it", "es"]
                let dsLanguageOption: String
                if manicGame.region >= 0,
                   manicGame.region < dsLanguageOptions.count {
                    dsLanguageOption = dsLanguageOptions[manicGame.region]
                } else {
                    dsLanguageOption = dsLanguageOptions.first!
                }
                
                //systemType
                let systemType: String
                if manicGame.isDSHomeMenuGame {
                    systemType = "ds"
                } else if manicGame.isDSiHomeMenuGame {
                    systemType = "dsi"
                } else if let mode = manicGame.getExtraString(key: ExtraKey.ndsSystemMode.rawValue), mode == "DSi" {
                    systemType = "dsi"
                } else {
                    systemType = "ds"
                }
                
                //麦克风
                let microphone = manicGame.getExtraBool(key: ExtraKey.microphone.rawValue) ?? false
                
                //jit
                let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
                if enableJIT {
                    setupUniversalScript(gameType: .ds)
                }
                
                //设置配置
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.melonDSDS.name,
                                                           configs: ["melonds_firmware_language": dsLanguageOption,
                                                                     "melonds_console_mode": systemType,
                                                                     "melonds_mic_input": microphone ? "microphone" : "silence",
                                                                     "melonds_mic_input_active": "always",
                                                                     "melonds_number_of_screen_layouts": "1",
                                                                     "melonds_screen_layout1": "custom",
                                                                     "melonds_show_cursor": "disabled",
                                                                     "melonds_jit_enable": enableJIT ? "enabled" : "disabled"],
                                                           reload: false)
                //wfc
                LibretroCore.sharedInstance().setNDSWFCDNS( WFC.currentDNS());
                DSEmulatorBridge.shared.isDeSmuMECore = false
            } else {
                //DeSmuME
                let languageOptions = Constants.Strings.DSConsoleLanguage
                var languageOption = languageOptions.first!
                if manicGame.region > 0 && manicGame.region < languageOptions.count {
                    languageOption = languageOptions[manicGame.region]
                }
                let scale = UInt32(manicGame.resolution == .undefine ? 1 : manicGame.resolution.rawValue)
                let option = "\(256*scale)x\(192*scale)"
                let microphone = manicGame.getExtraBool(key: ExtraKey.microphone.rawValue) ?? false
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.DeSmuME.name,
                                                           configs: ["desmume_pointer_type": "touch",
                                                                     "desmume_internal_resolution": option,
                                                                     "desmume_firmware_language": languageOption,
                                                                     "desmume_pointer_device_l": "emulated",
                                                                     "desmume_pointer_device_r": "emulated",
                                                                     "desmume_mic_mode": microphone ? "physical" : "pattern"],
                                                           reload: false)
                DSEmulatorBridge.shared.isDeSmuMECore = true
            }
        } else if manicGame.gameType == .gba {
            if manicGame.defaultCore == 1 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.VBAM.name, configs: [
                    "vbam_usebios": "enabled",
                    "vbam_gbHardware": "gba"
                ], reload: false)
            }
        } else if manicGame.gameType == .gbc {
            if manicGame.defaultCore == 0 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Gambatte.name, key: "gambatte_gbc_color_correction", value: "disabled", reload: false)
            } else if manicGame.defaultCore == 2 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.VBAM.name, configs: [
                    "vbam_usebios": "enabled",
                    "vbam_gbHardware": "gbc"
                ], reload: false)
            }
        } else if manicGame.gameType == .gb {
            if manicGame.defaultCore == 0 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Gambatte.name, configs: [
                    "gambatte_gb_colorization": manicGame.pallete == .None ? "disabled" : "internal",
                    "gambatte_gb_internal_palette": manicGame.pallete.optionForGambatte
                ], reload: false)
            } else if manicGame.defaultCore == 1 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.mGBA.name, configs: [
                    "mgba_gb_colors": manicGame.pallete.optionForMGBA], reload: false)
            } else if manicGame.defaultCore == 2 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.VBAM.name, configs: [
                    "vbam_usebios": "enabled",
                    "vbam_gbHardware": "gb",
                    "vbam_palettes": manicGame.pallete.optionForVBAM], reload: false)
            }
        } else if manicGame.gameType == .n64 {
            
            let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
            if enableJIT {
                setupUniversalScript(gameType: .n64)
            }
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Mupen64PlushNext.name, configs: [
                "mupen64plus-cpucore": (enableJIT ? "dynamic_recompiler" : "cached_interpreter"),
                "mupen64plus-rdp-plugin": ((manicGame.isN64ParaLLEl && !enableJIT) ? "parallel" : "gliden64"),
                "mupen64plus-pak1": manicGame.hasTransferPak ? "transfer" : "memory"
            ], reload: false)
            updateN64Resolution(manicGame.resolution, reload: false)
        } else if manicGame.gameType == .vb {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetleVB.name, key: "vb_color_mode", value: manicGame.pallete.paletteTitleForVB, reload: false)
        } else if manicGame.gameType == .pm {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PokeMini.name, key: "pokemini_palette", value: manicGame.pallete.paletteTitleForPM, reload: false)
        } else if manicGame.gameType == .ps1, manicGame.defaultCore == 0 {
            let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
            if enableJIT {
                setupUniversalScript(gameType: .ps1)
            }
            let isHardwareRenderer = manicGame.getExtraBool(key: ExtraKey.psxRenderer.rawValue) ?? true
            
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetlePSXHW.name,
                                                       configs: [
                                                        //video
                                                        "beetle_psx_hw_internal_resolution": manicGame.resolution.resolutionTitleForPS1,
                                                        "beetle_psx_hw_dither_mode": "disabled",
                                                        "beetle_psx_hw_msaa": "8x",
                                                        "beetle_psx_hw_mdec_yuv": "enabled",
                                                        "beetle_psx_hw_aspect_ratio": "4:3",
                                                        //memory card
                                                        "beetle_psx_hw_enable_memcard1": "disabled",
                                                        //pgxp
                                                        "beetle_psx_hw_pgxp_mode": "memory only",
                                                        "beetle_psx_hw_pgxp_nclip": "enabled",
                                                        "beetle_psx_hw_pgxp_texture": "enabled",
                                                        //hacks
                                                        "beetle_psx_hw_gte_overclock": "enabled",
                                                        "beetle_psx_hw_override_bios": manicGame.ps1OverrideBios,
                                                        //common
                                                        "beetle_psx_hw_renderer": isHardwareRenderer ? "hardware_vk" : "software",
                                                        //jit
                                                        "beetle_psx_hw_cpu_dynarec": enableJIT ? "execute" : "disabled",
                                                       ],
                                                       reload: false)
        } else if manicGame.gameType == .dc {
            if LibretroCore.jitAvailable(), manicGame.jit {
                setupUniversalScript(gameType: .dc)
            }
            updateDCResolution(manicGame.resolution, reload: false)
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Flycast.name,
                                                       configs: ["reicast_renderer": "Vulkan",
                                                                 "reicast_language" : Constants.Strings.DCConsoleLanguage[manicGame.region]],
                                                       reload: false)
        } else if manicGame.gameType == .arcade {
            if manicGame.defaultCore == 0 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.MAME.name, configs: ["mame_cheats_enable": "enabled"], reload: false)
                LibretroCore.sharedInstance().setLibretroLogMonitor(true)
            }
        } else if manicGame.gameType == ._3ds {
            ThreeDS.isAzaharCore = manicGame.isAzahar3DS
            if manicGame.isAzahar3DS {
                var enableJIT = false
                if LibretroCore.jitAvailable() {
                    if let value = LibretroCore.sharedInstance().coreConfigValue(LibretroCore.Cores.Azahar.name, key: "citra_use_cpu_jit"), value == "disabled" {
                        enableJIT = false
                    } else {
                        enableJIT = true
                        setupUniversalScript(gameType: ._3ds)
                    }
                }
                let enableLLE = (manicGame.isArticBaseHomeMenu || (manicGame.getExtraInt(key: ExtraKey.emulationAccuracy.rawValue) ?? 0 == 1)) ? true : false
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Azahar.name,
                                                           configs: [
                                                            "citra_layout_option": "custom",
                                                            "citra_touch_touchscreen": "enabled",
                                                            "citra_input_type": "frontend",
                                                            "citra_use_cpu_jit": enableJIT ? "enabled" : "disabled",
                                                            "citra_use_default_aes_key": manicGame.isAzaharArticBase || manicGame.isArticBaseHomeMenu || manicGame.is3DSHomeMenuGame ? "enabled" : "disabled",
                                                            "citra_required_online_lle_modules": enableLLE ? "enabled" : "disabled"
                                                           ],
                                                           reload: false)
                //Azahar核心每次启动都不进行加速，免得闪退
                Game.change { realm in
                    self.manicGame.speed = .one
                }
            }
        } else if manicGame.gameType == ._32x {
            S2X.isJGenesisCore = manicGame.defaultCore == 1
        } else if manicGame.gameType == .mcd {
            MCD.isJGenesisCore = manicGame.defaultCore == 1
        } else if manicGame.gameType == .a2600 {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Stella.name, configs: ["stella_crop_hoverscan": "enabled"], reload: false)
            self.update2600TvColor(isInit: true)
            self.update2600LeftDifficulty(isInit: true)
            self.update2600RightDifficulty(isInit: true)
            self.updateSkin()
        } else if manicGame.gameType == .a5200 {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Atari800.name, configs: ["atari800_system": "5200"], reload: false)
        } else if manicGame.gameType == .jaguar {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.VirtualJaguar.name,
                                                       configs: ["virtualjaguar_alt_inputs": "enabled",
                                                                 "virtualjaguar_bios": "enabled",
                                                                 "virtualjaguar_doom_res_hack": "enabled",
                                                                 "virtualjaguar_p1_retropad_analog_lu": "num_7",
                                                                 "virtualjaguar_p1_retropad_analog_ld": "num_8",
                                                                 "virtualjaguar_p1_retropad_analog_ll": "num_9",
                                                                 "virtualjaguar_p1_retropad_analog_lr": "star",
                                                                 "virtualjaguar_p1_retropad_analog_ru": "hash",
                                                                 "virtualjaguar_p2_retropad_analog_lu": "num_7",
                                                                 "irtualjaguar_p2_retropad_analog_ld": "num_8",
                                                                 "virtualjaguar_p2_retropad_analog_ll": "num_9",
                                                                 "virtualjaguar_p2_retropad_analog_lr": "star",
                                                                 "virtualjaguar_p2_retropad_analog_ru": "hash"
                                                                ],
                                                       reload: false)
        } else if manicGame.gameType == .doom {
            let scale = UInt32(manicGame.resolution == .undefine ? 1 : manicGame.resolution.rawValue)
            let option = "\(320*scale)x\(200*scale)"
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PrBoom.name,
                                                       configs: ["prboom-resolution": option,
                                                                 "prboom-rumble": "enabled"],
                                                       reload: false)
        } else if manicGame.gameType == .dos {
            //jit
            let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
            if enableJIT {
                setupUniversalScript(gameType: .dos)
            }
            if let content = manicGame.getStoreCoreConfigsString(enableJIT: enableJIT) {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.DOSBoxPure.name, content: content, reload: false)
            } else  {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.DOSBoxPure.name, configs: ["dosbox_pure_cpu_core": enableJIT ? "dynamic" : "normal"], reload: false)
            }
        }
        
        //配置静音模式
        if manicGame.isLibretroType {
            LibretroCore.sharedInstance().setRespectSilentMode(Settings.defalut.respectSilentMode)
        }
        if Settings.defalut.respectSilentMode {
            //监听静音键
            muteSwitchMonitor.startMonitoring { [weak self] isMute in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.updateAudio()
                }
            }
        }
        
        //Libretro配置
        if manicGame.isLibretroType {
            var enableLibretroLog = "false"
            var libretroLogLevel = "1"
#if DEBUG
            enableLibretroLog = "true"
            libretroLogLevel = "0"
#endif
            let enableMircophone = (manicGame.gameType == .ds && (manicGame.getExtraBool(key: ExtraKey.microphone.rawValue) ?? false)) || manicGame.isAzahar3DS
            LibretroCore.sharedInstance().updateLibretroConfigs([
                "fastforward_frameskip": "false",
                "log_verbosity": enableLibretroLog,
                "libretro_log_level": libretroLogLevel,
                "camera_allow": "true",
                "camera_driver": "avfoundation",
                "microphone_enable": enableMircophone ? "true" : "false",
                "microphone_driver": "coreaudio",
                "audio_latency": "200",
                "input_auto_game_focus": "1"
            ])
            if manicGame.isN64ParaLLEl {
                LibretroCore.sharedInstance().setReloadDelay(1)
            } else {
                LibretroCore.sharedInstance().setReloadDelay(0)
            }
            
            //RetroAchievements配置
            if manicGame.supportRetroAchievements, let user = AchievementsUser.getUser() {
                let enableAchievements = manicGame.enableAchievements
                let hardcore = manicGame.enableHarcore
                isHardcoreMode = hardcore
                LibretroCore.sharedInstance().updateLibretroConfigs(["cheevos_enable": enableAchievements ? "true" : "false",
                                                                     "cheevos_hardcore_mode_enable": hardcore ? "true" : "false",
                                                                     "cheevos_token": user.token,
                                                                     "cheevos_username": user.username])
                if enableAchievements {
                    setupLeaderboardView()
                    setupAchievementProgressView()
                    setupAchievementChallengeView()
                    if manicGame.gameType == .psp {
                        LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PPSSPP.name, configs: ["ppsspp_cheats": "disabled"], reload: false)
                    }
                }
            } else {
                LibretroCore.sharedInstance().updateLibretroConfig("cheevos_enable", value: "false")
            }
            
            //修改存档位置
            if manicGame.gameType == .gb {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.GBSavePath.libretroPath)
            } else if manicGame.gameType == .gbc {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.GBCSavePath.libretroPath)
            } else if manicGame.gameType == .gba {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.GBASavePath.libretroPath)
            } else if manicGame.gameType == .snes, manicGame.defaultCore == 0 {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.bsnes.libretroPath)
            } else if manicGame.gameType == .ds {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.DSSavePath.libretroPath)
            } else if manicGame.gameType == .doom {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.PrBoom.libretroPath)
            } else if manicGame.gameType == .dos {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.DOSBoxPure.libretroPath)
            } else {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.LibretroSavePath.libretroPath)
            }
            
            //配置Rumble
            LibretroCore.sharedInstance().setEnableRumble(Settings.defalut.getExtraBool(key: ExtraKey.rumble.rawValue) ?? false)
            
            //配置System的位置
            if manicGame.gameType == .dc {
                LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: Constants.Path.Flycast)
            } else if manicGame.gameType == .dos {
                LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: Constants.Path.DOSBoxPureSystem.libretroPath)
            } else {
                LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: Constants.Path.System.libretroPath)
            }
        }
        
        //配置控制器死区，
        ExternalGameControllerManager.shared.deadZone = (Settings.defalut.getExtraDouble(key: ExtraKey.deadZone.rawValue) ?? 0).float
        if !manicGame.gameType.supportAnalogInput {
            //对于没有摇杆输入的平台，如果使用外置控制器的摇杆来映射按键的时候，会有很多不可预见的问题
            let settingDeadzone = Settings.defalut.getExtraDouble(key: ExtraKey.deadZone.rawValue) ?? 0
            if settingDeadzone < 0.4 {
                //强制设置0.4以上可以避免摇杆细微变动输入带来的错误
                ExternalGameControllerManager.shared.deadZone = 0.4
            }
        }
        
        skinSwitchBindDatas["reverseScreens"] = manicGame.swapScreen
        skinSwitchBindDatas["volume"] = manicGame.volume
        skinSwitchBindDatas["toggleControlls"] = manicGame.forceFullSkin
        
        //配置屏幕的拉伸模式
        updateScreenScaling(manicGame.screenScaling)
    }
    
    private func loadMinimalConfig() {
        if manicGame.gameType == .psp {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PPSSPP.name, configs: [
                "ppsspp_cheats": "enabled",
                "ppsspp_language": "Automatic",
                "ppsspp_backend": "auto",
                "ppsspp_texture_replacement": "disabled",
                "ppsspp_enable_wlan": "disabled",
                "ppsspp_internal_resolution": "480x272",
                "ppsspp_cpu_core": "Interpreter"
            ], reload: false)
        } else if manicGame.gameType == .nes || manicGame.gameType == .fds {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Nestopia.name, configs: [
                "nestopia_aspect": "uncorrected",
                "nestopia_palette": "cxa2025as"
            ], reload: false)
        } else if manicGame.gameType == .snes {
            if manicGame.defaultCore == 0 {
                if manicGame.getExtraBool(key: ExtraKey.snesVRAM.rawValue) ?? false {
                    LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.bsnes.name, key: "bsnes_ppu_no_vram_blocking", value: "OFF", reload: false)
                }
            } else if manicGame.defaultCore == 1 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Snes9x.name, key: "snes9x_block_invalid_vram_access", value: "enabled", reload: false)
            }
        } else if manicGame.isPicodriveCore {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PicoDrive.name, key: "picodrive_input1", value: "6 button pad", reload: false)
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PicoDrive.name, key: "picodrive_input2", value: "6 button pad", reload: false)
        } else if manicGame.isClownMDEmuCore {
            let tvStandard = (manicGame.getExtraInt(key: ExtraKey.tvStandard.rawValue) ?? 0) == 0 ? "ntsc" : "pal"
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.ClownMDEmu.name, key: "clownmdemu_tv_standard", value: tvStandard, reload: false)
            if manicGame.gameType == .mcd {
                MCD.isJGenesisCore = false
            }
        } else if manicGame.gameType == .ss {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Yabause.name, key: "yabause_addon_cartridge", value: "4M_ram", reload: false)
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetleSaturn.name, key: "beetle_saturn_cart", value: "Extended RAM (4MB)", reload: false)
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetleSaturn.name, key: "beetle_saturn_region", value: Constants.Strings.SaturnConsoleLanguage[manicGame.region], reload: false)
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetleSaturn.name, key: "beetle_saturn_horizontal_overscan", value: "20", reload: false)
        } else if manicGame.gameType == .ds {
            if manicGame.defaultCore == 0 {
                //systemType
                let systemType: String
                if manicGame.isDSHomeMenuGame {
                    systemType = "ds"
                } else if manicGame.isDSiHomeMenuGame {
                    systemType = "dsi"
                } else {
                    systemType = "ds"
                }
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.melonDSDS.name,
                                                           configs: ["melonds_firmware_language": "auto",
                                                                     "melonds_console_mode": systemType,
                                                                     "melonds_mic_input": "silence",
                                                                     "melonds_mic_input_active": "always",
                                                                     "melonds_number_of_screen_layouts": "1",
                                                                     "melonds_screen_layout1": "custom",
                                                                     "melonds_show_cursor": "disabled",
                                                                     "melonds_jit_enable": "disabled"],
                                                           reload: false)
                //wfc
                LibretroCore.sharedInstance().setNDSWFCDNS( WFC.currentDNS());
                DSEmulatorBridge.shared.isDeSmuMECore = false
            } else {
                //DeSmuME
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.DeSmuME.name,
                                                           configs: ["desmume_pointer_type": "touch",
                                                                     "desmume_internal_resolution": "256x192",
                                                                     "desmume_firmware_language": "Auto",
                                                                     "desmume_pointer_device_l": "emulated",
                                                                     "desmume_pointer_device_r": "emulated",
                                                                     "desmume_mic_mode": "physical"],
                                                           reload: false)
                DSEmulatorBridge.shared.isDeSmuMECore = true
            }
        } else if manicGame.gameType == .gba {
            if manicGame.defaultCore == 1 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.VBAM.name, configs: [
                    "vbam_usebios": "enabled",
                    "vbam_gbHardware": "gba"
                ], reload: false)
            }
        } else if manicGame.gameType == .gbc {
            if manicGame.defaultCore == 0 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Gambatte.name, key: "gambatte_gbc_color_correction", value: "disabled", reload: false)
            } else if manicGame.defaultCore == 2 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.VBAM.name, configs: [
                    "vbam_usebios": "enabled",
                    "vbam_gbHardware": "gbc"
                ], reload: false)
            }
        } else if manicGame.gameType == .gb {
            if manicGame.defaultCore == 0 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Gambatte.name, configs: [
                    "gambatte_gb_colorization": "disabled",
                    "gambatte_gb_internal_palette": "GB - DMG"
                ], reload: false)
            } else if manicGame.defaultCore == 1 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.mGBA.name, configs: [
                    "mgba_gb_colors": "Grayscale"], reload: false)
            } else if manicGame.defaultCore == 2 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.VBAM.name, configs: [
                    "vbam_usebios": "enabled",
                    "vbam_gbHardware": "gb",
                    "vbam_palettes": "black and white"], reload: false)
            }
        } else if manicGame.gameType == .n64 {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Mupen64PlushNext.name, configs:
                                                        ["mupen64plus-cpucore": "cached_interpreter",
                                                         "mupen64plus-43screensize": "640x480",
                                                         "mupen64plus-rdp-plugin": "gliden64",
                                                         "mupen64plus-pak1": "memory"],
                                                       reload: false)
        } else if manicGame.gameType == .vb {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetleVB.name, key: "vb_color_mode", value: manicGame.pallete.paletteTitleForVB, reload: false)
        } else if manicGame.gameType == .pm {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PokeMini.name, key: "pokemini_palette", value: "black & red", reload: false)
        } else if manicGame.gameType == .ps1 && manicGame.defaultCore == 0 {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.BeetlePSXHW.name,
                                                       configs: [
                                                        //video
                                                        "beetle_psx_hw_internal_resolution": "1x",
                                                        "beetle_psx_hw_dither_mode": "disabled",
                                                        "beetle_psx_hw_msaa": "8x",
                                                        "beetle_psx_hw_mdec_yuv": "enabled",
                                                        "beetle_psx_hw_aspect_ratio": "4:3",
                                                        //memory card
                                                        "beetle_psx_hw_enable_memcard1": "disabled",
                                                        //pgxp
                                                        "beetle_psx_hw_pgxp_mode": "memory only",
                                                        "beetle_psx_hw_pgxp_nclip": "enabled",
                                                        "beetle_psx_hw_pgxp_texture": "enabled",
                                                        //hacks
                                                        "beetle_psx_hw_gte_overclock": "enabled",
                                                        "beetle_psx_hw_override_bios": "disabled",
                                                        //common
                                                        "beetle_psx_hw_renderer": "hardware_vk",
                                                        //jit
                                                        "beetle_psx_hw_cpu_dynarec": "disabled",
                                                       ],
                                                       reload: false)
        } else if manicGame.gameType == .dc {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Flycast.name,
                                                       configs: ["reicast_renderer": "Vulkan",
                                                                 "reicast_internal_resolution": "640x480",
                                                                 "reicast_language" : "Default"],
                                                       reload: false)
        } else if manicGame.gameType == .arcade {
            if manicGame.defaultCore == 0 {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.MAME.name, configs: ["mame_cheats_enable": "enabled"], reload: false)
                LibretroCore.sharedInstance().setLibretroLogMonitor(true)
            }
        } else if manicGame.gameType == ._3ds {
            ThreeDS.isAzaharCore = manicGame.isAzahar3DS
            if manicGame.isAzahar3DS {
                var enableJIT = false
                if LibretroCore.jitAvailable() {
                    if let value = LibretroCore.sharedInstance().coreConfigValue(LibretroCore.Cores.Azahar.name, key: "citra_use_cpu_jit"), value == "disabled" {
                        enableJIT = false
                    } else {
                        enableJIT = true
                        setupUniversalScript(gameType: ._3ds)
                    }
                }
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Azahar.name,
                                                           configs: [
                                                            "citra_layout_option": "custom",
                                                            "citra_touch_touchscreen": "enabled",
                                                            "citra_input_type": "frontend",
                                                            "citra_use_cpu_jit": enableJIT ? "enabled" : "disabled",
                                                            "citra_use_default_aes_key": manicGame.isAzaharArticBase || manicGame.isArticBaseHomeMenu || manicGame.is3DSHomeMenuGame ? "enabled" : "disabled",
                                                            "citra_required_online_lle_modules": manicGame.isArticBaseHomeMenu ? "enabled" : "disabled"
                                                           ],
                                                           reload: false)
                //Azahar核心每次启动都不进行加速，免得闪退
                Game.change { realm in
                    self.manicGame.speed = .one
                }
            }
        } else if manicGame.gameType == ._32x {
            S2X.isJGenesisCore = manicGame.defaultCore == 1
        } else if manicGame.gameType == .mcd {
            MCD.isJGenesisCore = manicGame.defaultCore == 1
        } else if manicGame.gameType == .a2600 {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Stella.name, configs: ["stella_crop_hoverscan": "enabled"], reload: false)
            self.update2600TvColor(isInit: true)
            self.update2600LeftDifficulty(isInit: true)
            self.update2600RightDifficulty(isInit: true)
            self.updateSkin()
        } else if manicGame.gameType == .a5200 {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Atari800.name, configs: ["atari800_system": "5200"], reload: false)
        } else if manicGame.gameType == .jaguar {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.VirtualJaguar.name,
                                                       configs: ["virtualjaguar_alt_inputs": "enabled",
                                                                 "virtualjaguar_bios": "enabled",
                                                                 "virtualjaguar_doom_res_hack": "enabled",
                                                                 "virtualjaguar_p1_retropad_analog_lu": "num_7",
                                                                 "virtualjaguar_p1_retropad_analog_ld": "num_8",
                                                                 "virtualjaguar_p1_retropad_analog_ll": "num_9",
                                                                 "virtualjaguar_p1_retropad_analog_lr": "star",
                                                                 "virtualjaguar_p1_retropad_analog_ru": "hash",
                                                                 "virtualjaguar_p2_retropad_analog_lu": "num_7",
                                                                 "irtualjaguar_p2_retropad_analog_ld": "num_8",
                                                                 "virtualjaguar_p2_retropad_analog_ll": "num_9",
                                                                 "virtualjaguar_p2_retropad_analog_lr": "star",
                                                                 "virtualjaguar_p2_retropad_analog_ru": "hash"
                                                                ],
                                                       reload: false)
        } else if manicGame.gameType == .doom  {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PrBoom.name,
                                                       configs: ["prboom-resolution": "320x200",
                                                                 "prboom-rumble": "enabled"],
                                                       reload: false)
        } else if manicGame.gameType == .dos {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.DOSBoxPure.name, content: nil, reload: false)
        }
        
        //配置静音模式
        if manicGame.isLibretroType {
            LibretroCore.sharedInstance().setRespectSilentMode(Settings.defalut.respectSilentMode)
        }
        if Settings.defalut.respectSilentMode {
            //监听静音键
            muteSwitchMonitor.startMonitoring { [weak self] isMute in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.updateAudio()
                }
            }
        }
        
        //Libretro配置
        if manicGame.isLibretroType {
            var enableLibretroLog = "false"
            var libretroLogLevel = "1"
#if DEBUG
            enableLibretroLog = "true"
            libretroLogLevel = "0"
#endif
            LibretroCore.sharedInstance().updateLibretroConfigs([
                "fastforward_frameskip": "false",
                "log_verbosity": enableLibretroLog,
                "libretro_log_level": libretroLogLevel,
                "camera_allow": "true",
                "camera_driver": "avfoundation",
                "microphone_enable": "false",
                "microphone_driver": "coreaudio",
                "audio_latency": "200"
            ])
            if manicGame.isN64ParaLLEl {
                LibretroCore.sharedInstance().setReloadDelay(1)
            } else {
                LibretroCore.sharedInstance().setReloadDelay(0)
            }
            
            //RetroAchievements配置
            LibretroCore.sharedInstance().updateLibretroConfig("cheevos_enable", value: "false")
            
            //修改存档位置
            if manicGame.gameType == .gb {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.GBSavePath.libretroPath)
            } else if manicGame.gameType == .gbc {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.GBCSavePath.libretroPath)
            } else if manicGame.gameType == .gba {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.GBASavePath.libretroPath)
            } else if manicGame.gameType == .snes, manicGame.defaultCore == 0 {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.bsnes.libretroPath)
            } else if manicGame.gameType == .ds {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.DSSavePath.libretroPath)
            } else if manicGame.gameType == .doom {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.PrBoom.libretroPath)
            } else if manicGame.gameType == .dos {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.DOSBoxPure.libretroPath)
            } else {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: Constants.Path.LibretroSavePath.libretroPath)
            }
            
            //配置Rumble
            LibretroCore.sharedInstance().setEnableRumble(false)
            
            //配置System的位置
            if manicGame.gameType == .dc {
                LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: Constants.Path.Flycast)
            } else if manicGame.gameType == .dos {
                LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: Constants.Path.DOSBoxPureSystem.libretroPath)
            } else {
                LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: Constants.Path.System.libretroPath)
            }
        }
        
        //配置控制器死区，
        ExternalGameControllerManager.shared.deadZone = (Settings.defalut.getExtraDouble(key: ExtraKey.deadZone.rawValue) ?? 0).float
        if !manicGame.gameType.supportAnalogInput {
            //对于没有摇杆输入的平台，如果使用外置控制器的摇杆来映射按键的时候，会有很多不可预见的问题
            let settingDeadzone = Settings.defalut.getExtraDouble(key: ExtraKey.deadZone.rawValue) ?? 0
            if settingDeadzone < 0.4 {
                //强制设置0.4以上可以避免摇杆细微变动输入带来的错误
                ExternalGameControllerManager.shared.deadZone = 0.4
            }
        }
        
        skinSwitchBindDatas["reverseScreens"] = manicGame.swapScreen
        skinSwitchBindDatas["volume"] = manicGame.volume
        skinSwitchBindDatas["toggleControlls"] = manicGame.forceFullSkin
        
        //配置屏幕的拉伸模式
        updateScreenScaling(manicGame.screenScaling)
    }
    
    //更新皮肤
    private func updateSkin() {
        
        func setPreferredSkin() {
            showSkinButtons()
            isFullScreen = false
            var initGameType: GameType?
            var supportGameTypes: [GameType]?
            if manicGame.gameType.reuseSkinGameType.count > 1 {
                initGameType = manicGame.gameType
                supportGameTypes = manicGame.gameType.reuseSkinGameType
            }
            if UIDevice.isLandscape {
                //设置横屏皮肤
                if let skin = manicGame.landscapeSkin, var controllerSkin = ControllerSkin(fileURL: skin.fileURL, initGameType: initGameType, supportGameTypes: supportGameTypes) {
                    if enableSwapScreen() {
                        controllerSkin.isSwapScreen = manicGame.swapScreen
                    }
                    controllerView.controllerSkin = controllerSkin
                } else if let skin = SkinConfig.preferredLandscapeSkin(gameType: manicGame.gameType), var controllerSkin = ControllerSkin(fileURL: skin.fileURL, initGameType: initGameType, supportGameTypes: supportGameTypes) {
                    if enableSwapScreen() {
                        controllerSkin.isSwapScreen = manicGame.swapScreen
                    }
                    controllerView.controllerSkin = controllerSkin
                }
            } else {
                //设置竖屏皮肤
                if let skin = manicGame.portraitSkin, var controllerSkin = ControllerSkin(fileURL: skin.fileURL, initGameType: initGameType, supportGameTypes: supportGameTypes) {
                    if enableSwapScreen() {
                        controllerSkin.isSwapScreen = manicGame.swapScreen
                    }
                    controllerView.controllerSkin = controllerSkin
                } else if let skin = SkinConfig.preferredPortraitSkin(gameType: manicGame.gameType), var controllerSkin = ControllerSkin(fileURL: skin.fileURL, initGameType: initGameType, supportGameTypes: supportGameTypes) {
                    if enableSwapScreen() {
                        controllerSkin.isSwapScreen = manicGame.swapScreen
                    }
                    controllerView.controllerSkin = controllerSkin
                }
            }
        }
        
        if manicGame.forceFullSkin {
            //设置全屏皮肤
            let realm = Database.realm
            if let coreName = emulatorCore?.deltaCore.name,
               let skin = realm.objects(Skin.self).where({ $0.fileName == "\(coreName)_FLEX.manicskin" }).first,
               let skinUrl = skin.skinData?.filePath,
               var controllerSkin = ControllerSkin(fileURL: skinUrl) {
                if enableSwapScreen() {
                    controllerSkin.isSwapScreen = manicGame.swapScreen
                }
                isFullScreen = true
                controllerView.controllerSkin = controllerSkin
                hideSkinButtons()
            } else {
                setPreferredSkin()
            }
        } else {
            setPreferredSkin()
        }

        //Set Skin Sound Effects
        controllerView.enableSkinSoundEffects = Settings.defalut.getExtraBool(key: ExtraKey.skinSoundEffects.rawValue) ?? true
        
        //更新背景
        updateBackground()

        //设置皮肤控制器的玩家角色
        controllerView.playerIndex = PlayViewController.skinControllerPlayerIndex
        //更新Libretro的画面
        updateLibretroViews()
        //尝试加载滤镜
        updateFilter()
        //尝试添加屏幕按钮
        updateFunctionButton()
        if manicGame.gameType == .ds || (manicGame.gameType == ._3ds && !manicGame.isAzaharArticBase) || (manicGame.gameType == .dos && UIDevice.isPad) {
            updateFunctionButtonContainer()
        }
        //更新3DS画面视图
        updateCitra3DSViews()
        //更新JGenesis画面
        updateJGenesisView()
        //更新J2ME画面
        updateJ2MEView()

        if controllerView.isIncludeSwitch {
            controllerView.updateSwitchState(skinSwitchBindDatas)
        }
    }
    
    /// 按照配置开始强制旋转屏幕
    private func startOrientation() {
        if #available(iOS 16.0, *) {
            self.setNeedsUpdateOfSupportedInterfaceOrientations()
            if let scene = ApplicationSceneDelegate.applicationScene {
                if manicGame.orientation == .landscape {
                    scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS.init(interfaceOrientations: .landscapeRight))
                } else if manicGame.orientation == .portrait {
                    scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS.init(interfaceOrientations: .portrait))
                }
            }
        } else {
            if manicGame.orientation == .landscape {
                UIDevice.current.setValue(NSNumber(integerLiteral: UIInterfaceOrientation.landscapeRight.rawValue), forKey: "orientation")
            } else if manicGame.orientation == .portrait {
                UIDevice.current.setValue(NSNumber(integerLiteral: UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
            }
        }
        setOrientationConfig()
    }
    
    
    /// 设置游戏页面的旋转配置
    
    private func setOrientationConfig() {
        AppDelegate.orientation = {
            if manicGame.orientation == .landscape {
                return .landscape
            } else if manicGame.orientation == .portrait {
                return .portrait
            } else {
                return Constants.Config.DefaultOrientation
            }
        }()
    }
    
    /// 恢复默认旋转配置
    private func resetOrientationConfig() {
        AppDelegate.orientation = Constants.Config.DefaultOrientation
    }
    
    ///固定旋转配置
    private func fixedOrientationConfig() {
        switch UIDevice.currentOrientation {
        case .unknown: break
        case .portrait:
            AppDelegate.orientation = .portrait
        case .portraitUpsideDown:
            AppDelegate.orientation = .portraitUpsideDown
        case .landscapeLeft:
            AppDelegate.orientation = .landscapeLeft
        case .landscapeRight:
            AppDelegate.orientation = .landscapeRight
        @unknown default:
            break
        }
    }
    
    /// 更新震感
    private func updateHaptic() {
        switch manicGame.haptic {
        case .off:
            controllerView.isButtonHapticFeedbackEnabled = false
            controllerView.isThumbstickHapticFeedbackEnabled = false
        default:
            controllerView.isButtonHapticFeedbackEnabled = true
            controllerView.isThumbstickHapticFeedbackEnabled = true
        }
        
        switch manicGame.haptic {
        case .soft:
            controllerView.hapticFeedbackStyle = .soft
        case .light:
            controllerView.hapticFeedbackStyle = .light
        case .medium:
            controllerView.hapticFeedbackStyle = .medium
        case .heavy:
            controllerView.hapticFeedbackStyle = .heavy
        case .rigid:
            controllerView.hapticFeedbackStyle = .rigid
        default:
            break
        }
        
        triggerProView?.hapticType = manicGame.haptic
    }
    
    /// 更新AirPlay
    private func updateAirPlay() {
        if PurchaseManager.isMember, Settings.defalut.airPlay, ExternalSceneDelegate.isAirPlaying {
            //执行全屏投屏
            if let airPlayViewController = ExternalSceneDelegate.airPlayViewController, let gameMetalView {
                gameMetalView.removeFromSuperview()
                var dimensions = emulatorCore?.deltaCore.videoFormat.dimensions ?? CGSize(width: 480, height: 360)
                if manicGame.gameType == .ds || manicGame.gameType == ._3ds {
                    dimensions.height = dimensions.height/2
                }
                if manicGame.isCitra3DS {
                    dimensions = dimensions.applying(CGAffineTransform(scaleX: UIScreen.main.scale, y: UIScreen.main.scale))
                }
                aiplayScaledDimensions = airPlayViewController.addLibretroView(gameMetalView, dimensions: dimensions, scalingType: Settings.defalut.airPlayScaling)
                updateDualScreenViews()
                updateNDSCursor()
            }
        } else {
            //不执行全屏投屏
            if let _ = ExternalSceneDelegate.airPlayViewController, let gameMetalView {
                gameMetalView.removeFromSuperview()
                view.insertSubview(gameMetalView, belowSubview: controllerView)
                updateLibretroViews()
                updateCitra3DSViews()
                updateNDSCursor()
            }
        }
    }
    
    private func updateFunctionButton() {
        functionButtonContainer.subviews.forEach { $0.removeFromSuperview() }
        if (manicGame.gameType == ._3ds && UIDevice.isPad) || manicGame.isAzaharArticBase {
            return
        }
        if let controllerSkin = controllerView.controllerSkin {
            if let skin = Database.realm.objects(Skin.self).first(where: { $0.identifier == controllerSkin.identifier }) {
                if skin.skinType == .default {
                    //当前使用的是默认皮肤 则添加功能按钮
                    let settings = Settings.defalut
                    let functionButtonCount = settings.displayGamesFunctionCount
                    guard functionButtonCount > 0 else { return }
                    for (index, settingTypeValue) in settings.gameFunctionList.prefix(functionButtonCount).enumerated() {
                        if let settingType = GameSetting.ItemType(rawValue: settingTypeValue) {
                            var gameSetting = GameSetting(type: settingType)
                            gameSetting.volumeOn = manicGame.volume
                            gameSetting.hapticType = manicGame.haptic
                            let button = UIImageView(image: gameSetting.image.withRenderingMode(.alwaysTemplate).applySymbolConfig(color: Constants.Color.LabelTertiary))
                            if manicGame.gameType == .dos {
                                button.tintColor = Constants.Color.LabelTertiary.forceStyle(.dark)
                            } else {
                                button.tintColor = Constants.Color.LabelTertiary
                            }
                            button.contentMode = .center
                            button.isUserInteractionEnabled = true
                            button.enableInteractive = true
                            functionButtonContainer.addSubview(button)
                            button.snp.makeConstraints { make in
                                if manicGame.gameType == .ds || manicGame.gameType == ._3ds {
                                    if UIDevice.isPhone {
                                        make.width.equalTo(31)
                                        make.height.equalToSuperview().dividedBy(2)
                                        if index == 0 {
                                            make.leading.equalToSuperview()
                                            make.top.equalToSuperview()
                                        } else if index == 1 {
                                            make.leading.equalToSuperview()
                                            make.top.equalTo(functionButtonContainer.subviews[index - 1].snp.bottom)
                                        } else if index == 2 {
                                            make.trailing.equalToSuperview()
                                            make.top.equalToSuperview()
                                        } else if index == 3 {
                                            make.trailing.equalToSuperview()
                                            make.top.equalTo(functionButtonContainer.subviews[index - 1].snp.bottom)
                                        }
                                    } else {
                                        make.width.equalTo(50)
                                        make.top.bottom.equalToSuperview()
                                        if index == 0 {
                                            make.leading.equalToSuperview()
                                        } else if index == 1 {
                                            make.leading.equalTo(functionButtonContainer.subviews[index-1].snp.trailing)
                                        } else if index == 2 {
                                            make.trailing.equalToSuperview().inset(50)
                                        } else if index == 3 {
                                            make.trailing.equalToSuperview()
                                        }
                                    }
                                } else {
                                    if index == 0 {
                                        make.leading.equalToSuperview()
                                    } else {
                                        make.leading.equalTo(functionButtonContainer.subviews[index-1].snp.trailing)
                                    }
                                    make.top.bottom.equalToSuperview()
                                    if index == functionButtonCount-1 && functionButtonCount == Constants.Numbers.GameFunctionButtonCount {
                                        make.trailing.equalToSuperview()
                                    }
                                    make.width.equalToSuperview().dividedBy(Constants.Numbers.GameFunctionButtonCount)
                                }
                            }
                            button.addTapGesture { [weak self, weak button] gesture in
                                guard let self = self else { return }
                                var newGameSetting = GameSetting(type: settingType)
                                switch settingType {
                                case .volume:
                                    newGameSetting.volumeOn = !self.manicGame.volume
                                    button?.image = newGameSetting.image.applySymbolConfig(color: Constants.Color.LabelTertiary)
                                case .fastForward:
                                    newGameSetting.fastForwardSpeed = self.manicGame.speed.next
                                case .haptic:
                                    newGameSetting.hapticType = self.manicGame.haptic.next
                                case .orientation:
                                    newGameSetting.orientation = self.manicGame.orientation.next
                                case .resolution:
                                    newGameSetting.resolution = self.manicGame.resolution.next
                                case .palette:
                                    if self.manicGame.gameType == .nes || self.manicGame.gameType == .fds {
                                        newGameSetting.nesPalette = self.manicGame.nextNesPalette
                                    } else {
                                        newGameSetting.palette = self.manicGame.pallete.next
                                    }
                                case .toggleFullscreen:
                                    newGameSetting.isFullScreen = !self.manicGame.forceFullSkin
                                case .swapDisk:
                                    if self.manicGame.gameType == .fds {
                                        newGameSetting.currentDiskIndex = 0
                                    } else {
                                        if let diskInfo = manicGame.diskInfo {
                                            let currentIndex = diskInfo.currentDiskIndex
                                            let totalCount = diskInfo.diskCount
                                            let nextIndex = currentIndex + 1 < totalCount ? currentIndex + 1 : 0
                                            newGameSetting.currentDiskIndex = UInt(nextIndex)
                                        }
                                    }
                                case .airPlayScaling:
                                    newGameSetting.airPlayScaling = Settings.defalut.airPlayScaling.next
                                case .airPlayLayout:
                                    newGameSetting.airPlayLayout = Settings.defalut.airPlayLayout.next
                                default:
                                    break
                                }
                                self.handleMenuGameSetting(newGameSetting, nil)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func updateFunctionButtonContainer() {
        if (manicGame.gameType == .ds || (UIDevice.isPhone && manicGame.gameType == ._3ds)) &&  UIDevice.isPhone {
            functionButtonContainer.snp.remakeConstraints { make in
                if gameViews.count > 1 {
                    //iPhone ds布局比较特殊
                    if UIDevice.isLandscape {
                        make.leading.equalTo(gameViews[0]).inset(-33)
                        make.trailing.equalTo(gameViews[1]).inset(-33)
                        make.top.equalToSuperview()
                    } else {
                        make.leading.trailing.equalTo(gameViews[1]).inset(-33)
                        make.top.equalTo(gameViews[1])
                    }
                    
                    if manicGame.gameType == ._3ds {
                        if let displayType = controllerView.controllerSkinTraits?.displayType, displayType == .standard {
                            //小屏幕
                            make.height.equalTo(80)
                        } else {
                            //大屏幕
                            make.height.equalTo(96)
                        }
                    } else {
                        if let displayType = controllerView.controllerSkinTraits?.displayType, displayType == .standard, !UIDevice.isLandscape {
                            make.height.equalTo(87)
                        } else {
                            make.height.equalTo(113)
                        }
                    }
                }
            }
        } else if manicGame.gameType == .dos, UIDevice.isPad {
            functionButtonContainer.snp.updateConstraints { make in
                make.top.equalTo(gameView.snp.bottom).offset(UIDevice.isLandscape ? 30 : 40)
            }
        }
    }
    
    private func updateCitra3DSViews() {
        guard manicGame.isCitra3DS else { return }
        guard let controllerSkin = controllerView.controllerSkin as? ControllerSkin else { return }
        guard let frames = controllerSkin.getFrames() else { return }
        guard let touchGameViewFrame = frames.touchGameViewFrame else { return }
        
        Log.debug("更新3DS视图 frames:\(frames)")
        if let gameMetalView {
            if gameMetalView.superview == view {
                gameMetalView.snp.remakeConstraints { make in
                    make.edges.equalTo(controllerView)
                }
            }
            updateDualScreenViews()
        } else {
            citraCore = self.emulatorCore?.deltaCore.emulatorBridge as? ThreeDSEmulatorBridge
            gameMetalView = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
            guard let gameMetalView else { return }
            self.view.insertSubview(gameMetalView, belowSubview: controllerView)
            gameMetalView.snp.makeConstraints { make in
                make.edges.equalTo(controllerView)
            }
            let jitEnable = LibretroCore.jitAvailable() ? manicGame.jit : false
            if jitEnable {
                setupUniversalScript(gameType: ._3ds)
            }
            citraCore?.start(withGameURL: manicGame.romUrl,
                               metalView: gameMetalView as! MTKView,
                               metalViewFrame: frames.skinFrame,
                               topRect: frames.mainGameViewFrame,
                               bottomRect: touchGameViewFrame,
                               mute: !manicGame.volume,
                               resolution: manicGame.resolution,
                               jit: jitEnable,
                               accurateShaders: manicGame.accurateShaders,
                               language: manicGame.region-1,
                               renderRightEye: manicGame.renderRightEye)
            DispatchQueue.main.asyncAfter(delay: 3.25) { [weak self] in
                guard let self else { return }
                self.updateFastforward(speed: self.manicGame.speed)
                self.updateAirPlay()
            }
            citraCore?.openKeyboardAction { hintText, keyboardType, maxTextSize in
                ThreeDSKeyboardView.showForCitra(hintText: hintText, keyboardType: keyboardType, maxTextSize: maxTextSize)
            }
        }
    }
    
    private func updateLibretroViews() {
        guard manicGame.isLibretroType else { return }
        
        if manicGame.gameType == .dos {
            controllerView.allowTapThroughIfButtonNotHit = true
            controllerView.allowKeyboardEvents = false
            if let skin = controllerView.controllerSkin,
               skin.identifier == Constants.Strings.DOSKeyboardSkinID {
                controllerView.activateButtonInputInterception = { input in
                    if input.stringValue == "menu" || input.stringValue == "useJoypadSkin" {
                        return false
                    }
                    Log.debug("[LibretroKeyboardCode] input: >>>\(input.stringValue)<<<<")
                    if let keyCode = LibretroKeyboardCode.createCode(withLabel: input.stringValue) {
                        LibretroCore.sharedInstance().pressKeyboard(keyCode)
                    }
                    return true
                }
                controllerView.deactivateButtonInputInterception = { input in
                    if input.stringValue == "menu" || input.stringValue == "useJoypadSkin" {
                        return false
                    }
                    if let keyCode = LibretroKeyboardCode.createCode(withLabel: input.stringValue) {
                        LibretroCore.sharedInstance().releaseKeyboard(keyCode)
                    }
                    return true
                }
            } else {
                controllerView.activateButtonInputInterception = nil
                controllerView.deactivateButtonInputInterception = nil
            }
        }
        
        if let gameMetalView {
            if gameMetalView.superview == view {
                gameMetalView.snp.remakeConstraints { make in
                    if self.manicGame.gameType == .ds || self.manicGame.isAzahar3DS {
                        if let dualScreenViewFrame = getDualScreenViewFrame() {
                            make.left.equalTo(dualScreenViewFrame.minX)
                            make.top.equalTo(dualScreenViewFrame.minY)
                            make.width.equalTo(dualScreenViewFrame.width)
                            make.height.equalTo(dualScreenViewFrame.height)
                        } else {
                            make.edges.equalTo(controllerView)
                        }
                    } else {
                        make.edges.equalTo(gameView)
                    }
                }
            }
            updateDualScreenViews()
        } else {
            DispatchQueue.main.asyncAfter(delay: 0.35) { [weak self] in
                guard let self = self else { return }
                
                //为了适配PSKM GB GBC GBA的存档路径进行特别处理
                var customSaveDir: String? = nil
                var customSaveExtension: String? = nil
                if manicGame.gameType == .gb {
                    customSaveDir = Constants.Path.GBSavePath
                    customSaveExtension = ".sav"
                } else if manicGame.gameType == .gbc {
                    customSaveDir = Constants.Path.GBCSavePath
                    customSaveExtension = ".sav"
                } else if manicGame.gameType == .gba {
                    customSaveDir = Constants.Path.GBASavePath
                    customSaveExtension = ".sav"
                } else if manicGame.gameType == .snes, manicGame.defaultCore == 0 {
                    customSaveDir = Constants.Path.bsnes
                } else if manicGame.gameType == .ds {
                    customSaveDir = Constants.Path.DSSavePath
                } else if manicGame.gameType == .doom {
                    customSaveDir = Constants.Path.PrBoom
                } else if manicGame.isAzahar3DS {
                    customSaveDir = Constants.Path.ThreeDS
                }
                
                let vc = LibretroCore.sharedInstance().start(withCustomSaveDir: customSaveDir)
                gameMetalView = vc.view
                guard let gameMetalView else { return }
                self.view.insertSubview(gameMetalView, belowSubview: controllerView)
                gameMetalView.snp.makeConstraints { make in
                    if self.manicGame.gameType == .ds || self.manicGame.isAzahar3DS {
                        if let dualScreenViewFrame = self.getDualScreenViewFrame() {
                            make.left.equalTo(dualScreenViewFrame.minX)
                            make.top.equalTo(dualScreenViewFrame.minY)
                            make.width.equalTo(dualScreenViewFrame.width)
                            make.height.equalTo(dualScreenViewFrame.height)
                        } else {
                            make.edges.equalTo(self.controllerView)
                        }
                    } else {
                        make.edges.equalTo(self.gameView)
                    }
                }
                gameMetalView.isHidden = true
                if let corePath = self.manicGame.libretroCorePath {
                    var compltion: (([AnyHashable: Any]?)-> Void)? = nil
                    if manicGame.isAzahar3DS {
                        //注册azahar的键盘
                        compltion = { _ in
                            LibretroCore.sharedInstance().registerAzaharKeyboard { config in
                                ThreeDSKeyboardView.showForAzahar(config: config,
                                                                  tapAction: { buttonType, text in
                                    LibretroCore.sharedInstance().inputAzaharKeyboard(text, buttonType: buttonType)
                                })
                            }
                        }
                    }
                    self.updateDualScreenViews()
                    LibretroCore.sharedInstance().setCustomSaveExtension(customSaveExtension)
                    if self.manicGame.isNDSHomeMenuGame || self.manicGame.isDSiHomeMenuGame || self.manicGame.isDOSHomeMenuGame {
                        LibretroCore.sharedInstance().loadWithoutContent(corePath)
                    } else {
                        LibretroCore.sharedInstance().loadGame(manicGame.isAzaharArticBase ? manicGame.romUrl.string : manicGame.romUrl.path, corePath: corePath, completion: compltion)
                    }
                    
                    DispatchQueue.main.asyncAfter(delay: 0.5) { [weak self] in
                        guard let self = self else { return }
                        self.gameMetalView?.isHidden = false
                        self.updateFilter()
                        self.updateAirPlay()
                        if self.manicGame.gameType == .ps1 && manicGame.defaultCore == 0 {
                            self.updateAnalogMode(toastAllow: false, toggle: false)
                        } else if manicGame.gameType == .ds {
                            if manicGame.defaultCore == 0 {
                                LibretroCore.sharedInstance().startWFCStatusMonitor()
                            }
                        }
                        DispatchQueue.main.asyncAfter(delay: 2.5) {
                            self.updateFastforward(speed: self.manicGame.speed)
                        }
                    }
                }
            }
        }
    }
    
    private func updateJGenesisView() {
        guard manicGame.isJGenesisCore else { return }
        if let gameMetalView {
            if gameMetalView.superview == view {
                gameMetalView.snp.remakeConstraints { make in
                    make.edges.equalTo(gameView)
                }
            }
        } else {
            let jGenesisView = JGenesisView()
            gameMetalView = jGenesisView
            guard let gameMetalView else { return }
            self.view.insertSubview(gameMetalView, belowSubview: controllerView)
            gameMetalView.snp.makeConstraints { make in
                make.edges.equalTo(self.gameView)
            }
            gameMetalView.isHidden = true
            
            jGenesisView.didFinishedInit = { [weak self] in
                guard let self = self else { return }
                if self.manicGame.gameType == ._32x {
                    self.jGenesisCore?.openFile(filePath: self.manicGame.romUrl.path)
                    DispatchQueue.main.asyncAfter(delay: 2) {
                        self.updateFastforward(speed: self.manicGame.speed)
                        self.updateAudio()
                        if let loadSaveState = self.loadSaveState {
                            self.quickLoadStateForJGenesis(loadSaveState)
                        }
                    }
                } else if self.manicGame.gameType == .mcd {
                    DispatchQueue.main.asyncAfter(delay: 3) {
                        let biosPaths = Constants.BIOS.MegaCDBios.map({ Constants.Path.System.appendingPathComponent($0.fileName) })
                        self.jGenesisCore?.openSegaCdFile(filePath: self.manicGame.romUrl.path, americasBiosPath: biosPaths[1], japanBiosPath: biosPaths[2], europeBiosPath: biosPaths[0])
                        DispatchQueue.main.asyncAfter(delay: 5) {
                            self.updateFastforward(speed: self.manicGame.speed)
                            self.updateAudio()
                            if let loadSaveState = self.loadSaveState {
                                self.quickLoadStateForJGenesis(loadSaveState)
                            }
                        }
                    }
                }
                
                self.gameMetalView?.isHidden = false
                self.updateAirPlay()
            }
        }
    }

    private func updateJ2MEView() {
        guard manicGame.isJ2MECore else { return }
        if let gameMetalView {
            if gameMetalView.superview == view {
                gameMetalView.snp.remakeConstraints { make in
                    make.edges.equalTo(gameView)
                }
            }
        } else {
            //允许点击穿透
            controllerView.allowTapThroughIfButtonNotHit = true
            
            let j2meView = J2MEView(coreType: manicGame.defaultCore == 0 ? .j2meJS : .freej2meWeb)
            gameMetalView = j2meView
            guard let gameMetalView else { return }
            self.view.insertSubview(gameMetalView, belowSubview: controllerView)
            gameMetalView.snp.makeConstraints { make in
                make.edges.equalTo(self.gameView)
            }
            gameMetalView.isHidden = true
            
            j2meView.onExit = { [weak self] in
                guard let self = self else { return }
                self.handleMenuGameSetting(GameSetting(type: .quit), nil)
            }
            
            var loadSuccess = false
            let group = DispatchGroup()
            group.enter()
            j2meView.didFinishedInit = { [weak self] in
                loadSuccess = true
                group.leave()
                UIView.hideLoading()
                guard let self = self else { return }
                self.j2meCore?.openJar(filePath: self.manicGame.romUrl.path,
                                       savePath: self.manicGame.gameSaveUrl.path,
                                       screenSize: self.manicGame.j2meScreenSize,
                                       rotation: self.manicGame.j2meScreenRotation) { [weak self] success in
                    guard let self = self else { return }
                    if success {
                        self.updateFastforward(speed: self.manicGame.speed)
                        self.updateAudio()
                        self.updateScreenScaling(self.manicGame.screenScaling)
                    }
                }

                self.gameMetalView?.isHidden = false
                self.updateAirPlay()
            }
            
            if manicGame.defaultCore == 1 {
                //freej2me的CheerpJ可能加载很长时间
                DispatchQueue.main.asyncAfter(delay: 3) {
                    if !loadSuccess {
                        UIView.makeLoadingToast(message: R.string.localizable.loadingCheerpJ())
                        UIView.makeLoading(timeout: 30)
                        DispatchQueue.global().async {
                            let result = group.wait(timeout: .now() + 30)
                            DispatchQueue.main.async {
                                if result == .success {
                                    UIView.hideLoadingToast()
                                    UIView.hideLoading()
                                } else {
                                    UIView.hideLoadingToast()
                                    UIView.makeAlert(detail: R.string.localizable.cheerpJLoadFailed(),
                                                     detailAlignment: .left,
                                                     cancelTitle: R.string.localizable.confirmTitle())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func updateDualScreenViews() {
        guard manicGame.gameType == .ds || manicGame.gameType == ._3ds else { return }
        
        if ExternalSceneDelegate.isAirPlaying {
            let layoutType = Settings.defalut.airPlayLayout
            var layout: String = ""
            let ratio = 0.3
            let scale = manicGame.filterName == nil ? UIScreen.main.scale : 1.25
            let dimensions = aiplayScaledDimensions.applying(CGAffineTransform(scaleX: scale, y: scale))
            let bufferSize = "\(dimensions.width),\(dimensions.height)"
            let bottomRatio = 0.75 //NDS和3DS的bottom屏幕都是3:4
            switch layoutType {
            case .embeddedTopLeft, .embeddedTopRight, .embeddedBottomLeft, .embeddedBottomRight:
                let bottomWidth = dimensions.width*ratio
                let bottomHeight = bottomWidth*bottomRatio
                var bottomOrigin = "\(0),\(0)"
                if layoutType == .embeddedTopRight {
                    bottomOrigin = "\(dimensions.width*(1-ratio)),\(0)"
                } else if layoutType == .embeddedBottomLeft {
                    bottomOrigin = "\(0),\(dimensions.height-bottomHeight)"
                } else if layoutType == .embeddedBottomRight {
                    bottomOrigin = "\(dimensions.width*(1-ratio)),\(dimensions.height-bottomHeight)"
                }
                layout = "\(0),\(0),\(dimensions.width),\(dimensions.height),\(bottomOrigin),\(bottomWidth),\(bottomHeight),\(bufferSize)"
            case .sideBySide:
                let topWidth = dimensions.width/2
                let topHeight = topWidth*dimensions.height/dimensions.width
                let topY = (dimensions.height - topHeight)/2
                let bottomWidth = topWidth
                let bottomHeight = bottomWidth*bottomRatio
                let bottomY = (dimensions.height - bottomHeight)/2
                layout = "\(0),\(topY),\(topWidth),\(topHeight),\(dimensions.width/2),\(bottomY),\(bottomWidth),\(bottomHeight),\(bufferSize)"
            case .stacked:
                let topHeight = dimensions.height/2
                let topWidth = topHeight*dimensions.width/dimensions.height
                let topX = (dimensions.width - topWidth)/2
                let bottomHeight = topHeight
                let bottomWidth = bottomHeight/bottomRatio
                let bottomX = (dimensions.width - bottomWidth)/2
                layout = "\(topX),\(0),\(topWidth),\(topHeight),\(bottomX),\(dimensions.height/2),\(bottomWidth),\(bottomHeight),\(bufferSize)"
            case .largeSmallTopLeft, .largeSmallTopRight, .largeSmallBottomLeft, .largeSmallBottomRight:
                var topX = dimensions.width*ratio
                if layoutType == .largeSmallTopRight || layoutType == .largeSmallBottomRight {
                    topX = 0
                }
                let topWidth = dimensions.width*(1-ratio)
                let topHeight = topWidth*dimensions.height/dimensions.width
                let bottomWidth = dimensions.width*ratio
                let bottomHeight = bottomWidth*bottomRatio
                let topY = (dimensions.height - topHeight)/2
                var bottomOrigin = CGPoint(x: 0, y: topY)
                if layoutType == .largeSmallTopRight {
                    bottomOrigin = CGPoint(x: dimensions.width*(1-ratio), y: topY)
                } else if layoutType == .largeSmallBottomLeft {
                    bottomOrigin = CGPoint(x: 0, y: topY + topHeight - bottomHeight)
                } else if layoutType == .largeSmallBottomRight {
                    bottomOrigin = CGPoint(x: dimensions.width*(1-ratio), y: topY + topHeight - bottomHeight)
                }
                layout = "\(topX),\(topY),\(topWidth),\(topHeight),\(bottomOrigin.x),\(bottomOrigin.y),\(bottomWidth),\(bottomHeight),\(bufferSize)"
            case .singleScreen:
                layout = "\(0),\(0),\(dimensions.width),\(dimensions.height),\(0),\(0),\(0),\(0),\(bufferSize)"
                
            }
            
            if manicGame.swapScreen {
                let components = layout.components(separatedBy: ",")
                if components.count == 10 {
                    let topScreen = (components[0...3])
                    let bottom = (components[4...7])
                    let buffer = (components[8...9])
                    layout = (bottom + topScreen + buffer).reduce("", { $0 + ($0.isEmpty ? "" : ",") + $1 })
                }
            }
            
            Log.debug(">>>>>传入核心的Layout:\(layout)")
            if manicGame.gameType == .ds {
                LibretroCore.sharedInstance().setNDSCustomLayout(layout)
            } else if manicGame.isAzahar3DS {
                LibretroCore.sharedInstance().set3DSCustomLayout(layout)
            } else if manicGame.isCitra3DS {
                let frames = layout.components(separatedBy: ",").compactMap({ $0.cgFloat() })
                if frames.count == 10 {
                    let topRect = CGRect(x: frames[0], y: frames[1], width: frames[2], height: frames[3]).applying(CGAffineTransform(scaleX: 1/scale, y: 1/scale))
                    let bottomRect = CGRect(x: frames[4], y: frames[5], width: frames[6], height: frames[7]).applying(CGAffineTransform(scaleX: 1/scale, y: 1/scale))
                    citraCore?.updateViews(topRect: topRect,
                                             bottomRect: bottomRect, isAirPlay: true)
                }
            }
            let params = (manicGame.swapScreen ? (layout.components(separatedBy: ",")[0...3]) : (layout.components(separatedBy: ",")[4...7])).compactMap({ $0.cgFloat() })
            if params.count == 4 {
                if manicGame.gameType == .ds {
                    DSEmulatorBridge.shared.touchInputFrame = CGRect(x: params[0], y: params[1], width: params[2], height: params[3]).applying(CGAffineTransform(scaleX: 1/scale, y: 1/scale))
                } else if manicGame.isAzahar3DS {
                    AzaharEmulatorBridge.shared.touchInputFrame = CGRect(x: params[0], y: params[1], width: params[2], height: params[3]).applying(CGAffineTransform(scaleX: 1/scale, y: 1/scale))
                }
                
            }
        } else {
            //屏幕需要跟随gameViews的更新而更新
            guard let controllerSkin = controllerView.controllerSkin as? ControllerSkin else { return }
            guard let frames = controllerSkin.getFrames() else { return }
            guard let libretroViewFrame = getDualScreenViewFrame() else { return }
            
            if manicGame.isCitra3DS {
                guard let touchGameViewFrame = frames.touchGameViewFrame else { return }
                citraCore?.updateViews(topRect: frames.mainGameViewFrame,
                                         bottomRect: touchGameViewFrame)
                return
            }
            
            let skinframe = frames.skinFrame
            var topFrame = frames.mainGameViewFrame
            var layout = ""
            let absX = abs(skinframe.minX - libretroViewFrame.minX)
            let absY = abs(skinframe.minY - libretroViewFrame.minY)
            let scale = manicGame.filterName == nil ? UIScreen.main.scale : 1.25
            let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
            var touchGameViewFrame = CGRect.zero
            if var bottomFrame = frames.touchGameViewFrame {
                //双屏幕
                topFrame = CGRect(x: max(topFrame.minX - absX, 0), y: max(topFrame.minY - absY, 0), width: topFrame.width, height: topFrame.height)
                bottomFrame = CGRect(x: max(bottomFrame.minX - absX, 0), y: max(bottomFrame.minY - absY, 0), width: bottomFrame.width, height: bottomFrame.height)
                touchGameViewFrame = bottomFrame
                
                let bufferframe = libretroViewFrame.applying(scaleTransform)
                let scaleTopFrame = topFrame.applying(scaleTransform)
                let scaleBottomFrame = bottomFrame.applying(scaleTransform)
                
                if manicGame.filterName != nil, manicGame.gameType == ._3ds, UIDevice.isLandscape {
                    //fix 3DS Scale
                    let fixScale = UIScreen.main.scale-scale
                    layout = "\(scaleTopFrame.minX),\(scaleTopFrame.minY),\(scaleTopFrame.width),\(scaleTopFrame.height*fixScale),\(scaleBottomFrame.minX),\(scaleBottomFrame.minY),\(scaleBottomFrame.width),\(scaleBottomFrame.height*fixScale),\(bufferframe.width),\(bufferframe.height*fixScale)"
                } else {
                    layout = "\(scaleTopFrame.minX),\(scaleTopFrame.minY),\(scaleTopFrame.width),\(scaleTopFrame.height),\(scaleBottomFrame.minX),\(scaleBottomFrame.minY),\(scaleBottomFrame.width),\(scaleBottomFrame.height),\(bufferframe.width),\(bufferframe.height)"
                }
                Log.debug("更新双屏的layout libretroViewFrame:\(libretroViewFrame) top:\(topFrame) bottom:\(bottomFrame) layout: \(layout)")
            } else {
                //单屏幕
                let bufferframe = libretroViewFrame.applying(scaleTransform)
                
                layout = "\(max(bufferframe.minX, 0)),\(max(bufferframe.minY, 0)),\(bufferframe.width),\(bufferframe.height),\(0),\(0),\(0),\(0),\(bufferframe.width),\(bufferframe.height)"
                Log.debug("更新单屏的layout libretroViewFrame:\(libretroViewFrame) layout: \(layout)")
            }
            
            if manicGame.gameType == .ds {
                LibretroCore.sharedInstance().setNDSCustomLayout(layout)
                DSEmulatorBridge.shared.touchInputFrame = touchGameViewFrame
            } else if manicGame.isAzahar3DS {
                LibretroCore.sharedInstance().set3DSCustomLayout(layout)
                AzaharEmulatorBridge.shared.touchInputFrame = touchGameViewFrame
            }
        }
    }
    
    private func snapShotFor3DS(topOnly: Bool = false) -> [UIImage]? {
        guard let controllerSkin = controllerView.controllerSkin as? ControllerSkin else { return nil }
        guard let frames = controllerSkin.getFrames() else { return nil }
        guard let touchGameViewFrame = frames.touchGameViewFrame else { return nil }
        let skinFrame = frames.skinFrame
        let mainGameViewFrame = frames.mainGameViewFrame
        let topRect = CGRectMake(skinFrame.minX + mainGameViewFrame.minX, skinFrame.minY + mainGameViewFrame.minY, mainGameViewFrame.width, mainGameViewFrame.height)
        let bottomRect = CGRectMake(skinFrame.minX + touchGameViewFrame.minX, skinFrame.minY + touchGameViewFrame.minY, touchGameViewFrame.width, touchGameViewFrame.height)
        let screenImage = view.asImage()
        if topOnly {
            return [screenImage.cropped(to: topRect)]
        } else {
            return [screenImage.cropped(to: topRect), screenImage.cropped(to: bottomRect)]
        }
    }
    
    private func snapShotForDualScreen(topOnly: Bool = false, source: UIImage) -> [UIImage]? {
        guard let controllerSkin = controllerView.controllerSkin as? ControllerSkin else { return nil }
        guard let frames = controllerSkin.getFrames() else { return nil }
        guard let libretroViewFrame = getDualScreenViewFrame() else { return nil }
        
        var screenImage = source
        if screenImage.scale != UIScreen.main.scale, let imageData = screenImage.pngData(), let scaleImage = UIImage(data: imageData, scale: UIScreen.main.scale) {
            screenImage = scaleImage
        }
        
        let skinframe = frames.skinFrame
        let absX = abs(skinframe.minX - libretroViewFrame.minX)
        let absY = abs(skinframe.minY - libretroViewFrame.minY)
        var topFrame = frames.mainGameViewFrame
        topFrame = CGRect(x: max(topFrame.minX - absX, 0), y: max(topFrame.minY - absY, 0), width: topFrame.width, height: topFrame.height)
        
        let topImage = screenImage.cropped(to: topFrame.adjustSize(add: -1))
        if !topOnly, var bottomFrame = frames.touchGameViewFrame {
            bottomFrame = CGRect(x: max(bottomFrame.minX - absX, 0), y: max(bottomFrame.minY - absY, 0), width: bottomFrame.width, height: bottomFrame.height)
            let bottomImage = screenImage.cropped(to: bottomFrame.adjustSize(add: -1))
            return [topImage, bottomImage]
        }
        return [topImage]
    }
    
    private func hideSkinButtons() {
        guard isFullScreen else { return }
        //隐藏按键 除了menu和flex
        for view in controllerView.contentView.subviews {
            if let buttonsDynamicEffectView = view as? ButtonsDynamicEffectView {
                for dynamicEffectView in  buttonsDynamicEffectView.itemViews {
                    let item = dynamicEffectView.item
                    if item.kind == .button, let input = item.inputs.allInputs.first, (input.stringValue == "menu" || input.stringValue == "flex") {
                        if input.stringValue == "menu" {
                            flexMenuButton = dynamicEffectView
                        } else if input.stringValue == "flex" {
                            flexButton = dynamicEffectView
                        }
                    }
                    dynamicEffectView.isHidden = true
                }
            } else if String(describing: type(of: view)) == "TouchInputView" {
                //触摸视图不隐藏
            } else {
                view.isHidden = true
            }
        }
    }
    
    private func showSkinButtons() {
        guard isFullScreen else { return }
        
        for view in controllerView.contentView.subviews {
            if let buttonsDynamicEffectView = view as? ButtonsDynamicEffectView {
                for dynamicEffectView in  buttonsDynamicEffectView.itemViews {
                    dynamicEffectView.isHidden = false
                    dynamicEffectView.alpha = 1
                }
            } else if String(describing: type(of: view)) == "InputDebugView" {
                //debug view不显示
            } else {
                view.isHidden = false
            }
        }
    }
    
    private func showFlexButtonsTemporarily() {
        guard let flexMenuButton, let flexButton, isFullScreen else { return }
        if flexMenuButton.isHidden {
            flexMenuButton.alpha = 0
            flexMenuButton.isHidden = false
            
        }
        if flexButton.isHidden {
            flexButton.alpha = 0
            flexButton.isHidden = false
        }
        UIView.springAnimate(animations: {
            flexMenuButton.alpha = 1
            flexButton.alpha = 1
        })
        DispatchQueue.main.asyncAfter(delay: 5, execute: {
            UIView.springAnimate(animations: {
                flexMenuButton.alpha = 0
                flexButton.alpha = 0
            }, completion: { _ in
                flexMenuButton.isHidden = true
                flexButton.isHidden = true
            })
        })
    }
    
    private func enableSwapScreen() -> Bool {
        if manicGame.gameType == .ds || manicGame.gameType == ._3ds {
            return true
        }
        return false
    }
    
    private func updateN64Resolution(_ resolution: GameSetting.Resolution, reload: Bool) {
        if manicGame.isN64ParaLLEl {
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Mupen64PlushNext.name, key: "mupen64plus-parallel-rdp-upscaling", value: resolution.resolutionTitleForN64ParaLLEl, reload: reload)
        } else {
            let options = ["640x480", "960x720", "1280x960", "1440x1080", "1600x1200", "1920x1440", "2240x1680", "2560x1920", "2880x2160", "3520x2640"]
            var option = "640x480"
            if resolution != .undefine {
                option = options[resolution.rawValue - 1]
            }
            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Mupen64PlushNext.name, key: "mupen64plus-43screensize", value: option, reload: reload)
        }
    }
    
    private func updateDCResolution(_ resolution: GameSetting.Resolution, reload: Bool) {
        let options = ["640x480", "1280x960", "1920x1440", "2560x1920", "3200x2400", "3840x2880", "4480x3360", "5120x3840", "5760x4320", "6400x4800"]
        var option = "640x480"
        if resolution != .undefine {
            option = options[resolution.rawValue - 1]
        }
        LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Flycast.name, key: "reicast_internal_resolution", value: option, reload: reload)
    }
    
    private func updatePSPResolution(_ resolution: GameSetting.Resolution, reload: Bool) {
        let scale = UInt32(resolution == .undefine ? 1 : resolution.rawValue)
        let option = "\(480*scale)x\(272*scale)"
        LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.PPSSPP.name, key: "ppsspp_internal_resolution", value: option, reload: reload)
    }
    
    private func updateAnalogMode(toastAllow: Bool, toggle: Bool) {
        guard manicGame.gameType == .ps1 else { return }
        if manicGame.defaultCore == 0 {
            var deviceType = Constants.Strings.PSXController
            if var isAnalog = manicGame.getExtra(key: ExtraKey.isAnalog.rawValue) as? Bool {
                isAnalog = toggle ? !isAnalog : isAnalog
                LibretroCore.sharedInstance().setPSXAnalog(isAnalog)
                if toggle {
                    manicGame.updateExtra(key: ExtraKey.isAnalog.rawValue, value: isAnalog)
                }
                if isAnalog {
                    deviceType = Constants.Strings.PSXDualShock
                }
                skinSwitchBindDatas["toggleAnalog"] = isAnalog
                Log.debug("读取数据库 使用\(deviceType)")
            } else {
                //默认使用DualShock
                LibretroCore.sharedInstance().setPSXAnalog(true)
                manicGame.updateExtra(key: ExtraKey.isAnalog.rawValue, value: true)
                skinSwitchBindDatas["toggleAnalog"] = true
                Log.debug("加载默认值 使用\(Constants.Strings.PSXDualShock)")
            }
            if toastAllow {
                UIView.makeToast(message: R.string.localizable.analogModeChange(deviceType))
            }
        } else {
            LibretroCore.sharedInstance().press(.L1, playerIndex: 0)
            LibretroCore.sharedInstance().press(.R1, playerIndex: 0)
            LibretroCore.sharedInstance().press(.select, playerIndex: 0)
            DispatchQueue.main.asyncAfter(delay: 0.1) { [weak self] in
                guard let self else { return }
                LibretroCore.sharedInstance().release(.L1, playerIndex: 0)
                LibretroCore.sharedInstance().release(.R1, playerIndex: 0)
                LibretroCore.sharedInstance().release(.select, playerIndex: 0)
                if self.pscxReArmedDeviceType == Constants.Strings.PSXController {
                    self.pscxReArmedDeviceType = Constants.Strings.PSXDualShock
                } else {
                    self.pscxReArmedDeviceType = Constants.Strings.PSXController
                }
                UIView.makeToast(message: R.string.localizable.analogModeChange(self.pscxReArmedDeviceType))
            }
        }
    }
    
    private func showRetroAchievements(badgeUrl: String? = nil, title: String, message: String? = nil, hideIcon: Bool = false, onTaped: (()->Void)? = nil) {
        var scale = 1.0
        if ExternalSceneDelegate.isAirPlaying, let window = ExternalSceneDelegate.externalWindow {
            //将成就信息展示到电视上
            AppContext.setExternalWindow(window, isActive: true)
            scale = 2
        }
        Toast(.init(duration: 3.5)) { [weak self] toast in
            guard let self else { return }
            toast.config.cardEdgeInsets = .zero
            toast.config.cardCornerRadius = Constants.Size.CornerRadiusMid
            toast.config.cardMaxWidth = (Constants.Size.WindowSize.minDimension - 2*Constants.Size.ContentSpaceHuge) * scale
            toast.config.cardMaxHeight = 64 * scale
            toast.contentView.layerBorderColor = Constants.Color.Border
            toast.contentView.layerBorderWidth = 1
            toast.config.dynamicBackgroundColor = Constants.Color.BackgroundPrimary.withAlphaComponent(0.95)
            toast.onViewDidDisappear { vc in
                DispatchQueue.main.asyncAfter(delay: 1, execute: {
                    AppContext.setExternalWindow(nil, isActive: false)
                })
            }
            
            let contentView = UIView()
            
            let imageView = UIImageView()
            let imageSize = 40 * scale
            imageView.contentMode = .scaleAspectFill
            if let badgeUrl {
                imageView.kf.setImage(with: URL(string: badgeUrl), placeholder: UIImage.placeHolder(preferenceSize: .init(imageSize)))
            } else if let coverUrl = manicGame.onlineCoverUrl, manicGame.gameCover == nil {
                imageView.kf.setImage(with: URL(string: coverUrl), placeholder: UIImage.placeHolder(preferenceSize: .init(imageSize)))
            } else if let data = manicGame.gameCover?.storedData() {
                imageView.image = UIImage.tryDataImageOrPlaceholder(tryData: data, preferenceSize: .init(imageSize))
            }
            
            contentView.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.size.equalTo(imageSize)
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMin*scale)
            }
            
            let label = UILabel()
            label.numberOfLines = message == nil ? 2 : 3
            let titleFont = scale == 1.0 ? Constants.Font.title(size: .s, weight: .regular) : UIFont.systemFont(ofSize: 30)
            let matt = NSMutableAttributedString(string: title, attributes: [.font: titleFont, .foregroundColor: Constants.Color.LabelPrimary])
            if let message {
                let messageFont = scale == 1.0 ? Constants.Font.body(size: .s) : UIFont.systemFont(ofSize: 20)
                matt.append(NSAttributedString(string: "\n\(message)", attributes: [.font: messageFont, .foregroundColor: Constants.Color.LabelSecondary]))
            }
            let style = NSMutableParagraphStyle()
            style.lineSpacing = (Constants.Size.ContentSpaceUltraTiny/2)*scale
            label.attributedText = matt.applying(attributes: [.paragraphStyle: style])
            contentView.addSubview(label)
            label.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(imageView.snp.trailing).offset(Constants.Size.ContentSpaceTiny*scale)
                if hideIcon {
                    make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid*scale)
                }
                make.top.greaterThanOrEqualTo(Constants.Size.ContentSpaceTiny*scale)
                make.bottom.lessThanOrEqualTo(-Constants.Size.ContentSpaceTiny*scale)
            }
            
            if !hideIcon {
                let image: UIImage?
                image = R.image.trophy_gold()
                //                image = R.image.trophy_silver()
                //                image = R.image.trophy_bronze()
                let icon = UIImageView(image: image)
                icon.contentMode = .scaleAspectFit
                contentView.addSubview(icon)
                icon.snp.makeConstraints { make in
                    make.size.equalTo(CGSize(width: 27.47*scale, height: 26*scale))
                    make.centerY.equalToSuperview()
                    make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid*scale)
                    make.leading.equalTo(label.snp.trailing)
                }
            }
            
            toast.add(subview: contentView).snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            toast.onTapped { toast in
                if onTaped != nil {
                    toast.pop()
                    onTaped?()
                }
            }
        }
    }
    
    private func setupLeaderboardView() {
        if leaderboardView == nil {
            let leaderboardView = LeaderboardView()
            view.addSubview(leaderboardView)
            leaderboardView.snp.makeConstraints { make in
                make.leading.top.equalTo(self.gameView).inset(5)
                make.height.equalTo(24)
            }
            leaderboardView.isHidden = true
            leaderboardView.addTapGesture { [weak self] gesture in
                guard let self else { return }
                self.pauseEmulationIfNeed()
                CheevosPopupView.show(type: .leaderboard,
                                      leaderboards: leaderboards.reversed()) { [weak self] in
                    self?.resumeEmulationAndHandleAudio()
                }
            }
            self.leaderboardView = leaderboardView
        }
    }
    
    private func setupAchievementProgressView() {
        if cheevosProgressView == nil {
            let progressView = CheevosProgressView()
            view.addSubview(progressView)
            progressView.snp.makeConstraints { make in
                make.trailing.bottom.equalTo(self.gameView).inset(5)
                make.height.equalTo(32)
            }
            progressView.isHidden = true
            progressView.addTapGesture { [weak self] gesture in
                guard let self else { return }
                self.pauseEmulationIfNeed()
                CheevosPopupView.show(type: .progress,
                                      achievements: progressAchievements.reversed()) { [weak self] in
                    self?.resumeEmulationAndHandleAudio()
                }
            }
            self.cheevosProgressView = progressView
        }
    }
    
    private func setupAchievementChallengeView() {
        if cheevosChallengeView == nil {
            let challengeView = CheevosChallengeView()
            view.addSubview(challengeView)
            challengeView.snp.makeConstraints { make in
                make.leading.bottom.equalTo(self.gameView).inset(5)
                make.height.equalTo(32)
            }
            challengeView.isHidden = true
            challengeView.addTapGesture { [weak self] gesture in
                guard let self else { return }
                self.pauseEmulationIfNeed()
                
                CheevosPopupView.show(type: .challenge,
                                      achievements: self.challengeAchievements.reversed()) { [weak self] in
                    self?.resumeEmulationAndHandleAudio()
                }
            }
            self.cheevosChallengeView = challengeView
        }
    }
    
    private func getMenuInsets() -> UIEdgeInsets? {
        var menuInsets: UIEdgeInsets? = nil
        if let traits = controllerView.controllerSkinTraits, let insets = controllerView.controllerSkin?.menuInsets(for: traits) {
            func absoluteValue(for inset: Double, dimension: Double) -> Double {
                guard inset > 0 && inset <= 1.0 else { return inset }
                let absoluteValue = inset * dimension
                return absoluteValue
            }
            var absoluteMenuInsets = UIEdgeInsets.zero
            absoluteMenuInsets.left = absoluteValue(for: insets.left, dimension: self.view.bounds.width)
            absoluteMenuInsets.right = absoluteValue(for: insets.right, dimension: self.view.bounds.width)
            absoluteMenuInsets.top = absoluteValue(for: insets.top, dimension: self.view.bounds.height)
            absoluteMenuInsets.bottom = absoluteValue(for: insets.bottom, dimension: self.view.bounds.height)
            menuInsets = absoluteMenuInsets
        }
        return menuInsets
    }
    
    private func hideAchievementProgressIfNeed(forceHide: Bool = false) {
        guard let cheevosProgressView, !cheevosProgressView.isHidden else { return }
        
        if forceHide || !(self.manicGame.getExtraBool(key: ExtraKey.alwaysShowProgress.rawValue) ?? false) {
            UIView.springAnimate { [weak self] in
                self?.cheevosProgressView?.isHidden = true
            }
        }
    }
    
    private func updateNDSCursor() {
        guard manicGame.gameType == .ds else { return }
        if manicGame.defaultCore == 0 {
            if ExternalGameControllerManager.shared.connectedControllers.count > 0 || ExternalSceneDelegate.isAirPlaying {
                //如果ds模式下连接上外置控制器，支持右摇杆控制光标移动 L3确定
                LibretroCore.sharedInstance().updateRunningCoreConfigs(["melonds_show_cursor": "always"], flush: false)
            } else {
                LibretroCore.sharedInstance().updateRunningCoreConfigs(["melonds_show_cursor": "disabled"], flush: false)
            }
        }
    }
    
    private func updateNESPalette(_ nesPalette: Game.NESPalette, firstInit: Bool = false) {
        Log.debug("更新NES调色板:\(nesPalette.name) type:\(nesPalette.type)")
        manicGame.updateExtra(key: ExtraKey.nesPalette.rawValue, value: nesPalette.name)
        if nesPalette.type == .nestopia {
            if firstInit {
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Nestopia.name, key: "nestopia_palette", value: nesPalette.name, reload: false)
            } else {
                LibretroCore.sharedInstance().updateRunningCoreConfigs(["nestopia_palette": nesPalette.name], flush: false)
            }
        } else if nesPalette.type == .buildIn || nesPalette.type == .custom {
            let fromPath: String
            if nesPalette.type == .buildIn {
                fromPath = Constants.Path.NESPalettes.appendingPathComponent(nesPalette.name + ".pal")
            } else {
                fromPath = Constants.Path.CustomPalettes.appendingPathComponent(manicGame.gameType.localizedShortName).appendingPathComponent(nesPalette.name + ".pal")
            }
            do {
                try FileManager.safeCopyItem(at: URL(fileURLWithPath: fromPath), to: URL(fileURLWithPath: Constants.Path.System.appendingPathComponent("custom.pal")), shouldReplace: true)
                LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Nestopia.name, key: "nestopia_palette", value: "custom", reload: false)
                if !firstInit {
                    DispatchQueue.main.asyncAfter(delay: 0.05) {
                        LibretroCore.sharedInstance().reload(byKeepState: true)
                    }
                }
            } catch {
                Log.debug("更新NES调色板失败:\(error)")
            }
        }
    }
    
    private func updateTriggerPro(showToast: Bool = false) {
        guard !isHardcoreMode else {
            if showToast {
                UIView.makeToast(message: R.string.localizable.notAllowHardcore())
            }
            return
        }
        
        triggerProView?.removeFromSuperview()
        triggerProView = nil
        triggerProUpdateToken = nil
        
        if let id = manicGame.getExtraInt(key: ExtraKey.triggerProID.rawValue), id != -1 {
            let realm = Database.realm
            if let trigger = realm.objects(Trigger.self).where({ $0.id == id }).first {
                triggerProUpdateToken = trigger.observe(keyPaths: [\Trigger.items]) { [weak self] change in
                    guard let self = self else { return }
                    switch change {
                    case .change(_, _):
                        Log.debug("TriggerPro更新")
                        self.triggerProView?.reloadButtons()
                    default:
                        break
                    }
                }
                
                let aView = TriggerProView(trigger: trigger)
                aView.hapticType = manicGame.haptic
                aView.activateHandler = { [weak self] inputs in
                    guard let self else { return }
                    for input in inputs {
                        if input.type == .controller(GameControllerInputType("directKeyboard")) {
                            self.gameController(self.controllerView, didActivate: input, value: 0)
                        } else {
                            self.controllerView.activate(input)
                        }
                    }
                }
                aView.deactivateHandler = { [weak self] inputs in
                    guard let self else { return }
                    for input in inputs {
                        if input.type == .controller(GameControllerInputType("directKeyboard")) {
                            self.gameController(self.controllerView, didDeactivate: input)
                        } else {
                            self.controllerView.deactivate(input)
                        }
                    }
                }
                view.addSubview(aView)
                aView.snp.makeConstraints { make in
                    make.edges.equalTo(controllerView)
                }
                triggerProView = aView
                if showToast {
                    UIView.makeToast(message: R.string.localizable.enableTriggerPro() + ": \(trigger.triggerProName)")
                }
                return
            }
        }
        //禁用TriggerPro
        if showToast {
            UIView.makeToast(message: R.string.localizable.disableTriggerPro())
        }
    }
    
    private func updateFastforward(speed: GameSetting.FastForwardSpeed) {
        guard !manicGame.safeMode else { return }
        if manicGame.isLibretroType {
            switch speed {
            case .one, .two:
                LibretroCore.sharedInstance().setFastforwardFrameSkip(false)
            default:
                LibretroCore.sharedInstance().setFastforwardFrameSkip((manicGame.gameType == .ps1 && manicGame.defaultCore == 0) ? false : true)
            }
            switch speed {
            case .one:
                LibretroCore.sharedInstance().fastForward(0.0)
            case .two:
                LibretroCore.sharedInstance().fastForward(1.35)
            case .three:
                LibretroCore.sharedInstance().fastForward(3)
            case .four:
                LibretroCore.sharedInstance().fastForward(5)
            case .five:
                LibretroCore.sharedInstance().fastForward(7)
            }
        } else if manicGame.isJGenesisCore {
            switch speed {
            case .one:
                jGenesisCore?.fastForward(speed: 1.0)
            case .two:
                jGenesisCore?.fastForward(speed: 1.5)
            case .three:
                jGenesisCore?.fastForward(speed: 3)
            case .four:
                jGenesisCore?.fastForward(speed: 5)
            case .five:
                jGenesisCore?.fastForward(speed: 7)
            }
        } else if manicGame.isJ2MECore {
            switch speed {
            case .one:
                j2meCore?.fastForward(speed: 1.0)
            case .two:
                j2meCore?.fastForward(speed: 1.5)
            case .three:
                j2meCore?.fastForward(speed: 3)
            case .four:
                j2meCore?.fastForward(speed: 5)
            case .five:
                j2meCore?.fastForward(speed: 7)
            }
        } else if manicGame.isCitra3DS {
            let bridge = ThreeDSEmulatorBridge.shared
            switch speed {
            case .one:
                bridge.setFrameLimit(100)
            case .two:
                bridge.setFrameLimit(120)
            case .three:
                bridge.setFrameLimit(150)
            case .four:
                bridge.setFrameLimit(200)
            case .five:
                bridge.setFrameLimit(300)
            }
        }
    }
    
    private func getDualScreenViewFrame() -> CGRect? {
        guard let controllerSkin = controllerView.controllerSkin as? ControllerSkin else { return nil }
        guard let frames = controllerSkin.getFrames() else { return nil }
        let skinframe = frames.skinFrame
        let topFrame = frames.mainGameViewFrame
        if let bottomFrame = frames.touchGameViewFrame {
            //双屏
            let minX = min(topFrame.minX, bottomFrame.minX)
            let minY = min(topFrame.minY, bottomFrame.minY)
            let x = skinframe.minX + minX
            let y = skinframe.minY + minY
            let width = topFrame.maxX > bottomFrame.maxX ? topFrame.maxX - minX : bottomFrame.maxX - minX
            let height = topFrame.maxY > bottomFrame.maxY ? topFrame.maxY - minY : bottomFrame.maxY - minY
            return CGRect(x: x, y: y, width: width, height: height)
        } else {
            //单屏幕
            let x = skinframe.minX + topFrame.minX
            let y = skinframe.minY + topFrame.minY
            let width = topFrame.width
            let height = topFrame.height
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }
    
    private func updateBackground() {
        guard !manicGame.safeMode else { return }
        guard controllerView.controllerSkin?.identifier.lowercased() == manicGame.gameType.rawValue.lowercased() + ".flex" else {
            return
        }
        if backgroundImageView == nil {
            let bgView = UIImageView()
            bgView.contentMode = .scaleAspectFill
            view.insertSubview(bgView, at: 0)
            bgView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            backgroundImageView = bgView
        }
        
        if let bg = FlexBackground.getBackground(isLandScape: UIDevice.isLandscape, game: manicGame) {
            backgroundType = bg.type
            background = bg.background
            self.backgroundImageView?.image = try? UIImage(url: bg.background.imageUrl)
        } else {
            backgroundType = nil
            background = nil
            self.backgroundImageView?.image = nil
        }
    }
    
    private func update2600TvColor(isInit: Bool) {
        guard manicGame.gameType == .a2600 else { return }
        var isColor = manicGame.getExtraBool(key: ExtraKey.tvType.rawValue) ?? true
        if !isInit {
            isColor = !isColor
            manicGame.updateExtra(key: ExtraKey.tvType.rawValue, value: isColor)
        }
        skinSwitchBindDatas["tvType"] = !isColor
        DispatchQueue.main.asyncAfter(delay: isInit ? 2 : 0, execute: {
            LibretroCore.sharedInstance().press(isColor ? .L3 : .R3, playerIndex: 0)
            DispatchQueue.main.asyncAfter(delay: 0.1) {
                LibretroCore.sharedInstance().release(isColor ? .L3 : .R3, playerIndex: 0)
            }
        })
    }
    
    private func update2600LeftDifficulty(isInit: Bool) {
        guard manicGame.gameType == .a2600 else { return }
        var isLeftDifficultyA = manicGame.getExtraBool(key: ExtraKey.leftDifficulty.rawValue) ?? true
        if !isInit {
            isLeftDifficultyA = !isLeftDifficultyA
            manicGame.updateExtra(key: ExtraKey.leftDifficulty.rawValue, value: isLeftDifficultyA)
        }
        skinSwitchBindDatas["leftDifficulty"] = !isLeftDifficultyA
        DispatchQueue.main.asyncAfter(delay: isInit ? 2 : 0, execute: {
            LibretroCore.sharedInstance().press(isLeftDifficultyA ? .L1 : .L2, playerIndex: 0)
            DispatchQueue.main.asyncAfter(delay: 0.1) {
                LibretroCore.sharedInstance().release(isLeftDifficultyA ? .L1 : .L2, playerIndex: 0)
            }
        })
    }
    
    private func update2600RightDifficulty(isInit: Bool) {
        guard manicGame.gameType == .a2600 else { return }
        var isRightDifficultyA = manicGame.getExtraBool(key: ExtraKey.rightDifficulty.rawValue) ?? true
        if !isInit {
            isRightDifficultyA = !isRightDifficultyA
            manicGame.updateExtra(key: ExtraKey.rightDifficulty.rawValue, value: isRightDifficultyA)
        }
        skinSwitchBindDatas["rightDifficulty"] = !isRightDifficultyA
        
        DispatchQueue.main.asyncAfter(delay: isInit ? 2 : 0, execute: {
            LibretroCore.sharedInstance().press(isRightDifficultyA ? .R1 : .R2, playerIndex: 0)
            DispatchQueue.main.asyncAfter(delay: 0.1) {
                LibretroCore.sharedInstance().release(isRightDifficultyA ? .R1 : .R2, playerIndex: 0)
            }
        })
    }
    
    private func updateScreenScaling(_ scaling: GameSetting.ScreenScaling) {
        if manicGame.isLibretroType {
            LibretroCore.sharedInstance().setFullScreen(scaling == .stretch ? true : false)
        } else if manicGame.isJ2MECore {
            j2meCore?.setScaleMode(scaling)
        }
    }
}

//MARK: GameViewControllerDelegate代理
extension PlayViewController: GameViewControllerDelegate {
    
    func gameViewControllerShouldResume(_ gameViewController: GameViewController) -> Bool {
        if SheetProvider.find(identifier: Constants.Strings.PlayPurchaseAlertIdentifier).count > 0 {
            return false
        }
        return (GameSettingView.isShow || GameInfoView.isShow || CheatCodeListView.isShow || SkinSettingsView.isShow || ShadersListView.isShow || ControllersSettingView.isShow || GameSettingView.isEditingShow || WebViewController.isShow || FlexSkinSettingViewController.isShow || RetroAchievementsListViewController.isShow || CheevosPopupView.isShow || GameplayManualsView.isShow || FBNeoCheatCodeListView.isShow || J2MESettingView.isShow || CoreConfigsView.isShow) ? false : true
    }
    
}

//MARK: 公开方法
extension PlayViewController {
    static var isGaming: Bool { currentPlayViewController != nil }
    
    static var enableAirplay: Bool {
        if let _ = currentPlayViewController {
            return true
        }
        return false
    }
    
    static var currentSkinID: String? {
        if let currentPlayViewController {
            if UIDevice.isLandscape {
                return currentPlayViewController.manicGame.landscapeSkin?.id
            } else {
                return currentPlayViewController.manicGame.portraitSkin?.id
            }
        }
        return nil
    }
    
    static var isHideControls: Bool {
        if let currentPlayViewController {
            return currentPlayViewController.manicGame.forceFullSkin
        }
        return false
    }
    
    static var menuInsets: UIEdgeInsets? {
        if let currentPlayViewController {
            return currentPlayViewController.getMenuInsets()
        }
        return nil
    }
    
    static var jGenesisView: JGenesisView? {
        if let currentPlayViewController {
            return currentPlayViewController.jGenesisCore
        }
        return nil
    }
    
    static var j2meView: J2MEView? {
        if let currentPlayViewController {
            return currentPlayViewController.j2meCore
        }
        return nil
    }
    
    static var currentGameType: GameType? {
        if let currentPlayViewController {
            return currentPlayViewController.manicGame.gameType
        }
        return nil
    }
}
