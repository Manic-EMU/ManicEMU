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
    private var notificationTokens = [Any]()
    
    //每分钟执行一次
    private lazy var repeatTimer: Schedule.Task = {
        if let task = TaskCenter.default.tasks(forTag: String(describing: Self.self)).first {
            return task
        } else {
            let task = Plan.every(R.Numbers.AutoSaveGameDuration.seconds).do(queue: .global()) { [weak self] in
                guard let self = self else { return }
                //每分钟记录一次游戏时间
                self.calculatePlayTime()
                //每分钟保存一次存档
                DispatchQueue.main.async { [weak self] in
                    guard let self,
                            !self.manicGame.isCitra3DS,
                            Settings.defalut.autoSaveState else { return }
                    self.saveState(type: .autoSaveState)
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
    class ShortcutButtonContainerView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            // Iterate through all subviews and check whether the click is on a subview
            for subview in subviews.reversed() {
                let convertedPoint = subview.convert(point, from: self)
                if subview.bounds.contains(convertedPoint) {
                    return super.hitTest(point, with: event)
                }
            }
            // Click not on any subview, return nil to let the click pass through.
            return nil
        }
    }
    private var shortcutsButtonContainer = ShortcutButtonContainerView()
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
    ///flex皮肤的menu和flex按钮
    private weak var flexMenuButton: UIView? = nil
    private weak var flexButton: UIView? = nil
    ///PscxReArmed init device
    private var pscxReArmedDeviceType = R.Strings.PSXController
    
    //数据库变化通知
    private var gameUpdateToken: Any? = nil
    private var cheatCodeUpdateToken: Any? = nil
    private var triggerProUpdateToken: Any? = nil
    private var settingsUpdateToken: Any? = nil
    
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
    
    private var currentSkinID: String? = nil
    
    //皮肤中的Switch绑定数据
    private var skinSwitchBindDatas = [String: Bool]()
    
    static func startGame(game: Game, saveState: GameSaveState? = nil) {
        if game.gameType == .ns {
            EmulatorInteractionKit.startGame(type: .meloNX, id: game.id)
            return
        } else if game.gameType == .xbox360 {
            EmulatorInteractionKit.startGame(type: .xeniOS, id: game.id)
            return
        } else if game.gameType == .xbox {
            EmulatorInteractionKit.startGame(type: .dukeX, id: game.id)
            return
        } else if game.gameType == .ps2 {
            EmulatorInteractionKit.startGame(type: .armsx2, id: game.id)
            return
        }
        
        game.ensurePS1BinCueSheet()
        if game.isRomExtsts || game.isNDSHomeMenuGame || game.isDOSHomeMenuGame {
            UIView.hideLoadingToast(forceHide: true)
            func showPlayView() {
                if game.isBIOSMissing() {
                    //检查是否缺失BIOS
                    BIOSSelectionView.show(gameType: game.gameType)
                    return
                }
                if game.gameType == .unknown {
                    PlatformSelectionView.show(games: [game])
                    return
                }
                func launchGameByDismissOtherVC() {
                    //Clear the image memory cache before starting the game.
                    KingfisherManager.shared.cache.clearMemoryCache()
                    
                    let pretendoNetworkingViewHasShownInstance = PretendoNetworkingView.hasShownInstance
                    
                    if !pretendoNetworkingViewHasShownInstance {
                        //hide all alert
                        UIView.hideAllAlert()
                    }
                    
                    FocusSystem.shared.isEnabled = false
                    
                    //游戏控制器和rootVC之间存在控制器则会导致游戏卡顿异常 估计是iOS的bug，导致了Main Run Loop调度异常
                    if game.isLibretroType {
                        LibretroCore.sharedInstance().workspace = R.Path.Libretro
                    }
                    if pretendoNetworkingViewHasShownInstance {
                        topViewController()?.present(PlayViewController(game: game, saveState: saveState), animated: true)
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
                if game.gameType == ._3ds, !UIDevice.current.hasA11ProcessorOrBetter, !UserDefaults.standard.bool(forKey: R.DefaultKey.HasShow3DSNotSupportAlert) {
                    UIView.makeAlert(title: R.string.localizable.threeDSNoSupportDeviceTitle(), detail: R.string.localizable.threeDSNoSupportDeviceDetail(), confirmTitle: R.string.localizable.gameSaveContinue(), confirmAction: {
                        UserDefaults.standard.set(true, forKey: R.DefaultKey.HasShow3DSNotSupportAlert)
                        launchGameByDismissOtherVC()
                    })
                } else if game.gameType == .ps1, !UserDefaults.standard.bool(forKey: R.DefaultKey.HasShowPS1PlayAlert) {
                    UIView.makeAlert(title: R.string.localizable.psxRunAlert(),
                                     detail: R.string.localizable.sbiImportDesc(),
                                     detailAlignment: .left,
                                     cancelTitle: R.string.localizable.confirmTitle(), hideAction: { _ in
                        UserDefaults.standard.set(true, forKey: R.DefaultKey.HasShowPS1PlayAlert)
                        launchGameByDismissOtherVC()
                    });
                } else if game.gameType == ._3ds, game.identifierFor3DS == R.Numbers.PKSMIdentifier {
                    if Settings.defalut.getExtraBool(key: ExtraKey.globalAchievements.rawValue) ?? false {
                        UIView.makeAlert(title: R.string.localizable.retroAchievements(), detail: R.string.localizable.forbitPKSM(), cancelTitle: R.string.localizable.confirmTitle())
                    } else {
                        launchGameByDismissOtherVC()
                    }
                } else if game.isJGenesisCore, game.gameType == .mcd, game.fileExtension.lowercased() != "chd" {
                    UIView.makeToast(message: R.string.localizable.jGenesisAlert())
                } else if game.isDolphinCore,
                          !game.jit,
                          !UserDefaults.standard.bool(forKey: R.DefaultKey.HasShowDolphinCoreAlert) {
                    UIView.makeAlert(title: R.string.localizable.focusShortcutsTips(),
                                     detail: R.string.localizable.dolphinCoreWraning(),
                                     cancelTitle: R.string.localizable.gotIt(),
                                     hideAction: { _ in
                        UserDefaults.standard.set(true, forKey: R.DefaultKey.HasShowDolphinCoreAlert)
                        launchGameByDismissOtherVC()
                    })
                }  else {
                    launchGameByDismissOtherVC()
                }
            }
            if game.gameType == .ss, !UserDefaults.standard.bool(forKey: R.DefaultKey.HasShowSSPlayAlert), game.isBIOSMissing(required: false), game.defaultCore == 1 {
                UIView.makeAlert(title: R.string.localizable.saturnBiosAlertTitle(),
                                 detail: R.string.localizable.saturnBiosAlertDetail(),
                                 detailAlignment: .left,
                                 cancelTitle: R.string.localizable.startGameWithoutBiosTitle(),
                                 confirmTitle: R.string.localizable.biosAddTitle(), cancelAction: {
                    UserDefaults.standard.set(true, forKey: R.DefaultKey.HasShowSSPlayAlert)
                    showPlayView()
                }, confirmAction: {
                    UserDefaults.standard.set(true, forKey: R.DefaultKey.HasShowSSPlayAlert)
                    BIOSSelectionView.show(gameType: .ss)
                }, hideAction: { _ in
                    UserDefaults.standard.set(true, forKey: R.DefaultKey.HasShowSSPlayAlert)
                });
            } else if game.gameType == .j2me, game.defaultCore == 1, !UserDefaults.standard.bool(forKey: R.DefaultKey.HasShowFreeJ2meAlert) {
                UIView.makeAlert(title: R.string.localizable.headsUp(),
                                 detail: R.string.localizable.freej2meAlert(),
                                 detailAlignment: .left,
                                 cancelTitle: R.string.localizable.confirmTitle(),
                                 cancelAction: {
                    UserDefaults.standard.set(true, forKey: R.DefaultKey.HasShowFreeJ2meAlert)
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
                        UIView.makeToast(message: R.string.localizable.loadRomSuccess(game.displayName))
                    }
                } else {
                    UIView.makeToast(message: R.string.localizable.loadGameErrorRomNotExist())
                }
            }
        }
    }
    
    //MARK: 生命周期
    deinit {
        Log.debug("✅ \(objectInfo(self)) deinit")
        gameUpdateToken = nil
        cheatCodeUpdateToken = nil
        triggerProUpdateToken = nil
        settingsUpdateToken = nil
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        if SyncManager.shared.hasDownloadTask {
            UIView.makeLoadingToast(message: R.string.localizable.loadingTitle())
        }
    }
    
    private init(game: Game, saveState: GameSaveState? = nil) {
        manicGame = game
        super.init()
        Log.debug("⚠️ \(ObjectIdentifier(self)) init")
        loadSaveState = saveState
        modalPresentationStyle = .fullScreen
        delegate = self
        self.game = DeltaCore.Game(fileURL: game.romUrl, type: game.gameType)
        
        //通知监听
        setupNotifications()
        
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
        gameUpdateToken = manicGame.observe(keyPaths: [
            \Game.orientation,
             \Game.haptic,
             \Game.accurateShaders,
             \Game.renderRightEye,
             \Game.swapScreen,
        ]) { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .change(_, let properties):
                Log.debug("游戏运行中，游戏更新")
                for property in properties {
                    if property.name == "orientation" {
                        //更新屏幕方向
                        self.startOrientation()
                    } else if property.name == "haptic" {
                        //修改震感
                        self.updateHaptic()
                    } else if property.name == "accurateShaders" {
                        citraCore?.updateConfig(["ManicEMU.useShadersAccurateMul": self.manicGame.accurateShaders])
                    } else if property.name == "renderRightEye" {
                        
                        citraCore?.updateConfig(["ManicEMU.disableRightEyeRender": self.manicGame.renderRightEye])
                    } else if property.name == "swapScreen" {
                        self.skinSwitchBindDatas["reverseScreens"] = self.manicGame.swapScreen
                        self.updateSkin()
                    }
                    Log.debug("设置更新 Property '\(property.name)' changed from \(property.oldValue == nil ? "nil" : property.oldValue!) to '\(property.newValue!)'")
                }
            default:
                break
            }
        }
        
        settingsUpdateToken = Settings.defalut.observe(keyPaths: [\Settings.threeDSMode]) { [weak self] change in
            guard let self else { return }
            switch change {
            case .change(_, let properties):
                for property in properties {
                    if property.name == "threeDSMode",
                        self.manicGame.isCitra3DS,
                        let citraCore = self.citraCore {
                        citraCore.updateConfig()
                    }
                }
            default:
                break
            }
        }
        
    }
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: .externalGameControllerDidConnect, object: nil, queue: .main) { [weak self] notification in
            //手柄连接
            self?.updateExternalGameController()
            self?.updateSkin()
        })
        notificationTokens.append(center.addObserver(forName: .externalGameControllerDidDisconnect, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            //手柄断开连接
            if ExternalGameControllerManager.shared.connectedControllers.count == 0 {
                self.manicGame.forceFullSkin = false
                self.updateSkin()
                self.updateNDSCursor()
            }
        })
        notificationTokens.append(center.addObserver(forName: .externalKeyboardDidConnect, object: nil, queue: .main) { [weak self] notification in
            //键盘连接
            self?.updateExternalGameController()
            self?.updateSkin()
        })
        notificationTokens.append(center.addObserver(forName: .externalKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] notification in
            //键盘断开连接
            if ExternalGameControllerManager.shared.connectedControllers.count == 0 {
                self?.manicGame.forceFullSkin = false
                self?.updateSkin()
            }
        })
        notificationTokens.append(center.addObserver(forName: UIScene.willConnectNotification, object: nil, queue: .main) { [weak self] notification in
            //投屏开始
            self?.updateAirPlay()
        })
        notificationTokens.append(center.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { [weak self] notification in
            //投屏结束
            self?.updateAirPlay()
        })
        notificationTokens.append(center.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: .main) { [weak self] notification in
            //进入后台
            guard let self = self else { return }
            self.pauseEmulationIfNeed()
        })
        notificationTokens.append(center.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] notification in
            //从后台回到前台
            self?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            guard let self = self else { return }
            if self.gameViewControllerShouldResume(self) {
                self.resumeEmulationAndHandleAudio()
            }
        })
        notificationTokens.append(center.addObserver(forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] notification in
            //keywindow变化
            self?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        })
        notificationTokens.append(center.addObserver(forName: R.NotificationName.MembershipChange, object: nil, queue: .main) { [weak self] notification in
            //购买会员成功
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
                            }, hideAction: { [weak self] _ in
                                self?.resumeEmulationAndHandleAudio()
                            })
                        }
                    } else {
                        self?.resumeEmulationAndHandleAudio()
                    }
                }
            }
        })
        notificationTokens.append(center.addObserver(forName: R.NotificationName.ControllerMapping, object: nil, queue: .main) { [weak self] notification in
            //监听控制器映射变化
            self?.updateExternalGameController()
        })
        notificationTokens.append(center.addObserver(forName: Notification.Name(rawValue: "DidConnectToWFCNotification"), object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            //监听WFC连接
            //在线游戏 禁用加速 禁用金手指
            UIView.makeToast(message: R.string.localizable.wfcConnectDesc())
            self.isWFCConnect = true
            self.updateFastforward(speed: .one)
        })
        notificationTokens.append(center.addObserver(forName: Notification.Name(rawValue: "DidDisconnectFromWFCNotification"), object: nil, queue: .main) { [weak self] notification in
            //监听WFC断开连接
            guard let self else { return }
            UIView.makeToast(message: R.string.localizable.wfcDisconnectDesc())
            self.isWFCConnect = false
            self.updateFastforward(speed: self.manicGame.speed)
        })
        notificationTokens.append(center.addObserver(forName: R.NotificationName.MotionShake, object: nil, queue: .main) { [weak self] notification in
            //核心请求退出
            guard let self else { return }
            if self.manicGame.gameType == .pm {
                LibretroCore.sharedInstance().press(.L1, playerIndex: 0)
                DispatchQueue.main.asyncAfter(delay: 0.1) {
                    LibretroCore.sharedInstance().release(.L1, playerIndex: 0)
                }
            }
        })
        notificationTokens.append(center.addObserver(forName: Notification.Name(rawValue: "LibretroDidShutdownNotification"), object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            //Libretro Shutdown
            if self.manicGame.gameType == .symbian {
                UIView.makeToast(message: R.string.localizable.symbianAppGetKilled())
            }
            
            if self.manicGame.isAzaharArticBase {
                // Dismiss the PlayViewController without dismissing the PretendoNetworkingView
                self.dismiss(animated: true)
            } else {
                UIView.hideAllAlert()
            }
            
            GameOption.quit.performAction(with: [self.manicGame])
        })
        notificationTokens.append(center.addObserver(forName: R.NotificationName.MotionShake, object: nil, queue: .main) { [weak self] notification in
            //设备晃动通知
            guard let self else { return }
            if self.manicGame.gameType == .pm {
                LibretroCore.sharedInstance().press(.L1, playerIndex: 0)
                DispatchQueue.main.asyncAfter(delay: 0.1) {
                    LibretroCore.sharedInstance().release(.L1, playerIndex: 0)
                }
            }
        })
        notificationTokens.append(center.addObserver(forName: Notification.Name(rawValue: "RetroAchievementsNotification"), object: nil, queue: .main, using: { [weak self] notification in
            //RetroAchievements通知
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
                        RetroAchievementsDetailView.show(achievement: achievement)
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
                self.showRetroAchievements(title: self.isHardcoreMode ?  R.string.localizable.achievementsMastered(self.manicGame.displayName) : R.string.localizable.achievementsCompleted(),
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
        }))
        notificationTokens.append(center.addObserver(forName: R.NotificationName.QuitGaming, object: nil, queue: .main, using: { [weak self] notification in
            //退出游戏
            guard let self else { return }
            UIView.hideAllAlert()
            self.quit()
        }))
        notificationTokens.append(center.addObserver(forName: R.NotificationName.TurnOffHardcore, object: nil, queue: .main, using: { [weak self] notification in
            //关闭硬核模式
            guard let self else { return }
            self.isHardcoreMode = false
            LibretroCore.sharedInstance().updateLibretroConfig("cheevos_hardcore_mode_enable", value: "false")
            LibretroCore.sharedInstance().turnOffHardcode()
            if self.manicGame.gameType == .psp {
                LibretroCore.sharedInstance().updateRunningCoreConfigs(["ppsspp_cheats": "enabled"], flush: false)
            }
        }))
        notificationTokens.append(center.addObserver(forName: R.NotificationName.TurnOffAlwaysShowProgress, object: nil, queue: .main, using: {
            //关闭进度常驻
            [weak self] notification in
            guard let self else { return }
            self.hideAchievementProgressIfNeed()
        }))
        notificationTokens.append(center.addObserver(forName: Notification.Name(rawValue: "MAMEGameFileMissingNotification"), object: nil, queue: .main) { notification in
            //MAME游戏文件缺失
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
        })
        notificationTokens.append(center.addObserver(forName: R.NotificationName.ResetImmediately, object: nil, queue: .main, using: { [weak self] notification in
            //重置游戏通知
            guard let self else { return }
            UIView.hideAllAlert()
            GameOption.reload.performAction(with: [self.manicGame])
        }))
        notificationTokens.append(center.addObserver(forName: R.NotificationName.SkinChange, object: nil, queue: .main, using: { [weak self] notification in
            //皮肤变更
            guard let self ,
                  let gameId = notification.object as? String,
                  gameId == self.manicGame.id else { return }
            self.updateSkin()
        }))
        notificationTokens.append(center.addObserver(forName: R.NotificationName.ShortcutsChange, object: nil, queue: .main, using: { [weak self] notification in
            //快捷键变更
            guard let self else { return }
            self.updateShortcutsButton()
        }))
        notificationTokens.append(center.addObserver(forName: Notification.Name(rawValue: "FirmwareNoSupportNotification"), object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            //Libretro Shutdown
            UIView.makeToast(message: R.string.localizable.firmwareNotSupport())
            DispatchQueue.main.asyncAfter(delay: 3) { [weak self] in
                guard let self else { return }
                UIView.hideAllAlert()
                GameOption.quit.performAction(with: [self.manicGame])
            }
        })
        notificationTokens.append(center.addObserver(forName: Notification.Name(rawValue: "AmigaBiosMissingNotification"), object: nil, queue: .main) { notification in
            if let log = notification.object as? String {
                UIView.makeAlert(title: R.string.localizable.mameFileMissingTitle(),
                                 detail: log,
                                 cancelTitle: R.string.localizable.confirmTitle())
            }
        })
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
        ExternalInputDispatch.sink = .gameplay
        FocusSystem.shared.isEnabled = false
        
        //发送开始游戏通知
        NotificationCenter.default.post(name: R.NotificationName.StartPlayGame, object: nil)
        
        //添加功能按钮容器按钮
        shortcutsButtonContainer.isHidden = true
        view.addSubview(shortcutsButtonContainer)
        shortcutsButtonContainer.snp.makeConstraints { make in
            if manicGame.gameType == .n64 && UIDevice.isPad {
                make.top.equalTo(gameView.snp.bottom).offset(-9)
            } else if manicGame.gameType == .j2me ||
                        manicGame.gameType == .gba {
                make.top.equalTo(gameView.snp.bottom).offset(3)
            } else if manicGame.gameType.usesDOSSkinLayout {
                if UIDevice.isSmallScreenPhone {
                    make.top.equalTo(gameView.snp.bottom).offset(17)
                } else if UIDevice.isProMaxPhone {
                    make.top.equalTo(gameView.snp.bottom).offset(22)
                } else {
                    make.top.equalTo(gameView.snp.bottom).offset(19)
                }
            } else if manicGame.gameType == .symbian, UIDevice.isPhone {
                make.top.equalTo(gameView.snp.bottom).offset(4)
            } else if manicGame.isDolphinCore {
                make.top.equalTo(gameView.snp.bottom).offset(5)
            } else if manicGame.gameType == .pce {
                make.top.equalTo(gameView.snp.bottom).offset(R.Size.ContentSpaceMedium)
            } else {
                make.top.equalTo(gameView.snp.bottom)
            }
            
            make.leading.trailing.equalTo(gameView)
            
            if manicGame.gameType == .j2me ||
                manicGame.gameType.usesDOSSkinLayout ||
                (manicGame.gameType == .symbian && UIDevice.isPhone) ||
                manicGame.gameType == .pce ||
                manicGame.gameType == .gba {
                make.height.equalTo(R.Size.ItemHeightMicro)
            } else if manicGame.gameType == .ngp {
                make.height.equalTo(R.Size.ItemHeightTiny)
            } else {
                make.height.equalTo(R.Size.ItemHeightMedium)
            }
            
        }
        //设置外设控制器
        updateExternalGameController()
        //如果需要加载默认配置
        LibretroCore.sharedInstance().forbitJIT = manicGame.safeMode
        loadConfig()
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
        shortcutsButtonContainer.isHidden = false
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
        if manicGame.safeMode {
            manicGame.safeMode = false
        }
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
                if let showDate = UserDefaults.standard.date(forKey: R.DefaultKey.ShowRequestReviewDate), showDate.isInToday {
                    
                } else {
                    SKStoreReviewController.requestReview(in: scene)
                    UserDefaults.standard.set(Date(), forKey: R.DefaultKey.ShowRequestReviewDate)
                }
            }
        }
