// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Owns one bounded pull attempt. Its callback may be missing, duplicated or late.
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
        lock.lock()
        guard active?.session != session else { lock.unlock(); return false }
        let previousTimeout = active?.cancelTimeout
        let id = UUID()
        active = Attempt(id: id, session: session, completion: completion)
        lock.unlock()
        previousTimeout?()
        let cancel = schedule(timeout) { [weak self] in
            self?.finish(id: id, error: Timeout())
        }
        lock.lock()
        let isCurrent = active?.id == id
        if isCurrent { active?.cancelTimeout = cancel }
        lock.unlock()
        guard isCurrent else { cancel(); return false }
        operation { [weak self] error in self?.finish(id: id, error: error) }
        return true
    }

    func cancel() {
        lock.lock()
        let timeout = active?.cancelTimeout
        active = nil
        lock.unlock()
        timeout?()
    }

    private func finish(id: UUID, error: Error?) {
        lock.lock()
        guard let attempt = active, attempt.id == id else { lock.unlock(); return }
        active = nil
        lock.unlock()
        attempt.cancelTimeout?()
        attempt.completion(error)
    }
}
