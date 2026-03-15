//
//  EmulatorCore.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/11/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import AVFoundation

extension EmulatorCore {
    @objc public static let emulationDidQuitNotification = Notification.Name("com.aoshuang.EmulatorCore.emulationDidQuit")
    
    private static let didUpdateFrameNotification = Notification.Name("com.aoshuang.EmulatorCore.didUpdateFrame")
}

public extension EmulatorCore {
    typealias Option = __EmulatorCoreOption
    
    @objc enum State: Int {
        case stopped
        case running
        case paused
    }
    
    enum CheatError: Error {
        case invalid
    }
    
    enum SaveStateError: Error {
        case doesNotExist
    }
}

@objc(MEEmulatorCore)
public final class EmulatorCore: NSObject {
    //MARK: - Properties -
    /** Properties **/
    public let game: GameBase
    public let options: [Option: Any]
    
    public var gameViews: Set<GameView> {
        return _gameViews.setRepresentation as! Set<GameView>
    }
    private let _gameViews: NSHashTable = NSHashTable<GameView>.weakObjects()
    
    public var updateHandler: ((EmulatorCore) -> Void)?
    public var saveHandler: ((EmulatorCore) -> Void)?
    
    public let audioManager: AudioUtils
    public let videoManager: VideoUtils
    
    // KVO-Compliant
    @objc public private(set) dynamic var state = State.stopped
    @objc public dynamic var rate = 1.0 {
        didSet {
            audioManager.rate = rate
        }
    }
    
    public let manicCore: ManicEmuCoreProtocol
    public var preferredRenderSize: CGSize { return manicCore.videoFormat.dimensions }
    
    //MARK: - Private Properties
    
    // We privately set this first to clean up before setting self.state, which notifies KVO observers
    private var _state = State.stopped
    
    private let gameType: GameType
    private let gameSaveURL: URL
    
    public var cheatCodes = [String: CheatType]()
    
    private var gameControllers = NSHashTable<AnyObject>.weakObjects()
    
    private var previousState = State.stopped
    private var preFrameTime: TimeInterval? = nil
    private var acceptsControllerInput = false
    
    private var resumeInputDispatchGroup: DispatchGroup?
    private let resumeInputsQueue = DispatchQueue(label: "com.aoshuang.EmulatorCore.EmulatorCore.reactivateInputsQueue", attributes: [.concurrent])
    
    private let emulationLock = NSLock()
    
    //MARK: - Initializers -
    /** Initializers **/
    public required init?(game: GameBase, options: [Option: Any] = [:]) {
        // These MUST be set in start(), because it's possible the same emulator core might be stopped, another one started, and then resumed back to this one
        // AKA, these need to always be set at start to ensure it points to the correct managers
        // self.configuration.bridge.audioRenderer = self.audioManager
        // self.configuration.bridge.videoRenderer = self.videoManager
        
        guard let deltaCore = ManicEmu.core(for: game.type) else {
            print(game.type.rawValue + " is not a supported game type.")
            return nil
        }
        
        self.manicCore = deltaCore
        
        self.game = game
        self.options = options
        
        // Store separately in case self.game is an NSManagedObject subclass, and we need to access .type or .gameSaveURL on a different thread than its NSManagedObjectContext
        self.gameType = self.game.type
        self.gameSaveURL = self.game.gameSaveURL
        
        var videoFormat = deltaCore.videoFormat
        if let prefersOpenGLES2 = self.options[.openGLES2] as? Bool, prefersOpenGLES2, videoFormat.format == .openGLES3 {
            // Override core's video format to use OpenGL ES 2.0 instead.
            videoFormat.format = .openGLES2
        }
        
        // These were previously lazy variables, but turns out Swift lazy variables are not thread-safe.
        // Since they don't actually need to be lazy, we now explicitly initialize them in the initializer.
        self.audioManager = AudioUtils(audioFormat: deltaCore.audioFormat)
        self.videoManager = VideoUtils(videoFormat: videoFormat, options: options)
        
        //Manic修改
        self.audioManager.isEnabled = false
        self.videoManager.isEnabled = false
                
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(EmulatorCore.emulationDidQuit), name: EmulatorCore.emulationDidQuitNotification, object: nil)
    }
}

//MARK: - Emulation -
/// Emulation
public extension EmulatorCore {
    @discardableResult func start() -> Bool {
        guard _state == .stopped else { return false }

        emulationLock.lock()

        acceptsControllerInput = false

        _state = .running
        defer { state = _state }
        
        manicCore.emulatorConnector.audioRenderer = self.audioManager
        manicCore.emulatorConnector.videoRenderer = self.videoManager
        manicCore.emulatorConnector.saveUpdateHandler = { [weak self] in
            guard let self = self else { return }
            self.save()
        }
        
        audioManager.start()
        manicCore.emulatorConnector.start(withGameURL: game.fileURL)
        manicCore.emulatorConnector.loadGameSave(from: gameSaveURL)
        acceptsControllerInput = true

        runGameLoop()
        waitingForUpdate()
        
        emulationLock.unlock()
        
        return true
    }
    