#endif
        
        if manicGame.isCitra3DS {
            citraCore?.destory()
        }
        
        removeExternalGameControllerReceivers()
        PlayViewController.currentPlayViewController = nil
        PlayViewController.refreshExternalInputSink()
        
        //发送结束游戏通知
        NotificationCenter.default.post(name: R.NotificationName.StopPlayGame, object: nil)
        
        //取消静音监听
        muteSwitchMonitor.stopMonitoring()
        
        //通知游戏列表更新
        if let gameSortType = GameSortType(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.gameSortType.rawValue) ?? 0),
           (gameSortType == .latestPlayed || gameSortType == .playTime) {
            NotificationCenter.default.post(name: R.NotificationName.GameSortChange, object: nil)
        }
        //Libretro已经停止，不要在这里进行注销事项，应该在stop()函数中完成
        
#if SIDE_LOAD
        if #available(iOS 26.0, tvOS 26.0, *),
           ((manicGame.gameType == .dos && ProcessInfo.processInfo.hasTXM) ||
            manicGame.gameType == .symbian),
           (LibretroCore.jitAvailable() && manicGame.jit) {
            if UIApplication.shared.canOpenURL(R.URLs.EnableJITUrl) {
                UIApplication.shared.open(R.URLs.EnableJITUrl)
            }
        }
