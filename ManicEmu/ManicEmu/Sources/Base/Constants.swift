//
//  Constants.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/25.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import RealmSwift
import KeychainAccess
import ManicEmuCore

struct Constants {
    struct Size {
        //系统常用尺寸
        static var WindowSize: CGSize { UIWindow.applicationWindow?.bounds.size ?? .zero }
        static var WindowWidth: CGFloat { WindowSize.width }
        static var WindowHeight: CGFloat { WindowSize.height }
        static var SafeAera: UIEdgeInsets { UIWindow.applicationWindow?.safeAreaInsets ?? .zero}
        
        //布局
        ///间距 24
        static let ContentSpaceHuge = 24.0
        ///间距 20
        static let ContentSpaceMax = 20.0
        ///间距 16
        static let ContentSpaceMid = 16.0
        ///间距 12
        static let ContentSpaceMin = 12.0
        ///间距 8
        static let ContentSpaceTiny = 8.0
        ///间距 4
        static let ContentSpaceUltraTiny = 4.0
        
        ///图标尺寸 76x76
        static let IconSizeHuge = CGSize(width: 76, height: 76)
        ///图标尺寸 36x36
        static let IconSizeMax = CGSize(width: 36, height: 36)
        ///图标尺寸 30x30
        static let IconSizeMid = CGSize(width: 30, height: 30)
        ///图标尺寸 24x24
        static let IconSizeMin = CGSize(width: 24, height: 24)
        ///图标尺寸 18x18
        static let IconSizeTiny = CGSize(width: 18, height: 18)
        
        /// 圆角半径 20
        static let CornerRadiusMax = 20.0
        /// 圆角半径 16
        static let CornerRadiusMid = 16.0
        /// 圆角半径 12
        static let CornerRadiusMin = 12.0
        /// 圆角半径 8
        static let CornerRadiusTiny = 8.0
        
        /// 条目高度 76
        static let ItemHeightHuge = 76.0
        /// 条目高度 60
        static let ItemHeightMax = 60.0
        /// 条目高度 50
        static let ItemHeightMid = 50.0
        /// 条目高度 44
        static let ItemHeightMin = 44.0
        /// 条目高度 36
        static let ItemHeightTiny = 36.0
        /// 条目高度 30
        static let ItemHeightUltraTiny = 30.0
        
        ///符号图标size 16
        static let SymbolSize = 18.0
        
        ///HomeTabBarSize 300x60
        static let HomeTabBarSize = CGSize(width: 300, height: ItemHeightMax)
        /// 侧边视图宽度
        static let SideMenuWidth = UIDevice.isPhone ? WindowSize.minDimension * 0.874 : 300
        ///分割线高度
        static let BorderLineHeight = 1.0
        /// 游戏封面宽高比 默认1:1
        static func GameCoverRatio(gameType: GameType) -> CGFloat {
            if GameCoverForceSquare {
                return 1.0
            }
            switch GameCoverStyle {
            case .style1:
                switch gameType {
                case ._3ds, .ds: return 1.13
                case .md, .gg: return 0.711
                case ._32x, .ms: return 0.706
                case .sg1000: return 0.735
                case .nes: return 0.7
                case .snes: return 1.4
                case .psp: return 0.57
                case .ss: return 0.638
                case .n64: return 1.369
                case .mcd: return (Locale.prefersUS ? 0.5864 : 1.1)
                case .doom: return 0.731
                case .arcade: return 0.731
                case .ns: return 0.611
                case .a2600: return 0.735
                case .a5200: return 0.732
                case .a7800: return 0.709
                case .jaguar: return 0.724
                case .lynx: return 1.118
                default: return 1.0
                }
            case .style2:
                return 1.0
            case .style3:
                return 1.0
            }
        }
        ///游戏列表选中状态外边缘 6.0
        static let GamesListSelectionEdge = 6.0
        ///游戏封面最大尺寸 300pt 可能是600px或者900px
        static let GameCoverMaxSize = 300.0
        ///游戏名称最大长度 255
        static let GameNameMaxCount = 255
        
        ///CollectionView的top缩进
        static var ContentInsetTop: CGFloat {
            let safeArea = Constants.Size.SafeAera
            return safeArea.top > 0 ? safeArea.top : Constants.Size.ContentSpaceMax
        }
        
        ///CollectionView的bottom缩进
        static var ContentInsetBottom: CGFloat {
            let safeArea = Constants.Size.SafeAera
            return safeArea.bottom > 0 ? safeArea.bottom : Constants.Size.ContentSpaceMax
        }
        
        ///游戏封面圆角样式
        static var GameCoverStyle = CoverStyle.style1
        static var GameCoverCornerRatio = GameCoverStyle.defaultCornerRadius()
        static var GameCoverForceSquare = false
        ///苹果图标默认尺寸
        static func AppleIconCornerRadius(height: CGFloat) -> CGFloat {
            return 10/57 * height
        }
        
        static var GamesPerRow = 2.0
        static var GamesHideScrollIndicator = false
        static var GamesHideTitle = false
        static var GamesHideGroupTitle = false
        static var GamesGroupTitleStyle: GroupTitleStyle = .abbr
        static var GamesToolViewHeight: CGFloat {
            let enableFilter = Theme.defalut.getExtraBool(key: ExtraKey.enableManufacturerFilter.rawValue) ?? false
            return Constants.Size.ItemHeightHuge + (enableFilter ? Constants.Size.ItemHeightUltraTiny + Constants.Size.ContentSpaceMid : 0)
        }
    }
    
