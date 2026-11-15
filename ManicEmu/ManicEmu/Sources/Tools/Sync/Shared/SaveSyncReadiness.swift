// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Selects title save data and metadata on the emulated 3DS SD card.
/// Paths are relative to Documents; title `content/` (installed games), cheats
/// and other emulator cores are outside this scope.
enum ThreeDSSavePolicy {
    static let sizeLimit: Int64 = 4 * 1024 * 1024

    private enum ComponentValidator {
        case directory(String)
        case hexID(length: Int)

        func matches(_ component: String) -> Bool {
            switch self {
            case .directory(let name): return component == name
            case .hexID(let length): return ThreeDSSavePolicy.isHex(component, count: length)
            }
        }
    }

    // The ordered validators describe the title root and validate it together.
    // 3DS/sdmc/Nintendo 3DS/<ID0>/<ID1>/title/<title ID high>/<title ID low>
    private static let titleRootValidators: [ComponentValidator] = [
        .directory("3DS"),
        .directory("sdmc"),
        .directory("Nintendo 3DS"),
        .hexID(length: 32), // ID0
        .hexID(length: 32), // ID1
        .directory("title"),
        .hexID(length: 8), // High half of the title ID
        .hexID(length: 8)  // Low half of the title ID
    ]

    /// Returns the title root for a file under `data/`, or the title's single
    /// `metadata` file. The `data` directory itself is not a save file.
    static func saveRoot(_ path: String) -> String? {
        guard let components = safeComponents(path),
              components.count > titleRootValidators.count,
              matchesTitleRoot(components) else { return nil }
        let saveComponents = components.dropFirst(titleRootValidators.count)
        let isSaveData = saveComponents.first == "data" && saveComponents.count > 1
        let isMetadata = saveComponents.first == "metadata" && saveComponents.count == 1
        guard isSaveData || isMetadata else { return nil }
        return components.prefix(titleRootValidators.count).joined(separator: "/")
    }

    static func overlaps(_ a: String, _ b: String) -> Bool {
        a == b || a.hasPrefix(b + "/") || b.hasPrefix(a + "/")
    }

    /// Directory mutations also affect saves when they target an ancestor of
    /// the title root or the `data` directory, unlike file-only `saveRoot`.
    static func affectsSaveTree(_ path: String) -> Bool {
        guard let components = safeComponents(path), matchesTitleRoot(components) else { return false }
        if components.count <= titleRootValidators.count { return true }
        let saveComponents = components.dropFirst(titleRootValidators.count)
        return saveComponents.first == "data"
            || (saveComponents.first == "metadata" && saveComponents.count == 1)
    }

    /// A shorter path matches only the corresponding prefix (for ancestor mutations).
    private static func matchesTitleRoot(_ components: [String]) -> Bool {
        zip(titleRootValidators, components).allSatisfy { $0.matches($1) }
    }

    private static func safeComponents(_ path: String) -> [String]? {
        let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return nil }
        return components
    }

    private static func isHex(_ string: String, count: Int) -> Bool {
        string.utf8.count == count && string.utf8.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
    }
}

/// Coordinates two independently arriving inputs: CloudKit intent records
/// (which describe what should exist) and the iCloud Drive file inventory.
/// Paths can be reconciled only after the intent pull succeeds AND the Drive
/// inventory is ready, regardless of arrival order. This does not mean file transfers
/// have completed. FilesSyncEngine owns the I/O and guards this state with its lock.
struct FilesSyncIntentReadiness {
    /// Account epoch, not a pull attempt ID. Retries share it; an account reset
    /// advances it so an old account's callback cannot release new account work.
    private(set) var session: UInt64 = 0
    private(set) var intentPullSucceeded = false
    private(set) var intentPullFailed = false
    /// Paths queued by record notifications or an explicit retry, consumed once
    /// both inputs are ready.
    private var pendingIntentPaths = Set<String>()
    /// Cloud-only save files with no intent yet. Replaying does not remove these;
    /// only reconciliation finding an intent (or no longer needing one) does.
    private(set) var pathsAwaitingIntent = Set<String>()

    mutating func enqueueIntentPaths(_ paths: [String]) { pendingIntentPaths.formUnion(paths) }
    mutating func waitForIntent(_ path: String) { pathsAwaitingIntent.insert(path) }
    mutating func markPathResolved(_ path: String) { pathsAwaitingIntent.remove(path) }

    @discardableResult
    mutating func finishIntentPull(session expected: UInt64, succeeded: Bool) -> Bool {
        guard session == expected else { return false }
        intentPullSucceeded = succeeded
        intentPullFailed = !succeeded
        return true
    }

    /// Consumes record notifications once, but keeps missing-intent paths eligible
    /// for another reconciliation after the next record notification or pull.
    mutating func takeReconciliationPaths(driveInventoryReady: Bool) -> [String] {
        guard intentPullSucceeded, driveInventoryReady else { return [] }
        let paths = pendingIntentPaths.union(pathsAwaitingIntent).sorted()
        pendingIntentPaths.removeAll()
        return paths
    }

    mutating func resetSession() {
        session &+= 1
        intentPullSucceeded = false
        intentPullFailed = false
        pendingIntentPaths.removeAll()
        pathsAwaitingIntent.removeAll()
    }
}

enum FilesSyncReadinessPhase: String {
    case idle
    case scanning // Discovering files or waiting for the first successful intent pull.
    case syncing
    case paused // Gameplay owns the save files.
    case unavailable // Drive is unavailable or the intent pull failed; retry is possible.
    case needsAttention // Both inputs are ready, but some paths remain unresolved.
}

extension FilesSyncIntentReadiness {
    /// Projects readiness into the existing sync UI phases. An empty transfer queue
    /// cannot report idle while either input is missing or paths remain unresolved.
    /// `settleIfQuiescent` is allowed only after the enclosing scan/replay finishes;
    /// a nested replay must not settle status before the rest of the scan runs.
    /// Active transfers and gameplay pause retain their existing phase priority.
    func reportedPhase(current: FilesSyncReadinessPhase, driveInventoryReady: Bool,
                       started: Bool, paused: Bool, hasActiveWork: Bool,
                       unresolvedCount: Int, settleIfQuiescent: Bool) -> FilesSyncReadinessPhase {
        if settleIfQuiescent, started, paused { return .paused }
        var phase = current
        if settleIfQuiescent, started, !hasActiveWork { phase = .idle }
        if phase == .idle, started {
            if !intentPullSucceeded || !driveInventoryReady { return intentPullFailed ? .unavailable : .scanning }
            if unresolvedCount > 0 { return .needsAttention }
        }
        return phase
    }
}
