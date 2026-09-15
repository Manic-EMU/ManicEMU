//
//  GameOptionPerform.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/3.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UniformTypeIdentifiers
import IceCream
import Kingfisher
import RealmSwift
import Haptica

extension GameOption {
    func performAction(with games: [Game],
                       performImmediately: Bool = false,
                       accessoryChange: (() -> Void)? = nil,
                       reloadAll: (() -> Void)? = nil) {
        guard let firstGame = games.first else { return }
        
        switch self {
        case .rename:
            GameInfoView.show(readyAction: .rename, game: firstGame)
            
        case .cover:
            GameCoverModifyView.show(game: firstGame)
            
        case .stateList:
            pauseEmulationIfNeed()
            SaveStateListView.show(game: firstGame, hideCompletion: { savestate in
                if let savestate {
                    if firstGame.isLibretroType {
                        PlayViewController.loadState(savestate)
                        UIView.hideAllAlert {
                            resumeEmulationIfNeed()
                        }
                    } else {
                        UIView.hideAllAlert {
                            PlayViewController.loadState(savestate)
                            resumeEmulationIfNeed()
                        }
                    }
                } else {
                    resumeEmulationIfNeed()
                }
            })

        case .skins:
            pauseEmulationIfNeed()
            SkinSettingsView.show(games: games, hideCompletion: {
                resumeEmulationIfNeed()
            })
            
        case .shareRom:
            ShareManager.shareFiles(games: games, shareFileType: .rom)
            
        case .importSave:
            if showSaveTipsIfNeed(games: games) {
                return
            }
            var types = UTType.gamesaveTypes
            if firstGame.gameType == .dos,
                let zip = UTType(filenameExtension: "zip") {
                types += [zip]
            }
            FilesImporter.shared.presentImportController(supportedTypes: types, allowsMultipleSelection: false) { urls in
                if var url = urls.first {
                    if firstGame.gameType == ._3ds || firstGame.gameType == .psp {
                        FilesImporter.importFiles(urls: [url])
                    } else {
                        //try to fix j2meJS saves
                        if firstGame.gameType == .j2me,
                           firstGame.defaultCore == 0,
                           let fixedUrl = Database.fixJ2meJSSave(fileName: firstGame.fileName, url: url) {
                            url = fixedUrl
                        }
                        
                        if firstGame.isSaveExtsts {
                            UIView.makeAlert(title: R.string.localizable.gameSaveAlreadyExistTitle(),
                                             detail: ImportError.saveAlreadyExist(gameSaveUrl: url, game: firstGame).localizedDescription,
                                             confirmTitle: R.string.localizable.confirmTitle(),
                                             enableForceHide: false,
                                             confirmAction: {
                                try? FileManager.safeCopyItem(at: url, to: firstGame.gameSaveUrl, shouldReplace: true)
                                UIView.makeToast(message: R.string.localizable.importGameSaveSuccessTitle())
                                firstGame.processNDSGameSave()
                            })
                        } else {
                            try? FileManager.safeCopyItem(at: url, to: firstGame.gameSaveUrl, shouldReplace: true)
                            UIView.makeToast(message: R.string.localizable.importGameSaveSuccessTitle())
                            firstGame.processNDSGameSave()
                        }
                    }
                }
            }
            
        case .shareSave:
            if showSaveTipsIfNeed(games: games) {
                return
            }
            ShareManager.shareFiles(games: games, shareFileType: .save)
            
        case .delete:
            UIView.makeAlert(title: R.string.localizable.gamesDelete(),
                             detail: R.string.localizable.deleteGameAlertDetail(),
                             confirmTitle: R.string.localizable.confirmDelte(),
                             confirmAction: {
                let sisUninstallJobs: [(uid: Int, index: Int)] = games.flatMap { game -> [(uid: Int, index: Int)] in
                    guard game.gameType == .symbian, game.ngageRelativeFiles.isEmpty else { return [] }
                    return game.symbianInstallPackages
                }
                let performDelete = {
                    Game.change { realm in
                        for game in games {
                            if game.gameType == .symbian {
                                // SIS packages were already uninstalled off the main thread.
                                if !game.ngageRelativeFiles.isEmpty {
                                    game.uninstallFromSymbianStorage()
                                }
                            } else if game.isRomExtsts {
                                if game.gameType == ._3ds, game.fileExtension.lowercased() == "app", let range = game.romUrl.path.range(of: "/content/") {
                                    let gamePath = String(game.romUrl.path[...range.lowerBound])
                                    try FileManager.safeRemoveItem(at: URL(fileURLWithPath: gamePath))
                                    SyncManager.delete(localFilePath: gamePath)
                                    // Remove DLC and update titles.
                                    let updatePath = gamePath.replacingOccurrences(of: "/00040000/", with: "/0004000e/")
                                    try FileManager.safeRemoveItem(at: URL(fileURLWithPath: updatePath))
                                    SyncManager.deletePath(localPath: updatePath)
                                    let dlcPath = gamePath.replacingOccurrences(of: "/00040000/", with: "/0004008c/")
                                    try FileManager.safeRemoveItem(at: URL(fileURLWithPath: dlcPath))
                                    SyncManager.deletePath(localPath: dlcPath)
                                } else if game.isMultiFileGame {
                                    let romParentPath = game.romUrl.path.deletingLastPathComponent
                                    try FileManager.safeRemoveItem(at: URL(fileURLWithPath: romParentPath))
                                    SyncManager.deletePath(localPath: romParentPath)
                                } else if game.gameType == .ps1, game.fileExtension.lowercased() == "bin" {
                                    let binUrl = URL(fileURLWithPath: R.Path.Data.appendingPathComponent(game.fileName))
                                    let cueUrl = binUrl.deletingPathExtension().appendingPathExtension("cue")
                                    try FileManager.safeRemoveItem(at: binUrl)
                                    try FileManager.safeRemoveItem(at: cueUrl)
                                    SyncManager.delete(localFilePath: binUrl.path)
                                    SyncManager.delete(localFilePath: cueUrl.path)
                                } else {
                                    try FileManager.safeRemoveItem(at: game.romUrl)
                                    SyncManager.delete(localFilePath: game.romUrl.path)
                                }
                            }
                            
                            if game.gameType == .j2me {
                                game.deleteJ2meSaves()
                            } else if game.gameType == .dos {
                                game.deleteDosFiles()
                            } else {
                                if game.isSaveExtsts {
                                    if game.gameType == .psp, let code = game.gameCodeForPSP {
                                        // PSP saves may span multiple folders.
                                        try? FileManager.default.contentsOfDirectory(atPath: R.Path.PSPSave).filter({ $0.hasPrefix(code)}).forEach { savePath in
                                            let deletePath = R.Path.PSPSave.appendingPathComponent(savePath)
                                            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: deletePath))
                                            SyncManager.deletePath(localPath: deletePath)
                                        }
                                    } else {
                                        try FileManager.safeRemoveItem(at: game.gameSaveUrl)
                                        SyncManager.delete(localFilePath: game.gameSaveUrl.path)
                                    }
                                }
                            }
                            
                            if let coverData = game.gameCover {
                                coverData.deleteAndClean(realm: realm)
                            }
                            CreamAsset.batchDeleteAndClean(assets: game.gameSaveStates.compactMap({ $0.stateCover }), realm: realm)
                            CreamAsset.batchDeleteAndClean(assets: game.gameSaveStates.compactMap({ $0.stateData }), realm: realm)
                            if Settings.defalut.iCloudSyncEnable {
                                // Soft-delete while iCloud sync is on.
                                game.gameCheats.forEach { $0.isDeleted = true }
                                game.gameSaveStates.forEach { $0.isDeleted = true }
                                game.isDeleted = true
                            } else {
                                // Local hard delete.
                                realm.delete(game.gameCheats)
                                realm.delete(game.gameSaveStates)
                                realm.delete(game)
                            }
                        }
                    }
                }
                if sisUninstallJobs.isEmpty {
                    performDelete()
                    return
                }
                UIView.makeLoading()
                DispatchQueue.global().async {
                    for job in sisUninstallJobs {
                        LibretroCore.uninstallSymbianGame(withUid: job.uid, index: job.index)
                    }
                    DispatchQueue.main.async {
                        performDelete()
                        UIView.hideLoading()
                    }
                }
            })
            