    @discardableResult func stop() -> Bool {
        guard _state != .stopped else { return false }
        
        emulationLock.lock()
        
        let isRunning = state == .running

        _state = .stopped
        acceptsControllerInput = false
        defer { state = _state }
        
        if isRunning
        {
            waitingForUpdate()
        }
        
        save()
        
        audioManager.stop()
        manicCore.emulatorConnector.stop()
        
        emulationLock.unlock()
        
        return true
    }
    
    @discardableResult func pause() -> Bool
    {
        guard _state == .running else { return false }
        
        emulationLock.lock()
        
        _state = .paused
        acceptsControllerInput = false
        defer { state = _state }
        
        waitingForUpdate()
        
        save()
        
        audioManager.isEnabled = false
        manicCore.emulatorConnector.pause()
        
        emulationLock.unlock()
        
        return true
    }
    
    @discardableResult func resume(prefersVolumeEnable: Bool) -> Bool {
        guard _state == .paused else { return false }
        
        emulationLock.lock()
        
        _state = .running
        defer { state = _state }
        //恢复游戏的时候声音是否恢复由外部来决定
        if prefersVolumeEnable {
            audioManager.isEnabled = true
        } else {
            audioManager.isEnabled = false
        }

        manicCore.emulatorConnector.resume()
        acceptsControllerInput = true

        runGameLoop()
        waitingForUpdate()
        
        emulationLock.unlock()
        
        return true
    }
    
    private func waitingForUpdate() {
        let semaphore = DispatchSemaphore(value: 0)

        let token = NotificationCenter.default.addObserver(forName: EmulatorCore.didUpdateFrameNotification, object: self, queue: nil) { (notification) in
            semaphore.signal()
        }

        semaphore.wait()

        NotificationCenter.default.removeObserver(token, name: EmulatorCore.didUpdateFrameNotification, object: self)
    }
    
    public func add(_ gameView: GameView) {
        guard !gameViews.contains(gameView) else { return }
        
        _gameViews.add(gameView)
        videoManager.add(gameView)
    }
    
    public func remove(_ gameView: GameView) {
        _gameViews.remove(gameView)
        videoManager.remove(gameView)
    }
    
