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
    private var isRunning = false
    private var emitWorkItem: DispatchWorkItem?
    var onCloudInventory: ((FilesSyncCloudInventory) -> Void)?
    
    func start() {
        guard !isRunning else { return }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            Log.debug("[iCloud Sync] No iCloud account, skip metadata query")
            return
        }
        isRunning = true
        Log.debug("[iCloud Sync] metadata query start main=\(Thread.isMainThread)")
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRunning else { return }
            self.configureIfNeeded()
            self.metadataQuery.enableUpdates()
            self.metadataQuery.start()
        }
    }
    
    func stop() {
        isRunning = false
        emitWorkItem?.cancel()
        emitWorkItem = nil
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
        metadataQuery.notificationBatchingInterval = 1
        metadataQuery.operationQueue = queryQueue
        
        let center = NotificationCenter.default
        let finish = center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: queryQueue) { [weak self] _ in
            self?.scheduleEmit(immediate: true)
        }
        let update = center.addObserver(forName: .NSMetadataQueryDidUpdate, object: metadataQuery, queue: queryQueue) { [weak self] _ in
            self?.scheduleEmit(immediate: false)
        }
        tokens = [finish, update]
    }
    
    private func scheduleEmit(immediate: Bool) {
        emitWorkItem?.cancel()
        if immediate {
            emitWorkItem = nil
            emitInventory()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.queryQueue.addOperation {
                self?.emitInventory()
            }
        }
        emitWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.75, execute: work)
    }
    
    private func emitInventory() {
        guard isRunning else { return }
        let startedAt = Date()
        metadataQuery.disableUpdates()
        let items = metadataQuery.results
        var inventory = FilesSyncCloudInventory()
        inventory.files.reserveCapacity(items.count)
        for case let item as NSMetadataItem in items {
            guard let fileURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                  let relative = FilesSyncPolicy.documentsRelativePath(from: fileURL) else { continue }
            if FilesSyncPolicy.shouldNeverSync(relativePath: relative) { continue }
            if fileURL.path.hasSuffix("/") { continue }
            if let contentType = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String,
               contentType == "public.directory" || contentType == "public.folder" {
                continue
            }
            
            let size = (item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value ?? 0
            let mtime = (item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date)?.timeIntervalSince1970 ?? 0
            inventory.files[relative] = FilesSyncFingerprint(size: size, mtime: mtime, hash: nil)
            
            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            if status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
                inventory.notDownloaded.insert(relative)
            }
            
            let uploadPercent = (item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? NSNumber)?.doubleValue
            let downloadPercent = (item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.doubleValue
            if (item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool) == true {
                inventory.uploading.insert(relative)
            } else if let percent = uploadPercent, percent > 0, percent < 100 {
                inventory.uploading.insert(relative)
            }
            if (item.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool) == true {
                inventory.downloading.insert(relative)
            } else if let percent = downloadPercent, percent > 0, percent < 100 {
                inventory.downloading.insert(relative)
            }
            
            if size > 0 {
                inventory.bytesTotal += size
                let percent: Double
                if inventory.uploading.contains(relative), let uploadPercent {
                    percent = uploadPercent
                } else if inventory.downloading.contains(relative), let downloadPercent {
                    percent = downloadPercent
                } else if status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
                    percent = 0
                } else {
                    percent = 100
                }
                inventory.bytesTransferred += Int64(Double(size) * min(max(percent, 0), 100) / 100)
            }
        }
        if isRunning {
            metadataQuery.enableUpdates()
        }
        Log.debug("[iCloud Sync] metadata emit files=\(inventory.files.count) uploading=\(inventory.uploading.count) downloading=\(inventory.downloading.count) notDownloaded=\(inventory.notDownloaded.count) elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s main=\(Thread.isMainThread)")
        onCloudInventory?(inventory)
    }
}
