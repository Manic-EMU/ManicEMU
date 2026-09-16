//
//  FilesSyncWatchers.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation

struct FilesSyncCloudInventory {
    var files: [String: FilesSyncFingerprint] = [:]
    var uploading: Set<String> = []
    var downloading: Set<String> = []
    var notDownloaded: Set<String> = []
    var bytesTransferred: Int64 = 0
    var bytesTotal: Int64 = 0
}

final class FilesSyncWatchers: NSObject {
    /// One cached row per cloud file, so an emit is pure in-memory aggregation. Reading
    /// ubiquitous attributes is an IPC round trip to the iCloud daemon, and doing it for
    /// every file on every update was the bulk of this class's CPU cost.
    private struct CloudEntry {
        var size: Int64
        var mtime: TimeInterval
        var notDownloaded: Bool
        var uploading: Bool
        var downloading: Bool
        /// Share of `size` already transferred, 0...100.
        var percent: Double
    }
    
    private let metadataQuery = NSMetadataQuery()
    /// Query notifications and result walks stay off the main thread. Reading
    /// ubiquitous item attributes can block on the iCloud daemon.
    private let queryQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.aoshuang.manicemu.files-sync-metadata"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()
    private var tokens: [NSObjectProtocol] = []
    private let lock = NSLock()
    private var isRunning = false
    private var emitWorkItem: DispatchWorkItem?
    /// Only touched on `queryQueue`, which is serial.
    private var entries: [String: CloudEntry] = [:]
    private var needsFullRebuild = true
    var onCloudInventory: ((FilesSyncCloudInventory) -> Void)?
    
