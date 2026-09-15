//
//  FilesImporter.swift
//  ManicEmu
//
//  Created by Max on 2025/1/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UniformTypeIdentifiers
import RealmSwift
import ZipArchive
import ZIPFoundation
import IceCream
import SmartCodable
import Citra
import PLzmaSDK
import Unrar

class FilesImporter: NSObject {
    static let shared = FilesImporter()
    private override init() {}
    private var manualHandle: (([URL])->Void)? = nil
    private var cancelHandle: (() -> Void)? = nil
    
    func presentImportController(supportedTypes: [UTType] = UTType.allTypes,
                                 allowsMultipleSelection: Bool = true,
                                 manualHandle: (([URL])->Void)? = nil,
                                 cancelHandle: (() -> Void)? = nil,
                                 appControllerPresent: Bool = false) {
        let documentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        documentPickerViewController.delegate = self
        documentPickerViewController.overrideUserInterfaceStyle = UIDevice.isDarkMode ? .dark : .light
        documentPickerViewController.allowsMultipleSelection = allowsMultipleSelection
        documentPickerViewController.modalPresentationStyle = .formSheet
        documentPickerViewController.sheetPresentationController?.preferredCornerRadius = R.Size.CornerRadiusLarge
        topViewController(appController: appControllerPresent)?.present(documentPickerViewController, animated: true)
        self.manualHandle = manualHandle
        self.cancelHandle = cancelHandle
    }
}

extension FilesImporter: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if manualHandle != nil {
            manualHandle?(urls)
            manualHandle = nil
        } else {
            FilesImporter.importFiles(urls: urls)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        cancelHandle?()
        cancelHandle = nil
    }
}

extension FilesImporter {
    //Pre-processed information specifically for PSP games
    static var importGameInfos = [String: Any]()
    //Prevent crashes during concurrent database inserts when the same content is imported simultaneously.
    static var processingHashes = Set<String>()
    private static let stateLock = NSLock()
    
