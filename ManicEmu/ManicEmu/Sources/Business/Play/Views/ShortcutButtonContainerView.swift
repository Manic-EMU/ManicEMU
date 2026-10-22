//
//  ShortcutButtonContainerView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import DeltaCore

class ShortcutButtonContainerView: UIView {
    struct InterfaceStyle {
        
        let gameType: GameType
        let isLandscape: Bool
        
        var offsetY: CGFloat {
            switch gameType {
            case .snes:
                return 11
            case .dos, .amiga, .c64, .doom:
                return UIDevice.isPhone || (UIDevice.isPad && isLandscape) ? 17 : 25
            case .flash, .ngc, .wii:
                return 8
            case .symbian, .arcade:
                return 2
            case .pce:
                return isLandscape ? 16 : 14
            case .wsc:
                return 2
            case ._3ds:
                if UIDevice.isPad {
                    return isLandscape ? 4 : 16
                } else if UIDevice.isPhoneDuo {
                    return isLandscape ? 4 : 24
                }
                return 0
            case .ds:
                if UIDevice.isPad {
                    return isLandscape ? 20 : 31
                } else if UIDevice.isPhoneDuo {
                    return isLandscape ? 20 : 17
                }
                return 0
            default:
                return 0
            }
        }
        
        var offsetX: CGFloat {
            switch gameType {
            case .pm:
                return isLandscape ? 0 : 20
            case ._3ds:
                return UIDevice.isPad ? 40 : (UIDevice.isPhoneDuo ? (isLandscape ? 40 : 121) : 0)
            default:
                return 0
            }
        }
        
        var dimension: CGFloat {
            switch gameType {
            case .nes, .jaguar, .lynx, .a7800, .a5200, .a2600, .dc, .ps1, .vb, .n64, .ss, .gg, .sg1000, ._32x, .mcd, .md, .psp, .fds:
                return dimensionValue(isLandscape ? 40 : 50, 40, 40)
            case .flash, .pm, .gbc, .gb, ._3ds, .ds:
                return 40
            case  .ngp, .pce, .symbian, .gba, .snes, .dos, .amiga, .c64, .doom:
                return 30
            case .wsc, .ws:
                return 28
            case .arcade:
                return 38
            case .ngc, .wii:
                return dimensionValue(40, 30, 30)
            case .ms:
                return dimensionValue(50, 50, 40)
            case .snes:
                return 24
            default:
                return 30
            }
        }
        
        private func dimensionValue(_ edgeToEdgePhoneValue: CGFloat,
                                    _ standardPhoneValue: CGFloat,
                                    _ PadValue: CGFloat) -> CGFloat {
            if UIDevice.isEdgeToEdgePhone {
                return edgeToEdgePhoneValue
            } else if UIDevice.isPad || UIDevice.isPhoneDuo {
                return PadValue
            } else {
                return standardPhoneValue
            }
        }
        
        var color: UIColor {
            if (gameType == .ds && (UIDevice.isPad || UIDevice.isPhoneDuo)) ||
                gameType == .wii ||
                gameType == .ngc ||
                (gameType == .pce && !isLandscape) ||
                gameType.usesDOSSkinLayout ||
                gameType == .wsc ||
                gameType == .snes {
                return .black.withAlphaComponent(0.25)
            } else if gameType == ._3ds && (UIDevice.isPad || UIDevice.isPhoneDuo) {
                return UIColor(hexString: "#222222")!
            } else {
                return .white.withAlphaComponent(0.25)
            }
        }
        
        var dualScreenSize: CGSize {
            if UIDevice.isStandardPhone || UIDevice.isEdgeToEdgePhone {
                if gameType == .ds {
                    return CGSize(width: 35, height: isLandscape ? 110 : 113)
                } else if gameType == ._3ds {
                    return CGSize(width: isLandscape ? 31 : 32, height: isLandscape ? 90 : 92)
                }
            }
            return .zero
        }
    }
    
    private var game: Game
    
