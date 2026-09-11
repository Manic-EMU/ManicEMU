//
//  SettingItem.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

struct SettingItem {
    
    enum ItemType: String {
        case appearance, theme, quickGame, autoSaveState, skin, airPlay, iCloud, fullScreenWhenConnectController, bios, respectSilentMode, onlinePlay, rumble, skinSound, retro, triggerPro, jit, shaders, globalCoreSwitch, FAQ, feedback, qq, telegram, discord, about, shareApp, clearCache, language, userAgreement, privacyPolicy, featuredItems, coverScraping
    }
    
    var type: ItemType
    
    var cellData: ASListPage.Cell {
        var styles = [ASListPage.Cell.Style]()
        var enablePressEffect = false
        //icon
        styles.append(.icon(icon,
                            iconSize: .fixSize(CGSize(R.Size.ButtonExtraExtraSmall))))
        //title
        styles.append(.title(.largeText(title)))
        //detail
        if let detail {
            styles.append(.detail(.extraSmallText(detail,
                                                  color: R.Color.LabelSecondary,
                                                  numberOfLines: 0)))
        }
        //switch
        if let switchStyle {
            styles.append(switchStyle)
        }
        //chevron
        if let chevronStyle {
            enablePressEffect = true
            styles.append(chevronStyle)
        }
        //segment
        if type == .appearance {
            let icons: [ASIcon] = [
                .symbolImage(R.image.dark_iconSymbols()),
                .symbolImage(R.image.light_iconSymbols()),
                .symbolImage(R.image.auto_iconSymbols())
            ]
            styles.append(.segment(.iconSegment(icons: icons, index: Settings.appearance.rawValue)))
        }
        return ASListPage.Cell.normal(styles, enablePressEffect: enablePressEffect)
    }
    
    var switchStyle: ASListPage.Cell.Style? {
        switch type {
        case .quickGame:
            return .switch(.init(state: Settings.defalut.quickGame ? .on : .off))
        case .autoSaveState:
            return .switch(.init(state: Settings.defalut.autoSaveState ? .on : .off))
        case .airPlay:
            let state: ASSwitch.State = PurchaseManager.isMember ? (Settings.defalut.airPlay ? .on : .off) : .disabled
            return .switch(.init(state: state))
        case .fullScreenWhenConnectController:
            return .switch(.init(state: Settings.defalut.fullScreenWhenConnectController ? .on : .off))
        case .respectSilentMode:
            return .switch(.init(state: Settings.defalut.respectSilentMode ? .on : .off))
        case .rumble:
            return .switch(.init(state: (Settings.defalut.getExtraBool(key: ExtraKey.rumble.rawValue) ?? false) ? .on : .off))
        case .skinSound:
            return .switch(.init(state: (Settings.defalut.getExtraBool(key: ExtraKey.skinSoundEffects.rawValue) ?? true) ? .on : .off))
        default:
            return nil
        }
    }
    
    var chevronStyle: ASListPage.Cell.Style? {
        switch type {
        case .quickGame,
                .autoSaveState,
                .airPlay,
                .fullScreenWhenConnectController,
                .respectSilentMode,
                .rumble,
                .skinSound,
                .appearance:
            return nil
            
        case .clearCache:
            return .chevron(ASChevron(title: CacheManager.totleSize))
            
        case .language:
            return .chevron(ASChevron(title: Locale.getSystemLanguageDisplayName(preferredLanguage: Settings.defalut.language)))
            
        default:
            return .chevron(ASChevron())
        }
    }
    