    private static func tryBeginProcessing(_ hash: String) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return processingHashes.insert(hash).inserted
    }
    
    private static func clearProcessingState() {
        stateLock.lock()
        processingHashes.removeAll()
        importGameInfos.removeAll()
        stateLock.unlock()
    }
    
    private static func setPSPImportGameInfo(_ game: LibretroPSPGame, for path: String) {
        stateLock.lock()
        importGameInfos[path] = game
        stateLock.unlock()
    }
    
    private static func pspImportGameInfo(for path: String) -> LibretroPSPGame? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return importGameInfos[path] as? LibretroPSPGame
    }
    
    static func importFiles(urls: [URL],
                            preErrors: [ImportError] = [],
                            silentMode: Bool = PlayViewController.isGaming,
                            importCompletion: (()->Void)? = nil) {
        if urls.isEmpty {
            UIView.hideLoading()
            if preErrors.count > 0 {
                UIView.makeToast(message: String.errorMessage(from: preErrors))
            } else {
                UIView.makeToast(message: R.string.localizable.filesImporterErrorEmptyContent())
            }
            importCompletion?()
            return
        }
        
        if !silentMode {
            UIView.makeLoading()
        }
        
        //Process the zip file.
        handleZip(urls: urls, silentMode: silentMode) { unzipUrls in
            var urls = urls.filter({ !FileType.zip.extensions.contains($0.pathExtension.lowercased()) }) + unzipUrls
            //First, handle the cue and m3u.
            let (multiFileResultUrls, multiFileResultError, multiFileResultItems) = handleMultiFiles(urls: urls)
            let (m3uResultUrls, m3uResultError, m3uResultM3uItems, m3uResultMultiFileItems) = handleM3uFiles(urls: multiFileResultUrls, multiFileItems: multiFileResultItems)
            
            urls = m3uResultUrls
            let nGage20Urls = urls.filter { isNGage20PackageURL($0) }
            urls.removeAll { isNGage20PackageURL($0) }
            let group = DispatchGroup()
            var errors: [ImportError] = preErrors
            var gameErrors = [ImportError]()
            gameErrors.append(contentsOf: m3uResultError)
            gameErrors.append(contentsOf: multiFileResultError)
            var skinErrors: [ImportError] = []
            var gameSaveErrors: [ImportError] = []
            var importGames: [(id: String, name: String)] = []
            var importSkins: [String] = []
            var importGameSaves: [(id: String, name: String)] = []
            let hasSymbianFirmware = !(LibretroCore.getSymbianDevices() ?? []).isEmpty
            var skippedSymbianWithoutFirmware = false
            for url in urls {
                if isSymbianImportURL(url) {
                    if !hasSymbianFirmware {
                        skippedSymbianWithoutFirmware = true
                        continue
                    }
                    group.enter()
                    importGame(url: url, items: []) { gameId, gameName, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                gameErrors.append(error)
                            }
                            if let gameId, let gameName {
                                importGames.append((gameId, gameName))
                            }
                            group.leave()
                        }
                    }
                    continue
                }
                if let fileType = FileType(fileExtension: url.pathExtension) {
                    //The file type was identified by its extension.
                    switch fileType {
                    case .game:
                        group.enter()
                        let isCueOrGdi = url.pathExtension.lowercased() == "cue" || (url.pathExtension.lowercased() == "gdi")
                        let isMultiFiles = isCueOrGdi || (url.pathExtension.lowercased() == "m3u")
                        let multiFileRoms = (isCueOrGdi ? m3uResultMultiFileItems : m3uResultM3uItems)
                        let items = multiFileRoms.first(where: { $0.url == url })?.files ?? []
                        importGame(url: url, items: isMultiFiles ? items : []) { gameId, gameName, error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    gameErrors.append(error)
                                }
                                if let gameId, let gameName {
                                    importGames.append((gameId, gameName))
                                }
                                group.leave()
                            }
                        }
                        
                    case .gameSave:
                        group.enter()
                        importSave(url: url) { gameId, gameSaveName, error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    gameSaveErrors.append(error)
                                }
                                if let gameId, let gameSaveName {
                                    importGameSaves.append((gameId, gameSaveName))
                                }
                                group.leave()
                            }
                        }
                        
                    case .skin:
                        group.enter()
                        importSkin(url: url) { skinName, error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    skinErrors.append(error)
                                }
                                if let skinName = skinName {
                                    importSkins.append(skinName)
                                }
                                group.leave()
                            }
                        }
                        
                    default:
                        break
                    }
                } else {
                    //File type cannot be recognized. This basically never happens unless there's a bug in UIDocumentPickerViewController.
                    group.enter()
                    errors.append(.noPermission(fileUrl: url))
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                clearProcessingState()
                
                UIView.hideLoading()
                importNGage20Packages(nGage20Urls) {
                    if silentMode {
                        importCompletion?()
                        return
                    }
                    // Handle save-file errors first.
                ErrorHandler.shared.handleErrors(gameSaveErrors) { error in
                    switch error {
                    case .saveNoMatchGames(_), .saveAlreadyExist(_, _), .saveMatchToMuch(_, _):
                        return true
                    default:
                        return false
                    }
                } handleAction: { error, actionCompletion in
                    if Database.realm.objects(Game.self).where({ !$0.isDeleted }).count == 0 {
                        //没有游戏
                        switch error {
                        case .saveNoMatchGames(let url), .saveMatchToMuch(let url, _):
                            UIView.makeAlert(title: R.string.localizable.importErrorTitle(),
                                             detail: R.string.localizable.importGameSaveFailedNoGameError(url.lastPathComponent), hideAction: { _ in
                                actionCompletion()
                            })
                        default:
                            actionCompletion()
                        }
                    } else {
                        switch error {
                        case .saveNoMatchGames(let url):
                            GamesSelectionView.showSaveMatch(title: R.string.localizable.gameSaveMatchTitle(),
                                                             detail: error.localizedDescription,
                                                             gameSaveUrl: url,
                                                             completion: {
                                actionCompletion()
                            })

                        case .saveAlreadyExist(let url, let game):
                            UIView.makeAlert(title: R.string.localizable.gameSaveAlreadyExistTitle(),
                                             detail: error.localizedDescription,
                                             confirmTitle: R.string.localizable.confirmTitle(),
                                             enableForceHide: false,
                                             confirmAction: {
                                var url = url
                                if game.gameType == .j2me,
                                    game.defaultCore == 0,
                                   let fixedUrl = Database.fixJ2meJSSave(fileName: game.fileName, url: url) {
                                    url = fixedUrl
                                }
                                try? FileManager.safeCopyItem(at: url, to: game.gameSaveUrl, shouldReplace: true)
                                SyncManager.upload(localFilePath: game.gameSaveUrl.path)
                                actionCompletion()
                            })
                        case .saveMatchToMuch(let url, let games):
                            GamesSelectionView.showSaveMatch(title: R.string.localizable.gameSaveMathToMuchTitle(),
                                                             detail: error.localizedDescription,
                                                             gameSaveUrl: url,
                                                             showGames: games,
                                                             completion: {
                                actionCompletion()
                            })
                        default:
                            actionCompletion()
                        }
                    }
                } completion: { unhandledErrors in
                    func handleImportSuccess() {
                        if importGames.count > 0 && importSkins.count == 0 && importGameSaves.count == 0 {
                            //判断一下gameType是否是未知
                            let realm = Database.realm
                            realm.refresh()
                            let group = DispatchGroup()
                            for importGame in importGames {
                                if let game = realm.object(ofType: Game.self, forPrimaryKey: importGame.id), game.gameType == .unknown {
                                    //弹窗要求用户进行平台选择
                                    group.enter()
                                    PlatformSelectionView.show(games: [game], cancelEnable: false) {
                                        group.leave()
                                    }
                                }
                            }
                            
                            group.notify(queue: .main) {
                                //导入游戏成功
                                if let home = topViewController(appController: true) as? HomeViewController,
                                    home.homeTabBar.currentSelection == .games {
                                    UIView.makeToast(message: R.string.localizable.importGameSuccessTitle())
                                } else {
                                    let detail: String
                                    let confirmTitle: String
                                    if importGames.count == 1 {
                                        detail = R.string.localizable.importGameSuccessDetailForOne(String.successMessage(from: importGames.map({ $0.name })))
                                        confirmTitle = R.string.localizable.startGameTitle()
                                    } else {
                                        detail = R.string.localizable.importGameSuccessDetail(String.successMessage(from: importGames.map({ $0.name })))
                                        confirmTitle =  R.string.localizable.checkTitle()
                                    }
                                    
                                    UIView.makeAlert(title: R.string.localizable.importGameSuccessTitle(),
                                                     detail: detail,
                                                     confirmTitle: confirmTitle,
                                                     confirmAction: {
                                        UIView.hideAllAlert {
                                            if importGames.count == 1 {
                                                startGame(gameId: importGames.first!.id)
                                            } else {
                                                NotificationCenter.default.post(name: R.NotificationName.HomeSelectionChange, object: HomeTabBar.BarSelection.games)
                                            }
                                        }
                                    })
                                }
                            }

                            
                        } else if importSkins.count > 0 && importGames.count == 0 && importGameSaves.count == 0 {
                            if SkinSettingsView.hasShownInstance {
                                UIView.makeToast(message: R.string.localizable.importSkinSuccessTitle())
                            } else {
                                //导入皮肤成功
                                UIView.makeAlert(title: R.string.localizable.importSkinSuccessTitle(),
                                                 detail: R.string.localizable.importSkinSuccessDetail(String.successMessage(from: importSkins)),
                                                 confirmTitle: R.string.localizable.checkTitle(),
                                                 confirmAction: {
                                    UIView.hideAllAlert {
                                        if importSkins.count == 1 {
                                            let skinName = importSkins.first!
                                            if let gameType = Database.realm.objects(Skin.self).first(where: { $0.name == skinName })?.gameType {
                                                SkinSettingsView.show(gameType: gameType)
                                            } else {
                                                SkinSettingsView.show()
                                            }
                                        } else {
                                            SkinSettingsView.show()
                                        }
                                    }
                                })
                            }
                        } else if importGameSaves.count > 0 && importGames.count == 0 && importSkins.count == 0 {
                            //导入存档成功
                            let detail: String
                            var confirmTitle: String? = nil
                            if importGameSaves.count == 1 {
                                detail = R.string.localizable.importGameSaveSuccessForOne(String.successMessage(from: importGameSaves.map({ $0.name })))
                                confirmTitle = R.string.localizable.startGameTitle()
                            } else {
                                detail = R.string.localizable.importGameSaveSuccessDetail(String.successMessage(from: importGameSaves.map({ $0.name })))
                            }
                            UIView.makeAlert(title: R.string.localizable.importGameSaveSuccessTitle(),
                                             detail: detail,
                                             confirmTitle: confirmTitle,
                                             confirmAction: {
                                UIView.hideAllAlert {
                                    startGame(gameId: importGameSaves.first!.id)
                                }
                            })
                        } else if importGameSaves.count > 0 || importGames.count > 0 || importSkins.count > 0 {
                            //导入多种资源成功
                            UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                        }
                    }
                    
                    errors.append(contentsOf: unhandledErrors)
                    errors.append(contentsOf: gameErrors)
                    errors.append(contentsOf: skinErrors)
                    func finishImport() {
                        if skippedSymbianWithoutFirmware {
                            UIView.makeAlert(detail: R.string.localizable.symbianGameNeedFirmware(),
                                             confirmTitle: R.string.localizable.goToInstallFirmware(),
                                             confirmAction: {
                                SymbianFirmwareView.show()
                            }, hideAction: { _ in
                                handleImportSuccess()
                                importCompletion?()
                            })
                        } else {
                            handleImportSuccess()
                            importCompletion?()
                        }
                    }
                    if errors.count > 0 {
                        UIView.makeAlert(title: R.string.localizable.importErrorTitle(),
                                         detail: String.errorMessage(from: errors),
                                         cancelTitle: R.string.localizable.confirmTitle(),
                                         hideAction: { _ in
                            finishImport()
                        })
                    } else {
                        finishImport()
                    }
                }
                }
            }
        }
    }
    
    private static func startGame(gameId: String) {
        let realm = Database.realm
        if let game = realm.object(ofType: Game.self, forPrimaryKey: gameId) {
            game.handleTapAction()
        }
    }
    
    class ErrorHandler {
        static let shared = ErrorHandler()
        // 处理错误主方法
        func handleErrors(_ errors: [ImportError],
                          shouldHandle: @escaping (_ error: ImportError)->Bool,
                          handleAction: @escaping (_ error: ImportError, _ actionCompletion: @escaping ()->Void)->Void,
                          completion: @escaping (_ unhandledErrors: [ImportError]) -> Void) {
            var unhandledErrors = [ImportError]()
            var currentIndex = 0
            
            // 递归处理方法
            func processNext() {
                guard currentIndex < errors.count else {
                    completion(unhandledErrors)
                    return
                }
                
                let error = errors[currentIndex]
                currentIndex += 1
                
                if shouldHandle(error) {
                    // 需要处理的错误
                    handleAction(error) {
                        // 继续处理下一个
                        processNext()
                    }
                } else {
                    // 直接收集不需要处理的错误
                    unhandledErrors.append(error)
                    processNext()
                }
            }
            
            processNext()
        }
    }
    
    private static func importGame(url: URL, items: [URL] = [], completion: ((_ gameId: String?, _ gameName: String?, _ error: ImportError?)->Void)?) {
        DispatchQueue.global(qos: .userInitiated).async {
            if isSymbianImportURL(url) {
                importSymbianGame(url: url, completion: completion)
                return
            }
            let realm = Database.realm
            var ciaTitleUrl: URL? = nil
            let originalUrl = url
            var url = url
            var threeDSGameInfo: CitraGameInformation? = nil
            if FileType.get3DSExtensions().contains([url.pathExtension.lowercased()]) {
                if url.pathExtension.lowercased() == "cia" {
                    Log.debug("开始安装")
                    let status = CitraCore.shared().importGame(at: url)
                    let ciaInfo = CitraCore.shared().getCIAInfo(url: url, isSdmc: true)
                    if let titlePath = ciaInfo.titlePath {
                        ciaTitleUrl = URL(fileURLWithPath: titlePath)
                    }
                    guard let ciaPath = ciaInfo.contentPath else {
                        Log.debug("安装CIA出错，无法获取CIA的安装路径")
                        Self.removeCIA(ciaTitleUrl: ciaTitleUrl)
                        Self.discardRommPending(fileName: originalUrl.lastPathComponent)
                        completion?(nil, nil, .badFile(fileName: url.lastPathComponent.deletingPathExtension))
                        return
                    }
                    
                    switch status {
                    case .success:
                        Log.debug("游戏安装目录:\(ciaPath)")
                        if ciaPath.contains("/00040000/") {
                            //游戏本体
                            url = URL(fileURLWithPath: ciaPath)
                        } else {
                            DispatchQueue.main.async {
                                UIView.makeToast(message: R.string.localizable.threeDSUpdateInstallSuccess(), identifier: "threeDSUpdateInstallSuccess")
                            }
                            Self.discardRommPending(fileName: originalUrl.lastPathComponent)
                            completion?(nil, nil, nil)
                            return
                        }
                    case .errorEncrypted:
                        Log.debug("CIA加密了")
                        Self.removeCIA(ciaTitleUrl: ciaTitleUrl)
                        Self.discardRommPending(fileName: originalUrl.lastPathComponent)
                        completion?(nil, nil, .decryptFailed(fileName: url.lastPathComponent))
                        return
                    default:
                        Log.debug("CIA安装失败")
                        Self.removeCIA(ciaTitleUrl: ciaTitleUrl)
                        Self.discardRommPending(fileName: originalUrl.lastPathComponent)
                        completion?(nil, nil, .badFile(fileName: url.lastPathComponent))
                        return
                    }
                }
                if let gameInfo = CitraCore.shared().information(for: url) {
                    Log.debug("获取游戏信息 identifier:\(gameInfo.identifier) title:\(gameInfo.title)")
                    threeDSGameInfo = gameInfo
                } else {
                    Log.debug("无法获取3DS ROM信息")
                    Self.removeCIA(ciaTitleUrl: ciaTitleUrl)
                    Self.discardRommPending(fileName: originalUrl.lastPathComponent)
                    completion?(nil, nil, .badFile(fileName: url.lastPathComponent))
                    return
                }
            }
            
            if let hash = FileHashUtil.truncatedHash(url: url) {
                guard tryBeginProcessing(hash) else {
                    completion?(nil, nil, .fileExist(fileName: url.lastPathComponent))
                    return
                }
                
                func recoverDeletedGame(_ game: Game, realm: Realm, recoverFaile: (() -> Void)? = nil) {
                    guard game.isDeleted else {
                        recoverFaile?()
                        return
                    }
                    do {
                        try realm.write { game.isDeleted = false }
                        completion?(game.id, game.gameType == ._3ds ? (game.displayName) : game.name, nil)
                    } catch {
                        Log.debug("导入游戏失败，写入数据库失败:\(error)")
                        completion?(nil, nil, .writeDatabase(fileName: game.name))
                    }
                }
                
                if let game = realm.object(ofType: Game.self, forPrimaryKey: hash) {
                    // Already in the library: drop the pending RomM link so an old game is not rebound.
                    Self.discardRommPending(fileName: originalUrl.lastPathComponent)
                    if game.isRomExtsts {
                        //游戏文件也存在
                        Log.debug("导入游戏失败，游戏已经存在数据库")
                        recoverDeletedGame(game, realm: realm, recoverFaile: {
                            completion?(nil, nil, .fileExist(fileName: url.lastPathComponent))
                        })
                        return
                    } else {
                        do {
                            if items.count > 0 {
                                //可能是m3u或者cue或者gdi
                                let romUrl = game.romUrl
                                let romParentPath = romUrl.path.deletingLastPathComponent
                                try FileManager.safeCopyItem(at: url, to: romUrl, shouldReplace: true)
                                for item in items {
                                    try FileManager.safeCopyItem(at: item, to: URL(fileURLWithPath: romParentPath.appendingPathComponent(item.lastPathComponent)), shouldReplace: true)
                                }
                                // Upload all files (main + companions) to iCloud
                                FilesSyncManager.shared.uploadROMFiles(for: game, extraFiles: items.map {
                                    URL(fileURLWithPath: romParentPath.appendingPathComponent($0.lastPathComponent))
                                })
                                recoverDeletedGame(game, realm: realm, recoverFaile: {
                                    completion?(game.id, game.name, nil)
                                })
                                return
                                
                            } else {
                                try FileManager.safeCopyItem(at: url, to: game.romUrl, shouldReplace: true)
                                FilesSyncManager.shared.uploadROMFiles(for: game)
                                //文件复制成功
                                recoverDeletedGame(game, realm: realm, recoverFaile: {
                                    completion?(game.id, game.name, nil)
                                })
                                return
                            }
                        } catch {
                            //复制文件出错
                            Log.debug("导入游戏失败，数据库存在 但是文件不存在 复制失败:\(error)")
                            completion?(nil, nil, .badCopy(fileName: game.name))
                            return
                        }
                    }
                } else {
                    //游戏不存在 创建游戏
                    let game = Game()
                    game.id = hash
                    game.name = originalUrl.deletingPathExtension().lastPathComponent
                    game.fileExtension = url.pathExtension
                    game.importDate = Date()
                    
                    //handle 3ds game info
                    if let threeDSGameInfo {
                        //读取3DS信息
                        game.extras = [
                            ExtraKey.identifier.rawValue: threeDSGameInfo.identifier,
                            ExtraKey.regions.rawValue: threeDSGameInfo.regions
                        ].jsonData()
                        if !threeDSGameInfo.title.isEmpty {
                            game.aliasName = threeDSGameInfo.title
                        }
                        
                        for (index, identifier) in R.Numbers.ThreeDSHomeMenuIdentifiers.enumerated() {
                            if identifier == threeDSGameInfo.identifier {
                                //这是一个home menu app 进行自定义别名
                                game.aliasName = "Home Menu (\(R.Strings.ThreeDSHomeMenuRegions[index]))"
                                break
                            }
                        }
                    }
                    
                    //handle psp pbp game
                    let isPSPPBP = isPSPPBPGame(url: url)
                    if isPSPPBP, let pspPBPGame = pspImportGameInfo(for: url.path) {
                        game.name = pspPBPGame.title
                        if let icon = pspPBPGame.icon,
                           let iconData = icon.jpegData(compressionQuality: 0.7) {
                            game.gameCover = CreamAsset.create(objectID: game.id, propName: "gameCover", data: iconData)
                        }
                        var extras = [
                            ExtraKey.PSPGameCode.rawValue: pspPBPGame.gameID,
                            ExtraKey.isPSPPBPGame.rawValue: true
                        ]
                        if let range = url.path.range(of: "PPSSPP/PSP/GAME/") {
                            extras[ExtraKey.pspPBPGamePath.rawValue] = String(url.path[range.upperBound...])
                        }
                        game.extras = extras.jsonData()
                    }
                    
                    var gameType = isPSPPBP ? .psp : GameType(fileExtension: game.fileExtension)
                    
                    if (game.fileExtension.lowercased() == "zip" || game.fileExtension.lowercased() == "7z") &&
                        MAMEKit.isSupportTitle(fileName: game.name) {
                        gameType = .arcade
                        if R.Strings.NaomiTitles.contains(game.name) {
                            game.extras = [ExtraKey.arcadeType.rawValue: 1].jsonData()
                        } else if R.Strings.AtomiswaveTitles.contains(game.name) {
                            game.extras = [ExtraKey.arcadeType.rawValue: 2].jsonData()
                        } else if R.Strings.SegaSPTitles.contains(game.name) {
                            game.extras = [ExtraKey.arcadeType.rawValue: 3].jsonData()
                        }
                        if let mameInfo = MAMEKit.getMAMEInfo(fileName: game.name) {
                            game.aliasName = mameInfo.name
                        }
                    }
                    
                    if gameType != .notSupport {
                        game.gameType = gameType
                        ///Handling game info for specific game types.
#if !SIDE_LOAD
                        //32x mcd
                        if game.gameType == ._32x || gameType == .mcd {
                            game.defaultCore = 1
                        }
#endif
                        
                        //Using the default core configured by the user.
                        let globalCoreSwitch = GlobalCoreSwitch.getConfig(realm: realm)
                        if let index = globalCoreSwitch.getUsingCoreIndex(gameType: gameType) {
                            Log.debug("[FilesImporter] using \(globalCoreSwitch.getUsingCoreName(gameType: gameType) ?? "Unknown")(\(index)) core for \(gameType.localizedShortName)")
                            game.defaultCore = index
                        }
                        
                        //j2me
                        if game.gameType == .j2me, let j2MEManifest = J2MEManifest.read(from: url.path) {
                            game.aliasName = j2MEManifest.displayName
                            game.extras = [ExtraKey.j2meScreenSize.rawValue: j2MEManifest.screenSize.stringValue].jsonData()
                            if let iconData = j2MEManifest.imageData {
                                game.gameCover = CreamAsset.create(objectID: game.id, propName: "gameCover", data: iconData)
                            }
                        }

                        if game.gameType == .flash, let coverData = FLASHCover.extractJPEGData(from: url) {
                            game.gameCover = CreamAsset.create(objectID: game.id, propName: "gameCover", data: coverData)
                        }
                        
                        //Obtain the game code for PSP.
                        if gameType == .psp, !isPSPPBP, let gameCode = LibretroCore.getPSPGameID(withRomPath: url.path) {
                            game.extras = [ExtraKey.PSPGameCode.rawValue: gameCode].jsonData()
                        }

                        if game.isDolphinCore {
                            if let dolphinID = DolphinGameID.read(from: url) {
                                if let extras = game.extras,
                                   let data = Game.updateExtra(extras: extras, key: ExtraKey.dolphinGameID.rawValue, value: dolphinID) {
                                    game.extras = data
                                } else {
                                    game.extras = [ExtraKey.dolphinGameID.rawValue: dolphinID].jsonData()
                                }
                            }
                            game.region = 1
                        }
                        
                        if game.gameType == .ngp {
                            game.extras = [ExtraKey.gameTypeCategory.rawValue: 1].jsonData()
                        }
                        
                        if game.gameType == .wsc {
                            let ext = url.pathExtension.lowercased()
                            if ext == "ws" || ext == "pc2" || ext == "pcv2" {
                                game.extras = [ExtraKey.gameTypeCategory.rawValue: 1].jsonData()
                            }
                        }
                        
                        do {
                            //Copy the ROMs
                            if ciaTitleUrl == nil {
                                //cia格式的3DS不需要拷贝了 因为已经安装进游戏目录了
                                if items.count > 0 {
                                    //可能是m3u或者cue或者gdi
                                    let romUrl = game.romUrl
                                    let romParentPath = romUrl.path.deletingLastPathComponent
                                    try FileManager.safeCopyItem(at: url, to: romUrl, shouldReplace: true)
                                    for item in items {
                                        try FileManager.safeCopyItem(at: item, to: URL(fileURLWithPath: romParentPath.appendingPathComponent(item.lastPathComponent)), shouldReplace: true)
                                    }
                                } else if !isPSPPBP {
                                    try FileManager.safeCopyItem(at: url, to: game.romUrl, shouldReplace: true)
                                }
                            }
                            do {
                                try realm.write {
                                    FilesSyncPolicy.applyDefaultROMSyncFlag(to: game)
                                    realm.add(game)
                                }
                                FilesSyncManager.shared.uploadROMFiles(for: game, extraFiles: items.map {
                                    URL(fileURLWithPath: game.romUrl.path.deletingLastPathComponent.appendingPathComponent($0.lastPathComponent))
                                })
                                if RommLibrary.shared.hasPendingLink(fileName: originalUrl.lastPathComponent)
                                    || RommLibrary.shared.hasPendingLink(fileName: game.fileName) {
                                    RommLibrary.shared.applyAfterImport(gameId: game.id, fileName: originalUrl.lastPathComponent)
                                } else {
                                    OnlineCoverManager.shared.addCoverMatch(OnlineCoverManager.CoverMatch(game: game))
                                }
                                completion?(game.id, game.gameType == ._3ds ? (game.displayName) : game.name, nil)
                                
                                return
                            } catch {
                                //写入数据失败
                                Log.debug("导入游戏失败，写入数据库失败:\(error)")
                                if let ciaTitleUrl {
                                    try? FileManager.safeRemoveItem(at: ciaTitleUrl)
                                }
                                Self.discardRommPending(fileName: originalUrl.lastPathComponent)
                                completion?(nil, nil, .writeDatabase(fileName: game.name))
                                return
                            }
                        } catch {
                            //复制文件失败
                            Log.debug("导入游戏失败，复制失败:\(error)")
                            if let ciaTitleUrl {
                                try? FileManager.safeRemoveItem(at: ciaTitleUrl)
                            }
                            Self.discardRommPending(fileName: originalUrl.lastPathComponent)
                            completion?(nil, nil, .badCopy(fileName: game.name))
                            return
                        }
                    } else {
                        //无法识别文件类型
                        Log.debug("导入游戏失败，后缀不正确\(game.fileName)")
                        Self.removeCIA(ciaTitleUrl: ciaTitleUrl)
                        Self.discardRommPending(fileName: originalUrl.lastPathComponent)
                        completion?(nil, nil, .badExtension(fileName: game.name))
                        return
                    }
                }
            } else {
                //无法计算文件哈希
                Log.debug("导入游戏失败，无法计算文件哈希")
                Self.removeCIA(ciaTitleUrl: ciaTitleUrl)
                Self.discardRommPending(fileName: originalUrl.lastPathComponent)
                completion?(nil, nil, .unableToHash(fileName: url.lastPathComponent))
                return
            }
        }
    }
    
    private static func discardRommPending(fileName: String) {
        RommLibrary.shared.discardPendingLink(fileName: fileName)
    }
    
    private static func removeCIA(ciaTitleUrl: URL?) {
        if let ciaTitleUrl {
            try? FileManager.safeRemoveItem(at: ciaTitleUrl)
        }
    }
    
    private static func importSave(url: URL, completion: ((_ gameId: String?, _ gameName: String?, _ error: ImportError?)->Void)?) {
        DispatchQueue.global().async {
            var url = url
            if url.path.contains(".3ds.sav") {
                handle3DSGameSave(url: url, completion: {
                    completion?(nil, nil, nil)
                })
                return
            }
            
            if url.path.contains(".psp.sav") {
                handlePSPGameSave(url: url, completion: {
                    completion?(nil, nil, nil)
                })
                return
            }
            
            let realm = Database.realm
            let fileExtension = url.pathExtension
            let fileName = url.deletingPathExtension().lastPathComponent
            var games: Results<Game>
            if let gameType = GameType(saveFileExtension: fileExtension) {
                games = realm.objects(Game.self).where { $0.name == fileName && $0.gameType == gameType && !$0.isDeleted }
            } else {
                games = realm.objects(Game.self).where { $0.name == fileName && !$0.isDeleted }
            }
            if games.count == 0 {
                //该存档没有匹配到游戏
                completion?(nil, nil, .saveNoMatchGames(gameSaveUrl: url))
                return
            } else if games.count == 1 {
                //匹配到游戏了
                //注意这个game带到别的线程使用会报错
                let game = games.first!
                if game.isSaveExtsts {
                    //匹配的游戏的存档也存在了 不再复制
                    //要将realm对象传输出去 最好搞到主线程上
                    let ref = ThreadSafeReference(to: game)
                    let gameName = game.displayName
                    DispatchQueue.main.async {
                        let realm = Database.realm
                        if let game = realm.resolve(ref) {
                            completion?(nil, nil, .saveAlreadyExist(gameSaveUrl: url, game: game))
                        } else {
                            completion?(nil, nil, .writeDatabase(fileName: gameName))
                        }
                    }
                    return
                } else {
                    //匹配的游戏还没有存档 开始复制
                    do {
                        if game.gameType == .j2me,
                            game.defaultCore == 0,
                           let fixedUrl = Database.fixJ2meJSSave(fileName: game.fileName, url: url) {
                            url = fixedUrl
                        }
                        try FileManager.safeCopyItem(at: url, to: game.gameSaveUrl)
                        SyncManager.upload(localFilePath: game.gameSaveUrl.path)
                        completion?(game.id, game.name, nil)
                        return
                    } catch {
                        completion?(nil, nil, .badCopy(fileName: "\(url.lastPathComponent)"))
                        return
                    }
                }
            } else if games.count > 0 {
                //要将realm对象传输出去 最好搞到主线程上
                let ref = ThreadSafeReference(to: games)
                DispatchQueue.main.async {
                    let realm = Database.realm
                    if let games = realm.resolve(ref) {
                        completion?(nil, nil, .saveMatchToMuch(gameSaveUrl: url, games: games.map { $0 }))
                    } else {
                        completion?(nil, nil, .saveMatchToMuch(gameSaveUrl: url, games: []))
                    }
                }
                return
            }
        }
    }
    
    private static func importSkin(url: URL, completion: ((_ skinName: String?, _ error: ImportError?)->Void)?) {
        DispatchQueue.global().async {
            if let controllerSkin = ControllerSkin(fileURL: url) {
                if let hash = FileHashUtil.truncatedHash(url: url) {
                    guard tryBeginProcessing(hash) else {
                        completion?(nil, .fileExist(fileName: url.lastPathComponent))
                        return
                    }
                    let realm = Database.realm
                    if let skin = realm.object(ofType: Skin.self, forPrimaryKey: hash) {
                        //skin数据库已经存在
                        if skin.isFileExtsts {
                            //skin文件也存在
                            completion?(nil, .fileExist(fileName: skin.fileName))
                            return
                        } else {
                            //skin文件不存在
                            do {
                                //复制成功
                                try FileManager.safeCopyItem(at: url, to: skin.fileURL, shouldReplace: true)
                                completion?(skin.name, nil)
                                return
                            } catch {
                                //复制失败
                                completion?(nil, .badCopy(fileName: skin.fileName))
                                return
                            }
                        }
                    } else if realm.objects(Skin.self).where({ $0.identifier == controllerSkin.identifier }).count > 0 {
                        //identifier冲突了
                        completion?(nil, .skinIdentifierConflict(identifier: controllerSkin.identifier))
                        return
                    } else {
                        //数据库skin不存在
                        let skin = Skin()
                        skin.id = hash
                        skin.identifier = controllerSkin.identifier
                        skin.name = controllerSkin.name
                        skin.fileName = url.lastPathComponent
                        skin.gameType = controllerSkin.gameType
                        skin.skinType = url.pathExtension.lowercased() == "playcase" ? .playcase : .import
                        skin.skinData = CreamAsset.create(objectID: skin.id, propName: "skinData", url: url)
                        do {
                            try realm.write {
                                realm.add(skin)
                            }
                            completion?(skin.name, nil)
                            return
                        } catch {
                            completion?(nil, .writeDatabase(fileName: skin.fileName))
                            return
                        }
                    }
                } else {
                    completion?(nil, .noPermission(fileUrl: url))
                    return
                }
            } else {
                //皮肤文件有问题
                completion?(nil, .skinBadFile(fileName: url.lastPathComponent))
                return
            }
        }
    }
    
    static func handleZip(urls: [URL], silentMode: Bool, completion: @escaping ([URL])->Void) {
        DispatchQueue.global().async {
            var results = [URL]()
            var needToHandleUrls = [URL]()
            
            
            for url in urls {
                let fileExtension = url.pathExtension.lowercased()
                if (fileExtension == "zip" || fileExtension == "7z") && MAMEKit.isSupportTitle(fileName: url.lastPathComponent.deletingPathExtension) {
                    results.append(url)
                    continue
                }
                
                if ["zip", "7z", "rar"].contains(fileExtension), isNGage10Archive(url) {
                    results.append(url)
                    continue
                }
                
                
                if url.pathExtension.lowercased() == "7z"  {
                    var sevenZipSnnerResults = [URL]()
                    do {
                        Log.debug("开始解压7z")
                        let archivePath = try Path(url.path)
                        let archivePathInStream = try InStream(path: archivePath)
                        let decoder = try Decoder(stream: archivePathInStream, fileType: .sevenZ)
                        let _ = try decoder.open()
                        let numberOfArchiveItems = try decoder.count()
                        for itemIndex in 0..<numberOfArchiveItems {
                            let item = try decoder.item(at: itemIndex)
                            if item.isDir {
                                continue
                            }
                            let path = try item.path().description
                            if path.lastPathComponent.hasPrefix(".") {
                                //跳过隐藏文件夹
                                continue
                            }
                            let itemArray = try ItemArray(capacity: 1)
                            if let _ = FileType(fileExtension: path.pathExtension) {
                                try itemArray.add(item: item)
                            } else {
                                continue
                            }
                            let dstPath = R.Path.ZipWorkSpace.appendingPathComponent(path)
                            Log.debug("构建路径:\(dstPath)")
                            let destUrl = URL(fileURLWithPath: dstPath)
                            if FileManager.default.fileExists(atPath: dstPath) {
                                try FileManager.safeRemoveItem(at: destUrl)
                            }
                            if !FileManager.default.fileExists(atPath: dstPath.deletingLastPathComponent) {
                                try FileManager.default.createDirectory(at: URL(fileURLWithPath: dstPath.deletingLastPathComponent), withIntermediateDirectories: true)
                            }
                            let _ = try decoder.extract(items: itemArray, to: Path(R.Path.ZipWorkSpace))
                            Log.debug("解压成功!")
                            sevenZipSnnerResults.append(destUrl)
                        }
                        results.append(contentsOf: sevenZipSnnerResults)
                    } catch {
                        Log.debug("解压7z失败:\(error)")
                        DispatchQueue.main.async {
                            UIView.makeToast(message: R.string.localizable.sevenZipDecompressError())
                        }
                    }
                    if sevenZipSnnerResults.isEmpty, !silentMode {
                        DispatchQueue.main.async {
                            UIView.makeToast(message: R.string.localizable.noSupportInZip(url.lastPathComponent))
                        }
                    }
                } else if url.pathExtension.lowercased() == "zip" {
                    //检查是不是PSP的PBP自制程序
                    if let pbpUrl = handlePSPPBPGame(url: url) {
                        results.append(pbpUrl)
                    } else {
                        needToHandleUrls.append(url)
                    }
                }
            }
            
            if needToHandleUrls.count > 0 {
                DispatchQueue.main.async {
                    UIView.hideLoading()
                    ZipHandlerView.show(urls: needToHandleUrls) { unzipUrls, noActionUrls in
                        results.append(contentsOf: noActionUrls)
                        if unzipUrls.count > 0 {
                            if !silentMode {
                                UIView.makeLoading()
                            }
                            
                            DispatchQueue.global().async {
                                for url in unzipUrls {
                                    if FileType.zip.extensions.contains(url.pathExtension) {
                                        var zipInnerResults = [URL]()
                                        if url.pathExtension.lowercased() == "zip" {
                                            
                                            //街机ROM则不解压
                                            if MAMEKit.isSupportTitle(fileName: url.lastPathComponent.deletingPathExtension) {
                                                results.append(url)
                                                continue
                                            }
                                            
                                            //先检查zip里面有没有支持的文件类型
                                            if SSZipArchive.isFilePasswordProtected(atPath: url.path) {
                                                //加密文件先不处理
                                                if !silentMode {
                                                    DispatchQueue.main.async {
                                                        UIView.makeToast(message: R.string.localizable.notSupportPasswordZip(url.lastPathComponent))
                                                    }
                                                }
                                                continue
                                            } else {
                                                //未加密
                                                if let archive = try? Archive(url: url, accessMode: .read, pathEncoding: nil) {
                                                    for entry in archive {
                                                        if entry.type == .file, let _ = FileType(fileExtension: entry.path.pathExtension) {
                                                            if entry.path.lastPathComponent.hasPrefix(".") {
                                                                //跳过隐藏文件夹
                                                                continue
                                                            }
                                                            do {
                                                                let dstPath = R.Path.ZipWorkSpace.appendingPathComponent(entry.decodedPath)
                                                                let destUrl = URL(fileURLWithPath: dstPath)
                                                                if FileManager.default.fileExists(atPath: dstPath) {
                                                                    try FileManager.safeRemoveItem(at: destUrl)
                                                                }
                                                                _ = try archive.extract(entry, to: destUrl)
                                                                zipInnerResults.append(destUrl)
                                                            } catch {
                                                                if !silentMode {
                                                                    DispatchQueue.main.async {
                                                                        UIView.makeToast(message: R.string.localizable.unzipFailed(entry.path.lastPathComponent))
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                    results.append(contentsOf: zipInnerResults)
                                                } else {
                                                    if !silentMode {
                                                        DispatchQueue.main.async {
                                                            UIView.makeToast(message: R.string.localizable.unzipFailed(url.lastPathComponent))
                                                        }
                                                    }
                                                    continue
                                                }
                                            }
                                        }
                                        if zipInnerResults.isEmpty, !silentMode {
                                            DispatchQueue.main.async {
                                                UIView.makeToast(message: R.string.localizable.noSupportInZip(url.lastPathComponent))
                                            }
                                        }
                                    }
                                }
                                DispatchQueue.main.async {
                                    completion(results)
                                    return
                                }
                            }
                        } else {
                            completion(results)
                            return
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(results)
                    return
                }
            }
        }
    }
    
    static func handle3DSGameSave(url: URL, completion: (()->Void)?) {
        if let archive = try? Archive(url: url, accessMode: .read, pathEncoding: nil) {
            var isValid = false
            for entry in archive {
                if entry.type == .file, entry.path.hasPrefix("sdmc") {
                    isValid = true
                    break
                }
            }

            guard isValid else {
                DispatchQueue.main.async {
                    UIView.makeToast(message: R.string.localizable.threeDSImportSaveFailed(url.lastPathComponent))
                }
                completion?()
                return
            }

            var isSaveExist = false
            for entry in archive {
                if entry.type == .file {
                    let savePath = R.Path.ThreeDS.appendingPathComponent(entry.path)
                    if FileManager.default.fileExists(atPath: savePath) {
                        isSaveExist = true
                        break
                    }
                }
            }
            
            func extractSaveFiles(archive: ZIPFoundation.Archive) {
                for entry in archive {
                    if entry.type == .file && entry.path.hasPrefix("sdmc") {
                        let savePath = R.Path.ThreeDS.appendingPathComponent(entry.path)
                        if FileManager.default.fileExists(atPath: savePath) {
                            try? FileManager.default.removeItem(atPath: savePath)
                        }
                        let _ = try? archive.extract(entry, to: URL(fileURLWithPath: savePath))
                    }
                }
            }
            
            if isSaveExist {
                //询问是否覆盖
                DispatchQueue.main.async {
                    UIView.hideLoading()
                    UIView.makeAlert(title: R.string.localizable.gameSaveAlreadyExistTitle(),
                                     detail: R.string.localizable.filesImporterErrorSaveAlreadyExist(url.lastPathComponent),
                                     confirmTitle: R.string.localizable.confirmTitle(),
                                     enableForceHide: false,
                                     confirmAction: {
                        if let archive = try? Archive(url: url, accessMode: .read, pathEncoding: nil) {
                            extractSaveFiles(archive: archive)
                            UIView.makeToast(message: R.string.localizable.importGameSaveSuccessTitle(), identifier: "importGameSaveSuccessTitle")
                        } else {
                            UIView.makeToast(message: R.string.localizable.threeDSImportSaveFailed(url.lastPathComponent))
                        }
                    }, hideAction: { _ in
                        completion?()
                    })
                }
            } else {
                //直接解压
                extractSaveFiles(archive: archive)
                DispatchQueue.main.async {
                    UIView.makeToast(message: R.string.localizable.importGameSaveSuccessTitle(), identifier: "importGameSaveSuccessTitle")
                }
                completion?()
            }
        } else {
            DispatchQueue.main.async {
                UIView.makeToast(message: R.string.localizable.threeDSImportSaveFailed(url.lastPathComponent))
            }
            completion?()
        }
    }
    
    static func handlePSPGameSave(url: URL, completion: (()->Void)?) {
        if let archive = try? Archive(url: url, accessMode: .read, pathEncoding: nil) {
            var isSaveExist = false
            for entry in archive {
                if entry.type == .file {
                    let realPath = entry.path.components(separatedBy: "/")[1...].reduce("") { $0 + "/" + $1 }
                    let savePath = R.Path.PSPSave.appendingPathComponent(realPath)
                    if FileManager.default.fileExists(atPath: savePath) {
                        isSaveExist = true
                        break
                    }
                }
            }
            
            func extractSaveFiles(archive: ZIPFoundation.Archive) {
                for entry in archive {
                    if entry.type == .file {
                        let realPath = entry.path.components(separatedBy: "/")[1...].reduce("") { $0 + "/" + $1 }
                        let savePath = R.Path.PSPSave.appendingPathComponent(realPath)
                        if FileManager.default.fileExists(atPath: savePath) {
                            try? FileManager.default.removeItem(atPath: savePath)
                        }
                        let _ = try? archive.extract(entry, to: URL(fileURLWithPath: savePath))
                    }
                }
            }
            
            if isSaveExist {
                //询问是否覆盖
                DispatchQueue.main.async {
                    UIView.hideLoading()
                    UIView.makeAlert(title: R.string.localizable.gameSaveAlreadyExistTitle(),
                                     detail: R.string.localizable.filesImporterErrorSaveAlreadyExist(url.lastPathComponent),
                                     confirmTitle: R.string.localizable.confirmTitle(),
                                     enableForceHide: false,
                                     confirmAction: {
                        if let newArchive = try? Archive(url: url, accessMode: .read, pathEncoding: nil) {
                            extractSaveFiles(archive: newArchive)
                            UIView.makeToast(message: R.string.localizable.importGameSaveSuccessTitle(), identifier: "importGameSaveSuccessTitle")
                        } else {
                            UIView.makeToast(message: R.string.localizable.threeDSImportSaveFailed(url.lastPathComponent))
                        }
                    }, hideAction: { _ in
                        completion?()
                    })
                }
            } else {
                //直接解压
                extractSaveFiles(archive: archive)
                DispatchQueue.main.async {
                    UIView.makeToast(message: R.string.localizable.importGameSaveSuccessTitle(), identifier: "importGameSaveSuccessTitle")
                }
                completion?()
            }
        } else {
            DispatchQueue.main.async {
                UIView.makeToast(message: R.string.localizable.threeDSImportSaveFailed(url.lastPathComponent))
            }
            completion?()
        }
    }
    
    static func handlePSPPBPGame(url: URL) -> URL? {
        guard url.pathExtension.lowercased() == "zip" else { return url }
        if let archive = try? Archive(url: url, accessMode: .read, pathEncoding: nil) {
            var isPSPPSPGame = false
            for entry in archive {
                if entry.path.lastPathComponent.uppercased() == "EBOOT.PBP" {
                    isPSPPSPGame = true
                    break
                }
            }
            
            if isPSPPSPGame {
                if let game = LibretroCore.installPSPGame(withZipPath: url.path, destDir: R.Path.PSPGame) {
                    setPSPImportGameInfo(game, for: game.gamePath)
                    return URL(fileURLWithPath: game.gamePath)
                }
            }

        }
        return nil
    }
    
    static func isPSPPBPGame(url: URL) -> Bool {
        return url.path.contains("PPSSPP/PSP/GAME")
    }
    
    static func handleM3uFiles(urls: [URL], multiFileItems: [MultiFileRom]) -> (result: [URL], errors: [ImportError], m3uItems: [MultiFileRom], multiFileItems: [MultiFileRom]) {
        var resultUrls = [URL]()
        var resultM3uItems = [MultiFileRom]()
        var resultErrors = [ImportError]()
        
        var excludeUrls = [URL]()
        var excludeMultiFiles = [MultiFileRom]()
        for url in urls {
            if url.pathExtension.lowercased() == "m3u" {
                if let content = try? String(contentsOf: url) {
                    var isBadM3u = false
                    var missFileName = ""
                    var m3uFiles = [URL]()
                    let fileNames = content.components(separatedBy: .newlines).filter({ !$0.isEmpty })
                    guard fileNames.count > 0 else {
                        resultErrors.append(.badCopy(fileName: url.lastPathComponent))
                        continue
                    }
                    for fileName in fileNames {
                        // Read each playlist entry and require the referenced file to be in this import batch.
                        if !fileName.isEmpty {
                            if let fileUrl = urls.first(where: { $0.lastPathComponent == fileName}) {
                                let playlistExt = fileUrl.pathExtension.lowercased()
                                if playlistExt == "cue" || playlistExt == "gdi" {
                                    // Attach cue/gdi companion tracks so they are not imported as separate games.
                                    if let companion = multiFileItems.first(where: { $0.url.lastPathComponent == fileName }) {
                                        excludeMultiFiles.append(companion)
                                        excludeUrls.append(companion.url)
                                        m3uFiles.append(companion.url)
                                        m3uFiles.append(contentsOf: companion.files)
                                    } else {
                                        isBadM3u = true
                                        missFileName = fileName
                                    }
                                } else {
                                    excludeUrls.append(fileUrl)
                                    m3uFiles.append(fileUrl)
                                }

                            } else {
                                isBadM3u = true
                                missFileName = fileName
                                break
                            }
                        }
                    }
                    if isBadM3u {
                        excludeUrls.append(url)
                        for fileName in fileNames {
                            if fileName.pathExtension.lowercased() == "cue" || fileName.pathExtension.lowercased() == "gdi" {
                                excludeMultiFiles.append(contentsOf: multiFileItems.filter({ $0.url.lastPathComponent == fileName }))
                            } else {
                                excludeUrls.append(contentsOf: urls.filter({ $0.lastPathComponent == fileName }))
                            }
                        }
                        resultErrors.append(.missingFile(errorFileName: url.lastPathComponent, missingFileName: missFileName))
                    } else {
                        resultUrls.append(url)
                        resultM3uItems.append(MultiFileRom(url: url, files: m3uFiles))
                    }
                } else {
                    resultErrors.append(.badFile(fileName: url.lastPathComponent))
                }
            } else {
                resultUrls.append(url)
            }
        }
        
        resultUrls.removeAll(where: { excludeUrls.contains([$0]) })
        
        let resultCueItems = multiFileItems.filter { originCue in
            if excludeMultiFiles.contains(where: { $0.url == originCue.url }) {
                return false
            }
            return true
        }
        
        return (resultUrls, resultErrors, resultM3uItems, resultCueItems)
    }
    
    fileprivate static func extractCueFilenames(from cueContent: String) -> [String] {
        let pattern = #"FILE\s+(?:"([^"]+)"|'([^']+)'|(\S+))"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsString = cueContent as NSString
        let matches = regex.matches(in: cueContent, options: [], range: NSRange(location: 0, length: nsString.length))
        return matches.compactMap { match in
            for group in 1...3 {
                let range = match.range(at: group)
                if range.location != NSNotFound {
                    return nsString.substring(with: range)
                }
            }
            return nil
        }
    }
    
    fileprivate static func extractGdiFilenames(from content: String) -> [String] {
        var filenames: [String] = []
        
        // 使用 .newlines 字符集来处理不同系统的换行符（\n, \r\n, \r）
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // GDI 文件格式：
        // 第一行：轨道总数
        // 后续行：轨道编号 LBA 类型 扇区大小 文件名 偏移量
        // 例如：1 0 4 2352 track01.bin 0
        
        guard lines.count > 1 else {
            return filenames
        }
        
        // 跳过第一行（文件总数）
        for line in lines.dropFirst() {
            // 检查行是否为空或者是注释
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }
            
            if let quoted = extractQuotedFilename(from: line) {
                filenames.append(quoted)
                continue
            }
            
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            
            // GDI 标准格式应该有 6 个字段
            // 如果少于 5 个字段，说明格式可能有问题
            if components.count >= 5 {
                // 文件名在倒数第二列（第5列，索引为4）
                let filename = String(components[components.count - 2])
                
                if !filename.isEmpty {
                    filenames.append(filename)
                }
            }
        }
        
        return filenames
    }
    
    fileprivate static func extractQuotedFilename(from line: String) -> String? {
        let pattern = #""([^"]+)"|'([^']+)'"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsString = line as NSString
        guard let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }
        for group in 1...2 {
            let range = match.range(at: group)
            if range.location != NSNotFound {
                let name = nsString.substring(with: range)
                return name.isEmpty ? nil : name
            }
        }
        return nil
    }
    
    static func handleMultiFiles(urls: [URL]) -> (results: [URL], errors: [ImportError], cueItems: [MultiFileRom]) {
        var results = [URL]()
        var excludes = [URL]()
        var errors = [ImportError]()
        var cueItems = [MultiFileRom]()
        for url in urls {
            if url.pathExtension.lowercased() == "cue" || url.pathExtension.lowercased() == "gdi" {
                if let content = try? String(contentsOf: url) {
                    let isCue = url.pathExtension.lowercased() == "cue"
                    var isBadFile = false
                    var missFileName = ""
                    var multiFiles = [URL]()
                    let fileNames = isCue ? extractCueFilenames(from: content) : extractGdiFilenames(from: content)
                    guard fileNames.count > 0 else {
                        errors.append(.badMultiFile(fileName: url.lastPathComponent))
                        continue
                    }
                    for fileName in fileNames {
                        //读取每一个文件
                        if !fileName.isEmpty {
                            //查询这个文件是否存在
                            if let fileUrl = urls.first(where: { $0.lastPathComponent == fileName}) {
                                //文件存在 则将这个文件排除，不再需要导入
                                excludes.append(fileUrl)
                                multiFiles.append(fileUrl)
                            } else {
                                //文件不存在 说明这个多文件格式不合法，文件有缺失 则不导入这个文件，并且将其他文件也一并排除
                                isBadFile = true
                                missFileName = fileName
                                break
                            }
                        }
                    }
                    if isBadFile {
                        //排除错误文件
                        excludes.append(url)
                        for fileName in fileNames {
                            excludes.append(contentsOf: urls.filter({ $0.lastPathComponent == fileName }))
                        }
                        errors.append(.missingFile(errorFileName: url.lastPathComponent, missingFileName: missFileName))
                    } else {
                        //cue文件合法
                        results.append(url)
                        cueItems.append(MultiFileRom(url: url, files: multiFiles))
                    }
                } else {
                    //无法读取cue文件
                    errors.append(.badMultiFile(fileName: url.lastPathComponent))
                }
            } else {
                results.append(url)
            }
        }
        
        //排除files
        results.removeAll(where: { excludes.contains([$0]) })
        
        return (results, errors, cueItems)
    }
    
    private static func isNGage20PackageURL(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "n-gage"
    }
    
    private static func nGage20StagedPackages() -> [URL] {
        let dir = URL(fileURLWithPath: R.Path.EKA2L1DriveENGage)
        guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return items.filter { $0.pathExtension.lowercased() == "n-gage" }
    }
    
    /// N-Gage 2.0 packages are staged for the in-OS installer; no Realm row.
    private static func importNGage20Packages(_ urls: [URL], completion: @escaping () -> Void) {
        var remaining = urls
        func next() {
            guard let url = remaining.first else {
                completion()
                return
            }
            remaining.removeFirst()
            importOneNGage20Package(url, completion: next)
        }
        next()
    }
    
    private static func importOneNGage20Package(_ url: URL, completion: @escaping () -> Void) {
        let stageAndNotify = {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try stageNGage20Package(url)
                    DispatchQueue.main.async {
                        UIView.makeAlert(title: R.string.localizable.nGage2Install(),
                                         detail: R.string.localizable.nGagePackageReady(),
                                         cancelTitle: R.string.localizable.gotIt(),
                                         enableForceHide: false,
                                         cancelAction: completion)
                    }
                } catch {
                    DispatchQueue.main.async {
                        UIView.makeToast(message: R.string.localizable.importErrorTitle())
                        completion()
                    }
                }
            }
        }
        if nGage20StagedPackages().isEmpty {
            stageAndNotify()
            return
        }
        UIView.makeAlert(title: R.string.localizable.nGage2Install(),
                         detail: R.string.localizable.nGagePendingInstallOverwrite(),
                         confirmTitle: R.string.localizable.confirmTitle(),
                         enableForceHide: false,
                         cancelAction: completion,
                         confirmAction: stageAndNotify)
    }
    
    private static func stageNGage20Package(_ url: URL) throws {
        let dir = URL(fileURLWithPath: R.Path.EKA2L1DriveENGage)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for old in nGage20StagedPackages() {
            try? FileManager.safeRemoveItem(at: old)
        }
        let dest = dir.appendingPathComponent(url.lastPathComponent)
        try FileManager.safeCopyItem(at: url, to: dest, shouldReplace: true)
    }
    
    private static func isSymbianPackageExtension(_ ext: String) -> Bool {
        ext == "sis" || ext == "sisx"
    }
    
    private static func isSymbianImportURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if isSymbianPackageExtension(ext) {
            return true
        }
        guard ["zip", "7z", "rar"].contains(ext) else { return false }
        if MAMEKit.isSupportTitle(fileName: url.lastPathComponent.deletingPathExtension) {
            return false
        }
        return isNGage10Archive(url)
    }
    
    private static func isNGage10Archive(_ url: URL) -> Bool {
        nGageDumpInfo(from: archiveEntryPaths(url)) != nil
    }
    
    private struct NGageDumpInfo {
        /// Path from archive extract root to the folder that contains `system/apps`. Empty if that folder is the archive root.
        let dumpRootRelative: String
        let gameFolder: String
    }
    
    /// N-Gage 1.0 card dumps register as `system/apps/<GameName>/<GameName>.aif` (case-insensitive). An extra wrapper folder is allowed.
    private static func nGageDumpInfo(from entries: [String]) -> NGageDumpInfo? {
        for entry in entries {
            let parts = entry.replacingOccurrences(of: "\\", with: "/")
                .split(separator: "/")
                .map(String.init)
                .filter { !$0.isEmpty && $0 != "." }
            guard let systemIdx = parts.firstIndex(where: { $0.lowercased() == "system" }) else { continue }
            let after = Array(parts[(systemIdx + 1)...])
            guard after.count >= 3, after[0].lowercased() == "apps" else { continue }
            let folder = after[1]
            let file = after[2]
            guard file.lowercased() == folder.lowercased() + ".aif" else { continue }
            let prefix = parts[..<systemIdx].joined(separator: "/")
            return NGageDumpInfo(dumpRootRelative: prefix, gameFolder: folder)
        }
        return nil
    }
    
    private static func archiveEntryPaths(_ url: URL) -> [String] {
        let ext = url.pathExtension.lowercased()
        if ext == "zip" {
            guard let archive = try? ZIPFoundation.Archive(url: url, accessMode: .read, pathEncoding: nil) else { return [] }
            return archive.compactMap { $0.type == .file ? $0.path : nil }
        }
        if ext == "7z" {
            do {
                let decoder = try Decoder(stream: InStream(path: Path(url.path)), fileType: .sevenZ)
                _ = try decoder.open()
                let count = try decoder.count()
                var paths: [String] = []
                paths.reserveCapacity(Int(count))
                for index in 0..<count {
                    let item = try decoder.item(at: index)
                    if item.isDir { continue }
                    paths.append(try item.path().description)
                }
                return paths
            } catch {
                return []
            }
        }
        if ext == "rar" {
            do {
                let archive = try Unrar.Archive(fileURL: url)
                return try archive.entries().compactMap { $0.directory ? nil : $0.fileName }
            } catch {
                return []
            }
        }
        return []
    }
    
    private static func extractArchive(_ url: URL, to dest: URL) -> Bool {
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        let ext = url.pathExtension.lowercased()
        if ext == "zip" {
            return SSZipArchive.unzipFile(atPath: url.path, toDestination: dest.path)
        }
        if ext == "7z" {
            do {
                let decoder = try Decoder(stream: InStream(path: Path(url.path)), fileType: .sevenZ)
                _ = try decoder.open()
                return try decoder.extract(to: Path(dest.path), itemsFullPath: true)
            } catch {
                Log.debug("Failed to extract N-Gage 7z: \(error)")
                return false
            }
        }
        if ext == "rar" {
            do {
                let archive = try Unrar.Archive(fileURL: url)
                for entry in try archive.entries() {
                    if entry.directory { continue }
                    let relative = entry.fileName.replacingOccurrences(of: "\\", with: "/")
                    let fileURL = dest.appendingPathComponent(relative)
                    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let data = try archive.extract(entry)
                    try data.write(to: fileURL)
                }
                return true
            } catch {
                Log.debug("Failed to extract N-Gage rar: \(error)")
                return false
            }
        }
        return false
    }
    
    /// Unique E: prefixes `system/<dir>/<name>` (e.g. `system/apps/6rbc`, `system/libs/foo.dll`).
    private static func collectNGageInstalledFiles(dumpRoot: URL) -> [String] {
        var prefixes = Set<String>()
        let root = dumpRoot.resolvingSymlinksInPath()
        if let enumerator = FileManager.default.enumerator(at: root,
                                                           includingPropertiesForKeys: [.isRegularFileKey],
                                                           options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let isFile = (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
                guard isFile else { continue }
                if let relative = nGageEDriveRelativePath(of: fileURL, dumpRoot: root) {
                    prefixes.insert(relative)
                }
            }
        }
        return prefixes.sorted()
    }
    
    /// E: relative prefix `system/<first>/<second>`. Drops extract-root / `/private/var` prefixes.
    private static func nGageEDriveRelativePath(of fileURL: URL, dumpRoot: URL) -> String? {
        let rootPath = dumpRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let filePath = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
        var relative = filePath
        if filePath.hasPrefix(rootPath) {
            relative = String(filePath.dropFirst(rootPath.count))
        }
        return nGageEDriveRelativePath(relative)
    }
    
    private static func nGageEDriveRelativePath(_ path: String) -> String? {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        guard let range = normalized.range(of: "system/") else { return nil }
        let parts = String(normalized[range.lowerBound...]).split(separator: "/").map(String.init)
        guard parts.count >= 3, parts[0] == "system" else { return nil }
        return "\(parts[0])/\(parts[1])/\(parts[2])"
    }
    
    private static func installSymbianGameSync(_ path: String) -> (LibretroSymbianGameInstallResult, LibretroSymbianGame?) {
        let lock = DispatchSemaphore(value: 0)
        var mapped = LibretroSymbianGameInstallResult.unknown
        var installed: LibretroSymbianGame?
        LibretroCore.installSymbianGame(path) { result, game in
            mapped = result
            installed = game
            lock.signal()
        }
        lock.wait()
        return (mapped, installed)
    }
    
    private static func importSymbianGame(url: URL, completion: ((_ gameId: String?, _ gameName: String?, _ error: ImportError?)->Void)?) {
        let originalName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()
        var installPath = url.path
        var ngageFiles: [String] = []
        var tempRoot: URL?
        var isNGageArchive = false
        
        if ["zip", "7z", "rar"].contains(ext) {
            isNGageArchive = true
            let entries = archiveEntryPaths(url)
            guard let info = nGageDumpInfo(from: entries) else {
                completion?(nil, nil, .badFile(fileName: originalName))
                return
            }
            let temp = URL(fileURLWithPath: R.Path.Temp.appendingPathComponent("NGageImport-\(UUID().uuidString)"))
            tempRoot = temp
            guard extractArchive(url, to: temp) else {
                try? FileManager.default.removeItem(at: temp)
                completion?(nil, nil, .badFile(fileName: originalName))
                return
            }
            let dumpRoot = info.dumpRootRelative.isEmpty ? temp : temp.appendingPathComponent(info.dumpRootRelative)
            guard FileManager.default.fileExists(atPath: dumpRoot.path) else {
                try? FileManager.default.removeItem(at: temp)
                completion?(nil, nil, .badFile(fileName: originalName))
                return
            }
            ngageFiles = collectNGageInstalledFiles(dumpRoot: dumpRoot)
            installPath = dumpRoot.path
        }
        defer {
            if let tempRoot {
                try? FileManager.default.removeItem(at: tempRoot)
            }
        }
        
        let (result, installed) = installSymbianGameSync(installPath)
        guard result == .OK, let installed else {
            Log.debug("Symbian game install failed result:\(result.rawValue) \(originalName)")
            if result == .alreadyExist {
                completion?(nil, nil, .fileExist(fileName: originalName))
            } else {
                completion?(nil, nil, .badFile(fileName: originalName))
            }
            return
        }
        
        let uidString = installed.uidString
        guard tryBeginProcessing(uidString) else {
            completion?(nil, nil, .fileExist(fileName: originalName))
            return
        }
        
        let realm = Database.realm
        if let game = realm.object(ofType: Game.self, forPrimaryKey: uidString) {
            if game.isDeleted {
                do {
                    try realm.write { game.isDeleted = false }
                    if let device = installed.compatibleDevice {
                        game.updateSymbianGame(device: device,
                                               changeSkin: SymbianOS.getOS(by: device).rawValue > SymbianOS.S60v3.rawValue)
                    }
                    completion?(game.id, game.displayName, nil)
                } catch {
                    completion?(nil, nil, .writeDatabase(fileName: originalName))
                }
            } else {
                completion?(nil, nil, .fileExist(fileName: originalName))
            }
            return
        }
        
        let game = Game()
        game.id = uidString
        let caption = [installed.longCaption, installed.shortCaption]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
        game.name = caption ?? originalName
        game.fileExtension = isNGageArchive ? "nge" : ext
        game.importDate = Date()
        game.gameType = .symbian
        
        if let icon = installed.icon, let iconData = icon.jpegData(compressionQuality: 0.7) {
            game.gameCover = CreamAsset.create(objectID: game.id, propName: "gameCover", data: iconData)
        }
        
        var extras: [String: Any] = [:]
        if !ngageFiles.isEmpty {
            extras[ExtraKey.ngageFiles.rawValue] = ngageFiles
        }
        let packages: [[String: Any]] = installed.packages.map { package in
            ["uid": package.uid, "index": package.index]
        }
        if !packages.isEmpty {
            extras[ExtraKey.symbianPackages.rawValue] = packages
        } else if ngageFiles.isEmpty {
            extras[ExtraKey.symbianPackages.rawValue] = [["uid": installed.uid, "index": 0]]
        }
        if let device = installed.compatibleDevice {
            extras[ExtraKey.symbianFirmwareCode.rawValue] = device.firmwareCode
            extras[ExtraKey.symbianFirmwareModel.rawValue] = device.model
            extras[ExtraKey.symbianOSVer.rawValue] = SymbianOS.getOS(by: device).rawValue
        }
        if !extras.isEmpty {
            game.extras = extras.jsonData()
        }
        
        do {
            try realm.write { realm.add(game) }
            if let device = installed.compatibleDevice {
                game.updateSymbianGame(device: device,
                                       changeSkin: SymbianOS.getOS(by: device).rawValue > SymbianOS.S60v3.rawValue)
            }
            OnlineCoverManager.shared.addCoverMatch(OnlineCoverManager.CoverMatch(game: game))
            completion?(game.id, game.displayName, nil)
        } catch {
            Log.debug("Failed to insert Symbian game into database:\(error)")
            completion?(nil, nil, .writeDatabase(fileName: originalName))
        }
    }
}

struct MultiFileRom {
    var url: URL
    var files: [URL]
}
