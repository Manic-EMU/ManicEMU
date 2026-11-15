import XCTest

/// Drives the production pull adapter and readiness/phase logic without CloudKit credentials.
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

    func testMissingCallbackTimesOutThenSameAccountRetryReleasesQueuedIntent() {
        let clock = Clock()
        let pulls = FilesSyncPullCoordinator(timeout: 1, schedule: clock.schedule)
        var readiness = FilesSyncIntentReadiness()
        readiness.enqueue(["save"])
        var firstCallback: ((Error?) -> Void)?
        var completions = 0
        let finish: (Error?) -> Void = { error in
            completions += 1
            readiness.finishPull(session: 0, succeeded: error == nil)
        }
        XCTAssertTrue(pulls.perform(session: 0, operation: { firstCallback = $0 }, completion: finish))
        // IceCream's terminal-error path can omit its completion entirely.
        clock.expire()
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(readiness.pullFailed)
        XCTAssertTrue(readiness.drain(inventoryReady: true).isEmpty)
        var retryCallback: ((Error?) -> Void)?
        XCTAssertTrue(pulls.perform(session: 0, operation: { retryCallback = $0 }, completion: finish))
        firstCallback?(nil) // Old success cannot finish the new attempt.
        XCTAssertEqual(completions, 1)
        XCTAssertFalse(pulls.perform(session: 0, operation: { _ in XCTFail("overlapping retry") }, completion: finish))
        retryCallback?(nil)
        XCTAssertEqual(completions, 2)
        XCTAssertEqual(readiness.drain(inventoryReady: true), ["save"])
        firstCallback?(NSError(domain: "late", code: 1))
        retryCallback?(nil)
        clock.expire()
        XCTAssertEqual(completions, 2)
        XCTAssertTrue(readiness.pullReady)
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
        var old: ((Error?) -> Void)?
        pulls.perform(session: 0, operation: { old = $0 }, completion: { _ in XCTFail("old account") })
        var finished = false
        pulls.perform(session: 1, operation: { finish in finish(nil) }, completion: { error in
            XCTAssertNil(error)
            finished = true
        })
        XCTAssertTrue(finished)
        old?(nil)
        clock.jobs[0].action()
        XCTAssertTrue(clock.jobs.allSatisfy(\.cancelled))
    }

    func testFirstInventoryWithNoTransfersSettlesAfterPullHadToWaitForInventory() {
        let clock = Clock()
        let pulls = FilesSyncPullCoordinator(schedule: clock.schedule)
        var state = FilesSyncIntentReadiness()
        var phase = FilesSyncReadinessPhase.scanning
        pulls.perform(session: 0, operation: { $0(nil) }, completion: { error in
            state.finishPull(session: 0, succeeded: error == nil)
            phase = state.reportedPhase(current: phase, inventoryReady: false, started: true,
                paused: false, hasActiveWork: false, unresolvedCount: 0, settleIfQuiescent: true)
        })
        XCTAssertEqual(phase, .scanning)
        XCTAssertTrue(state.drain(inventoryReady: true).isEmpty) // Empty listing or a changed listing whose decisions are all skips.
        XCTAssertEqual(state.reportedPhase(current: phase, inventoryReady: true, started: true,
            paused: false, hasActiveWork: false, unresolvedCount: 0, settleIfQuiescent: true), .idle)
    }

    func testNestedNoOpReplayDoesNotSettleBeforeOuterScanFinishes() {
        var state = FilesSyncIntentReadiness()
        state.finishPull(session: 0, succeeded: true)
        let duringReplay = state.reportedPhase(current: .scanning, inventoryReady: true,
            started: true, paused: false, hasActiveWork: false, unresolvedCount: 0,
            settleIfQuiescent: false)
        XCTAssertEqual(duringReplay, .scanning)
        // The remaining scan discovers a missing-intent path after replay did no work.
        state.waitForIntent("another-save")
        XCTAssertEqual(state.reportedPhase(current: duringReplay, inventoryReady: true,
            started: true, paused: false, hasActiveWork: false, unresolvedCount: state.waiting.count,
            settleIfQuiescent: true), .needsAttention)
    }

    func testNoOpIntentReplaySettlesButPendingTransfersAndPauseArePreserved() {
        var state = FilesSyncIntentReadiness()
        state.enqueue(["already-applied"])
        state.finishPull(session: 0, succeeded: true)
        XCTAssertEqual(state.drain(inventoryReady: true), ["already-applied"])
        func phase(_ current: FilesSyncReadinessPhase, active: Bool = false,
                   paused: Bool = false, unresolved: Int = 0) -> FilesSyncReadinessPhase {
            state.reportedPhase(current: current, inventoryReady: true, started: true,
                paused: paused, hasActiveWork: active, unresolvedCount: unresolved, settleIfQuiescent: true)
        }
        XCTAssertEqual(phase(.scanning), .idle)
        XCTAssertEqual(phase(.syncing, active: true), .syncing)
        XCTAssertEqual(phase(.scanning, active: true), .scanning)
        XCTAssertEqual(phase(.scanning, paused: true), .paused)
        XCTAssertEqual(phase(.scanning, unresolved: 1), .needsAttention)
    }
}
