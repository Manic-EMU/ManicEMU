//
//  GameViewController.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/4/16.
//  Happy 4th of July, Everyone! 🎉
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation

fileprivate extension NSLayoutConstraint
{
    class func constraints(aspectFitting view1: UIView, to view2: UIView) -> [NSLayoutConstraint]
    {
        let boundingWidthConstraint = view1.widthAnchor.constraint(lessThanOrEqualTo: view2.widthAnchor, multiplier: 1.0)
        let boundingHeightConstraint = view1.heightAnchor.constraint(lessThanOrEqualTo: view2.heightAnchor, multiplier: 1.0)
        
        let widthConstraint = view1.widthAnchor.constraint(equalTo: view2.widthAnchor)
        widthConstraint.priority = .defaultHigh
        
        let heightConstraint = view1.heightAnchor.constraint(equalTo: view2.heightAnchor)
        heightConstraint.priority = .defaultHigh
        
        return [boundingWidthConstraint, boundingHeightConstraint, widthConstraint, heightConstraint]
    }
}

public protocol GameViewControllerDelegate: AnyObject
{
    func gameViewControllerShouldPause(_ gameViewController: GameViewController) -> Bool
    func gameViewControllerShouldResume(_ gameViewController: GameViewController) -> Bool
    
    func gameViewController(_ gameViewController: GameViewController, handleMenuInputFrom gameController: GameController)
    
    func gameViewControllerDidUpdate(_ gameViewController: GameViewController)
    func gameViewController(_ gameViewController: GameViewController, didUpdateGameViews gameViews: [GameView])
    
    func gameViewController(_ gameViewController: GameViewController, optionsFor game: GameBase) -> [EmulatorCore.Option: Any]
}

public extension GameViewControllerDelegate
{
    func gameViewControllerShouldPause(_ gameViewController: GameViewController) -> Bool { return true }
    func gameViewControllerShouldResume(_ gameViewController: GameViewController) -> Bool { return true }
    
    func gameViewController(_ gameViewController: GameViewController, handleMenuInputFrom gameController: GameController) {}
    
    func gameViewControllerDidUpdate(_ gameViewController: GameViewController) {}
    func gameViewController(_ gameViewController: GameViewController, didUpdateGameViews gameViews: [GameView]) {}
    
    func gameViewController(_ gameViewController: GameViewController, optionsFor game: GameBase) -> [EmulatorCore.Option: Any] { return [:] }
}

private var kvoContext = 0

open class GameViewController: UIViewController, ControllerReceiverProtocol
{
    open var game: GameBase?
    {
        didSet
        {
            if let game = self.game
            {
                let options = self.delegate?.gameViewController(self, optionsFor: game) ?? [:]
                manicEmuCore = EmulatorCore(game: game, options: options)
            }
            else
            {
                manicEmuCore = nil
            }
        }
    }
    
    open private(set) var manicEmuCore: EmulatorCore?
    {
        didSet
        {
            oldValue?.stop()
            
            manicEmuCore?.updateHandler = { [weak self] core in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.gameViewControllerDidUpdate(strongSelf)
            }
            
            prepareForGame()
        }
    }
    
    open weak var delegate: GameViewControllerDelegate?
    
    public var autoPauses: Bool = true
    
    public var gameView: GameView! {
        return gameViews.first
    }
    public private(set) var gameViews: [GameView] = []
        
    open private(set) var controllerView: ControllerView!
    private var splitViewHeight: CGFloat = 0
    
    private var tapGestureRecognizer: UITapGestureRecognizer!
    
    private let manicEmuCoreQueue = DispatchQueue(label: "com.aoshuang.EmulatorCore.GameViewController.emulatorCoreQueue", qos: .userInitiated)
    