    public func save() {
        let parentUrl = gameSaveURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentUrl.path) {
            try! FileManager.default.createDirectory(at: parentUrl, withIntermediateDirectories: true)
        }
        manicCore.emulatorConnector.saveGameSave(to: gameSaveURL)
        saveHandler?(self)
    }
    
    @discardableResult public func saveSaveState(to url: URL) -> SaveStateBase {
        manicCore.emulatorConnector.saveSaveState(to: url)
        
        let saveState = SaveState(fileURL: url, gameType: gameType)
        return saveState
    }
    
    public func load(_ saveState: SaveStateBase, ignoreActivatedInputs: Bool = false) throws {
        guard FileManager.default.fileExists(atPath: saveState.fileURL.path) else { throw SaveStateError.doesNotExist }
        
        manicCore.emulatorConnector.loadSaveState(from: saveState.fileURL)
        
        updateCheats()
        manicCore.emulatorConnector.resetInputs()
        
        // Reactivate activated inputs.
        if !ignoreActivatedInputs {
            for gameController in gameControllers.allObjects as! [GameController] {
                for (input, value) in gameController.activatedInputs {
                    gameController.activate(input, value: value)
                }
            }
        }
    }
    
    public func activate(_ cheat: CheatBase) throws {
        let success = manicCore.emulatorConnector.addCheatCode(String(cheat.code), type: cheat.type.rawValue)
        if success {
            cheatCodes[cheat.code] = cheat.type
        }
        
        // Ensures correct state, especially if attempted cheat was invalid
        updateCheats()
        
        if !success {
            throw CheatError.invalid
        }
    }
    
    public func deactivate(_ cheat: CheatBase) {
        guard cheatCodes[cheat.code] != nil else { return }
        
        cheatCodes[cheat.code] = nil
        
        updateCheats()
    }
    
    private func updateCheats() {
        manicCore.emulatorConnector.resetCheats()
        
        for (cheatCode, type) in cheatCodes {
            manicCore.emulatorConnector.addCheatCode(String(cheatCode), type: type.rawValue)
        }
        
        manicCore.emulatorConnector.updateCheats()
    }
    
    func runGameLoop() {
        let emulationQueue = DispatchQueue(label: "com.aoshuang.EmulatorCore.emulationQueue", qos: .userInitiated)
        emulationQueue.async { [weak self] in
            guard let self = self else { return }
            
            let screenRefreshRate = 1.0 / 60.0
            
            var emulationTime = Thread.absoluteSystemTime
            var counter = 0.0
            
            while true {
                let frameDuration = self.manicCore.emulatorConnector.frameDuration / self.rate
                if frameDuration != self.preFrameTime {
                    Thread.setRealTimePriority(withPeriod: frameDuration)
                    
                    self.preFrameTime = frameDuration
                    
                    // Reset counter
                    counter = 0
                }
                
                // Update audio configurations if necessary.
                
                let internalFrameDuration = self.manicCore.emulatorConnector.frameDuration
                if internalFrameDuration != self.audioManager.frameDuration {
                    self.audioManager.frameDuration = internalFrameDuration
                }
                
                let audioFormat = self.manicCore.audioFormat
                if audioFormat != self.audioManager.audioFormat {
                    self.audioManager.audioFormat = audioFormat
                }
                
                if counter >= screenRefreshRate {
                    self.runFrame(renderGraphics: true)
                    
                    // Reset counter
                    counter = 0
                } else {
                    // No need to render graphics more than once per screen refresh rate
                    self.runFrame(renderGraphics: false)
                }
                
                counter += frameDuration
                emulationTime += frameDuration
                
                let currentTime = Thread.absoluteSystemTime
                
                // The number of frames we need to skip to keep in sync
                var framesToSkip = Int((currentTime - emulationTime) / frameDuration)
                framesToSkip = min(framesToSkip, 5) // Prevent unbounding frame skipping resulting in frozen game.
                
                if framesToSkip > 0 {
                    // Only actually skip frames if we're running at normal speed
                    if self.rate == 1.0 {
                        for _ in 0 ..< framesToSkip {
                            // "Skip" frames by running them without rendering graphics
                            self.runFrame(renderGraphics: false)
                        }
                    }
                    
                    emulationTime = currentTime
                }
                
                // Prevent race conditions
                let state = self._state
                
                defer {
                    if self.previousState != state {
                        NotificationCenter.default.post(name: EmulatorCore.didUpdateFrameNotification, object: self)
                        self.previousState = state
                    }
                }
                
                if state != .running {
                    break
                }
                
                Thread.realTimeWait(until: emulationTime)
            }
        }
    }
    
    func runFrame(renderGraphics: Bool) {
        self.manicCore.emulatorConnector.runFrame(processVideo: renderGraphics)
        
        if renderGraphics {
            videoManager.render()
        }
        
        if let dispatchGroup = resumeInputDispatchGroup {
            dispatchGroup.leave()
        }
        
        updateHandler?(self)
    }
    
    @objc func emulationDidQuit(_ notification: Notification) {
        guard let bridge = notification.object as? EmulatorBase, bridge.gameURL == game.fileURL else { return }
        
        // Re-post notification with `self` as object.
        NotificationCenter.default.post(name: EmulatorCore.emulationDidQuitNotification, object: self, userInfo: nil)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // Dispatch onto global queue to prevent deadlock.
            self.stop()
        }
    }
}

extension EmulatorCore: ControllerReceiverProtocol {
    private func hasActiveGameScene() -> Bool {
        guard !gameViews.isEmpty else { return true }

        return gameViews.contains { gameView in
            guard let scene = gameView.window?.windowScene else { return false }
            return scene.activationState == .foregroundActive
        }
    }

