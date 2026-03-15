//
//  GameControllerStateManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

internal class GameControllerStateUtils
{
    let gameController: GameController
    
    private(set) var activatedInputs = [SomeInput: Double]()
    private(set) var continueInputs = [SomeInput: Double]()
    
    var receivers: [ControllerReceiverProtocol] {
        var objects: [ControllerReceiverProtocol]!
        
        self.dispatchQueue.sync { [weak self] in
            guard let self = self else { return }
            objects = self._receivers.keyEnumerator().allObjects as? [ControllerReceiverProtocol]
        }
        
        return objects
    }

    private let _receivers = NSMapTable<AnyObject, AnyObject>.weakToStrongObjects()
    
    // Used to synchronize access to _receivers to prevent race conditions (yay ObjC)
    private let dispatchQueue = DispatchQueue(label: "com.aoshuang.EmulatorCore.GameControllerStateManager.dispatchQueue")
    
    
    init(gameController: GameController)
    {
        self.gameController = gameController
    }
    
    func addReceiver(_ receiver: ControllerReceiverProtocol, inputMapping: GameControllerInputMappingBase?)
    {
        dispatchQueue.sync { [weak self] in
            guard let self = self else { return }
            self._receivers.setObject(inputMapping as AnyObject, forKey: receiver)
        }
    }
    
    func removeReceiver(_ receiver: ControllerReceiverProtocol)
    {
        dispatchQueue.sync { [weak self] in
            guard let self = self else { return }
            _receivers.removeObject(forKey: receiver)
        }
    }
    
    func activate(_ input: Input, value: Double)
    {
        precondition(input.type == .controller(gameController.inputType), "input.type must match self.gameController.inputType")
         
        // An input may be "activated" multiple times, such as by pressing different buttons that map to same input, or moving an analog stick.
        activatedInputs[SomeInput(input)] = value

        for receiver in receivers
        {
            if let mappedInput = mappedInput(for: input, receiver: receiver)
            {
                receiver.gameController(gameController, didActivate: mappedInput, value: value)
            }
        }
    }
    
    func deactivate(_ input: Input)
    {
        precondition(input.type == .controller(gameController.inputType), "input.type must match self.gameController.inputType")
        
        // Unlike activate(_:), we don't allow an input to be deactivated multiple times.
        guard activatedInputs.keys.contains(SomeInput(input)) else { return }
        
        if let continueValue = continueInputs[SomeInput(input)]
        {
            if input.isContinuous
            {
                // Input is continuous and currently continue, so reset value to continue value.
                activate(input, value: continueValue)
            }
        }
        else
        {
            // Not continue, so simply deactivate it.
            activatedInputs[SomeInput(input)] = nil
            
            for receiver in receivers
            {
                if let mappedInput = mappedInput(for: input, receiver: receiver)
                {
                    let hasActivatedMappedControllerInputs = activatedInputs.keys.contains {
                        guard let input = self.mappedInput(for: $0, receiver: receiver) else { return false }
                        return input == mappedInput
                    }
                    
                    if !hasActivatedMappedControllerInputs
                    {
                        // All controller inputs that map to this input have been deactivated, so we can deactivate the mapped input.
                        receiver.gameController(gameController, didDeactivate: mappedInput)
                    }
                }
            }
        }
    }
    
    func makeContinue(_ input: Input, value: Double)
    {
        precondition(input.type == .controller(gameController.inputType), "input.type must match self.gameController.inputType")
        
        if self.activatedInputs[SomeInput(input)] != value
        {
            self.activate(input, value: value)
        }

        self.continueInputs[SomeInput(input)] = value
    }
    
    // Technically not a word, but no good alternative, so ¯\_(ツ)_/¯
    func stopContinue(_ input: Input)
    {
        precondition(input.type == .controller(gameController.inputType), "input.type must match self.gameController.inputType")
        
        self.continueInputs[SomeInput(input)] = nil
        
        self.deactivate(SomeInput(input))
    }
    
    func inputMapping(for receiver: ControllerReceiverProtocol) -> GameControllerInputMappingBase?
    {
        let inputMapping = _receivers.object(forKey: receiver) as? GameControllerInputMappingBase
        return inputMapping
    }
    
    func mappedInput(for input: Input, receiver: ControllerReceiverProtocol) -> Input?
    {
        guard let inputMapping = inputMapping(for: receiver) else { return input }
        
        let mappedInput = inputMapping.input(forControllerInput: input)
        return mappedInput
    }
}
