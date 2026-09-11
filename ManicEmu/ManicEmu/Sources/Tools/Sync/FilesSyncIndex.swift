//
//  FilesSyncIndex.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation
import Device

struct FilesSyncFingerprint: Codable, Equatable {
    var size: Int64
    var mtime: TimeInterval
    var hash: String?
    
    func matches(_ other: FilesSyncFingerprint) -> Bool {
        if size != other.size { return false }
        if let hash, let otherHash = other.hash {
            return hash == otherHash
        }
        return abs(mtime - other.mtime) < 2
    }
    
    /// iCloud often restamps mtime after upload; size (and hash when present) is the real identity.
    func samePayload(_ other: FilesSyncFingerprint) -> Bool {
        if size != other.size { return false }
        if let hash, let otherHash = other.hash {
            return hash == otherHash
        }
        return true
    }
}

enum FilesSyncTombstone {
    enum Reason: String, Codable {
        case deleted
        case excluded
    }
}

struct FilesSyncIndexStore: Codable {
    var files: [String: FilesSyncLedgerEntry] = [:]
    var lastFullScan: TimeInterval?
    /// Local change-token: last intent generation applied on this device.
    var appliedGenerations: [String: Int] = [:]
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        files = try container.decodeIfPresent([String: FilesSyncLedgerEntry].self, forKey: .files) ?? [:]
        lastFullScan = try container.decodeIfPresent(TimeInterval.self, forKey: .lastFullScan)
        appliedGenerations = try container.decodeIfPresent([String: Int].self, forKey: .appliedGenerations) ?? [:]
    }
}

struct FilesSyncLedgerEntry: Codable {
    var fingerprint: FilesSyncFingerprint
    var lastSyncedAt: TimeInterval
}

struct FilesSyncPendingStore: Codable {
    var ops: [String: FilesSyncOp] = [:]
}

enum FilesSyncIndex {
    private static let lock = NSLock()
    private static let hashSizeLimit: Int64 = 4 * 1024 * 1024
    private static var _store = FilesSyncIndexStore()
    
    static var store: FilesSyncIndexStore {
        lock.lock()
        defer { lock.unlock() }
        return _store
    }
    
    static func modify(_ body: (inout FilesSyncIndexStore) -> Void) {
        lock.lock()
        body(&_store)
        lock.unlock()
    }
    
    static func load() {
        try? FileManager.default.createDirectory(atPath: R.Path.FilesSync, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: URL(fileURLWithPath: R.Path.FilesSyncIndex)),
           let decoded = try? JSONDecoder().decode(FilesSyncIndexStore.self, from: data) {
            modify { $0 = decoded }
            Log.debug("[iCloud Sync] ledger loaded files=\(decoded.files.count) applied=\(decoded.appliedGenerations.count) lastFullScan=\(decoded.lastFullScan.map { String(Int($0)) } ?? "nil")")
        } else {
            modify { $0 = FilesSyncIndexStore() }
            Log.debug("[iCloud Sync] ledger missing, starting empty")
        }
    }
    
    static func save() {
        try? FileManager.default.createDirectory(atPath: R.Path.FilesSync, withIntermediateDirectories: true)
        let snapshot = store
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: URL(fileURLWithPath: R.Path.FilesSyncIndex), options: .atomic)
        }
    }
    
    static func loadPending() -> [String: FilesSyncOp] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: R.Path.FilesSyncPending)),
              let decoded = try? JSONDecoder().decode(FilesSyncPendingStore.self, from: data) else {
            Log.debug("[iCloud Sync] pending store empty")
            return [:]
        }
        Log.debug("[iCloud Sync] pending store loaded ops=\(decoded.ops.count)")
        return decoded.ops
    }
    
    static func savePending(_ ops: [String: FilesSyncOp]) {
        try? FileManager.default.createDirectory(atPath: R.Path.FilesSync, withIntermediateDirectories: true)
        let store = FilesSyncPendingStore(ops: ops)
        if ops.isEmpty {
            try? FileManager.default.removeItem(atPath: R.Path.FilesSyncPending)
            Log.debug("[iCloud Sync] pending store cleared")
            return
        }
        if let data = try? JSONEncoder().encode(store) {
            try? data.write(to: URL(fileURLWithPath: R.Path.FilesSyncPending), options: .atomic)
            Log.debug("[iCloud Sync] pending store saved ops=\(ops.count)")
        }
    }
    
    static var needsInitialScan: Bool {
        store.lastFullScan == nil
    }
    
    static func fingerprint(for url: URL, preferHash: Bool) -> FilesSyncFingerprint? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
        if values?.isDirectory == true { return nil }
        let size = Int64(values?.fileSize ?? 0)
        let mtime = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        var hash: String? = nil
        if preferHash, size > 0, size <= hashSizeLimit {
            hash = FileHashUtil.truncatedHash(url: url)
        }
        return FilesSyncFingerprint(size: size, mtime: mtime, hash: hash)
    }
    
    static func recordSynced(relativePath: String, fingerprint: FilesSyncFingerprint, generation: Int? = nil) {
        modify {
            $0.files[relativePath] = FilesSyncLedgerEntry(fingerprint: fingerprint, lastSyncedAt: Date().timeIntervalSince1970)
            if let generation {
                $0.appliedGenerations[relativePath] = generation
            }
        }
    }
    
    static func appliedGeneration(for relativePath: String) -> Int {
        store.appliedGenerations[relativePath] ?? 0
    }
    
    static func setAppliedGeneration(_ relativePath: String, _ generation: Int) {
        modify { $0.appliedGenerations[relativePath] = generation }
    }
    
    static func removeFile(_ relativePath: String) {
        modify { $0.files[relativePath] = nil }
    }
    
    static func markFullScan() {
        modify { $0.lastFullScan = Date().timeIntervalSince1970 }
    }
    
    static func backupLoser(localURL: URL, relativePath: String) {
        try? FileManager.default.createDirectory(atPath: R.Path.FilesSyncConflicts, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = URL(fileURLWithPath: R.Path.FilesSyncConflicts)
            .appendingPathComponent("\(stamp)_\(relativePath.replacingOccurrences(of: "/", with: "_"))")
        try? FileManager.safeCopyItem(at: localURL, to: dest, shouldReplace: true)
        Log.debug("[iCloud Sync] Conflict backup: \(relativePath) -> \(dest.lastPathComponent)")
    }
    
    static func conflictSiblingURL(for url: URL) -> URL {
        let device = Device.version().rawValue
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let stamp = Int(Date().timeIntervalSince1970)
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        let name: String
        if ext.isEmpty {
            name = "\(base).conflict.\(device).\(stamp)"
        } else {
            name = "\(base).conflict.\(device).\(stamp).\(ext)"
        }
        return url.deletingLastPathComponent().appendingPathComponent(name)
    }
}