    init(game: Game) {
        self.game = game
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
    
    func updateControllerSkin(_ controllerSkin: ControllerSkin,
                              beginLongPress: ((AnyInput) -> Void)? = nil,
                              endLongPress: ((AnyInput) -> Void)? = nil) {
        
        subviews.forEach({ $0.removeFromSuperview() })
        
        if game.isAzaharArticBase {
            return
        }
        
        if let skin = Database.realm.objects(Skin.self).first(where: { $0.identifier == controllerSkin.identifier }),
            !skin.supportShortcut {
            return
        }
        
        guard let hostingWindow else { return }
        guard let skinFrames = controllerSkin.getFrames(window: hostingWindow) else { return }
        let skinFrame = skinFrames.skinFrame
        let gameViewFrame = CGRect(origin: CGPoint(x: skinFrame.minX + skinFrames.mainGameViewFrame.minX, y: skinFrame.minY + skinFrames.mainGameViewFrame.minY), size: skinFrames.mainGameViewFrame.size)
        let traits = ControllerSkin.Traits.defaults(for: hostingWindow)
        let skinAspectRatio = controllerSkin.aspectRatio(for: traits) ?? hostingWindow.bounds.size
        let scaleRatio = CGSize(width: skinFrame.width/skinAspectRatio.width, height: skinFrame.height/skinAspectRatio.height)
        let interfaceStyle = InterfaceStyle(gameType: game.gameType, isLandscape: traits.orientation == .landscape)
        let isSpecialConstraintsForDualScreen = (game.gameType == .ds || game.gameType == ._3ds) && (UIDevice.isStandardPhone || UIDevice.isEdgeToEdgePhone)
        let commonWidth = gameViewFrame.width - interfaceStyle.offsetX*scaleRatio.width*2
        self.snp.remakeConstraints { make in
            if isSpecialConstraintsForDualScreen {
                var touchscreenFrame = skinFrames.touchGameViewFrame ?? gameViewFrame
                touchscreenFrame = CGRect(origin: CGPoint(x: skinFrame.minX + touchscreenFrame.minX, y: skinFrame.minY + touchscreenFrame.minY), size: touchscreenFrame.size)
                if traits.orientation == .landscape {
                    make.top.equalToSuperview().offset(gameViewFrame.minY)
                    make.leading.equalToSuperview().offset(gameViewFrame.minX - interfaceStyle.dualScreenSize.width*scaleRatio.width)
                    make.width.equalTo(touchscreenFrame.maxX - gameViewFrame.minX + interfaceStyle.dualScreenSize.width*scaleRatio.width*2)
                } else {
                    make.top.equalToSuperview().offset(gameViewFrame.maxY)
                    make.leading.equalToSuperview().offset(touchscreenFrame.minX - interfaceStyle.dualScreenSize.width*scaleRatio.width)
                    make.width.equalTo(touchscreenFrame.width + interfaceStyle.dualScreenSize.width*scaleRatio.width*2)
                }
                make.height.equalTo(interfaceStyle.dualScreenSize.height*scaleRatio.height)
            } else {
                make.top.equalToSuperview().offset((interfaceStyle.offsetY * scaleRatio.height) + gameViewFrame.maxY)
                make.leading.equalToSuperview().offset(gameViewFrame.minX + interfaceStyle.offsetX*scaleRatio.width)
                make.width.equalTo(commonWidth)
                make.height.equalTo(interfaceStyle.dimension*scaleRatio.height)
            }
        }
        
        var shortcuts = Prefference.defalut.getPrefference(kind: .gameShortcut,
                                                           storeKey: .game(gameId: game.id),
                                                           bestEfforts: true)?.gameShortcutValue ?? GameOption.defaultShortcutOptions(for: game)
        let availableOptions = Set(GameOption.availableOptions(game: game, scene: .gaming))
        shortcuts = shortcuts.filter({ availableOptions.contains($0) })
        
        guard shortcuts.count > 0 else { return }
        let functionButtonCount = shortcuts.count
        for (index, shortcut) in shortcuts.enumerated() {
            let buttonContainerView = UIView()
            let button = ASButtonView(.iconOnlyWithSmallSize(icon: shortcut.icon.updateColorsIfNeed(colors: [interfaceStyle.color], forceUpdate: true),
                                                             background: .clear))
            button.didTapButton = { [weak self] in
                guard let self, shortcut != .rewind else { return }
                shortcut.showSecondPromptIfNeed(continued: {
                    shortcut.performAction(with: [self.game],
                                           in: self.hostingWindowScene,
                                           performImmediately: true)
                })
            }
            button.didLongPressButton = { state in
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
                    beginLongPress?(input)
                } else if state == .cancelled || state == .ended {
                    endLongPress?(input)
                }
            }
            buttonContainerView.addSubview(button)
            button.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
            addSubview(buttonContainerView)
            buttonContainerView.snp.makeConstraints { make in
                if isSpecialConstraintsForDualScreen {
                    let width = game.gameType == .ds ? 35 : 32
                    make.width.equalTo(width)
                    make.height.equalToSuperview().dividedBy(2)
                    if index == 0 {
                        make.leading.equalToSuperview()
                        make.top.equalToSuperview()
                    } else if index == 1 {
                        make.leading.equalToSuperview()
                        make.top.equalTo(subviews[index - 1].snp.bottom)
                    } else if index == 2 {
                        make.trailing.equalToSuperview()
                        make.top.equalToSuperview()
                    } else if index == 3 {
                        make.trailing.equalToSuperview()
                        make.top.equalTo(subviews[index - 1].snp.bottom)
                    }
                } else if (game.gameType == ._3ds || game.gameType == .ds) && (UIDevice.isPad || (UIDevice.isPhoneDuo && traits.orientation == .landscape )) {
                    let centerSpacing = 150 * scaleRatio.width
                    if index == 0 {
                        make.leading.equalToSuperview()
                    } else {
                        make.leading.equalTo(subviews[index-1].snp.trailing).offset(index == 2 ? centerSpacing : 0)
                    }
                    make.top.bottom.equalToSuperview()
                    if index == functionButtonCount-1 && functionButtonCount == R.Numbers.GameFunctionButtonCount {
                        make.trailing.equalToSuperview()
                    }
                    make.width.equalTo((commonWidth - centerSpacing)/CGFloat(R.Numbers.GameFunctionButtonCount))
                } else {
                    if index == 0 {
                        make.leading.equalToSuperview()
                    } else {
                        make.leading.equalTo(subviews[index-1].snp.trailing)
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