    struct Color {
        //文本
        static let LabelPrimary = UIColor(.dm,
                                          light: UIColor(hexString: "#323443")!,
                                          dark: UIColor(hexString: "#ffffff")!)
        static let LabelSecondary = UIColor(.dm,
                                            light: UIColor(hexString: "#90929F")!,
                                            dark: UIColor(hexString: "#8F8F92")!)
        static let LabelTertiary = UIColor(.dm,
                                           light: UIColor(hexString: "#C1C0C6")!,
                                           dark: UIColor(hexString: "#403E46")!)
        
        //分割线
        static let Border = UIColor(.dm,
                                    light: .black.withAlphaComponent(0.05),
                                    dark: .white.withAlphaComponent(0.05))
        
        //侧边栏
        static let SideList = UIColor(.dm,
                                      light: UIColor(hexString: "#F7F8FC")!,
                                      dark: UIColor(hexString: "#17171D")!)
        
        //背景
        static let Background = UIColor(.dm,
                                              light: UIColor(hexString: "#F1F4FE")!,
                                              dark: UIColor(hexString: "#17171D")!)
        
        static let BackgroundPrimary = UIColor(.dm,
                                              light: UIColor(hexString: "#FAFCFF")!,
                                              dark: UIColor(hexString: "#222229")!)
        
        static let BackgroundSecondary = UIColor(.dm,
                                           light: UIColor(hexString: "#E1E2E5")!,
                                           dark: UIColor(hexString: "#464651")!)
        //Input
        static let InputBackground = UIColor(.dm,
                                           light: UIColor(hexString: "#E8EBF2")!,
                                           dark: UIColor(hexString: "#121217")!)
        
        //Segment
        static let SegmentBackground = UIColor(.dm,
                                               light: UIColor(hexString: "#E8EBF2")!,
                                               dark: UIColor(hexString: "#222229")!)
        
        static let SegmentHighlight = UIColor(.dm,
                                              light: UIColor(hexString: "#FAFCFF")!,
                                              dark: UIColor(hexString: "#464651")!)
        
        static let AppearanceSegmentHighlight = UIColor(.dm,
                                                        light: UIColor(hexString: "#FFFFFF")!,
                                                        dark: UIColor(hexString: "#464651")!)
        
        //阴影
        static let Shadow = BackgroundPrimary
        
        //颜色
        static var Gradient = [UIColor(hexString: "#FF2442")!, UIColor(hexString: "#EB7500")!, UIColor(hexString: "#BB64FF")!, UIColor(hexString: "#0096FF")!]
        
        static var MainDynamicColor = UIColor(hexString: "#FF2442")!
        
        static let Main = UIColor(.dm) { traitCollection in
            return MainDynamicColor
        }
        
        static let Red = UIColor(.dm,
                                 light: UIColor(hexString: "#FF2442")!,
                                 dark: UIColor(hexString: "#FF2442")!)
        
        static let Green = UIColor(.dm,
                                   light: UIColor(hexString: "#06D58F")!,
                                   dark: UIColor(hexString: "#06D58F")!)
        
        static let Blue = UIColor(.dm,
                                  light: UIColor(hexString: "#7984FF")!,
                                  dark: UIColor(hexString: "#7984FF")!)
        
        static let Indigo = UIColor(.dm,
                                    light: UIColor(hexString: "#33A9FF")!,
                                    dark: UIColor(hexString: "#33A9FF")!)
        
        static let Purple = UIColor(.dm,
                                    light: UIColor(hexString: "#9390FF")!,
                                    dark: UIColor(hexString: "#9390FF")!)
        
        static let Yellow = UIColor(.dm,
                                    light: UIColor(hexString: "#FEC458")!,
                                    dark: UIColor(hexString: "#FEC458")!)

        
        static let Magenta = UIColor(.dm,
                                     light: UIColor(hexString: "#FF7B7F")!,
                                     dark: UIColor(hexString: "#FF7B7F")!)

        
        static let Orange = UIColor(.dm,
                                    light: UIColor(hexString: "#FF7A71")!,
                                    dark: UIColor(hexString: "#FF7A71")!)
        
        static let Pink = UIColor(.dm,
                                    light: UIColor(hexString: "#FB89DE")!,
                                    dark: UIColor(hexString: "#FB89DE")!)
    }
    
