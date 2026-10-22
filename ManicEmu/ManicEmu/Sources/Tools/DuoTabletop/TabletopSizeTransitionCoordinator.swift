//
//  TabletopSizeTransitionCoordinator.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

/// Runs `viewWillTransition` work for a window-frame change. Blocks are collected, then flushed after the will-phase returns.
@available(iOS 27.1, *)
final class TabletopSizeTransitionCoordinator: NSObject, UIViewControllerTransitionCoordinator {
    let containerView: UIView
    private weak var viewController: UIViewController?
    private var animations: [(UIViewControllerTransitionCoordinatorContext) -> Void] = []
    private var completions: [(UIViewControllerTransitionCoordinatorContext) -> Void] = []
    private var interactionHandlers: [(UIViewControllerTransitionCoordinatorContext) -> Void] = []
    private var didFinishAlongside = false
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        self.containerView = viewController.view
    }
    
    var isAnimated: Bool { false }
    var presentationStyle: UIModalPresentationStyle { .none }
    var initiallyInteractive: Bool { false }
    var isInterruptible: Bool { false }
    var isInteractive: Bool { false }
    var isCancelled: Bool { false }
    var transitionDuration: TimeInterval { 0 }
    var percentComplete: CGFloat { didFinishAlongside ? 1 : 0 }
    var completionVelocity: CGFloat { 1 }
    var completionCurve: UIView.AnimationCurve { .linear }
    var targetTransform: CGAffineTransform { .identity }
    
    func viewController(forKey _: UITransitionContextViewControllerKey) -> UIViewController? {
        viewController
    }
    
    func view(forKey _: UITransitionContextViewKey) -> UIView? {
        viewController?.view
    }
    
    func animate(alongsideTransition animation: ((UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Void)? = nil) -> Bool {
        enqueue(animation: animation, completion: completion)
    }
    
    func animateAlongsideTransition(in _: UIView?, animation: ((UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Void)? = nil) -> Bool {
        enqueue(animation: animation, completion: completion)
    }
    
    func notifyWhenInteractionEnds(_ handler: @escaping (UIViewControllerTransitionCoordinatorContext) -> Void) {
        notifyWhenInteractionChanges(handler)
    }
    
    func notifyWhenInteractionChanges(_ handler: @escaping (UIViewControllerTransitionCoordinatorContext) -> Void) {
        if didFinishAlongside {
            handler(self)
        } else {
            interactionHandlers.append(handler)
        }
    }
    
    func performAlongside() {
        guard !didFinishAlongside else { return }
        didFinishAlongside = true
        let pending = animations
        animations.removeAll()
        pending.forEach { $0(self) }
    }
    
    func performCompletion() {
        performAlongside()
        let pendingInteractions = interactionHandlers
        interactionHandlers.removeAll()
        pendingInteractions.forEach { $0(self) }
        let pendingCompletions = completions
        completions.removeAll()
        pendingCompletions.forEach { $0(self) }
    }
    
    private func enqueue(animation: ((UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Void)?) -> Bool {
        if didFinishAlongside {
            animation?(self)
            completion?(self)
            return true
        }
        if let animation {
            animations.append(animation)
        }
        if let completion {
            completions.append(completion)
        }
        return animation != nil || completion != nil
    }
}
