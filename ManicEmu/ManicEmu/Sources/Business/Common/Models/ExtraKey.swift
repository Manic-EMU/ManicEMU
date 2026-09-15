//
//  ExtraKey.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

enum ExtraKey: String {
    case ndsSystemMode
    case wfc
    case isAnalog
    case rdpPlugin
    case deadZone
    case psxRenderer
    case achievementsUser
    case enableAchievements
    case achievementsHardcore
    case saveStateCore
    case rumble
    case gameSortType
    case gameSortOrder
    case achievementsProgress
    case alwaysShowProgress
    case cheevosSubsetId
    case tvStandard
    case snesVRAM
    case airPlayScaling
    case airPlayLayout
    case pspRenderer
    case globalAchievements
    case globalHardcore
    case microphone
    case pspTexture
    case manualPage
    case manualFileName
    case manualScaleFactor
    case manulDestination
    case nesPalette
    case triggerProID
    case forceFullSkin
    case enableManufacturerFilter
    case PSPGameCode
    case dolphinGameID
    case cheatSort
    case flexBackground
    case shaderConfig
    case tvType
    case leftDifficulty
    case rightDifficulty
    case pspConfig
    case screenScaling
    case j2meScreenSize
    case j2meScreenRotate
    case coreConfigs
    case skinSoundEffects
    case biosName
    case pretendoConfig
    case identifier
    case regions
    case isArticBaseHomeMenu
    case isPSPPBPGame
    case pspPBPGamePath
    case gameTypeCategory
    case globalCoreConfigs
    case manufacturerOrder
    case emulationAccuracy
    case gamehackingBookMark
    case steamGridDBAPIKey
    case landscapeListStyle
    case landscapeCarouselEnabled
    case landscapeShaderToy
    case landscapeBackgroundMusic
    case landscapeSoundEffects
    case gameMetadata
    case hasQueryMetadata
    case hideGameRating
    case rewind
    case nickname
    case joinDate
    case symbianFirmwareCode
    case symbianFirmwareModel
    case symbianOSVer
    case ngageFiles
    case symbianPackages
    case wiiController
    case dolphinManicInterpreter
    case autoEnableJITOnLaunch
    case slowMotionSpeed
    case iCloudSyncROM
    case iCloudSyncROMPlatforms
    case wswanRotation
    case wswanPalette
    case arcadeType//naomi=1 atomiswave=2 segasp=3
    /// Game that launches a third-party emulator via a custom URL scheme.
    case isUrlGame
    /// Launch URL for `isUrlGame`. Game.id is an MD5 of this string so CreamAsset filenames stay valid.
    case urlGameURL
    /// JSON recipe mapping FLASHSkinButton raw values to FLASHKey (KeyboardEvent.code) values.
    case skinButtonBinding
}
