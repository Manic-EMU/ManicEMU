//
//  KeyboardGameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/14/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit
import GameController

public extension GameControllerInputType
{
    static let keyboard = GameControllerInputType("keyboard")
}

extension KeyboardGameController
{
    public struct Input: Hashable, RawRepresentable, Codable
    {
        public let rawValue: String
        
        public init(rawValue: String)
        {
            self.rawValue = rawValue
        }
        
        public init(_ rawValue: String)
        {
            self.rawValue = rawValue
        }
    }
}

extension KeyboardGameController.Input: Input
{
    public var type: InputType {
        return .controller(.keyboard)
    }
    
    public init(stringValue: String)
    {
        self.init(rawValue: stringValue)
    }
}

public extension KeyboardGameController.Input
{
    static let up = KeyboardGameController.Input("up")
    static let down = KeyboardGameController.Input("down")
    static let left = KeyboardGameController.Input("left")
    static let right = KeyboardGameController.Input("right")
    
    static let escape = KeyboardGameController.Input("escape")
    
    static let shift = KeyboardGameController.Input("shift")
    static let command = KeyboardGameController.Input("command")
    static let option = KeyboardGameController.Input("option")
    static let control = KeyboardGameController.Input("control")
    static let capsLock = KeyboardGameController.Input("capsLock")
    
    static let space = KeyboardGameController.Input("space")
    static let `return` = KeyboardGameController.Input("return")
    static let tab = KeyboardGameController.Input("tab")
}

public class KeyboardGameController: UIResponder, GameController
{
    public var name: String {
        return NSLocalizedString("Keyboard", comment: "")
    }
    
    public var playerIndex: Int?

    public let inputType: GameControllerInputType = .keyboard

    private static func builtInDefaultInputMapping() -> GameControllerInputMapping {
        var inputMapping = GameControllerInputMapping(gameControllerInputType: .keyboard)

        inputMapping.set(StandardGameControllerInput.up, forControllerInput: KeyboardGameController.Input.up)
        inputMapping.set(StandardGameControllerInput.down, forControllerInput: KeyboardGameController.Input.down)
        inputMapping.set(StandardGameControllerInput.left, forControllerInput: KeyboardGameController.Input.left)
        inputMapping.set(StandardGameControllerInput.right, forControllerInput: KeyboardGameController.Input.right)

        inputMapping.set(StandardGameControllerInput.menu, forControllerInput: KeyboardGameController.Input.escape)
        inputMapping.set(StandardGameControllerInput.a, forControllerInput: KeyboardGameController.Input.space)
        inputMapping.set(StandardGameControllerInput.start, forControllerInput: KeyboardGameController.Input.return)
        inputMapping.set(StandardGameControllerInput.select, forControllerInput: KeyboardGameController.Input.tab)

        inputMapping.set(StandardGameControllerInput.a, forControllerInput: KeyboardGameController.Input("z"))
        inputMapping.set(StandardGameControllerInput.b, forControllerInput: KeyboardGameController.Input("x"))
        inputMapping.set(StandardGameControllerInput.x, forControllerInput: KeyboardGameController.Input("s"))
        inputMapping.set(StandardGameControllerInput.y, forControllerInput: KeyboardGameController.Input("a"))
        inputMapping.set(StandardGameControllerInput.l1, forControllerInput: KeyboardGameController.Input("q"))
        inputMapping.set(StandardGameControllerInput.r1, forControllerInput: KeyboardGameController.Input("w"))

        return inputMapping
    }
    
    public private(set) lazy var defaultInputMapping: GameControllerInputMappingBase? = {
        guard let fileURL = Bundle.resources.url(forResource: "KeyboardGameController", withExtension: "keymapping") else {
            print("KeyboardGameController.keymapping is missing, using built-in defaults.")
            return Self.builtInDefaultInputMapping()
        }
        
        do
        {
            let inputMapping = try GameControllerInputMapping(fileURL: fileURL)
            return inputMapping
        }
        catch
        {
            print(error)
            print("Falling back to built-in keyboard mapping.")
            return Self.builtInDefaultInputMapping()
        }
    }()
    
    // When non-nil, uses modern keyboard handling.
    private let keyboard: GCKeyboard?
    
    public var keyboardPress: ((_ key: String)->Void)? = nil
    
    public init(keyboard: GCKeyboard?)
    {
        self.keyboard = keyboard
        
        super.init()
        
        self.keyboard?.keyboardInput?.keyChangedHandler = { [weak self] (profile, buttonInput, keyCode, isActive) in
            let input: Input
            
            switch keyCode
            {
            case .upArrow: input = .up
            case .downArrow: input = .down
            case .leftArrow: input = .left
            case .rightArrow: input = .right
                
            case .escape: input = .escape
                
            case .leftShift, .rightShift: input = .shift
            case .leftGUI, .rightGUI: input = .command
            case .leftAlt, .rightAlt: input = .option
            case .leftControl, .rightControl: input = .control
            case .capsLock: input = .capsLock
                
            case .spacebar: input = .space
            case .returnOrEnter, .keypadEnter: input = .return
            case .tab: input = .tab
                
            case .comma: input = .init(",")
            case .period, .keypadPeriod: input = .init(".")
            case .slash, .keypadSlash: input = .init("/")
            case .semicolon: input = .init(";")
            case .quote: input = .init("'")
            case .openBracket: input = .init("[")
            case .closeBracket: input = .init("]")
            case .backslash: input = .init("\\")
            case .nonUSBackslash: input = .init("|")
            case .hyphen, .keypadHyphen: input = .init("-")
            case .equalSign, .keypadEqualSign: input = .init("=")
            case .graveAccentAndTilde: input = .init("`")
                
            case .keypadPlus: input = .init("+")
            case .keypadAsterisk: input = .init("*")
                
            case .one, .keypad1: input = .init("1")
            case .two, .keypad2: input = .init("2")
            case .three, .keypad3: input = .init("3")
            case .four, .keypad4: input = .init("4")
            case .five, .keypad5: input = .init("5")
            case .six, .keypad6: input = .init("6")
            case .seven, .keypad7: input = .init("7")
            case .eight, .keypad8: input = .init("8")
            case .nine, .keypad9: input = .init("9")
            case .zero, .keypad0: input = .init("0")
                
            default:
                // Catch-all for single letters.
                guard let key = buttonInput.description.components(separatedBy: .whitespacesAndNewlines).first, key.count == 1 else { return }
                input = Input(stringValue: key.lowercased())
            }
            
            if isActive
            {
                self?.activate(input)
            }
            else
            {
                self?.deactivate(input)
            }
        }
    }
    
    override public func keyPressesBegan(_ presses: Set<KeyPress>, with event: UIEvent)
    {
        // Ignore unless using legacy keyboard handling.
        guard self.keyboard == nil else { return }
        
        for press in presses
        {
            keyboardPress?(press.key)
            let input = Input(press.key)
            self.activate(input)
        }
    }
    
    override public func keyPressesEnded(_ presses: Set<KeyPress>, with event: UIEvent)
    {
        // Ignore unless using legacy keyboard handling.
        guard self.keyboard == nil else { return }
        
        for press in presses
        {
            let input = Input(press.key)
            self.deactivate(input)
        }
    }
}
