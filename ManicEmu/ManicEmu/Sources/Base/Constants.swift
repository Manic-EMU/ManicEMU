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

extension _R {
    var Size: _Size.Type { _Size.self }
    var Color: _Color.Type { _Color.self }
    var Path: _Path.Type { _Path.self }
    var DefaultKey: _DefaultKey.Type { _DefaultKey.self }
    var Font: _Font.Type { _Font.self }
    var Strings: _Strings.Type { _Strings.self }
    var Config: _Config.Type { _Config.self }
    var Numbers: _Numbers.Type { _Numbers.self }
    var NotificationName: _NotificationName.Type { _NotificationName.self }
    var URLs: _URLs.Type { _URLs.self }
    var BIOS: _BIOS.Type { _BIOS.self }
    var Style: _Style.Type { _Style.self }
    var Cipher: _Cipher.Type { _Cipher.self }
}

extension _R {
    struct _Size {
        //系统常用尺寸
        static var WindowSize: CGSize { UIWindow.applicationWindow?.bounds.size ?? .zero }
        static var WindowWidth: CGFloat { WindowSize.width }
        static var WindowHeight: CGFloat { WindowSize.height }
        static var SafeArea: UIEdgeInsets { UIWindow.applicationWindow?.safeAreaInsets ?? .zero}
        static var TopWindowSafeArea: UIEdgeInsets { UIWindow.topWindow?.safeAreaInsets ?? .zero}
        static var PresentationTop: CGFloat { UIDevice.isPhone ? (UIDevice.hasNotch ? 69 : 40) : 0 }
        
        ///符号图标size 18
        static let SymbolSize = 18.0
        
        ///HomeTabBarSize 300x60
        static let HomeTabBarSize = CGSize(width: 300, height: ItemHeightLarge)
        /// 侧边视图宽度
        static let SideMenuWidth = UIDevice.isPhone ? WindowSize.minDimension * 0.874 : 300
        /// 游戏封面宽高比 默认1:1
        static func GameCoverRatio(gameType: GameType, ignoreForceSquare: Bool = false) -> CGFloat {
            if R.Style.GameCoverForceSquare && !ignoreForceSquare {
                return 1.0
            }
            var style = R.Style.GameCoverStyle
            if ignoreForceSquare {
                style = .style1 
            }
            switch style {
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
                case .xbox360: return 0.7062
                case .j2me: return 0.75
                case .dos, .win95, .win98: return 0.8
                case .chm: return 0.7908
                case .xbox: return 0.714
                case .ps2: return 0.711
                case .ngc, .wii: return 0.706
                case .ngp, .ngpc: return 0.8594
                case .wsc: return 0.6799
                case .ws: return 0.8063
                case .c64: return 0.7146
                case .amiga: return 0.7052
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
            let safeArea = R.Size.SafeArea
            return safeArea.top > 0 ? safeArea.top : R.Size.ContentSpaceLarge
        }
        
        ///CollectionView的bottom缩进
        static var ContentInsetBottom: CGFloat {
            let safeArea = R.Size.SafeArea
            return safeArea.bottom > 0 ? safeArea.bottom : R.Size.ContentSpaceLarge
        }
        
        ///苹果图标默认尺寸
        static func AppleIconCornerRadius(height: CGFloat) -> CGFloat {
            return 10/57 * height
        }
        
        static var GamesToolViewHeight: CGFloat {
            let enableFilter = Theme.defalut.enableManufacturerFilter
            return R.Size.ContentSpaceExtraSmall +
            R.Size.ItemHeightTiny +
            R.Size.ContentSpaceExtraSmall +
            (enableFilter ? R.Size.ContentSpaceTiny + R.Size.ItemHeightMicro + R.Size.ContentSpaceMedium : 0)
        }
        
        //MARK Spacing
        ///24.0
        static let ContentSpaceHuge = 24.0
        ///20.0
        static let ContentSpaceLarge = 20.0
        ///16.0
        static let ContentSpaceMedium = 16.0
        ///12.0
        static let ContentSpaceSmall = 12.0
        ///8.0
        static let ContentSpaceExtraSmall = 8.0
        ///6.0
        static let ContentSpaceExtraExtraSmall = 6.0
        ///4.0
        static let ContentSpaceTiny = 4.0
        ///2.0
        static let ContentSpaceMicro = 2.0
        
        //MARK: - Padding Size
        ///12.0
        static let PaddingLarge = 12.0
        ///8.0
        static let PaddingMedium = 8.0
        ///4.0
        static let PaddingSmall = 4.0
        ///2.0
        static let PaddingExtraSmall = 2.0
        
        //MARK: - Button Size
        ///50.0
        static let ButtonExtraLarge = 50.0
        ///44.0
        static let ButtonLarge = 44.0
        ///40.0
        static let ButtonMedium = 40.0
        ///36.0
        static let ButtonSmall = 36.0
        ///30.0
        static let ButtonExtraSmall = 30.0
        ///24.0
        static let ButtonExtraExtraSmall = 24.0
        ///32x24
        static let ButtonSizeExtraExtraSmall = CGSize(width: 32, height: 24)
        ///20x20 CheckButton RadioButton
        static let ButtonSizeAccessory = CGSize(width: 20, height: 20)
        ///horizontal: 8 vertical: 4
        static let ButtonInsets = UIEdgeInsets(horizontal: R.Size.ContentSpaceExtraSmall*2, vertical: R.Size.ContentSpaceTiny*2)
        ///327.0
        static let ButtonMaxWidth = 327.0
        
        //MARK: - Icon Size
        ///图标尺寸 76x76
        static let IconSizeHuge = CGSize(76)
        ///图标尺寸 36x36
        static let IconSizeExtraLarge = CGSize(36)
        ///图标尺寸 30x30
        static let IconSizeLarge = CGSize(30)
        ///24x24
        static let IconSizeMedium = CGSize(24)
        ///图标尺寸 18x18
        static let IconSizeSmall = CGSize(18)
        ///16x16
        static let IconSizeExtraSmall = CGSize(16)
        
        //MARK: - Border Size
        ///2.0
        static let Border = 1.0
        
        //MARK: - Progress Size
        ///24.0
        static let ProgressLarge = 24.0
        ///4.0
        static let ProgressMedium = 4.0
        ///2.0
        static let ProgressSmall = 2.0
        
        //MARK: - Icon Size
        ///20.0
        static let IconMedium = 20.0
        static let LabelIconSizeToFontSizeRatio = 0.8
        static let ButtonIconSizeToFontSizeRatio = 0.725
        static let IconOffsetRatioInLabel = 0.125
        
        //MARK: - Min Touch Size
        static let MinTouchAreaSize = 44.0
        
        //MARK: - Keyboard
        ///150.0
        static let KeyboardDistance = 150.0
        
        //MARK: Header & Footer
        ///44.0
        static let SupplementaryItemHeight = 44.0
        ///32.0
        static let SupplementaryButtonHeight = 32.0
        
        //MARK: - Navigation
        ///50.0
        static let NavigationHeight = 50.0
        
        //MARK: - Cell
        ///60.0
        static let CellHeight = 60.0
        
        //MARK: - Card
        ///154.0
        static let CardHeight = 154.0
        
        //MARK: - Sheet
        static var SheetWindowMaxSize: CGSize {
            if UIDevice.isPhone {
                if UIDevice.isLandscape {
                    return CGSize(width: WindowHeight, height: WindowHeight - SafeArea.vertical)
                } else {
                    return CGSize(width: WindowWidth, height: WindowHeight - PresentationTop)
                }
            } else if UIDevice.isPad {
                if UIDevice.isLandscape {
                    let height = WindowHeight * 0.9
                    return CGSize(width: height*9/16, height: height)
                } else {
                    let width = WindowWidth*(UIDevice.isPadMini ? 0.65 : 0.5)
                    return CGSize(width: width, height: width*16/9)
                }
            }
            return R.Size.WindowSize
        }
        
        static var SheetWindowMinSize: CGSize {
            let size = SheetWindowMaxSize
            return CGSize(width: size.width, height: 200)
        }
        
        static var SheetFullScreenForIpadLandscape: CGSize {
            let width = WindowWidth*0.8
            return CGSize(width: width, height: width*9/16)
        }
        
        ///12.0
        static var SheetGrabberTopInset = 12.0
        
        //MARK: - CornerRadius
        ///20.0
        static let CornerRadiusLarge = 20.0
        ///16.0
        static let CornerRadiusMedium = 16.0
        ///12.0
        static let CornerRadiusSmall = 12.0
        ///8.0
        static let CornerRadiusTiny = 8.0
        ///6.0
        static let CornerRadiusMicro = 6.0
        
        ///76.0
        static let ItemHeightExtraLarge = 76.0
        ///60.0
        static let ItemHeightLarge = 60.0
        ///50.0
        static let ItemHeightMedium = 50.0
        ///44.0
        static let ItemHeightSmall = 44.0
        ///40.0
        static let ItemHeightExtraSmall = 44.0
        ///36.0
        static let ItemHeightTiny = 36.0
        ///30.0
        static let ItemHeightMicro = 30.0
        
        //MARK: Others
        static var PageBackgroundMaskHeight: CGFloat { ContentInsetTop + ItemHeightMedium }
        
        static let GameInfoGameOptionsTopInsets = 380.0
        
        static let LabelLineSpacing = 2.0
        
        static var PreferredContentSize: CGSize {
            var sheetSize = SheetWindowMaxSize
            if UIDevice.isLandscape {
                sheetSize.height = WindowHeight * 0.79
            }
            return sheetSize
        }
    }
    
