//
//  ExternalGameControllerManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/20/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import GameController

private let ExternalKeyboardStatusDidChange: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void = {
    (notificationCenter, observer, name, object, userInfo) in
    
    if ExternalGameControllerUtils.shared.isKeyboardConnected
    {
        NotificationCenter.default.post(name: .externalKeyboardDidConnect, object: nil)
    }
    else
    {
        NotificationCenter.default.post(name: .externalKeyboardDidDisconnect, object: nil)
    }
}

public extension Notification.Name
{
    static let externalGameControllerDidConnect = Notification.Name("ExternalGameControllerDidConnectNotification")
    static let externalGameControllerDidDisconnect = Notification.Name("ExternalGameControllerDidDisconnectNotification")
    
    static let externalKeyboardDidConnect = Notification.Name("ExternalKeyboardDidConnect")
    static let externalKeyboardDidDisconnect = Notification.Name("ExternalKeyboardDidDisconnect")
    
    static let externalGameControllerDidPress = Notification.Name("ExternalGameControllerDidPressNotification")
    static let externalGameControllerDidRelease = Notification.Name("ExternalGameControllerDidReleaseNotification")
}

public class ExternalGameControllerUtils: UIResponder
{
    public static let shared = ExternalGameControllerUtils()
    
    //MARK: - Properties -
    /** Properties **/
    public private(set) var linkedControllers: [GameController] = []
    
    public var autoPlayerIndexes: Bool
    
    public var forceSetPlayerIndex: Int? = nil
    
    public var deadZone: Float = 0.0 {
        didSet {
            linkedControllers.forEach {
                if let mfi = $0 as? MFiGameController {
                    mfi.deadZone = deadZone
                }
            }
        }
    }
    
    internal var keyboardController: KeyboardGameController? {
        let keyboardController = linkedControllers.lazy.compactMap { $0 as? KeyboardGameController }.first
        return keyboardController
    }
    
    internal var prefersKeyboardProcess: Bool {
        if ProcessInfo.processInfo.isiOSAppOnMac
        {
            // Legacy keyboard handling doesn't work on macOS, so use modern handling instead.
            // It's still in development, but better than nothing.
            return true
        }
        else
        {
            return false
        }
    }
    
    private var nextEnablePlayerIndex: Int {
        //如果设置了强制序号 就所有外设都设置为强制的序号
        if let forceSetPlayerIndex = forceSetPlayerIndex {
            return forceSetPlayerIndex
        }
        var nextPlayerIndex = -1
        
        let sortedGameControllers = linkedControllers.sorted { ($0.playerIndex ?? -1) < ($1.playerIndex ?? -1) }
        for controller in sortedGameControllers
        {
            let playerIndex = controller.playerIndex ?? -1
            
            if abs(playerIndex - nextPlayerIndex) > 1
            {
                break
            }
            else
            {
                nextPlayerIndex = playerIndex
            }
        }
        
        nextPlayerIndex += 1
        
        return nextPlayerIndex
    }
    
    private override init()
    {
#if targetEnvironment(simulator)
        autoPlayerIndexes = true
#else
        autoPlayerIndexes = true
#endif
        
        super.init()
    }

    private func existingMFiController(for controller: GCController) -> MFiGameController? {
        linkedControllers.first { linkedController in
            guard let mfiController = linkedController as? MFiGameController else { return false }
            return mfiController.controller == controller
        } as? MFiGameController
    }
    
