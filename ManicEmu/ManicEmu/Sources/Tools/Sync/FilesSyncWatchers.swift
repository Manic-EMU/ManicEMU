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
    private var tokens: [NSObjectProtocol] = []
    private var isRunning = false
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
            self?.configureIfNeeded()
            self?.metadataQuery.enableUpdates()
            self?.metadataQuery.start()
        }
    }
    
    func stop() {
        isRunning = false
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
        metadataQuery.notificationBatchingInterval = 0.5
        
        let center = NotificationCenter.default
        let finish = center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: .main) { [weak self] _ in
            self?.metadataQuery.disableUpdates()
            self?.emitInventory()
            self?.metadataQuery.enableUpdates()
        }
        let update = center.addObserver(forName: .NSMetadataQueryDidUpdate, object: metadataQuery, queue: .main) { [weak self] _ in
            self?.emitInventory()
        }
        tokens = [finish, update]
    }
    
    private func emitInventory() {
        guard isRunning else { return }
        let startedAt = Date()
        var inventory = FilesSyncCloudInventory()
        for case let item as NSMetadataItem in metadataQuery.results {
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
        Log.debug("[iCloud Sync] metadata emit files=\(inventory.files.count) uploading=\(inventory.uploading.count) downloading=\(inventory.downloading.count) notDownloaded=\(inventory.notDownloaded.count) elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s main=\(Thread.isMainThread)")
        onCloudInventory?(inventory)
    }
}
