// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Owns one bounded pull attempt. Its callback may be missing, duplicated or late.
/// Completion, timeout and cancellation can arrive on different queues. The lock
/// makes claiming/removing `active` atomic, so only one outcome wins. Scheduling,
/// timer cancellation and client callbacks run outside the lock to allow reentry.
final class FilesSyncPullCoordinator {
    struct Timeout: Error, LocalizedError {
        var errorDescription: String? { "Cloud sync pull timed out. Retry is available." }
    }
    typealias Schedule = (TimeInterval, @escaping () -> Void) -> (() -> Void)
    private struct Attempt {
        var id: UUID
        var session: UInt64
        var completion: (Error?) -> Void
        var cancelTimeout: (() -> Void)?
    }
    private let lock = NSLock()
    private var active: Attempt?
    private let timeout: TimeInterval
    private let schedule: Schedule

    init(timeout: TimeInterval = 120, schedule: @escaping Schedule = { delay, action in
        let item = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return { item.cancel() }
    }) {
        self.timeout = timeout
        self.schedule = schedule
    }

    @discardableResult
    func perform(session: UInt64, operation: (@escaping (Error?) -> Void) -> Void,
                 completion: @escaping (Error?) -> Void) -> Bool {
        let start = lock.withLock { () -> (id: UUID, previousTimeout: (() -> Void)?)? in
            guard active?.session != session else { return nil }
            let previousTimeout = active?.cancelTimeout
            let id = UUID()
            active = Attempt(id: id, session: session, completion: completion)
            return (id, previousTimeout)
        }
        guard let start else { return false }
        let id = start.id
        start.previousTimeout?()
        let cancel = schedule(timeout) { [weak self] in
            self?.finish(id: id, error: Timeout())
        }
        // Scheduling may itself cancel/finish this attempt before returning.
        let isCurrent = lock.withLock {
            guard active?.id == id else { return false }
            active?.cancelTimeout = cancel
            return true
        }
        guard isCurrent else { cancel(); return false }
        operation { [weak self] error in self?.finish(id: id, error: error) }
        return true
    }

    func cancel() {
        let timeout = lock.withLock {
            let timeout = active?.cancelTimeout
            active = nil
            return timeout
        }
        timeout?()
    }

    private func finish(id: UUID, error: Error?) {
        let attempt = lock.withLock { () -> Attempt? in
            guard let attempt = active, attempt.id == id else { return nil }
            active = nil
            return attempt
        }
        guard let attempt else { return }
        attempt.cancelTimeout?()
        attempt.completion(error)
    }
}