    private var appPlacementLayoutGuide: UILayoutGuide!
    private var appPlacementXConstraint: NSLayoutConstraint!
    private var appPlacementYConstraint: NSLayoutConstraint!
    private var appPlacementWidthConstraint: NSLayoutConstraint!
    private var appPlacementHeightConstraint: NSLayoutConstraint!
    
    // HACK: iOS 16 beta 5 sends multiple incorrect keyboard focus notifications when resuming from background.
    // As a workaround, we ignore all notifications when returning from background, and then wait an extra delay
    // after app becomes active before checking keyboard focus to ensure we get the correct value.
    private var isGoingToForeground: Bool = false
    private weak var detectKeyboardFocusTimer: Timer?
    
    //添加一个属性 用户当前是否需要声音
    open var prefersVolumeEnable = true
    
    /// UIViewController
    open override var prefersStatusBarHidden: Bool {
        return true
    }
    
    public required init()
    {
        super.init(nibName: nil, bundle: nil)
        
        initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        initialize()
    }
    
    private func initialize()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardWillShow(with:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardWillChangeFrame(with:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardWillHide(with:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.willResignActive(with:)), name: UIScene.willDeactivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.didBecomeActive(with:)), name: UIScene.didActivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.willEnterForeground(_:)), name: UIScene.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.sceneKeyboardFocusDidChange(_:)), name: UIScene.keyboardFocusDidChangeNotification, object: nil)
    }
    
    deinit
    {
        // controllerView might not be initialized by the time deinit is called.
        controllerView?.removeObserver(self, forKeyPath: #keyPath(ControllerView.isHidden), context: &kvoContext)
        
        manicEmuCore?.stop()
    }
    
    // MARK: - UIViewController -
    /// UIViewController
    // These would normally be overridden in a public extension, but overriding these methods in subclasses of GameViewController segfaults compiler if so
    
    open override var prefersHomeIndicatorAutoHidden: Bool
    {
        let prefersHomeIndicatorAutoHidden = view.bounds.width > view.bounds.height
        return prefersHomeIndicatorAutoHidden
    }
    
    open dynamic override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        
        appPlacementLayoutGuide = UILayoutGuide()
        view.addLayoutGuide(self.appPlacementLayoutGuide)
        
        let gameView = GameView(frame: CGRect.zero)
        view.addSubview(gameView)
        gameViews.append(gameView)
        
        controllerView = ControllerView(frame: CGRect.zero)
        controllerView.placementLayoutGuide = appPlacementLayoutGuide
        view.addSubview(controllerView)
        
        controllerView.addObserver(self, forKeyPath: #keyPath(ControllerView.isHidden), options: [.old, .new], context: &kvoContext)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.updateGameViews), name: ControllerView.controllerSkinDidChangeNotification, object: controllerView)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.controllerViewDidUpdateGameViews(_:)), name: ControllerView.didUpdateGameViewsNotification, object: controllerView)
        
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(GameViewController.resumeIfNeeded))
        tapGestureRecognizer.delegate = self
        view.addGestureRecognizer(tapGestureRecognizer)
        
        prepareForGame()
        
        appPlacementXConstraint = appPlacementLayoutGuide.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0)
        appPlacementYConstraint = appPlacementLayoutGuide.topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
        appPlacementWidthConstraint = appPlacementLayoutGuide.widthAnchor.constraint(equalToConstant: 0)
        appPlacementHeightConstraint = appPlacementLayoutGuide.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([appPlacementXConstraint, appPlacementYConstraint, appPlacementWidthConstraint, appPlacementHeightConstraint])
    }
    
    open dynamic override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        manicEmuCoreQueue.async {
            _ = self._startEmulation()
        }
    }
    
    open dynamic override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        UIApplication.manicShared?.isIdleTimerDisabled = true
        
        if game != nil
        {
            controllerView.becomeFirstResponder()
        }
        
        if let scene = view.window?.windowScene
        {
            scene.startDetectKeyboardFocus()
        }
    }
    
    open dynamic override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        UIApplication.manicShared?.isIdleTimerDisabled = false
        
        manicEmuCoreQueue.async {
            _ = self._pauseEmulation()
        }
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        controllerView.beginUpdateSkin()
        
        // Disable VideoManager temporarily to prevent random Metal crashes due to rendering while adjusting layout.
        let isVideoManagerEnabled = manicEmuCore?.videoManager.isEnabled ?? true
        manicEmuCore?.videoManager.isEnabled = false
        
        // As of iOS 11, the keyboard NSNotifications may return incorrect values for split view controller input view when rotating device.
        // As a workaround, we explicitly resign controllerView as first responder, then restore first responder status after rotation.
        let isControllerViewFirstResponder = controllerView.isFirstResponder
        controllerView.resignFirstResponder()
        
        self.view.setNeedsUpdateConstraints()
        
        coordinator.animate(alongsideTransition: { (context) in
            self.updateGameViews()
        }) { (context) in
            self.controllerView.finishUpdateSkin()
            
            if isControllerViewFirstResponder
            {
                self.controllerView.becomeFirstResponder()
            }
            
            // Re-enable VideoManager if necessary.
            self.manicEmuCore?.videoManager.isEnabled = isVideoManagerEnabled
        }
    }
    
    open override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let controllerViewFrame: CGRect
        let availableGameFrame: CGRect
        
        /* Controller View */
        switch controllerView.controllerSkinTraits
        {
        case let traits? where traits.displayType == .splitView:
            // Split-View:
            // - Controller View is pinned to bottom and spans width of device as keyboard input view.
            // - Game View should be vertically centered between top of screen and input view.
            
            controllerViewFrame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height)
            (_, availableGameFrame) = view.bounds.divided(atDistance: splitViewHeight, from: .maxYEdge)
            
        case .none: fallthrough
        case _? where controllerView.isHidden:
            // Controller View Hidden:
            // - Controller View should have a height of 0.
            // - Game View should be centered in self.view.
             
            (controllerViewFrame, availableGameFrame) = view.bounds.divided(atDistance: 0, from: .maxYEdge)
            
        case let traits? where traits.orientation == .portrait && !(controllerView.controllerSkin?.screens(for: traits) ?? []).contains(where: { $0.placement == .controller }):
            // Portrait (and no custom screens with `controller` placement):
            // - Controller View should be pinned to bottom of self.view and centered horizontally.
            // - Game View should be vertically centered between top of screen and controller view.
            
            let intrinsicContentSize = controllerView.intrinsicContentSize
            if intrinsicContentSize.height != UIView.noIntrinsicMetric && intrinsicContentSize.width != UIView.noIntrinsicMetric
            {
                let controllerViewHeight = (view.bounds.width / intrinsicContentSize.width) * intrinsicContentSize.height
                (controllerViewFrame, availableGameFrame) = view.bounds.divided(atDistance: controllerViewHeight, from: .maxYEdge)
            }
            else
            {
                controllerViewFrame = view.bounds
                availableGameFrame = view.bounds
            }
            
        case _?:
            // Landscape (or Portrait with custom screens using `controller` placement):
            // - Controller View should be centered vertically in view (though most of the time its height will == self.view height).
            // - Game View should be centered in self.view.
                        
            let intrinsicContentSize = self.controllerView.intrinsicContentSize
            if intrinsicContentSize.height != UIView.noIntrinsicMetric && intrinsicContentSize.width != UIView.noIntrinsicMetric
            {
                controllerViewFrame = AVMakeRect(aspectRatio: intrinsicContentSize, insideRect: view.bounds)
            }
            else
            {
                controllerViewFrame = view.bounds
            }
            
            availableGameFrame = view.bounds
        }
        
        controllerView.frame = controllerViewFrame
        
        let gameScreenDimensions = manicEmuCore?.preferredRenderSize ?? CGSize(width: 1, height: 1)
        let contentAspectRatio: CGSize
        
        if let traits = controllerView.controllerSkinTraits,
           let controllerSkin = controllerView.controllerSkin,
           let aspectRatio = controllerSkin.contentSize(for: traits)
        {
            contentAspectRatio = aspectRatio
        }
        else
        {
            // Fall back to `gameScreenDimensions` if controller skin does not define `contentSize`.
            contentAspectRatio = gameScreenDimensions
        }
        
        let appPlacementFrame = AVMakeRect(aspectRatio: contentAspectRatio, insideRect: availableGameFrame).rounded()
        if appPlacementLayoutGuide.layoutFrame.rounded() != appPlacementFrame
        {
            appPlacementXConstraint.constant = appPlacementFrame.minX
            appPlacementYConstraint.constant = appPlacementFrame.minY
            appPlacementWidthConstraint.constant = appPlacementFrame.width
            appPlacementHeightConstraint.constant = appPlacementFrame.height
            
            // controllerView needs to reposition any items with `app` placement.
            controllerView.setNeedsLayout()
        }
        
        /* Game Views */
        if let traits = controllerView.controllerSkinTraits, let screens = screens(for: traits), !controllerView.isHidden
        {
            for (screen, gameView) in zip(screens, gameViews)
            {
                let placementFrame = (screen.placement == .controller) ? controllerViewFrame : appPlacementFrame
                
                if let outputFrame = screen.outputFrame
                {
                    let frame = outputFrame.scaled(to: placementFrame)
                    gameView.frame = frame
                }
                else
                {
                    // Nil outputFrame, so use gameView.outputImage's aspect ratio to determine default positioning.
                    // We check outputImage before inputFrame because we prefer to keep aspect ratio of whatever is currently being displayed.
                    // Otherwise, screen may resize to screenAspectRatio while still displaying partial content, appearing distorted.
                    let aspectRatio = gameView.outputImage?.extent.size ?? screen.inputFrame?.size ?? gameScreenDimensions
                    let containerFrame = (screen.placement == .controller) ? controllerViewFrame : availableGameFrame

                    let screenFrame = AVMakeRect(aspectRatio: aspectRatio, insideRect: containerFrame)
                    gameView.frame = screenFrame
                }
            }
        }
        else
        {
            let gameScreenFrame = AVMakeRect(aspectRatio: gameScreenDimensions, insideRect: availableGameFrame)
            gameView.frame = gameScreenFrame
        }
        
        if let emulatorCore = manicEmuCore, emulatorCore.state != .running
        {
            // WORKAROUND
            // Sometimes, iOS will cache the rendered image (such as when covered by a UIVisualEffectView), and as a result the game view might appear skewed
            // To compensate, we manually "refresh" the game screen
            emulatorCore.videoManager.render()
        }
        
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    // MARK: - KVO -
    /// KVO
    open dynamic override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        guard context == &kvoContext else { return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context) }

        // Ensures the value is actually different, or else we might potentially run into an infinite loop if subclasses hide/show controllerView in viewDidLayoutSubviews()
        guard (change?[.newKey] as? Bool) != (change?[.oldKey] as? Bool) else { return }
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    // MARK: - GameControllerReceiver -
    /// GameControllerReceiver
    // These would normally be declared in an extension, but non-ObjC compatible methods cannot be overridden if declared in extension :(
    open func gameController(_ gameController: GameController, didActivate input: Input, value: Double)
    {
        manicEmuCore?.gameController(gameController, didActivate: input, value: value)
    }
    
    open func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        manicEmuCore?.gameController(gameController, didDeactivate: input)
        
        // Wait until menu button is released before calling handleMenuInputFrom:
        // Fixes potentially missing key-up inputs due to showing pause menu.
        guard let standardInput = StandardGameControllerInput(input: input), standardInput == .menu else { return }
        delegate?.gameViewController(self, handleMenuInputFrom: gameController)
    }
    
    @objc func willResignActive(with notification: Notification)
    {
        guard let scene = notification.object as? UIScene, scene == self.view.window?.windowScene else { return }
        
        self.manicEmuCoreQueue.async {
            guard self.manicEmuCore?.state == .running else { return }
            _ = self._pauseEmulation()
        }
    }
    
    @objc func didBecomeActive(with notification: Notification)
    {
        guard let scene = notification.object as? UIWindowScene, scene == self.view.window?.windowScene else { return }
                        
        if #available(iOS 16, *), isGoingToForeground
        {
            // HACK: When returning from background, scene.hasKeyboardFocus may not be accurate when this method is called.
            // As a workaround, we wait an extra 0.5 seconds after becoming active before checking keyboard focus.
            
            detectKeyboardFocusTimer?.invalidate()
            detectKeyboardFocusTimer = nil
            
            detectKeyboardFocusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { timer in
                guard timer.isValid else { return }
                
                // Keep ignoring keyboard focus notifications until after 0.5 second delay.
                self.isGoingToForeground = false
                self.didBecomeActive(with: notification)
            }
            
            return
        }
        else
        {
            isGoingToForeground = false
        }
        
        if autoPauses
        {
            // Make sure scene has keyboard focus before automatically resuming.
            guard scene.isKeyBoardFocus else { return }
        }
        
        self.manicEmuCoreQueue.async {
            guard self.manicEmuCore?.state == .paused else { return }
            _ = self._resumeEmulation()
        }
    }
        
    @objc func willEnterForeground(_ notification: Notification)
    {
        guard let scene = notification.object as? UIScene, scene == self.view.window?.windowScene else { return }
        
        isGoingToForeground = true
    }
    
    @objc func controllerViewDidUpdateGameViews(_ notification: Notification)
    {
        guard let addedGameViews = notification.userInfo?[ControllerView.NotificationKey.addedGameViews] as? Set<GameView>,
              let removedGameViews = notification.userInfo?[ControllerView.NotificationKey.removedGameViews] as? Set<GameView>
        else { return }
        
        for gameView in addedGameViews
        {
            manicEmuCore?.add(gameView)
        }
        
        for gameView in removedGameViews
        {
            manicEmuCore?.remove(gameView)
        }
    }
    
    @objc func keyboardWillShow(with notification: Notification)
    {
        guard let window = self.view.window, let windowScene = window.windowScene,
              let traits = controllerView.controllerSkinTraits, traits.displayType == .splitView
        else { return }
        
        // Only adjust screen if we have keyboard focus OR emulatorCore is running.
        guard windowScene.isKeyBoardFocus || manicEmuCore?.state == .running else { return }
        
        let systemKeyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        guard systemKeyboardFrame.height > 0 else { return }

        // Keyboard frames are given in screen coordinates.
        let appFrame = window.screen.coordinateSpace.convert(window.bounds, from: window.coordinateSpace)
        let relativeHeight = appFrame.maxY - systemKeyboardFrame.minY
        
        let isLocalKeyboard = notification.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool ?? false
        if #available(iOS 16, *), let scene = view.window?.windowScene, scene.isStageUtilsEnabled, !isLocalKeyboard
        {
            splitViewHeight = 0
        }
        else
        {
            splitViewHeight = relativeHeight
        }
        
        updateGameViews()
        
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval
        
        let rawAnimationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as! Int
        let animationCurve = UIView.AnimationCurve(rawValue: rawAnimationCurve)!
        
        let animator = UIViewPropertyAnimator(duration: duration, curve: animationCurve) {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
        animator.startAnimation()
    }
    
    @objc func keyboardWillChangeFrame(with notification: Notification)
    {
        keyboardWillShow(with: notification)
    }
    
    @objc func keyboardWillHide(with notification: Notification)
    {
        guard let traits = controllerView.controllerSkinTraits, traits.displayType == .splitView else { return }
        
        // Always allow resizing screen back to original size to ensure it never gets stuck at small size.
        // guard windowScene.hasKeyboardFocus || self.emulatorCore?.state == .running else { return }
        
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval
        
        let rawAnimationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as! Int
        let animationCurve = UIView.AnimationCurve(rawValue: rawAnimationCurve)!
        
        splitViewHeight = 0
        
        let animator = UIViewPropertyAnimator(duration: duration, curve: animationCurve) {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
        animator.startAnimation()
        
        let isLocalKeyboard = notification.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool ?? false
        if let scene = view.window?.windowScene, scene.activationState == .foregroundInactive, isLocalKeyboard
        {
            // Explicitly resign first responder to prevent keyboard controller automatically appearing when not frontmost app.
            controllerView.resignFirstResponder()
        }
        
        updateGameViews()
    }
    
    @available(iOS 13.0, *)
    @objc func sceneKeyboardFocusDidChange(_ notification: Notification)
    {
        guard let scene = notification.object as? UIWindowScene, scene == view.window?.windowScene else { return }
        
        if #available(iOS 16, *)
        {
            // HACK: iOS 16 beta 5 sends multiple incorrect keyboard focus notifications when resuming from background.
            // As a workaround, we just ignore all of them until after becoming active.
            guard !self.isGoingToForeground else { return }
        }
        else if !scene.isKeyBoardFocus && scene.activationState == .foregroundActive
        {
            // Explicitly resign first responder to prevent emulation resuming automatically when not frontmost app.
            controllerView.resignFirstResponder()
        }
        
        if let traits = controllerView.controllerSkinTraits,
           let screens = screens(for: traits), screens.first?.outputFrame == nil
        {
            // First screen is dynamic, so explicitly update game views.
            updateGameViews()
        }
        
        // Must run on emulatorCoreQueue to ensure emulatorCore state is accurate.
        self.manicEmuCoreQueue.async {
            if scene.isKeyBoardFocus
            {
                // Always resume emulation, even if automaticallyPausesWhileInactive == false
                guard self.manicEmuCore?.state == .paused else { return }
                _ = self._resumeEmulation()
            }
            else
            {
                guard self.manicEmuCore?.state == .running, self.autoPauses else { return }
                _ = self._pauseEmulation()
            }
        }
    }
    
    @objc func updateGameViews()
    {
        var previousGameViews = Array(self.gameViews.reversed())
        var gameViews = [GameView]()
        
        if let traits = self.controllerView.controllerSkinTraits, let screens = self.screens(for: traits), !self.controllerView.isHidden
        {
            for screen in screens
            {
                let gameView = previousGameViews.popLast() ?? GameView(frame: .zero)
                gameView.update(for: screen)
                gameViews.append(gameView)
            }
        }
        else
        {
            for gameView in self.gameViews
            {
                gameView.filter = nil
            }
        }
        
        if gameViews.isEmpty
        {
            // gameViews needs to _always_ contain at least one game view.
            gameViews.append(self.gameView)
        }
        
        for gameView in gameViews
        {
            guard !self.gameViews.contains(gameView) else { continue }
            
            self.view.insertSubview(gameView, aboveSubview: self.gameView)
            self.manicEmuCore?.add(gameView)
        }
        
        for gameView in previousGameViews
        {
            guard !gameViews.contains(gameView) else { continue }
            
            gameView.removeFromSuperview()
            self.manicEmuCore?.remove(gameView)
        }
        
        self.gameViews = gameViews
        self.view.setNeedsLayout()
        
        self.delegate?.gameViewController(self, didUpdateGameViews: self.gameViews)
    }
    
    @discardableResult public func startEmulation() -> Bool
    {
        return manicEmuCoreQueue.sync {
            return self._startEmulation()
        }
    }
    
    @discardableResult open func pauseEmulation() -> Bool
    {
        return manicEmuCoreQueue.sync {
            return self._pauseEmulation()
        }
    }
    
    @discardableResult public func resumeEmulation() -> Bool
    {
        return manicEmuCoreQueue.sync {
            self._resumeEmulation()
        }
    }
    
    func _startEmulation() -> Bool
    {
        guard let emulatorCore = self.manicEmuCore else { return false }
        
        // Toggle audioManager.enabled to reset the audio buffer and ensure the audio isn't delayed from the beginning
        // This is especially noticeable when peeking a game
        emulatorCore.audioManager.isEnabled = false
        emulatorCore.audioManager.isEnabled = true
        
        return _resumeEmulation()
    }
    
    private func _pauseEmulation() -> Bool
    {
        guard let emulatorCore = manicEmuCore, delegate?.gameViewControllerShouldPause(self) ?? true else { return false }
        
        let result = emulatorCore.pause()
        return result
    }
    
    private func _resumeEmulation() -> Bool
    {
        guard let emulatorCore = manicEmuCore, delegate?.gameViewControllerShouldResume(self) ?? true else { return false }
        
        DispatchQueue.main.async {
            if self.view.window != nil
            {
                self.controllerView.becomeFirstResponder()
            }
        }
        
        let result: Bool
        
        switch emulatorCore.state
        {
        case .stopped: result = emulatorCore.start()
        case .paused: result = emulatorCore.resume(prefersVolumeEnable: prefersVolumeEnable)
        case .running: result = true
        }
        
        return result
    }
    
    func prepareForGame()
    {
        guard
            let controllerView = controllerView,
            let emulatorCore = manicEmuCore,
            let game = game
        else { return }
        
        for gameView in gameViews + controllerView.gameViews
        {
            emulatorCore.add(gameView)
        }
        
        controllerView.addReceiver(self)
        
        let controllerSkin = ControllerSkin.standardControllerSkin(for: game.type)
        controllerView.controllerSkin = controllerSkin
        
        self.view.setNeedsUpdateConstraints()
    }
    
    @objc func resumeIfNeeded()
    {
        controllerView.becomeFirstResponder()
        
        // Pre-check whether we should actually resume while we're still on main queue.
        // This helps avoid potential deadlock due to calling dispatch_sync on main queue in _resumeEmulation.
        guard manicEmuCore?.state == .paused, delegate?.gameViewControllerShouldResume(self) ?? true else { return }
        
        self.manicEmuCoreQueue.async {
            guard self.manicEmuCore?.state == .paused else { return }
            _ = self._resumeEmulation()
        }
    }
    
    func screens(for traits: ControllerSkin.Traits) -> [ControllerSkin.Screen]?
    {
        guard let controllerSkin = controllerView.controllerSkin,
              let traits = controllerView.controllerSkinTraits,
              var screens = controllerSkin.screens(for: traits)
        else { return nil }
        
        guard traits.displayType == .splitView else {
            // When not in split view, manage all game views regardless of placement.
            return screens
        }
        
        // When in split view, only manage game views with `app` placement.
        screens = screens.filter { $0.placement == .app }

        if var screen = screens.first, screen.outputFrame == nil, !controllerView.isFirstResponder
        {
            // Keyboard is not visible, so set inputFrame to nil to display entire screen.
            // This essentially collapses all screens into a single main screen that we can manage easier.
            screen.inputFrame = nil
            screens = [screen]
        }
        
        return screens
    }
}

extension GameViewController: UIGestureRecognizerDelegate
{
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
    {
        guard gestureRecognizer == self.tapGestureRecognizer else { return true }
        
        // We only need tap-to-resume when using Split View/Stage Manager to handle edge cases where emulation doesn't resume automatically.
        // However, we'll also respond to direct taps on primary game screen just in case.
        let location = touch.location(in: gameView)
        let shouldReceiveTouch = controllerView.controllerSkinTraits?.displayType == .splitView || gameView.bounds.contains(location)
        return shouldReceiveTouch
    }
}