    struct _Color {
        //MARK: - Label Color
        /// dark: #ffffff light: #323443
        static let LabelPrimary = UIColor(.dm,
                                          light: UIColor(hexString: "#323443")!,
                                          dark: UIColor(hexString: "#ffffff")!)
        /// dark: #8F8F92 light: #90929F
        static let LabelSecondary = UIColor(.dm,
                                            light: UIColor(hexString: "#90929F")!,
                                            dark: UIColor(hexString: "#8F8F92")!)
        /// dark: #403E46 light: #C7C6CC
        static let LabelTertiary = UIColor(.dm,
                                           light: UIColor(hexString: "#C7C6CC")!,
                                           dark: UIColor(hexString: "#403E46")!)
        
        //MARK: - Border Color
        /// dark: #FFFFFF 5% light: #000000 5%
        static let Border = UIColor(.dm,
                                    light: .black.withAlphaComponent(0.05),
                                    dark: .white.withAlphaComponent(0.05))
        
        //MARK: - Side Menu Color
        /// dark: #121212 light: #C7C6CC
        static let SideList = UIColor(.dm,
                                      light: UIColor(hexString: "#C7C6CC")!,
                                      dark: UIColor(hexString: "#121212")!)
        
        static let Switch = UIColor(.dm,
                                    light: UIColor(hexString: "#E0E0E0")!,
                                    dark: UIColor(hexString: "#35353D")!)
        
        //MARK: - Background
        /// dark: #121212 light: #F2F2F6
        static let BackgroundPrimary = UIColor(.dm,
                                               light: UIColor(hexString: "#F2F2F6")!,
                                               dark: UIColor(hexString: "#121212")!)
        /// dark: #1B1B20 light: #FFFFFF
        static let BackgroundSecondary = UIColor(.dm,
                                                 light: UIColor(hexString: "#FFFFFF")!,
                                                 dark: UIColor(hexString: "#1B1B20")!)
        /// dark: #27272E light: #EEEEEE
        static let BackgroundTertiary = UIColor(.dm,
                                                light: UIColor(hexString: "#EEEEEE")!,
                                                dark: UIColor(hexString: "#27272E")!)
        /// dark: #464651 light: #FFFFFF
        static let BackgroundQuaternary = UIColor(.dm,
                                                  light: UIColor(hexString: "#FFFFFF")!,
                                                  dark: UIColor(hexString: "#464651")!)
        /// dark: #1B1B20 70% light: #FFFFFF 70%
        static let BackgroundQuinary = UIColor(.dm,
                                               light: UIColor(hexString: "#FFFFFF", transparency: 0.7)!,
                                               dark: UIColor(hexString: "#464651", transparency: 0.7)!)
        
        //MARK: - Input Box Color
        /// dark: #101010 light: #E9E9ED
        static let InputBox = UIColor(.dm,
                                      light: UIColor(hexString: "#E9E9ED")!,
                                      dark: UIColor(hexString: "#101010")!)
        
