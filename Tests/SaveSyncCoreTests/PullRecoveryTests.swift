import XCTest

/// Exercises bounded pull attempts and stale-callback fencing without CloudKit credentials.
final class PullRecoveryTests: XCTestCase {
    private final class Clock {
        final class Job {
            var cancelled = false
            let action: () -> Void
            init(_ action: @escaping () -> Void) { self.action = action }
        }
        var jobs = [Job]()
        func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) -> () -> Void {
            let job = Job(action)
            jobs.append(job)
            return { job.cancelled = true }
        }
        func expire() { for job in jobs where !job.cancelled { job.action() } }
    }

    func testFailedOrMissingCallbackCanRetry() {
        for missingCallback in [false, true] {
            let clock = Clock()
            let pulls = FilesSyncPullCoordinator(timeout: 1, schedule: clock.schedule)
            var pullFailed = false
            var firstCallback: ((Error?) -> Void)?
            var completions = 0
            let finish: (Error?) -> Void = { error in
                completions += 1
                pullFailed = error != nil
            }
            XCTAssertTrue(pulls.perform(session: 0, operation: { firstCallback = $0 }, completion: finish))
            if missingCallback {
                // IceCream's terminal-error path can omit its completion entirely.
                clock.expire()
            } else {
                firstCallback?(NSError(domain: "pull", code: 1))
            }
            XCTAssertEqual(completions, 1)
            XCTAssertTrue(pullFailed)
            var retryCallback: ((Error?) -> Void)?
            XCTAssertTrue(pulls.perform(session: 0, operation: { retryCallback = $0 }, completion: finish))
            firstCallback?(nil) // Old success cannot finish the new attempt.
            XCTAssertEqual(completions, 1)
            XCTAssertFalse(pulls.perform(session: 0, operation: { _ in XCTFail("overlapping retry") }, completion: finish))
            retryCallback?(nil)
            XCTAssertEqual(completions, 2)
            XCTAssertFalse(pullFailed)
            firstCallback?(NSError(domain: "late", code: 1))
            retryCallback?(nil)
            clock.expire()
            XCTAssertEqual(completions, 2)
        }
    }

    func testStopStartInSameAccountCancelsWatchdogAndFencesOldCallback() {
        let clock = Clock()
        let pulls = FilesSyncPullCoordinator(schedule: clock.schedule)
        var old: ((Error?) -> Void)?
        pulls.perform(session: 0, operation: { old = $0 }, completion: { _ in XCTFail("cancelled setup") })
        pulls.cancel()
        XCTAssertTrue(clock.jobs[0].cancelled)
        var current: ((Error?) -> Void)?
        var finished = false
        XCTAssertTrue(pulls.perform(session: 0, operation: { current = $0 }, completion: { error in
            XCTAssertNil(error)
            finished = true
        }))
        old?(nil)
        clock.jobs[0].action() // Even a timeout already dequeued before cancel is harmless.
        XCTAssertFalse(finished)
        current?(nil)
        XCTAssertTrue(finished)
        XCTAssertTrue(clock.jobs[1].cancelled)
    }

    func testAccountReplacementFencesPreviousTimeoutAndCompletion() {
        let clock = Clock()
        let pulls = FilesSyncPullCoordinator(schedule: clock.schedule)
        let oldSession: UInt64 = 0
        var old: ((Error?) -> Void)?
        pulls.perform(session: oldSession, operation: { old = $0 }, completion: { _ in XCTFail("old account") })
        let newSession = oldSession + 1
        var current: ((Error?) -> Void)?
        var finished = false
        XCTAssertTrue(pulls.perform(session: newSession, operation: { current = $0 }, completion: { error in
            XCTAssertNil(error)
            finished = true
        }))
        old?(nil)
        clock.jobs[0].action()
        XCTAssertFalse(finished)
        current?(nil)
        XCTAssertTrue(finished)
        XCTAssertTrue(clock.jobs.allSatisfy(\.cancelled))
    }
}