    struct Path {
        static let Document = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        static var Data: String {
            let path = Document.appendingPathComponent("Datas")
            if !FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            }
            return path
        }
        static let Library = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
        static let Cache = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        static let Temp = NSTemporaryDirectory()
        static let PasteWorkSpace = Temp.appendingPathComponent("PasteWorkSpace")
        static let UploadWorkSpace = Temp.appendingPathComponent("UploadWorkSpace")
        static let ShareWorkSpace = Temp.appendingPathComponent("ShareWorkSpace")
        static let DownloadWorkSpace = Cache.appendingPathComponent("DownloadWorkSpace")
        static let SMBWorkSpace = Temp.appendingPathComponent("SMBWorkSpace")
        static let DropWorkSpace = Temp.appendingPathComponent("DropWorkSpace")
        static let SaveStateWorkSpace = Temp.appendingPathComponent("SaveStateWorkSpace")
        static let ZipWorkSpace = Temp.appendingPathComponent("ZipWorkSpace")
        static let Realm = Library.appendingPathComponent("Realm")
        static let RealmFilePath = Realm.appendingPathComponent("default.realm")
        static let Resource = Library.appendingPathComponent("System.bundle")
        static let ThreeDS = Document.appendingPathComponent("3DS")
        static let ThreeDSSystemData = ThreeDS.appendingPathComponent("sysdata")
        static let ThreeDSStateLoad = ThreeDS.appendingPathComponent("states")
        static let CitraConfig = ThreeDS.appendingPathComponent("config/config.ini")
        static let CitraDefaultConfig = Resource.appendingPathComponent("3DS.ini")
        static let AzaharConfig = Libretro.appendingPathComponent("config/Azahar/Azahar.opt")
        static let AzaharDefaultConfig = Resource.appendingPathComponent("Azahar.opt")
        static let BoxArtsCache = Cache.appendingPathComponent("BoxArtsCache")
        static let Libretro = Library.appendingPathComponent("Libretro")
        static func PSPCheat(gameCode: String) -> String { Document.appendingPathComponent("PPSSPP/PSP/Cheats/\(gameCode).ini") }
        static let Shaders = Libretro.appendingPathComponent("shaders")
        static let Screenshot = Libretro.appendingPathComponent("screenshots")
        static let PSPSave = Document.appendingPathComponent("PPSSPP/PSP/SAVEDATA")
        static let Nestopia = Document.appendingPathComponent(LibretroCore.Cores.Nestopia.name)
        static let Snes9x = Document.appendingPathComponent(LibretroCore.Cores.Snes9x.name)
        static let PicoDrive = Document.appendingPathComponent(LibretroCore.Cores.PicoDrive.name)
        static let Gearsystem = Document.appendingPathComponent(LibretroCore.Cores.Gearsystem.name)
        static let ClownMDEmu = Document.appendingPathComponent(LibretroCore.Cores.ClownMDEmu.name)
        static let Yabause = Document.appendingPathComponent(LibretroCore.Cores.Yabause.name)
        static let BeetleSaturn = Document.appendingPathComponent(LibretroCore.Cores.BeetleSaturn.name)
        static let Mupen64PlushNext = Document.appendingPathComponent(LibretroCore.Cores.Mupen64PlushNext.name)
        static let BIOS = Document.appendingPathComponent("BIOS")
        static let System = Libretro.appendingPathComponent("system")
        static let DSSavePath = ThreeDS.appendingPathComponent("sdmc/saves/nds")
        static let GBASavePath = ThreeDS.appendingPathComponent("sdmc/saves/gba")
        static let GBCSavePath = ThreeDS.appendingPathComponent("sdmc/saves/gbc")
        static let GBSavePath = ThreeDS.appendingPathComponent("sdmc/saves/gb")
        static let BeetleVB = Document.appendingPathComponent(LibretroCore.Cores.BeetleVB.name)
        static let PokeMini = Document.appendingPathComponent(LibretroCore.Cores.PokeMini.name)
        static let BeetlePSXHW = Document.appendingPathComponent(LibretroCore.Cores.BeetlePSXHW.name)
        static let Flycast = Document.appendingPathComponent(LibretroCore.Cores.Flycast.name)
        static let bsnes = Document.appendingPathComponent(LibretroCore.Cores.bsnes.name)
        static let MAME = Document.appendingPathComponent(LibretroCore.Cores.MAME.name)
        static var PrBoom: String {
            let path = Document.appendingPathComponent(LibretroCore.Cores.PrBoom.name)
            if !FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            }
            return path
        }
        static let Stella = Document.appendingPathComponent(LibretroCore.Cores.Stella.name)
        static let Atari800 = Document.appendingPathComponent(LibretroCore.Cores.Atari800.name)
        static let ProSystem = Document.appendingPathComponent(LibretroCore.Cores.ProSystem.name)
        static let VirtualJaguar = Document.appendingPathComponent(LibretroCore.Cores.VirtualJaguar.name)
        static let Holani = Document.appendingPathComponent(LibretroCore.Cores.Holani.name)
        static let LibretroSavePath = Document
        static let GamesDB = Resource.appendingPathComponent("Games.db")
        static let MAMEDB = Resource.appendingPathComponent("MAME.db")
        static let Assets = Document.appendingPathComponent("Assets")
        static var GameListBackground: String = {
            var backgroundImageName = ""
            if UIDevice.isPhone {
                backgroundImageName = "iphone"
            } else if UIDevice.isPad {
                backgroundImageName = "ipad"
            }
            return Assets.appendingPathComponent(backgroundImageName + "_background.png")
        }()
        static let GameplayManuals = Document.appendingPathComponent("Manuals")
        static let NESPalettes = Resource.appendingPathComponent("NESPalettes")
        static let CustomPalettes = Document.appendingPathComponent("Palettes")
        static let ShaderDefault = Shaders.appendingPathComponent("default")
        static let ShaderRetroArch = Shaders.appendingPathComponent("retroarch")
        static let ShaderRetroArchGLSL = ShaderRetroArch.appendingPathComponent("glsl")
        static let ShaderRetroArchSlang = ShaderRetroArch.appendingPathComponent("slang")
        static let ShaderImported = Shaders.appendingPathComponent("imported")
        static let ShaderImportedInDocument = Document.appendingPathComponent("Shaders")
        static let JGenesis = Resource.appendingPathComponent("jgenesis")
        static let RomPatcher = Resource.appendingPathComponent("RomPatcher")
    }
    
    struct DefaultKey {
        static let HasShowPrivacyAlert = "HasShowPrivacyAlert"
        static let AppGroupName = "group.aoshuang.ManicEmu"
        static let AppGroupIsPremiumKey = "AppGroupIsPremiumKey"
        static let HasShowCheatCodeWarning = "HasShowCheatCodeWarning"
        static let HadSavedSnapshot = "HadSavedSnapshot"
        static let ShowRequestReviewDate = "ShowRequestReviewDate"
        static let SystemCoreVersion = "SystemCoreVersion"
        static let SystemCoreBuildVersion = "SystemCoreBuildVersion"
        static let SystemCoreBundleSize = "SystemCoreBundleSize"
        static let HasShow3DSPlayAlert = "HasShow3DSPlayAlert"
        static let HasShow3DSNotSupportAlert = "HasShow3DSNotSupportAlert"
        static let FlexSkinFirstTimeGuide = "FlexSkinFirstTimeGuide"
        static let HasShowSSPlayAlert = "HasShowSSPlayAlert"
        static let HasShowPS1PlayAlert = "HasShowPS1PlayAlert"
        static let HasShowJumpGameInfoAlert = "HasShowJumpGameInfoAlert"
        static let Appearance = "Appearance"
        static let HasShowPlayCasePromo = "HasShowPlayCasePromo"
        static let HasImportedPlayCaseSkin = "HasImportedPlayCaseSkin"
    }
    
    struct Font {
        enum Size { case s, m, l}
        
        /// title
        /// - Parameters:
        ///   - size: s: 17 m: 18 l: 24
        ///   - weight: 默认medium
        /// - Returns: UIFont
        static func title(size: Size = .l, weight: UIFont.Weight = .bold) -> UIFont {
            switch size {
            case .s:
                UIFont.systemFont(ofSize: 17, weight: weight)
            case .m:
                UIFont.systemFont(ofSize: 18, weight: weight)
            case .l:
                UIFont.systemFont(ofSize: 24, weight: weight)
            }
        }
        
        /// body
        /// - Parameters:
        ///   - size: s: 13 m: 14 l: 15
        ///   - weight: 默认regular
        /// - Returns: UIFont
        static func body(size: Size = .s, weight: UIFont.Weight = .regular) -> UIFont {
            switch size {
            case .s:
                UIFont.systemFont(ofSize: 13, weight: weight)
            case .m:
                UIFont.systemFont(ofSize: 14, weight: weight)
            case .l:
                UIFont.systemFont(ofSize: 15, weight: weight)
            }
        }
        
        /// caption
        /// - Parameters:
        ///   - size: s: 8 m: 10 l: 12
        ///   - weight: 默认regular
        /// - Returns: UIFont
        static func caption(size: Size = .m, weight: UIFont.Weight = .regular) -> UIFont {
            switch size {
            case .s:
                UIFont.systemFont(ofSize: 8, weight: weight)
            case .m:
                UIFont.systemFont(ofSize: 10, weight: weight)
            case .l:
                UIFont.systemFont(ofSize: 12, weight: weight)
            }
        }
    }
    
    struct Strings {
        static let SupportEmail = "support@manicemu.site"
        static let MemberKeyChainKey = "MemberKeyChainKey"
        static let OAuthCallbackHost = "manicemu-oauth"
        static let OAuthGoogleDriveCallbackHost = "com.googleusercontent.apps.177622908853-bkjvno7a5v14obn3rn70s264afrll6p7"
        static let OAuthOneDriveCallbackHost = "msauth.com.aoshuang.manicemu"
        static let TimeFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        static let FileNameTimeFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        static let PlayPurchaseAlertIdentifier = "PlayPurchaseAlertIdentifier"
        static let PSPConsoleLanguage = ["Automatic", "English", "日本語", "Français", "Español", "Deutsch", "Italiano", "Nederlands", "Português", "Русский", "한국어", "繁體中文", "简体中文"]
        static let ThreeDSConsoleLanguage = ["Automatic", "Japan", "USA" , "Europe", "Australia", "China", "Korea", "Taiwan"]
        static let SaturnConsoleLanguage = ["Auto Detect", "Japan", "North America", "Europe", "South Korea", "Asia (NTSC)", "Asia (PAL)", "Brazil", "Latin America"]
        static let DSConsoleLanguage = ["Auto", "Japanese", "English", "French", "German", "Italian", "Spanish"]
        static let DCConsoleLanguage = ["Default", "Japanese", "English", "German",  "French",  "Spanish", "Italian"]
        static let ManicScheme = "manicemu"
        static var PSXController = "PlayStation Controller"
        static var PSXDualShock = "DualShock"
        static var ThreeDSHomeMenuRegions = ["JPN", "USA", "EUR", "CHN", "KOR", "TWN"]
        static let MAMEBiosTitle = "MAME BIOS"
        static let GLSLShader = "shaders_glsl.zip"
        static let SlangShader = "shaders_slang.zip"
        static let AppendedShaders = "MANIC_EMU_PRESET_LIST"
        static let ShaderForceBase = "MANIC_EMU_FORCE_BASE"
        static let MeloNXScheme = "atariemulator"
    }
    
    enum Config {
        static let AppName: String = value(forKey: "CFBundleDisplayName")
        static let AppVersion: String = value(forKey: "CFBundleShortVersionString")
        static let AppBuildVersion: String = value(forKey: "CFBundleVersion")
        static let AppIdentifier: String = value(forKey: "CFBundleIdentifier")
        static func value<T>(forKey key: String) -> T {
            guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? T else {
                fatalError("Invalid value or undefined key")
            }
            return value
        }
        static var PlatformOrder: [String]? = nil
        static var DefaultOrientation: UIInterfaceOrientationMask {
            UIDevice.isPad ? .all : .allButUpsideDown
        }
    }
    
    struct Numbers {
        /// 游戏页面功能按钮个数
        static let GameFunctionButtonCount = 4
        /// 游戏截图发大倍数
        static let GameSnapshotScaleRatio = 5.0
        /// 自动存档间隔 秒
        static let AutoSaveGameDuration = 120
        /// 自动存档最大个数
        static var AutoSaveGameCount: Int {
            PurchaseManager.isMember ? 50 : 3
        }
        /// 非会员手动存档最大个数
        static var NonMemberManualSaveGameCount = 3
        /// 随机游戏功能最少需要多少个游戏
        static let RandomGameLimit = 10
        ///非会员最大金手指数量
        static let NonMemberCheatCodeCount = 3
        ///非会员最大TriggerPro数量
        static let NonMemberTriggerProCount = 10
        /// 动画执行时间
        static let LongAnimationDuration = 1.0
        ///主题颜色最大数量
        static let ThemeColorMaxCount = 5
        
        static let ThreeDSHomeMenuIdentifiers: [UInt64] = [1126106065306114, 1126106065309442, 1126106065311746, 1126106065314050, 1126106065316098, 1126106065318146]
        
        static let PKSMIdentifier: UInt64 = 1125900154372096
    }
    
    struct NotificationName {
        ///购买成功
        static let PurchaseSuccess = NSNotification.Name(rawValue: "PurchaseSuccess")
        ///切换homeBar object是BarSelection
        static let HomeSelectionChange = NSNotification.Name(rawValue: "HomeSelectionChange")
        ///会员资格变化
        static let MembershipChange = NSNotification.Name(rawValue: "MembershipChange")
        ///商品更新成功
        static let ProductsUpdate = NSNotification.Name(rawValue: "ProductsUpdate")
        ///开始游戏
        static let StartPlayGame = NSNotification.Name(rawValue: "StartPlayGame")
        ///结束游戏
        static let StopPlayGame = NSNotification.Name(rawValue: "StopPlayGame")
        ///控制器映射更新
        static let ControllerMapping = NSNotification.Name(rawValue: "ControllerMapping")
        ///下载状态通知
        static let BeginDownload = NSNotification.Name(rawValue: "BeginDownload")
        static let StopDownload = NSNotification.Name(rawValue: "StopDownload")
        ///主题颜色变更
        static let GradientColorChange = NSNotification.Name(rawValue: "GradientColorChange")
        static let MainColorChange = NSNotification.Name(rawValue: "MainColorChange")
        ///游戏封面样式变更
        static let GameCoverChange = NSNotification.Name(rawValue: "GameCoverChange")
        ///游戏平台顺序更新
        static let PlatformOrderChange = NSNotification.Name(rawValue: "PlatformOrderChange")
        //游戏平台切换更新
        static let PlatformSelectionChange = NSNotification.Name(rawValue: "PlatformSelectionChange")
        ///游戏列表变更
        static let GameListStyleChange = NSNotification.Name(rawValue: "GameListStyleChange")
        ///shake
        static let MotionShake = NSNotification.Name(rawValue: "MotionShake")
        ///退出游戏
        static let QuitGaming = NSNotification.Name(rawValue: "QuitGaming")
        ///关闭硬核模式
        static let TurnOffHardcore = NSNotification.Name(rawValue: "TurnOffHardcore")
        ///游戏排序更新
        static let GameSortChange = NSNotification.Name(rawValue: "GameSortChange")
        ///成就解锁进度常驻关闭
        static let TurnOffAlwaysShowProgress = NSNotification.Name(rawValue: "TurnOffAlwaysShowProgress")
        //游戏库背景变更
        static let GameListBackgroundChange = NSNotification.Name(rawValue: "GameListBackgroundChange")
        //iCloud同步状态变更
        static let iCloudDriveSyncChange = NSNotification.Name(rawValue: "iCloudDriveSyncChange")
        //iCloud开关变更
        static let iCloudEnableChange = NSNotification.Name(rawValue: "iCloudEnableChange")
        //厂商分类变更通知
        static let ManufacturerFilterChange = NSNotification.Name(rawValue: "ManufacturerFilterChange")
        //RetroArch的着色器下载成功
        static let RetroArchShadersDownloadSuccess = NSNotification.Name(rawValue: "RetroArchShadersDownloadSuccess")
    }
    
    struct URLs {
        #if DEBUG
        static let ManicEMU = "http://10.10.10.2:4000/"
        #else
        static let ManicEMU = "https://manicemu.site/"
        #endif
        static let AppReview = URL(string: "itms-apps://itunes.apple.com/app/id6743335790?action=write-review")!
        static let AppStoreUrl = URL(string: "https://apps.apple.com/app/id6743335790")!
        static let TermsOfUse = URL(string: ManicEMU + "terms-of-use")!
        static let PrivacyPolicy = URL(string: ManicEMU + "privacy-policy")!
        static let PaymentTerms = URL(string: ManicEMU + "Payment-Terms")!
        static var FAQ: URL {
            Locale.prefersCN ? URL(string: ManicEMU + "FAQ-CN")! : URL(string: ManicEMU + "FAQ-EN")!
        }
        static var GameImportGuide: URL {
            Locale.prefersCN ? URL(string: ManicEMU + "Game-Import-Guide-CN")! : URL(string: ManicEMU + "Game-Import-Guide-EN")!
        }
        static var SkinUsageGuide: URL {
            Locale.prefersCN ? URL(string: ManicEMU + "Skin-Usage-Guide-CN")! : URL(string: ManicEMU + "Skin-Usage-Guide-EN")!
        }
        static var ControllerUsageGuide: URL {
            Locale.prefersCN ? URL(string: ManicEMU + "Controller-Usage-Guide-CN")! : URL(string: ManicEMU + "Controller-Usage-Guide-EN")!
        }
        static var CheatCodesGuide: URL {
            Locale.prefersCN ? URL(string: ManicEMU + "Cheat-Codes-Guide-CN")! : URL(string: ManicEMU + "Cheat-Codes-Guide-EN")!
        }
        static var AirPlayUsageGuide: URL {
            Locale.prefersCN ? URL(string: ManicEMU + "AirPlay-Usage-Guide-CN")! : URL(string: ManicEMU + "AirPlay-Usage-Guide-EN")!
        }
        static func manufacturer(_ manufacturer: Manufacturer) -> URL {
            return URL(string: ManicEMU + "Manufacturer-" + manufacturer.title + "-EN")!
        }
        static var JoinQQ: URL {
            URL(string: "https://pd.qq.com/s/7i1g6jf5k")!
        }
//        static var JoinTelegram: URL {
//            URL(string: "https://t.me/+R56rb3Sa9hM0YjEx")!
//        }
        static var JoinDiscord: URL {
            URL(string: "https://discord.gg/qsaTHzknAZ")!
        }
        static func DeltaStyles(gameType: GameType) -> URL {
            let deltastyles = "https://deltastyles.com"
            switch gameType {
            case .nes, .fds: return URL(string: "\(deltastyles)/systems/nes")!
            case .snes: return URL(string: "\(deltastyles)/systems/snes")!
            case .gbc: return URL(string: "\(deltastyles)/systems/gbc")!
            case .gb: return URL(string: "\(deltastyles)/systems/gbc")!
            case .gba: return URL(string: "\(deltastyles)/systems/gba")!
            case .ds: return URL(string: "\(deltastyles)/systems/nds")!
            case ._3ds: return URL(string: "\(deltastyles)/systems/3ds")!
            case .n64: return URL(string: "\(deltastyles)/systems/n64")!
            case .psp: return URL(string: "\(deltastyles)/systems/psp")!
            case .md: return URL(string: "\(deltastyles)/systems/genesis")!
            case .mcd: return URL(string: "\(deltastyles)/systems/cd")!
            case ._32x: return URL(string: "\(deltastyles)/systems/32x")!
            case .sg1000: return URL(string: "\(deltastyles)/systems/sg1000")!
            case .gg: return URL(string: "\(deltastyles)/systems/gamegear")!
            case .ms: return URL(string: "\(deltastyles)/systems/ms")!
            case .ss: return URL(string: "\(deltastyles)/systems/saturn")!
            case .vb: return URL(string: "\(deltastyles)/systems/virtualboy")!
            case .ps1: return URL(string: "\(deltastyles)/systems/ps1")!
            case .dc: return URL(string: "\(deltastyles)/systems/dreamcast")!
            case .arcade: return URL(string: "\(deltastyles)/systems/arcade")!
            default: return URL(string: deltastyles)!
            }
        }
        static func History(gameType: GameType) -> URL {
            return URL(string: ManicEMU + "History-" + (gameType == .gb ? GameType.gbc.localizedShortName : gameType.localizedShortName) + "-EN")!
        }
        static let WFC = URL(string: "https://cdn.altstore.io/file/deltaemulator/delta/wfc-servers.json")!
        #if SIDE_LOAD
        static let Donate = URL(string: "https://ko-fi.com/maftymanicemu")!
        #endif
        static let AboutUS = URL(string: ManicEMU + "About-US")!
        static let RetroSignUp = URL(string: "https://retroachievements.org/createaccount.php")!
        static func RetroProfile(username: String) -> URL {
            return URL(string: "https://retroachievements.org/user/\(username)")!
        }
        static let Retro = URL(string: "https://retroachievements.org")!
        static let MobyGames = URL(string: "https://www.mobygames.com")!
        static let InstallSideload = URL(string: "sidestore://source?url=https://apps.manicemu.site/altstore")!
        static let SideStore = URL(string: "https://sidestore.io")!
        static let GLSLShaders = URL(string: "https://buildbot.libretro.com/assets/frontend/shaders_glsl.zip")!
        static let SlangShaders = URL(string: "https://buildbot.libretro.com/assets/frontend/shaders_slang.zip")!
        static let PlayCasePromo = URL(string: "https://playcase.gg/playmanic")!
        static let FetchMeloNXGames = URL(string: "\(Constants.Strings.MeloNXScheme)://gameInfo?scheme=manicemu")!
        static func MeloNXGameLaunch(gameId: String) -> URL { URL(string: "\(Constants.Strings.MeloNXScheme)://game?id=\(gameId)")! }
    }
    
    struct BIOS {
        static let MegaCDBios = [
            BIOSItem(fileName: "bios_CD_E.bin", imported: false, desc: "MegaCD EU BIOS", required: true),
            BIOSItem(fileName: "bios_CD_U.bin", imported: false, desc: "SegaCD US BIOS", required: true),
            BIOSItem(fileName: "bios_CD_J.bin", imported: false, desc: "MegaCD JP BIOS", required: true)
        ]
        
        static let SaturnBios = [
            BIOSItem(fileName: "saturn_bios.bin", imported: false, desc: "Yabause Saturn BIOS", required: false),
            BIOSItem(fileName: "sega_101.bin", imported: false, desc: "Beetle Saturn JP BIOS for JP games", required: true),
            BIOSItem(fileName: "mpr-17933.bin", imported: false, desc: "Beetle Saturn US.mdEU BIOS for US/EU games", required: true),
            BIOSItem(fileName: "mpr-18811-mx.ic1", imported: false, desc: "The King of Fighters '95 ROM Cartridge", required: false),
            BIOSItem(fileName: "mpr-19367-mx.ic1", imported: false, desc: "Ultraman: Hikari no Kyojin Densetsu ROM Cartridge", required: false),
        ]
        
        static let DSBios = [
            BIOSItem(fileName: "bios7.bin", imported: false, desc: "NDS ARM7 BIOS", required: false),
            BIOSItem(fileName: "bios9.bin", imported: false, desc: "NDS ARM9 BIOS", required: false),
            BIOSItem(fileName: "firmware.bin", imported: false, desc: "NDS Firmware", required: false),
            BIOSItem(fileName: "dsi_bios7.bin", imported: false, desc: "DSi ARM7 BIOS - Required in DSi mode", required: false),
            BIOSItem(fileName: "dsi_bios9.bin", imported: false, desc: "DSi ARM9 BIOS - Required in DSi mode", required: false),
            BIOSItem(fileName: "dsi_firmware.bin", imported: false, desc: "DSi Firmware - Required in DSi mode", required: false),
            BIOSItem(fileName: "dsi_nand.bin", imported: false, desc: "DSi NAND - Required in DSi mode", required: false)
        ]
        
        static let PS1Bios = [
            BIOSItem(fileName: "ps1_rom.bin", imported: false, desc: "Comes from the PS3, region-free", required: false),
            BIOSItem(fileName: "PSXONPSP660.bin", imported: false, desc: "Comes from the PSP, region-free", required: false),
            BIOSItem(fileName: "scph5500.bin", imported: false, desc: "PS1 JP BIOS - Required for JP games", required: false),
            BIOSItem(fileName: "scph5501.bin", imported: false, desc: "PS1 US BIOS - Required for US games", required: false),
            BIOSItem(fileName: "scph5502.bin", imported: false, desc: "PS1 EU BIOS - Required for EU games", required: false)
        ]
        
        static let DCBios = [
            BIOSItem(fileName: "dc_boot.bin", imported: false, desc: "Required for Dreamcast", required: false)
        ]
        
        static let GBBios = [
            BIOSItem(fileName: "gb_bios.bin", imported: false, desc: "Game Boy BIOS", required: false)
        ]
        
        static let GBCBios = [
            BIOSItem(fileName: "gbc_bios.bin", imported: false, desc: "Game Boy Color BIOS", required: false)
        ]
        
        static let GBABios = [
            BIOSItem(fileName: "gba_bios.bin", imported: false, desc: "Game Boy Advance BIOS", required: false)
        ]
            
        static let FDSBios = [
            BIOSItem(fileName: "disksys.rom", imported: false, desc: "Family Computer Disk System BIOS", required: false)
        ]
        
        static let PMBios = [
            BIOSItem(fileName: "bios.min", imported: false, desc: "Pokémon Mini BIOS", required: false)
        ]
        
        static let ThreeDSBios = [
            BIOSItem(fileName: "nand.zip", imported: false, desc: "The internal storage of 3DS ", required: false)
        ]
        
        static let ArcadeDSBios = [
            BIOSItem(fileName: Strings.MAMEBiosTitle, imported: false, desc: R.string.localizable.mameBiosDesc(), required: false)
        ]
        
        static var MAMEBiosMap: [String: String] {
            //Source: MAME 0.282 (arcade).dat
            ["3dobios.zip" : "3DO BIOS",
             "airlbios.zip" : "NAOMI Airline Pilots (deluxe) BIOS",
             "aleck64.zip" : "Aleck64 PIF BIOS",
             "alg3do.zip" : "ALG 3DO BIOS",
             "alg_bios.zip" : "American Laser Games BIOS",
             "allied.zip" : "Allied System",
             "ar_bios.zip" : "Arcadia System BIOS",
             "aristmk5.zip" : "MKV Set-Clear Chips (US)",
             "aristmk6.zip" : "MK6 System Software-Setchips",
             "aristmk7.zip" : "Aristocrat MK-7 BIOS",
             "atarisy1.zip" : "Atari System 1 BIOS",
             "awbios.zip" : "Atomiswave BIOS",
             "bubsys.zip" : "Bubble System BIOS",
             "cdibios.zip" : "CD-i (Mono-I) (PAL) BIOS",
             "cedmag.zip" : "Magnet System",
             "chihiro.zip" : "Chihiro BIOS",
             "coh1000a.zip" : "Acclaim ZN-1",
             "coh1000c.zip" : "Capcom ZN-1",
             "coh1000t.zip" : "Taito FX-1",
             "coh1000w.zip" : "Time Warner ZN-1",
             "coh1001l.zip" : "Atlus ZN-1",
             "coh1002e.zip" : "Eighting - Raizing ZN-1",
             "coh1002m.zip" : "Tecmo TPS System",
             "coh1002t.zip" : "Taito G NET (COH-1002T)",
             "coh1002v.zip" : "Video System ZN-1",
             "coh3002c.zip" : "Capcom ZN-2",
             "coh3002t.zip" : "Taito G NET (COH-3002T)",
             "crysbios.zip" : "Crystal System BIOS",
             "cubo.zip" : "Cubo BIOS",
             "decocass.zip" : "DECO Cassette System",
             "f355bios.zip" : "NAOMI Ferrari F355 Challenge (twin-deluxe) BIOS",
             "f355dlx.zip" : "NAOMI Ferrari F355 Challenge (deluxe) BIOS",
             "galgbios.zip" : "Galaxy Games BIOS",
             "genpin.zip" : "genpin",
             "gp_110.zip" : "Model 110",
             "gq863.zip" : "Twinkle System",
             "gts1.zip" : "System 1",
             "hikaru.zip" : "Hikaru BIOS",
             "hng64.zip" : "Hyper NeoGeo 64 BIOS",
             "hod2bios.zip" : "NAOMI The House of the Dead 2 BIOS",
             "isgsm.zip" : "ISG Selection Master Type 2006 BIOS",
             "iteagle.zip" : "Eagle BIOS",
             "konamigv.zip" : "Baby Phoenix-GV System",
             "konamigx.zip" : "System GX",
             "konendev.zip" : "Konami Endeavour BIOS",
             "kpython.zip" : "Konami Python BIOS",
             "kpython2.zip" : "Konami Python 2 BIOS",
             "kviper.zip" : "Konami Viper BIOS",
             "lindbios.zip" : "Sega Lindbergh BIOS",
             "mac2bios.zip" : "Multi Amenity Cassette System 2 BIOS",
             "macsbios.zip" : "Multi Amenity Cassette System BIOS",
             "maxaflex.zip" : "Max-A-Flex",
             "megaplay.zip" : "Mega Play BIOS",
             "megatech.zip" : "Mega-Tech",
             "miuchiz.zip" : "Miuchiz Virtual Companions common BIOS",
             "naomi.zip" : "NAOMI BIOS",
             "naomi2.zip" : "NAOMI 2 BIOS",
             "naomigd.zip" : "NAOMI GD-ROM BIOS",
             "neogeo.zip" : "Neo-Geo MV-6F",
             "nichidvd.zip" : "Nichibutsu High Rate DVD BIOS",
             "nss.zip" : "Nintendo Super System BIOS",
             "pgm.zip" : "PGM (Polygame Master) System BIOS",
             "playch10.zip" : "PlayChoice-10 BIOS",
             "pumpitup.zip" : "Pump It Up BIOS",
             "recel.zip" : "Recel BIOS",
             "sammymdl.zip" : "Sammy Medal Game System BIOS",
             "segasp.zip" : "Sega System SP (Spider) BIOS",
             "sfcbox.zip" : "Super Famicom Box BIOS",
             "shtzone.zip" : "Shooting Zone System BIOS",
             "skns.zip" : "Super Kaneko Nova System BIOS",
             "stvbios.zip" : "ST-V BIOS",
             "su2000.zip" : "SU2000",
             "sys246.zip" : "System 246 BIOS",
             "sys256.zip" : "System 256 BIOS",
             "sys573.zip" : "System 573 BIOS",
             "systemy2.zip" : "System Board Y2",
             "taitotz.zip" : "Type Zero BIOS",
             "tourvis.zip" : "TourVisión (PC Engine bootleg)",
             "triforce.zip" : "Triforce BIOS",
             "v4bios.zip" : "MPU4 Video Firmware"]
        }
        
        static let A5200Bios = [
            BIOSItem(fileName: "5200.rom", imported: false, desc: "5200 BIOS", required: false)
        ]
        
        static let A7800Bios = [
            BIOSItem(fileName: "7800 BIOS (U).rom", imported: false, desc: "7800 BIOS", required: false)
        ]
        
        static let LynxBios = [
            BIOSItem(fileName: "lynxboot.img", imported: false, desc: "Lynx Boot Image", required: false)
        ]
    }
}