        //MARK: - Vibrant colors
        static var Gradient = [R.Color.Red, R.Color.Orange, R.Color.Purple, R.Color.Indigo]
        
        static var Main: UIColor {
            UIColor { _ in
                ThemeManager.shared.mainColor
            }
        }
        ///#FF2442
        static let Red = UIColor(.dm,
                                 light: UIColor(hexString: "#FF2442")!,
                                 dark: UIColor(hexString: "#FF2442")!.darken(by: 0.1))
        ///#06D58F
        static let Green = UIColor(.dm,
                                   light: UIColor(hexString: "#06D58F")!,
                                   dark: UIColor(hexString: "#06D58F")!.darken(by: 0.1))
        ///#4BE1E5
        static let Cyan = UIColor(.dm,
                                  light: UIColor(hexString: "#4BE1E5")!,
                                  dark: UIColor(hexString: "#4BE1E5")!.darken(by: 0.1))
        ///#33A9FF
        static let Indigo = UIColor(.dm,
                                    light: UIColor(hexString: "#33A9FF")!,
                                    dark: UIColor(hexString: "#33A9FF")!.darken(by: 0.1))
        ///#7984FF
        static let Purple = UIColor(.dm,
                                    light: UIColor(hexString: "#7984FF")!,
                                    dark: UIColor(hexString: "#7984FF")!.darken(by: 0.1))
        ///#FFBC40
        static let Yellow = UIColor(.dm,
                                    light: UIColor(hexString: "#FFBC40")!,
                                    dark: UIColor(hexString: "#FFBC40")!.darken(by: 0.1))
        ///#FF7A71
        static let Magenta = UIColor(.dm,
                                     light: UIColor(hexString: "#FF7A71")!,
                                     dark: UIColor(hexString: "#FF7A71")!.darken(by: 0.1))
        ///#FF9762
        static let Orange = UIColor(.dm,
                                    light: UIColor(hexString: "#FF9762")!,
                                    dark: UIColor(hexString: "#FF9762")!.darken(by: 0.1))
        ///#FB89DE
        static let Pink = UIColor(.dm,
                                  light: UIColor(hexString: "#FB89DE")!,
                                  dark: UIColor(hexString: "#FB89DE")!.darken(by: 0.1))
        
        //MARK: Other colors
        static let Shadow = BackgroundPrimary
        
        static let PressOverlay = UIColor(.dm,
                                          light: .black.withAlphaComponent(0.04),
                                          dark: .white.withAlphaComponent(0.04))
        
        static let CoverSide = UIColor(.dm,
                                       light: UIColor(hexString: "#FFFFFF")!,
                                       dark: UIColor(hexString: "#202026")!)
        
        static let CoverEmpty = UIColor(.dm,
                                        light: UIColor(hexString: "#FAFAFA")!,
                                        dark: UIColor(hexString: "#1B1B20")!)
    }
    
    struct _Path {
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
        static let FilesSync = Library.appendingPathComponent("FilesSync")
        static let FilesSyncIndex = FilesSync.appendingPathComponent("index.json")
        static let FilesSyncPending = FilesSync.appendingPathComponent("pending.json")
        static let ManicSync = Document.appendingPathComponent(".manic-sync")
        static let FilesSyncConflicts = ManicSync.appendingPathComponent("conflicts")
        static let Resource = Library.appendingPathComponent("System.bundle")
        static let ThreeDS = Document.appendingPathComponent("3DS")
        static let ThreeDSSystemData = ThreeDS.appendingPathComponent("sysdata")
        static let ThreeDSStateLoad = ThreeDS.appendingPathComponent("states")
        static let ThreeDSHomeMenuBase = ThreeDS.appendingPathComponent("nand/00000000000000000000000000000000/title/00040030")
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
        static let PSPGame = Document.appendingPathComponent("PPSSPP/PSP/GAME")
        static let Nestopia = Document.appendingPathComponent(EmulationCore.Nestopia.name)
        static let Snes9x = Document.appendingPathComponent(EmulationCore.Snes9x.name)
        static let PicoDrive = Document.appendingPathComponent(EmulationCore.PicoDrive.name)
        static let Gearsystem = Document.appendingPathComponent(EmulationCore.Gearsystem.name)
        static let ClownMDEmu = Document.appendingPathComponent(EmulationCore.ClownMDEmu.name)
        static let Yabause = Document.appendingPathComponent(EmulationCore.Yabause.name)
        static let BeetleSaturn = Document.appendingPathComponent(EmulationCore.BeetleSaturn.name)
        static let Mupen64PlushNext = Document.appendingPathComponent(EmulationCore.Mupen64PlushNext.name)
        static let BIOS = Document.appendingPathComponent("BIOS")
        static let System = Libretro.appendingPathComponent("system")
        static let DSSavePath = ThreeDS.appendingPathComponent("sdmc/saves/nds")
        static let GBASavePath = ThreeDS.appendingPathComponent("sdmc/saves/gba")
        static let GBCSavePath = ThreeDS.appendingPathComponent("sdmc/saves/gbc")
        static let GBSavePath = ThreeDS.appendingPathComponent("sdmc/saves/gb")
        static let BeetleVB = Document.appendingPathComponent(EmulationCore.BeetleVB.name)
        static let PokeMini = Document.appendingPathComponent(EmulationCore.PokeMini.name)
        static let BeetlePSXHW = Document.appendingPathComponent(EmulationCore.BeetlePSXHW.name)
        static let PCSXReArmed = Document.appendingPathComponent(EmulationCore.PCSXReArmed.name)
        static let Flycast = Document.appendingPathComponent(EmulationCore.Flycast.name)
        static let bsnes = Document.appendingPathComponent(EmulationCore.bsnes.name)
        static let MAME = Document.appendingPathComponent(EmulationCore.MAME.name)
        static var PrBoom: String {
            let path = Document.appendingPathComponent(EmulationCore.PrBoom.name)
            if !FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            }
            return path
        }
        static let Stella = Document.appendingPathComponent(EmulationCore.Stella.name)
        static let Atari800 = Document.appendingPathComponent(EmulationCore.Atari800.name)
        static let ProSystem = Document.appendingPathComponent(EmulationCore.ProSystem.name)
        static let VirtualJaguar = Document.appendingPathComponent(EmulationCore.VirtualJaguar.name)
        static let Holani = Document.appendingPathComponent(EmulationCore.Holani.name)
        static let BeetlePCE = Document.appendingPathComponent(EmulationCore.BeetlePCE.name)
        static let BeetleNeoPop = Document.appendingPathComponent(EmulationCore.BeetleNeoPop.name)
        static let BeetleWonderSwan = Document.appendingPathComponent(EmulationCore.BeetleWonderSwan.name)
        static let VICEx64sc = Document.appendingPathComponent(EmulationCore.VICEx64sc.name)
        static let PUAE = Document.appendingPathComponent(EmulationCore.PUAE.name)
        static let LibretroSavePath = Document
        static let GamesDB = Resource.appendingPathComponent("Games.db")
        static let MAMEDB = Resource.appendingPathComponent("MAME.db")
        static let ExtrasDB = Resource.appendingPathComponent("Extras.db")
        static let Assets = Document.appendingPathComponent("Assets")
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
        static let J2meJS = Resource.appendingPathComponent("j2mejs")
        static let Freej2meWeb = Resource.appendingPathComponent("freej2me")
        static let DOSBoxPure = Document.appendingPathComponent(EmulationCore.DOSBoxPure.name)
        static let DOSBoxPureSystem = DOSBoxPure.appendingPathComponent("system")
        static let EKA2L1 = Document.appendingPathComponent(EmulationCore.EKA2L1.name)
        static let EKA2L1DriveE = EKA2L1.appendingPathComponent("data/drives/e")
        static let EKA2L1DriveENGage = EKA2L1DriveE.appendingPathComponent("n-gage")
        static let Dolphin = Document.appendingPathComponent(EmulationCore.Dolphin.name)
        static let DolphinGameSettings = Dolphin.appendingPathComponent("User/GameSettings")
        static let NimbusPath = Resource.appendingPathComponent("Nimbus210")
        static let Nimbus3DSPath = NimbusPath.appendingPathComponent("3ds")
        static let NimbusCiaPath = NimbusPath.appendingPathComponent("cias/nimbus.cia")
        static let GamecubeUser = Dolphin.appendingPathComponent("/User/GC")
        static let GamecubeUserEUR = GamecubeUser.appendingPathComponent("/EUR")
        static let GamecubeUserJAP = GamecubeUser.appendingPathComponent("/JAP")
        static let GamecubeUserUSA = GamecubeUser.appendingPathComponent("/USA")
    }
    
