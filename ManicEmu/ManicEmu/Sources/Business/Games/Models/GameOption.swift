//
//  GameOption.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/28.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import RealmSwift

enum GameOption: Int, CaseIterable {
    case rename,
         cover,
         skins,
         stateList,
         importSave,
         shareSave,
         platformChange,
         switchCore,
         changeCategory,
         genHomeMenu,
         copyLink,
         shareRom,
         delete,
         retroAchievements,
         cheatCode,
         manual,
         language,
         jit,
         citraAdvanceToggle,
         citraMode,
         citraShader,
         citraRightEyeRender,
         azaharEmulationAccuracy,
         pspJitType,//deprecated
         pspRenderer,
         pspTexture,
         ps1Bios,
         ps1ControllerMode,
         ps1Sbi,
         ps1Renderer,
         n64TransferPak,
         n64RdpPlugin,
         ndsSystemType,
         ndsGbaSlot,
         ndsMicrophone,
         clownMDTvStandard,
         snesVRAM,
         wswanRotation,
         coreSettings,
         saveState,
         quickLoadState,
         volume,
         fastForward,
         shaders,
         screenShot,
         haptic,
         airplay,
         controllerSetting,
         orientation,
         gameOptionSort,
         swapScreen,
         resolution,
         consoleHome,
         amiibo,
         hideControls,
         simBlowing,
         palette,
         swapDisk,
         airPlayScaling,
         airPlayLayout,
         triggerPro,
         screenScaling,
         insertDisc,
         reload,
         quit,
         gameShortcut,
         deadZone,
         rewind,
         netplay,
         symbianDevice,
         wiiControllerMode,
         coverScraping,
         dolphinCpuCore,
         slowMotion,
         ndsLidToggle,
         editLink,
         skinButtonBinding
        
    //When adding a new option, make sure to add it at the end; otherwise, it might affect the existing Prefference configurations
    
