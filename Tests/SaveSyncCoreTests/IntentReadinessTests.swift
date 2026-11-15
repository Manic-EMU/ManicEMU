import XCTest

final class IntentReadinessTests: XCTestCase {
    func testIntentBeforeInventoryWaitsThenDrainsOnce() {
        var state = FilesSyncIntentReadiness()
        state.enqueueIntentPaths(["save", "save"])
        state.finishIntentPull(session: 0, succeeded: true)
        XCTAssertTrue(state.takeReconciliationPaths(driveInventoryReady: false).isEmpty)
        XCTAssertEqual(state.takeReconciliationPaths(driveInventoryReady: true), ["save"])
        XCTAssertTrue(state.takeReconciliationPaths(driveInventoryReady: true).isEmpty)
    }
    func testInventoryBeforeIntentPullDoesNotLoseInitialRecords() {
        var state = FilesSyncIntentReadiness()
        state.enqueueIntentPaths(["save"])
        XCTAssertTrue(state.takeReconciliationPaths(driveInventoryReady: true).isEmpty)
        state.finishIntentPull(session: 0, succeeded: true)
        XCTAssertEqual(state.takeReconciliationPaths(driveInventoryReady: true), ["save"])
    }
    func testMissingIntentRemainsUnresolvedUntilReconciled() {
        var state = FilesSyncIntentReadiness()
        state.waitForIntent("save")
        state.finishIntentPull(session: 0, succeeded: true)
        XCTAssertEqual(state.takeReconciliationPaths(driveInventoryReady: true), ["save"])
        XCTAssertEqual(state.pathsAwaitingIntent, ["save"])
        state.enqueueIntentPaths(["save"])
        XCTAssertEqual(state.takeReconciliationPaths(driveInventoryReady: true), ["save"])
        state.markPathResolved("save")
        XCTAssertTrue(state.pathsAwaitingIntent.isEmpty)
    }
    func testScopeExcludesROMsAndOtherCores() {
        let titleRoot = "3DS/sdmc/Nintendo 3DS/" + String(repeating: "a", count: 32)
            + "/" + String(repeating: "B", count: 32) + "/title/00040000/00123400"
        let path = titleRoot + "/data/save.dat"
        for file in [path, titleRoot + "/data/nested/save.dat", titleRoot + "/metadata"] {
            XCTAssertEqual(ThreeDSSavePolicy.saveRoot(file), titleRoot, file)
            XCTAssertTrue(ThreeDSSavePolicy.affectsSaveTree(file), file)
        }
        // Replacing/deleting an ancestor affects saves; an ancestor is not itself a save file.
        let components = titleRoot.split(separator: "/")
        for count in 1...components.count {
            let ancestor = components.prefix(count).joined(separator: "/")
            XCTAssertNil(ThreeDSSavePolicy.saveRoot(ancestor), ancestor)
            XCTAssertTrue(ThreeDSSavePolicy.affectsSaveTree(ancestor), ancestor)
        }
        XCTAssertNil(ThreeDSSavePolicy.saveRoot(titleRoot + "/data"))
        XCTAssertTrue(ThreeDSSavePolicy.affectsSaveTree(titleRoot + "/data"))
        for excluded in [
            titleRoot + "/content/game.app", titleRoot + "/metadata/child",
            "Datas/Other/data/save.dat", "3DS/cheats/game.txt", "",
            "/" + path, path + "/", path + "/../bad", path + "/./bad",
            path.replacingOccurrences(of: "/data/", with: "//data/"),
            path.replacingOccurrences(of: String(repeating: "a", count: 32), with: String(repeating: "a", count: 31)),
            path.replacingOccurrences(of: String(repeating: "B", count: 32), with: String(repeating: "g", count: 32)),
            path.replacingOccurrences(of: "00040000", with: "0004000"),
            path.replacingOccurrences(of: "00123400", with: "0012340g"),
            path.replacingOccurrences(of: "/title/", with: "/extdata/")
        ] {
            XCTAssertNil(ThreeDSSavePolicy.saveRoot(excluded), excluded)
            XCTAssertFalse(ThreeDSSavePolicy.affectsSaveTree(excluded), excluded)
        }
    }
}