    struct _DefaultKey {
        static let AppGroupName = "group.aoshuang.ManicEmu"
        static let AppGroupIsPremiumKey = "AppGroupIsPremiumKey"
        static let HasShowCheatCodeWarning = "HasShowCheatCodeWarning"
        static let HadSavedSnapshot = "HadSavedSnapshot"
        static let ShowRequestReviewDate = "ShowRequestReviewDate"
        static let SystemCoreVersion = "SystemCoreVersion"
        static let SystemCoreBuildVersion = "SystemCoreBuildVersion"
        static let HasShow3DSNotSupportAlert = "HasShow3DSNotSupportAlert"
        static let HasShowSSPlayAlert = "HasShowSSPlayAlert"
        static let HasShowPS1PlayAlert = "HasShowPS1PlayAlert"
        static let HasShowJumpGameInfoAlert = "HasShowJumpGameInfoAlert"
        static let Appearance = "Appearance"
        static let HasShowPlayCasePromo = "HasShowPlayCasePromo"
        static let HasImportedPlayCaseSkin = "HasImportedPlayCaseSkin"
        static let HasShowFreeJ2meAlert = "HasShowFreeJ2meAlert"
        static let HasShowDolphinCoreAlert = "HasShowDolphinCoreAlert"
        static let HasPolishSkins = "HasPolishSkins"
        static let DisableSecondPrompt = "DisableSecondPrompt"
        static let TipsDefaultKeys: [String] = [HasShowCheatCodeWarning,
                                                ShowRequestReviewDate,
                                                HasShow3DSNotSupportAlert,
                                                HasShowSSPlayAlert,
                                                HasShowPS1PlayAlert,
                                                HasShowJumpGameInfoAlert,
                                                HasShowPlayCasePromo,
                                                HasShowFreeJ2meAlert,
                                                HasShowDolphinCoreAlert,
                                                DisableSecondPrompt]
    }
    
    struct _Font {
        ///24
        static func LargeTitle(emphasis: Bool = false) -> UIFont { UIFont.systemFont(ofSize: 24, weight: emphasis ? .bold : .regular) }
        ///17
        static func Headline(emphasis: Bool = false) -> UIFont { UIFont.systemFont(ofSize: 17, weight: emphasis ? .semibold : .regular) }
        ///15
        static func Body(emphasis: Bool = false) -> UIFont { UIFont.systemFont(ofSize: 15, weight: emphasis ? .medium : .regular) }
        ///14
        static func Body2(emphasis: Bool = false) -> UIFont { UIFont.systemFont(ofSize: 14, weight: emphasis ? .bold : .regular) }
        ///13
        static func Subheadline(emphasis: Bool = false) -> UIFont { UIFont.systemFont(ofSize: 13, weight: emphasis ? .medium : .regular) }
        ///12
        static func Footnote(emphasis: Bool = false) -> UIFont { UIFont.systemFont(ofSize: 12, weight: emphasis ? .medium : .regular) }
        ///11
        static func Caption(emphasis: Bool = false) -> UIFont { UIFont.systemFont(ofSize: 11, weight: emphasis ? .medium : .regular) }
        ///8
        static func Caption2(emphasis: Bool = false) -> UIFont { UIFont.systemFont(ofSize: 8, weight: emphasis ? .medium : .regular) }
        
    }
    
