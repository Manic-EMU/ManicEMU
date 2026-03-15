//
//  MFiGameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import GameController

public extension GameControllerInputType
{
    static let mfi = GameControllerInputType("mfi")
}

extension MFiGameController
{
    private enum ProductCategory: String
    {
        case mfi = "MFi"
        
        case joyConL = "Nintendo Switch Joy-Con (L)"
        case joyConR = "Nintendo Switch Joy-Con (R)"
        case joyConsCombined = "Nintendo Switch Joy-Con (L/R)"
        
        case switchPro = "Switch Pro Controller"
        case switchOnlineNES = "Switch NES Controller"
        case switchOnlineSNES = "Switch SNES Controller"
    }
}

extension MFiGameController
{
    public enum Input: String, Codable
    {
        case menu
        
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
        
        case a
        case b
        case x
        case y
        
        case leftShoulder
        case leftTrigger
        
        case rightShoulder
        case rightTrigger
        
        case start
        case select
        
        case leftThumbstickButton
        case rightThumbstickButton
    }
}

extension MFiGameController.Input: Input
{
    public var type: InputType {
        return .controller(.mfi)
    }
    
    public var isContinuous: Bool {
        switch self
        {
        case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight: return true
        case .rightThumbstickUp, .rightThumbstickDown, .rightThumbstickLeft, .rightThumbstickRight: return true
        default: return false
        }
    }
}

public class MFiGameController: NSObject, GameController
{
    //MARK: - Properties -
    /** Properties **/
    public let controller: GCController
    
    public var name: String {
        return self.controller.vendorName ?? NSLocalizedString("MFi Controller", comment: "")
    }
    
    public var playerIndex: Int? {
        get {
            switch self.controller.playerIndex
            {
            case .indexUnset: return nil
            case .index1: return 0
            case .index2: return 1
            case .index3: return 2
            case .index4: return 3
            @unknown default: return nil
            }
        }
        set {
            switch newValue
            {
            case .some(0): self.controller.playerIndex = .index1
            case .some(1): self.controller.playerIndex = .index2
            case .some(2): self.controller.playerIndex = .index3
            case .some(3): self.controller.playerIndex = .index4
            default: self.controller.playerIndex = .indexUnset
            }
        }
    }
    
    public var deadZone: Float = 0.0

    public let inputType: GameControllerInputType = .mfi

    private static func builtInDefaultInputMapping() -> GameControllerInputMapping {
        var inputMapping = GameControllerInputMapping(gameControllerInputType: .mfi)

        inputMapping.set(StandardGameControllerInput.menu, forControllerInput: MFiGameController.Input.menu)
        inputMapping.set(StandardGameControllerInput.up, forControllerInput: MFiGameController.Input.up)
        inputMapping.set(StandardGameControllerInput.down, forControllerInput: MFiGameController.Input.down)
        inputMapping.set(StandardGameControllerInput.left, forControllerInput: MFiGameController.Input.left)
        inputMapping.set(StandardGameControllerInput.right, forControllerInput: MFiGameController.Input.right)

        inputMapping.set(StandardGameControllerInput.leftThumbstickUp, forControllerInput: MFiGameController.Input.leftThumbstickUp)
        inputMapping.set(StandardGameControllerInput.leftThumbstickDown, forControllerInput: MFiGameController.Input.leftThumbstickDown)
        inputMapping.set(StandardGameControllerInput.leftThumbstickLeft, forControllerInput: MFiGameController.Input.leftThumbstickLeft)
        inputMapping.set(StandardGameControllerInput.leftThumbstickRight, forControllerInput: MFiGameController.Input.leftThumbstickRight)

        inputMapping.set(StandardGameControllerInput.rightThumbstickUp, forControllerInput: MFiGameController.Input.rightThumbstickUp)
        inputMapping.set(StandardGameControllerInput.rightThumbstickDown, forControllerInput: MFiGameController.Input.rightThumbstickDown)
        inputMapping.set(StandardGameControllerInput.rightThumbstickLeft, forControllerInput: MFiGameController.Input.rightThumbstickLeft)
        inputMapping.set(StandardGameControllerInput.rightThumbstickRight, forControllerInput: MFiGameController.Input.rightThumbstickRight)

        inputMapping.set(StandardGameControllerInput.a, forControllerInput: MFiGameController.Input.a)
        inputMapping.set(StandardGameControllerInput.b, forControllerInput: MFiGameController.Input.b)
        inputMapping.set(StandardGameControllerInput.x, forControllerInput: MFiGameController.Input.x)
        inputMapping.set(StandardGameControllerInput.y, forControllerInput: MFiGameController.Input.y)

        inputMapping.set(StandardGameControllerInput.l1, forControllerInput: MFiGameController.Input.leftShoulder)
        inputMapping.set(StandardGameControllerInput.l2, forControllerInput: MFiGameController.Input.leftTrigger)
        inputMapping.set(StandardGameControllerInput.r1, forControllerInput: MFiGameController.Input.rightShoulder)
        inputMapping.set(StandardGameControllerInput.r2, forControllerInput: MFiGameController.Input.rightTrigger)

        inputMapping.set(StandardGameControllerInput.start, forControllerInput: MFiGameController.Input.start)
        inputMapping.set(StandardGameControllerInput.select, forControllerInput: MFiGameController.Input.select)
        inputMapping.set(StandardGameControllerInput.l3, forControllerInput: MFiGameController.Input.leftThumbstickButton)
        inputMapping.set(StandardGameControllerInput.r3, forControllerInput: MFiGameController.Input.rightThumbstickButton)

        return inputMapping
    }
         
