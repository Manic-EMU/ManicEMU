//
//  DuoHingeKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

@available(iOS 27.1, *)
struct DuoHingeKit {
    static let fromStatusKey = "DuoHingeFromStatus"
    static let toStatusKey = "DuoHingeToStatus"
    
    /// Latest sample, including angle ticks. Layout should use `statusDidChange`, not this alone.
    static var currentStatusHinge: UIHinge?
    
    /// Status observers were last told about. Nil until the first real sample.
    private static var deliveredHinge: UIHinge?
    /// Start of the in-flight gesture. Stays put while intermediate statuses are replaced.
    private static var pendingFrom: UIHinge?
    private static var pendingTo: UIHinge?
    private static var waitGeneration = 0
    private static var settleWork: DispatchWorkItem?
    /// Quiet period after the last hinge sample.
    private static let settleDelay: TimeInterval = 0.35
    
    static func didHingeUpdate(interaction: UIHingeInteraction,
                               update: UIHingeInteraction.Update) {
        guard interaction.isEnabled, let hinge = update.hinge, hinge.status != .unknown else { return }
        let status = hinge.status
        currentStatusHinge = hinge
        guard let deliveredHinge else {
            self.deliveredHinge = hinge
            return
        }
        if status == deliveredHinge.status {
            cancelPending()
            return
        }
        pendingFrom = pendingFrom ?? deliveredHinge
        pendingTo = hinge
        scheduleDelivery()
    }
    
    static func transition(from notification: Notification) -> (from: UIHinge, to: UIHinge)? {
        guard let from = notification.userInfo?[fromStatusKey] as? UIHinge,
              let to = notification.userInfo?[toStatusKey] as? UIHinge else { return nil }
        return (from, to)
    }
    
    private static func cancelPending() {
        pendingFrom = nil
        pendingTo = nil
        waitGeneration += 1
        settleWork?.cancel()
        settleWork = nil
    }
    
    /// Restarts the quiet wait. Angle ticks and intermediate statuses both postpone the notice.
    private static func scheduleDelivery() {
        waitGeneration += 1
        let generation = waitGeneration
        settleWork?.cancel()
        let work = DispatchWorkItem {
            attemptDelivery(generation: generation, remainingAttempts: 60)
        }
        settleWork = work
        // Partially open often snaps back to closed. Wait longer only for that notice.
        let delay = pendingTo?.status == .partiallyOpen ? settleDelay * 2 : settleDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    
    /// Inner and outer displays are far apart in points (about 951 vs 678 on the long side).
    private static func isInnerDisplay(_ window: UIWindow) -> Bool {
        let screen = window.screen.bounds
        let longSide = max(screen.width, screen.height)
        return longSide > 800
    }
    
    private static func displayMatches(_ hinge: UIHinge, window: UIWindow) -> Bool {
        let inner = isInnerDisplay(window)
        switch hinge.status {
        case .closed:
            return !inner
        case .partiallyOpen, .fullyOpen:
            return inner
        case .unknown:
            return false
        @unknown default:
            return false
        }
    }
    
    private static func attemptDelivery(generation: Int, remainingAttempts: Int) {
        guard generation == waitGeneration,
              let from = pendingFrom,
              let to = pendingTo,
              from != to,
              let window = ApplicationSceneDelegate.applicationWindow else { return }
        guard displayMatches(to, window: window) else {
            guard remainingAttempts > 0 else { return }
            DispatchQueue.main.async {
                attemptDelivery(generation: generation, remainingAttempts: remainingAttempts - 1)
            }
            return
        }
        pendingFrom = nil
        pendingTo = nil
        deliveredHinge = to
        NotificationCenter.default.post(
            name: R.NotificationName.DuoHingeChange,
            object: window,
            userInfo: [
                fromStatusKey: from,
                toStatusKey: to
            ]
        )
    }
}