    public func gameController(_ gameController: GameController, didActivate controllerInput: Input, value: Double) {
        guard acceptsControllerInput else { return }

        // Fallback to player 0 if index is temporarily unavailable.
        let playerIndex = gameController.playerIndex ?? 0

        gameControllers.add(gameController)
        
//        if let input = mappedInput(for: controllerInput) {
//            print(">>>>controllerInput:\(controllerInput) \(controllerInput.type)\n mappedInput:\(input) \(input.type)")
//        } else {
//            print(">>>>controllerInput:\(controllerInput) \(controllerInput.type)\n 映射失败")
//        }
        
        
        guard let input = mappedInput(for: controllerInput), input.type == .game(gameType) else { return }

        if gameType.rawValue == "public.aoshuang.game.n64" {
            NotificationCenter.default.post(name: Notification.Name("ManicN64InputTraceNotification"), object: nil, userInfo: ["message": String(format: "EMU on %@ -> %@ p%d v%.2f", controllerInput.stringValue, input.stringValue, playerIndex, value)])
        }
        
        // If any of game controller's continue inputs map to input, treat input as continue.
        let continueControllerInput = gameController.continueInputs.first { (continueInput, value) in
            guard let newInput = gameController.mappedInput(for: continueInput, receiver: self) else { return false }
            return mappedInput(for: newInput) == input
        }
        
        let discreteThreshold = 0.0
        var adjustedValue: Double? = value
        
        if !input.isContinuous, value < discreteThreshold {
            // input is discrete, so ignore values less than 0.33 to avoid eagerly activating.
            // This significantly improves using analog sticks as dpad inputs.
            
            if let continueControllerInput, continueControllerInput.value >= discreteThreshold {
                // Set adjustedValue to continue value to reset.
                adjustedValue = continueControllerInput.value
            }
            else {
                // input is not continue, or continue value is less than threshold,
                // so we'll deactivate the input instead.
                adjustedValue = nil
            }
        }
        
        if let adjustedValue {
            if let continueControllerInput, !continueControllerInput.key.isContinuous, !input.isContinuous {
                // input is continue, but neither it nor the controller input are continuous.
                // This means we need to temporarily deactivate the input before activating it again.
                resumeInputsQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.manicCore.emulatorConnector.deactivateInput(input.intValue!, playerIndex: playerIndex)
                    
                    self.resumeInputDispatchGroup = DispatchGroup()
                    
                    // To ensure the emulator core recognizes us activating an input that is currently active, we need to first deactivate it, wait at least two frames, then activate it again.
                    self.resumeInputDispatchGroup?.enter()
                    self.resumeInputDispatchGroup?.enter()
                    self.resumeInputDispatchGroup?.wait()

                    self.resumeInputDispatchGroup = nil
                    
                    if gameController.continueInputs.keys.contains(continueControllerInput.key)
                    {
                        // Make sure input is still continue before reactivating it.
                        self.manicCore.emulatorConnector.activateInput(input.intValue!, value: adjustedValue, playerIndex: playerIndex)
                    }
                }
            }
            else {
                // Because continuous continueControllerInput values are deactivated when below discreteThreshold,
                // we don't need to manually deactivate them first since that will implicitly happen during user gesture.
                manicCore.emulatorConnector.activateInput(input.intValue!, value: adjustedValue, playerIndex: playerIndex)
            }
        }
        else {
            // Treat input as deactivated if adjustedValue is nil (a.k.a. below discreteThreshold).
            self.gameController(gameController, didDeactivate: controllerInput)
        }
    }
    
    public func gameController(_ gameController: GameController, didDeactivate input: Input) {
        guard acceptsControllerInput else { return }

        // Fallback to player 0 if index is temporarily unavailable.
        let playerIndex = gameController.playerIndex ?? 0

        guard let input = mappedInput(for: input), input.type == .game(gameType) else { return }

        if gameType.rawValue == "public.aoshuang.game.n64" {
            NotificationCenter.default.post(name: Notification.Name("ManicN64InputTraceNotification"), object: nil, userInfo: ["message": "EMU off \(input.stringValue) p\(playerIndex)"])
        }
        
        manicCore.emulatorConnector.deactivateInput(input.intValue!, playerIndex: playerIndex)
    }
    
    private func mappedInput(for input: Input) -> Input? {
        if input.type == .game(gameType) {
            return input
        }

        let standardInput: StandardGameControllerInput?

        if input.type == .controller(.mfi) {
            switch input.stringValue {
            case "menu": standardInput = .menu
            case "up": standardInput = .up
            case "down": standardInput = .down
            case "left": standardInput = .left
            case "right": standardInput = .right
            case "leftThumbstickUp": standardInput = .leftThumbstickUp
            case "leftThumbstickDown": standardInput = .leftThumbstickDown
            case "leftThumbstickLeft": standardInput = .leftThumbstickLeft
            case "leftThumbstickRight": standardInput = .leftThumbstickRight
            case "rightThumbstickUp": standardInput = .rightThumbstickUp
            case "rightThumbstickDown": standardInput = .rightThumbstickDown
            case "rightThumbstickLeft": standardInput = .rightThumbstickLeft
            case "rightThumbstickRight": standardInput = .rightThumbstickRight
            case "a": standardInput = .a
            case "b": standardInput = .b
            case "x": standardInput = .x
            case "y": standardInput = .y
            case "leftShoulder": standardInput = .l1
            case "leftTrigger": standardInput = .l2
            case "rightShoulder": standardInput = .r1
            case "rightTrigger": standardInput = .r2
            case "start": standardInput = .start
            case "select": standardInput = .select
            case "leftThumbstickButton": standardInput = .l3
            case "rightThumbstickButton": standardInput = .r3
            default: standardInput = nil
            }
        } else {
            standardInput = StandardGameControllerInput(stringValue: input.stringValue)
        }

        guard let standardInput else { return nil }

        return standardInput.input(for: gameType)
    }
}