    public private(set) lazy var defaultInputMapping: GameControllerInputMappingBase? = {
        guard let fileURL = Bundle.resources.url(forResource: "MFiGameController", withExtension: "keymapping") else {
            print("MFiGameController.keymapping is missing, using built-in defaults.")
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
            print("Falling back to built-in MFi controller mapping.")
            return Self.builtInDefaultInputMapping()
        }
    }()
    
    //MARK: - Initializers -
    /** Initializers **/
    public init(controller: GCController)
    {
        self.controller = controller
        
        super.init()
        
        let inputChangedHandler: (_ input: MFiGameController.Input, _ pressed: Bool) -> Void = { [weak self] (input, pressed) in
            guard let self = self else { return }
            if pressed
            {
                self.activate(input)
            }
            else
            {
                self.deactivate(input)
            }
        }
        
        let thumbstickChangedHandler: (_ input1: MFiGameController.Input, _ input2: MFiGameController.Input, _ value: Float) -> Void = { [weak self] (input1, input2, value) in
            guard let self = self else { return }
            
            switch value
            {
            case ..<0:
                if abs(value) > deadZone {
                    self.activate(input1, value: Double(-value))
                } else {
                    print("忽略输入:\(input1.stringValue) value: \(-value) deadZone:\(deadZone)")
                }
                self.deactivate(input2)
                
            case 0:
                self.deactivate(input1)
                self.deactivate(input2)
                
            default:
                self.deactivate(input1)
                if abs(value) > deadZone {
                    self.activate(input2, value: Double(value))
                } else {
                    print("忽略输入:\(input2.stringValue) value: \(value) deadZone:\(deadZone)")
                }
            }
        }
        
        let profile = self.controller.physicalInputProfile
        profile.buttons[GCInputButtonA]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.a, pressed) }
        profile.buttons[GCInputButtonB]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.b, pressed) }
        profile.buttons[GCInputButtonX]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.x, pressed) }
        profile.buttons[GCInputButtonY]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.y, pressed) }
        
        profile.buttons[GCInputLeftShoulder]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.leftShoulder, pressed) }
        profile.buttons[GCInputLeftTrigger]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.leftTrigger, pressed) }
        profile.buttons[GCInputRightShoulder]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.rightShoulder, pressed) }
        profile.buttons[GCInputRightTrigger]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.rightTrigger, pressed) }
        
        profile.buttons[GCInputLeftThumbstickButton]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.leftThumbstickButton, pressed) }
        profile.buttons[GCInputRightThumbstickButton]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.rightThumbstickButton, pressed) }
        
        // Menu = Primary menu button (Start/+/Menu)
        let menuButton = profile.buttons[GCInputButtonMenu]
        menuButton?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.menu, pressed) }
        
        // Options = Secondary menu button (Select/-)
        if let optionsButton = profile.buttons[GCInputButtonOptions]
        {
            optionsButton.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.select, pressed) }
            
            // .alwaysReceive == asking permission to record screen every time button is pressed as of iOS 16.3 (annoying).
            // optionsButton.preferredSystemGestureState = .alwaysReceive
        }
        
        if let dPad = profile.dpads[GCInputDirectionPad]
        {
            dPad.up.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.up, pressed) }
            dPad.down.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.down, pressed) }
            dPad.left.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.left, pressed) }
            dPad.right.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.right, pressed) }
        }

        if let leftThumbstick = profile.dpads[GCInputLeftThumbstick]
        {
            leftThumbstick.xAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.leftThumbstickLeft, .leftThumbstickRight, value)
            }
            leftThumbstick.yAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.leftThumbstickDown, .leftThumbstickUp, value)
            }
        }
        
        if let rightThumbstick = profile.dpads[GCInputRightThumbstick]
        {
            rightThumbstick.xAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.rightThumbstickLeft, .rightThumbstickRight, value)
            }
            rightThumbstick.yAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.rightThumbstickDown, .rightThumbstickUp, value)
            }
        }
        
        let productCategory = ProductCategory(rawValue: self.controller.productCategory)
        switch productCategory
        {
        case .mfi:
            // MFi controllers typically only have one Menu button, so no need to re-map it.
            // menuButton?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.menu, pressed) }
            break
            
        case .joyConL, .joyConR:
            // Rotate single Joy-Con inputs 90º
            profile.buttons[GCInputButtonA]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.b, pressed) }
            profile.buttons[GCInputButtonB]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.y, pressed) }
            profile.buttons[GCInputButtonX]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.a, pressed) }
            profile.buttons[GCInputButtonY]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.x, pressed) }
            
            // For some reason, iOS treats the analog stick as a digital dPad input (as of iOS 16.3).
            // Re-map to .leftThumbstick instead to work as expected with N64 games.
            guard let dPad = profile.dpads[GCInputDirectionPad] else { break }
            dPad.xAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.leftThumbstickLeft, .leftThumbstickRight, value)
            }
            dPad.yAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.leftThumbstickDown, .leftThumbstickUp, value)
            }
            
            // Remove existing dPad change handlers to avoid duplicate inputs.
            dPad.up.pressedChangedHandler = nil
            dPad.down.pressedChangedHandler = nil
            dPad.left.pressedChangedHandler = nil
            dPad.right.pressedChangedHandler = nil
            
        case .switchOnlineNES, .switchOnlineSNES:
            guard var defaultMapping = self.defaultInputMapping as? GameControllerInputMapping else { break }
            
            // Re-map ZL and ZR buttons to Menu so we can treat Start as regular input.
            if productCategory == .switchOnlineNES
            {
                defaultMapping.set(StandardGameControllerInput.menu, forControllerInput: Input.leftShoulder)
                defaultMapping.set(StandardGameControllerInput.menu, forControllerInput: Input.rightShoulder)
            }
            else
            {
                defaultMapping.set(StandardGameControllerInput.menu, forControllerInput: Input.leftTrigger)
                defaultMapping.set(StandardGameControllerInput.menu, forControllerInput: Input.rightTrigger)
            }
            
            self.defaultInputMapping = defaultMapping
            
            // Re-map Start button to...Start
            menuButton?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.start, pressed) }
                        
        default:
            // Home = Home/"Logo" button
            guard let homeButton = profile.buttons[GCInputButtonHome] else { break }
            
            // If controller has Home button, and isn't MFi controller, treat it as Menu button instead.
            // e.g. Switch Pro, PlayStation, and Xbox controllers
            homeButton.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.menu, pressed) }
            
            // Disable "Show Game Center" gesture
            homeButton.preferredSystemGestureState = .disabled
            
            // Re-map Menu button to Start
            menuButton?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.start, pressed) }
        }
    }
}
