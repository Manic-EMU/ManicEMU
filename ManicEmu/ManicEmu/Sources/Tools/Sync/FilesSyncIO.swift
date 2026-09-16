//
//  FilesSyncIO.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation
import SwiftCloudDrive

final class FilesSyncIO {
    private var cloudDrive: CloudDrive?
    
    func prepare() async throws {
        if cloudDrive == nil {
            Log.debug("[iCloud Sync] CloudDrive init begin main=\(Thread.isMainThread)")
            let startedAt = Date()
            cloudDrive = try await CloudDrive()
            Log.debug("[iCloud Sync] CloudDrive init end elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s")
        }
    }
    
    func fileExists(relativePath: String) async -> Bool {
        guard let cloudDrive = try? await resolvedDrive() else { return false }
        return (try? await cloudDrive.fileExists(at: RootRelativePath(path: FilesSyncPolicy.cloudRootPath(relativePath: relativePath)))) ?? false
    }
    
    func directoryExists(relativePath: String) async -> Bool {
        guard let cloudDrive = try? await resolvedDrive() else { return false }
        return (try? await cloudDrive.directoryExists(at: RootRelativePath(path: FilesSyncPolicy.cloudRootPath(relativePath: relativePath)))) ?? false
    }
    
    enum FilesSyncIOError: Swift.Error {
        case missingLocal
    }
    
    func resetSession() {
        cloudDrive = nil
    }
    