    var iconColors: [UIColor] {
        switch type {
        case .appearance, .respectSilentMode, .globalCoreSwitch, .discord, .privacyPolicy:
            [R.Color.Purple]
        case .theme, .onlinePlay, .FAQ, .featuredItems:
            [R.Color.Orange]
        case .autoSaveState, .rumble, .feedback:
            [R.Color.Green]
        case .skin, .skinSound, .about:
            [R.Color.Pink]
        case .airPlay, .qq, .telegram, .shareApp, .coverScraping:
            [R.Color.Indigo]
        case .quickGame, .iCloud, .triggerPro, .clearCache:
            [R.Color.Yellow]
        case .fullScreenWhenConnectController, .jit, .language:
            [R.Color.Cyan]
        case .bios, .shaders, .userAgreement:
            [R.Color.Magenta]
        case .retro:
            [R.Color.Indigo, R.Color.Yellow]
        }
    }
    
    var icon: ASIcon {
        switch type {
        case .theme:
            ASIcon.symbolImage(R.image.themeRegular_iconSymbols(), colors: iconColors)
        case .quickGame:
            ASIcon.symbolImage(R.image.games_iconSymbols(), colors: iconColors)
        case .airPlay:
            ASIcon.symbolImage(R.image.airplay_iconSymbols(), colors: iconColors)
        case .iCloud:
            ASIcon.symbolImage(R.image.icloudsync_iconSymbols(), colors: iconColors)
        case .fullScreenWhenConnectController:
            ASIcon.symbolImage(R.image.fullscreen_iconSymbols(), colors: iconColors)
        case .FAQ:
            ASIcon.symbolImage(R.image.faq_iconSymbols(), colors: iconColors)
        case .feedback:
            ASIcon.symbolImage(R.image.feedback_iconSymbols(), colors: iconColors)
        case .shareApp:
            ASIcon.symbolImage(R.image.shareRa_iconSymbols(), colors: iconColors)
        case .qq:
            ASIcon.symbolImage(R.image.qq_iconSymbols(), colors: iconColors)
        case .telegram:
            ASIcon.symbolImage(R.image.share_iconSymbols(), colors: iconColors)
        case .discord:
            ASIcon.symbolImage(R.image.discord_iconSymbols(), colors: iconColors)
        case .clearCache:
            ASIcon.symbolImage(R.image.clean_iconSymbols(), colors: iconColors)
        case .language:
            ASIcon.symbolImage(R.image.language_iconSymbols(), colors: iconColors)
        case .userAgreement:
            ASIcon.symbolImage(R.image.termsofservice_iconSymbols(), colors: iconColors)
        case .privacyPolicy:
            ASIcon.symbolImage(R.image.privacypolicy_iconSymbols(), colors: iconColors)
        case .autoSaveState:
            ASIcon.symbolImage(R.image.autosavestates_iconSymbols(), colors: iconColors)
        case .bios:
            ASIcon.symbolImage(R.image.bios_iconSymbols(), colors: iconColors)
        case .respectSilentMode:
            ASIcon.symbolImage(R.image.bell_iconSymbols(), colors: iconColors)
        case .onlinePlay:
            ASIcon.symbolImage(R.image.online_iconSymbols(), colors: iconColors)
        case .about:
            ASIcon.symbolImage(R.image.aboutus_iconSymbols(), colors: iconColors)
        case .retro:
            ASIcon.symbolImage(R.image.retroachievements_iconSymbols(), colors: iconColors)
        case .rumble:
            ASIcon.symbolImage(R.image.rumble_iconSymbols(), colors: iconColors)
        case .appearance:
            ASIcon.symbolImage(R.image.appearance_iconSymbols(), colors: iconColors)
        case .triggerPro:
            ASIcon.symbolImage(R.image.triggerpro_iconSymbols(), colors: iconColors)
        case .skin:
            ASIcon.symbolImage(R.image.skin_iconSymbols(), colors: iconColors)
        case .jit:
            ASIcon.symbolImage(R.image.jit_iconSymbols(), colors: iconColors)
        case .shaders:
            ASIcon.symbolImage(R.image.shaders_iconSymbols(), colors: iconColors)
        case .featuredItems:
            ASIcon.symbolImage(R.image.featureditems_iconSymbols(), colors: iconColors)
        case .skinSound:
            ASIcon.symbolImage(R.image.skin_iconSymbols(), colors: iconColors)
        case .globalCoreSwitch:
            ASIcon.symbolImage(R.image.core_iconSymbols(), colors: iconColors)
        case .coverScraping:
            ASIcon.symbolImage(R.image.cover_iconSymbols(), colors: iconColors)
        }
    }
    