    struct _Strings {
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
        static let DolphinLanguage = ["Japanese", "English", "German", "French", "Spanish", "Italian", "Dutch", "Simplified", "Traditional", "Korean"]
        static let WSwanLanguage = ["English", "Japanese"]
        static let ManicScheme = "manicemu"
        static var PSXController = "PlayStation Controller"
        static var PSXDualShock = "DualShock"
        static var ThreeDSHomeMenuRegions = ["JPN", "USA", "EUR", "AUS", "CHN", "KOR", "TWN"]
        static let MAMEBiosTitle = "MAME BIOS"
        static let GLSLShader = "shaders_glsl.zip"
        static let SlangShader = "shaders_slang.zip"
        static let AppendedShaders = "MANIC_EMU_PRESET_LIST"
        static let ShaderForceBase = "MANIC_EMU_FORCE_BASE"
        static let MeloNXScheme = "atariemulator"
        static let XeniOSScheme = "xenios"
        static let DukeXScheme = "dukex"
        static let ARMSX2Scheme = "armsx2"
        static let J2MEScreenSizes = ["96x65", "96x96", "104x80", "128x128", "132x176", "128x160", "176x208", "176x220", "208x208", "240x320", "320x240", "240x400", "352x416", "360x640", "640x360", "480x800", "800x480"]
        static let DOSKeyboardSkinID = "public.aoshuang.game.dos.standard.keyboard"
        static let AzaharArticBaseGameID = "AzaharArticBase"
        static let WiiControllers = [
            "Classic Controller Pro",
            "Wiimote",
            R.string.localizable.wiimoteSideways(),
            "Wiimote+Nunchuk"
        ]
        static let SymbianEdgeSkinIdentifier = "public.aoshuang.game.symbian.standard.edge"
        static let SymbianEdgeFlexSkinIdentifier = "public.aoshuang.game.symbian.edge.flex"
        static let SymbianSkinIdentifier = "public.aoshuang.game.symbian.standard"
        static let SymbianFlexSkinIdentifier = "public.aoshuang.game.symbian.flex"
        static let WiimoteSkinIdentifier = "public.aoshuang.game.wiimote"
        static let DolphinCPUs = [
            "Manic Interpreter (experimental)",
            "Cached Interpreter (slower)"
        ]
        static let NaomiTitles: Set<String> = ["18wheelro",
                                               "18wheelr",
                                               "18wheelrt",
                                               "18wheels",
                                               "18wheelu",
                                               "airlbios",
                                               "alienfnt",
                                               "alienfnta",
                                               "alpilotj",
                                               "alpilot",
                                               "anpanman2",
                                               "anpanman2a",
                                               "asndynmt",
                                               "asndynmto",
                                               "ausfache",
                                               "azumanga",
                                               "bdrdown",
                                               "beachspi",
                                               "capsnk",
                                               "capsnka",
                                               "capsnkb",
                                               "cfield",
                                               "chocomk",
                                               "cleoftp",
                                               "clubk2k3",
                                               "clubk2kp",
                                               "clubk2kpa",
                                               "clubkcyc",
                                               "clubkcyco",
                                               "clubkprz",
                                               "clubkpzb",
                                               "clubkpzbp",
                                               "clubkrt",
                                               "clubkrta",
                                               "clubkrtc",
                                               "clubkrto",
                                               "confmiss",
                                               "crackndj",
                                               "crakndj2",
                                               "crzytaxi",
                                               "csmash",
                                               "csmasho",
                                               "cspike",
                                               "cvs2mf",
                                               "cvs2",
                                               "cvsgd",
                                               "deathcox",
                                               "deathcoxj",
                                               "deathcoxo",
                                               "derbyo2k",
                                               "derbyoc",
                                               "derbyoc2",
                                               "derbyocw",
                                               "doa2",
                                               "doa2a",
                                               "doa2m",
                                               "dragntra",
                                               "dragntr",
                                               "dragntr2",
                                               "dragntr3",
                                               "drbyocwa",
                                               "drbyocwb",
                                               "drbyocwc",
                                               "drbyocwt",
                                               "dybb99",
                                               "dybbnao",
                                               "dygolf",
                                               "dygolfp",
                                               "f355",
                                               "f355p",
                                               "f355bios",
                                               "f355dlx",
                                               "f355twin",
                                               "f355twinp",
                                               "f355twn2",
                                               "ggram2",
                                               "ggx",
                                               "ggxx",
                                               "ggxxac",
                                               "ggxxrl",
                                               "ggxxrlo",
                                               "ggxxsla",
                                               "gram2000",
                                               "gundmct",
                                               "gundmgd",
                                               "gundmxgd",
                                               "gunsur2",
                                               "gunsur2j",
                                               "gwing2",
                                               "hmgeo",
                                               "hod2bios",
                                               "hopper",
                                               "hotd2",
                                               "hotd2e",
                                               "hotd2o",
                                               "hotd2p",
                                               "ikaruga",
                                               "illvelo",
                                               "inidv3ca",
                                               "inidv3cy",
                                               "initd",
                                               "initdexp",
                                               "initdexpo",
                                               "initdo",
                                               "initdv2e",
                                               "initdv2j",
                                               "initdv2ja",
                                               "initdv2jo",
                                               "initdv3e",
                                               "initdv3j",
                                               "initdv3jb",
                                               "inunoos",
                                               "jambo",
                                               "jingystm",
                                               "karous",
                                               "keyboard",
                                               "kick4csh",
                                               "kingrt66",
                                               "kingrt66p",
                                               "kurucham",
                                               "lupinsho",
                                               "lupinshoo",
                                               "luptype",
                                               "mamonoro",
                                               "manicpnc",
                                               "marstv",
                                               "mazan",
                                               "mazanj",
                                               "mazanu",
                                               "mbaa",
                                               "mbaao",
                                               "meltyb",
                                               "meltybld",
                                               "meltyblo",
                                               "meltybo",
                                               "mj1a",
                                               "mj1b",
                                               "mj1c",
                                               "mj1d",
                                               "mj1e",
                                               "mj1",
                                               "moeru",
                                               "mok",
                                               "monkeyba",
                                               "mushi2k3",
                                               "mushi2k4",
                                               "mushi2k5",
                                               "mushi2k61",
                                               "mushi2k62",
                                               "mushike",
                                               "mushikeo",
                                               "mushikep",
                                               "mushikc",
                                               "mushikk",
                                               "mushi2eo",
                                               "mushik2e",
                                               "mushik2k",
                                               "mushik4e",
                                               "mushik4t",
                                               "mvsc2",
                                               "mvsc2u",
                                               "naomi",
                                               "naomi2",
                                               "naomigd",
                                               "ndcfboxa",
                                               "ngdup23a",
                                               "ngdup23c",
                                               "ngdup23e",
                                               "ninjaslt",
                                               "ninjaslta",
                                               "ninjasltj",
                                               "ninjasltu",
                                               "ntvmys",
                                               "oinori",
                                               "otrigger",
                                               "pjustic",
                                               "pjustica",
                                               "pokasuka",
                                               "pstone",
                                               "pstone2",
                                               "pstone2b",
                                               "psyvar2",
                                               "puyoda",
                                               "puyofev",
                                               "puyofevj",
                                               "puyofevp",
                                               "qmegamis",
                                               "quizqgd",
                                               "radirgy",
                                               "radirgyn",
                                               "radirgyo",
                                               "rhytngk",
                                               "ringouto",
                                               "ringout",
                                               "samba",
                                               "sambaa",
                                               "samba2k",
                                               "sambap",
                                               "senko",
                                               "senkoo",
                                               "senkosp",
                                               "sfz3ugd",
                                               "sgdrvsim",
                                               "sgtetris",
                                               "shaktam",
                                               "shaktamb",
                                               "shaktmsp",
                                               "shangril",
                                               "shikgam2",
                                               "shootopl",
                                               "shootpl",
                                               "shootplm",
                                               "shootplmp",
                                               "shorse",
                                               "shorsem",
                                               "shorsel",
                                               "shors2k1",
                                               "shors2k2",
                                               "shors2k2l",
                                               "shors2k2m",
                                               "shors2k2s",
                                               "shorsep",
                                               "shorsepm",
                                               "shorseps",
                                               "shorsepb",
                                               "shorsepl",
                                               "shorsepr",
                                               "shorseprl",
                                               "shorseprs",
                                               "shorseprvl",
                                               "shorseprvr",
                                               "sl2007",
                                               "slasho",
                                               "slashout",
                                               "smarinef",
                                               "smlg99",
                                               "soulsurf",
                                               "spawn",
                                               "spkrbtl",
                                               "sprtjam",
                                               "ss2005",
                                               "ss2005o",
                                               "sstrkfgt",
                                               "sstrkfgta",
                                               "starseek",
                                               "suchie3",
                                               "takoron",
                                               "tduno",
                                               "tduno2",
                                               "tetkiwam",
                                               "tokyobus",
                                               "totd",
                                               "totdo",
                                               "toukon4",
                                               "toyfight",
                                               "trgheart",
                                               "trghearto",
                                               "trizeal",
                                               "undefeat",
                                               "usagiym",
                                               "vathlete",
                                               "vathletep",
                                               "vf4",
                                               "vf4b",
                                               "vf4cart",
                                               "vf4evo",
                                               "vf4evob",
                                               "vf4evoa",
                                               "vf4evoct",
                                               "vf4o",
                                               "vf4tuned",
                                               "vf4tuneda",
                                               "vf4tunedd",
                                               "virnba",
                                               "virnbao",
                                               "virnbap",
                                               "virnbapa",
                                               "vonot",
                                               "vs2_2ko",
                                               "vs2_2k",
                                               "vstrik3",
                                               "vstrik3c",
                                               "vstrik3co",
                                               "vtenis2c",
                                               "vtennis",
                                               "vtennis2",
                                               "vtennisg",
                                               "wccf116",
                                               "wccf1dup",
                                               "wccf212e",
                                               "wccf234j",
                                               "wccf2chk",
                                               "wccf310j",
                                               "wccf322e",
                                               "wccf331e",
                                               "wccf331j",
                                               "wccf341j",
                                               "wccf400j",
                                               "wccf420e",
                                               "wldkicks",
                                               "wldkicksj",
                                               "wldkicksu",
                                               "wldkickspj",
                                               "wldkickspw",
                                               "wldrider",
                                               "wrungp",
                                               "wrungpo",
                                               "wsbbgd",
                                               "wwfroyal",
                                               "zerogu2",
                                               "zombrvn",
                                               "zombrvne",
                                               "zombrvno",
                                               "zunou"]
        static let AtomiswaveTitles: Set<String> = ["anmlbskt",
                                                    "anmlbskta",
                                                    "awbios",
                                                    "basschal",
                                                    "basschalo",
                                                    "blokpong",
                                                    "claychal",
                                                    "demofist",
                                                    "dirtypig",
                                                    "dolphin",
                                                    "fotns",
                                                    "ftspeed",
                                                    "ggisuka",
                                                    "ggx15",
                                                    "kofnw",
                                                    "kofnwj",
                                                    "kofxi",
                                                    "kov7sprt",
                                                    "maxspeed",
                                                    "mslug6",
                                                    "ngbc",
                                                    "ngbcj",
                                                    "rangrmsn",
                                                    "rumblef",
                                                    "rumblef2",
                                                    "rumblefp",
                                                    "rumblf2p",
                                                    "salmankt",
                                                    "samsptk",
                                                    "sprtshot",
                                                    "sushibar",
                                                    "vfurlong",
                                                    "waidrive",
                                                    "xtrmhnt2",
                                                    "xtrmhunt"]
        static let SegaSPTitles: Set<String> = ["aminosan",
                                                "arajewel",
                                                "arajewelm",
                                                "arajewels",
                                                "bingogal",
                                                "bingogala",
                                                "bingogalb",
                                                "bingogalc",
                                                "bingogals",
                                                "bingopar",
                                                "brickppl",
                                                "btlracer",
                                                "dinoki25",
                                                "dinokich",
                                                "dinoki4",
                                                "dinoking",
                                                "dinokior",
                                                "galilfac",
                                                "isshoni",
                                                "huhimage",
                                                "kazaaan",
                                                "kazaaana",
                                                "kazaaan2",
                                                "kazaaan2c",
                                                "kazaaan2o",
                                                "kingyo",
                                                "kingyoch",
                                                "loveber3",
                                                "loveber3cn",
                                                "lovebero",
                                                "lovebery",
                                                "magicpop",
                                                "manpuku",
                                                "mirworld",
                                                "monomedal",
                                                "ochaken",
                                                "puyomedal",
                                                "segasp",
                                                "shateki",
                                                "spchecksrv",
                                                "tetgiano",
                                                "tetgiant",
                                                "unomedal",
                                                "westdrmg"]
    }
    