    func upload(localURL: URL, relativePath: String) async throws {
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw FilesSyncIOError.missingLocal
        }
        let startedAt = Date()
        Log.debug("[iCloud Sync] Upload begin \(relativePath) main=\(Thread.isMainThread) bytes=\(localFileSize(localURL))")
        let drive = try await resolvedDrive()
        let parentRelative = (relativePath as NSString).deletingLastPathComponent
        if !parentRelative.isEmpty, parentRelative != "." {
            let parent = RootRelativePath(path: FilesSyncPolicy.cloudRootPath(relativePath: parentRelative))
            if !(try await drive.directoryExists(at: parent)) {
                Log.debug("[iCloud Sync] Create cloud directory \(parentRelative)")
                try await drive.createDirectory(at: parent)
            }
        }
        let cloudPath = RootRelativePath(path: FilesSyncPolicy.cloudRootPath(relativePath: relativePath))
        if (try? await drive.fileExists(at: cloudPath)) == true {
            Log.debug("[iCloud Sync] Replace existing cloud file \(relativePath)")
            try await replaceCloudFile(drive: drive, from: localURL, at: cloudPath)
        } else {
            do {
                try await drive.upload(from: localURL, to: cloudPath)
            } catch {
                if (try? await drive.fileExists(at: cloudPath)) == true {
                    Log.debug("[iCloud Sync] Upload collided, replacing \(relativePath)")
                    try await replaceCloudFile(drive: drive, from: localURL, at: cloudPath)
                } else {
                    throw error
                }
            }
        }
        Log.debug("[iCloud Sync] Upload end \(relativePath) elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s")
    }
    
    func download(relativePath: String, localURL: URL) async throws {
        let startedAt = Date()
        Log.debug("[iCloud Sync] Download begin \(relativePath) main=\(Thread.isMainThread)")
        let drive = try await resolvedDrive()
        let cloudPath = RootRelativePath(path: FilesSyncPolicy.cloudRootPath(relativePath: relativePath))
        let tempURL = URL(fileURLWithPath: R.Path.Temp.appendingPathComponent(UUID().uuidString + "-" + localURL.lastPathComponent))
        try await drive.download(from: cloudPath, toURL: tempURL)
        try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try coordinateLocalReplace(from: tempURL, to: localURL)
        Log.debug("[iCloud Sync] Download end \(relativePath) elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s")
    }
    
    func removeFile(relativePath: String) async throws {
        Log.debug("[iCloud Sync] Remove cloud file \(relativePath)")
        let drive = try await resolvedDrive()
        try await drive.removeFile(at: RootRelativePath(path: FilesSyncPolicy.cloudRootPath(relativePath: relativePath)))
    }
    
    func removeDirectory(relativePath: String) async throws {
        Log.debug("[iCloud Sync] Remove cloud directory \(relativePath)")
        let drive = try await resolvedDrive()
        try await drive.removeDirectory(at: RootRelativePath(path: FilesSyncPolicy.cloudRootPath(relativePath: relativePath)))
    }
    
    func removeCloudItem(relativePath: String, isDirectory: Bool) async throws {
        let drive = try await resolvedDrive()
        let cloudPath = RootRelativePath(path: FilesSyncPolicy.cloudRootPath(relativePath: relativePath))
        let fileExists = (try? await drive.fileExists(at: cloudPath)) ?? false
        let directoryExists = (try? await drive.directoryExists(at: cloudPath)) ?? false
        guard fileExists || directoryExists else { return }
        do {
            if isDirectory || (directoryExists && !fileExists) {
                try await drive.removeDirectory(at: cloudPath)
            } else {
                try await drive.removeFile(at: cloudPath)
            }
        } catch {
            let stillFile = (try? await drive.fileExists(at: cloudPath)) ?? false
            let stillDirectory = (try? await drive.directoryExists(at: cloudPath)) ?? false
            if stillFile || stillDirectory {
                throw error
            }
            Log.debug("[iCloud Sync] Cloud item already gone \(relativePath)")
        }
    }
    
    func listCloudFiles() async -> [String: FilesSyncFingerprint]? {
        let startedAt = Date()
        guard let drive = try? await resolvedDrive() else {
            Log.debug("[iCloud Sync] listCloudFiles skipped: CloudDrive unavailable")
            return nil
        }
        var result: [String: FilesSyncFingerprint] = [:]
        await collectCloudFiles(at: RootRelativePath(path: "Documents"), drive: drive, into: &result)
        Log.debug("[iCloud Sync] listCloudFiles count=\(result.count) elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s main=\(Thread.isMainThread)")
        return result
    }
    
    private func resolvedDrive() async throws -> CloudDrive {
        if let cloudDrive { return cloudDrive }
        let drive = try await CloudDrive()
        cloudDrive = drive
        return drive
    }
    
    private func collectCloudFiles(at path: RootRelativePath,
                                   drive: CloudDrive,
                                   into result: inout [String: FilesSyncFingerprint]) async {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
        guard let items = try? await drive.contentsOfDirectory(at: path, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return
        }
        for item in items {
            guard let values = try? item.resourceValues(forKeys: Set(keys)),
                  let relative = FilesSyncPolicy.documentsRelativePath(from: item) else { continue }
            if FilesSyncPolicy.shouldNeverSync(relativePath: relative) {
                continue
            }
            if values.isDirectory == true {
                await collectCloudFiles(at: RootRelativePath(path: FilesSyncPolicy.cloudRootPath(relativePath: relative)), drive: drive, into: &result)
            } else if values.isRegularFile == true {
                let size = Int64(values.fileSize ?? 0)
                let mtime = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                result[relative] = FilesSyncFingerprint(size: size, mtime: mtime, hash: nil)
            }
        }
    }
    
    enum EnumerationMode {
        case all
        case saveRoots
    }
    
    static func enumerateLocalFiles(root: URL = URL(fileURLWithPath: R.Path.Document),
                                    mode: EnumerationMode = .all) -> [String: FilesSyncFingerprint] {
        let startedAt = Date()
        var result: [String: FilesSyncFingerprint] = [:]
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            Log.debug("[iCloud Sync] enumerateLocalFiles failed to create enumerator mode=\(mode) root=\(root.lastPathComponent)")
            return result
        }
        for case let item as URL in enumerator {
            guard let values = try? item.resourceValues(forKeys: Set(keys)),
                  let relative = FilesSyncPolicy.documentsRelativePath(from: item) else { continue }
            if FilesSyncPolicy.shouldNeverSync(relativePath: relative) {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }
            if mode == .saveRoots, FilesSyncPolicy.shouldSkipOnSaveScan(relativePath: relative) {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }
            if values.isDirectory == true { continue }
            if values.isRegularFile == true {
                let size = Int64(values.fileSize ?? 0)
                let mtime = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                result[relative] = FilesSyncFingerprint(size: size, mtime: mtime, hash: nil)
            }
        }
        Log.debug("[iCloud Sync] enumerateLocalFiles mode=\(mode) count=\(result.count) elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s main=\(Thread.isMainThread)")
        return result
    }
    
    private func localFileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
    }
    
    private func ubiquityURL(relativePath: String) -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(relativePath)
    }
    
    private func replaceCloudFile(drive: CloudDrive, from localURL: URL, at cloudPath: RootRelativePath) async throws {
        let staging = URL(fileURLWithPath: R.Path.Temp).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: staging.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: localURL, to: staging)
        defer { try? FileManager.default.removeItem(at: staging) }
        try await drive.updateFile(at: cloudPath) { destURL in
            if FileManager.default.fileExists(atPath: destURL.path) {
                do {
                    _ = try FileManager.default.replaceItemAt(destURL, withItemAt: staging)
                } catch {
                    try FileManager.default.removeItem(at: destURL)
                    try FileManager.default.copyItem(at: staging, to: destURL)
                }
            } else {
                try FileManager.default.copyItem(at: staging, to: destURL)
            }
        }
    }
    
    private func coordinateLocalReplace(from tempURL: URL, to localURL: URL) throws {
        var coordinatorError: NSError?
        var replaceError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: localURL, options: .forReplacing, error: &coordinatorError) { url in
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
                } else {
                    try FileManager.safeMoveItem(at: tempURL, to: url, shouldReplace: true)
                }
            } catch {
                replaceError = error as NSError
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let replaceError { throw replaceError }
    }
}