    public func startDetecting()
    {
        for controller in GCController.controllers()
        {
            guard existingMFiController(for: controller) == nil else { continue }
            let externalController = MFiGameController(controller: controller)
            add(externalController)
        }
        
        if self.isKeyboardConnected
        {
            let keyboard = self.prefersKeyboardProcess ? GCKeyboard.coalesced : nil
            let keyboardController = KeyboardGameController(keyboard: keyboard)
            add(keyboardController)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerUtils.mfiGameControllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerUtils.mfiGameControllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerUtils.keyboardDidConnect(_:)), name: .externalKeyboardDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerUtils.keyboardDidDisconnect(_:)), name: .externalKeyboardDidDisconnect, object: nil)
        
        if #available(iOS 14, *)
        {
            NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerUtils.gcKeyboardDidConnect(_:)), name: .GCKeyboardDidConnect, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerUtils.gcKeyboardDidDisconnect(_:)), name: .GCKeyboardDidDisconnect, object: nil)
        }
        else
        {
            let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterAddObserver(notificationCenter, nil, ExternalKeyboardStatusDidChange, "GSEventHardwareKeyboardAttached" as CFString, nil, .deliverImmediately)
        }
    }
    
    func stopMonitoring()
    {
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidDisconnect, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: .externalKeyboardDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: .externalKeyboardDidDisconnect, object: nil)
        
        self.linkedControllers.removeAll()
    }
    
    func startWirelessControllerDiscovery(withCompletionHandler completionHandler: (() -> Void)?)
    {
        GCController.startWirelessControllerDiscovery(completionHandler: completionHandler)
    }
    
    func stopWirelessControllerDiscovery()
    {
        GCController.stopWirelessControllerDiscovery()
    }
    
    // Implementation based on Ian McDowell's tweet: https://twitter.com/ian_mcdowell/status/844572113759547392
    public var isKeyboardConnected: Bool = GCKeyboard.coalesced != nil
    
    override public func keyPressesBegan(_ presses: Set<KeyPress>, with event: UIEvent)
    {
        for case let keyboardController as KeyboardGameController in self.linkedControllers
        {
            keyboardController.keyPressesBegan(presses, with: event)
        }
    }
    
    override public func keyPressesEnded(_ presses: Set<KeyPress>, with event: UIEvent)
    {
        for case let keyboardController as KeyboardGameController in self.linkedControllers
        {
            keyboardController.keyPressesEnded(presses, with: event)
        }
    }
    
    func add(_ controller: GameController)
    {
        if let mfiController = controller as? MFiGameController,
           existingMFiController(for: mfiController.controller) != nil {
            return
        }

        if let keyboardController = controller as? KeyboardGameController,
           linkedControllers.contains(where: { $0 is KeyboardGameController && $0 !== keyboardController }) {
            return
        }

        if autoPlayerIndexes
        {
            let playerIndex = nextEnablePlayerIndex
            controller.playerIndex = playerIndex
        }
        
        linkedControllers.append(controller)
        
        NotificationCenter.default.post(name: .externalGameControllerDidConnect, object: controller)
    }
    
    func remove(_ controller: GameController)
    {
        guard let index = linkedControllers.firstIndex(where: { $0.isEqual(controller) }) else { return }
        
        linkedControllers.remove(at: index)
        
        NotificationCenter.default.post(name: .externalGameControllerDidDisconnect, object: controller)
    }
    
    @objc func mfiGameControllerDidConnect(_ notification: Notification)
    {
        guard let controller = notification.object as? GCController else { return }
        guard existingMFiController(for: controller) == nil else { return }
        
        let externalController = MFiGameController(controller: controller)
        externalController.deadZone = deadZone
        add(externalController)
    }
    
    @objc func mfiGameControllerDidDisconnect(_ notification: Notification)
    {
        guard let controller = notification.object as? GCController else { return }
        
        for externalController in linkedControllers
        {
            guard let mfiController = externalController as? MFiGameController else { continue }
            
            if mfiController.controller == controller
            {
                remove(externalController)
            }
        }
    }
    
    @objc func gcKeyboardDidConnect(_ notification: Notification)
    {
        NotificationCenter.default.post(name: .externalKeyboardDidConnect, object: nil)
    }
    
    @objc func gcKeyboardDidDisconnect(_ notification: Notification)
    {
        NotificationCenter.default.post(name: .externalKeyboardDidDisconnect, object: nil)
    }
    
    @objc func keyboardDidConnect(_ notification: Notification)
    {
        guard keyboardController == nil else { return }
        
        let keyboard = prefersKeyboardProcess ? GCKeyboard.coalesced : nil
        let keyboardController = KeyboardGameController(keyboard: keyboard)
        self.add(keyboardController)
    }
    
    @objc func keyboardDidDisconnect(_ notification: Notification)
    {
        guard let keyboardController = keyboardController else { return }
        
        remove(keyboardController)
    }
}