    enum _Config {
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
    
    struct _Numbers {
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
        
        static let WebLoadingViewTimeout = 10.0
    }
    
    struct _NotificationName {
        ///购买成功
        static let PurchaseSuccess = NSNotification.Name(rawValue: "PurchaseSuccess")
        ///切换homeBar object是BarSelection
        static let HomeSelectionChange = NSNotification.Name(rawValue: "HomeSelectionChange")
        ///横屏动态背景变更 object是LandscapeBackgroundView.Background? nil表示默认Shader背景
        static let LandscapeBackgroundChange = NSNotification.Name(rawValue: "LandscapeBackgroundChange")
        ///iPhone横屏下全屏Sheet遮挡动态背景 object是Bool true盖住 false离开
        static let LandscapeBackgroundFullscreenSheet = NSNotification.Name(rawValue: "LandscapeBackgroundFullscreenSheet")
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
        //iCloud同步状态变更
        static let iCloudDriveSyncChange = NSNotification.Name(rawValue: "iCloudDriveSyncChange")
        //iCloud开关变更
        static let iCloudEnableChange = NSNotification.Name(rawValue: "iCloudEnableChange")
        //厂商分类变更通知
        static let ManufacturerFilterChange = NSNotification.Name(rawValue: "ManufacturerFilterChange")
        //RetroArch的着色器下载成功
        static let RetroArchShadersDownloadSuccess = NSNotification.Name(rawValue: "RetroArchShadersDownloadSuccess")
        //重置游戏
        static let ResetImmediately = NSNotification.Name(rawValue: "ResetImmediately")
        // manufacturer order update
        static let ManufacturerOrderUpdate = NSNotification.Name(rawValue: "ManufacturerOrderUpdate")
        //platform visible change object = platform
        static let PlatformVisibleChange = NSNotification.Name(rawValue: "PlatformVisibleChange")
        //Game category change
        static let GameCategoryChange = NSNotification.Name(rawValue: "GameCategoryChange")
        //KeyboardEvent
        static let KeyboardEvent = NSNotification.Name(rawValue: "KeyboardEvent")
        //SkinChange
        static let SkinChange = NSNotification.Name(rawValue: "SkinChange")
        //Transition
        static let ViewWillTransition = NSNotification.Name(rawValue: "ViewWillTransition")
        static let ViewAlongsideTransition = NSNotification.Name(rawValue: "ViewAlongsideTransition")
        static let ViewDidTransition = NSNotification.Name(rawValue: "ViewDidTransition")
        // GameOptionsSortChange
        static let GameOptionsSortChange = NSNotification.Name(rawValue: "GameOptionsSortChange")
        //Shortcuts
        static let ShortcutsChange = NSNotification.Name(rawValue: "ShortcutsChange")
        //HideGameRating
        static let HideGameRating = NSNotification.Name(rawValue: "HideGameRating")
        //GameMetadataChange
        static let GameMetadataChange = NSNotification.Name(rawValue: "GameMetadataChange")
    }
    
