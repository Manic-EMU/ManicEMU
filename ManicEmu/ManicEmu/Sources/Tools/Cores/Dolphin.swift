import AVFoundation

extension GameType
{
    static let gc = GameType("public.aoshuang.game.gc")
    static let wii = GameType("public.aoshuang.game.wii")
}

@objc enum DolphinGameInput: Int, Input, CaseIterable {
    case a
    case b
    case x
    case y
    case l
    case r
    case z
    case start
    case up
    case down
    case left
    case right
    case leftThumbstickUp
    case leftThumbstickDown
    case leftThumbstickLeft
    case leftThumbstickRight
    case rightThumbstickUp
    case rightThumbstickDown
    case rightThumbstickLeft
    case rightThumbstickRight

    case flex
    case menu

    var type: InputType {
        return .game(.gc)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "l" { self = .l }
        else if stringValue == "r" { self = .r }
        else if stringValue == "z" { self = .z }
        else if stringValue == "start" { self = .start }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp }
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown }
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft }
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight }
        else if stringValue == "rightThumbstickUp" { self = .rightThumbstickUp }
        else if stringValue == "rightThumbstickDown" { self = .rightThumbstickDown }
        else if stringValue == "rightThumbstickLeft" { self = .rightThumbstickLeft }
        else if stringValue == "rightThumbstickRight" { self = .rightThumbstickRight }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "menu" { self = .menu }
        else { return nil }
    }
}

@objc enum WiiRemoteGameInput: Int, Input, CaseIterable {
    case a = 1000
    case b = 1001
    case one = 1002
    case two = 1003
    case plus = 1004
    case minus = 1005
    case up = 1006
    case down = 1007
    case left = 1008
    case right = 1009
    case home = 1010

    case flex = 1011
    case menu = 1012

    var type: InputType {
        return .game(.wii)
    }

    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "one" { self = .one }
        else if stringValue == "two" { self = .two }
        else if stringValue == "plus" { self = .plus }
        else if stringValue == "minus" { self = .minus }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "home" { self = .home }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "menu" { self = .menu }
        else { return nil }
    }
}

enum Dolphin {
    static let coreFrameworkName = "dolphin.libretro"
    static let displayName = "Dolphin"

    static var runtimeCorePath: String? {
        Bundle.main.path(forResource: coreFrameworkName, ofType: "framework", inDirectory: "Frameworks")
    }

    static var runtimeVersion: String? {
        guard let runtimeCorePath else { return nil }
        return Bundle(path: runtimeCorePath)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}

struct GameCube: DeltaCoreProtocol {
    static let core = GameCube()
    
    var name: String { "GC" }
    var identifier: String { "com.aoshuang.GameCubeCore" }
    var version: String? { Dolphin.runtimeVersion }
    
    var gameType: GameType { GameType.gc }
    var gameInputType: Input.Type { DolphinGameInput.self }
    var allInputs: [Input] { DolphinGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 640, height: 528))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let geckoFormat = CheatFormat(name: NSLocalizedString("Gecko", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .actionReplay)
        return [geckoFormat]
    }
    
    var emulatorBridge: EmulatorBridging { DolphinEmulatorBridge.shared }
    
    private init() {}
}

struct Wii: DeltaCoreProtocol {
    static let core = Wii()
    
    var name: String { "Wii" }
    var identifier: String { "com.aoshuang.WiiCore" }
    var version: String? { Dolphin.runtimeVersion }
    
    var gameType: GameType { GameType.wii }
    var gameInputType: Input.Type { WiiRemoteGameInput.self }
    var allInputs: [Input] { WiiRemoteGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 640, height: 528))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let geckoFormat = CheatFormat(name: NSLocalizedString("Gecko", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .actionReplay)
        return [geckoFormat]
    }
    
    var emulatorBridge: EmulatorBridging { DolphinEmulatorBridge.shared }
    
    private init() {}
}

class DolphinEmulatorBridge : EmulatorBridgeBase {
    static let shared = DolphinEmulatorBridge()

    private var leftThumbstickPosition: CGPoint = .zero
    private var rightThumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }

        if input == DolphinGameInput.leftThumbstickUp || input == DolphinGameInput.leftThumbstickDown {
            leftThumbstickPosition.y = input == DolphinGameInput.leftThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DolphinGameInput.leftThumbstickLeft || input == DolphinGameInput.leftThumbstickRight {
            leftThumbstickPosition.x = input == DolphinGameInput.leftThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DolphinGameInput.rightThumbstickUp || input == DolphinGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = input == DolphinGameInput.rightThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DolphinGameInput.rightThumbstickLeft || input == DolphinGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = input == DolphinGameInput.rightThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = DolphinGameInput(rawValue: input),
               let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
                Log.debug("\(String(describing: Self.self)) clicked: \(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            } else if let wiiRemoteInput = WiiRemoteGameInput(rawValue: input),
                      let libretroButton = wiiRemoteInputToCoreInput(gameInput: wiiRemoteInput) {
#if DEBUG
                Log.debug("\(String(describing: Self.self)) clicked: \(wiiRemoteInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }

    func gameInputToCoreInput(gameInput: DolphinGameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
        else if gameInput == .b { return .A }
        else if gameInput == .x { return .Y }
        else if gameInput == .y { return .X }
        else if gameInput == .l { return .L1 }
        else if gameInput == .r { return .R1 }
        else if gameInput == .z { return .L2 }
        else if gameInput == .start { return .start }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }

    func wiiRemoteInputToCoreInput(gameInput: WiiRemoteGameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
        else if gameInput == .b { return .A }
        else if gameInput == .one { return .Y }
        else if gameInput == .two { return .X }
        else if gameInput == .plus { return .start }
        else if gameInput == .minus { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .home { return .R3 }
        return nil
    }

    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == DolphinGameInput.leftThumbstickUp || input == DolphinGameInput.leftThumbstickDown {
            leftThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DolphinGameInput.leftThumbstickLeft || input == DolphinGameInput.leftThumbstickRight {
            leftThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DolphinGameInput.rightThumbstickUp || input == DolphinGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DolphinGameInput.rightThumbstickLeft || input == DolphinGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = DolphinGameInput(rawValue: input),
               let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            } else if let wiiRemoteInput = WiiRemoteGameInput(rawValue: input),
                      let libretroButton = wiiRemoteInputToCoreInput(gameInput: wiiRemoteInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
}