        case .platformChange:
            PlatformSelectionView.show(games: games) {
                accessoryChange?()
            }
            
        case .switchCore:
            CoreSelectionView.show(games: games) {
                reloadAll?()
            }
            
        case .changeCategory:
            CategorySelectionView.show(games: games, completion: { success in
                if success {
                    NotificationCenter.default.post(name: R.NotificationName.GameCategoryChange, object: nil)
                    accessoryChange?()
                }
            })
            
        case .genHomeMenu:
            let realm = Database.realm
            if realm.object(ofType: Game.self, forPrimaryKey: Game.DOSHomeMenuPrimaryKey) == nil {
                let game = Game()
                game.gameType = .dos
                game.id = Game.DOSHomeMenuPrimaryKey
                game.name = Game.DOSHomeMenuPrimaryKey
                try? realm.write {
                    realm.add(game)
                }
            }
            
        case .copyLink:
            if firstGame.gameType == .ns {
                UIPasteboard.general.string = R.URLs.MeloNXGameLaunch(gameId: firstGame.id).absoluteString
            } else if firstGame.gameType == .xbox360 {
                UIPasteboard.general.string = R.URLs.XeniOSGameLaunch(gameId: firstGame.id).absoluteString
            } else if firstGame.gameType == .xbox {
                UIPasteboard.general.string = R.URLs.DukeXGameLaunch(gameId: firstGame.id).absoluteString
            } else if firstGame.gameType == .ps2 {
                UIPasteboard.general.string = R.URLs.ARMSX2GameLaunch(gameId: firstGame.id).absoluteString
            } else {
                UIPasteboard.general.string = "manicemu://launch/\(firstGame.id)"
            }
            if firstGame.gameCover != nil || firstGame.onlineCoverUrl != nil {
                //弹出提示询问用户是否需要进行封面的保存
                UIView.makeAlert(detail: R.string.localizable.askIfNeedToSaveCover(), confirmTitle: R.string.localizable.saveTitle(), confirmAction: {
                    //保存封面到相册
                    if let imageFilePath = firstGame.gameCover?.filePath, let imageData = try? Data(contentsOf: imageFilePath) {
                        PhotoSaver.save(datas: [imageData])
                    } else if let onlineCoverUrl = firstGame.onlineCoverUrl, let url = URL(string: onlineCoverUrl) {
                        KingfisherManager.shared.retrieveImage(with: url) { result in
                            switch result {
                            case .success(let imageResult):
                                Task { @MainActor in
                                    PhotoSaver.save(image: imageResult.image)
                                }
                            case .failure(_):
                                Task { @MainActor in
                                    UIView.makeToast(message: R.string.localizable.onlineCoverFetchFailed())
                                }
                            }
                        }
                        
                    } else {
                        UIView.makeToast(message: R.string.localizable.onlineCoverFetchFailed())
                    }
                })
            }
            
        case .retroAchievements:
            if !firstGame.supportRetroAchievements {
                let showName = firstGame.gameType == .arcade ? EmulationCore.MAME.name : firstGame.gameType.localizedShortName
                UIView.makeToast(message: R.string.localizable.achievementsNotSupport(showName))
                return
            }
            pauseEmulationIfNeed()
            RetroAchievementsLaunchView.show(loginedAction: .jumpList(game: firstGame, didClose: {
                resumeEmulationIfNeed()
            }))
            
        case .cheatCode:
            if firstGame.gameType == .arcade {
                if firstGame.defaultCore == 0 {
                    UIView.makeAlert(detail: R.string.localizable.mameCheatCodeDesc(), cancelTitle: R.string.localizable.confirmTitle())
                } else if firstGame.defaultCore == 1, !PlayViewController.isGaming {
                    UIView.makeToast(message: R.string.localizable.fbNeoCheatCodeDesc())
                }
                return
            }

            if firstGame.isDolphinCore {
                if firstGame.gameIDForDolphin == nil {
                    firstGame.ensureDolphinGameID()
                }
                if firstGame.gameIDForDolphin == nil {
                    UIView.makeToast(message: R.string.localizable.dolphinGameIDMissing())
                    return
                }
            }
            
            pauseEmulationIfNeed()
            CheatCodeListView.show(game: firstGame, hideCompletion: {
                resumeEmulationIfNeed()
            })
            
        case .manual:
            pauseEmulationIfNeed()
            if firstGame.isManualsExists {
                GameplayManualsView.show(game: firstGame, hideCompletion: {
                    resumeEmulationIfNeed()
                })
            } else {
                UIView.makeAlert(title: R.string.localizable.gameplayManualsNoExists(),
                                 detail: R.string.localizable.gameplayManualsDesc(),
                                 confirmTitle: R.string.localizable.gameListBackgroundUpload(),
                                 confirmAction: {
                    FilesImporter.shared.presentImportController(supportedTypes: [UTType.pdf],
                                                                 allowsMultipleSelection: false,
                                                                 manualHandle: { urls in
                        if let pdfUrl = urls.first {
                            do {
                                let pdfName = pdfUrl.lastPathComponent
                                try FileManager.safeCopyItem(at: pdfUrl, to: URL(fileURLWithPath: R.Path.GameplayManuals.appendingPathComponent(pdfName)), shouldReplace: true)
                                firstGame.updateExtra(key: ExtraKey.manualFileName.rawValue, value: pdfName)
                                GameplayManualsView.show(game: firstGame, hideCompletion: {
                                    resumeEmulationIfNeed()
                                })
                            } catch {
                                resumeEmulationIfNeed()
                            }
                        } else {
                            resumeEmulationIfNeed()
                        }
                    })
                }, hideAction: { type in
                    if type != .confirm {
                        resumeEmulationIfNeed()
                    }
                })
            }
            
        case .language:
            let languages = firstGame.supportedLanguages
            guard languages.count > 0 else { return }
            var selectedIndex: Int? = nil
            if let accessory = accessory(for: games).chevronValue,
               let _ = accessory.string  {
                selectedIndex = firstGame.region
            }
            pauseEmulationIfNeed()
            OptionsSheetView.show(icon: icon,
                                  title: title,
                                  options: languages,
                                  selectedIndex: selectedIndex,
                                  groupTogether: true,
                                  completion: { index in
                if let index {
                    for game in games {
                        Game.change { _ in
                            game.region = index
                        }
                    }
                    accessoryChange?()
                }
                resumeEmulationIfNeed()
            })
            
            
        case .jit:
            performSwitchAction(with: games,
                                accessoryChange: accessoryChange,
                                reloadAll: reloadAll)
            
        case .citraAdvanceToggle:
            Settings.change { realm in
                Settings.defalut.threeDSAdvancedSettingMode.toggle()
            }
            reloadAll?()
            
        case .citraMode:
            pauseEmulationIfNeed()
            OptionsSheetView.show(icon: icon,
                                  title: title,
                                  options: [
                                    R.string.localizable.threeDSModeCompatibility(),
                                    R.string.localizable.threeDSModePerformance(),
                                    R.string.localizable.threeDSModeQuality()
                                  ],
                                  selectedIndex: Settings.defalut.threeDSMode.rawValue,
                                  completion: { index in
                if let index, let mode = ThreeDSMode(rawValue: index) {
                    Settings.change { realm in
                        Settings.defalut.threeDSMode = mode
                    }
                    accessoryChange?()
                }
                resumeEmulationIfNeed()
            })
            
        case .citraShader:
            performSwitchAction(with: games, accessoryChange: accessoryChange)
            
        case .citraRightEyeRender:
            performSwitchAction(with: games, accessoryChange: accessoryChange)
            
        case .azaharEmulationAccuracy:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .pspJitType:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .pspRenderer:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .pspTexture:
            performSwitchAction(with: games, accessoryChange: accessoryChange)
            
        case .ps1Bios:
            let ps1Bios = firstGame.ps1ImportedBios
            let extraKey = ExtraKey.biosName.rawValue
            var selectedIndex: Int? = nil
            let firstGameValue = (firstGame.getExtraString(key: extraKey) ?? "OpenBIOS")
            if games.allSatisfy({
                ($0.getExtraString(key: extraKey) ?? "OpenBIOS") == firstGameValue
            }) {
                selectedIndex = (ps1Bios.map({ $0.fileName }) + ["OpenBIOS"]).firstIndex(where: { $0 == firstGameValue })
            }
            
