// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Narrowly identifies saves without including ROMs, cheats or unrelated cores.
enum ThreeDSSavePolicy {
    static let sizeLimit: Int64 = 4 * 1024 * 1024

    static func saveRoot(_ path: String) -> String? {
        let p = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard p.count >= 9, !p.contains(".."), !p.contains("."), !p.contains(""),
              Array(p.prefix(3)) == ["3DS", "sdmc", "Nintendo 3DS"],
              isHex(p[3], count: 32), isHex(p[4], count: 32), p[5] == "title",
              isHex(p[6], count: 8), isHex(p[7], count: 8),
              (p[8] == "data" && p.count > 9) || (p[8] == "metadata" && p.count == 9) else { return nil }
        return p.prefix(8).joined(separator: "/")
    }

    static func overlaps(_ a: String, _ b: String) -> Bool {
        a == b || a.hasPrefix(b + "/") || b.hasPrefix(a + "/")
    }

    static func affectsSaveTree(_ path: String) -> Bool {
        let base = "3DS/sdmc/Nintendo 3DS"
        if path == base || base.hasPrefix(path + "/") { return true }
        let p = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard p.count >= 4, Array(p.prefix(3)) == ["3DS", "sdmc", "Nintendo 3DS"],
              !p.contains(".."), !p.contains("."), !p.contains(""), isHex(p[3], count: 32) else { return false }
        if p.count == 4 { return true }
        guard isHex(p[4], count: 32) else { return false }
        if p.count == 5 { return true }
        guard p[5] == "title" else { return false }
        if p.count == 6 { return true }
        guard isHex(p[6], count: 8) else { return false }
        if p.count == 7 { return true }
        guard isHex(p[7], count: 8) else { return false }
        return p.count == 8 || p[8] == "data" || (p.count == 9 && p[8] == "metadata")
    }

    private static func isHex(_ string: String, count: Int) -> Bool {
        string.utf8.count == count && string.utf8.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
    }
}

/// Guarded by the owning engine's lock; also exercised directly by XCTest.
struct FilesSyncIntentReadiness {
    private(set) var session: UInt64 = 0
    private(set) var pullReady = false
    private(set) var pullFailed = false
    private var pending = Set<String>()
    private(set) var waiting = Set<String>()

    mutating func enqueue(_ paths: [String]) { pending.formUnion(paths) }
    mutating func waitForIntent(_ path: String) { waiting.insert(path) }
    mutating func resolved(_ path: String) { waiting.remove(path) }

    @discardableResult
    mutating func finishPull(session expected: UInt64, succeeded: Bool) -> Bool {
        guard session == expected else { return false }
        pullReady = succeeded
        pullFailed = !succeeded
        return true
    }

    mutating func drain(inventoryReady: Bool) -> [String] {
        guard pullReady, inventoryReady else { return [] }
        let paths = pending.union(waiting).sorted()
        pending.removeAll()
        return paths
    }

    mutating func resetSession() {
        session &+= 1
        pullReady = false
        pullFailed = false
        pending.removeAll()
        waiting.removeAll()
    }
}

enum FilesSyncReadinessPhase: String {
    case idle, scanning, syncing, paused, unavailable, needsAttention
}

extension FilesSyncIntentReadiness {
    func reportedPhase(current: FilesSyncReadinessPhase, inventoryReady: Bool,
                       started: Bool, paused: Bool, hasActiveWork: Bool,
                       unresolvedCount: Int, settleIfQuiescent: Bool) -> FilesSyncReadinessPhase {
        if settleIfQuiescent, started, paused { return .paused }
        var phase = current
        if settleIfQuiescent, started, !hasActiveWork { phase = .idle }
        if phase == .idle, started {
            if !pullReady || !inventoryReady { return pullFailed ? .unavailable : .scanning }
            if unresolvedCount > 0 { return .needsAttention }
        }
        return phase
    }
}
