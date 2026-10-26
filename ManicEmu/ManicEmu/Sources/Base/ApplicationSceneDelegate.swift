//
//  ApplicationSceneDelegate.swift
//  testScene
//
//  Created by Aoshuang Lee on 2024/12/26.
//

import UIKit
import GameController
import OAuthSwift
import UniformTypeIdentifiers
import ProHUD

class ApplicationSceneDelegate: UIResponder, UIWindowSceneDelegate {
    static weak var applicationScene: UIWindowScene?
    static weak var applicationWindow: UIWindow?
    var window: UIWindow?
    static var launchGameID: String? = nil
    private var hingeChangeNotification: Any? = nil
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            ApplicationSceneDelegate.applicationScene = windowScene
            window = UIWindow(windowScene: windowScene)
            ApplicationSceneDelegate.applicationWindow = window
            window?.tintColor = R.Color.Main
            installGamepadEventInteraction(on: window)
            //setup ProHUD
            AppContext.supportedInterfaceOrientations = {
                OrientationLockPin.resolvedMask(for: nil)
            }
            if #available(iOS 26.0, *) {
                AppContext.prefersInterfaceOrientationLocked = {
                    if #available(iOS 27.1, *), DuoTabletopKit.isTabletopActive {
                        return DuoTabletopKit.isTabletopOrientationLocked
                    }
                    return OrientationLockPin.prefersLocked
                }
            }
            OrientationLockPin.onForcedLandscapeGeometry = {
                AppContext.alignOverlayWindowsWithScene()
            }
            AppContext.prefersStatusBarHidden = { [weak self] presentedViewController in
                guard let self else { return nil }
                return UIViewController.shouldStatusBarHidden(window: self.window,
                                                              presentedViewController: presentedViewController)
            }
            let loadThenPresentHome = {
                ResourcesKit.loadResources { isSuccess in
                    Database.setup {
                        ThemeManager.shared.setup()
                        self.window?.rootViewController = HomeViewController()
                        self.window?.makeKeyAndVisible()
                        BackgroundMusicKit.shared.startMonitoring()
                        FocusSoundEffects.shared.startMonitoring()
                        if Settings.defalut.iCloudSyncEnable {
                            SyncManager.shared.startSync()
                        }
                        
                        if !isSuccess {
                            UIView.makeAlert(title: R.string.localizable.fatalErrorTitle(), detail: R.string.localizable.fatalErrorDesc(), cancelTitle: R.string.localizable.confirmTitle())
                        }
                        if connectionOptions.urlContexts.count > 0 {
                            self.scene(scene, openURLContexts: connectionOptions.urlContexts)
                        }
                        
                        CheevosBridge.setup(with: R.Config.AppVersion, requireCredentials: {
                            if let user = AchievementsUser.getUser() {
                                let cheevosUser = CheevosUser()
                                cheevosUser.userName = user.username
                                cheevosUser.password = user.password
                                cheevosUser.token = user.token
                                return cheevosUser
                            }
                            return nil
                        }, updateCredentials: { cheevosUser in
                            if let u = cheevosUser?.userName,
                               let p = cheevosUser?.password,
                               let t = cheevosUser?.token {
                                AchievementsUser.updateUser(username: u, password: p, token: t)
                                
                            }
                        })
                        
#if SIDE_LOAD
                        StikJITHostCoordinator.shared.enableOnLaunchIfNeeded()
#endif
                    }
                }
            }
            
            // Same unzip conditions as ResourcesKit; keep this read-only so the original extract path is unchanged.
            if Self.needsResourceExtract() {
                window?.rootViewController = LaunchPlaceholderViewController()
                window?.makeKeyAndVisible()
                // Return from scene-create first; unzip still runs on main on the next turn.
                DispatchQueue.main.async(execute: loadThenPresentHome)
            } else {
                loadThenPresentHome()
            }
            
            let dropInteraction = UIDropInteraction(delegate: self)
            window?.addInteraction(dropInteraction)
            
            if #available(iOS 27.1, *), UIDevice.isPhoneDuo {
                //Monitor changes to the hinge
                window?.addInteraction(UIHingeInteraction(updateHandler: { interaction, update in
                    DuoHingeKit.didHingeUpdate(interaction: interaction, update: update)
                    DispatchQueue.once {
                        /// try enter iPhone Duo Tabletop Mode
                        if !PlayViewController.isGaming,
                           UIDevice.isPhoneDuoInner,
                           let hinge = DuoHingeKit.currentStatusHinge,
                           hinge.status == .partiallyOpen {
                            if UIDevice.isLandscape && !DuoTabletopKit.isTabletopMode {
                                UIView.makeToast(message: R.string.localizable.tabletopModeDetected())
                            } else {
                                DuoTabletopKit.startTabletopMode()
                            }
                        }
                    }
                }))
                hingeChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.DuoHingeChange, object: nil, queue: .main) { notification in
                    guard !PlayViewController.isGaming else { return }
                    if let transition = DuoHingeKit.transition(from: notification) {
                        if transition.to.status == .partiallyOpen {
                            if UIDevice.isLandscape && !DuoTabletopKit.isTabletopMode {
                                UIView.makeToast(message: R.string.localizable.tabletopModeDetected())
                                return
                            } else {
                                DuoTabletopKit.startTabletopMode()
                            }
                        } else if DuoTabletopKit.isTabletopMode {
                            DuoTabletopKit.stopTabletopMode()
                        }
                    }
                }
            }
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        if let hingeChangeNotification {
            NotificationCenter.default.removeObserver(hingeChangeNotification)
        }
    }
    
    /// Route gamepad HID through Game Controller instead of UIKit (iPad system focus hitch).
    /// iOS 18+; older versions fall back to swallowing gamepad UIPress in ManicApplication.
    private func installGamepadEventInteraction(on window: UIWindow?) {
        guard let window else { return }
        if #available(iOS 18.0, *) {
            let interaction = GCEventInteraction()
            interaction.handledEventTypes = .gamepad
            if #available(iOS 26.0, *) {
                interaction.receivesEventsInView = false
            }
            window.addInteraction(interaction)
        }
    }
    
    /// Mirrors ResourcesKit's unzip gate without performing any file work.
    private static func needsResourceExtract() -> Bool {
        if let systemCoreVersion = UserDefaults.standard.string(forKey: R.DefaultKey.SystemCoreVersion) {
            let appVersionNumber = UInt64(R.Config.AppVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
            let systemCoreVersionNumber = UInt64(systemCoreVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
            if systemCoreVersionNumber < appVersionNumber {
                return true
            }
            let systemCoreBuildVersion = UserDefaults.standard.integer(forKey: R.DefaultKey.SystemCoreBuildVersion)
            let appBuildVersion = Int(R.Config.AppBuildVersion)!
            if appBuildVersion > systemCoreBuildVersion {
                return true
            }
        } else {
            return true
        }
        return !FileManager.default.fileExists(atPath: R.Path.Resource)
            || !FileManager.default.fileExists(atPath: R.Path.ExtrasDB)
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        OrientationLockPin.handleSceneWillResignActive()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        FilesSyncManager.shared.handleDidBecomeActive()
        if #available(iOS 27.1, *) {
            DuoTabletopKit.resumeTabletopOnBecomeActiveIfNeeded()
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for URLContext in URLContexts {
            let url = URLContext.url
            Log.debug("openURLContexts 回调URL:\(url)")
            if let scheme = url.scheme {
                if scheme == R.Strings.OAuthGoogleDriveCallbackHost ||
                    scheme == R.Strings.OAuthCallbackHost ||
                    scheme == R.Strings.OAuthOneDriveCallbackHost {
                    Log.debug("OAuth鉴权回调")
                    OAuthSwift.handle(url: url)
                } else if scheme == R.Strings.ManicScheme {
                    if let host = url.host, host == R.Strings.MeloNXScheme {
                        EmulatorInteractionKit.processGames(type: .meloNX, callbackUrl: url)
                    } else if let host = url.host, host == R.Strings.XeniOSScheme {
                        EmulatorInteractionKit.processGames(type: .xeniOS, callbackUrl: url)
                    } else if let host = url.host, host == R.Strings.DukeXScheme {
                        EmulatorInteractionKit.processGames(type: .dukeX, callbackUrl: url)
                    } else if let host = url.host, host == R.Strings.ARMSX2Scheme {
                        EmulatorInteractionKit.processGames(type: .armsx2, callbackUrl: url)
                    } else if let host = url.host, host == R.Strings.MeloCafeScheme {
                        EmulatorInteractionKit.processGames(type: .melocafe, callbackUrl: url)
                    } else {
                        Self.launchGameID = url.lastPathComponent
                    }
                }
            }
        }
        
        if let launchGameID = Self.launchGameID, let window, let _ = window.rootViewController {
            //页面已经初始化好了，在这里处理, 如果没有初始化好，则交给GamesViewController处理
            Self.launchGameID = nil
            let realm = Database.realm
            if let game = realm.object(ofType: Game.self, forPrimaryKey: launchGameID) {
                game.handleTapAction(forceQuick: true, in: nil)
            }
        }
        
        DispatchQueue.global().async {
            let allSupportExtentions = FileType.allSupportFileExtension()
            let fileUrls = URLContexts.map({ $0.url }).filter { $0.scheme == "file" && allSupportExtentions.contains([$0.pathExtension]) }
            if fileUrls.count > 0 {
                //先复制到本地 确保后续操作有足够权限
                var newFileUrls = [URL]()
                for fileUrl in fileUrls {
                    if #available(iOS 17.0, *) {
                        guard fileUrl.startAccessingSecurityScopedResource() else {
                            DispatchQueue.main.async {
                                UIView.makeToast(message: R.string.localizable.openFilePermissionsLimit(fileUrl.lastPathComponent))
                            }
                            continue
                        }
                    } else {
                        let _ = fileUrl.startAccessingSecurityScopedResource()
                    }
                    let newFileUrl = URL(fileURLWithPath: R.Path.Temp.appendingPathComponent(fileUrl.lastPathComponent))
                    do {
                        try FileManager.safeCopyItem(at: fileUrl, to: newFileUrl, shouldReplace: true)
                        newFileUrls.append(newFileUrl)
                    } catch {
                        DispatchQueue.main.async {
                            UIView.makeToast(message: R.string.localizable.openFilePermissionsLimit(fileUrl.lastPathComponent))
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(delay: 1.5) {
                    if newFileUrls.count > 0 {
                        FilesImporter.importFiles(urls: newFileUrls, in: nil)
                    }
                }
            }
        }
    }
    
    func windowScene(_ windowScene: UIWindowScene, didUpdate previousCoordinateSpace: any UICoordinateSpace, interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation, traitCollection previousTraitCollection: UITraitCollection) {
        if #available(iOS 26.0, tvOS 26.0, *) {
            return
        }
        //Use this method to handle the following geometry changes in iOS26 and below.
    }
    
    @available(iOS 26.0, tvOS 26.0, *)
    func windowScene(_ windowScene: UIWindowScene, didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry) {
        if #available(iOS 27.1, *),
            UIDevice.isPhoneDuoInnerFullScreen,
            UIDevice.isPortrait,
           let hinge = DuoHingeKit.currentStatusHinge,
           hinge.status == .partiallyOpen,
           !DuoTabletopKit.isTabletopMode,
            let window = windowScene.keyWindow,
            windowScene.screen.bounds.equalTo(window.bounds) {
            DuoTabletopKit.startTabletopMode()
        } else if #available(iOS 27.1, *),
                  DuoTabletopKit.isTabletopMode,
                  let hinge = DuoHingeKit.currentStatusHinge,
                  hinge.status == .closed {
            DuoTabletopKit.stopTabletopMode()
        }
        
        guard #available(iOS 27.1, *), DuoTabletopKit.isTabletopActive else { return }
        if windowScene.effectiveGeometry.interfaceOrientation == DuoTabletopKit.tabletopPendingOrientation {
            DuoTabletopKit.finishTabletopOrientationFlip()
        }
        DuoTabletopKit.relayoutTabletopPanesIfNeeded()
    }
    
    @available(iOS 27.0, tvOS 27.0, *)
    func supportedInterfaceOrientations(for windowScene: UIWindowScene) -> UIInterfaceOrientationMask {
        return OrientationLockPin.resolvedMask(for: window)
    }
    
    @available(iOS 26.0, tvOS 26.0, *)
    func preferredWindowingControlStyle(for windowScene: UIWindowScene) -> UIWindowScene.WindowingControlStyle {
        return .minimal
    }
}

extension ApplicationSceneDelegate: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: any UIDropSession) {
        window?.showDropView()
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: any UIDropSession) -> Bool {
        if let _ = session.localDragSession {
            return false
        }
        return true
    }
    
    // 处理拖放操作
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        let allowedTypes = UTType.allTypes
        if session.hasItemsConforming(toTypeIdentifiers: allowedTypes.map({ $0.identifier })) {
            UIView.makeLoading()
            let dispatchGroup = DispatchGroup()
            var urls: [URL] = []
            var errors: [ImportError] = []
            let supportIdentifiers = allowedTypes.reduce("") { $0 + " " + $1.identifier }
            for item in session.items {
                let itemProvider = item.itemProvider
                var supportIdentifier: String? = nil
                //找出item支持的UTType的identifier
                for itemProviderIdentifier in itemProvider.registeredTypeIdentifiers {
                    if supportIdentifiers.contains(itemProviderIdentifier, caseSensitive: false) {
                        supportIdentifier = itemProviderIdentifier
                        break
                    }
                }
                
                if let supportIdentifier = supportIdentifier {
                    //找到了支持的类型
                    if let utType = UTType(supportIdentifier),
                       let extens = utType.tags[.filenameExtension]?.first,
                       let suggestedName = itemProvider.suggestedName {
                        //获取到文件名
                        let fileName = suggestedName + "." + extens
                        //将内容先复制到缓存目录中
                        let dstUrl = URL(fileURLWithPath: R.Path.DropWorkSpace.appendingPathComponent(fileName))
                        dispatchGroup.enter()
                        itemProvider.loadFileRepresentation(forTypeIdentifier: supportIdentifier) { url, error in
                            defer { dispatchGroup.leave() }
                            if let url = url {
                                do {
                                    try FileManager.safeCopyItem(at: url, to: dstUrl, shouldReplace: true)
                                    //复制成功
                                    urls.append(dstUrl)
                                } catch {
                                    //复制失败
                                    errors.append(.badCopy(fileName: fileName))
                                }
                            }
                        }
                    }
                }
            }
            
            // 所有操作完成后刷新UI
            dispatchGroup.notify(queue: .main) {
                if urls.count > 0 {
                    FilesImporter.importFiles(urls: urls, preErrors: errors, in: nil)
                } else {
                    UIView.hideLoading()
                    UIView.makeToast(message: R.string.localizable.dropErrorLoadFailed())
                }
            }
        } else {
            UIView.makeToast(message: R.string.localizable.dropErrorNotSupportFile())
        }
    }
    
    // 设置拖放操作类型为复制
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: any UIDropSession) {
        window?.hideDropView()
    }
}

/// LaunchScreen layout plus a spinner, used only while System.core is extracted on first launch or upgrade.
private final class LaunchPlaceholderViewController: UIViewController {
    override var prefersStatusBarHidden: Bool { true }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backgroundImageView = UIImageView(image: R.image.launch_bg())
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        
        let iconImageView = UIImageView(image: R.image.icon_corner())
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layerCornerRadius = 20
        
        let titleImageView = UIImageView(image: R.image.app_title_light())
        titleImageView.contentMode = .scaleToFill
        
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = false
        indicator.startAnimating()
        
        view.addSubview(backgroundImageView)
        view.addSubview(iconImageView)
        view.addSubview(titleImageView)
        view.addSubview(indicator)
        
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-80)
            make.size.equalTo(80)
        }
        titleImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        indicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleImageView.snp.bottom).offset(R.Size.ContentSpaceHuge)
        }
    }
}