    var icon: ASIcon {
        switch self {
        case .rename:
                .symbolImage(R.image.renameRegular_iconSymbols())
        case .cover, .coverScraping:
                .symbolImage(R.image.cover_iconSymbols())
        case .skins:
                .symbolImage(R.image.skin_iconSymbols())
        case .stateList:
                .symbolImage(R.image.viewsavestates_iconSymbols())
        case .importSave:
                .symbolImage(R.image.importgamesave_iconSymbols())
        case .shareSave:
                .symbolImage(R.image.exportgamesave_iconSymbols())
        case .platformChange:
                .symbolImage(R.image.assignplatform_iconSymbols())
        case .switchCore:
                .symbolImage(R.image.core_iconSymbols())
        case .changeCategory:
                .symbolImage(R.image.category_iconSymbols())
        case .genHomeMenu:
                .symbolImage(R.image.home_iconSymbols())
        case .copyLink, .editLink:
                .symbolImage(R.image.link_iconSymbols())
        case .shareRom:
                .symbolImage(R.image.shareRa_iconSymbols())
        case .delete:
                .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red])
        case .retroAchievements:
                .symbolImage(R.image.retroachievements_iconSymbols())
        case .cheatCode:
                .symbolImage(R.image.cheat_iconSymbols())
        case .manual:
                .symbolImage(R.image.manuals_iconSymbols())
        case .language:
                .symbolImage(R.image.language_iconSymbols())
        case .jit:
                .symbolImage(R.image.jit_iconSymbols())
        case .citraAdvanceToggle:
                .symbolImage(R.image.advancesetting_iconSymbols())
        case .citraMode:
                .symbolImage(R.image.emulationaccuracy_iconSymbols())
        case .citraShader:
                .symbolImage(R.image.advance_shader_iconSymbols())
        case .citraRightEyeRender:
                .symbolImage(R.image.righteyerender_iconSymbols())
        case .azaharEmulationAccuracy:
                .symbolImage(R.image.emulationaccuracy_iconSymbols())
        case .pspJitType:
                .symbolImage(R.image.jit_typeSymbols())
        case .pspRenderer:
                .symbolImage(R.image.advance_shader_iconSymbols())
        case .pspTexture:
                .symbolImage(R.image.texture_iconSymbols())
        case .ps1Bios, .dolphinCpuCore:
                .symbolImage(R.image.bios_iconSymbols())
        case .ps1ControllerMode, .wiiControllerMode:
                .symbolImage(R.image.controller_iconSymbols())
        case .ps1Sbi:
                .symbolImage(R.image.sbi_cionSymbols())
        case .ps1Renderer:
                .symbolImage(R.image.advance_shader_iconSymbols())
        case .n64TransferPak:
                .symbolImage(R.image.transfer_iconSymbols())
        case .n64RdpPlugin:
                .symbolImage(R.image.render_iconSymbols())
        case .ndsSystemType:
                .symbolImage(R.image.systemtypeRegular_iconSymbols())
        case .ndsGbaSlot:
                .symbolImage(R.image.slot_iconSymbols())
        case .ndsMicrophone:
                .symbolImage(R.image.micro_iconSymbols())
        case .clownMDTvStandard:
                .symbolImage(R.image.tv_iconSymbols())
        case .snesVRAM:
                .symbolImage(R.image.vram_iconSymbols())
        case .coreSettings:
                .symbol(.atom)
        case .saveState:
                .symbolImage(R.image.savestate_iconSymbols())
        case .quickLoadState:
                .symbolImage(R.image.quickload_iconSymbols())
        case .volume:
                .symbolImage(R.image.volume_iconSymbols())
        case .fastForward:
                .symbolImage(R.image.fastforward_iconSymbols())
        case .shaders:
                .symbolImage(R.image.shaders_iconSymbols())
        case .screenShot:
                .symbolImage(R.image.screenshot_iconSymbols())
        case .haptic:
                .symbolImage(R.image.rumble_iconSymbols())
        case .airplay:
                .symbolImage(R.image.airplay_iconSymbols())
        case .controllerSetting:
                .symbolImage(R.image.controller_iconSymbols())
        case .orientation, .wswanRotation:
                .symbolImage(R.image.autorotate_iconSymbols())
        case .gameOptionSort:
                .symbolImage(R.image.systemtypeRegular_iconSymbols())
        case .swapScreen:
                .symbolImage(R.image.swapscreen_iconSymbols())
        case .resolution:
                .symbolImage(R.image.resolution_iconSymbols())
        case .consoleHome:
                .symbolImage(R.image.home_iconSymbols())
        case .amiibo:
                .symbolImage(R.image.amiibo_iconSymbols())
        case .hideControls:
                .symbolImage(R.image.hidecontrols_iconSymbols())
        case .simBlowing:
                .symbolImage(R.image.blowing_iconSymbols())
        case .palette:
                .symbolImage(R.image.themeRegular_iconSymbols())
        case .swapDisk:
                .symbolImage(R.image.disc_iconSymbols())
        case .airPlayScaling:
                .symbolImage(R.image.proportions_iconSymbols())
        case .airPlayLayout:
                .symbolImage(R.image.layout_iconSymbols())
        case .triggerPro:
                .symbolImage(R.image.triggerpro_iconSymbols())
        case .screenScaling:
                .symbol(.arrowUpRightAndArrowDownLeftRectangle)
        case .insertDisc:
                .symbolImage(R.image.insertdisic_iconSymbols())
        case .reload:
                .symbolImage(R.image.refresh_iconSymbols())
        case .quit:
                .symbolImage(R.image.quit_iconSymbols(), colors: [R.Color.Red])
        case .gameShortcut:
                .symbol(.command)
        case .deadZone:
                .symbolImage(R.image.joycon_iconSymbols())
        case .rewind:
                .symbolImage(R.image.rewind_iconSymbols())
        case .netplay:
                .symbolImage(R.image.online_iconSymbols())
        case .symbianDevice:
                .symbol(.candybarphone)
        case .slowMotion:
                .symbol(.slowmo)
        case .ndsLidToggle:
                .symbol(.squareTophalfFilled)
        case .skinButtonBinding:
                .symbolImage(R.image.keyboard_iconSymbols())
        }
    }
    
    var title: String {
        switch self {
        case .rename:
            R.string.localizable.gamesRename()
        case .cover:
            R.string.localizable.gamesModifyCover()
        case .skins:
            R.string.localizable.gamesSpecifySkin()
        case .shareRom:
            R.string.localizable.gamesShareRom()
        case .stateList:
            R.string.localizable.gamesCheckSave()
        case .importSave:
            R.string.localizable.gamesImportSave()
        case .shareSave:
            R.string.localizable.gamesShareSave()
        case .delete:
            R.string.localizable.gamesDelete()
        case .platformChange:
            R.string.localizable.platformChange()
        case .switchCore:
            R.string.localizable.switchEmulationCore()
        case .changeCategory:
            R.string.localizable.changeCategory()
        case .genHomeMenu:
            R.string.localizable.generateHomeMenu()
        case .copyLink:
            R.string.localizable.copyLaunchLinkTitle()
        case .editLink:
            R.string.localizable.editLink()
        case .retroAchievements:
            "RetroAchievements"
        case .cheatCode:
            R.string.localizable.gamesCheatCode()
        case .manual:
            R.string.localizable.gameplayManuals()
        case .language:
            R.string.localizable.languageTitle()
        case .jit:
            "JIT"
        case .citraAdvanceToggle:
            R.string.localizable.threeDSAdvanceSettingTitle()
        case .citraMode:
            R.string.localizable.threeDSPresetMode()
        case .citraShader:
            R.string.localizable.shaderModeTitle()
        case .citraRightEyeRender:
            R.string.localizable.renderRightEyeTitle()
        case .azaharEmulationAccuracy:
            R.string.localizable.emulationAccuracy()
        case .pspJitType:
            ""
        case .pspRenderer:
            R.string.localizable.rendererTitle()
        case .pspTexture:
            R.string.localizable.texture()
        case .ps1Bios:
            "BIOS"
        case .ps1ControllerMode, .wiiControllerMode:
            R.string.localizable.psxControllerMode()
        case .ps1Sbi:
            R.string.localizable.sbiImport()
        case .ps1Renderer:
            R.string.localizable.rendererTitle()
        case .n64TransferPak:
            "Transfer Pak"
        case .n64RdpPlugin:
            R.string.localizable.n64RdpPlugin()
        case .ndsSystemType:
            R.string.localizable.ndsSystemTypeTitle()
        case .ndsGbaSlot:
            R.string.localizable.gbaSlot()
        case .ndsMicrophone:
            R.string.localizable.microphone()
        case .clownMDTvStandard:
            R.string.localizable.mdtvStandard()
        case .snesVRAM:
            "VRAM"
        case .coreSettings:
            R.string.localizable.coreSettings()
        case .saveState:
            R.string.localizable.gameSettingSaveState()
        case .quickLoadState:
            R.string.localizable.gameSettingQuickLoadState()
        case .volume:
            R.string.localizable.gameSettingVolume()
        case .fastForward:
            R.string.localizable.fastForward()
        case .shaders:
            R.string.localizable.shaders()
        case .screenShot:
            R.string.localizable.gameSettingScreenShot()
        case .haptic:
            R.string.localizable.haptics()
        case .airplay:
            R.string.localizable.gameSettingAirplay()
        case .controllerSetting:
            R.string.localizable.gameSettingControllerSetting()
        case .orientation:
            R.string.localizable.orientation()
        case .gameOptionSort:
            R.string.localizable.gameSettingFunctionSort()
        case .swapScreen:
            R.string.localizable.gameSettingSwapScreen()
        case .resolution:
            R.string.localizable.resolution()
        case .consoleHome:
            R.string.localizable.consoleHomeTitle()
        case .amiibo:
            R.string.localizable.amiiboTitle()
        case .hideControls:
            R.string.localizable.hideControlsTitle()
        case .simBlowing:
            R.string.localizable.simulateBlowingTitle()
        case .palette:
            R.string.localizable.paletteTitle()
        case .swapDisk:
            R.string.localizable.swapDisk()
        case .airPlayScaling:
            R.string.localizable.airPlayScaling()
        case .airPlayLayout:
            R.string.localizable.airPlayLayout()
        case .triggerPro:
            "TriggerPro"
        case .screenScaling:
            R.string.localizable.screenScaling()
        case .insertDisc:
            R.string.localizable.insertDisc()
        case .reload:
            R.string.localizable.gameSettingReload()
        case .quit:
            R.string.localizable.gameSettingQuit()
        case .gameShortcut:
            R.string.localizable.gamePlayShortcut()
        case .deadZone:
            R.string.localizable.deadZoneSetting()
        case .rewind:
            R.string.localizable.rewind()
        case .netplay:
            R.string.localizable.netplay()
        case .symbianDevice:
            R.string.localizable.symbianFirmwareChoosing()
        case .coverScraping:
            R.string.localizable.coverScraping()
        case .dolphinCpuCore:
            R.string.localizable.cpuEmulationMethod()
        case .slowMotion:
            R.string.localizable.slowMotion()
        case .wswanRotation:
            R.string.localizable.wSwanRotateDisplay()
        case .ndsLidToggle:
            R.string.localizable.ndsLidToggle()
        case .skinButtonBinding:
            R.string.localizable.skinButtonBinding()
        }
    }
    
    var detail: String? {
        switch self {
        case .jit:
            return R.string.localizable.jitMenuDesc()
        case .citraShader:
            return R.string.localizable.shaderModeDesc()
        case .citraRightEyeRender:
            return R.string.localizable.renderRightEyeDesc()
        case .pspRenderer:
            return R.string.localizable.rendererDesc()
        case .pspTexture:
            return R.string.localizable.textureReplacement()
        case .ps1Sbi:
            return R.string.localizable.sbiImportDesc()
        case .ps1ControllerMode:
            return R.string.localizable.analogModeDesc()
        case .ps1Renderer:
            return R.string.localizable.rendererDesc()
        case .n64TransferPak:
            return R.string.localizable.transferPakDesc()
        case .n64RdpPlugin:
            return R.string.localizable.n64RDPDesc()
        case .snesVRAM:
            return R.string.localizable.snesvramEnable()
        case .azaharEmulationAccuracy:
            return R.string.localizable.emulationAccuracyDesc()
        case .deadZone:
            return R.string.localizable.deadZoneDesc()
        case .ndsMicrophone:
            return R.string.localizable.microphoneTips()
        case .ndsSystemType:
            return R.string.localizable.ndsSystemTypeDesc()
        case .ndsGbaSlot:
            return R.string.localizable.gbaSlotDesc()
        case .clownMDTvStandard:
            return R.string.localizable.tvStandard()
        case .rewind:
            return R.string.localizable.rewindDesc()
        case .airPlayLayout:
            return R.string.localizable.airPlayLayoutTips()
        case .language:
            return R.string.localizable.consoleLanguageDesc()
        default:
            return nil
        }
    }
    
    private static let disableOptionsForMultiGames: [Self] = [
        .rename,
        .cover,
        .editLink,
        .stateList,
        .importSave,
        .copyLink,
        .retroAchievements,
        .cheatCode,
        .manual,
        .ps1Sbi,
        .n64TransferPak,
        .ndsGbaSlot,
        .saveState,
        .quickLoadState,
        .screenShot,
        .reload,
        .quit,
        .consoleHome,
        .amiibo,
        .simBlowing,
        .swapDisk,
        .insertDisc,
        .ndsLidToggle
    ]
    
    static let defaultGroupAndSort: [[Self]] = [
        [
            .rename,
            .cover,
            .editLink,
            .coverScraping,
            .skins
        ],
        [
            .stateList,
            .importSave,
            .shareSave
        ],
        [
            .platformChange,
            .switchCore,
            .changeCategory,
            .genHomeMenu
        ],
        [
            .retroAchievements
        ],
        [
            .jit,
            .cheatCode,
            .manual,
            .language,
            .citraAdvanceToggle,
            .citraMode,
            .citraShader,
            .citraRightEyeRender,
            .azaharEmulationAccuracy,
            .pspJitType,
            .pspRenderer,
            .pspTexture,
            .ps1Bios,
            .ps1ControllerMode,
            .ps1Sbi,
            .ps1Renderer,
            .n64TransferPak,
            .n64RdpPlugin,
            .ndsSystemType,
            .ndsGbaSlot,
            .ndsMicrophone,
            .clownMDTvStandard,
            .snesVRAM,
            .symbianDevice,
            .wiiControllerMode,
            .dolphinCpuCore,
            .wswanRotation,
            .ndsLidToggle,
            .skinButtonBinding,
            .coreSettings,
        ],
        [
            .saveState,
            .quickLoadState,
            .volume,
            .fastForward,
            .slowMotion,
            .shaders,
            .screenShot,
            .haptic,
            .airplay,
            .controllerSetting,
            .deadZone,
            .orientation,
            .swapScreen,
            .resolution,
            .consoleHome,
            .amiibo,
            .hideControls,
            .simBlowing,
            .palette,
            .swapDisk,
            .airPlayScaling,
            .airPlayLayout,
            .triggerPro,
            .screenScaling,
            .insertDisc,
            .rewind,
            .netplay,
            .reload,
            .quit
        ],
        [
            .gameOptionSort,
            .gameShortcut
        ],
        [
            .copyLink,
            .shareRom
        ],
        [
            .delete
        ]
    ]
    
    func accessory(for games: [Game]) -> Accessory {
        guard let firstGame = games.first else { return .chevron(nil) }
        
        switch self {
        case .platformChange:
            if games.allSatisfy({ $0.gameType == firstGame.gameType }) {
                return .chevron(firstGame.gameType.localizedShortName)
            }
            
        case .switchCore:
            if games.allSatisfy({ $0.defaultCore == firstGame.defaultCore }) {
                return .chevron(firstGame.gameType.supportCores[firstGame.defaultCore])
            }
            
        case .changeCategory:
            let extraKey = ExtraKey.gameTypeCategory.rawValue
            let firstGameValue = firstGame.getExtraInt(key: extraKey) ?? 0
            if games.allSatisfy({
                ($0.getExtraInt(key: extraKey) ?? 0) == firstGameValue
            }) {
                return .chevron(firstGame.supportedCategories[firstGameValue].localizedShortName)
            }
            
        case .language:
            if games.allSatisfy({ $0.region == firstGame.region }) {
                var title: String? = nil
                let languages = firstGame.supportedLanguages
                if firstGame.region < languages.count {
                    title = languages[firstGame.region]
                }
                return .chevron(title)
            }
            
        case .jit:
            if games.count == 1 {
                return .switch(firstGame.jit ? .on : .off)
            } else if games.all(matching: { $0.jit == firstGame.jit }) {
                return .chevron(firstGame.jit ? R.string.localizable.on() : R.string.localizable.off())
            }
            
        case .citraMode:
            let title: String
            switch Settings.defalut.threeDSMode {
            case .performance:
                title = R.string.localizable.threeDSModePerformance()
            case .compatibility:
                title = R.string.localizable.threeDSModeCompatibility()
            case .quality:
                title = R.string.localizable.threeDSModeQuality()
            }
            return .chevron(title)
            
        case .citraShader:
            if games.count == 1 {
                return .switch(firstGame.accurateShaders ? .on : .off)
            } else if games.allSatisfy({ $0.accurateShaders == firstGame.accurateShaders }) {
                return .chevron(firstGame.accurateShaders ? R.string.localizable.on() : R.string.localizable.off())
            }
            
        case .citraRightEyeRender:
            if games.count == 1 {
                return .switch(firstGame.renderRightEye ? .on : .off)
            } else if games.allSatisfy({ $0.renderRightEye == firstGame.renderRightEye }) {
                return .chevron(firstGame.renderRightEye ? R.string.localizable.on() : R.string.localizable.off())
            }
            
        case .azaharEmulationAccuracy:
            let extraKey = ExtraKey.emulationAccuracy.rawValue
            let firstGameValue = firstGame.getExtraInt(key: extraKey) ?? 0
            if games.allSatisfy({
                ($0.getExtraInt(key: extraKey) ?? 0) == firstGameValue
            }) {
                return .chevron(firstGameValue == 0 ? "HLE" : "LLE")
            }
            
        case .pspRenderer:
            let extraKey = ExtraKey.pspRenderer.rawValue
            let firstGameValue = firstGame.getExtraInt(key: extraKey) ?? 0
            if games.allSatisfy({
                ($0.getExtraInt(key: extraKey) ?? 0) == firstGameValue
            }) {
                if firstGameValue == 0 {
                    return .chevron("Automatic")
                } else if firstGameValue == 1 {
                    return .chevron("OpenGL")
                } else {
                    return .chevron("Vulkan")
                }
            }
            
        case .pspTexture:
            let extraKey = ExtraKey.pspTexture.rawValue
            let firstGameValue = firstGame.getExtraBool(key: extraKey) ?? false
            if games.count == 1 {
                return .switch(firstGameValue ? .on : .off)
            }
            if games.allSatisfy({
                ($0.getExtraBool(key: extraKey) ?? false) == firstGameValue
            }) {
                return .chevron(firstGameValue ? R.string.localizable.on() : R.string.localizable.off())
            }
            
        case .ps1Bios:
            let extraKey = ExtraKey.biosName.rawValue
            let firstGameValue = (firstGame.getExtraString(key: extraKey) ?? "OpenBIOS")
            if games.allSatisfy({
                ($0.getExtraString(key: extraKey) ?? "OpenBIOS") == firstGameValue
            }) {
                return .chevron(firstGameValue.deletingPathExtension)
            }
            
        case .ps1ControllerMode:
            let extraKey = ExtraKey.isAnalog.rawValue
            let firstGameValue = firstGame.getExtraBool(key: extraKey) ?? true
            if games.allSatisfy({
                ($0.getExtraBool(key: extraKey) ?? true) == firstGameValue
            }) {
                return .chevron(firstGameValue ? R.Strings.PSXDualShock : R.Strings.PSXController)
            }
            
        case .ps1Renderer:
            let extraKey = ExtraKey.psxRenderer.rawValue
            let firstGameValue = firstGame.getExtraBool(key: extraKey) ?? true
            if games.allSatisfy({
                ($0.getExtraBool(key: extraKey) ?? true) == firstGameValue
            }) {
                return .chevron(firstGameValue ? "Hardware" : "Software")
            }
            
        case .n64TransferPak:
            return .chevron(firstGame.hasTransferPak ? R.string.localizable.transferPakOn() : R.string.localizable.transferPakOff())
            
        case .n64RdpPlugin:
            if games.allSatisfy({ $0.isN64ParaLLEl == firstGame.isN64ParaLLEl }) {
                return .chevron(firstGame.isN64ParaLLEl ? "ParaLLEl-RDP" : "GLideN64")
            }
            
        case .ndsSystemType:
            let extraKey = ExtraKey.ndsSystemMode.rawValue
            let firstGameValue = firstGame.getExtraString(key: extraKey) ?? "DS"
            if games.allSatisfy({
                ($0.getExtraString(key: extraKey) ?? "DS") == firstGameValue
            }) {
                return .chevron(firstGameValue)
            }
            
        case .ndsGbaSlot:
            return .chevron(firstGame.hasGBASlotInsert ? R.string.localizable.gbaSlotInsert() : R.string.localizable.gbaSlotUnInsert())
            
        case .ndsMicrophone:
            let extraKey = ExtraKey.microphone.rawValue
            let firstGameValue = firstGame.getExtraBool(key: extraKey) ?? false
            if games.count == 1 {
                return .switch(firstGameValue ? .on : .off)
            } else if games.allSatisfy({
                ($0.getExtraBool(key: extraKey) ?? false) == firstGameValue
            }) {
                return .chevron(firstGameValue ? R.string.localizable.on() : R.string.localizable.off())
            }
            
        case .clownMDTvStandard:
            let extraKey = ExtraKey.tvStandard.rawValue
            let firstGameValue = firstGame.getExtraInt(key: extraKey) ?? 0
            if games.allSatisfy({
                ($0.getExtraInt(key: extraKey) ?? 0) == firstGameValue
            }) {
                return .chevron(firstGameValue == 0 ? "NTSC (59.94HZ)" : "PAL (50HZ)")
            }
            
        case .snesVRAM:
            let extraKey = ExtraKey.snesVRAM.rawValue
            let firstGameValue = firstGame.getExtraBool(key: extraKey) ?? false
            if games.allSatisfy({
                ($0.getExtraBool(key: extraKey) ?? false) == firstGameValue
            }) {
                return .chevron(firstGameValue ? R.string.localizable.enableTitle() : R.string.localizable.disableTitle())
            }
            
        case .shaders:
            if games.count == 1 {
                let shaderPath = Prefference.defalut.getPrefference(kind: .shader,
                                                                    storeKey: .shaderKey(gameId: firstGame.id,
                                                                                         isGlsl: firstGame.supportGlslShaders),
                                                                    bestEfforts: true)?.shaderValue
                return .chevron(Shader.parseTitle(with: shaderPath))
                
            } else {
                let firstGameShaderPath = Prefference.defalut.getPrefference(kind: .shader,
                                                                         storeKey: .shaderKey(gameId: firstGame.id,
                                                                                              isGlsl: firstGame.supportGlslShaders),
                                                                             bestEfforts: true)?.shaderValue
                if games.allSatisfy({
                    let gameShaderPath = Prefference.defalut.getPrefference(kind: .shader,
                                                       storeKey: .shaderKey(gameId: $0.id,
                                                                            isGlsl: $0.supportGlslShaders),
                                                                            bestEfforts: true)?.shaderValue
                    return gameShaderPath == firstGameShaderPath
                }) {
                    return .chevron(Shader.parseTitle(with: firstGameShaderPath))
                }
            }
            
        case .haptic:
            if games.allSatisfy({
                $0.haptic == firstGame.haptic
            }) {
                return .chevron(firstGame.haptic.title)
            }
            
        case .orientation:
            if games.allSatisfy({
                $0.orientation == firstGame.orientation
            }) {
                return .chevron(firstGame.orientation.title)
            }
            
        case .resolution:
            if games.allSatisfy({
                $0.resolution == firstGame.resolution
            }) {
                if firstGame.gameType == .ps1 {
                    return .chevron(firstGame.resolution.resolutionTitleForPS1)
                } else if firstGame.isN64ParaLLEl {
                    return .chevron(firstGame.resolution.resolutionTitleForN64ParaLLEl)
                } else {
                    return .chevron(firstGame.resolution.title)
                }
            }
            
        case .palette:
            if games.allSatisfy({
                $0.pallete == firstGame.pallete
            }) {
                if firstGame.gameType == .vb {
                    return .chevron(firstGame.pallete.paletteTitleForVB)
                    
                } else if firstGame.gameType == .pm {
                    return .chevron(firstGame.pallete.paletteTitleForPM)
                    
                } else if firstGame.gameType == .gb {
                    if firstGame.defaultCore == 0 {
                        //Gambatte
                        return .chevron(firstGame.pallete.optionForGambatte)
                        
                    } else if firstGame.defaultCore == 1 {
                        //mGBA
                        return .chevron(firstGame.pallete.optionForMGBA)
                        
                    } else if firstGame.defaultCore == 2 {
                        return .chevron(firstGame.pallete.optionForVBAM)
                    }
                } else if firstGame.gameType == .nes || firstGame.gameType == .fds {
                    return .chevron(firstGame.currentNesPalette.name)
                } else if firstGame.effectiveGameType == .ws {
                    return .chevron(firstGame.wswanPaletteTitle)
                }
            }
            
        case .swapDisk:
            if firstGame.gameType == .fds {
                return .chevron(nil)
            } else {
                return .chevron("\nDisc \(firstGame.diskInfo?.currentDiskIndex ?? 0)")
            }
            
        case .airPlayScaling:
            return .chevron(Settings.defalut.airPlayScaling.title)
            
        case .airPlayLayout:
            return .chevron(Settings.defalut.airPlayLayout.title)
            
        case .triggerPro:
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
                let realm = Database.realm
                if let trigger = realm.objects(Trigger.self).where({ $0.id == usingTriggerId }).first {
                    return .chevron(trigger.triggerProName)
                }
            } else {
                return .chevron(R.string.localizable.off())
            }
            
        case .screenScaling:
            if games.allSatisfy({
                $0.screenScaling == firstGame.screenScaling
            }) {
                return .chevron(firstGame.screenScaling.title)
            }
            
        case .insertDisc:
            return .chevron(firstGame.diskInfo?.diskLabels.reduce("", { $0 + " " + $1}))
            
        case .citraAdvanceToggle:
            return .switch(Settings.defalut.threeDSAdvancedSettingMode ? .on : .off)
            
        case .quickLoadState:
            if let imageData = firstGame.gameSaveStates.last?.stateCover?.storedData() {
                return .image(.image(UIImage(data: imageData)))
            } else {
                return .chevron(firstGame.gameSaveStates.last?.date.dateTimeString(ofStyle: .short))
            }
            
        case .volume:
            if games.count == 1 {
                return .switch(firstGame.volume ? .on : .off)
            } else if games.allSatisfy({ $0.volume == firstGame.volume }) {
                return .chevron(firstGame.volume ? R.string.localizable.on() : R.string.localizable.off())
            }
            
        case .fastForward:
            if games.allSatisfy({ $0.speed == firstGame.speed }) {
                return .chevron(firstGame.speed.title)
            }
            
        case .swapScreen:
            if games.count == 1 {
                return .switch(firstGame.swapScreen ? .on : .off)
            } else if games.allSatisfy({ $0.swapScreen == firstGame.swapScreen }) {
                return .chevron(firstGame.swapScreen ? R.string.localizable.on() : R.string.localizable.off())
            }
            
        case .hideControls:
            let extraKey = ExtraKey.forceFullSkin.rawValue
            let firstGameValue = firstGame.getExtraBool(key: extraKey) ?? false
            if games.count == 1 {
                return .switch(firstGameValue ? .on : .off)
            } else if games.allSatisfy({
                ($0.getExtraBool(key: extraKey) ?? false) == firstGameValue
            }) {
                return .chevron(firstGameValue ? R.string.localizable.on() : R.string.localizable.off())
            }
            
        case .deadZone:
            if let deadZoneValue = Settings.defalut.getExtraDouble(key: ExtraKey.deadZone.rawValue) {
                return .chevron("\(deadZoneValue.roundedString(scale: 2, minFraction: 2, maxFraction: 2))")
            }
            
        case .rewind:
            let rewind = firstGame.getExtraBool(key: ExtraKey.rewind.rawValue) ?? false
            if games.count == 1 {
                return .switch(rewind ? .on : .off)
            } else if games.allSatisfy({ ($0.getExtraBool(key: ExtraKey.rewind.rawValue) ?? false) == rewind }) {
                return .chevron(rewind ? R.string.localizable.on() : R.string.localizable.off())
            }
            
        case .netplay:
            if LibretroNetplaySession.shared.isHosting,
               let connectedHost = LibretroNetplaySession.shared.connectedHost,
               let detail = connectedHost.nickname ?? connectedHost.address {
                return .chevron(detail)
            } else {
                return .chevron(nil)
            }
            
        case .symbianDevice:
            if let model = firstGame.getExtraString(key: ExtraKey.symbianFirmwareModel.rawValue) {
                if games.count == 1 {
                    return .chevron(model)
                } else if games.allSatisfy({ $0.getExtraString(key: ExtraKey.symbianFirmwareModel.rawValue) == model }) {
                    return .chevron(model)
                }
            }
            
        case .wiiControllerMode:
            let extraKey = ExtraKey.wiiController.rawValue
            let firstGameValue = firstGame.getExtraInt(key: extraKey) ?? 0
            if games.allSatisfy({
                ($0.getExtraInt(key: extraKey) ?? 0) == firstGameValue
            }) {
                return .chevron(R.Strings.WiiControllers[firstGameValue])
            }
        
        case .dolphinCpuCore:
            let extraKey = ExtraKey.dolphinManicInterpreter.rawValue
            let firstGameValue = firstGame.getExtraBool(key: extraKey) ?? true
            if games.allSatisfy({
                ($0.getExtraBool(key: extraKey) ?? true) == firstGameValue
            }) {
                return .chevron(R.Strings.DolphinCPUs[firstGameValue ? 0 : 1])
            }
            
        case .slowMotion:
            let extraKey = ExtraKey.slowMotionSpeed.rawValue
            let firstGameValue = firstGame.getExtraInt(key: extraKey) ?? 0
            if games.allSatisfy({
                ($0.getExtraInt(key: extraKey) ?? 0) == firstGameValue
            }) {
                if firstGameValue == 0 {
                    return .chevron(R.string.localizable.gameSettingFastForwardResume())
                } else if let speed = SlowMotionSpeed(rawValue: firstGameValue) {
                    return .chevron(speed.title)
                }
            }
            
        case .wswanRotation:
            let extraKey = ExtraKey.wswanRotation.rawValue
            let firstGameValue = firstGame.getExtraInt(key: extraKey) ?? 0
            if games.allSatisfy({
                ($0.getExtraInt(key: extraKey) ?? 0) == firstGameValue
            }) {
                if firstGameValue == 0 {
                    return .chevron(R.string.localizable.skinSegmentPortraitTitle())
                } else {
                    return .chevron(R.string.localizable.skinSegmentLandscapeTitle())
                }
            }
            
        case .rename,
                .cover,
                .editLink,
                .skins,
                .stateList,
                .importSave,
                .shareSave,
                .genHomeMenu,
                .copyLink,
                .shareRom,
                .delete,
                .retroAchievements,
                .cheatCode,
                .manual,
                .ps1Sbi,
                .coreSettings,
                .saveState,
                .screenShot,
                .airplay,
                .controllerSetting,
                .gameOptionSort,
                .consoleHome,
                .amiibo,
                .simBlowing,
                .reload,
                .quit,
                .gameShortcut,
                .coverScraping,
                .ndsLidToggle,
                .pspJitType,
                .skinButtonBinding:
            break
        }
        return .chevron(nil)
    }
    
    private static func disableOptionsForScene(_ scene: Scene) -> [Self] {
        switch scene {
        case .common:
            return [
                .saveState,
                .quickLoadState,
                .screenShot,
                .consoleHome,
                .amiibo,
                .simBlowing,
                .swapDisk,
                .insertDisc,
                .reload,
                .quit,
                .ndsLidToggle,
                .pspJitType,
            ]
        case .gameInfo:
            return disableOptionsForScene(.common) + [.rename, .genHomeMenu, .coverScraping]
            
        case .gaming:
            return [
                .rename,
                .cover,
                .importSave,
                .shareSave,
                .platformChange,
                .switchCore,
                .changeCategory,
                .genHomeMenu,
                .copyLink,
                .shareRom,
                .delete,
                .language,
                .jit,
                .citraAdvanceToggle,
                .azaharEmulationAccuracy,
                .pspJitType,
                .pspRenderer,
                .pspTexture,
                .ps1Bios,
                .ps1Sbi,
                .ps1Renderer,
                .n64TransferPak,
                .n64RdpPlugin,
                .ndsSystemType,
                .ndsGbaSlot,
                .ndsMicrophone,
                .clownMDTvStandard,
                .snesVRAM,
                .symbianDevice,
                .coverScraping,
                .dolphinCpuCore
            ]
        }
    }
    
    static func availableOptions(game: Game, scene: Scene = .common) -> [Self] {
        if game.isSymbianHomeMenu {
            var options: [Self] = [.rename,
                                   .cover,
                                   .delete,
                                   .volume,
                                   .haptic,
                                   .airplay,
                                   .orientation,
                                   .gameOptionSort,
                                   .airPlayScaling,
                                   .triggerPro,
                                   .gameShortcut,
                                   .deadZone]
            
            if scene == .gaming {
                options += [.screenShot,
                            .hideControls,
                            .reload,
                            .quit]
            }
            return options
        }
        
        if game.isUrlGame {
            return [.cover, .editLink, .delete]
        }
        
        if game.gameType.externalType {
            return [.rename, .cover, .delete]
        }
        
        if game.isNDSHomeMenuGame {
            return [.delete]
        }
        
        if game.gameType == .unknown {
            return  [.platformChange, .delete]
        }
        
        var allOptions = Set(GameOption.allCases)
        allOptions.remove(.editLink)
        
        if GameType.gameTypes(multiPlatformFileExtension: game.fileExtension).count == 0 {
            allOptions.remove(.platformChange)
        }
        
        if game.gameType.supportCores.count == 0 ||
            (game.gameType == .ss && game.fileExtension.lowercased() == "iso") ||
            game.isArticBaseHomeMenu ||
            game.isSegaArcade {
            allOptions.remove(.switchCore)
        }
        
#if !SIDE_LOAD
        if game.gameType == .md ||
            game.gameType == ._32x ||
            game.gameType == .arcade ||
            game.isGearSystemCore {
            //The App Store versions of md, 32x, arcade, ms, gg, and sg-1000 don’t support core switching.
            allOptions.remove(.switchCore)
        }
#endif
        
        if game.gameType != .dos || game.isDOSHomeMenuGame {
            allOptions.remove(.genHomeMenu)
        }
        
        if game.isDOSHomeMenuGame {
            allOptions.subtract([.stateList, .shareRom])
        }
        
        if !game.supportSave {
            allOptions.subtract([.importSave, .shareSave])
        }
        
        if !game.supportChangeCategory {
            allOptions.remove(.changeCategory)
        }
        
        if !game.supportRetroAchievements {
            allOptions.remove(.retroAchievements)
        }
        
        if !game.supportCheatCode {
            allOptions.remove(.cheatCode)
        }
        
        if !game.supportLanguage {
            allOptions.remove(.language)
        }
        
        if !LibretroCore.jitAvailable() || !game.supportJit {
            allOptions.remove(.jit)
        }
        
        if game.isCitra3DS {
            if Settings.defalut.threeDSAdvancedSettingMode {
                allOptions.subtract([.citraMode, .citraShader, .citraRightEyeRender])
            } else {
                allOptions.remove(.coreSettings)
            }
        } else {
            allOptions.subtract([.citraAdvanceToggle, .citraMode, .citraShader, .citraRightEyeRender])
        }
        
        if !game.isAzahar3DS {
            allOptions.subtract([.azaharEmulationAccuracy])
        }
        
        if game.gameType != .psp {
            allOptions.subtract([.pspJitType, .pspRenderer, .pspTexture])
        }
        
        if game.gameType == .ps1 && game.defaultCore == 1 {
            //PCSReArmed
            allOptions.subtract([.ps1Bios, .ps1ControllerMode, .ps1Renderer])
        }
        
        if game.gameType != .ps1 {
            allOptions.subtract([.ps1Bios, .ps1ControllerMode, .ps1Sbi, .ps1Renderer])
        }
        
        if game.gameType != .n64 {
            allOptions.subtract([.n64TransferPak, .n64RdpPlugin])
        }
        
        if game.gameType == .ds && game.defaultCore == 1 {
            //DeSmuME
            allOptions.subtract([.ndsSystemType, .ndsGbaSlot])
        }
        
        if game.gameType != .ds {
            allOptions.subtract([.ndsSystemType, .ndsGbaSlot, .ndsMicrophone])
        }
        
        if game.gameType != .md || (game.gameType == .md && game.defaultCore != 0) {
            allOptions.remove(.clownMDTvStandard)
        }
        
        if game.gameType != .snes {
            allOptions.remove(.snesVRAM)
        }
        
        if game.gameType == .snes, game.defaultCore == 2 {
            allOptions.remove(.snesVRAM)
        }
        
        if !game.supportCoreSettings {
            allOptions.remove(.coreSettings)
        }
        
        if !game.supportSaveState {
            allOptions.subtract([.stateList, .saveState, .quickLoadState])
        }
        
        if !game.supportFastForward {
            allOptions.remove(.fastForward)
        }
        
        if !game.supportSlangShaders && !game.supportGlslShaders {
            allOptions.remove(.shaders)
        }
        
        if !game.supportSwapScreen {
            allOptions.remove(.swapScreen)
        }
        
        if !game.supportResolution {
            allOptions.remove(.resolution)
        }
        
        if !game.supportConsoleHome {
            allOptions.remove(.consoleHome)
        }
        
        if !game.supportAmiibo {
            allOptions.remove(.amiibo)
        }
        
        if !game.supportSimBlowing {
            allOptions.remove(.simBlowing)
        }
        
        if !game.supportPalette {
            allOptions.remove(.palette)
        }
        
        if !game.supportSwapDisc {
            allOptions.remove(.swapDisk)
        }
        
        if !game.supportAirPlayLayout {
            allOptions.remove(.airPlayLayout)
        }
        
        if !game.supportScreenScaling {
            allOptions.remove(.screenScaling)
        }
        
        if !game.supportInsertDisc {
            allOptions.remove(.insertDisc)
        }
        
        if PlayViewController.isWFCConnect {
            allOptions.subtract([.saveState, .quickLoadState, .fastForward, .stateList, .cheatCode, .rewind, .slowMotion])
        }
        
        if PlayViewController.isHardcoreMode {
            allOptions.subtract([.quickLoadState, .cheatCode, .triggerPro, .rewind, .slowMotion])
        }
        
        if !game.supportRewind {
            allOptions.remove(.rewind)
        }
        
        if !game.isLibretroType {
            allOptions.remove(.netplay)
        } else {
            if let core = game.libretroCore {
                if !core.supportNetplay {
                    allOptions.remove(.netplay)
                }
            } else {
                allOptions.remove(.netplay)
            }
        }
        
        if game.gameType != .symbian {
            allOptions.remove(.symbianDevice)
        }
        
        if game.gameType != .wii {
            allOptions.remove(.wiiControllerMode)
        }
        
        if !game.isDolphinCore || (LibretroCore.jitAvailable() && game.jit) {
            allOptions.remove(.dolphinCpuCore)
        }
        
        if !game.supportSlowMotion {
            allOptions.remove(.slowMotion)
        }
        
        if game.gameType != .wsc {
            allOptions.remove(.wswanRotation)
        }
        
        if game.gameType != .ds {
            allOptions.remove(.ndsLidToggle)
        }
        
        if game.gameType != .flash {
            allOptions.remove(.skinButtonBinding)
        }
        
        allOptions.subtract(disableOptionsForScene(scene))
        
        return Array(allOptions)
    }
    
    static func availableOptions(games: [Game], scene: Scene = .common) -> [Self] {
        guard games.count > 0 else { return [] }
        
        if games.count == 1 {
            var options = availableOptions(game: games.first!, scene: scene)
            options.removeAll(where: { $0 == .coverScraping })
            return options
            
        } else {
            guard let firstGame = games.first else { return [] }
            var optionsSet = Set<GameOption>()
            
            for g in games {
                let options = GameOption.availableOptions(game: g, scene: scene)
                guard options.count > 0 else { continue }
                if optionsSet.count == 0 {
                    optionsSet = Set(options)
                } else {
                    optionsSet = optionsSet.intersection(options)
                }
            }
            
            GameOption.disableOptionsForMultiGames.forEach({
                optionsSet.remove($0)
            })
            
            optionsSet = removeUnavailableOptions(optionsSet: optionsSet, options: [.platformChange], condition: {
                !games.allSatisfy({
                    $0.fileExtension.lowercased() == firstGame.fileExtension.lowercased()
                })
            })
            
            
            optionsSet = removeUnavailableOptions(optionsSet: optionsSet,
                                                  options: [.skins,
                                                            .switchCore,
                                                            .changeCategory,
                                                            .language,
                                                            .palette,
                                                            .triggerPro,
                                                            .gameShortcut,
                                                            .symbianDevice,
                                                            .skinButtonBinding],
                                                  condition: {
                !games.allSatisfy({ $0.gameType == firstGame.gameType })
            })
            
            
            optionsSet = removeUnavailableOptions(optionsSet: optionsSet,
                                                  options: [.shaders],
                                                  condition: {
                !games.allSatisfy({
                    $0.supportSlangShaders == firstGame.supportSlangShaders ||
                    $0.supportGlslShaders == firstGame.supportGlslShaders
                })
            })
            
            optionsSet = removeUnavailableOptions(optionsSet: optionsSet,
                                                  options: [.resolution],
                                                  condition: {
                !games.allSatisfy({
                    $0.gameType == firstGame.gameType ||
                    (firstGame.gameType == .n64 &&
                     $0.gameType == firstGame.gameType &&
                     $0.defaultCore == firstGame.defaultCore)
                })
            })
            
            optionsSet = removeUnavailableOptions(optionsSet: optionsSet,
                                                  options: [.coreSettings],
                                                  condition: {
                !games.allSatisfy({
                    $0.gameType == firstGame.gameType &&
                    $0.defaultCore == firstGame.defaultCore
                })
            })
            
            return Array(optionsSet)
        }
        
    }
    
    private static func removeUnavailableOptions(optionsSet: Set<GameOption>,
                                                 options: [Self],
                                                 condition: (()->Bool)) -> Set<GameOption> {
        var result = optionsSet
        if condition() {
            result.subtract(options)
        }
        return result
    }
    
    static func defaultShortcutOptions(for game: Game?) -> [Self] {
        guard let game else { return [.quit, .reload, .volume, .screenShot] }
        let availableOptions = Set(GameOption.availableOptions(game: game, scene: .gaming))
        var result: [GameOption] = [.quit, .reload]
        if availableOptions.contains(.saveState) {
            result += [.saveState, .quickLoadState]
        } else {
            result.append(.volume)
            if availableOptions.contains(.fastForward) {
                result.append(.fastForward)
            } else {
                result.append(.screenShot)
            }
        }
        return result
    }
    
    static func groupAndSortOptions(_ options: [Self]) -> [[Self]] {
        guard !options.isEmpty else { return [] }
        let optionSet = Set(options)
        var groupAndSort = defaultGroupAndSort
        if let prefference = Prefference.defalut.getPrefference(kind: .gameOptionsSort,
                                                                storeKey: .global())?.gameOptionsSortValue {
            groupAndSort = prefference
        }
        
        var result = groupAndSort.compactMap { group -> [Self]? in
            let sortedGroup = group.filter { optionSet.contains($0) }
            return sortedGroup.isEmpty ? nil : sortedGroup
        }
        let unknownOptions = optionSet.subtracting(Set(groupAndSort.flatMap { $0 }))
        if !unknownOptions.isEmpty {
            result.append(unknownOptions.sorted { $0.rawValue < $1.rawValue })
        }
        return result
    }
}
