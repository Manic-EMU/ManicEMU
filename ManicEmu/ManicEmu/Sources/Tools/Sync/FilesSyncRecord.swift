//
//  FilesSyncRecord.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation
import RealmSwift
import IceCream
import Device

/// CloudKit-synced intent for one Documents-relative file. The row stays when the
/// file is deleted (`intent == .deleted`); IceCream `isDeleted` is only for pruning.
enum FilesSyncIntentKind: Int, PersistableEnum {
    case present = 0
    case deleted = 1
    case excluded = 2
    
    var debugLabel: String {
        switch self {
        case .present: return "present"
        case .deleted: return "deleted"
        case .excluded: return "excluded"
        }
    }
}

extension FilesSyncRecord: CKRecordConvertible & CKRecordRecoverable {}

class FilesSyncRecord: Object, ObjectUpdatable {
    /// SHA-256 of `path` so the CloudKit record name stays ASCII and under 255 characters.
    @Persisted(primaryKey: true) var id: String
    @Persisted var path: String
    @Persisted var generation: Int
    @Persisted var size: Int64 = 0
    @Persisted var intent: FilesSyncIntentKind
    @Persisted var updatedAt: Date
    @Persisted var device: String = Device.version().rawValue
    /// IceCream tombstone for this row. Do not use for file deletion.
    @Persisted var isDeleted: Bool = false
    @Persisted var extras: Data?
    
    static func objectId(forPath path: String) -> String {
        path.sha256()
    }
    
    func getExtra(key: String) -> Any? {
        if let extras {
            return Self.getExtra(extras: extras, key: key)
        }
        return nil
    }
    
    func updateExtra(key: String, value: Any?) {
        if let extras, let data = Self.updateExtra(extras: extras, key: key, value: value) {
            Self.change { realm in
                self.extras = data
            }
        } else if let data = [key: value].jsonData() {
            Self.change { realm in
                self.extras = data
            }
        }
    }
}

struct FilesSyncIntentSnapshot {
    var path: String
    var generation: Int
    var size: Int64
    var intent: FilesSyncIntentKind
    var updatedAt: Date
}

enum FilesSyncIntentStore {
    private static let pruneAfter: TimeInterval = 90 * 24 * 60 * 60
    
    static func snapshot(relativePath: String) -> FilesSyncIntentSnapshot? {
        let realm = Database.realm
        let id = FilesSyncRecord.objectId(forPath: relativePath)
        guard let record = realm.object(ofType: FilesSyncRecord.self, forPrimaryKey: id),
              !record.isDeleted else { return nil }
        return snapshot(record)
    }
    
    static func allActive() -> [String: FilesSyncIntentSnapshot] {
        let records = Database.realm.objects(FilesSyncRecord.self).where { !$0.isDeleted }
        var result: [String: FilesSyncIntentSnapshot] = [:]
        result.reserveCapacity(records.count)
        for record in records {
            result[record.path] = snapshot(record)
        }
        return result
    }
    
    static func paths(matchingPrefix prefix: String) -> [String] {
        let records = Database.realm.objects(FilesSyncRecord.self).where { !$0.isDeleted }
        return records.compactMap { record in
            if record.path == prefix || record.path.hasPrefix(prefix + "/") {
                return record.path
            }
            return nil
        }
    }
    
    static func hasPresentIntent(relativePath: String, isDirectory: Bool) -> Bool {
        if let item = snapshot(relativePath: relativePath), item.intent == .present {
            return true
        }
        guard isDirectory else { return false }
        return allActive().contains { path, item in
            item.intent == .present && (path == relativePath || path.hasPrefix(relativePath + "/"))
        }
    }
    
    /// Creates or bumps the row after a successful upload.
    @discardableResult
    static func markPresent(relativePath: String, size: Int64) -> Int {
        write(relativePath: relativePath, intent: .present, size: size, bump: true)
    }
    
    /// Writes a delete intent before removing the Drive copy.
    @discardableResult
    static func markDeleted(relativePath: String) -> Int {
        write(relativePath: relativePath, intent: .deleted, size: 0, bump: true)
    }
    
    @discardableResult
    static func markExcluded(relativePath: String) -> Int {
        write(relativePath: relativePath, intent: .excluded, size: 0, bump: true)
    }
    
    static func pruneExpiredDeleted() {
        let cutoff = Date().addingTimeInterval(-pruneAfter)
        let realm = Database.realm
        let expired = realm.objects(FilesSyncRecord.self).where {
            !$0.isDeleted && $0.intent == .deleted && $0.updatedAt < cutoff
        }
        guard !expired.isEmpty else { return }
        var pruned = 0
        try? realm.write {
            for record in expired {
                // Keep unapplied deletes so a later catch-up can still remove the Drive copy.
                if FilesSyncIndex.appliedGeneration(for: record.path) < record.generation {
                    continue
                }
                record.isDeleted = true
                pruned += 1
            }
        }
        if pruned > 0 {
            Log.debug("[iCloud Sync] pruned \(pruned) expired delete intents")
        }
    }
    
    private static func write(relativePath: String, intent: FilesSyncIntentKind, size: Int64, bump: Bool) -> Int {
        let id = FilesSyncRecord.objectId(forPath: relativePath)
        let realm = Database.realm
        var generation = 1
        try? realm.write {
            if let existing = realm.object(ofType: FilesSyncRecord.self, forPrimaryKey: id), !existing.isDeleted {
                generation = bump ? existing.generation + 1 : max(existing.generation, 1)
                existing.generation = generation
                existing.intent = intent
                existing.size = size
                existing.updatedAt = Date()
                existing.device = Device.version().rawValue
                existing.path = relativePath
            } else {
                let record = FilesSyncRecord()
                record.id = id
                record.path = relativePath
                record.generation = 1
                record.size = size
                record.intent = intent
                record.updatedAt = Date()
                record.device = Device.version().rawValue
                record.isDeleted = false
                realm.add(record, update: .modified)
                generation = 1
            }
        }
        Log.debug("[iCloud Sync] intent \(intentLabel(intent)) gen=\(generation) size=\(size) \(relativePath)")
        return generation
    }
    
    private static func snapshot(_ record: FilesSyncRecord) -> FilesSyncIntentSnapshot {
        FilesSyncIntentSnapshot(
            path: record.path,
            generation: record.generation,
            size: record.size,
            intent: record.intent,
            updatedAt: record.updatedAt
        )
    }
    
    private static func intentLabel(_ intent: FilesSyncIntentKind) -> String {
        switch intent {
        case .present: return "present"
        case .deleted: return "deleted"
        case .excluded: return "excluded"
        }
    }
}