#endif
        
        //如果是Artic Base配置 离开这个页面的时候需要进行一些清理
        if manicGame.isAzaharArticBase {
            DispatchQueue.main.asyncAfter(delay: 1) {
                let realm = Database.realm
                if let game = realm.object(ofType: Game.self, forPrimaryKey: R.Strings.AzaharArticBaseGameID) {
                    try? realm.write { realm.delete(game) }
                }
            }
        }
        //If it's an operation on AzaharArticBase, note that manicGame has been deleted above 👆. Any further operations involving manicGame could cause serious issues.
        
        LibretroNetplaySession.shared.clear()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if #available(iOS 26.0, *) {
            return AppDelegate.orientation
        }
        return super.supportedInterfaceOrientations
    }
    
    /// Default orientation when this screen is presented.
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        if manicGame.orientation == .landscape {
            return .landscapeRight
        } else if manicGame.orientation == .portrait {
            return .portrait
        }
        return super.preferredInterfaceOrientationForPresentation
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        let fromSize = R.Size.WindowSize
        let toSize = size
        if manicGame.orientation == .portrait {
            // Portrait lock: ignore landscape-bound transitions.
            if fromSize.height > fromSize.width && toSize.height < toSize.width {
                return
            }
        } else if manicGame.orientation == .landscape {
            // Landscape lock: ignore portrait-bound transitions.
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
            self.update3DSMotionRotation()
            self.updateSkin()
            self.view.setNeedsLayout()
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
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.gameController(gameController, didActivate: input, value: value)
            }
            return
        }
        if gameController.inputType == .mfi || gameController.inputType == .keyboard {
            guard ExternalInputDispatch.sink == .gameplay else { return }
        }
        
        guard !isPaused || input.stringValue == "menu" else { return }
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
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.gameController(gameController, didDeactivate: input)
            }
            return
        }
        if let directKeyboardInput = input as? AnyInput,
           directKeyboardInput.type == .controller(GameControllerInputType("directKeyboard")),
           manicGame.isLibretroType,
           let keyCode = LibretroKeyboardCode.createCode(withLabel: directKeyboardInput.stringValue) {
            LibretroCore.sharedInstance().releaseKeyboard(keyCode)
        } else if let mappingKey = MappingOption(rawValue: input.stringValue) {
            if mappingKey == .fastForward2x ||
                mappingKey == .fastForward3x ||
                mappingKey == .fastForward4x ||
                mappingKey == .fastForward {
                updateFastforward(speed: manicGame.speed)
                Log.debug("长按结束，恢复原速度")
            } else if mappingKey == .rewind {
                LibretroCore.sharedInstance().setRewind(false)
            }
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
                    self.manicGame.totalPlayDuration += Double(R.Numbers.AutoSaveGameDuration*1000)
                }
                Log.debug("记录游戏时间")
            }
        }
    }
    
    private func saveState(type: GameSaveStateType) {
        guard manicGame.supportSaveState else { return }
        let now = Date.now
        if type == .manualSaveState,
           let lastSaveDate = lastSaveDate,
           now.timeIntervalSince1970ms - lastSaveDate.timeIntervalSince1970ms < (manicGame.isCitra3DS ? 5000 : 3000) {
            UIView.makeToast(message: R.string.localizable.saveStateTooFrequent(), identifier: "saveStateTooFrequent")
            return
        }
        
        func persistentSaveState(stateName: String,
                                 image: UIImage?,
                                 statePath: String?,
                                 stateData: Data?) {
            guard statePath != nil || stateData != nil else { return }
            let now = Date.now
            let state = GameSaveState()
            state.name = "\(now.string(withFormat: R.Strings.FileNameTimeFormat))_" + stateName
            state.type = type
            state.date = now
            if let imageData = image?.scaled(toHeight: 150)?.jpegData(compressionQuality: 0.7) {
                state.stateCover = CreamAsset.create(objectID: state.name, propName: "stateCover", data: imageData)
            }
            if let statePath {
                state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", url: URL(fileURLWithPath: statePath))
            } else if let stateData {
                state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", data: stateData)
            }
            let autoSaveStates = self.manicGame.gameSaveStates.where({ $0.type == .autoSaveState }).sorted(by: \GameSaveState.date)
            Game.change { realm in
                //自动保存的数量最多只能保存AutoSaveGameCount个
                if autoSaveStates.count >= R.Numbers.AutoSaveGameCount {
                    let needToDeletes = autoSaveStates.prefix(autoSaveStates.count - R.Numbers.AutoSaveGameCount + 1)
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
                UIView.makeToast(message: R.string.localizable.gameSaveStateSuccess(), identifier: "gameSaveStateSuccess")
            }
        }
        
        if manicGame.isCitra3DS {
            if let citraCore {
                let result = citraCore.saveState()
                if result.isSuccess {
                    DispatchQueue.main.asyncAfter(delay: 2) { [weak self] in
                        guard let self else { return }
                        persistentSaveState(stateName: result.path.lastPathComponent,
                                            image: self.snapShotFor3DS(topOnly: true)?.first,
                                            statePath: result.path,
                                            stateData: nil)
                    }
                }
            }
            
        } else if manicGame.isLibretroType {
            LibretroCore.sharedInstance().snapshot { snapshot in
                var image = snapshot
                if (self.manicGame.gameType == .ds || self.manicGame.isAzahar3DS), let i = image {
                    image = self.snapShotForDualScreen(topOnly: true, source: i)?.first
                }
                LibretroCore.sharedInstance().saveState { [weak self] statePath in
                    guard let self else { return }
                    if let statePath {
                        persistentSaveState(stateName: self.manicGame.fileName,
                                            image: image,
                                            statePath: statePath,
                                            stateData: nil)
                    }
                }
            }
            
        } else if manicGame.isJGenesisCore {
            jGenesisCore?.saveState { [weak self] data in
                guard let self else { return }
                if let data {
                    persistentSaveState(stateName: self.manicGame.fileName,
                                        image: jGenesisCore?.snapShot(),
                                        statePath: nil,
                                        stateData: data)
                }
            }
        }
    }
    
    private func loadState(_ state: GameSaveState?) {
        let now = Date.now
        if let lastLoadDate = lastLoadDate,
           now.timeIntervalSince1970ms - lastLoadDate.timeIntervalSince1970ms < (manicGame.isCitra3DS ?  5000 : 1000) {
            UIView.makeToast(message: R.string.localizable.loadStateTooFrequent(), identifier: "loadStateTooFrequent")
            return
        }
        
        if let state = state ?? manicGame.gameSaveStates.last {
            if manicGame.isCitra3DS {
                if let citraCore {
                    let slotFromName = UInt32(state.name.deletingPathExtension.pathExtension)
                    let slotFromFile = state.stateData.flatMap {
                        UInt32($0.filePath.lastPathComponent.deletingPathExtension.pathExtension)
                    }
                    let slot = slotFromName ?? slotFromFile ?? 1
                    // Copy into Citra's `{titleId}.{slot:02d}.cst` before the core loads that slot.
                    if let fileUrl = state.stateData?.filePath {
                        citraCore.addSaveState(fileUrl: fileUrl, slot: slot)
                    }
                    citraCore.loadState(slot)
                    UIView.makeToast(message: R.string.localizable.gameSaveStateLoadSuccess())
                    lastLoadDate = Date.now
                    updateCheatCodes()
                } else {
                    UIView.makeToast(message: R.string.localizable.loadSaveStateFailed())
                }
                
            } else if manicGame.isLibretroType {
                if let statePath = state.stateData?.filePath.path,
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
                    UIView.makeToast(message: R.string.localizable.loadSaveStateFailed())
                }
                
            } else if manicGame.isJGenesisCore {
                if let statePath = state.stateData?.filePath.path {
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
                            UIView.makeToast(message: R.string.localizable.loadSaveStateFailed())
                        }
                    }
                }
            }
        }
    }
    
    private func handleGameInput(_ inputStringValue: String) {
        //点击menu弹出菜单
        if inputStringValue == "menu" {
            if GameOptionsView.hasShownInstance {
                UIView.hideAllAlert { [weak self] in
                    self?.resumeEmulationAndHandleAudio()
                }
            } else {
                pauseEmulationIfNeed()
                if UIDevice.isPhone && UIDevice.isPortrait {
                    var prefferedMenuHeight = view.height - gameView.frame.maxY
                    if prefferedMenuHeight < R.Size.WindowHeight/3 {
                        prefferedMenuHeight = R.Size.SheetWindowMaxSize.height/2
                    }
                    GameOptionsView.MaxHeightForGaming = max(prefferedMenuHeight, R.Size.SheetWindowMinSize.height)
                }
                GameOptionsView.show(scene: .gaming, games: [manicGame], hideCompletion: { [weak self] option in
                    guard let self else { return }
                    if let option {
                        if option == .volume {
                            self.skinSwitchBindDatas["volume"] = self.manicGame.volume
                        } else if option == .hideControls {
                            self.skinSwitchBindDatas["toggleControlls"] = self.manicGame.forceFullSkin
                        } else if option == .swapScreen {
                            self.skinSwitchBindDatas["reverseScreens"] = self.manicGame.swapScreen
                        }
                    }
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
                                                           gameId: manicGame.id,
                                                           gameType: manicGame.gameType)
                    vc.didCompletion = { [weak self] _ in
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
            
            snapShot(completion: { images in
                if let images {
                    updateFlex(images: images)
                } else {
                    updateFlex(images: [])
                }
            })
        } else if let mappingKey = MappingOption(rawValue: inputStringValue) {
            
            guard MappingOption.availableOptions(games: [manicGame]).contains(where: { $0 == mappingKey }) else { return }
            
            if let gameOption = mappingKey.gameOption {
                gameOption.performAction(with: [manicGame], performImmediately: true)
            } else if mappingKey == .j2meSettings || mappingKey == .dosSettings {
                GameOption.coreSettings.performAction(with: [manicGame])
            } else if mappingKey == .fastForward2x ||
                        mappingKey == .fastForward3x ||
                        mappingKey == .fastForward4x ||
                        mappingKey == .fastForward {
                if !PurchaseManager.isMember {
                    updateFastforward(speed: .two)
                } else {
                    if manicGame.speed.rawValue < GameOption.FastForwardSpeed.five.rawValue {
                        let speed: GameOption.FastForwardSpeed
                        if mappingKey == .fastForward2x {
                            speed = .two
                        } else if mappingKey == .fastForward3x {
                            speed = .three
                        } else if mappingKey == .fastForward4x {
                            speed = .four
                        } else {
                            speed = .five
                        }
                        Log.debug("长按速度: \(speed.rawValue)x")
                        updateFastforward(speed: speed)
                    }
                }
            } else if mappingKey == .tvType {
                update2600TvColor(isInit: false)
            } else if mappingKey == .leftDifficulty {
                update2600LeftDifficulty(isInit: false)
            } else if mappingKey == .rightDifficulty {
                update2600RightDifficulty(isInit: false)
            } else if mappingKey == .useKeyboardSkin {
                guard manicGame.gameType.supportsKeyboardSkin else {
                    UIView.makeToast(message: R.string.localizable.notSupportGameSetting(manicGame.gameType.localizedShortName))
                    return
                }
                let realm = Database.realm
                let keyboardSkinID = "\(manicGame.gameType.rawValue).standard.keyboard"
                if let skin = realm.objects(Skin.self).where({
                    $0.gameType == manicGame.gameType &&
                    $0.skinType == .buildIn &&
                    $0.identifier == keyboardSkinID
                }).first {
                    Prefference.defalut.storePrefference(kind: .skin,
                                                         storeKey: .orientationKey(gameId: manicGame.id, isLandScape: true),
                                                         storeValue: skin.id)
                    Prefference.defalut.storePrefference(kind: .skin,
                                                         storeKey: .orientationKey(gameId: manicGame.id),
                                                         storeValue: skin.id)
                    updateSkin()
                }
            } else if mappingKey == .useJoypadSkin {
                guard manicGame.gameType.supportsKeyboardSkin else {
                    UIView.makeToast(message: R.string.localizable.notSupportGameSetting(manicGame.gameType.localizedShortName))
                    return
                }
                let realm = Database.realm
                if let skin = realm.objects(Skin.self).where({ $0.gameType == manicGame.gameType && $0.skinType == .default }).first {
                    Prefference.defalut.storePrefference(kind: .skin,
                                                         storeKey: .orientationKey(gameId: manicGame.id, isLandScape: true),
                                                         storeValue: skin.id)
                    Prefference.defalut.storePrefference(kind: .skin,
                                                         storeKey: .orientationKey(gameId: manicGame.id),
                                                         storeValue: skin.id)
                    updateSkin()
                }
            } else if mappingKey == .rewind {
                guard !isHardcoreMode else {
                    UIView.makeToast(message: R.string.localizable.notAllowHardcore())
                    return
                }
                guard !isWFCConnect else {
                    UIView.makeToast(message: R.string.localizable.notAllowOnlineGame())
                    return
                }
                LibretroCore.sharedInstance().setRewind(true)
            }
        }
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
    
    var isPaused: Bool {
        if manicGame.isCitra3DS, let citraCore {
            return citraCore.isPaused
        } else if manicGame.isLibretroType {
            return LibretroCore.sharedInstance().isPaused()
        } else if manicGame.isJGenesisCore, let jGenesisCore {
            return jGenesisCore.isPaused
        } else if manicGame.isJ2MECore, let j2meCore {
            return j2meCore.isPaused
        }
        return false
    }
    
    @discardableResult
    private func pauseEmulationIfNeed() -> Bool {
        guard !isWFCConnect else {
            return false
        }
        var didPause = false
        if manicGame.isCitra3DS {
            citraCore?.pause()
            didPause = true
        } else if manicGame.isLibretroType {
            LibretroCore.sharedInstance().pause()
            didPause = true
        } else if manicGame.isJGenesisCore {
            jGenesisCore?.pause()
            didPause = true
        } else if manicGame.isJ2MECore {
            j2meCore?.pause()
            didPause = true
        }
        if didPause {
            releaseHeldExternalCoreInputs()
            PlayViewController.refreshExternalInputSink()
        }
        return didPause
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
        PlayViewController.refreshExternalInputSink()
        replayHeldExternalCoreInputs()
    }
    
    /// Release mapped core / function keys so pause does not leave a stuck input.
    private func releaseHeldExternalCoreInputs() {
        guard let emulatorCore else { return }
        for controller in ExternalGameControllerManager.shared.connectedControllers {
            let held = controller.activatedInputs
            for (physicalInput, _) in held {
                if let mapped = controller.mappedInput(for: physicalInput, receiver: emulatorCore) {
                    emulatorCore.gameController(controller, didDeactivate: mapped)
                }
                if let mapped = controller.mappedInput(for: physicalInput, receiver: self) {
                    gameController(controller, didDeactivate: mapped)
                }
            }
        }
    }
    
    /// Re-apply still-held analog sticks after resume. Digital buttons are not replayed
    /// so closing a menu while holding A cannot fire an in-game confirm.
    private func replayHeldExternalCoreInputs() {
        guard ExternalInputDispatch.sink == .gameplay else { return }
        guard let emulatorCore else { return }
        for controller in ExternalGameControllerManager.shared.connectedControllers {
            for (physicalInput, value) in controller.activatedInputs {
                guard physicalInput.isContinuous else { continue }
                if let mapped = controller.mappedInput(for: physicalInput, receiver: emulatorCore) {
                    emulatorCore.gameController(controller, didActivate: mapped, value: value)
                }
            }
        }
    }
    
    private func removeExternalGameControllerReceivers() {
        for controller in ExternalGameControllerManager.shared.connectedControllers {
            controller.removeReceiver(self)
            if let emulatorCore {
                controller.removeReceiver(emulatorCore)
            }
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
                    let cheatFilePath = R.Path.ThreeDS.appendingPathComponent("cheats/\(String(format: "%016llX.txt", identifier))")
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
                var enableCheats: [String] = []
                for cheatCode in manicGame.gameCheats {
                    if cheatCode.activate {
                        cheatsTxt += "_C1 \(cheatCode.name)\n\(cheatCode.code)\n"
                        enableCheats.append("\(cheatCode.name)")
                    }
                }
                let cheatFilePath = R.Path.PSPCheat(gameCode: gameCode)
                if firstInit {
                    LibretroCore.sharedInstance().updatePSPCheat(cheatsTxt, cheatFilePath: cheatFilePath, reloadGame: false)
                    lastPSPCheatCode = cheatsTxt
                } else if cheatsTxt != lastPSPCheatCode {
                    LibretroCore.sharedInstance().updatePSPCheat(cheatsTxt, cheatFilePath: cheatFilePath, reloadGame: true)
                    lastPSPCheatCode = cheatsTxt
                    UIView.makeToast(message: R.string.localizable.gameCheatActivateSuccess(String.successMessage(from: enableCheats)))
                }
            }
        } else if manicGame.isLibretroType {
            DispatchQueue.main.asyncAfter(delay: manicGame.isPicodriveCore && firstInit ? 1 : 0) {
                if self.manicGame.gameType == .arcade, self.manicGame.defaultCore == 1, firstInit, !self.isHardcoreMode {
                    //FBNeo激活作弊码
                    if let configs = LibretroCore.sharedInstance().getConfigs(EmulationCore.FinalBurnNeo.name) {
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
                            UIView.makeToast(message: R.string.localizable.gameCheatActivateSuccess(String.successMessage(from: needToActivedKeys)))
                        }
                    }
                } else {
                    LibretroCore.sharedInstance().resetCheatCode()
                    var enableCheats: [String] = []
                    for (index, cheatCode) in self.manicGame.gameCheats.enumerated() {
                        if cheatCode.activate {
                            // Convert newline separators to '+' (libretro standard for multi-line cheats)
                            let coreCode: String
                            if CheatType(cheatCode.type) == .actionReplay16, self.manicGame.isPicodriveCore, cheatCode.code.count > 6 {
                                // PicoDrive rejects 0123456789; it needs 012345:6789
                                coreCode = cheatCode.code[...5] + ":" + cheatCode.code[6...]
                            } else if self.manicGame.isDolphinCore, CheatType(cheatCode.type) == .ARMax {
                                // Stock Dolphin retro_cheat_set only matches decrypted Action Replay.
                                guard let decrypted = ARMaxDecrypt.toActionReplay(cheatCode.code) else { continue }
                                coreCode = decrypted
                            } else {
                                coreCode = cheatCode.code.replacingOccurrences(of: "\n", with: "+")
                            }
                            LibretroCore.sharedInstance().addCheatCode(String(coreCode), index: UInt32(index), enable: true)
                            enableCheats.append("\(cheatCode.name)")
                        }
                    }
                    if enableCheats.count > 0 {
                        UIView.makeToast(message: R.string.localizable.gameCheatActivateSuccess(String.successMessage(from: enableCheats)))
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
        guard manicGame.supportGlslShaders || manicGame.supportSlangShaders else { return }
        guard manicGame.isLibretroType else { return }
        
        let shaderPath = Prefference.defalut.getPrefference(kind: .shader,
                                                            storeKey: .shaderKey(gameId: manicGame.id,
                                                                                 isGlsl: manicGame.supportGlslShaders),
                                                            bestEfforts: true)?.shaderValue
        if shaderPath == nil || shaderPath == "" {
            LibretroCore.sharedInstance().setShader(nil)
        } else if let shaderPath {
            LibretroCore.sharedInstance().setShader(R.Path.Shaders.appendingPathComponent(shaderPath))
        }
        
        updateDualScreenViews()
    }
    
    private func stopShader() {
        LibretroCore.sharedInstance().setShader(nil)
    }
    
    //加载默认配置
    private func loadConfig() {
        let enableAchievements = manicGame.safeMode ? false : manicGame.enableAchievements
        isHardcoreMode = enableAchievements ? manicGame.enableHarcore : false
        
        if !manicGame.safeMode {
            //non safe mode
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
                            self.loadState(saveState)
                        }
                    } else if self.manicGame.isLibretroType {
                        var delay = 0.0
                        if self.manicGame.gameType == .arcade || self.manicGame.isAzahar3DS {
                            delay = 4.0
                        }
                        DispatchQueue.main.asyncAfter(delay: delay) {
                            self.loadState(saveState)
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
        }
        
        if manicGame.safeMode {
            //safe mode
            if manicGame.gameType == .psp {
                updateLibretroCoreConfigs(core: .PPSSPP, configs: [
                    .ppsspp_cheats: "enabled",
                    .ppsspp_language: "Automatic",
                    .ppsspp_backend: "auto",
                    .ppsspp_texture_replacement: "disabled",
                    .ppsspp_enable_wlan: "disabled",
                    .ppsspp_internal_resolution: "480x272",
                    .ppsspp_cpu_core: "Interpreter"
                ], safeMode: true)
            } else if manicGame.gameType == .nes || manicGame.gameType == .fds {
                updateLibretroCoreConfigs(core: .Nestopia, configs: [
                    .nestopia_palette: "cxa2025as"
                ], safeMode: true)
            } else if manicGame.gameType == .snes {
                if manicGame.defaultCore == 0 {
                    updateLibretroCoreConfigs(core: .bsnes, configs: [
                        .bsnes_ppu_no_vram_blocking: "OFF"
                    ], safeMode: true)
                } else if manicGame.defaultCore == 1 {
                    updateLibretroCoreConfigs(core: .Snes9x, configs: [
                        .snes9x_block_invalid_vram_access: "enabled"
                    ], safeMode: true)
                }
            } else if manicGame.isPicodriveCore {
                updateLibretroCoreConfigs(core: .PicoDrive, configs: [:], safeMode: true)
            } else if manicGame.isClownMDEmuCore {
                let tvStandard = (manicGame.getExtraInt(key: ExtraKey.tvStandard.rawValue) ?? 0) == 0 ? "ntsc" : "pal"
                updateLibretroCoreConfigs(core: .ClownMDEmu, configs: [
                    .clownmdemu_tv_standard: tvStandard
                ], safeMode: true)
                if manicGame.gameType == .mcd {
                    MCD.isJGenesisCore = false
                }
            } else if manicGame.gameType == .ss {
                if manicGame.defaultCore == 0 {
                    updateLibretroCoreConfigs(core: .Yabause, configs: [:], safeMode: true)
                } else {
                    updateLibretroCoreConfigs(core: .BeetleSaturn, configs: [
                        .beetle_saturn_region: "Auto Detect"
                    ], safeMode: true)
                }
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
                    updateLibretroCoreConfigs(core: .melonDSDS, configs: [
                        .melonds_firmware_language: "auto",
                        .melonds_console_mode: systemType,
                        .melonds_mic_input: "silence",
                        .melonds_jit_enable: "disabled"
                    ], safeMode: true)
                    //wfc
                    LibretroCore.sharedInstance().setNDSWFCDNS( WFC.currentDNS());
                    DSEmulatorBridge.shared.isDeSmuMECore = false
                } else {
                    //DeSmuME
                    updateLibretroCoreConfigs(core: .DeSmuME, configs: [
                        .desmume_internal_resolution: "256x192",
                        .desmume_firmware_language: "Auto",
                        .desmume_mic_mode: "physical"
                    ], safeMode: true)
                    DSEmulatorBridge.shared.isDeSmuMECore = true
                }
            } else if manicGame.gameType == .gba {
                if manicGame.defaultCore == 1 {
                    updateLibretroCoreConfigs(core: .VBAM, configs: [.vbam_gbHardware: "gba"], safeMode: true)
                }
            } else if manicGame.gameType == .gbc {
                if manicGame.defaultCore == 0 {
                    updateLibretroCoreConfigs(core: .Gambatte, configs: [:], safeMode: true)
                } else if manicGame.defaultCore == 2 {
                    updateLibretroCoreConfigs(core: .VBAM, configs: [
                        .vbam_gbHardware: "gbc"
                    ], safeMode: true)
                }
            } else if manicGame.gameType == .gb {
                if manicGame.defaultCore == 0 {
                    updateLibretroCoreConfigs(core: .Gambatte, configs: [
                        .gambatte_gb_colorization: "disabled",
                        .gambatte_gb_internal_palette: "GB - DMG"
                    ], safeMode: true)
                } else if manicGame.defaultCore == 1 {
                    updateLibretroCoreConfigs(core: .mGBA, configs: [
                        .mgba_gb_colors: "Grayscale"
                    ], safeMode: true)
                } else if manicGame.defaultCore == 2 {
                    updateLibretroCoreConfigs(core: .VBAM, configs: [
                        .vbam_gbHardware: "gb",
                        .vbam_palettes: "black and white"
                    ], safeMode: true)
                }
            } else if manicGame.gameType == .n64 {
                updateLibretroCoreConfigs(core: .Mupen64PlushNext, configs: [
                    .mupen64plus_cpucore: "cached_interpreter",
                    .mupen64plus_43screensize: "640x480",
                    .mupen64plus_rdp_plugin: "gliden64",
                    .mupen64plus_pak1: "memory"
                ], safeMode: true)
            } else if manicGame.gameType == .vb {
                updateLibretroCoreConfigs(core: .BeetleVB, configs: [
                    .vb_color_mode: manicGame.pallete.paletteTitleForVB
                ], safeMode: true)
            } else if manicGame.gameType == .pm {
                updateLibretroCoreConfigs(core: .PokeMini, configs: [
                    .pokemini_palette: "black & red"
                ], safeMode: true)
            } else if manicGame.gameType == .ps1 && manicGame.defaultCore == 0 {
                updateLibretroCoreConfigs(core: .BeetlePSXHW, configs: [
                    .beetle_psx_hw_internal_resolution: "1x",
                    .beetle_psx_hw_override_bios: "disabled",
                    .beetle_psx_hw_renderer: "hardware_vk",
                    .beetle_psx_hw_cpu_dynarec: "disabled",
                ], safeMode: true)
            } else if manicGame.gameType == .dc {
                updateLibretroCoreConfigs(core: .Flycast, configs: [
                    .reicast_internal_resolution: "640x480",
                    .reicast_language : "Default"
                ], safeMode: true)
            } else if manicGame.gameType == .arcade {
                if manicGame.defaultCore == 0 {
                    updateLibretroCoreConfigs(core: .MAME, configs: [:], safeMode: true)
                    LibretroCore.sharedInstance().setLibretroLogMonitor(true)
                }
            } else if manicGame.gameType == ._3ds {
                ThreeDS.isAzaharCore = manicGame.isAzahar3DS
                if manicGame.isAzahar3DS {
                    updateLibretroCoreConfigs(core: .Azahar, configs: [
                        .citra_use_cpu_jit: "disabled",
                        .citra_use_default_aes_key: manicGame.isAzaharArticBase || manicGame.isArticBaseHomeMenu || manicGame.is3DSHomeMenuGame ? "enabled" : "disabled",
                        .citra_required_online_lle_modules: manicGame.isArticBaseHomeMenu ? "enabled" : "disabled",
                        .citra_motion_rotation: Self.citraMotionRotationValue()
                    ], safeMode: true)
                    // Never start Azahar with fast-forward; it can crash on boot.
                    Game.change { realm in
                        self.manicGame.speed = .one
                    }
                }
            } else if manicGame.gameType == ._32x {
                S2X.isJGenesisCore = manicGame.defaultCore == 1
            } else if manicGame.gameType == .mcd {
                MCD.isJGenesisCore = manicGame.defaultCore == 1
            } else if manicGame.gameType == .a2600 {
                updateLibretroCoreConfigs(core: .Stella, configs: [:], safeMode: true)
                self.update2600TvColor(isInit: true)
                self.update2600LeftDifficulty(isInit: true)
                self.update2600RightDifficulty(isInit: true)
                self.updateSkin()
            } else if manicGame.gameType == .a5200 {
                updateLibretroCoreConfigs(core: .Atari800, configs: [:], safeMode: true)
            } else if manicGame.gameType == .jaguar {
                updateLibretroCoreConfigs(core: .VirtualJaguar, configs: [:], safeMode: true)
            } else if manicGame.gameType == .doom  {
                updateLibretroCoreConfigs(core: .PrBoom, configs: [.prboom_resolution: "320x200"], safeMode: true)
            } else if manicGame.gameType == .dos {
                updateLibretroCoreConfigs(core: .DOSBoxPure, configs: [:])
            } else if manicGame.gameType == .symbian {
                var deviceIndex: Int? = nil
                if let app = manicGame.symbianSystemApp {
                    deviceIndex = app.deviceIndex
                }
                updateLibretroCoreConfigs(core: .EKA2L1, configs: [
                    .eka2l1_cpu_backend: "dyncom",
                    .eka2l1_device_index: "\(deviceIndex ?? manicGame.usingSymbianDeviceIndex ?? 0)"
                ])
                LibretroCore.sharedInstance().setLibretroLogMonitor(true)
            } else if manicGame.isDolphinCore {
                updateLibretroCoreConfigs(core: .Dolphin, configs: [:])
            } else if manicGame.gameType == .amiga {
                LibretroCore.sharedInstance().setLibretroLogMonitor(true)
            }
        } else {
            //non safe mode
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
                var networkingConfigs = [SpecialCoreOption: String]()
                LibretroCore.sharedInstance().setPSPCustomServerAddress(nil)
                LibretroCore.sharedInstance().setPSPCustomServerPort(nil)
                if networkingConfig.enable, networkingConfig.type == .local, networkingConfig.asHost {
                    //本地网络 作为主机
                    networkingConfigs += [.ppsspp_enable_wlan: "enabled",
                                          .ppsspp_enable_builtin_pro_ad_hoc_server: "enabled",
                                          .ppsspp_change_pro_ad_hoc_server_address: "IP address"]
                    if let ipAddress = BonjourKit.shared.currentIPAddress, let hostResult = (ipAddress+":\(networkingConfig.asHostPort)").parseIPv4() {
                        for (index, ip) in hostResult.ips.enumerated() {
                            if let addressKey = SpecialCoreOption.ppssppServerAddressConfig(index: (index < 9 ? "0\(index+1)" : "\(index+1)")) {
                                networkingConfigs[addressKey] = "\(ip)"
                            }
                        }
                        networkingConfigs[.ppsspp_port_offset] = "\(hostResult.port)"
                        LibretroCore.sharedInstance().setPSPCustomServerPort("\(hostResult.port)")
                    }
                    LibretroCore.sharedInstance().setPSPCustomServerPort("\(networkingConfig.asHostPort)")
                } else if networkingConfig.enable, networkingConfig.type == .local, !networkingConfig.asHost, let ip = networkingConfig.connectedLocalIP {
                    //本地网络 作为从机
                    networkingConfigs += [
                        .ppsspp_enable_wlan: "enabled",
                        .ppsspp_enable_builtin_pro_ad_hoc_server: "disabled",
                        .ppsspp_change_pro_ad_hoc_server_address: "IP address"
                    ]
                    if let hostResult = ip.parseIPv4() {
                        for (index, ip) in hostResult.ips.enumerated() {
                            if let addressKey = SpecialCoreOption.ppssppServerAddressConfig(index: (index < 9 ? "0\(index+1)" : "\(index+1)")) {
                                networkingConfigs[addressKey] = "\(ip)"
                            }
                        }
                        networkingConfigs[.ppsspp_port_offset] = "\(hostResult.port)"
                        LibretroCore.sharedInstance().setPSPCustomServerPort("\(hostResult.port)")
                    } else {
                        networkingConfigs[.ppsspp_change_pro_ad_hoc_server_address] = ip
                        LibretroCore.sharedInstance().setPSPCustomServerAddress(ip)
                    }
                } else if networkingConfig.enable, networkingConfig.type == .online {
                    //互联网络
                    networkingConfigs += [.ppsspp_enable_wlan: "enabled",
                                          .ppsspp_enable_builtin_pro_ad_hoc_server: "disabled",
                                          .ppsspp_change_pro_ad_hoc_server_address: networkingConfig.connectedHost]
                    if !["socom.cc", "psp.gameplayer.club", "myneighborsushicat.com"].contains(where: { $0 == networkingConfig.connectedHost }) {
                        LibretroCore.sharedInstance().setPSPCustomServerAddress(networkingConfig.connectedHost)
                    }
                } else {
                    //禁用网络
                    networkingConfigs += [.ppsspp_enable_wlan: "disabled"]
                }
                
                //jit
                let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
                if enableJIT {
                    setupUniversalScript(gameType: .psp)
                }
                let jitValue = ((manicGame.getExtraInt(key: ExtraKey.jitType.rawValue) ?? 0) == 0) ? "JIT" : "IR JIT"
                updateLibretroCoreConfigs(core: .PPSSPP, configs: [
                    .ppsspp_language: languages[manicGame.region],
                    .ppsspp_backend: backend,
                    .ppsspp_texture_replacement: (manicGame.getExtraBool(key: ExtraKey.pspTexture.rawValue) ?? false) ? "enabled" : "disabled",
                    .ppsspp_cpu_core : enableJIT ? jitValue : "Interpreter"
                ] + networkingConfigs)
                updatePSPResolution(manicGame.resolution, reload: false)
                
            } else if manicGame.gameType == .nes || manicGame.gameType == .fds {
                updateNESPalette(manicGame.currentNesPalette, firstInit: true)
                updateLibretroCoreConfigs(core: .Nestopia, configs: [:])
            } else if manicGame.gameType == .snes {
                let snesVRAM = manicGame.getExtraBool(key: ExtraKey.snesVRAM.rawValue) ?? false
                if manicGame.defaultCore == 0 {
                    updateLibretroCoreConfigs(core: .bsnes, configs: [
                        .bsnes_ppu_no_vram_blocking: (snesVRAM ? "ON" : "OFF")
                    ])
                } else if manicGame.defaultCore == 1 {
                    updateLibretroCoreConfigs(core: .Snes9x, configs: [
                        .snes9x_block_invalid_vram_access: snesVRAM ? "disabled" : "enabled"
                    ])
                }
            } else if manicGame.isPicodriveCore {
                updateLibretroCoreConfigs(core: .PicoDrive, configs: [:])
            } else if manicGame.isClownMDEmuCore {
                updateLibretroCoreConfigs(core: .ClownMDEmu, configs: [
                    .clownmdemu_tv_standard: ((manicGame.getExtraInt(key: ExtraKey.tvStandard.rawValue) ?? 0) == 0 ? "ntsc" : "pal")
                ])
                if manicGame.gameType == .mcd {
                    MCD.isJGenesisCore = false
                }
            } else if manicGame.gameType == .ss {
                if manicGame.defaultCore == 0 {
                    updateLibretroCoreConfigs(core: .Yabause, configs: [:])
                } else if manicGame.defaultCore == 1 {
                    updateLibretroCoreConfigs(core: .BeetleSaturn, configs: [
                        .beetle_saturn_region: R.Strings.SaturnConsoleLanguage[manicGame.region]
                    ])
                }
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
                    updateLibretroCoreConfigs(core: .melonDSDS, configs: [
                        .melonds_firmware_language: dsLanguageOption,
                        .melonds_console_mode: systemType,
                        .melonds_mic_input: microphone ? "microphone" : "silence",
                        .melonds_jit_enable: enableJIT ? "enabled" : "disabled"
                    ])
                    //wfc
                    LibretroCore.sharedInstance().setNDSWFCDNS( WFC.currentDNS());
                    DSEmulatorBridge.shared.isDeSmuMECore = false
                } else {
                    //DeSmuME
                    let languageOptions = R.Strings.DSConsoleLanguage
                    var languageOption = languageOptions.first!
                    if manicGame.region > 0 && manicGame.region < languageOptions.count {
                        languageOption = languageOptions[manicGame.region]
                    }
                    let scale = UInt32(manicGame.resolution == .undefine ? 1 : manicGame.resolution.rawValue)
                    let option = "\(256*scale)x\(192*scale)"
                    let microphone = manicGame.getExtraBool(key: ExtraKey.microphone.rawValue) ?? false
                    updateLibretroCoreConfigs(core: .DeSmuME, configs: [
                        .desmume_internal_resolution: option,
                        .desmume_firmware_language: languageOption,
                        .desmume_mic_mode: microphone ? "physical" : "pattern"
                    ])
                    DSEmulatorBridge.shared.isDeSmuMECore = true
                }
            } else if manicGame.gameType == .gba {
                if manicGame.defaultCore == 1 {
                    updateLibretroCoreConfigs(core: .VBAM, configs: [:])
                }
            } else if manicGame.gameType == .gbc {
                if manicGame.defaultCore == 0 {
                    updateLibretroCoreConfigs(core: .Gambatte, configs: [:])
                } else if manicGame.defaultCore == 2 {
                    updateLibretroCoreConfigs(core: .VBAM, configs: [:])
                }
            } else if manicGame.gameType == .gb {
                if manicGame.defaultCore == 0 {
                    updateLibretroCoreConfigs(core: .Gambatte, configs: [
                        .gambatte_gb_colorization: manicGame.pallete == .None ? "disabled" : "internal",
                        .gambatte_gb_internal_palette: manicGame.pallete.optionForGambatte
                    ])
                } else if manicGame.defaultCore == 1 {
                    updateLibretroCoreConfigs(core: .mGBA, configs: [
                        .mgba_gb_colors: manicGame.pallete.optionForMGBA
                    ])
                } else if manicGame.defaultCore == 2 {
                    updateLibretroCoreConfigs(core: .VBAM, configs: [
                        .vbam_palettes: manicGame.pallete.optionForVBAM
                    ])
                }
            } else if manicGame.gameType == .n64 {
                let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
                if enableJIT {
                    setupUniversalScript(gameType: .n64)
                }
                updateLibretroCoreConfigs(core: .Mupen64PlushNext, configs: [
                    .mupen64plus_cpucore: (enableJIT ? "dynamic_recompiler" : "cached_interpreter"),
                    .mupen64plus_rdp_plugin: (manicGame.isN64ParaLLEl ? "parallel" : "gliden64"),
                    .mupen64plus_pak1: manicGame.hasTransferPak ? "transfer" : "memory"
                ])
                updateN64Resolution(manicGame.resolution, reload: false)
            } else if manicGame.gameType == .vb {
                updateLibretroCoreConfigs(core: .BeetleVB, configs: [
                    .vb_color_mode: manicGame.pallete.paletteTitleForVB
                ])
            } else if manicGame.gameType == .pm {
                updateLibretroCoreConfigs(core: .PokeMini, configs: [
                    .pokemini_palette: manicGame.pallete.paletteTitleForPM
                ])
            } else if manicGame.gameType == .ps1, manicGame.defaultCore == 0 {
                let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
                if enableJIT {
                    setupUniversalScript(gameType: .ps1)
                }
                let isHardwareRenderer = manicGame.getExtraBool(key: ExtraKey.psxRenderer.rawValue) ?? true
                
                updateLibretroCoreConfigs(core: .BeetlePSXHW, configs: [
                    .beetle_psx_hw_internal_resolution: manicGame.resolution.resolutionTitleForPS1,
                    .beetle_psx_hw_override_bios: manicGame.ps1OverrideBios,
                    .beetle_psx_hw_renderer: isHardwareRenderer ? "hardware_vk" : "software",
                    .beetle_psx_hw_cpu_dynarec: enableJIT ? "execute" : "disabled"
                ])
            } else if manicGame.gameType == .dc {
                if LibretroCore.jitAvailable(), manicGame.jit {
                    setupUniversalScript(gameType: .dc)
                }
                updateDCResolution(manicGame.resolution, reload: false)
                updateLibretroCoreConfigs(core: .Flycast, configs: [
                    .reicast_language : R.Strings.DCConsoleLanguage[manicGame.region]
                ])
            } else if manicGame.gameType == .arcade {
                if manicGame.defaultCore == 0 {
                    updateLibretroCoreConfigs(core: .MAME, configs: [:])
                    LibretroCore.sharedInstance().setLibretroLogMonitor(true)
                }
            } else if manicGame.gameType == ._3ds {
                ThreeDS.isAzaharCore = manicGame.isAzahar3DS
                if manicGame.isAzahar3DS {
                    let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
                    if enableJIT {
                        setupUniversalScript(gameType: ._3ds)
                    }
                    let enableLLE = (manicGame.isArticBaseHomeMenu || (manicGame.getExtraInt(key: ExtraKey.emulationAccuracy.rawValue) ?? 0 == 1)) ? true : false
                    updateLibretroCoreConfigs(core: .Azahar, configs: [
                        .citra_use_cpu_jit: enableJIT ? "enabled" : "disabled",
                        .citra_use_default_aes_key: manicGame.isAzaharArticBase || manicGame.isArticBaseHomeMenu || manicGame.is3DSHomeMenuGame ? "enabled" : "disabled",
                        .citra_required_online_lle_modules: enableLLE ? "enabled" : "disabled",
                        .citra_motion_rotation: Self.citraMotionRotationValue()
                    ])
                    // Never start Azahar with fast-forward; it can crash on boot.
                    Game.change { realm in
                        self.manicGame.speed = .one
                    }
                }
            } else if manicGame.gameType == ._32x {
                S2X.isJGenesisCore = manicGame.defaultCore == 1
            } else if manicGame.gameType == .mcd {
                MCD.isJGenesisCore = manicGame.defaultCore == 1
            } else if manicGame.gameType == .a2600 {
                updateLibretroCoreConfigs(core: .Stella, configs: [:])
                self.update2600TvColor(isInit: true)
                self.update2600LeftDifficulty(isInit: true)
                self.update2600RightDifficulty(isInit: true)
                self.updateSkin()
            } else if manicGame.gameType == .a5200 {
                updateLibretroCoreConfigs(core: .Atari800, configs: [:])
            } else if manicGame.gameType == .jaguar {
                updateLibretroCoreConfigs(core: .VirtualJaguar, configs: [:])
            } else if manicGame.gameType == .doom {
                let scale = UInt32(manicGame.resolution == .undefine ? 1 : manicGame.resolution.rawValue)
                let option = "\(320*scale)x\(200*scale)"
                updateLibretroCoreConfigs(core: .PrBoom, configs: [
                    .prboom_resolution: option
                ])
            } else if manicGame.gameType == .dos {
                //jit
                let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
                if enableJIT {
                    setupUniversalScript(gameType: .dos)
                }
                updateLibretroCoreConfigs(core: .DOSBoxPure, configs: [
                    .dosbox_pure_cpu_core: enableJIT ? "dynamic" : "normal"
                ])
            } else if manicGame.gameType == .symbian {
                let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
                if enableJIT {
                    setupUniversalScript(gameType: .symbian)
                }
                updateLibretroCoreConfigs(core: .EKA2L1, configs: [
                    .eka2l1_cpu_backend: enableJIT ? "dynarmic" : "dyncom",
                    .eka2l1_device_index: "\(manicGame.usingSymbianDeviceIndex ?? 0)"
                ])
                LibretroCore.sharedInstance().setLibretroLogMonitor(true)
            } else if manicGame.isDolphinCore {
                var enableManicInterpreter = true
                let enableJIT = LibretroCore.jitAvailable() && manicGame.jit
                if enableJIT {
                    setupUniversalScript(gameType: manicGame.gameType)
                } else {
                    enableManicInterpreter = manicGame.getExtraBool(key: ExtraKey.dolphinManicInterpreter.rawValue) ?? true
                }
                //4: JITARM64 5: Cached Interpreter 6: Manic Interpreter
                 
                updateLibretroCoreConfigs(core: .Dolphin, configs: [
                    .dolphin_cpu_core: enableJIT ? "4" : (enableManicInterpreter ? "6" : "5"),
                    .dolphin_cheats_enabled: isHardcoreMode ? "disabled" : "enabled"
                ])
            } else if manicGame.gameType == .amiga {
                LibretroCore.sharedInstance().setLibretroLogMonitor(true)
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
            let enableMircophone: Bool
            if manicGame.safeMode {
                enableMircophone = false
            } else {
                enableMircophone = (manicGame.gameType == .ds && (manicGame.getExtraBool(key: ExtraKey.microphone.rawValue) ?? false)) || manicGame.isAzahar3DS
            }
            
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
            
            if manicGame.safeMode {
                //safe mode
                //RetroAchievements配置
                LibretroCore.sharedInstance().updateLibretroConfig("cheevos_enable", value: "false")
            } else {
                //non safe mode
                //RetroAchievements配置
                if manicGame.supportRetroAchievements, let user = AchievementsUser.getUser() {
                    LibretroCore.sharedInstance().updateLibretroConfigs(["cheevos_enable": enableAchievements ? "true" : "false",
                                                                         "cheevos_hardcore_mode_enable": isHardcoreMode ? "true" : "false",
                                                                         "cheevos_token": user.token,
                                                                         "cheevos_username": user.username])
                    if enableAchievements {
                        setupLeaderboardView()
                        setupAchievementProgressView()
                        setupAchievementChallengeView()
                        if manicGame.gameType == .psp {
                            LibretroCore.sharedInstance().updateConfig(EmulationCore.PPSSPP.name, configs: ["ppsspp_cheats": "disabled"], reload: false)
                        }
                    }
                } else {
                    LibretroCore.sharedInstance().updateLibretroConfig("cheevos_enable", value: "false")
                }
            }
            
            // Save directory must match Game.gameSaveUrl.
            if manicGame.gameType == .gb {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: R.Path.GBSavePath.libretroPath)
            } else if manicGame.gameType == .gbc {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: R.Path.GBCSavePath.libretroPath)
            } else if manicGame.gameType == .gba {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: R.Path.GBASavePath.libretroPath)
            } else if manicGame.gameType == .snes, manicGame.defaultCore == 0 {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: R.Path.bsnes.libretroPath)
            } else if manicGame.gameType == .ds {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: R.Path.DSSavePath.libretroPath)
            } else if manicGame.gameType == .doom {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: R.Path.PrBoom.libretroPath)
            } else if manicGame.gameType == .dos {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: R.Path.DOSBoxPure.libretroPath)
            } else {
                LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: R.Path.LibretroSavePath.libretroPath)
            }
            
            //配置Rumble
            if manicGame.safeMode {
                LibretroCore.sharedInstance().setEnableRumble(false)
            } else {
                LibretroCore.sharedInstance().setEnableRumble(Settings.defalut.getExtraBool(key: ExtraKey.rumble.rawValue) ?? false)
            }
            
            //配置System的位置
            if manicGame.gameType == .dc {
                LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: R.Path.Flycast)
            } else if manicGame.gameType == .dos {
                LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: R.Path.DOSBoxPureSystem.libretroPath)
            } else {
                LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: R.Path.System.libretroPath)
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
        updateScreenScaling()
    }
    
    /// Reload the controller skin for the current orientation and settings.
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
            
            if let result = Prefference.defalut.getPrefference(kind: .skin,
                                                               storeKey: .orientationKey(gameId: manicGame.id, isLandScape: UIDevice.isLandscape),
                                                               bestEfforts: true),
               let skinId = result.skinValue?.skinId,
               let skin = Database.realm.object(ofType: Skin.self, forPrimaryKey: skinId),
               var controllerSkin = ControllerSkin(fileURL: skin.fileURL, initGameType: initGameType, supportGameTypes: supportGameTypes) {
                if manicGame.supportSwapScreen {
                    controllerSkin.isSwapScreen = manicGame.swapScreen
                }
                controllerView.controllerSkin = controllerSkin
                currentSkinID = skin.id
            } else if var controllerSkin = ControllerSkin.standardControllerSkin(for: manicGame.gameType) {
                if manicGame.supportSwapScreen {
                    controllerSkin.isSwapScreen = manicGame.swapScreen
                }
                if manicGame.gameType == .wii,
                   let controllerType = LibretroWiiController(rawValue: manicGame.getExtraInt(key: ExtraKey.wiiController.rawValue) ?? 0),
                   controllerType != .classicPro,
                   let wiimoteSkin = Database.realm.objects(Skin.self).where({
                       $0.identifier == R.Strings.WiimoteSkinIdentifier }).first,
                   let wiimoteControllerSkin = ControllerSkin(fileURL: wiimoteSkin.fileURL) {
                    //If the user has set up a Wiimote controller and hasn't specifically picked a preferred skin, then assign the Wiimote skin to them.
                    controllerView.controllerSkin = wiimoteControllerSkin
                } else {
                    controllerView.controllerSkin = controllerSkin
                }
                // Same dual-orientation skin may only be stored under the other orientation key.
                controllerView.updateControllerSkin()
                
                if let identifier = controllerView.controllerSkin?.identifier,
                   let skin = Database.realm.objects(Skin.self).where({ $0.identifier == identifier }).first {
                    currentSkinID = skin.id
                }
            }
        }
        
        if manicGame.forceFullSkin {
            // Full-screen flex skin.
            let realm = Database.realm
            if let coreName = emulatorCore?.deltaCore.name,
               let skin = realm.objects(Skin.self).where({ $0.fileName == "\(coreName)_FLEX.manicskin" }).first,
               let skinUrl = skin.skinData?.filePath,
               var controllerSkin = ControllerSkin(fileURL: skinUrl) {
                if manicGame.supportSwapScreen {
                    controllerSkin.isSwapScreen = manicGame.swapScreen
                }
                isFullScreen = true
                controllerView.controllerSkin = controllerSkin
                currentSkinID = skin.id
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
        updateShortcutsButton()
        if manicGame.gameType == .ds || (manicGame.gameType == ._3ds && !manicGame.isAzaharArticBase) || (manicGame.gameType.usesDOSSkinLayout && UIDevice.isPad) {
            updateShortcutButtonContainer()
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
    
    /// Azahar / Citra motion rotation: 0 portrait, 1 landscapeLeft, 2 upside down, 3 landscapeRight.
    private static func citraMotionRotationValue(
        for orientation: UIInterfaceOrientation = UIDevice.currentOrientation
    ) -> String {
        switch orientation {
        case .portrait:
            return "0"
        case .landscapeLeft:
            return "1"
        case .portraitUpsideDown:
            return "2"
        case .landscapeRight:
            return "3"
        default:
            return "3"
        }
    }

    private func update3DSMotionRotation() {
        let value = Self.citraMotionRotationValue()
        if manicGame.isAzahar3DS {
            LibretroCore.sharedInstance().updateRunningCoreConfigs(
                [SpecialCoreOption.citra_motion_rotation.rawValue: value],
                flush: false
            )
        } else if manicGame.isCitra3DS {
            citraCore?.applyCurrentMotionRotation()
        }
    }

    /// Rotate to the orientation selected in game options.
    private func startOrientation() {
        func requestForcedOrientation() {
            if #available(iOS 16.0, tvOS 16.0, *) {
                setNeedsUpdateOfSupportedInterfaceOrientations()
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
        }
        if #available(iOS 26.0, *) {
            // iOS 26 requires the allowed mask to include the requested orientation first.
            setOrientationConfig()
            requestForcedOrientation()
        } else {
            requestForcedOrientation()
            setOrientationConfig()
        }
    }
    
    /// Apply the in-game orientation lock via AppDelegate.orientation.
    private func setOrientationConfig() {
        AppDelegate.orientation = {
            if manicGame.orientation == .landscape {
                return .landscape
            } else if manicGame.orientation == .portrait {
                return .portrait
            } else {
                return R.Config.DefaultOrientation
            }
        }()
    }
    
    /// Restore the app-wide default orientation mask.
    private func resetOrientationConfig() {
        AppDelegate.orientation = R.Config.DefaultOrientation
    }
    
    /// Pin the allowed mask to the current interface orientation (not the physical device).
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
    
    /// Move the game Metal view onto the AirPlay window, or back onto the phone.
    private func updateAirPlay() {
        if PurchaseManager.isMember, Settings.defalut.airPlay, ExternalSceneDelegate.isAirPlaying {
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
            if let _ = ExternalSceneDelegate.airPlayViewController, let gameMetalView {
                gameMetalView.removeFromSuperview()
                view.insertSubview(gameMetalView, belowSubview: controllerView)
                updateLibretroViews()
                updateCitra3DSViews()
                updateNDSCursor()
            }
        }
    }
    
    private func updateShortcutsButton() {
        shortcutsButtonContainer.subviews.forEach { $0.removeFromSuperview() }
        if (manicGame.gameType == ._3ds && UIDevice.isPad) || manicGame.isAzaharArticBase {
            return
        }
        if let controllerSkin = controllerView.controllerSkin {
            if let skin = Database.realm.objects(Skin.self).first(where: { $0.identifier == controllerSkin.identifier }) {
                if skin.supportShortcut {
                    //当前使用的是默认皮肤 则添加功能按钮
                    var shortcuts = Prefference.defalut.getPrefference(kind: .gameShortcut,
                                                                       storeKey: .game(gameId: manicGame.id),
                                                                       bestEfforts: true)?.gameShortcutValue ?? GameOption.defaultShortcutOptions(for: manicGame)
                    let availableOptions = Set(GameOption.availableOptions(game: manicGame, scene: .gaming))
                    shortcuts = shortcuts.filter({ availableOptions.contains($0) })
                    
                    
                    guard shortcuts.count > 0 else { return }
                    let functionButtonCount = shortcuts.count
                    for (index, shortcut) in shortcuts.enumerated() {
                        var iconColor = UIColor.white.withAlphaComponent(0.25)
                        if (manicGame.gameType == .ds && UIDevice.isPad) ||
                            manicGame.gameType == .wii ||
                            manicGame.gameType == .ngc ||
                            (manicGame.gameType == .pce && !UIDevice.isLandscape) ||
                            manicGame.gameType.usesDOSSkinLayout {
                            iconColor = .black.withAlphaComponent(0.25)
                        }
                        let buttonContainerView = UIView()
                        let button = ASButtonView(.iconOnlyWithSmallSize(icon: shortcut.icon.updateColorsIfNeed(colors: [iconColor], forceUpdate: true),
                                                                         background: .clear))
                        button.didTapButton = { [weak self] in
                            guard let self, shortcut != .rewind else { return }
                            shortcut.showSecondPromptIfNeed(continued: {
                                shortcut.performAction(with: [self.manicGame], performImmediately: true)
                            })
                        }
                        button.didLongPressButton = { [weak self] state in
                            guard let self else { return }
                            var mapping: MappingOption? = nil
                            if shortcut == .fastForward {
                                mapping = .fastForward2x
                            } else if shortcut == .rewind {
                                mapping = .rewind
                            } else {
                                mapping = MappingOption.GameOptionMappings.key(forValue: shortcut)
                            }
                            guard let mapping else { return }
                            let input = AnyInput(stringValue: mapping.rawValue,
                                                 intValue: 1,
                                                 type: .controller(.controllerSkin))
                            if state == .began {
                                self.gameController(self.controllerView,
                                                    didActivate:input,
                                                    value: 1)
                            } else if state == .cancelled || state == .ended {
                                self.gameController(self.controllerView,
                                                    didDeactivate: input)
                            }
                        }
                        buttonContainerView.addSubview(button)
                        button.snp.makeConstraints { make in
                            make.center.equalToSuperview()
                        }
                        shortcutsButtonContainer.addSubview(buttonContainerView)
                        buttonContainerView.snp.makeConstraints { make in
                            if manicGame.gameType == .ds || manicGame.gameType == ._3ds {
                                if UIDevice.isPhone {
                                    make.width.equalTo(31)
                                    make.height.equalToSuperview().dividedBy(2)
                                    if index == 0 {
                                        make.leading.equalToSuperview()
                                        make.top.equalToSuperview()
                                    } else if index == 1 {
                                        make.leading.equalToSuperview()
                                        make.top.equalTo(shortcutsButtonContainer.subviews[index - 1].snp.bottom)
                                    } else if index == 2 {
                                        make.trailing.equalToSuperview()
                                        make.top.equalToSuperview()
                                    } else if index == 3 {
                                        make.trailing.equalToSuperview()
                                        make.top.equalTo(shortcutsButtonContainer.subviews[index - 1].snp.bottom)
                                    }
                                } else {
                                    make.width.equalTo(50)
                                    make.top.bottom.equalToSuperview()
                                    if index == 0 {
                                        make.leading.equalToSuperview()
                                    } else if index == 1 {
                                        make.leading.equalTo(shortcutsButtonContainer.subviews[index-1].snp.trailing)
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
                                    make.leading.equalTo(shortcutsButtonContainer.subviews[index-1].snp.trailing)
                                }
                                make.top.bottom.equalToSuperview()
                                if index == functionButtonCount-1 && functionButtonCount == R.Numbers.GameFunctionButtonCount {
                                    make.trailing.equalToSuperview()
                                }
                                make.width.equalToSuperview().dividedBy(R.Numbers.GameFunctionButtonCount)
                            }
                        }
                        
                    }
                }
            }
        }
    }
    
    private func updateShortcutButtonContainer() {
        if (manicGame.gameType == .ds || (UIDevice.isPhone && manicGame.gameType == ._3ds)) &&  UIDevice.isPhone {
            shortcutsButtonContainer.snp.remakeConstraints { make in
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
        } else if manicGame.gameType.usesDOSSkinLayout, UIDevice.isPad {
            shortcutsButtonContainer.snp.updateConstraints { make in
                make.top.equalTo(gameView.snp.bottom).offset(UIDevice.isLandscape ? 30 : 40)
            }
        } else if manicGame.gameType == .ds, UIDevice.isPad {
            shortcutsButtonContainer.snp.updateConstraints { make in
                make.top.equalTo(gameView.snp.bottom).offset(UIDevice.isLandscape ? 25 : 40)
            }
        } else if manicGame.gameType == .pm && !UIDevice.isLandscape {
            shortcutsButtonContainer.snp.updateConstraints { make in
                make.leading.trailing.equalTo(gameView).inset(UIDevice.isLandscape ? 0 : 50)
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
            citraCore?.openKeyboardAction { [weak self] config in
                guard let self else { return }
                self.pauseEmulationIfNeed()
                ThreeDSKeyboardView.showForCitra(config: config) { [weak self] _, _ in
                    self?.resumeEmulationAndHandleAudio()
                }
            }
        }
    }
    
    private func updateLibretroViews() {
        guard manicGame.isLibretroType else { return }
        
        if manicGame.gameType.supportsKeyboardSkin {
            controllerView.allowTapThroughIfButtonNotHit = true
            controllerView.allowKeyboardEvents = false
            if let skin = controllerView.controllerSkin,
               skin.identifier.hasSuffix(".keyboard") {
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
        } else if manicGame.gameType == .symbian {
            controllerView.allowTapThroughIfButtonNotHit = true
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
                    customSaveDir = R.Path.GBSavePath
                    customSaveExtension = ".sav"
                } else if manicGame.gameType == .gbc {
                    customSaveDir = R.Path.GBCSavePath
                    customSaveExtension = ".sav"
                } else if manicGame.gameType == .gba {
                    customSaveDir = R.Path.GBASavePath
                    customSaveExtension = ".sav"
                } else if manicGame.gameType == .snes, manicGame.defaultCore == 0 {
                    customSaveDir = R.Path.bsnes
                } else if manicGame.gameType == .ds {
                    customSaveDir = R.Path.DSSavePath
                } else if manicGame.gameType == .doom {
                    customSaveDir = R.Path.PrBoom
                } else if manicGame.isAzahar3DS {
                    customSaveDir = R.Path.ThreeDS
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
                        // Register Azahar SWKBD after the core is loaded.
                        compltion = { [weak self] _ in
                            guard let self else { return }
                            LibretroCore.sharedInstance().registerAzaharKeyboard { [weak self] config in
                                guard let self else { return }
                                self.pauseEmulationIfNeed()
                                ThreeDSKeyboardView.showForAzahar(config: config,
                                                                  tapAction: { [weak self] buttonType, text in
                                    guard let self else { return }
                                    // Finalize while paused so the next frame sees DataReady.
                                    LibretroCore.sharedInstance().inputAzaharKeyboard(text, buttonType: buttonType)
                                    self.resumeEmulationAndHandleAudio()
                                })
                            }
                        }
                    } else if manicGame.gameType == .symbian {
                        compltion = { _ in
                            LibretroCore.sharedInstance().registerEKA2L1InputDialog { initText, maxLength in
                                Log.debug("Symbian InputDialog initText:\(initText ?? "nil") maxLength:\(maxLength)")
                                LimitedTextInputView.show(title: R.string.localizable.game3DSInputTitle(),
                                                          text: initText,
                                                          limitedType: .normal(maxTextSize: maxLength <= 0 ? 1024 : maxLength),
                                                          confirmAction: { result in
                                    if let result = result as? String {
                                        LibretroCore.sharedInstance().submitEKA2L1Input(result)
                                    }
                                })
                            } questionDialog: { text, buttonYes, buttonNo in
                                Log.debug("Symbian questionDialog text:\(text) buttonYes:\(buttonYes ?? "nil") buttonNo:\(buttonNo ?? "nil")")
                                LimitedTextInputView.show(detail: text,
                                                          cancelTitle: buttonNo,
                                                          confirmTitle: buttonYes,
                                                          limitedType: .normal(maxTextSize: 1024),
                                                          confirmAction: { result in
                                    if let result = result as? String {
                                        LibretroCore.sharedInstance().submitEKA2L1Input(result)
                                    }
                                })
                            }
                        }
                    }
                    self.updateDualScreenViews()
                    LibretroCore.sharedInstance().setCustomSaveExtension(customSaveExtension)
                    if self.manicGame.isNDSHomeMenuGame || self.manicGame.isDSiHomeMenuGame || self.manicGame.isDOSHomeMenuGame {
                        LibretroCore.sharedInstance().loadWithoutContent(corePath)
                    } else {
                        let romPath: String
                        if manicGame.isAzaharArticBase || manicGame.gameType == .symbian {
                            romPath = manicGame.romUrl.string
                        } else {
                            romPath = manicGame.romUrl.path
                        }
                        LibretroCore.sharedInstance().loadGame(romPath, corePath: corePath, completion: compltion)
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
                        } else if manicGame.gameType == .wii {
                            let wiiController = manicGame.getExtraInt(key: ExtraKey.wiiController.rawValue) ?? 0
                            let controllerType = LibretroWiiController(rawValue: wiiController) ?? .classicPro
                            LibretroCore.sharedInstance().setWiiController(controllerType)
                            WiiEmulatorBridge.shared.controllerType = controllerType
                        }
                        DispatchQueue.main.asyncAfter(delay: 2.5) {
                            self.updateFastforward(speed: self.manicGame.speed)
                            self.updateRewind()
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
                            self.loadState(loadSaveState)
                        }
                    }
                } else if self.manicGame.gameType == .mcd {
                    DispatchQueue.main.asyncAfter(delay: 3) {
                        let biosPaths = R.BIOS.MegaCDBios.map({ R.Path.System.appendingPathComponent($0.fileName) })
                        self.jGenesisCore?.openSegaCdFile(filePath: self.manicGame.romUrl.path, americasBiosPath: biosPaths[1], japanBiosPath: biosPaths[2], europeBiosPath: biosPaths[0])
                        DispatchQueue.main.asyncAfter(delay: 5) {
                            self.updateFastforward(speed: self.manicGame.speed)
                            self.updateAudio()
                            if let loadSaveState = self.loadSaveState {
                                self.loadState(loadSaveState)
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
                GameOption.quit.performAction(with: [self.manicGame])
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
                        self.updateScreenScaling()
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
        let usingShaderPath = Prefference.defalut.getPrefference(kind: .shader,
                                                                 storeKey: .shaderKey(gameId: manicGame.id,
                                                                                      isGlsl: manicGame.supportGlslShaders),
                                                                 bestEfforts: true)?.shaderValue
        let isOriginalShader = usingShaderPath == nil || usingShaderPath == ""
        
        if ExternalSceneDelegate.isAirPlaying {
            let layoutType = Settings.defalut.airPlayLayout
            var layout: String = ""
            let ratio = 0.3
            
            let scale = isOriginalShader ? UIScreen.main.scale : 1.25
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
            let scale = isOriginalShader ? UIScreen.main.scale : 1.25
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
                
                if !isOriginalShader, manicGame.gameType == ._3ds, UIDevice.isLandscape {
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
    
    private func quit() {
        if manicGame.isCitra3DS {
            citraCore?.stop()
            DispatchQueue.main.asyncAfter(delay: 0.5) {
                self.dismiss(animated: true)
            }
        } else if manicGame.isLibretroType {
            LibretroCore.sharedInstance().updateLibretroConfig("savefile_directory", value: R.Path.LibretroSavePath.libretroPath)
            LibretroCore.sharedInstance().updateLibretroConfig("system_directory", value: R.Path.System.libretroPath)
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
    }
    
    private func consoleHome() {
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
        } else if manicGame.gameType == .wii {
            DispatchQueue.main.asyncAfter(delay: 1) {
                LibretroCore.sharedInstance().press(.R3, playerIndex: 0)
                DispatchQueue.main.asyncAfter(delay: 0.1) {
                    LibretroCore.sharedInstance().release(.R3, playerIndex: 0)
                }
            }
        }
    }
    
    private func simBlowing() {
        if manicGame.gameType == ._3ds {
            if manicGame.isCitra3DS {
                citraCore?.setSimBlowing(start: true)
                DispatchQueue.main.asyncAfter(delay: 5) { [weak self] in
                    self?.citraCore?.setSimBlowing(start: false)
                }
            } else {
                LibretroCore.sharedInstance().updateRunningCoreConfigs([SpecialCoreOption.citra_input_type.rawValue: "static_noise"], flush: false)
                DispatchQueue.main.asyncAfter(delay: 5) {
                    LibretroCore.sharedInstance().updateRunningCoreConfigs([SpecialCoreOption.citra_input_type.rawValue: "frontend"], flush: false)
                }
            }
        } else if manicGame.gameType == .ds {
            if manicGame.defaultCore == 0 {
                //melonDSDS
                LibretroCore.sharedInstance().updateRunningCoreConfigs([SpecialCoreOption.melonds_mic_input.rawValue: "blow"], flush: false)
                DispatchQueue.main.asyncAfter(delay: 5) { [weak self] in
                    var restoreInput = "silence"
                    if self?.manicGame.getExtraBool(key: ExtraKey.microphone.rawValue) ?? false {
                        restoreInput = "microphone"
                    }
                    LibretroCore.sharedInstance().updateRunningCoreConfigs([SpecialCoreOption.melonds_mic_input.rawValue: restoreInput], flush: false)
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
    }
    
    private func amiibo() {
        if manicGame.gameType == ._3ds {
            let isSearchingAmiibo = (manicGame.isCitra3DS && (citraCore?.isAmiiboSearching() ?? false)) || (manicGame.isAzahar3DS && LibretroCore.sharedInstance().isSearchingAmiibo())
            if isSearchingAmiibo {
                if !GameOptionsView.hasShownInstance {
                    pauseEmulationIfNeed()
                }
                Log.debug("amiibo正在搜索中")
                FilesImporter.shared.presentImportController(supportedTypes: UTType.binTypes, allowsMultipleSelection: false) { [weak self] urls in
                    guard let self = self else { return }
                    self.resumeEmulationAndHandleAudio()
                    UIView.hideAllAlert { [weak self] in
                        guard let self = self else { return }
                        if let url = urls.first {
                            DispatchQueue.main.asyncAfter(delay: 1) { [weak self] in
                                guard let self = self else { return }
                                if self.manicGame.isCitra3DS {
                                    self.citraCore?.loadAmiibo(path: url.path)
                                } else {
                                    LibretroCore.sharedInstance().loadAmiibo(url.path)
                                }
                            }
                        }
                    }
                }
            } else {
                Log.debug("amiibo没有搜索")
                UIView.makeToast(message: R.string.localizable.amiiboNotSearching())
            }
        }
    }
    
    private func updateResolution(_ resolution: GameOption.Resolution) {
        if manicGame.gameType == ._3ds {
            if manicGame.isCitra3DS {
                citraCore?.setResolution(resolution: resolution)
            } else {
                let resolutionRaw = resolution == .undefine ? 1 : resolution.rawValue
                LibretroCore.sharedInstance().updateRunningCoreConfigs(["citra_resolution_factor": "\(resolutionRaw)"], flush: false)
            }
        } else if manicGame.gameType == .psp {
            updatePSPResolution(resolution, reload: true)
        } else if manicGame.gameType == .n64 {
            updateN64Resolution(resolution, reload: true)
        } else if manicGame.gameType == .ps1 && manicGame.defaultCore == 0 {
            LibretroCore.sharedInstance().updateConfig(EmulationCore.BeetlePSXHW.name, key: "beetle_psx_hw_internal_resolution", value: resolution.resolutionTitleForPS1, reload: true)
        } else if manicGame.gameType == .dc {
            updateDCResolution(resolution, reload: true)
        } else if manicGame.gameType == .ds {
            let scale = UInt32(resolution == .undefine ? 1 : resolution.rawValue)
            let option = "\(256*scale)x\(192*scale)"
            LibretroCore.sharedInstance().updateRunningCoreConfigs(["desmume_internal_resolution": option], flush: false)
        } else if manicGame.gameType == .doom {
            let scale = UInt32(resolution == .undefine ? 1 : resolution.rawValue)
            let option = "\(320*scale)x\(200*scale)"
            LibretroCore.sharedInstance().updateRunningCoreConfigs(["prboom-resolution": option], flush: true)
            LibretroCore().reload(byKeepState: true)
        }
    }
    
    private func reload() {
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
                    self.updateScreenScaling()
                }
            }
        }
    }
    
    private func saveSnapShot() {
        snapShot(completion: { images in
            if let images {
                PhotoSaver.save(images: images)
            }
        })
    }
    
    private func snapShot(completion: (([UIImage]?) -> Void)? = nil) {
        if manicGame.isCitra3DS {
            if let images = self.snapShotFor3DS() {
                DispatchQueue.main.asyncAfter(delay: GameOptionsView.hasShownInstance ? 1 : 0, execute: {
                    completion?(images)
                })
            }
        } else if manicGame.isLibretroType {
            DispatchQueue.main.asyncAfter(delay: GameOptionsView.hasShownInstance ? 1 : 0, execute: {
                LibretroCore.sharedInstance().snapshot { image in
                    guard let image else {
                        completion?(nil)
                        return
                    }
                    if (self.manicGame.gameType == .ds || self.manicGame.isAzahar3DS),
                       let images = self.snapShotForDualScreen(source: image) {
                        completion?(images)
                    } else {
                        completion?([image])
                    }
                }
            })
        } else if manicGame.isJGenesisCore {
            if let image = jGenesisCore?.snapShot() {
                completion?([image])
            } else {
                completion?(nil)
            }
        } else if manicGame.isJ2MECore {
            if let image = j2meCore?.snapShot() {
                completion?([image])
            } else {
                completion?(nil)
            }
        } else {
            completion?(gameViews.compactMap({ $0.snapshot() }))
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
    
    private func updateN64Resolution(_ resolution: GameOption.Resolution, reload: Bool) {
        if manicGame.isN64ParaLLEl {
            LibretroCore.sharedInstance().updateConfig(EmulationCore.Mupen64PlushNext.name,
                                                       key: SpecialCoreOption.mupen64plus_parallel_rdp_upscaling.rawValue,
                                                       value: resolution.resolutionTitleForN64ParaLLEl, reload: reload)
        } else {
            let options = ["640x480", "960x720", "1280x960", "1440x1080", "1600x1200", "1920x1440", "2240x1680", "2560x1920", "2880x2160", "3520x2640"]
            var option = "640x480"
            if resolution != .undefine {
                option = options[resolution.rawValue - 1]
            }
            LibretroCore.sharedInstance().updateConfig(EmulationCore.Mupen64PlushNext.name,
                                                       key: SpecialCoreOption.mupen64plus_43screensize.rawValue,
                                                       value: option,
                                                       reload: reload)
        }
    }
    
    private func updateDCResolution(_ resolution: GameOption.Resolution, reload: Bool) {
        let options = ["640x480", "1280x960", "1920x1440", "2560x1920", "3200x2400", "3840x2880", "4480x3360", "5120x3840", "5760x4320", "6400x4800"]
        var option = "640x480"
        if resolution != .undefine {
            option = options[resolution.rawValue - 1]
        }
        LibretroCore.sharedInstance().updateConfig(EmulationCore.Flycast.name,
                                                   key: SpecialCoreOption.reicast_internal_resolution.rawValue,
                                                   value: option,
                                                   reload: reload)
    }
    
    private func updatePSPResolution(_ resolution: GameOption.Resolution, reload: Bool) {
        let scale = UInt32(resolution == .undefine ? 1 : resolution.rawValue)
        let option = "\(480*scale)x\(272*scale)"
        LibretroCore.sharedInstance().updateConfig(EmulationCore.PPSSPP.name,
                                                   key: SpecialCoreOption.ppsspp_internal_resolution.rawValue,
                                                   value: option, reload: reload)
    }
    
    private func updateAnalogMode(toastAllow: Bool, toggle: Bool) {
        guard manicGame.gameType == .ps1 else { return }
        if manicGame.defaultCore == 0 {
            var deviceType = R.Strings.PSXController
            if var isAnalog = manicGame.getExtra(key: ExtraKey.isAnalog.rawValue) as? Bool {
                isAnalog = toggle ? !isAnalog : isAnalog
                LibretroCore.sharedInstance().setPSXAnalog(isAnalog)
                if toggle {
                    manicGame.updateExtra(key: ExtraKey.isAnalog.rawValue, value: isAnalog)
                }
                if isAnalog {
                    deviceType = R.Strings.PSXDualShock
                }
                skinSwitchBindDatas["toggleAnalog"] = isAnalog
                Log.debug("读取数据库 使用\(deviceType)")
            } else {
                //默认使用DualShock
                LibretroCore.sharedInstance().setPSXAnalog(true)
                manicGame.updateExtra(key: ExtraKey.isAnalog.rawValue, value: true)
                skinSwitchBindDatas["toggleAnalog"] = true
                Log.debug("加载默认值 使用\(R.Strings.PSXDualShock)")
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
                if self.pscxReArmedDeviceType == R.Strings.PSXController {
                    self.pscxReArmedDeviceType = R.Strings.PSXDualShock
                } else {
                    self.pscxReArmedDeviceType = R.Strings.PSXController
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
            toast.config.cardCornerRadius = R.Size.CornerRadiusMedium
            toast.config.cardMaxWidth = (R.Size.WindowSize.minDimension - 2*R.Size.ContentSpaceHuge) * scale
            toast.config.cardMaxHeight = 64 * scale
            toast.contentView.layerBorderColor = R.Color.Border
            toast.contentView.layerBorderWidth = 1
            toast.config.dynamicBackgroundColor = R.Color.BackgroundSecondary.withAlphaComponent(0.95)
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
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall*scale)
            }
            
            let label = UILabel()
            label.numberOfLines = message == nil ? 2 : 3
            let titleFont = scale == 1.0 ? R.Font.Headline() : UIFont.systemFont(ofSize: 30)
            let matt = NSMutableAttributedString(string: title, attributes: [.font: titleFont, .foregroundColor: R.Color.LabelPrimary])
            if let message {
                let messageFont = scale == 1.0 ? R.Font.Footnote() : UIFont.systemFont(ofSize: 20)
                matt.append(NSAttributedString(string: "\n\(message)", attributes: [.font: messageFont, .foregroundColor: R.Color.LabelSecondary]))
            }
            let style = NSMutableParagraphStyle()
            style.lineSpacing = (R.Size.ContentSpaceTiny/2)*scale
            label.attributedText = matt.applying(attributes: [.paragraphStyle: style])
            contentView.addSubview(label)
            label.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(imageView.snp.trailing).offset(R.Size.ContentSpaceExtraSmall*scale)
                if hideIcon {
                    make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium*scale)
                }
                make.top.greaterThanOrEqualTo(R.Size.ContentSpaceExtraSmall*scale)
                make.bottom.lessThanOrEqualTo(-R.Size.ContentSpaceExtraSmall*scale)
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
                    make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium*scale)
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
                LibretroCore.sharedInstance().updateConfig(EmulationCore.Nestopia.name,
                                                           key: SpecialCoreOption.nestopia_palette.rawValue,
                                                           value: nesPalette.name,
                                                           reload: false)
            } else {
                LibretroCore.sharedInstance().updateRunningCoreConfigs([
                    SpecialCoreOption.nestopia_palette.rawValue: nesPalette.name
                ], flush: false)
            }
        } else if nesPalette.type == .buildIn || nesPalette.type == .custom {
            let fromPath: String
            if nesPalette.type == .buildIn {
                fromPath = R.Path.NESPalettes.appendingPathComponent(nesPalette.name + ".pal")
            } else {
                fromPath = R.Path.CustomPalettes.appendingPathComponent(manicGame.gameType.localizedShortName).appendingPathComponent(nesPalette.name + ".pal")
            }
            do {
                try FileManager.safeCopyItem(at: URL(fileURLWithPath: fromPath), to: URL(fileURLWithPath: R.Path.System.appendingPathComponent("custom.pal")), shouldReplace: true)
                LibretroCore.sharedInstance().updateConfig(EmulationCore.Nestopia.name,
                                                           key: SpecialCoreOption.nestopia_palette.rawValue,
                                                           value: "custom",
                                                           reload: false)
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
        
        if let id = Prefference.defalut.getPrefference(kind: .triggerPro,
                                                       storeKey: .game(gameId: manicGame.id),
                                                       bestEfforts: true)?.triggerProValue,
           id != -1 {
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
    
    private func updateFastforward(speed: GameOption.FastForwardSpeed) {
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
            backgroundImageView?.image = nil
            backgroundImageView = nil
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
        
        if let result = Prefference.defalut.getPrefference(kind: .flexBackground,
                                                           storeKey: .orientationKey(gameId: manicGame.id, isLandScape: UIDevice.isLandscape),
                                                           bestEfforts: true),
           case let .flexBackground(bg) = result {
            backgroundImageView?.image = bg.image
        } else {
            backgroundImageView?.image = nil
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
    
    private func updateScreenScaling() {
        let scaling = manicGame.screenScaling
        if manicGame.isLibretroType {
            LibretroCore.sharedInstance().setFullScreen(scaling == .stretch ? true : false)
        } else if manicGame.isJ2MECore {
            j2meCore?.setScaleMode(scaling)
        }
    }
    
    private func getShaderPreviewImage(completion: ((UIImage?) -> Void)? = nil) {
        guard manicGame.isLibretroType else {
            completion?(nil)
            return
        }
        DispatchQueue.main.asyncAfter(delay: GameOptionsView.hasShownInstance ? 1 : 0, execute: { [weak self] in
            guard let self else { return }
            LibretroCore.sharedInstance().snapshot { [weak self] image in
                guard let self else { return }
                if (self.manicGame.gameType == .ds || self.manicGame.isAzahar3DS),
                   let i = image,
                   let resultImage = self.snapShotForDualScreen(topOnly: true, source: i)?.first {
                    completion?(resultImage)
                } else {
                    completion?(image)
                }
            }
        })
    }
    
    private func updateLibretroCoreConfigs(core: EmulationCore,
                                           configs: [SpecialCoreOption: String],
                                           reload: Bool = false,
                                           safeMode: Bool = false) {
        if let coreConfigs = SpecialCoreOption.resolvedCoreConfigs(game: manicGame,
                                                                   optimizationCoreConfigs: configs,
                                                                   safeMode: safeMode) {
            LibretroCore.sharedInstance().updateConfig(core.name,
                                                       configs: coreConfigs,
                                                       reload: false)
        }
    }
    
    private func updateRewind() {
        guard !isHardcoreMode && !isWFCConnect else {
            LibretroCore.sharedInstance().setRewindEnable(false)
            return
        }
        
        func rewindBufferSizeMB() -> UInt32 {
            let ramGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
            switch ramGB {
            case ..<1.5: return 20     // old device
            case ..<2.5: return 32   // 2GB iPhone 6s/7
            case ..<3.5: return 64   // 3GB iPhone 8P/X/11
            case ..<5.5: return 128  // 4GB iPhone 12~14
            default:     return 256  // 6GB+ new device
            }
        }
        LibretroCore.sharedInstance().setRewindEnable(manicGame.getExtraBool(key: ExtraKey.rewind.rawValue) ?? false,
                                                      granularity: 3,
                                                      bufferSizeMB: rewindBufferSizeMB(),
                                                      bufferSizeStepMB: 10,
                                                      mute: false)
    }
}

//MARK: GameViewControllerDelegate代理
extension PlayViewController: GameViewControllerDelegate {
    
    func gameViewControllerShouldResume(_ gameViewController: GameViewController) -> Bool {
        if SheetProvider.find(identifier: R.Strings.PlayPurchaseAlertIdentifier).count > 0 {
            return false
        }
        return (GameOptionsView.hasShownInstance ||
                GameInfoView.hasShownInstance ||
                CheatCodeListView.hasShownInstance ||
                SkinSettingsView.hasShownInstance ||
                ShaderListView.hasShownInstance ||
                ControllersSettingView.hasShownInstance ||
                ASWebView.hasShownInstance ||
                FlexSkinSettingViewController.isShow ||
                RetroAchievementListView.hasShownInstance ||
                CheevosPopupView.hasShownInstance ||
                GameplayManualsView.hasShownInstance ||
                J2MESettingView.hasShownInstance) ? false : true
    }
    
}

//MARK: 静态公开方法
extension PlayViewController {
    static var isGaming: Bool { currentPlayViewController != nil }
    
    /// Playing and the core is not paused. Pause (GameOptions, etc.) yields FocusKit instead of cores.
    static var isEmulationActive: Bool {
        guard let currentPlayViewController else { return false }
        return !currentPlayViewController.isPaused
    }
    
    static func refreshExternalInputSink() {
        if ControllerMappingViewController.isCapturingInput {
            ExternalInputDispatch.sink = .mapping
            FocusSystem.shared.isEnabled = false
            return
        }
        if isEmulationActive {
            ExternalInputDispatch.sink = .gameplay
            FocusSystem.shared.isEnabled = false
            FocusSystem.shared.userDidTouchScreen()
        } else {
            ExternalInputDispatch.sink = .focusKit
            FocusSystem.shared.isEnabled = true
        }
    }
    
    static var enableAirplay: Bool {
        if let _ = currentPlayViewController {
            return true
        }
        return false
    }
    
    static var currentSkinID: String? {
        if let currentPlayViewController {
            return currentPlayViewController.currentSkinID
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
    
    static var isWFCConnect: Bool {
        if let currentPlayViewController {
            return currentPlayViewController.isWFCConnect
        }
        return false
    }
    
    static var isHardcoreMode: Bool {
        if let currentPlayViewController {
            return currentPlayViewController.isHardcoreMode
        }
        return false
    }
    
    static func updateAirPlay() {
        if let currentPlayViewController {
            currentPlayViewController.updateAirPlay()
        }
    }
    
    static func updateAnalogMode() {
        if let currentPlayViewController {
            currentPlayViewController.updateAnalogMode(toastAllow: true, toggle: true)
        }
    }
    
    static func updateTriggerPro() {
        if let currentPlayViewController {
            currentPlayViewController.updateTriggerPro(showToast: true)
        }
    }
    
    static func updateScreenScaling() {
        if let currentPlayViewController {
            currentPlayViewController.updateScreenScaling()
        }
    }
    
    static func pauseEmulationIfNeed() {
        if let currentPlayViewController {
            currentPlayViewController.pauseEmulationIfNeed()
        }
    }
    
    static func resumeEmulationAndHandleAudio() {
        if let currentPlayViewController {
            currentPlayViewController.resumeEmulationAndHandleAudio()
        }
    }
    
    static func saveState() {
        if let currentPlayViewController {
            currentPlayViewController.saveState(type: .manualSaveState)
        }
    }
    
    static func loadState(_ state: GameSaveState?) {
        if let currentPlayViewController {
            currentPlayViewController.loadState(state)
        }
    }
    
    static func updateAudio() {
        if let currentPlayViewController {
            currentPlayViewController.updateAudio()
        }
    }
    
    static func updateFastforward(speed: GameOption.FastForwardSpeed) {
        if let currentPlayViewController {
            currentPlayViewController.updateFastforward(speed: speed)
        }
    }
    
    static func saveSnapShot() {
        if let currentPlayViewController {
            currentPlayViewController.saveSnapShot()
        }
    }
    
    static func reload() {
        if let currentPlayViewController {
            currentPlayViewController.reload()
        }
    }
    
    static func updateResolution(_ resolution: GameOption.Resolution) {
        if let currentPlayViewController {
            currentPlayViewController.updateResolution(resolution)
        }
    }
    
    static func consoleHome() {
        if let currentPlayViewController {
            currentPlayViewController.consoleHome()
        }
    }
    
    static func amiibo() {
        if let currentPlayViewController {
            currentPlayViewController.amiibo()
        }
    }
    
    static func updateSkin() {
        if let currentPlayViewController {
            currentPlayViewController.updateSkin()
        }
    }
    
    static func simBlowing() {
        if let currentPlayViewController {
            currentPlayViewController.simBlowing()
        }
    }
    
    static func updateNESPalette(_ nesPalette: Game.NESPalette) {
        if let currentPlayViewController {
            currentPlayViewController.updateNESPalette(nesPalette)
        }
    }
    
    static func quit() {
        if let currentPlayViewController {
            currentPlayViewController.quit()
        }
    }
    
    static func updateShader() {
        if let currentPlayViewController {
            currentPlayViewController.updateFilter()
        }
    }
    
    static func stopShader() {
        if let currentPlayViewController {
            currentPlayViewController.stopShader()
        }
    }
    
    static func getShaderPreviewImage(completion: ((UIImage?) -> Void)? = nil) {
        if let currentPlayViewController {
            return currentPlayViewController.getShaderPreviewImage(completion: completion)
        } else {
            completion?(nil)
        }
    }
    
    static func updateRewind() {
        if let currentPlayViewController {
            currentPlayViewController.updateRewind()
        }
    }
    
    static func forceFullSkin(hideControls: Bool) {
        if let currentPlayViewController {
            currentPlayViewController.manicGame.forceFullSkin = hideControls
            currentPlayViewController.updateSkin()
        }
    }
    
    static func updateBackground() {
        if let currentPlayViewController {
            currentPlayViewController.updateBackground()
        }
    }
    
    static var currentGame: Game? {
        if let currentPlayViewController {
            return currentPlayViewController.manicGame
        }
        return nil
    }
}
