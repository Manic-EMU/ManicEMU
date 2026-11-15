import XCTest

final class IntentReadinessTests: XCTestCase {
    func testIntentBeforeInventoryWaitsThenDrainsOnce() {
        var state = FilesSyncIntentReadiness()
        state.enqueue(["save", "save"])
        state.finishPull(session: 0, succeeded: true)
        XCTAssertTrue(state.drain(inventoryReady: false).isEmpty)
        XCTAssertEqual(state.drain(inventoryReady: true), ["save"])
        XCTAssertTrue(state.drain(inventoryReady: true).isEmpty)
    }
    func testInventoryBeforeIntentPullDoesNotLoseInitialRecords() {
        var state = FilesSyncIntentReadiness()
        state.enqueue(["save"])
        XCTAssertTrue(state.drain(inventoryReady: true).isEmpty)
        state.finishPull(session: 0, succeeded: true)
        XCTAssertEqual(state.drain(inventoryReady: true), ["save"])
    }
    func testMissingIntentRemainsUnresolvedUntilReconciled() {
        var state = FilesSyncIntentReadiness()
        state.waitForIntent("save")
        state.finishPull(session: 0, succeeded: true)
        XCTAssertEqual(state.drain(inventoryReady: true), ["save"])
        XCTAssertEqual(state.waiting, ["save"])
        state.enqueue(["save"])
        XCTAssertEqual(state.drain(inventoryReady: true), ["save"])
        state.resolved("save")
        XCTAssertTrue(state.waiting.isEmpty)
    }
    func testScopeExcludesROMsAndOtherCores() {
        let path = "3DS/sdmc/Nintendo 3DS/" + String(repeating: "0", count: 32) + "/" + String(repeating: "1", count: 32) + "/title/00040000/00123400/data/save.dat"
        XCTAssertNotNil(ThreeDSSavePolicy.saveRoot(path))
        XCTAssertNil(ThreeDSSavePolicy.saveRoot(path.replacingOccurrences(of: "/data/", with: "/content/")))
        XCTAssertNil(ThreeDSSavePolicy.saveRoot("Datas/Other/data/save.dat"))
        XCTAssertNil(ThreeDSSavePolicy.saveRoot(path + "/../bad"))
    }
}