    var title: String {
        switch type {
        case .theme:
            R.string.localizable.themeSettingTitle()
        case .quickGame:
            R.string.localizable.quickGameTitle()
        case .airPlay:
            R.string.localizable.airPlayTitle()
        case .iCloud:
            R.string.localizable.iCloudTitle()
        case .FAQ:
            R.string.localizable.qaTitle()
        case .feedback:
            R.string.localizable.feedbackTitle()
        case .shareApp:
            R.string.localizable.shareAppTitle()
        case .qq:
            R.string.localizable.joinQQTitle()
        case .telegram:
            R.string.localizable.joinTelegramTitle()
        case .discord:
            R.string.localizable.joinDiscordTitle()
        case .clearCache:
            R.string.localizable.clearCacheTitle()
        case .language:
            R.string.localizable.languageTitle()
        case .userAgreement:
            R.string.localizable.userAgreementTitle()
        case .privacyPolicy:
            R.string.localizable.privacyPolicyTitle()
        case .fullScreenWhenConnectController:
            R.string.localizable.fullScreenWhenConnectControllerTitle()
        case .autoSaveState:
            R.string.localizable.autoSaveStateTitle()
        case .bios:
            "BIOS"
        case .respectSilentMode:
            R.string.localizable.respectSilentMode()
        case .onlinePlay:
            R.string.localizable.onlinePlaySetting()
        case .about:
            "About Us"
        case .retro:
            "RetroAchievements"
        case .rumble:
            "Rumble"
        case .appearance:
            R.string.localizable.appearance()
        case .triggerPro:
            "TriggerPro"
        case .skin:
            R.string.localizable.gamesSpecifySkin()
        case .jit:
            "JIT"
        case .shaders:
            R.string.localizable.shaders()
        case .featuredItems:
            R.string.localizable.featuredItems()
        case .skinSound:
            R.string.localizable.skinSoundEffects()
        case .globalCoreSwitch:
            R.string.localizable.globalCoreSwitch()
        case .coverScraping:
            R.string.localizable.coverScraping()
        }
    }
    
    var detail: String? {
        if type == .quickGame {
            return R.string.localizable.quickGameDetail()
        } else if type == .airPlay {
            return R.string.localizable.airPlayDetail()
        } else if type == .fullScreenWhenConnectController {
            return R.string.localizable.fullScreenWhenConnectControllerDetail()
        } else if type == .theme {
            return R.string.localizable.themeSettingDetail()
        } else if type == .bios {
            return R.string.localizable.biosDesc()
        } else if type == .respectSilentMode {
            return R.string.localizable.respectSilentModeDesc()
        } else if type == .rumble {
            return R.string.localizable.rumbleDetail()
        } else if type == .appearance {
            return Settings.appearance.desc
        } else if type == .triggerPro {
            return R.string.localizable.triggerProDesc()
        } else if type == .iCloud {
#if SIDE_LOAD
            return R.string.localizable.iCloudNotEnable()
#else
            if !Settings.defalut.iCloudSyncEnable {
                return R.string.localizable.iCloudNotEnable()
            }
            let progress = FilesSyncManager.shared.progress
            switch progress.phase {
            case .idle:
                return R.string.localizable.iCloudSynced()
            case .paused:
                return R.string.localizable.iCloudSyncPaused()
            case .unavailable:
                return R.string.localizable.iCloudNotEnable()
            case .scanning, .syncing:
                if progress.totalCount > 0 {
                    return R.string.localizable.iCloudSyncing() + " " + R.string.localizable.iCloudSyncProgressFormat(progress.completedCount, progress.totalCount)
                }
                return R.string.localizable.iCloudSyncing()
            }
#endif
        }
        return nil
    }
}