    private var running: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning
    }
    
    func start() {
        lock.lock()
        if isRunning {
            lock.unlock()
            return
        }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            lock.unlock()
            Log.debug("[iCloud Sync] No iCloud account, skip metadata query")
            return
        }
        isRunning = true
        lock.unlock()
        Log.debug("[iCloud Sync] metadata query start main=\(Thread.isMainThread)")
        queryQueue.addOperation { [weak self] in
            self?.needsFullRebuild = true
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.running else { return }
            self.configureIfNeeded()
            self.metadataQuery.enableUpdates()
            self.metadataQuery.start()
        }
    }
    
    func stop() {
        lock.lock()
        isRunning = false
        let work = emitWorkItem
        emitWorkItem = nil
        lock.unlock()
        work?.cancel()
        Log.debug("[iCloud Sync] metadata query stop")
        DispatchQueue.main.async { [weak self] in
            self?.metadataQuery.stop()
            self?.metadataQuery.disableUpdates()
        }
    }
    
    deinit {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    private func configureIfNeeded() {
        guard tokens.isEmpty else { return }
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = NSPredicate(value: true)
        metadataQuery.notificationBatchingInterval = 2
        metadataQuery.operationQueue = queryQueue
        
        let center = NotificationCenter.default
        let finish = center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: queryQueue) { [weak self] _ in
            guard let self, self.running else { return }
            self.needsFullRebuild = true
            self.scheduleEmit(immediate: true)
        }
        let update = center.addObserver(forName: .NSMetadataQueryDidUpdate, object: metadataQuery, queue: queryQueue) { [weak self] notification in
            self?.applyUpdate(notification)
        }
        tokens = [finish, update]
    }
    
    /// Applies the query's added/changed/removed deltas to the cache. Runs on the serial
    /// `queryQueue`, so attribute reads only happen for items that actually moved.
    private func applyUpdate(_ notification: Notification) {
        guard running else { return }
        guard let userInfo = notification.userInfo else {
            needsFullRebuild = true
            scheduleEmit(immediate: false)
            return
        }
        var touched = 0
        for key in [NSMetadataQueryUpdateAddedItemsKey, NSMetadataQueryUpdateChangedItemsKey] {
            guard let changed = userInfo[key] as? [Any] else { continue }
            for case let item as NSMetadataItem in changed where absorb(item) {
                touched += 1
            }
        }
        if let removed = userInfo[NSMetadataQueryUpdateRemovedItemsKey] as? [Any] {
            for case let item as NSMetadataItem in removed {
                if let relative = Self.relativePath(for: item) {
                    if entries.removeValue(forKey: relative) != nil {
                        touched += 1
                    }
                } else if Self.fileURL(for: item) == nil {
                    // A removed item that can no longer report its URL would leave a stale row
                    // claiming the file is still in the cloud. Resync from the result set.
                    needsFullRebuild = true
                }
            }
        }
        guard touched > 0 || needsFullRebuild else { return }
        scheduleEmit(immediate: false)
    }
    
    private func scheduleEmit(immediate: Bool) {
        lock.lock()
        let previous = emitWorkItem
        emitWorkItem = nil
        lock.unlock()
        previous?.cancel()
        
        if immediate {
            emitInventory()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.queryQueue.addOperation {
                self?.emitInventory()
            }
        }
        lock.lock()
        emitWorkItem = work
        lock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.75, execute: work)
    }
    
    /// Reads one item's attributes into the cache. Returns false when the item is not a
    /// syncable file.
    private func absorb(_ item: NSMetadataItem) -> Bool {
        guard let relative = Self.relativePath(for: item) else { return false }
        if let contentType = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String,
           contentType == "public.directory" || contentType == "public.folder" {
            entries[relative] = nil
            return false
        }
        
        let size = (item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value ?? 0
        let mtime = (item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date)?.timeIntervalSince1970 ?? 0
        let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
        let notDownloaded = status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
        let uploadPercent = (item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? NSNumber)?.doubleValue
        let downloadPercent = (item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.doubleValue
        
        var uploading = (item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool) == true
        if !uploading, let percent = uploadPercent, percent > 0, percent < 100 {
            uploading = true
        }
        var downloading = (item.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool) == true
        if !downloading, let percent = downloadPercent, percent > 0, percent < 100 {
            downloading = true
        }
        
        let percent: Double
        if uploading, let uploadPercent {
            percent = uploadPercent
        } else if downloading, let downloadPercent {
            percent = downloadPercent
        } else if notDownloaded {
            percent = 0
        } else {
            percent = 100
        }
        
        entries[relative] = CloudEntry(size: size,
                                       mtime: mtime,
                                       notDownloaded: notDownloaded,
                                       uploading: uploading,
                                       downloading: downloading,
                                       percent: min(max(percent, 0), 100))
        return true
    }
    
    private static func fileURL(for item: NSMetadataItem) -> URL? {
        item.value(forAttribute: NSMetadataItemURLKey) as? URL
    }
    
    /// Nil for items outside Documents, for never-synced paths, and for items that cannot
    /// report a URL. Callers that need to tell those apart also check `fileURL(for:)`.
    private static func relativePath(for item: NSMetadataItem) -> String? {
        guard let fileURL = fileURL(for: item),
              let relative = FilesSyncPolicy.documentsRelativePath(from: fileURL) else { return nil }
        if FilesSyncPolicy.shouldNeverSync(relativePath: relative) { return nil }
        if fileURL.path.hasSuffix("/") { return nil }
        return relative
    }
    
    /// Walks the whole result set. Only needed after the initial gather, or if a delta
    /// notification arrived without payload.
    private func rebuildAll() {
        let startedAt = Date()
        metadataQuery.disableUpdates()
        let items = metadataQuery.results
        entries.removeAll(keepingCapacity: true)
        entries.reserveCapacity(items.count)
        for case let item as NSMetadataItem in items {
            _ = absorb(item)
        }
        if running {
            metadataQuery.enableUpdates()
        }
        needsFullRebuild = false
        Log.debug("[iCloud Sync] metadata full rebuild items=\(items.count) tracked=\(entries.count) elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s")
    }
    
    private func emitInventory() {
        guard running else { return }
        if needsFullRebuild {
            rebuildAll()
        }
        var inventory = FilesSyncCloudInventory()
        inventory.files.reserveCapacity(entries.count)
        for (relative, entry) in entries {
            inventory.files[relative] = FilesSyncFingerprint(size: entry.size, mtime: entry.mtime, hash: nil)
            if entry.notDownloaded { inventory.notDownloaded.insert(relative) }
            if entry.uploading { inventory.uploading.insert(relative) }
            if entry.downloading { inventory.downloading.insert(relative) }
            if entry.size > 0 {
                inventory.bytesTotal += entry.size
                inventory.bytesTransferred += Int64(Double(entry.size) * entry.percent / 100)
            }
        }
        Log.debug("[iCloud Sync] metadata emit files=\(inventory.files.count) uploading=\(inventory.uploading.count) downloading=\(inventory.downloading.count) notDownloaded=\(inventory.notDownloaded.count) main=\(Thread.isMainThread)")
        onCloudInventory?(inventory)
    }
}
