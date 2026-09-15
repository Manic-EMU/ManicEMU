//
//  GameInfoDetailReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import BetterSegmentedControl
import RealmSwift
import UniformTypeIdentifiers


class GameInfoDetailReusableView: UICollectionReusableView {
    let backgroundBlurView: UIView = {
        let view = UIView()
        view.makeBlur()
        view.alpha = 0
        return view
    }()
    
    lazy var titleTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = Constants.Color.LabelPrimary
        textField.font = UIFont.systemFont(ofSize: 17)
        textField.clearButtonMode = .never
        textField.returnKeyType = .done
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
            if let game = self.game, let text = textField?.text?.trimmed {
                if text.isEmpty {
                    textField?.text = game.aliasName ?? game.name
                    UIView.makeToast(message: R.string.localizable.readyEditTitleFailed())
                } else if text != game.aliasName {
                    Game.change { realm in
                        game.aliasName = text
                    }
                }
            }
        }
        textField.onChange { [weak textField] text in
            if text.count > Constants.Size.GameNameMaxCount {
                if let markRange = textField?.markedTextRange, let _ = textField?.position(from: markRange.start, offset: 0) { } else {
                    textField?.text = String(text.prefix(Constants.Size.GameNameMaxCount))
                }
            }
        }
        return textField
    }()
    
    private lazy var editTitleButton: SymbolButton = {
        let view = SymbolButton(image: R.image.customPencilLine()?.applySymbolConfig(size: Constants.Size.IconSizeMin.height))
        view.backgroundColor = .clear
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if !self.titleTextField.isFirstResponder {
                self.titleTextField.becomeFirstResponder()
            }
        }
        return view
    }()
    
    private let subtitleIcon: UIImageView = {
        let view = UIImageView()
        view.image = .symbolImage(.starCircleFill).applySymbolConfig(color: Constants.Color.LabelSecondary)
        return view
    }()
    
    private let subtitleLabel: UILabel = {
        let view = UILabel()
        view.textColor = Constants.Color.LabelSecondary
        view.font = Constants.Font.body()
        return view
    }()
    
    private let functionButtonContainerView: UIScrollView = {
        let view = UIScrollView()
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        if Locale.isRTLLanguage {
            view.semanticContentAttribute = .forceLeftToRight
        }
        return view
    }()
    
    private lazy var retroButton: SymbolButton = {
        let view = SymbolButton(image: R.image.customTrophy()?.applySymbolConfig(), title: R.string.localizable.retroAchievements2())
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self, let game else { return }
            if !game.supportRetroAchievements {
                let showName = game.gameType == .arcade ? LibretroCore.Cores.MAME.name : game.gameType.localizedShortName
                UIView.makeToast(message: R.string.localizable.achievementsNotSupport(showName))
                return
            }
            if let _ = AchievementsUser.getUser() {
                topViewController()?.present(RetroAchievementsListViewController(game: game), animated: true)
            } else {
                //先进行登录
                let vc = RetroAchievementsViewController()
                vc.dismissAfterLoginSuccess = { [weak self] in
                    topViewController()?.present(RetroAchievementsListViewController(game: game), animated: true)
                }
                topViewController()?.present(vc, animated: true)
            }
        }
        
        // 无障碍配置
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.retroAchievements2()
        view.accessibilityTraits = .button
        
        return view
    }()

    private lazy var skinButton: SymbolButton = {
        let view = SymbolButton(symbol: .tshirt, title: R.string.localizable.gamesSpecifySkin())
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if let game = self.game {
                topViewController()?.present(SkinSettingsViewController(game: game), animated: true)
            }
        }
        
        // 无障碍配置
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.gamesSpecifySkin()
        view.accessibilityTraits = .button
        
        return view
    }()
    
    private lazy var cheatCodeButton: SymbolButton = {
        let view = SymbolButton(image: R.image.customAppleTerminal()?.applySymbolConfig(), title: R.string.localizable.gamesCheatCode())
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if let game = self.game {
                if game.gameType == .arcade {
                    if game.defaultCore == 0 {
                        UIView.makeAlert(detail: R.string.localizable.mameCheatCodeDesc(), cancelTitle: R.string.localizable.confirmTitle())
                    } else if game.defaultCore == 1 {
                        UIView.makeToast(message: R.string.localizable.fbNeoCheatCodeDesc())
                    }
                    return
                }
                topViewController()?.present(CheatCodeViewController(game: game), animated: true)
            }
        }
        
        // 无障碍配置
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.gamesCheatCode()
        view.accessibilityTraits = .button
        
        return view
    }()
    
    private lazy var manualButton: SymbolButton = {
        let view = SymbolButton(symbol: .textBookClosed, title: R.string.localizable.gameplayManuals())
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if let game = self.game {
                if game.isManualsExists {
                    topViewController()?.present(GameplayManualsViewController(game: game), animated: true)
                } else {
                    UIView.makeAlert(title: R.string.localizable.gameplayManualsNoExists(),
                                     detail: R.string.localizable.gameplayManualsDesc(),
                                     confirmTitle: R.string.localizable.gameListBackgroundUpload(),
                                     confirmAction: {
                        FilesImporter.shared.presentImportController(supportedTypes: [UTType.pdf],
                                                                     allowsMultipleSelection: false,
                                                                     manualHandle: { [weak self] urls in
                            guard let self else { return }
                            if let pdfUrl = urls.first {
                                do {
                                    let pdfName = pdfUrl.lastPathComponent
                                    try FileManager.safeCopyItem(at: pdfUrl, to: URL(fileURLWithPath: Constants.Path.GameplayManuals.appendingPathComponent(pdfName)), shouldReplace: true)
                                    game.updateExtra(key: ExtraKey.manualFileName.rawValue, value: pdfName)
                                    topViewController()?.present(GameplayManualsViewController(game: game), animated: true)
                                } catch {}
                            }
                        }, appControllerPresent: true)
                    })
                }
            }
        }
        
        // 无障碍配置
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.gameplayManuals()
        view.accessibilityTraits = .button
        
        return view
    }()
    
    private lazy var threeDSAdvancedModeButton: SymbolButton = {
        let title = Settings.defalut.threeDSAdvancedSettingMode ? R.string.localizable.threeDSBasicSettingMode() : R.string.localizable.threeDSAdvanceSettingMode()
        let view = SymbolButton(symbol: .sliderHorizontal3, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            Settings.change { realm in
                Settings.defalut.threeDSAdvancedSettingMode.toggle()
            }
            self.threeDSAdvancedModeButton.titleLabel.text = Settings.defalut.threeDSAdvancedSettingMode ? R.string.localizable.threeDSBasicSettingMode() : R.string.localizable.threeDSAdvanceSettingMode()
            self.updateCitra3DSFunctionButton()
            self.addManualsButton()
        }
        return view
    }()
    
    private lazy var threeDSModecontextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.threeDSModePerformance()) { [weak self] _ in
            guard let self = self else { return }
            self.threeDSModeButton.titleLabel.text = R.string.localizable.threeDSModePerformance()
            Settings.change { realm in
                Settings.defalut.threeDSMode = .performance
            }
        }))
        actions.append(UIAction(title: R.string.localizable.threeDSModeCompatibility()) { [weak self] _ in
            guard let self = self else { return }
            self.threeDSModeButton.titleLabel.text = R.string.localizable.threeDSModeCompatibility()
            Settings.change { realm in
                Settings.defalut.threeDSMode = .compatibility
            }
        })
        actions.append((UIAction(title: R.string.localizable.threeDSModeQuality()) { [weak self] _ in
            guard let self = self else { return }
            self.threeDSModeButton.titleLabel.text = R.string.localizable.threeDSModeQuality()
            Settings.change { realm in
                Settings.defalut.threeDSMode = .quality
            }
        }))
        let view = ContextMenuButton(image: nil, menu: UIMenu(children: actions))
        return view
    }()
    
    private lazy var threeDSModeButton: SymbolButton = {
        let title: String
        switch Settings.defalut.threeDSMode {
        case .performance:
            title = R.string.localizable.threeDSModePerformance()
        case .compatibility:
            title = R.string.localizable.threeDSModeCompatibility()
        case .quality:
            title = R.string.localizable.threeDSModeQuality()
        }
        let view = SymbolButton(symbol: .gearshape2, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.threeDSModecontextMenuButton.triggerTapGesture()
        }
        
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        
        return view
    }()
    
    private lazy var jitContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.on()) { [weak self] _ in
            guard let self = self else { return }
            self.jitButton.titleLabel.text = "JIT \(R.string.localizable.on())"
            if let game = self.game {
                Game.change { _ in
                    game.jit = true
                }
            }
        }))
        actions.append(UIAction(title: R.string.localizable.off()) { [weak self] _ in
            guard let self = self else { return }
            self.jitButton.titleLabel.text = "JIT \(R.string.localizable.off())"
            if let game = self.game {
                Game.change { _ in
                    game.jit = false
                }
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.jitMenuDesc(), children: actions))
        return view
    }()
    
    private lazy var jitButton: SymbolButton = {
        let title: String
        let jitAvailable = LibretroCore.jitAvailable()
        if jitAvailable {
            if game?.jit ?? false {
                title = "JIT \(R.string.localizable.on())"
            } else {
                title = "JIT \(R.string.localizable.off())"
            }
        } else {
            title = "JIT \(R.string.localizable.off())"
        }
        
        let view = SymbolButton(symbol: .bolt, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if jitAvailable {
                self.jitContextMenuButton.triggerTapGesture()
            } else {
                UIView.makeToast(message: R.string.localizable.jitNoSupportDesc())
            }
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var jitTypeContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: "JIT") { [weak self] _ in
            guard let self = self else { return }
            self.jitTypeButton.titleLabel.text = "\(R.string.localizable.jitType())\nJIT"
            self.game?.updateExtra(key: ExtraKey.jitType.rawValue, value: 0)
        }))
        actions.append(UIAction(title: "IR JIT") { [weak self] _ in
            guard let self = self else { return }
            self.jitTypeButton.titleLabel.text = "\(R.string.localizable.jitType())\nIR JIT"
            self.game?.updateExtra(key: ExtraKey.jitType.rawValue, value: 1)
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.jitTypeDesc(), children: actions))
        return view
    }()
    
    private lazy var jitTypeButton: SymbolButton = {
        let title: String
        let jitAvailable = LibretroCore.jitAvailable()
        if jitAvailable {
            let jitType = ((game?.getExtraInt(key: ExtraKey.jitType.rawValue) ?? 0) == 0) ? "JIT" : "IR JIT"
            title = "\(R.string.localizable.jitType())\n\(jitType)"
        } else {
            title = R.string.localizable.jitNotAllow()
        }
        let view = SymbolButton(symbol: .boltFill, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if jitAvailable {
                self.jitTypeContextMenuButton.triggerTapGesture()
            } else {
                UIView.makeToast(message: R.string.localizable.jitNoSupportDesc())
            }
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var biosSelectionContextMenuButton: ContextMenuButton = {
        let ps1Bios = game?.ps1ImportedBios ?? []
        var actions: [UIMenuElement] = ps1Bios.map({ bios in
            UIAction(title: bios.fileName, subtitle: bios.desc) { [weak self] _ in
                guard let self = self else { return }
                self.biosSelectionButton.titleLabel.text = "BIOS\n" + bios.fileName.deletingPathExtension
                self.game?.updateExtra(key: ExtraKey.biosName.rawValue, value: bios.fileName)
            }
        })
        actions.append(UIAction(title: "OpenBIOS") { [weak self] _ in
            guard let self = self else { return }
            self.biosSelectionButton.titleLabel.text = "BIOS\nOpenBIOS"
            self.game?.updateExtra(key: ExtraKey.biosName.rawValue, value: nil)
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: "BIOS", children: actions))
        return view
    }()
    
    private lazy var biosSelectionButton: SymbolButton = {
        let title = "BIOS\n" + (game?.getExtraString(key: ExtraKey.biosName.rawValue) ?? "OpenBIOS").deletingPathExtension
        let view = SymbolButton(symbol: .cpu, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self, let game = self.game else { return }
            if game.ps1ImportedBios.count > 0 {
                self.biosSelectionContextMenuButton.triggerTapGesture()
            } else {
                UIView.makeToast(message: R.string.localizable.saturnBiosAlertTitle())
            }
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var shaderContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.on()) { [weak self] _ in
            guard let self = self else { return }
            self.shaderButton.titleLabel.text = "\(R.string.localizable.shaderModeTitle())\n\(R.string.localizable.on())"
            if let game {
                Game.change { _ in
                    game.accurateShaders = true
                }
            }
        }))
        actions.append(UIAction(title: R.string.localizable.off()) { [weak self] _ in
            guard let self = self else { return }
            self.shaderButton.titleLabel.text = "\(R.string.localizable.shaderModeTitle())\n\(R.string.localizable.off())"
            if let game {
                Game.change { _ in
                    game.accurateShaders = false
                }
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.shaderModeDesc(), children: actions))
        return view
    }()
    
    private lazy var shaderButton: SymbolButton = {
        let title: String
        if game?.accurateShaders ?? false {
            title = "\(R.string.localizable.shaderModeTitle())\n\(R.string.localizable.on())"
        } else {
            title = "\(R.string.localizable.shaderModeTitle())\n\(R.string.localizable.off())"
        }
        let view = SymbolButton(image: R.image.customLightspectrumHorizontal()?.applySymbolConfig(color: Constants.Color.LabelPrimary), title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.shaderContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var languageContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        var languages = [String]()
        if let game {
            if game.gameType == ._3ds {
                languages = Constants.Strings.ThreeDSConsoleLanguage
            } else if game.gameType == .psp {
                languages = Constants.Strings.PSPConsoleLanguage
            } else if game.gameType == .ss {
                languages = Constants.Strings.SaturnConsoleLanguage
            } else if game.gameType == .ds {
                languages = Constants.Strings.DSConsoleLanguage
            } else if game.gameType == .dc {
                languages = Constants.Strings.DCConsoleLanguage
            }
        }
        for (index, language) in languages.enumerated() {
            actions.append((UIAction(title: language) { [weak self] _ in
                guard let self = self else { return }
                self.languageButton.titleLabel.text = language
                if let game {
                    Game.change { _ in
                        game.region = index
                    }
                }
            }))
        }
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.consoleLanguageDesc(), children: actions))
        return view
    }()
    
    private lazy var languageButton: SymbolButton = {
        var title: String = ""
        if let game {
            var languages = [String]()
            if game.gameType == ._3ds {
                languages = Constants.Strings.ThreeDSConsoleLanguage
            } else if game.gameType == .psp {
                languages = Constants.Strings.PSPConsoleLanguage
            } else if game.gameType == .ss {
                languages = Constants.Strings.SaturnConsoleLanguage
            } else if game.gameType == .ds {
                languages = Constants.Strings.DSConsoleLanguage
            } else if game.gameType == .dc {
                languages = Constants.Strings.DCConsoleLanguage
            }
            if game.region < languages.count {
                title = languages[game.region]
            }
        }
        let view = SymbolButton(symbol: .characterBubble, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.languageContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var rightEyeRenderMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.disableTitle()) { [weak self] _ in
            guard let self = self else { return }
            self.rightEyeRenderButton.titleLabel.text = R.string.localizable.disableTitle() + R.string.localizable.renderRightEyeTitle()
            self.rightEyeRenderButton.imageView.image = .symbolImage(.eyeSlash)
            if let game {
                Game.change { _ in
                    game.renderRightEye = false
                }
            }
        }))
        actions.append(UIAction(title: R.string.localizable.enableTitle()) { [weak self] _ in
            guard let self = self else { return }
            self.rightEyeRenderButton.titleLabel.text = R.string.localizable.enableTitle() + R.string.localizable.renderRightEyeTitle()
            self.rightEyeRenderButton.imageView.image = .symbolImage(.eye)
            if let game {
                Game.change { _ in
                    game.renderRightEye = true
                }
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.renderRightEyeDesc(), children: actions))
        return view
    }()
    
    private lazy var rightEyeRenderButton: SymbolButton = {
        var title: String = R.string.localizable.renderRightEyeTitle()
        let enableRightEyeRender = game?.renderRightEye ?? false
        if enableRightEyeRender {
            title = R.string.localizable.enableTitle() + title
        } else {
            title = R.string.localizable.disableTitle() + title
        }
        let view = SymbolButton(symbol: enableRightEyeRender ? .eye : .eyeSlash, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.rightEyeRenderMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var threeDSAdvancedSettingButton: SymbolButton = {
        let view = SymbolButton(symbol: .gear, title: R.string.localizable.threeDSAdvanceSettingTitle(), horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self, let game else { return }
            if game.defaultCore == 0 {
                topViewController()?.present(CitraAdvancedSettingViewController(), animated: true)
            } else {
                topViewController()?.present(AzaharAdvancedSettingViewController(), animated: true)
            }
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.threeDSAdvanceSettingTitle()
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var transferPakContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append(UIAction(title: R.string.localizable.transferPakFromLibrary()) { [weak self] _ in
            guard let self = self else { return }
            //从游戏库导入
            let realm = Database.realm
            let objects = realm.objects(Game.self).where({ !$0.isDeleted && ($0.gameType == .gbc || $0.gameType == .gb) }).filter({ $0.isSaveExtsts })
            var games = [Game]()
            games.append(contentsOf: objects)
            if games.count > 0 {
                GameSaveMatchGameView.show(showGames: games, title: "Transfer Pak", detail: R.string.localizable.transferPakFromLibraryDesc(), cancelTitle: R.string.localizable.cancelTitle()) { [weak self] selectedGame in
                    guard let self = self else { return }
                    if let game = self.game, let selectedGame, selectedGame.isRomExtsts, selectedGame.isSaveExtsts {
                        try? FileManager.safeCopyItem(at: selectedGame.romUrl, to: URL(fileURLWithPath: game.romUrl.path + ".gb"), shouldReplace: true)
                        try? FileManager.safeCopyItem(at: selectedGame.gameSaveUrl, to: URL(fileURLWithPath: game.romUrl.path + ".sav"), shouldReplace: true)
                        self.transferPakButton.titleLabel.text = "Transfer Pak\n\(R.string.localizable.transferPakOn())"
                        UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                    }
                }
            } else {
                UIView.makeToast(message: R.string.localizable.transferPakNoGames())
            }
        })
        actions.append(UIAction(title: R.string.localizable.transferPakFromFiles()) { [weak self] _ in
            guard let self = self else { return }
            //从文件导入
            if let gb = UTType(filenameExtension: "gb"), let gbc = UTType(filenameExtension: "gbc"), let sav = UTType(filenameExtension: "sav") {
                FilesImporter.shared.presentImportController(supportedTypes: [gb, gbc, sav]) { [weak self] urls in
                    guard let self = self else { return }
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
                    
                    if let game = self.game {
                        try? FileManager.safeCopyItem(at: URL(fileURLWithPath: romPath), to: URL(fileURLWithPath: game.romUrl.path + ".gb"), shouldReplace: true)
                        try? FileManager.safeCopyItem(at: URL(fileURLWithPath: savePath), to: URL(fileURLWithPath: game.romUrl.path + ".sav"), shouldReplace: true)
                        self.transferPakButton.titleLabel.text = "Transfer Pak\n\(R.string.localizable.transferPakOn())"
                        UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                    }
                    
                }
            }
        })
        actions.append(UIAction(title: R.string.localizable.off()) { [weak self] _ in
            guard let self = self else { return }
            //关闭Transfer Pak
            if let game = self.game {
                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: game.romUrl.path + ".gb"))
                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: game.romUrl.path + ".sav"))
                self.transferPakButton.titleLabel.text = "Transfer Pak\n\(R.string.localizable.transferPakOff())"
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.transferPakDesc(), children: actions))
        return view
    }()
    
    private lazy var transferPakButton: SymbolButton = {
        var state = "\n" + R.string.localizable.transferPakOff()
        if let game = self.game, game.hasTransferPak {
            state = "\n" + R.string.localizable.transferPakOn()
        }
        let view = SymbolButton(symbol: .arrowshapeZigzagForward, title: "Transfer Pak\(state)", horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.transferPakContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Transfer Pak\(state)"
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var rdpPluginContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append(UIAction(title: "GLideN64") { [weak self] _ in
            guard let self = self else { return }
            self.rdpPluginButton.titleLabel.text = "RDP Plugin\nGLideN64"
            if let game = self.game {
                Game.change { realm in
                    game.resolution = .one
                }
                game.updateExtra(key: ExtraKey.rdpPlugin.rawValue, value: true)
            }
        })
        actions.append(UIAction(title: "ParaLLEl-RDP") { [weak self] _ in
            guard let self = self else { return }
            self.rdpPluginButton.titleLabel.text = "RDP Plugin\nParaLLEl-RDP"
            if let game = self.game {
                Game.change { realm in
                    game.resolution = .one
                }
                game.updateExtra(key: ExtraKey.rdpPlugin.rawValue, value: false)
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.n64RDPDesc(), children: actions))
        return view
    }()
    
    private lazy var rdpPluginButton: SymbolButton = {
        let title = "RDP Plugin\n" + ((self.game?.isN64ParaLLEl ?? false) ? "ParaLLEl-RDP" : "GLideN64")
        let view = SymbolButton(image: R.image.customLightspectrumHorizontal()?.applySymbolConfig(color: Constants.Color.LabelPrimary), title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.rdpPluginContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var ndsSystemTypeContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append(UIAction(title: "DS") { [weak self] _ in
            guard let self = self else { return }
            self.ndsSystemTypeButton.titleLabel.text = R.string.localizable.ndsSystemTypeTitle() + "\nDS"
            self.game?.updateExtra(key: ExtraKey.ndsSystemMode.rawValue, value: "DS")
            self.updateDSFunctionButton()
            self.addManualsButton()
        })
        actions.append(UIAction(title: "DSi") { [weak self] _ in
            guard let self = self else { return }
            self.ndsSystemTypeButton.titleLabel.text = R.string.localizable.ndsSystemTypeTitle() + "\nDSi"
            self.game?.updateExtra(key: ExtraKey.ndsSystemMode.rawValue, value: "DSi")
            self.updateDSFunctionButton()
            self.addManualsButton()
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.ndsSystemTypeDesc(), children: actions))
        return view
    }()
    
    private lazy var ndsSystemTypeButton: SymbolButton = {
        var type = "\n" + (self.game?.getExtraString(key: ExtraKey.ndsSystemMode.rawValue) ?? "DS")
        let view = SymbolButton(symbol: .squareSplit1x2, title: R.string.localizable.ndsSystemTypeTitle() + type, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.ndsSystemTypeContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.ndsSystemTypeTitle() + type
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var gbaSlotContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append(UIAction(title: R.string.localizable.transferPakFromLibrary()) { [weak self] _ in
            guard let self = self else { return }
            //从游戏库导入
            let realm = Database.realm
            let objects = realm.objects(Game.self).where({ !$0.isDeleted && $0.gameType == .gba })
            var games = [Game]()
            games.append(contentsOf: objects)
            if games.count > 0 {
                GameSaveMatchGameView.show(showGames: games, title: "GBA Slot", detail: R.string.localizable.transferPakFromLibraryDesc(), cancelTitle: R.string.localizable.cancelTitle()) { [weak self] selectedGame in
                    guard let self = self else { return }
                    if let game = self.game, let selectedGame, selectedGame.isRomExtsts {
                        try? FileManager.safeCopyItem(at: selectedGame.romUrl, to: URL(fileURLWithPath: game.romUrl.path + ".slot.gba"), shouldReplace: true)
                        try? FileManager.safeCopyItem(at: selectedGame.gameSaveUrl, to: URL(fileURLWithPath: game.romUrl.path + ".slot.sav"), shouldReplace: true)
                        self.gbaSlotButton.titleLabel.text = "GBA Slot\n\(R.string.localizable.gbaSlotInsert())"
                        self.gbaSlotButton.imageView.image = .symbolImage(.externaldriveBadgeCheckmark)
                        UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                    }
                }
            } else {
                UIView.makeToast(message: R.string.localizable.transferPakNoGames())
            }
        })
        actions.append(UIAction(title: R.string.localizable.transferPakFromFiles()) { [weak self] _ in
            guard let self = self else { return }
            //从文件导入
            if let gba = UTType(filenameExtension: "gba"), let sav = UTType(filenameExtension: "sav") {
                FilesImporter.shared.presentImportController(supportedTypes: [gba, sav]) { [weak self] urls in
                    guard let self = self else { return }
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
                    
                    if let game = self.game {
                        try? FileManager.safeCopyItem(at: URL(fileURLWithPath: romPath), to: URL(fileURLWithPath: game.romUrl.path + ".slot.gba"), shouldReplace: true)
                        if !savePath.isEmpty {
                            try? FileManager.safeCopyItem(at: URL(fileURLWithPath: savePath), to: URL(fileURLWithPath: game.romUrl.path + ".slot.sav"), shouldReplace: true)
                        }
                        self.gbaSlotButton.titleLabel.text = "GBA Slot\n\(R.string.localizable.gbaSlotInsert())"
                        self.gbaSlotButton.imageView.image = .symbolImage(.externaldriveBadgeCheckmark)
                        UIView.makeToast(message: R.string.localizable.alertImportFilesSuccess())
                    }
                    
                }
            }
        })
        actions.append(UIAction(title: R.string.localizable.off()) { [weak self] _ in
            guard let self = self else { return }
            //关闭Transfer Pak
            if let game = self.game {
                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: game.romUrl.path + ".slot.gba"))
                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: game.romUrl.path + ".slot.sav"))
                self.gbaSlotButton.titleLabel.text = "GBA Slot\n\(R.string.localizable.gbaSlotUnInsert())"
                self.gbaSlotButton.imageView.image = .symbolImage(.externaldriveBadgeXmark)
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.gbaSlotDesc(), children: actions))
        return view
    }()
    
    private lazy var gbaSlotButton: SymbolButton = {
        var state = "\n" + R.string.localizable.gbaSlotUnInsert()
        var symbol = SFSymbol.externaldriveBadgeXmark
        if let game = self.game, game.hasGBASlotInsert {
            state = "\n" + R.string.localizable.gbaSlotInsert()
            symbol = SFSymbol.externaldriveBadgeCheckmark
        }
        let view = SymbolButton(symbol: symbol, title: "GBA Slot\(state)", horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if let game = self.game {
                if game.gameType.isNDSBiosComplete().isDSComplete {
                    self.gbaSlotContextMenuButton.triggerTapGesture()
                } else {
                    topViewController(appController: true)?.present(BIOSSelectionViewController(gameType: game.gameType), animated: true)
                }
            }
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = "GBA Slot\(state)"
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var microphoneContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.on()) { [weak self] _ in
            guard let self = self else { return }
            self.microphoneButton.titleLabel.text = R.string.localizable.microphone() + " " + R.string.localizable.on()
            if let game {
                game.updateExtra(key: ExtraKey.microphone.rawValue, value: true)
            }
        }))
        actions.append(UIAction(title: R.string.localizable.off()) { [weak self] _ in
            guard let self = self else { return }
            self.microphoneButton.titleLabel.text = R.string.localizable.microphone() + " " + R.string.localizable.off()
            if let game {
                game.updateExtra(key: ExtraKey.microphone.rawValue, value: false)
            }
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.microphoneTips(), children: actions))
        return view
    }()
    
    private lazy var microphoneButton: SymbolButton = {
        let title: String
        if game?.getExtraBool(key: ExtraKey.microphone.rawValue) ?? false {
            title = R.string.localizable.microphone() + " " + R.string.localizable.on()
        } else {
            title = R.string.localizable.microphone() + " " + R.string.localizable.off()
        }
        let view = SymbolButton(image: R.image.customMicrophone()?.applySymbolConfig(color: Constants.Color.LabelPrimary), title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.microphoneContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var psxModeContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append(UIAction(title: Constants.Strings.PSXController) { [weak self] _ in
            guard let self = self else { return }
            self.psxModeButton.titleLabel.text = Constants.Strings.PSXController
            self.game?.updateExtra(key: ExtraKey.isAnalog.rawValue, value: false)
        })
        actions.append(UIAction(title: Constants.Strings.PSXDualShock) { [weak self] _ in
            guard let self = self else { return }
            self.psxModeButton.titleLabel.text = Constants.Strings.PSXDualShock
            self.game?.updateExtra(key: ExtraKey.isAnalog.rawValue, value: true)
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.analogModeDesc(), children: actions))
        return view
    }()
    
    private lazy var psxModeButton: SymbolButton = {
        let title = (self.game?.getExtraBool(key: ExtraKey.isAnalog.rawValue) ?? true) ? Constants.Strings.PSXDualShock : Constants.Strings.PSXController
        let view = SymbolButton(symbol: .gamecontroller, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.psxModeContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var psxImportSbiButton: SymbolButton = {
        let view = SymbolButton(symbol: .lockRectangleStack, title: R.string.localizable.sbiImport(), horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            if let game = self.game {
                topViewController()?.present(PSXSBIImportViewController(game: game), animated: true)
            }
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.sbiImport()
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var psxRendererContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append(UIAction(title: "Hardware") { [weak self] _ in
            guard let self = self else { return }
            self.psxRendererButton.titleLabel.text = "\(R.string.localizable.rendererTitle())\nHardware"
            self.game?.updateExtra(key: ExtraKey.psxRenderer.rawValue, value: true)
        })
        actions.append(UIAction(title: "Software") { [weak self] _ in
            guard let self = self else { return }
            self.psxRendererButton.titleLabel.text = "\(R.string.localizable.rendererTitle())\nSoftware"
            self.game?.updateExtra(key: ExtraKey.psxRenderer.rawValue, value: false)
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.rendererDesc(), children: actions))
        return view
    }()
    
    private lazy var psxRendererButton: SymbolButton = {
        let title = "\(R.string.localizable.rendererTitle())\n" + ((self.game?.getExtraBool(key: ExtraKey.psxRenderer.rawValue) ?? true) ? "Hardware" : "Software")
        let view = SymbolButton(image: R.image.customLightspectrumHorizontal()?.applySymbolConfig(color: Constants.Color.LabelPrimary), title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.psxRendererContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var startGameButton: SymbolButton = {
        let view = SymbolButton(symbol: .playFill, symbolColor: Constants.Color.LabelPrimary.forceStyle(.dark))
        view.backgroundColor = Constants.Color.Main
        view.layerCornerRadius = Constants.Size.ItemHeightMid/2
        view.addTapGesture { [weak self] gesture in
            guard let self = self, let game = self.game else { return }
            PlayViewController.startGame(game: game)
        }
        view.addLongPressGesture(handler: { [weak self] gesture in
            guard let self = self, let game = self.game else { return }
            switch gesture.state {
            case .began:
                UIDevice.generateHaptic()
                UIView.makeAlert(title: R.string.localizable.safeMode(),
                                 detail: R.string.localizable.safeModeDesc(),
                                 confirmTitle: R.string.localizable.confirmTitle(),
                                 confirmAction: {
                    game.safeMode = true
                    PlayViewController.startGame(game: game)
                })
            default:
                break
            }
        })
        
        // 无障碍配置
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.startGameTitle()
        view.accessibilityTraits = .button
        
        return view
    }()
    
    private lazy var dcCoreContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: "JITLess Ver: Default") { [weak self] _ in
            guard let self = self else { return }
            self.dcCoreButton.titleLabel.text = "JITLess Ver: Default"
            if let game {
                Game.change { _ in
                    game.defaultCore = 0
                }
            }
        }))
        actions.append((UIAction(title: "JITLess Ver: WinCE") { [weak self] _ in
            guard let self = self else { return }
            self.dcCoreButton.titleLabel.text = "JITLess Ver: WinCE"
            if let game {
                Game.change { _ in
                    game.defaultCore = 1
                }
            }
        }))
        actions.append((UIAction(title: "JITLess Ver: Fuse") { [weak self] _ in
            guard let self = self else { return }
            self.dcCoreButton.titleLabel.text = "JITLess Ver: Fuse"
            if let game {
                Game.change { _ in
                    game.defaultCore = 2
                }
            }
        }))
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.dcjitLessVer(), children: actions))
        return view
    }()
    
    private lazy var dcCoreButton: SymbolButton = {
        var ver = "Default"
        let defaultCore = (game?.defaultCore ?? 0)
        if defaultCore == 1 {
            ver = "WinCE"
        } else if defaultCore == 2 {
            ver = "Fuse"
        }
        let view = SymbolButton(symbol: .boltSlash, title: "JITLess Ver: \(ver)", horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.dcCoreContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = "JITLess Ver: \(ver)"
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var tvStandardMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: "NTSC (59.94HZ)") { [weak self] _ in
            guard let self = self else { return }
            self.tVStandardButton.titleLabel.text = "NTSC (59.94HZ)"
            if let game {
                game.updateExtra(key: ExtraKey.tvStandard.rawValue, value: 0)
            }
        }))
        actions.append((UIAction(title: "PAL (50HZ)") { [weak self] _ in
            guard let self = self else { return }
            self.tVStandardButton.titleLabel.text = "PAL (50HZ)"
            if let game {
                game.updateExtra(key: ExtraKey.tvStandard.rawValue, value: 1)
            }
        }))
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.tvStandard(), children: actions))
        return view
    }()
    
    private lazy var tVStandardButton: SymbolButton = {
        let standard = (game?.getExtraInt(key: ExtraKey.tvStandard.rawValue) ?? 0) == 0 ? "NTSC (59.94HZ)" : "PAL (50HZ)"
        let view = SymbolButton(symbol: .tv, title: standard, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.tvStandardMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = standard
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var snesVRAMMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.enableTitle()) { [weak self] _ in
            guard let self = self else { return }
            self.snesVRAMButton.titleLabel.text = "VRAM: " + R.string.localizable.enableTitle()
            if let game {
                game.updateExtra(key: ExtraKey.snesVRAM.rawValue, value: true)
            }
        }))
        actions.append((UIAction(title: R.string.localizable.disableTitle()) { [weak self] _ in
            guard let self = self else { return }
            self.snesVRAMButton.titleLabel.text = "VRAM: " + R.string.localizable.disableTitle()
            if let game {
                game.updateExtra(key: ExtraKey.snesVRAM.rawValue, value: false)
            }
        }))
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.snesvramEnable(), children: actions))
        return view
    }()
    
    private lazy var snesVRAMButton: SymbolButton = {
        let title = "VRAM: " + ((game?.getExtraBool(key: ExtraKey.snesVRAM.rawValue) ?? false) ? R.string.localizable.enableTitle() : R.string.localizable.disableTitle())
        let view = SymbolButton(symbol: .memorychip, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.snesVRAMMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var pspRendererContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append(UIAction(title: "Automatic") { [weak self] _ in
            guard let self = self else { return }
            self.pspRendererButton.titleLabel.text = "\(R.string.localizable.rendererTitle())\nAutomatic"
            self.game?.updateExtra(key: ExtraKey.pspRenderer.rawValue, value: 0)
        })
        actions.append(UIAction(title: "OpenGL") { [weak self] _ in
            guard let self = self else { return }
            self.pspRendererButton.titleLabel.text = "\(R.string.localizable.rendererTitle())\nOpenGL"
            self.game?.updateExtra(key: ExtraKey.pspRenderer.rawValue, value: 1)
        })
        actions.append(UIAction(title: "Vulkan") { [weak self] _ in
            guard let self = self else { return }
            self.pspRendererButton.titleLabel.text = "\(R.string.localizable.rendererTitle())\nVulkan"
            self.game?.updateExtra(key: ExtraKey.pspRenderer.rawValue, value: 2)
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(children: actions))
        return view
    }()
    
    private lazy var pspRendererButton: SymbolButton = {
        let type = (self.game?.getExtraInt(key: ExtraKey.pspRenderer.rawValue) ?? 0)
        var renderType = "Automatic"
        if type == 1 {
            renderType = "OpenGL"
        } else if type == 2 {
            renderType = "Vulkan"
        }
        let title = "\(R.string.localizable.rendererTitle())\n" + renderType
        let view = SymbolButton(image: R.image.customLightspectrumHorizontal()?.applySymbolConfig(color: Constants.Color.LabelPrimary), title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.pspRendererContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var pspTextureContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append(UIAction(title: R.string.localizable.on()) { [weak self] _ in
            guard let self = self else { return }
            self.pspTextureButton.titleLabel.text = "\(R.string.localizable.texture()) \(R.string.localizable.on())"
            self.game?.updateExtra(key: ExtraKey.pspTexture.rawValue, value: true)
        })
        actions.append(UIAction(title: R.string.localizable.off()) { [weak self] _ in
            guard let self = self else { return }
            self.pspTextureButton.titleLabel.text = "\(R.string.localizable.texture()) \(R.string.localizable.off())"
            self.game?.updateExtra(key: ExtraKey.pspTexture.rawValue, value: false)
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.textureReplacement(), children: actions))
        return view
    }()
    
    private lazy var pspTextureButton: SymbolButton = {
        let title = R.string.localizable.texture() + " " + ((self.game?.getExtraBool(key: ExtraKey.pspTexture.rawValue) ?? false) ? "\(R.string.localizable.on())" : "\(R.string.localizable.off())")
        let view = SymbolButton(symbol: .aqiMedium, title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.pspTextureContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var j2meSettingButton: SymbolButton = {
        let title = GameType.j2me.coreConfigTitle
        let view = SymbolButton(image: GameType.j2me.coreConfigIcon?.applySymbolConfig(size: 30), title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if let game = self.game {
                J2MESettingView.show(game: game)
            }
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var dosSettingButton: SymbolButton = {
        let title = GameType.dos.coreConfigTitle
        let view = SymbolButton(image: GameType.dos.coreConfigIcon?.applySymbolConfig(size: 24), title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            if let game = self.game {
                CoreConfigsView.show(game: game)
            }
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    var didSegmentChange: ((_ index: Int)->Void)?
    lazy var segmentView: BetterSegmentedControl = {
        let titles = [R.string.localizable.readySegmentManualSave(), R.string.localizable.readySegmentAutoSave()]
        let segments = LabelSegment.segments(withTitles: titles,
                                             normalFont: Constants.Font.body(),
                                             normalTextColor: Constants.Color.LabelSecondary,
                                            selectedTextColor: Constants.Color.LabelPrimary)
        let options: [BetterSegmentedControl.Option] = [
            .backgroundColor(Constants.Color.SegmentBackground),
            .indicatorViewInset(5),
            .indicatorViewBackgroundColor(Constants.Color.SegmentHighlight),
            .cornerRadius(16)
        ]
        let view = BetterSegmentedControl(frame: .zero,
                                          segments: segments,
                                          options: options)
        
        view.on(.valueChanged) { [weak self] sender, forEvent in
            guard let self = self, let index = (sender as? BetterSegmentedControl)?.index else { return }
            UIDevice.generateHaptic()
            self.didSegmentChange?(index)
        }
        return view
    }()
    
    private class GameInfoSymbolButton: SymbolButton {}
    var didDeleteSaveState: (()->Void)?
    private lazy var deleteSaveStateButton: GameInfoSymbolButton = {
        let view = GameInfoSymbolButton(image: .symbolImage(.trash).applySymbolConfig(color: Constants.Color.Red))
        view.layerCornerRadius = Constants.Size.CornerRadiusMid
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            self.didDeleteSaveState?()
        }
        
        // 无障碍配置
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.deleteGameGameStateAlertTitle()
        view.accessibilityTraits = .button

        return view
    }()

    private class RommSyncSymbolButton: SymbolButton {}
    var didSyncSaveState: (()->Void)?
    private lazy var syncSaveStateButton: RommSyncSymbolButton = {
        let view = RommSyncSymbolButton(image: .symbolImage(.arrowTriangle2Circlepath).applySymbolConfig(color: Constants.Color.Main))
        view.layerCornerRadius = Constants.Size.CornerRadiusMid
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            self.didSyncSaveState?()
        }
        view.isHidden = !RommSyncManager.shared.isConfigured()

        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.rommSyncTitle()
        view.accessibilityTraits = .button

        return view
    }()

    private lazy var emulationAccuracyContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append(UIAction(title: "HLE") { [weak self] _ in
            guard let self = self else { return }
            self.emulationAccuracyButton.titleLabel.text = "\(R.string.localizable.emulationAccuracy()): HLE"
            game?.updateExtra(key: ExtraKey.emulationAccuracy.rawValue, value: 0)
        })
        actions.append(UIAction(title: "LLE") { [weak self] _ in
            guard let self = self else { return }
            self.emulationAccuracyButton.titleLabel.text = "\(R.string.localizable.emulationAccuracy()): LLE"
            game?.updateExtra(key: ExtraKey.emulationAccuracy.rawValue, value: 1)
        })
        let view = ContextMenuButton(image: nil, menu: UIMenu(title: R.string.localizable.emulationAccuracyDesc(), children: actions))
        return view
    }()
    
    private lazy var emulationAccuracyButton: SymbolButton = {
        let title =  "\(R.string.localizable.emulationAccuracy()): \(((self.game?.getExtraInt(key: ExtraKey.emulationAccuracy.rawValue) ?? 0) == 0) ? "HLE" : "LLE")"
        let view = SymbolButton(image: UIImage(symbol: .timelapse, color: Constants.Color.LabelPrimary), title: title, horizontalContian: true)
        view.titleLabel.numberOfLines = 0
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.emulationAccuracyContextMenuButton.triggerTapGesture()
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = title
        view.accessibilityTraits = .button
        return view
    }()
    
    var hasSetupViews: Bool = false
    
    var game: Game? = nil {
        didSet {
            syncSaveStateButton.isHidden = !RommSyncManager.shared.isConfigured()
            updateSaveStateLayout()
            if let game = game {
                titleTextField.text = game.aliasName ?? game.name
                if let timeAgo = game.latestPlayDate?.timeAgo() {
                    subtitleLabel.text = R.string.localizable.readyGameInfoSubTitle(timeAgo, Date.timeDuration(milliseconds: Int(game.totalPlayDuration)))
                } else {
                    subtitleLabel.text = R.string.localizable.readyGameInfoNeverPlayed()
                }
                
                if !hasSetupViews {
                    if game.gameType == ._3ds {
                        if game.defaultCore == 0 {
                            updateCitra3DSFunctionButton()
                        } else {
                            updateAzahar3DSFunctionButton()
                        }
                    } else if game.gameType == .psp {
                        updatePSPFunctionButton()
                    } else if game.gameType == .ss {
                        updateSaturnFunctionButton()
                    } else if game.gameType == .ds {
                        updateDSFunctionButton()
                    } else if game.gameType == .n64 {
                        updateN64FunctionButton()
                    } else if game.gameType == .vb || game.gameType == .pm || game.isJGenesisCore {
                        hideDefaultFunctionButtons([cheatCodeButton])
                    } else if game.gameType == .ps1 {
                        updatePS1FunctionButton()
                    } else if game.gameType == .dc {
                        updateDCFunctionButton()
                    } else if game.isClownMDEmuCore {
                        updateClownMDEmuFunctionButton()
                    } else if game.gameType == .snes {
                        updateSNESFunctionButton()
                    } else if game.gameType == .ns || game.gameType == .xbox360 {
                        hideDefaultFunctionButtons([retroButton, skinButton, cheatCodeButton])
                    } else if game.isAtari {
                        if game.gameType == .a5200 {
                            hideDefaultFunctionButtons([retroButton, cheatCodeButton])
                        } else {
                            hideDefaultFunctionButtons([cheatCodeButton])
                        }
                    } else if game.isJ2MECore {
                        updateJ2MEFunctionButton()
                    } else if game.gameType == .doom || (game.gameType == .arcade && game.defaultCore == 0) {
                        hideDefaultFunctionButtons([retroButton])
                    } else if game.gameType == .dos {
                        updateDOSFunctionButton()
                    }
                    addManualsButton()
                    hasSetupViews = true
                }
            }
        }
    }
    
    func resetForGamingUsing() {
        subviews.forEach {
            if $0 is BetterSegmentedControl {
                $0.snp.remakeConstraints { make in
                    make.top.equalToSuperview().offset(10)
                    make.height.equalTo(50)
                    make.leading.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
                    make.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
                }
            } else if $0 is GameInfoSymbolButton {
                $0.snp.remakeConstraints { make in
                    make.centerY.equalTo(segmentView)
                    make.size.equalTo(Constants.Size.ItemHeightMid)
                    make.leading.equalTo(segmentView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
                }
            } else {
                $0.isHidden = true
            }
        }
        backgroundBlurView.isHidden = false
        backgroundBlurView.alpha = 1
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(titleTextField)
        titleTextField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceHuge)
            make.top.equalToSuperview()
        }
        
        addSubview(editTitleButton)
        editTitleButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.top.equalTo(titleTextField)
            make.leading.equalTo(titleTextField.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.trailing.lessThanOrEqualToSuperview().offset(-Constants.Size.ContentSpaceMax)
        }
        
        addSubview(subtitleIcon)
        subtitleIcon.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeTiny)
            make.leading.equalTo(titleTextField)
            make.top.equalTo(titleTextField.snp.bottom).offset(Constants.Size.ContentSpaceUltraTiny)
        }
        
        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(subtitleIcon)
            make.leading.equalTo(subtitleIcon.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.trailing.lessThanOrEqualToSuperview().offset(-Constants.Size.ContentSpaceMax)
        }
        
        addSubview(functionButtonContainerView)
        functionButtonContainerView.snp.makeConstraints { make in
            make.top.equalTo(subtitleIcon.snp.bottom).offset(Constants.Size.ContentSpaceMid)
            make.leading.equalTo(titleTextField)
            make.height.equalTo(Constants.Size.IconSizeHuge.height)
        }
        
        functionButtonContainerView.addSubview(retroButton)
        retroButton.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.IconSizeHuge)
        }
        
        functionButtonContainerView.addSubview(skinButton)
        skinButton.snp.makeConstraints { make in
            make.leading.equalTo(retroButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.IconSizeHuge)
        }
        
        functionButtonContainerView.addSubview(cheatCodeButton)
        cheatCodeButton.snp.makeConstraints { make in
            make.leading.equalTo(skinButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.IconSizeHuge)
        }
        
        addSubview(startGameButton)
        startGameButton.snp.makeConstraints { make in
            make.centerY.equalTo(functionButtonContainerView)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
            make.size.equalTo(Constants.Size.ItemHeightMid)
            make.leading.equalTo(functionButtonContainerView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
        }
        
        addSubview(segmentView)

        addSubview(deleteSaveStateButton)
        deleteSaveStateButton.snp.makeConstraints { make in
            make.centerY.equalTo(segmentView)
            make.size.equalTo(Constants.Size.ItemHeightMid)
            make.trailing.equalTo(startGameButton)
        }

        addSubview(syncSaveStateButton)
        syncSaveStateButton.snp.makeConstraints { make in
            make.centerY.equalTo(segmentView)
            make.size.equalTo(Constants.Size.ItemHeightMid)
            make.trailing.equalTo(deleteSaveStateButton.snp.leading).offset(-Constants.Size.ContentSpaceMin)
        }

        updateSaveStateLayout()
    }
    /// Update the layout if we do not have RomM enabled. 
    private func updateSaveStateLayout() {
        let trailingButton: UIView = syncSaveStateButton.isHidden ? deleteSaveStateButton : syncSaveStateButton
        segmentView.snp.remakeConstraints { make in
            make.top.equalTo(functionButtonContainerView.snp.bottom).offset(29)
            make.height.equalTo(50)
            make.leading.equalTo(functionButtonContainerView)
            make.bottom.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
            make.trailing.equalTo(trailingButton.snp.leading).offset(-Constants.Size.ContentSpaceMin)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateCitra3DSFunctionButton() {
        hideDefaultFunctionButtons([retroButton])
        threeDSAdvancedModeButton.removeFromSuperview()
        jitContextMenuButton.removeFromSuperview()
        jitButton.removeFromSuperview()
        threeDSModecontextMenuButton.removeFromSuperview()
        threeDSModeButton.removeFromSuperview()
        shaderContextMenuButton.removeFromSuperview()
        shaderButton.removeFromSuperview()
        languageContextMenuButton.removeFromSuperview()
        languageButton.removeFromSuperview()
        rightEyeRenderMenuButton.removeFromSuperview()
        rightEyeRenderButton.removeFromSuperview()
        threeDSAdvancedSettingButton.removeFromSuperview()
        manualButton.removeFromSuperview()
        if let lastView = functionButtonContainerView.subviews.last {
            functionButtonContainerView.addSubview(threeDSAdvancedModeButton)
            threeDSAdvancedModeButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            
            
            if Settings.defalut.threeDSAdvancedSettingMode {
                functionButtonContainerView.addSubview(threeDSAdvancedSettingButton)
                threeDSAdvancedSettingButton.snp.makeConstraints { make in
                    make.leading.equalTo(threeDSAdvancedModeButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                    make.trailing.equalToSuperview()
                }
            } else {
                //JIT按钮
                functionButtonContainerView.addSubview(jitContextMenuButton)
                functionButtonContainerView.addSubview(jitButton)
                jitButton.snp.makeConstraints { make in
                    make.leading.equalTo(threeDSAdvancedModeButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                jitContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(jitButton)
                }
                
                //模式选择按钮
                functionButtonContainerView.addSubview(threeDSModecontextMenuButton)
                functionButtonContainerView.addSubview(threeDSModeButton)
                threeDSModeButton.snp.makeConstraints { make in
                    make.leading.equalTo(jitButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                threeDSModecontextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(threeDSModeButton)
                }
                
                //着色器选择按钮
                functionButtonContainerView.addSubview(shaderContextMenuButton)
                functionButtonContainerView.addSubview(shaderButton)
                shaderButton.snp.makeConstraints { make in
                    make.leading.equalTo(threeDSModeButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                shaderContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(shaderButton)
                }
                
                //语言选择按钮
                functionButtonContainerView.addSubview(languageContextMenuButton)
                functionButtonContainerView.addSubview(languageButton)
                languageButton.snp.makeConstraints { make in
                    make.leading.equalTo(shaderButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                languageContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(languageButton)
                }
                
                //右眼渲染按钮
                functionButtonContainerView.addSubview(rightEyeRenderMenuButton)
                functionButtonContainerView.addSubview(rightEyeRenderButton)
                rightEyeRenderButton.snp.makeConstraints { make in
                    make.leading.equalTo(languageButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                    make.trailing.equalToSuperview()
                }
                rightEyeRenderMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(rightEyeRenderButton)
                }
            }
        }
    }
    
    private func updateAzahar3DSFunctionButton() {
        hideDefaultFunctionButtons([retroButton])
        emulationAccuracyContextMenuButton.removeFromSuperview()
        emulationAccuracyButton.removeFromSuperview()
        if let lastView = functionButtonContainerView.subviews.last {
            if let game, !game.isArticBaseHomeMenu {
                functionButtonContainerView.addSubview(emulationAccuracyContextMenuButton)
                functionButtonContainerView.addSubview(emulationAccuracyButton)
                emulationAccuracyButton.snp.makeConstraints { make in
                    make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                emulationAccuracyContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(emulationAccuracyButton)
                }
            }
            
            functionButtonContainerView.addSubview(threeDSAdvancedSettingButton)
            threeDSAdvancedSettingButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
        }
    }
    
    private func updatePSPFunctionButton() {
        manualButton.removeFromSuperview()
        languageContextMenuButton.removeFromSuperview()
        languageButton.removeFromSuperview()
        pspRendererContextMenuButton.removeFromSuperview()
        pspRendererButton.removeFromSuperview()
        pspTextureContextMenuButton.removeFromSuperview()
        pspTextureButton.removeFromSuperview()
        jitContextMenuButton.removeFromSuperview()
        jitButton.removeFromSuperview()
        jitTypeContextMenuButton.removeFromSuperview()
        jitTypeButton.removeFromSuperview()
        
        if let lastView = functionButtonContainerView.subviews.last {
            //语言选择按钮
            functionButtonContainerView.addSubview(languageContextMenuButton)
            functionButtonContainerView.addSubview(languageButton)
            languageButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            languageContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(languageButton)
            }
            
            functionButtonContainerView.addSubview(pspRendererContextMenuButton)
            functionButtonContainerView.addSubview(pspRendererButton)
            pspRendererButton.snp.makeConstraints { make in
                make.leading.equalTo(languageButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            pspRendererContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(pspRendererButton)
            }
            
            functionButtonContainerView.addSubview(pspTextureContextMenuButton)
            functionButtonContainerView.addSubview(pspTextureButton)
            pspTextureButton.snp.makeConstraints { make in
                make.leading.equalTo(pspRendererButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            pspTextureContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(pspTextureButton)
            }
            
            //jit
            functionButtonContainerView.addSubview(jitContextMenuButton)
            functionButtonContainerView.addSubview(jitButton)
            jitButton.snp.makeConstraints { make in
                make.leading.equalTo(pspTextureButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            jitContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(jitButton)
            }
            
            //jitType
            functionButtonContainerView.addSubview(jitTypeContextMenuButton)
            functionButtonContainerView.addSubview(jitTypeButton)
            jitTypeButton.snp.makeConstraints { make in
                make.leading.equalTo(jitButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
            jitTypeContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(jitTypeButton)
            }
            
        }
    }
    
    private func updateSaturnFunctionButton() {
        manualButton.removeFromSuperview()
        languageContextMenuButton.removeFromSuperview()
        languageButton.removeFromSuperview()
        guard let game else { return }
        if game.defaultCore == 0 {
            cheatCodeButton.removeFromSuperview()
        }
        if game.defaultCore == 0, let lastView = functionButtonContainerView.subviews.last {
            //语言选择按钮
            functionButtonContainerView.addSubview(languageContextMenuButton)
            functionButtonContainerView.addSubview(languageButton)
            languageButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
            languageContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(languageButton)
            }
        }
    }
    
    private func updateDSFunctionButton() {
        manualButton.removeFromSuperview()
        languageContextMenuButton.removeFromSuperview()
        languageButton.removeFromSuperview()
        microphoneContextMenuButton.removeFromSuperview()
        microphoneButton.removeFromSuperview()
        ndsSystemTypeContextMenuButton.removeFromSuperview()
        ndsSystemTypeButton.removeFromSuperview()
        gbaSlotContextMenuButton.removeFromSuperview()
        gbaSlotButton.removeFromSuperview()
        jitContextMenuButton.removeFromSuperview()
        jitButton.removeFromSuperview()
        let isMelonDS = (game?.defaultCore ?? 0) == 0
        if let lastView = functionButtonContainerView.subviews.last {
            //语言选择按钮
            functionButtonContainerView.addSubview(languageContextMenuButton)
            functionButtonContainerView.addSubview(languageButton)
            languageButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            languageContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(languageButton)
            }
            
            //麦克风
            functionButtonContainerView.addSubview(microphoneContextMenuButton)
            functionButtonContainerView.addSubview(microphoneButton)
            microphoneButton.snp.makeConstraints { make in
                make.leading.equalTo(languageButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            microphoneContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(microphoneButton)
            }
            
            if isMelonDS {
                var enableGBASlot = true
                if let game, let mode = game.getExtraString(key: ExtraKey.ndsSystemMode.rawValue), mode == "DSi" {
                    enableGBASlot = false
                }
                
                //系统类型
                functionButtonContainerView.addSubview(ndsSystemTypeContextMenuButton)
                functionButtonContainerView.addSubview(ndsSystemTypeButton)
                ndsSystemTypeButton.snp.makeConstraints { make in
                    make.leading.equalTo(microphoneButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                    if !enableGBASlot {
                        make.trailing.equalToSuperview()
                    }
                }
                ndsSystemTypeContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(ndsSystemTypeButton)
                }
                
                if enableGBASlot {
                    //GBA Slot
                    functionButtonContainerView.addSubview(gbaSlotContextMenuButton)
                    functionButtonContainerView.addSubview(gbaSlotButton)
                    gbaSlotButton.snp.makeConstraints { make in
                        make.leading.equalTo(ndsSystemTypeButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                        make.centerY.equalToSuperview()
                        make.size.equalTo(Constants.Size.IconSizeHuge)
                    }
                    gbaSlotContextMenuButton.snp.makeConstraints { make in
                        make.edges.equalTo(gbaSlotButton)
                    }
                }
                
                //jit
                functionButtonContainerView.addSubview(jitContextMenuButton)
                functionButtonContainerView.addSubview(jitButton)
                jitButton.snp.makeConstraints { make in
                    make.leading.equalTo((enableGBASlot ? gbaSlotButton : ndsSystemTypeButton).snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                    make.trailing.equalToSuperview()
                }
                jitContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(jitButton)
                }
            }
        }
    }
    
    private func updateN64FunctionButton() {
        manualButton.removeFromSuperview()
        transferPakContextMenuButton.removeFromSuperview()
        transferPakButton.removeFromSuperview()
        rdpPluginContextMenuButton.removeFromSuperview()
        rdpPluginButton.removeFromSuperview()
        jitContextMenuButton.removeFromSuperview()
        jitButton.removeFromSuperview()
        if let lastView = functionButtonContainerView.subviews.last {
            //transferPak
            functionButtonContainerView.addSubview(transferPakContextMenuButton)
            functionButtonContainerView.addSubview(transferPakButton)
            transferPakButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            transferPakContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(transferPakButton)
            }
            
            //RDP
            functionButtonContainerView.addSubview(rdpPluginContextMenuButton)
            functionButtonContainerView.addSubview(rdpPluginButton)
            rdpPluginButton.snp.makeConstraints { make in
                make.leading.equalTo(transferPakButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            rdpPluginContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(rdpPluginButton)
            }
            
            //jit
            functionButtonContainerView.addSubview(jitContextMenuButton)
            functionButtonContainerView.addSubview(jitButton)
            jitButton.snp.makeConstraints { make in
                make.leading.equalTo(rdpPluginButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
            jitContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(jitButton)
            }
        }
    }
    
    private func updatePS1FunctionButton() {
        var isPCSXReArmed = false
        if let game, game.defaultCore == 1 {
            isPCSXReArmed = true
        }
        manualButton.removeFromSuperview()
        psxImportSbiButton.removeFromSuperview()
        psxModeContextMenuButton.removeFromSuperview()
        psxModeButton.removeFromSuperview()
        psxRendererContextMenuButton.removeFromSuperview()
        psxRendererButton.removeFromSuperview()
        jitContextMenuButton.removeFromSuperview()
        jitButton.removeFromSuperview()
        biosSelectionContextMenuButton.removeFromSuperview()
        biosSelectionButton.removeFromSuperview()
        
        if let lastView = functionButtonContainerView.subviews.last {
            //导入sbi文件
            functionButtonContainerView.addSubview(psxImportSbiButton)
            psxImportSbiButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                if isPCSXReArmed {
                    make.trailing.equalToSuperview()
                }
            }
            
            if !isPCSXReArmed {
                //手柄模式
                functionButtonContainerView.addSubview(psxModeContextMenuButton)
                functionButtonContainerView.addSubview(psxModeButton)
                psxModeButton.snp.makeConstraints { make in
                    make.leading.equalTo(psxImportSbiButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                psxModeContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(psxModeButton)
                }
                
                //Renderer
                functionButtonContainerView.addSubview(psxRendererContextMenuButton)
                functionButtonContainerView.addSubview(psxRendererButton)
                psxRendererButton.snp.makeConstraints { make in
                    make.leading.equalTo(psxModeButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                psxRendererContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(psxRendererButton)
                }
                
                //jit
                functionButtonContainerView.addSubview(jitContextMenuButton)
                functionButtonContainerView.addSubview(jitButton)
                jitButton.snp.makeConstraints { make in
                    make.leading.equalTo(psxRendererButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                jitContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(jitButton)
                }
                
                //bios
                functionButtonContainerView.addSubview(biosSelectionContextMenuButton)
                functionButtonContainerView.addSubview(biosSelectionButton)
                biosSelectionButton.snp.makeConstraints { make in
                    make.leading.equalTo(psxRendererButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                    make.trailing.equalToSuperview()
                }
                biosSelectionContextMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(biosSelectionButton)
                }
            }
        }
    }
    
    private func updateDCFunctionButton() {
        cheatCodeButton.removeFromSuperview()
        manualButton.removeFromSuperview()
        jitContextMenuButton.removeFromSuperview()
        jitButton.removeFromSuperview()
        dcCoreContextMenuButton.removeFromSuperview()
        dcCoreButton.removeFromSuperview()
        languageContextMenuButton.removeFromSuperview()
        languageButton.removeFromSuperview()
        
        if let lastView = functionButtonContainerView.subviews.last {
            //jit
            functionButtonContainerView.addSubview(jitContextMenuButton)
            functionButtonContainerView.addSubview(jitButton)
            jitButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            jitContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(jitButton)
            }
            
            //jitless core ver
            functionButtonContainerView.addSubview(dcCoreContextMenuButton)
            functionButtonContainerView.addSubview(dcCoreButton)
            dcCoreButton.snp.makeConstraints { make in
                make.leading.equalTo(jitButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            dcCoreContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(dcCoreButton)
            }
            
            //语言选择按钮
            functionButtonContainerView.addSubview(languageContextMenuButton)
            functionButtonContainerView.addSubview(languageButton)
            languageButton.snp.makeConstraints { make in
                make.leading.equalTo(dcCoreButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
            languageContextMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(languageButton)
            }
        }
    }
    
    private func updateClownMDEmuFunctionButton() {
        manualButton.removeFromSuperview()
        tvStandardMenuButton.removeFromSuperview()
        tVStandardButton.removeFromSuperview()
        if let game, game.isClownMDEmuCore {
            cheatCodeButton.removeFromSuperview()
            if let lastView = functionButtonContainerView.subviews.last {
                //TV Standard
                functionButtonContainerView.addSubview(tvStandardMenuButton)
                functionButtonContainerView.addSubview(tVStandardButton)
                tVStandardButton.snp.makeConstraints { make in
                    make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeHuge)
                }
                tvStandardMenuButton.snp.makeConstraints { make in
                    make.edges.equalTo(tVStandardButton)
                }
            }
        }
    }
    
    private func updateSNESFunctionButton() {
        manualButton.removeFromSuperview()
        snesVRAMMenuButton.removeFromSuperview()
        snesVRAMButton.removeFromSuperview()
        if let lastView = functionButtonContainerView.subviews.last {
            //VRAM
            functionButtonContainerView.addSubview(snesVRAMMenuButton)
            functionButtonContainerView.addSubview(snesVRAMButton)
            snesVRAMButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
            snesVRAMMenuButton.snp.makeConstraints { make in
                make.edges.equalTo(snesVRAMButton)
            }
            
        }
    }
    
    private func updateJ2MEFunctionButton() {
        hideDefaultFunctionButtons([retroButton, cheatCodeButton])
        j2meSettingButton.removeFromSuperview()
        
        if let lastView = functionButtonContainerView.subviews.last {
            functionButtonContainerView.addSubview(j2meSettingButton)
            j2meSettingButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
        }
    }
    
    private func updateDOSFunctionButton() {
        hideDefaultFunctionButtons([retroButton, cheatCodeButton])
        dosSettingButton.removeFromSuperview()
        jitContextMenuButton.removeFromSuperview()
        jitButton.removeFromSuperview()
        
        if let lastView = functionButtonContainerView.subviews.last {
            functionButtonContainerView.addSubview(dosSettingButton)
            dosSettingButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
        }
        
        //jit
        functionButtonContainerView.addSubview(jitContextMenuButton)
        functionButtonContainerView.addSubview(jitButton)
        jitButton.snp.makeConstraints { make in
            make.leading.equalTo(dosSettingButton.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.IconSizeHuge)
            make.trailing.equalToSuperview()
        }
        jitContextMenuButton.snp.makeConstraints { make in
            make.edges.equalTo(jitButton)
        }
    }
    
    private func hideDefaultFunctionButtons(_ buttons: [UIView]) {
        guard buttons.count > 0 else { return }
        var removeButtons = [UIView]()
        functionButtonContainerView.subviews.forEach { button in
            if buttons.contains(where: { $0 == button }) {
                removeButtons.append(button)
            }
        }
        if removeButtons.count > 0 {
            removeButtons.forEach { $0.removeFromSuperview() }
        }
        
        let visableSubViews = functionButtonContainerView.subviews.filter({ !$0.isKind(of: ContextMenuButton.self) })
        for (index, subView) in visableSubViews.enumerated() {
            
            subView.snp.remakeConstraints { make in
                if index == 0 {
                    make.leading.equalToSuperview()
                } else {
                    make.leading.equalTo(visableSubViews[index-1].snp.trailing).offset(Constants.Size.ContentSpaceMin)
                }
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
        }
    }
    
    private func addManualsButton() {
        //添加游戏手册按钮
        manualButton.removeFromSuperview()
        let subviews = functionButtonContainerView.subviews.filter({ $0 is SymbolButton })
        functionButtonContainerView.addSubview(manualButton)
        if subviews.count == 0 {
            manualButton.snp.makeConstraints { make in
                make.leading.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
        } else if subviews.count == 1 {
            manualButton.snp.makeConstraints { make in
                make.leading.equalTo(subviews[0].snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
        } else {
            let lastTwoViews = subviews.suffix(2)
            let lastTwoView = Array(lastTwoViews)[0]
            let lastView = Array(lastTwoViews)[1]
            lastView.snp.remakeConstraints { make in
                make.leading.equalTo(lastTwoView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
            }
            manualButton.snp.makeConstraints { make in
                make.leading.equalTo(lastView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.IconSizeHuge)
                make.trailing.equalToSuperview()
            }
        }
    }
}