            var cells = ps1Bios.map({
                [ASListPage.Cell.iconTitleDetailRadioCell(title: $0.fileName.deletingPathExtension,
                                                          detail: $0.desc,
                                                          isSelected: selectedIndex == nil ? false : ($0.fileName == firstGameValue))]
            })
            cells.append([ASListPage.Cell.iconTitleDetailRadioCell(title: "OpenBIOS", isSelected: selectedIndex == nil ? false : ("OpenBIOS" == firstGameValue))])
            
            let sheetData = ASSheet(style: .simpleList(icon: icon,
                                                       title: title,
                                                       options: cells))
            
            ASSheetView.show(sheetData, action: { action, _ in
                if let index = action.listPageValue?.normalItemValue?.indexPath.section {
                    let biosName: String
                    if index < ps1Bios.count {
                        biosName = ps1Bios[index].fileName
                    } else {
                        biosName = "OpenBIOS"
                    }
                    for game in games {
                        game.updateExtra(key: ExtraKey.biosName.rawValue, value: biosName)
                    }
                    accessoryChange?()
                }
                return .dismiss()
            })
            
            
        case .ps1ControllerMode:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .ps1Sbi:
            PSXSBIImportView.show(game: firstGame)
            
        case .ps1Renderer:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .n64TransferPak:
            let options = [
                R.string.localizable.transferPakFromLibrary(),
                R.string.localizable.transferPakFromFiles(),
                R.string.localizable.off()
            ]
            ChevronSheetView.show(icon: icon,
                                  title: title,
                                  detail: R.string.localizable.transferPakDesc(),
                                  stringOptions: options,
                                  completion: { index in
                if let index {
                    if index == 0 {
                        //from library
                        let realm = Database.realm
                        let objects = realm.objects(Game.self).where({ !$0.isDeleted && ($0.gameType == .gbc || $0.gameType == .gb) }).filter({ $0.isSaveExtsts })
                        var games = [Game]()
                        games.append(contentsOf: objects)
                        if games.count > 0 {
                            GamesSelectionView.show(title: "Transfer Pak",
                                                    detail: R.string.localizable.transferPakFromLibraryDesc(),
                                                    showGames: games,
                                                    completion: { selectedGame in
                                if let selectedGame, selectedGame.isRomExtsts, selectedGame.isSaveExtsts {
                                    try? FileManager.safeCopyItem(at: selectedGame.romUrl, to: URL(fileURLWithPath: firstGame.romUrl.path + ".gb"), shouldReplace: true)
                                    try? FileManager.safeCopyItem(at: selectedGame.gameSaveUrl, to: URL(fileURLWithPath: firstGame.romUrl.path + ".sav"), shouldReplace: true)
                                    UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                                }
                            })
                        } else {
                            UIView.makeToast(message: R.string.localizable.transferPakNoGames())
                        }
                        
                    } else if index == 1 {
                        //from files
                        if let gb = UTType(filenameExtension: "gb"), let gbc = UTType(filenameExtension: "gbc"), let sav = UTType(filenameExtension: "sav") {
                            FilesImporter.shared.presentImportController(supportedTypes: [gb, gbc, sav]) { urls in
                                guard urls.count == 2 else {
                                    UIView.makeToast(message: R.string.localizable.transferPakImportError())
                                    return
                                }
                                
                                var romPath = ""
                                var savePath = ""
                                let firstPath = urls.first!.path
                                let firstPathExtension = firstPath.pathExtension.lowercased()
                                if firstPathExtension == "gb" || firstPathExtension == "gbc" {
                                    romPath = firstPath
                                } else if firstPathExtension == "sav" {
                                    savePath = firstPath
                                } else {
                                    UIView.makeToast(message: R.string.localizable.transferPakImportError())
                                    return
                                }
                                
                                let lastPath = urls.last!.path
                                let lastPathExtension = lastPath.pathExtension.lowercased()
                                if romPath.isEmpty {
                                    if lastPathExtension == "gb" || lastPathExtension == "gbc" {
                                        romPath = lastPath
                                    } else {
                                        UIView.makeToast(message: R.string.localizable.transferPakImportError())
                                        return
                                    }
                                } else {
                                    if lastPathExtension == "sav" {
                                        savePath = lastPath
                                    } else {
                                        UIView.makeToast(message: R.string.localizable.transferPakImportError())
                                        return
                                    }
                                }
                                
                                try? FileManager.safeCopyItem(at: URL(fileURLWithPath: romPath), to: URL(fileURLWithPath: firstGame.romUrl.path + ".gb"), shouldReplace: true)
                                try? FileManager.safeCopyItem(at: URL(fileURLWithPath: savePath), to: URL(fileURLWithPath: firstGame.romUrl.path + ".sav"), shouldReplace: true)
                                UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                                
                            }
                        }
                    } else {
                        //turn off
                        try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: firstGame.romUrl.path + ".gb"))
                        try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: firstGame.romUrl.path + ".sav"))
                    }
                    accessoryChange?()
                }
            })
            
            
        case .n64RdpPlugin:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .ndsSystemType:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .ndsGbaSlot:
            let options = [
                R.string.localizable.transferPakFromLibrary(),
                R.string.localizable.transferPakFromFiles(),
                R.string.localizable.off()
            ]
            ChevronSheetView.show(icon: icon,
                                  title: title,
                                  detail: R.string.localizable.gbaSlotDesc(),
                                  stringOptions: options,
                                  completion: { index in
                if let index {
                    if index == 0 {
                        //from library
                        let realm = Database.realm
                        let objects = realm.objects(Game.self).where({ !$0.isDeleted && $0.gameType == .gba })
                        var games = [Game]()
                        games.append(contentsOf: objects)
                        if games.count > 0 {
                            GamesSelectionView.show(title: "GBA Slot",
                                                    detail: R.string.localizable.transferPakFromLibraryDesc(),
                                                    showGames: games,
                                                    completion: { selectedGame in
                                if let selectedGame, selectedGame.isRomExtsts {
                                    try? FileManager.safeCopyItem(at: selectedGame.romUrl, to: URL(fileURLWithPath: firstGame.romUrl.path + ".slot.gba"), shouldReplace: true)
                                    try? FileManager.safeCopyItem(at: selectedGame.gameSaveUrl, to: URL(fileURLWithPath: firstGame.romUrl.path + ".slot.sav"), shouldReplace: true)
                                    UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                                }
                            })
                        } else {
                            UIView.makeToast(message: R.string.localizable.transferPakNoGames())
                        }
                        
                    } else if index == 1 {
                        //from files
                        if let gba = UTType(filenameExtension: "gba"), let sav = UTType(filenameExtension: "sav") {
                            FilesImporter.shared.presentImportController(supportedTypes: [gba, sav]) { urls in
                                guard urls.count == 1 || urls.count == 2 else {
                                    UIView.makeToast(message: R.string.localizable.gbaSlotImportError())
                                    return
                                }
                                
                                var romPath = ""
                                var savePath = ""
                                let firstPath = urls.first!.path
                                let firstPathExtension = firstPath.pathExtension.lowercased()
                                if firstPathExtension == "gba" {
                                    romPath = firstPath
                                } else if firstPathExtension == "sav" {
                                    savePath = firstPath
                                } else {
                                    UIView.makeToast(message: R.string.localizable.gbaSlotImportError())
                                    return
                                }
                                
                                if urls.count == 1, romPath.isEmpty {
                                    UIView.makeToast(message: R.string.localizable.gbaSlotImportError())
                                    return
                                }
                                
                                if urls.count == 2 {
                                    let lastPath = urls.last!.path
                                    let lastPathExtension = lastPath.pathExtension.lowercased()
                                    if romPath.isEmpty {
                                        if lastPathExtension == "gba" {
                                            romPath = lastPath
                                        } else {
                                            UIView.makeToast(message: R.string.localizable.gbaSlotImportError())
                                            return
                                        }
                                    } else {
                                        if lastPathExtension == "sav" {
                                            savePath = lastPath
                                        } else {
                                            UIView.makeToast(message: R.string.localizable.gbaSlotImportError())
                                            return
                                        }
                                    }
                                }
                                try? FileManager.safeCopyItem(at: URL(fileURLWithPath: romPath), to: URL(fileURLWithPath: firstGame.romUrl.path + ".slot.gba"), shouldReplace: true)
                                if !savePath.isEmpty {
                                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: savePath), to: URL(fileURLWithPath: firstGame.romUrl.path + ".slot.sav"), shouldReplace: true)
                                }
                                UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                            }
                        }
                        
                    } else {
                        //turn off
                        try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: firstGame.romUrl.path + ".slot.gba"))
                        try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: firstGame.romUrl.path + ".slot.sav"))
                    }
                    accessoryChange?()
                }
            })
            
        case .ndsMicrophone:
            performSwitchAction(with: games, accessoryChange: accessoryChange)
            
        case .clownMDTvStandard:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .snesVRAM:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .coreSettings:
            pauseEmulationIfNeed()
            if firstGame.isJ2MECore {
                J2MESettingView.show(game: firstGame, hideCompletion: {
                    resumeEmulationIfNeed()
                })
            } else if firstGame.isCitra3DS {
                CitraAdvancedSettingView.show(hideCompletion: {
                    resumeEmulationIfNeed()
                })
            } else {
                LibretroCoreConfigsView.show(games: games, hideCompletion: { changeConfigs in
                    resumeEmulationIfNeed()
                    if changeConfigs.count > 0,
                       PlayViewController.isGaming {
                        LibretroCore.sharedInstance().updateRunningCoreConfigs(changeConfigs, flush: false)
                    }
                })
            }
            
        case .saveState:
            if !PurchaseManager.isMember && firstGame.gameSaveStates.filter({ $0.type == .manualSaveState }).count >= R.Numbers.NonMemberManualSaveGameCount {
                pauseEmulationIfNeed()
                UIView.makeAlert(identifier: R.Strings.PlayPurchaseAlertIdentifier,
                                 detail: R.string.localizable.manualGameSaveCountLimit(),
                                 confirmTitle: R.string.localizable.goToUpgrade(),
                                 confirmAutoHide: false,
                                 confirmAction: {
                    topViewController()?.present(PurchaseViewController(), animated: true)
                }, hideAction: { _ in
                    resumeEmulationIfNeed()
                })
                return
            }
            PlayViewController.saveState()
            hideSheetInGaming()

        case .quickLoadState:
            if let state = firstGame.gameSaveStates.last(where: { $0.type == .manualSaveState }) {
                PlayViewController.loadState(state)
                hideSheetInGaming()
            } else {
                UIView.makeToast(message: R.string.localizable.gameSaveStateQuickLoadFailed())
            }

        case .volume:
            if performImmediately {
                performVolume(game: firstGame)
            } else {
                performSwitchAction(with: games, accessoryChange: accessoryChange)
            }

        case .fastForward:
            if performImmediately {
                performFastForward(games: games, speed: firstGame.speed.next)
            } else {
                performStringAction(with: games, accessoryChange: accessoryChange)
            }
            
        case .shaders:
            if PlayViewController.isGaming {
                PlayViewController.stopShader()
                UIView.makeLoading()
                pauseEmulationIfNeed()
                PlayViewController.getShaderPreviewImage(completion: { image in
                    UIView.hideLoading()
                    ShaderListView.show(initType: .gamePlay,
                                        isGlsl: games.first?.supportGlslShaders ?? false,
                                        games: games,
                                        previewImage: image,
                                        hideCompletion: {
                        PlayViewController.updateShader()
                        resumeEmulationIfNeed()
                        accessoryChange?()
                    })
                })
            } else {
                ShaderListView.show(initType: .normal,
                                    isGlsl: games.first?.supportGlslShaders ?? false,
                                    games: games, hideCompletion: {
                    accessoryChange?()
                })
            }

        case .screenShot:
            PlayViewController.saveSnapShot()
            hideSheetInGaming()
            
        case .haptic:
            if performImmediately {
                performHaptic(games: games, haptic: firstGame.haptic.next)
            } else {
                performStringAction(with: games, accessoryChange: accessoryChange)
            }

        case .airplay:
            pauseEmulationIfNeed()
            ASWebView.show(url: R.URLs.AirPlayUsageGuide) {
                resumeEmulationIfNeed()
            }

        case .controllerSetting:
            pauseEmulationIfNeed()
            ControllersSettingView.show(games: games, hideCompletion: {
                resumeEmulationIfNeed()
            })
            
        case .orientation:
            if performImmediately {
                performOrientation(games: games, orientation: firstGame.orientation.next)
            } else {
                performStringAction(with: games, accessoryChange: accessoryChange)
            }

        case .gameOptionSort:
            pauseEmulationIfNeed()
            GameOptionsSortView.show(hideCompletion: {
                resumeEmulationIfNeed()
            })

        case .swapScreen:
            performSwitchAction(with: games, accessoryChange: accessoryChange)

        case .resolution:
            if performImmediately {
                performResolution(games: games, resolution: firstGame.resolution.next)
            } else {
                performStringAction(with: games, accessoryChange: accessoryChange)
            }

        case .consoleHome:
            PlayViewController.consoleHome()
            hideSheetInGaming()

        case .amiibo:
            PlayViewController.amiibo()

        case .hideControls:
            performSwitchAction(with: games, accessoryChange: accessoryChange)

        case .simBlowing:
            PlayViewController.simBlowing()
            hideSheetInGaming()

        case .palette:
            if firstGame.gameType == .nes || firstGame.gameType == .fds {
                let nesPalettes = firstGame.nesPalettes
                let nestopias = nesPalettes.filter({ $0.type == .nestopia })
                let buildIns = nesPalettes.filter({ $0.type == .buildIn })
                let customs = nesPalettes.filter({ $0.type == .custom })
                var sections = [ASListPage.Section]()
                let selectedName = accessory(for: games).chevronValue?.string
                sections.append(.init(cells: nestopias.map({
                    .iconTitleDetailRadioCell(title: $0.name,
                                              isSelected: selectedName == $0.name)
                })))
                sections.append(.init(cells: buildIns.map({
                    .iconTitleDetailRadioCell(title: $0.name,
                                              isSelected: selectedName == $0.name)
                })))
                if customs.count > 0 {
                    sections.append(.init(cells: customs.map({
                        .iconTitleDetailRadioCell(title: $0.name,
                                                  isSelected: selectedName == $0.name)
                    })))
                }
                sections.append(.init(cells: [.iconTitleChevronCell(icon: .symbolImage(R.image.folder_iconSymbols()),
                                                                        title: R.string.localizable.gameListBackgroundUpload())]))
                pauseEmulationIfNeed()
                var isUploadDismiss = false
                ASSheetView.show(.init(style: .listPage(.init(navigation: .defaultNavigation(title: title, titleIcon: icon),
                                                              sections: sections))),
                                 action: { action, updation in
                    if let indexPath = action.listPageValue?.normalItemValue?.indexPath {
                        if (customs.count == 0 && indexPath.section == 2) || indexPath.section == 3 {
                            //upload
                            isUploadDismiss = true
                            return .dismiss(completion: {
                                FilesImporter.shared.presentImportController(supportedTypes: [UTType(filenameExtension: "pal") ?? UTType.data],
                                                                             allowsMultipleSelection: false,
                                                                             manualHandle: { urls in
                                    if let url = urls.first {
                                        let toPath = R.Path.CustomPalettes.appendingPathComponent(firstGame.gameType.localizedShortName).appendingPathComponent(url.lastPathComponent)
                                        if FileManager.default.fileExists(atPath: toPath) {
                                            UIView.makeToast(message: R.string.localizable.filesImporterErrorFileExist(url.lastPathComponent))
                                            return
                                        }
                                        try? FileManager.safeCopyItem(at: url, to: URL(fileURLWithPath: toPath), shouldReplace: true)
                                        let palette = Game.NESPalette(name: url.lastPathComponent.deletingPathExtension, type: .custom)
                                        firstGame.nesPalettes.append(palette)
                                        GameOption.palette.performAction(with: games, accessoryChange: accessoryChange)
                                    }
                                })
                            })
                        }
                        
                        let palette: Game.NESPalette
                        if indexPath.section == 0 {
                            palette = nestopias[indexPath.row]
                        } else if indexPath.section == 1 {
                            palette = buildIns[indexPath.row]
                        } else {
                            palette = customs[indexPath.row]
                        }
                        if PlayViewController.isGaming {
                            PlayViewController.updateNESPalette(palette)
                        } else {
                            games.forEach({
                                $0.updateExtra(key: ExtraKey.nesPalette.rawValue, value: palette.name)
                            })
                        }
                        accessoryChange?()
                    }
                    resumeEmulationIfNeed()
                    return .dismiss()
                }, dismiss: {
                    if !isUploadDismiss {
                        resumeEmulationIfNeed()
                    }
                })
                
            } else {
                performStringAction(with: games, accessoryChange: accessoryChange)
            }

        case .swapDisk:
            performStringAction(with: games, accessoryChange: accessoryChange)

        case .airPlayScaling:
            performStringAction(with: games, accessoryChange: accessoryChange)

        case .airPlayLayout:
            performStringAction(with: games, accessoryChange: accessoryChange)

        case .triggerPro:
            let triggers = Trigger.supportTriggers(gameType: firstGame.gameType)
            if triggers.count == 0 {
                pauseEmulationIfNeed()
                TriggerProManageView.show(hideCompletion: {
                    accessoryChange?()
                    resumeEmulationIfNeed()
                })
            } else {
                var options = [[ASListPage.Cell]]()
                var usingTriggerId: Int? = nil
                let firstGameUsingTriggerId = Prefference.defalut.getPrefference(kind: .triggerPro, storeKey: .game(gameId: firstGame.id), bestEfforts: true)?.triggerProValue
                if let firstGameUsingTriggerId, firstGameUsingTriggerId != -1 {
                    if games.allSatisfy({
                        Prefference.defalut.getPrefference(kind: .triggerPro, storeKey: .game(gameId: $0.id), bestEfforts: true)?.triggerProValue == firstGameUsingTriggerId
                    }) {
                        usingTriggerId = firstGameUsingTriggerId
                    }
                }
                if let usingTriggerId {
                    options.append(triggers.map({ ASListPage.Cell.iconTitleDetailRadioCell(title: $0.triggerProName, isSelected: $0.id == usingTriggerId) }))
                } else {
                    options.append(triggers.map({ ASListPage.Cell.iconTitleDetailRadioCell(title: $0.triggerProName) }))
                }
                options.append([ASListPage.Cell.iconTitleChevronCell(title: R.string.localizable.disableTriggerPro())])
                options.append([ASListPage.Cell.iconTitleChevronCell(title: R.string.localizable.manageTriggerPro())])
                let sheet = ASSheet(style: .simpleList(icon: icon, title: title, options: options))
                pauseEmulationIfNeed()
                var isFunctionDismiss = false
                ASSheetView.show(sheet, action: { action, _ in
                    if let indexPath = action.listPageValue?.normalItemValue?.indexPath {
                        if indexPath.section == 0 || indexPath.section == 1 {
                            let storeValue = indexPath.section == 0 ? "\(triggers[indexPath.row].id)" : "-1"
                            //section == 0: trigger pro
                            //section == 1: disableTriggerPro
                            games.forEach({
                                Prefference.defalut.storePrefference(kind: .triggerPro, storeKey: .game(gameId: $0.id), storeValue: storeValue)
                            })
                            PlayViewController.updateTriggerPro()
                            accessoryChange?()
                            isFunctionDismiss = true
                            return .dismiss(completion: {
                                hideSheetInGaming()
                                resumeEmulationIfNeed()
                            })
                        } else if indexPath.section == 2 {
                            //manageTriggerPro
                            isFunctionDismiss = true
                            return .dismiss(completion: {
                                TriggerProManageView.show(hideCompletion: {
                                    accessoryChange?()
                                    resumeEmulationIfNeed()
                                })
                            })
                        }
                    } else if let navigationValue = action.listPageValue?.navigationValue,
                                navigationValue.isTapClose {
                        isFunctionDismiss = true
                        return .dismiss(completion: {
                            resumeEmulationIfNeed()
                        })
                    }
                    return .none
                }, dismiss: {
                    if !isFunctionDismiss {
                        resumeEmulationIfNeed()
                    }
                })
            }

        case .screenScaling:
            performStringAction(with: games, accessoryChange: accessoryChange)

        case .insertDisc:
            pauseEmulationIfNeed()
            UIView.makeAlert(title: R.string.localizable.insertDisc(),
                             detail: R.string.localizable.insertDiscAlert(),
                             cancelTitle: R.string.localizable.transferPakFromLibrary(),
                             confirmTitle: R.string.localizable.transferPakFromFiles(), cancelAction: {
                let realm = Database.realm
                let objects = realm.objects(Game.self).where({ $0.gameType == firstGame.gameType && !$0.isDeleted })
                var games = [Game]()
                games.append(contentsOf: objects)
                if games.count > 0 {
                    GamesSelectionView.show(title: R.string.localizable.insertDisc(),
                                            showGames: games,
                                            completion: { game in
                        if let path = game?.romUrl.path {
                            if LibretroCore.sharedInstance().insertDisk(path) {
                                UIView.makeToast(message: R.string.localizable.discInsert(firstGame.diskInfo?.currentDiskIndex ?? 0))
                            } else {
                                UIView.makeToast(message: R.string.localizable.insertDiscFailed())
                            }
                        } else {
                            UIView.makeToast(message: R.string.localizable.transferPakNoGames())
                        }
                        resumeEmulationIfNeed()
                    })
                } else {
                    UIView.makeToast(message: R.string.localizable.transferPakNoGames())
                    resumeEmulationIfNeed()
                }
            }, confirmAction: {
                let types = UTType.getGameTypes(gameType: firstGame.gameType)
                DispatchQueue.main.asyncAfter(delay: 1) {
                    FilesImporter.shared.presentImportController(supportedTypes: types,
                                                                 allowsMultipleSelection: false,
                                                                 manualHandle: { urls in
                        if let url = urls.first {
                            let toCachePath = R.Path.Cache.appendingPathComponent(url.lastPathComponent)
                            if !FileManager.default.fileExists(atPath: toCachePath) {
                                UIView.makeLoading()
                                try? FileManager.safeCopyItem(at: url, to: URL(fileURLWithPath: toCachePath))
                                DispatchQueue.main.async {
                                    UIView.hideLoading()
                                }
                            }
                            if LibretroCore.sharedInstance().insertDisk(toCachePath) {
                                UIView.makeToast(message: R.string.localizable.discInsert(firstGame.diskInfo?.currentDiskIndex ?? 0))
                            } else {
                                UIView.makeToast(message: R.string.localizable.insertDiscFailed())
                            }
                        }
                        resumeEmulationIfNeed()
                    }, cancelHandle: {
                        resumeEmulationIfNeed()
                    })
                }
            }, hideAction: { type in
                if type == .other {
                    resumeEmulationIfNeed()
                }
            })
        case .reload:
            PlayViewController.reload()
            hideSheetInGaming()

        case .quit:
            PlayViewController.quit()
            if !game.isAzaharArticBase {
                hideSheetInGaming()
            }
            
        case .gameShortcut:
            pauseEmulationIfNeed()
            GameShortcutView.show(games: games, hideCompletion: {
                resumeEmulationIfNeed()
            })
            
        case .deadZone:
            pauseEmulationIfNeed()
            DeadZoneControl.show(hideCompletion: {
                accessoryChange?()
                resumeEmulationIfNeed()
            })
            
        case .rewind:
            performSwitchAction(with: games)
            
        case .netplay:
            if PlayViewController.isGaming {
                pauseEmulationIfNeed()
                LibretroNetplayView.show(game: firstGame, hideCompletion: {
                    resumeEmulationIfNeed()
                })
            } else {
                LibretroNetplayView.show()
            }
            
        case .symbianDevice:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .wiiControllerMode:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        case .coverScraping:
            GameCoverScrapingView.show(games: games)
            
        case .dolphinCpuCore:
            performStringAction(with: games, accessoryChange: accessoryChange)
            
        }
    }
    
    private func performSwitchAction(with games: [Game],
                                     accessoryChange: (() -> Void)? = nil,
                                     reloadAll: (() -> Void)? = nil) {
        guard let firstGame = games.first else { return }
        
        var firstGameTimeConsumingValue: Bool? = nil
        if self == .pspTexture {
            firstGameTimeConsumingValue = (firstGame.getExtraBool(key: ExtraKey.pspTexture.rawValue) ?? false)
        } else if self == .ndsMicrophone {
            firstGameTimeConsumingValue = (firstGame.getExtraBool(key: ExtraKey.microphone.rawValue) ?? false)
        } else if self == .hideControls {
            firstGameTimeConsumingValue = (firstGame.getExtraBool(key: ExtraKey.forceFullSkin.rawValue) ?? false)
        } else if self == .rewind {
            firstGameTimeConsumingValue = (firstGame.getExtraBool(key: ExtraKey.rewind.rawValue) ?? false)
        }
        
        if games.count == 1 {
            if self == .jit {
                Game.change(action: { _ in firstGame.jit.toggle() })
                if firstGame.isDolphinCore {
                    reloadAll?()
                }
            } else if self == .citraShader {
                Game.change(action: { _ in firstGame.accurateShaders.toggle() })
                hideSheetInGaming()
                if PlayViewController.isGaming {
                    var message = R.string.localizable.shaderModeTitle() + " "
                    message += (firstGame.accurateShaders ?  R.string.localizable.enableTitle() : R.string.localizable.disableTitle())
                    UIView.makeToast(message: message)
                }
            } else if self == .citraRightEyeRender {
                Game.change(action: { _ in firstGame.renderRightEye.toggle() })
                hideSheetInGaming()
                if PlayViewController.isGaming {
                    var message = R.string.localizable.renderRightEyeTitle() + " "
                    message += (firstGame.renderRightEye ?  R.string.localizable.enableTitle() : R.string.localizable.disableTitle())
                    UIView.makeToast(message: message)
                }
            } else if self == .pspTexture {
                firstGame.updateExtra(key: ExtraKey.pspTexture.rawValue, value: !(firstGameTimeConsumingValue ?? false))
            } else if self == .ndsMicrophone {
                firstGame.updateExtra(key: ExtraKey.microphone.rawValue, value: !(firstGameTimeConsumingValue ?? false))
            } else if self == .volume {
                performVolume(game: firstGame)
            } else if self == .swapScreen {
                Game.change(action: { _ in firstGame.swapScreen.toggle() })
                hideSheetInGaming()
            } else if self == .hideControls {
                let forceFullSkin = !(firstGameTimeConsumingValue ?? false)
                firstGame.updateExtra(key: ExtraKey.forceFullSkin.rawValue, value: forceFullSkin)
                PlayViewController.forceFullSkin(hideControls: forceFullSkin)
                hideSheetInGaming()
            } else if self == .rewind {
                firstGame.updateExtra(key: ExtraKey.rewind.rawValue, value: !(firstGameTimeConsumingValue ?? false))
                PlayViewController.updateRewind()
            }
        } else {
            var selectedIndex: Int? = nil
            
            if games.allSatisfy({
                self == .jit && $0.jit == firstGame.jit ||
                self == .citraShader && $0.accurateShaders == firstGame.accurateShaders ||
                self == .citraRightEyeRender && $0.renderRightEye == firstGame.renderRightEye ||
                self == .pspTexture && ($0.getExtraBool(key: ExtraKey.pspTexture.rawValue) ?? false) == (firstGameTimeConsumingValue ?? false) ||
                self == .ndsMicrophone && ($0.getExtraBool(key: ExtraKey.microphone.rawValue) ?? false) == (firstGameTimeConsumingValue ?? false) ||
                self == .volume && $0.volume == firstGame.volume ||
                self == .swapScreen && $0.swapScreen == firstGame.swapScreen ||
                self == .hideControls && ($0.getExtraBool(key: ExtraKey.forceFullSkin.rawValue) ?? false) == (firstGameTimeConsumingValue ?? false) ||
                self == .rewind && ($0.getExtraBool(key: ExtraKey.rewind.rawValue) ?? false) == (firstGameTimeConsumingValue ?? false)
            }) {
                if self == .jit {
                    selectedIndex = firstGame.jit ? 0 : 1
                } else if self == .citraShader {
                    selectedIndex = firstGame.accurateShaders ? 0 : 1
                } else if self == .citraRightEyeRender {
                    selectedIndex = firstGame.renderRightEye ? 0 : 1
                } else if self == .pspTexture {
                    selectedIndex = (firstGameTimeConsumingValue ?? false) ? 0 : 1
                } else if self == .ndsMicrophone {
                    selectedIndex = (firstGameTimeConsumingValue ?? false) ? 0 : 1
                } else if self == .volume {
                    selectedIndex = firstGame.volume ? 0 : 1
                } else if self == .swapScreen {
                    selectedIndex = firstGame.swapScreen ? 0 : 1
                } else if self == .hideControls {
                    selectedIndex = (firstGameTimeConsumingValue ?? false) ? 0 : 1
                } else if self == .rewind {
                    selectedIndex = (firstGameTimeConsumingValue ?? false) ? 0 : 1
                }
            }
            
            var options = [R.string.localizable.on(), R.string.localizable.off()]
            if self == .citraRightEyeRender {
                options = [R.string.localizable.enableTitle(), R.string.localizable.disableTitle()]
            }
            
            var detail: String? = nil
            if self == .jit {
                detail = R.string.localizable.jitMenuDesc()
            } else if self == .citraShader {
                detail = R.string.localizable.shaderModeDesc()
            } else if self == .citraRightEyeRender {
                detail = R.string.localizable.renderRightEyeDesc()
            } else if self == .pspTexture {
                detail = R.string.localizable.textureReplacement()
            } else if self == .ndsMicrophone {
                detail = R.string.localizable.microphoneTips()
            } else if self == .rewind {
                detail = R.string.localizable.rewindDesc()
            }
            
            OptionsSheetView.show(icon: icon,
                                  title: title,
                                  detail: detail,
                                  options: options,
                                  selectedIndex: selectedIndex,
                                  completion: { index in
                if let index {
                    for game in games {
                        if self == .jit {
                            Game.change(action: { _ in game.jit = index == 0 })
                        } else if self == .citraShader {
                            Game.change(action: { _ in game.accurateShaders = index == 0 })
                        } else if self == .citraRightEyeRender {
                            Game.change(action: { _ in game.renderRightEye = index == 0 })
                        } else if self == .pspTexture {
                            game.updateExtra(key: ExtraKey.pspTexture.rawValue, value: index == 0)
                        } else if self == .ndsSystemType {
                            game.updateExtra(key: ExtraKey.microphone.rawValue, value: index == 0)
                        } else if self == .volume {
                            Game.change(action: { _ in game.volume = index == 0 })
                        } else if self == .swapScreen {
                            Game.change(action: { _ in game.swapScreen = index == 0 })
                        } else if self == .ndsSystemType {
                            game.forceFullSkin = index == 0
                            game.updateExtra(key: ExtraKey.forceFullSkin.rawValue, value: index == 0)
                        } else if self == .rewind {
                            game.updateExtra(key: ExtraKey.rewind.rawValue, value: index == 0)
                        }
                    }
                    accessoryChange?()
                    if games.allSatisfy({ $0.isDolphinCore }) {
                        reloadAll?()
                    }
                }
            })
        }
    }
    
    private func performStringAction(with games: [Game], accessoryChange: (() -> Void)? = nil) {
        guard let firstGame = games.first else { return }
        
        var options = [String]()
        var symbianDevices = [LibretroSymbianDevice]()
        var detail: String? = nil
        if self == .azaharEmulationAccuracy {
            options = ["HLE", "LLE"]
            detail = R.string.localizable.emulationAccuracyDesc()
        } else if self == .pspJitType {
            options = ["JIT", "IR JIT"]
            detail = R.string.localizable.jitTypeDesc()
        } else if self == .pspRenderer {
            options = ["Automatic", "OpenGL", "Vulkan"]
        } else if self == .ps1ControllerMode {
            options = [R.Strings.PSXDualShock, R.Strings.PSXController]
            detail = R.string.localizable.analogModeDesc()
        } else if self == .ps1Renderer {
            options = ["Hardware", "Software"]
            detail = R.string.localizable.rendererDesc()
        } else if self == .n64RdpPlugin {
            options = ["GLideN64", "ParaLLEl-RDP"]
            detail = R.string.localizable.n64RDPDesc()
        } else if self == .ndsSystemType {
            options = ["DS", "DSi"]
            detail = R.string.localizable.ndsSystemTypeDesc()
        } else if self == .clownMDTvStandard {
            options = ["NTSC (59.94HZ)", "PAL (50HZ)"]
            detail = R.string.localizable.tvStandard()
        } else if self == .snesVRAM {
            options = [R.string.localizable.enableTitle(), R.string.localizable.disableTitle()]
            detail = R.string.localizable.snesvramEnable()
        } else if self == .fastForward {
            options = GameOption.FastForwardSpeed.allCases.map({ $0.title })
        } else if self == .haptic {
            options = GameOption.HapticType.allCases.map({ $0.title })
        } else if self == .orientation {
            options = GameOption.OrientationType.allCases.map({ $0.title })
        } else if self == .resolution {
            if firstGame.gameType == .ps1 {
                options = GameOption.Resolution.AllResolutionTitleForPS1
            } else if firstGame.isN64ParaLLEl {
                options = GameOption.Resolution.AllResolutionTitleForN64ParaLLEl
            } else {
                options = GameOption.Resolution.allCases.filter({ $0 != .undefine }).map({ $0.title })
            }
        } else if self == .palette {
            if firstGame.gameType == .vb {
                options = GameOption.Palette.AllPaletteTitleForVB
                
            } else if firstGame.gameType == .pm {
                options = GameOption.Palette.AllPaletteTitleForPM
                
            } else if firstGame.gameType == .gb {
                if firstGame.defaultCore == 0 {
                    //Gambatte
                    options = GameOption.Palette.allCases.map({ $0.optionForGambatte })
                    
                } else if firstGame.defaultCore == 1 {
                    //mGBA
                    options = GameOption.Palette.allCases.map({ $0.optionForMGBA })
                    
                } else if firstGame.defaultCore == 2 {
                    options = GameOption.Palette.allCases.map({ $0.optionForVBAM })
                }
            }
        } else if self == .swapDisk {
            if firstGame.gameType == .fds {
                options = [R.string.localizable.diskSideChange(), R.string.localizable.ejectDisk()]
            } else {
                if let diskInfo = firstGame.diskInfo {
                    options = (0..<diskInfo.diskCount).map({ "Disc \($0)" })
                }
            }
        } else if self == .airPlayScaling {
            options = GameOption.AirPlayScaling.allCases.map({ $0.title })
        } else if self == .airPlayLayout {
            options = GameOption.AirPlayLayout.allCases.map({ $0.title })
            detail = R.string.localizable.airPlayLayoutTips()
        } else if self == .screenScaling {
            options = GameOption.ScreenScaling.allCases.map({ $0.title })
        } else if self == .symbianDevice {
            if let devices = LibretroCore.getSymbianDevices(),
                devices.count > 0 {
                symbianDevices = devices
                options = devices.map({ $0.model })
                detail = R.string.localizable.symbianOSFirmwareDesc()
            } else {
                UIView.makeToast(message: R.string.localizable.noFirmware())
                SymbianFirmwareView.show()
                return
            }
        } else if self == .wiiControllerMode {
            options = R.Strings.WiiControllers
            detail = R.string.localizable.wiimoteDesc()
        } else if self == .dolphinCpuCore {
            options = R.Strings.DolphinCPUs
            detail = R.string.localizable.dolphinCPUDesc()
        }
        
        guard options.count > 0 else { return }
        
        var selectedIndex: Int? = nil
        if let accessory = accessory(for: games).chevronValue,
           let accessoryString = accessory.string,
           let index = options.firstIndex(where: { $0 == accessoryString }) {
            selectedIndex = index
        }
        pauseEmulationIfNeed()
        OptionsSheetView.show(icon: icon,
                              title: title,
                              detail: detail,
                              options: options,
                              selectedIndex: selectedIndex,
                              groupTogether: true,
                              completion: { index in
            if let index {
                if self == .azaharEmulationAccuracy {
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.emulationAccuracy.rawValue, value: index)
                    })
                } else if self == .pspJitType {
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.jitType.rawValue, value: index)
                    })
                } else if self == .pspRenderer {
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.pspRenderer.rawValue, value: index)
                    })
                } else if self == .ps1ControllerMode {
                    if PlayViewController.isGaming {
                        let isAnalog = firstGame.getExtraBool(key: ExtraKey.isAnalog.rawValue) ?? true
                        if (isAnalog && index == 1) || (!isAnalog && index == 0) {
                            PlayViewController.updateAnalogMode()
                        }
                        resumeEmulationIfNeed()
                    }
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.isAnalog.rawValue, value: index == 0)
                    })
                } else if self == .ps1Renderer {
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.psxRenderer.rawValue, value: index == 0)
                    })
                } else if self == .n64RdpPlugin {
                    Game.change { realm in
                        games.forEach({
                            $0.resolution = .one
                        })
                    }
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.rdpPlugin.rawValue, value: index == 0)
                    })
                } else if self == .ndsSystemType {
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.ndsSystemMode.rawValue, value: options[index])
                    })
                } else if self == .clownMDTvStandard {
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.tvStandard.rawValue, value: index)
                    })
                } else if self == .clownMDTvStandard {
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.tvStandard.rawValue, value: index)
                    })
                } else if self == .snesVRAM {
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.snesVRAM.rawValue, value: index == 0)
                    })
                } else if self == .fastForward {
                    if let speed = GameOption.FastForwardSpeed(rawValue: index+1) {
                        performFastForward(games: games, speed: speed)
                    }
                } else if self == .haptic {
                    if let haptic = GameOption.HapticType(rawValue: index) {
                        performHaptic(games: games, haptic: haptic)
                    }
                } else if self == .orientation {
                    if let orientation = GameOption.OrientationType(rawValue: index) {
                        performOrientation(games: games, orientation: orientation)
                    }
                } else if self == .resolution {
                    if let resolution = GameOption.Resolution(rawValue: index+1) {
                        performResolution(games: games, resolution: resolution)
                    }
                    
                } else if self == .palette {
                    if let palette = GameOption.Palette(rawValue: index) {
                        Game.change { realm in
                            games.forEach({
                                if $0.pallete != palette {
                                    $0.pallete = palette
                                }
                            })
                        }
                        if PlayViewController.isGaming {
                            if firstGame.gameType == .vb {
                                LibretroCore.sharedInstance().updateConfig(EmulationCore.BeetleVB.name, key: SpecialCoreOption.vb_color_mode.rawValue, value: palette.paletteTitleForVB, reload: true)
                            } else if firstGame.gameType == .pm {
                                LibretroCore.sharedInstance().updateConfig(EmulationCore.PokeMini.name, key: SpecialCoreOption.pokemini_palette.rawValue, value: palette.paletteTitleForPM, reload: true)
                            } else if firstGame.gameType == .gb {
                                if firstGame.defaultCore == 0 {
                                    //Gambatte
                                    LibretroCore.sharedInstance().updateRunningCoreConfigs([
                                        SpecialCoreOption.gambatte_gb_colorization.rawValue: palette == .None ? "disabled" : "internal",
                                        SpecialCoreOption.gambatte_gb_internal_palette.rawValue: palette.optionForGambatte
                                    ], flush: false)
                                } else if firstGame.defaultCore == 1 {
                                    //mGBA
                                    LibretroCore.sharedInstance().updateRunningCoreConfigs([
                                        SpecialCoreOption.mgba_gb_colors.rawValue: palette.optionForMGBA
                                    ], flush: false)
                                } else if firstGame.defaultCore == 2 {
                                    LibretroCore.sharedInstance().updateRunningCoreConfigs([
                                        SpecialCoreOption.vbam_palettes.rawValue: palette.optionForVBAM
                                    ], flush: false)
                                }
                            }
                            resumeEmulationIfNeed()
                        }
                    }
                    
                } else if self == .swapDisk {
                    if firstGame.gameType == .fds {
                        if index == 0 {
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
                        hideSheetInGaming()
                    } else {
                        LibretroCore.sharedInstance().setDiskIndex(UInt32(index), delay: firstGame.gameType == .ps1 ? true : false)
                        UIView.makeToast(message: R.string.localizable.discInsert(index))
                    }
                    resumeEmulationIfNeed()
                    
                } else if self == .airPlayScaling {
                    if index != Settings.defalut.airPlayScaling.rawValue {
                        Settings.defalut.updateExtra(key: ExtraKey.airPlayScaling.rawValue, value: index)
                        PlayViewController.updateAirPlay()
                        if PlayViewController.isGaming {
                            UIView.makeToast(message: R.string.localizable.airPlayScaling() + ": " + Settings.defalut.airPlayScaling.title)
                        }
                        hideSheetInGaming()
                        resumeEmulationIfNeed()
                    }
                } else if self == .airPlayLayout {
                    if index != Settings.defalut.airPlayLayout.rawValue {
                        Settings.defalut.updateExtra(key: ExtraKey.airPlayLayout.rawValue, value: index)
                        PlayViewController.updateAirPlay()
                    }
                    if PlayViewController.isGaming {
                        UIView.makeToast(message: R.string.localizable.airPlayLayout() + ": " + Settings.defalut.airPlayLayout.title)
                    }
                    hideSheetInGaming()
                    resumeEmulationIfNeed()
                    
                } else if self == .screenScaling {
                    if let screenScaling = GameOption.ScreenScaling(rawValue: index) {
                        games.forEach({
                            if $0.screenScaling != screenScaling {
                                $0.updateExtra(key: ExtraKey.screenScaling.rawValue, value: index)
                            }
                        })
                        PlayViewController.updateScreenScaling()
                        if PlayViewController.isGaming {
                            UIView.makeToast(message: R.string.localizable.screenScaling() + ": " + firstGame.screenScaling.title)
                        }
                        hideSheetInGaming()
                        resumeEmulationIfNeed()
                    }
                } else if self == .symbianDevice {
                    let device = symbianDevices[index]
                    games.forEach({
                        $0.updateSymbianGame(device: device, changeSkin: true)
                    })
                } else if self == .wiiControllerMode {
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.wiiController.rawValue, value: index)
                    })
                    if PlayViewController.isGaming {
                        let wiiController = firstGame.getExtraInt(key: ExtraKey.wiiController.rawValue) ?? 0
                        let controllerType = LibretroWiiController(rawValue: wiiController) ?? .classicPro
                        let realm = Database.realm
                        if let currentSkinID = PlayViewController.currentSkinID,
                           let skin = realm.object(ofType: Skin.self, forPrimaryKey: currentSkinID) {
                            if controllerType == .classicPro, skin.skinType != .default {
                                PlayViewController.updateSkin()
                            } else if controllerType != .classicPro, skin.skinType == .default {
                                PlayViewController.updateSkin()
                            }
                            
                        }
                        LibretroCore.sharedInstance().setWiiController(controllerType)
                        WiiEmulatorBridge.shared.controllerType = controllerType
                        resumeEmulationIfNeed()
                    }
                } else if self == .dolphinCpuCore {
                    games.forEach({
                        $0.updateExtra(key: ExtraKey.dolphinManicInterpreter.rawValue, value: index == 0)
                    })
                }
                accessoryChange?()
            } else {
                resumeEmulationIfNeed()
            }
        })
    }
    
    private func performFastForward(games: [Game],
                                    speed: GameOption.FastForwardSpeed) {
        guard let firstGame = games.first else { return }
        if !PurchaseManager.isMember && speed.rawValue > GameOption.FastForwardSpeed.two.rawValue {
            pauseEmulationIfNeed()
            
            UIView.makeAlert(identifier: R.Strings.PlayPurchaseAlertIdentifier,
                             detail: R.string.localizable.fastForwardSpeedLimit(),
                             cancelTitle: R.string.localizable.resetSpeed(),
                             confirmTitle: R.string.localizable.goToUpgrade(),
                             confirmAutoHide: false, cancelAction: {
                PlayViewController.updateFastforward(speed: .one)
                Game.change { realm in
                    games.forEach({ $0.speed = .one })
                }
                resumeEmulationIfNeed()
                UIView.makeToast(message: R.string.localizable.gameSettingFastForwardResume())
            }, confirmAction: {
                topViewController()?.present(PurchaseViewController(), animated: true)
            }, hideAction: { type in
                if type == .other {
                    resumeEmulationIfNeed()
                }
            })
        } else {
            if PlayViewController.isGaming {
                if firstGame.gameType == .ps1, firstGame.defaultCore == 0 {
                    pauseEmulationIfNeed()
                }
                PlayViewController.updateFastforward(speed: speed)
                if firstGame.gameType == .ps1, firstGame.defaultCore == 0 {
                    resumeEmulationIfNeed()
                }
            }
            Game.change { realm in
                games.forEach({
                    if $0.speed == 0 || $0.speed != speed {
                        $0.speed = speed
                    }
                })
            }
            if PlayViewController.isGaming {
                UIView.makeToast(message: speed == .one ? R.string.localizable.gameSettingFastForwardResume() : speed.title, identifier: "gameSpeed")
            }
        }
    }
    
    private func performVolume(game: Game) {
        Game.change(action: { _ in game.volume.toggle() })
        if !GameOptionsView.hasShownInstance {
            PlayViewController.updateAudio()
        }
        if PlayViewController.isGaming {
            UIView.makeToast(message: game.volume ? R.string.localizable.volumeOn(): R.string.localizable.volumeOff(), identifier: "gameVolume")
        }
    }
    
    private func performHaptic(games: [Game], haptic: GameOption.HapticType) {
        switch haptic {
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
        
        Game.change { realm in
            games.forEach({
                if $0.haptic != haptic {
                    $0.haptic = haptic
                }
            })
        }
        
        if PlayViewController.isGaming {
            UIView.makeToast(message: haptic.title, identifier: "hapticType")
            resumeEmulationIfNeed()
        }
    }
    
    private func performOrientation(games: [Game], orientation: GameOption.OrientationType) {
        Game.change { realm in
            games.forEach({
                if $0.orientation != orientation {
                    $0.orientation = orientation
                }
            })
        }
        if PlayViewController.isGaming {
            DispatchQueue.main.asyncAfter(delay: 0.5) {
                UIView.makeToast(message: orientation.title)
                resumeEmulationIfNeed()
            }
        }
    }
    
    private func performResolution(games: [Game], resolution: GameOption.Resolution) {
        guard let firstGame = games.first else { return }
        Game.change { realm in
            games.forEach({
                if $0.resolution != resolution {
                    $0.resolution = resolution
                }
            })
        }
        PlayViewController.updateResolution(resolution)
        let message: String
        if firstGame.gameType == .ps1 && firstGame.defaultCore == 0 {
            message = R.string.localizable.gameSettingResolution(resolution.resolutionTitleForPS1)
        } else if firstGame.isN64ParaLLEl {
            message = R.string.localizable.gameSettingResolution(resolution.resolutionTitleForN64ParaLLEl)
        } else {
            message = resolution.title
        }
        UIView.makeToast(message: message, identifier: "resolution")
        resumeEmulationIfNeed()
    }
    
    private var isGameOptionViewShow: Bool {
        return GameOptionsView.hasShownInstance
    }
    
    private func pauseEmulationIfNeed() {
        if !isGameOptionViewShow {
            PlayViewController.pauseEmulationIfNeed()
        }
    }
    
    private func resumeEmulationIfNeed() {
        if !isGameOptionViewShow {
            PlayViewController.resumeEmulationAndHandleAudio()
        }
    }
    
    private func hideSheetInGaming() {
        if PlayViewController.isGaming {
            UIView.hideAllAlert()
        }
    }
    
    private func showSaveTipsIfNeed(games: [Game]) -> Bool {
        var tips: String? = nil
        if games.contains(where: { $0.isDolphinCore }) {
            tips = R.string.localizable.dolphinSaveTips()
        } else if games.contains(where: { $0.gameType == .symbian }) {
            tips = R.string.localizable.symbianSaveTips()
        } else if games.contains(where: { $0.gameType == .dc }) {
            tips = R.string.localizable.dcSaveTips()
        } else if games.contains(where: { $0.gameType == .doom }) {
            tips = R.string.localizable.doomSaveTips()
        }
        if let tips {
            UIView.makeAlert(title: R.string.localizable.focusShortcutsTips(),
                             detail: tips,
                             cancelTitle: R.string.localizable.gotIt())
            return true
        } else {
            return false
        }
    }
    
    func showSecondPromptIfNeed(continued: (() -> Void)? = nil) {
        if self == .quit || self == .reload || self == .quickLoadState {
            UIView.makeAlert(title: R.string.localizable.headsUp(),
                             detail: R.string.localizable.continuedAlert(self.title),
                             confirmTitle: R.string.localizable.confirmTitle(),
                             confirmAction: {
                continued?()
            })
        } else {
            continued?()
        }
    }
}