    struct _URLs {
#if DEBUG
        static let ManicEMU = "http://10.10.10.2:4321/"
#else
        static let ManicEMU = "https://manicemu.site/"
#endif
        static let ManicHome = URL(string: ManicEMU)!
        static let AppReview = URL(string: "itms-apps://itunes.apple.com/app/id6743335790?action=write-review")!
        static let AppStoreUrl = URL(string: "https://apps.apple.com/app/id6743335790")!
        static let TermsOfUse = URL(string: ManicEMU + "terms-of-use")!
        static let PrivacyPolicy = URL(string: ManicEMU + "privacy-policy")!
        static let PaymentTerms = URL(string: ManicEMU + "Payment-Terms")!
        static let FAQ = URL(string: ManicEMU + "guides/faq")!
        static let GameImportGuide = URL(string: ManicEMU + "guides/import")!
        static let SkinUsageGuide = URL(string: ManicEMU + "guides/skins")!
        static let ControllerUsageGuide = URL(string: ManicEMU + "guides/controllers")!
        static let CheatCodesGuide = URL(string: ManicEMU + "guides/cheats")!
        static let AirPlayUsageGuide = URL(string: ManicEMU + "guides/airplay")!
        static func manufacturer(_ manufacturer: Manufacturer) -> URL {
            return URL(string: ManicEMU + "Manufacturer-" + manufacturer.title)!
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
            case .a2600, .a5200, .a7800, .lynx, .jaguar: return URL(string: "\(deltastyles)/systems/atari")!
            default: return URL(string: deltastyles)!
            }
        }
        static func History(gameType: GameType) -> URL {
            var gameTypeName = gameType.localizedShortName
            if gameType == .gb {
                gameTypeName = GameType.gbc.localizedShortName
            } else if gameType == .ngpc {
                gameTypeName = GameType.ngp.localizedShortName
            } else if gameType == .ws {
                gameTypeName = GameType.wsc.localizedShortName
            } else if gameType == .supergrafx || gameType == .turbografx_16 || gameType == .turbografx_cd {
                gameTypeName = GameType.pce.localizedShortName
            }
            return URL(string: ManicEMU + "History-" + gameTypeName)!
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
        static func RetroGame(gameId: Int) -> URL {
            return Retro.appendingPathComponent("/game/\(gameId)")
        }
        static let MobyGames = URL(string: "https://www.mobygames.com")!
        static let InstallSideload = URL(string: "sidestore://source?url=https://apps.manicemu.site/altstore")!
        static let SideStore = URL(string: "https://sidestore.io")!
        static let GLSLShaders = URL(string: "https://buildbot.libretro.com/assets/frontend/shaders_glsl.zip")!
        static let SlangShaders = URL(string: "https://buildbot.libretro.com/assets/frontend/shaders_slang.zip")!
        static let PlayCasePromo = URL(string: "https://playcase.gg/playmanic")!
        static let FetchMeloNXGames = URL(string: "\(R.Strings.MeloNXScheme)://gameInfo?scheme=manicemu")!
        static func MeloNXGameLaunch(gameId: String) -> URL { URL(string: "\(R.Strings.MeloNXScheme)://game?id=\(gameId)")! }
        static let FetchXeniOSGames = URL(string: "\(R.Strings.XeniOSScheme)://gameInfo?scheme=manicemu")!
        static func XeniOSGameLaunch(gameId: String) -> URL { URL(string: "\(R.Strings.XeniOSScheme)://launch?title-id=\(gameId)")! }
        static let FetchDukeXGames = URL(string: "\(R.Strings.DukeXScheme)://gameInfo?scheme=manicemu")!
        static func DukeXGameLaunch(gameId: String) -> URL { URL(string: "\(R.Strings.DukeXScheme)://launch?titleid=\(gameId)")! }
        static let FetchARMSX2Games: URL = {
            var components = URLComponents()
            components.scheme = R.Strings.ARMSX2Scheme
            components.host = "library"
            components.queryItems = [
                URLQueryItem(name: "callback", value: "\(R.Strings.ManicScheme)://\(R.Strings.ARMSX2Scheme)")
            ]
            return components.url!
        }()
        static func ARMSX2GameLaunch(gameId: String) -> URL {
            var components = URLComponents()
            components.scheme = R.Strings.ARMSX2Scheme
            components.host = "launch"
            components.queryItems = [URLQueryItem(name: "game", value: gameId)]
            return components.url!
        }
#if SIDE_LOAD
        static let EnableJITUrl = URL(string: "stikjit://enable-jit?bundle-id=com.aoshuang.manicemu&script-name=universal.js")!
#endif
        static let Gamehacking = URL(string: "https://gamehacking.org/")!
        static func GamehackingSearch(gameType: GameType, gameName: String) -> URL? {
            guard let searchSystem = gameType.gamehackingSystem else { return nil }
            
            guard gameName.isEnglishLanguage() else {
                return Gamehacking.appendingPathComponent("system/\(searchSystem)")
            }
            
            return Gamehacking.appendingPathComponent("system/\(searchSystem)/\(gameName)")
        }
        
        static let SymbianSkinUrl = URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("Symbian.manicskin"))
        static let SymbianFlexSkinUrl = URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("Symbian_Flex.manicskin"))
        static let SymbianEdgeSkinUrl = URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("Symbian_Edge.manicskin"))
        static let SymbianEdgeFlexSkinUrl = URL(fileURLWithPath: R.Path.Resource.appendingPathComponent("Symbian_Edge_Flex.manicskin"))
        
    }
    
    struct _BIOS {
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
        
        static let WiiBios = [
            BIOSItem(fileName: "keys.bin", imported: false, desc: R.string.localizable.wiiKeysBinDesc(), required: true)
        ]
        
        static let ArcadeDSBios = [
            BIOSItem(fileName: R.Strings.MAMEBiosTitle, imported: false, desc: R.string.localizable.mameBiosDesc(), required: false)
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
        
        static let PCEBios = [
            BIOSItem(fileName: "syscard3.pce", imported: false, desc: "Super CD-ROM2 System V3.xx", required: false),
            BIOSItem(fileName: "syscard2.pce", imported: false, desc: "CD-ROM System V2.xx", required: false),
            BIOSItem(fileName: "syscard1.pce", imported: false, desc: "CD-ROM System V1.xx", required: false),
            BIOSItem(fileName: "gexpress.pce", imported: false, desc: "Game Express CD Card", required: false)
        ]
        
        static let C64Bios = [
            BIOSItem(fileName: "JiffyDOS_C64.bin", imported: false, desc: "JiffyDOS C64 Kernal", required: false),
            BIOSItem(fileName: "JiffyDOS_1541-II.bin", imported: false, desc: "JiffyDOS 1541 drive BIOS", required: false),
            BIOSItem(fileName: "JiffyDOS_1571_repl310654.bin", imported: false, desc: "JiffyDOS 1571 drive BIOS", required: false),
            BIOSItem(fileName: "JiffyDOS_1581.bin", imported: false, desc: "JiffyDOS 1581 drive BIOS", required: false)
        ]
        
        static let AmigaBios = [
            BIOSItem(fileName: "kick33180.A500", imported: false, desc: "A500-A2000 KS v1.2 rev 33.180", required: false),
            BIOSItem(fileName: "kick34005.A500", imported: false, desc: "A500-A2000-CDTV KS v1.3 rev 34.005", required: true),
            BIOSItem(fileName: "kick37175.A500", imported: false, desc: "A500+ KS v2.04 rev 37.175", required: false),
            BIOSItem(fileName: "kick37350.A600", imported: false, desc: "A600 KS v2.05 rev 37.350", required: false),
            BIOSItem(fileName: "kick40063.A600", imported: false, desc: "A600-A2000 KS v3.1 rev 40.063", required: false),
            BIOSItem(fileName: "kick39106.A1200", imported: false, desc: "A1200 KS v3.0 rev 39.106", required: false),
            BIOSItem(fileName: "kick40068.A1200", imported: false, desc: "A1200 KS v3.1 rev 40.068", required: true),
            BIOSItem(fileName: "kick39106.A4000", imported: false, desc: "A4000 KS v3.0 rev 39.106", required: false),
            BIOSItem(fileName: "kick40068.A4000", imported: false, desc: "A4000 KS v3.1 rev 40.068", required: false),
            BIOSItem(fileName: "kick34005.CDTV", imported: false, desc: "CDTV extended ROM v1.0", required: false),
            BIOSItem(fileName: "kick40060.CD32", imported: false, desc: "CD32 KS v3.1 rev 40.060", required: true),
            BIOSItem(fileName: "kick40060.CD32.ext", imported: false, desc: "CD32 extended ROM rev 40.060", required: true)
        ]
        
        static let SegaArcadeBios: Set<String> = ["airlbios.zip",
                                                  "awbios.zip",
                                                  "f355bios.zip",
                                                  "f355dlx.zip",
                                                  "hod2bios.zip",
                                                  "naomi.zip",
                                                  "naomi2.zip",
                                                  "naomigd.zip"]
    }
    
    struct _Style {
        static var GameCoverStyle = CoverStyle.style1
        static var GameCoverCornerRatio = GameCoverStyle.defaultCornerRadius()
        static var GameCoverForceSquare = false
        static var GamesPerRow = 3.0
        static var GamesHideScrollIndicator = false
        static var GamesHideTitle = false
        static var GamesHideGroupTitle = false
        static var GamesGroupTitleStyle: GroupTitleStyle = .abbr
        static var GameHideRating = false
    }
}
