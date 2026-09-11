//
//  FilesSyncManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation
import CloudKit
import Network
import RealmSwift

struct FilesSyncProgress {
    enum Phase: String {
        case idle
        case scanning
        case syncing
        case paused
        case unavailable
    }
    
    var phase: Phase = .idle
    var completedCount: Int = 0
    var totalCount: Int = 0
    var bytesTransferred: Int64 = 0
    var bytesTotal: Int64 = 0
    var currentFileName: String?
    
    var fraction: Float {
        if totalCount <= 0 {
            return phase == .idle ? 1 : 0
        }
        return min(1, Float(completedCount) / Float(totalCount))
    }
    
    var isBusy: Bool {
        phase == .scanning || phase == .syncing
    }
}

struct FilesSyncRepairStats {
    var uploads: Int = 0
    var downloads: Int = 0
    var deletes: Int = 0
    
    var queued: Int { uploads + downloads + deletes }
}

enum FilesSyncROMAvailability {
    case local
    case syncing
    case excluded
    case missing
}

enum FilesSyncRepairEvent {
    case alreadyRunning
    case notStarted
    case scanFinished(FilesSyncRepairStats)
    case completed(uploaded: Int, downloaded: Int, remaining: Int)
}

final class FilesSyncManager {
    static let shared = FilesSyncManager()
    
    private let engine = FilesSyncEngine()
    private let watchers = FilesSyncWatchers()
    private var startPlayToken: Any?
    private var stopPlayToken: Any?
    private var accountToken: Any?
    private var pathMonitor: NWPathMonitor?
    private var networkSatisfied = false
    private var intentToken: NotificationToken?
    
    private(set) var progress = FilesSyncProgress()
    
    var hasDownloadTask: Bool { engine.hasDownloadTask }
    
    var syncState: SyncManager.SyncState {
        switch progress.phase {
        case .idle, .paused:
            return .idle
        case .scanning, .syncing:
            return .syncing
        case .unavailable:
            return .undefine
        }
    }
    
    private init() {
        engine.onProgress = { [weak self] progress in
            self?.progress = progress
        }
        watchers.onCloudInventory = { [weak self] inventory in
            self?.engine.applyCloudInventory(inventory)
        }
    }
    
    func start() {
#if SIDE_LOAD
        return
#else
        guard Settings.iCloudSyncEnableValue else {
            Log.debug("[iCloud Sync] Manager.start skipped (disabled) main=\(Thread.isMainThread)")
            return
        }
        Log.debug("[iCloud Sync] Manager.start main=\(Thread.isMainThread)")
        observeLifecycleIfNeeded()
        watchers.start()
        engine.start()
        startPathMonitor()
        observeIntentRecords()
#endif
    }
    
    func stop() {
        Log.debug("[iCloud Sync] Manager.stop main=\(Thread.isMainThread)")
        stopPathMonitor()
        watchers.stop()
        engine.stop()
        intentToken = nil
        progress = FilesSyncProgress()
        NotificationCenter.default.post(name: R.NotificationName.iCloudDriveSyncChange, object: progress)
    }
    
    func noteLocalChange(at url: URL) {
#if SIDE_LOAD
        return
#else
        guard Settings.iCloudSyncEnableValue else {
            Log.debug("[iCloud Sync] noteLocalChange skipped (disabled): \(url.path)")
            return
        }
        Log.debug("[iCloud Sync] Manager.noteLocalChange \(url.path)")
        engine.noteLocalChange(at: url)
#endif
    }
    
    func noteLocalChange(path: String) {
        noteLocalChange(at: URL(fileURLWithPath: path))
    }
    
    func noteLocalRemoval(at url: URL) {
#if SIDE_LOAD
        return
#else
        guard Settings.iCloudSyncEnableValue else { return }
        engine.noteLocalRemoval(at: url)
#endif
    }
    
    func noteLocalRemoval(path: String) {
        noteLocalRemoval(at: URL(fileURLWithPath: path))
    }
    
    /// Drop Drive copies when the user deletes a game, even if ROM sync is off
    /// and the cloud file was kept.
    func noteGameROMRemoval(for game: Game) {
#if SIDE_LOAD
        return
#else
        guard FilesSyncPolicy.isDriveSyncAvailable else { return }
        let urls = game.iCloudROMFileURLs
        Log.debug("[iCloud Sync] noteGameROMRemoval game=\(game.name) count=\(urls.count)")
        for url in urls {
            noteLocalRemoval(at: url)
        }
#endif
    }
    
    func romAvailability(for game: Game) -> FilesSyncROMAvailability {
        if game.isRomExtsts {
            return .local
        }
#if SIDE_LOAD
        return .missing
#else
        if !Settings.iCloudSyncEnableValue {
            return .missing
        }
        if !FilesSyncPolicy.shouldSyncROM(game) {
            return .excluded
        }
        for url in game.iCloudROMFileURLs {
            guard let relative = FilesSyncPolicy.documentsRelativePath(from: url) else { continue }
            if FileManager.default.fileExists(atPath: url.path) { continue }
            if FilesSyncIntentStore.hasPresentIntent(relativePath: relative, isDirectory: true) {
                return .syncing
            }
        }
        return .missing
#endif
    }
    
    func ensureROM(for game: Game, completion: ((Error?) -> Void)? = nil) {
#if SIDE_LOAD
        completion?(NSError(domain: "FilesSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "ROM sync disabled"]))
        return
#else
        if !FilesSyncPolicy.shouldSyncROM(game) {
            completion?(NSError(domain: "FilesSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "ROM sync disabled"]))
            return
        }
        let urls = game.iCloudROMFileURLs
        Log.debug("[iCloud Sync] ensureROM game=\(game.name) urls=\(urls.map(\.lastPathComponent).joined(separator: ","))")
        Task.detached {
            var lastError: Error?
            for url in urls {
                if FileManager.default.fileExists(atPath: url.path) {
                    Log.debug("[iCloud Sync] ensureROM already local: \(url.lastPathComponent)")
                    continue
                }
                if let error = await self.engine.ensureLocal(at: url) {
                    lastError = error
                }
            }
            let errorToReport = lastError
            await MainActor.run {
                completion?(errorToReport)
            }
        }
#endif
    }
    
    func ensureLocal(at url: URL, completion: ((Error?) -> Void)? = nil) {
#if SIDE_LOAD
        completion?(nil)
        return
#else
        Task.detached {
            let error = await self.engine.ensureLocal(at: url)
            await MainActor.run {
                completion?(error)
            }
        }
#endif
    }
    
    func cloudFileExists(localFilePath: String, completion: ((Bool) -> Void)? = nil) {
        guard let relative = FilesSyncPolicy.documentsRelativePath(from: localFilePath) else {
            completion?(false)
            return
        }
        Task.detached {
            let exists = await self.engine.cloudFileExists(relativePath: relative)
            await MainActor.run {
                completion?(exists)
            }
        }
    }
    
    func reconcile() {
#if SIDE_LOAD
        return
#else
        guard Settings.iCloudSyncEnableValue else { return }
        Log.debug("[iCloud Sync] Manager.reconcile requested")
        engine.requestReconcile(full: false)
#endif
    }
    
    func repair(_ handler: @escaping (FilesSyncRepairEvent) -> Void) -> Bool {
#if SIDE_LOAD
        DispatchQueue.main.async { handler(.notStarted) }
        return false
#else
        guard Settings.iCloudSyncEnableValue else {
            Log.debug("[iCloud Sync] Manager.repair skipped (disabled)")
            DispatchQueue.main.async { handler(.notStarted) }
            return false
        }
        Log.debug("[iCloud Sync] Manager.repair requested")
        return engine.requestRepair(handler)
#endif
    }
    
    func excludeCloudROMs(for games: [Game]) {
#if SIDE_LOAD
        return
#else
        guard FilesSyncPolicy.isDriveSyncAvailable else { return }
        var urls: [URL] = []
        for game in games {
            urls.append(contentsOf: game.iCloudROMFileURLs)
        }
        engine.excludeCloudCopies(urls: urls)
#endif
    }
    
    /// Upload or evict Drive copies after the user assigns or changes GameType.
    func applyROMSyncAfterGameTypeChange(for games: [Game]) {
#if SIDE_LOAD
        return
#else
        guard FilesSyncPolicy.isDriveSyncAvailable, !games.isEmpty else { return }
        var evict: [Game] = []
        for game in games {
            if FilesSyncPolicy.shouldSyncROM(game) {
                uploadROMFiles(for: game)
            } else {
                evict.append(game)
            }
        }
        if !evict.isEmpty {
            excludeCloudROMs(for: evict)
        }
#endif
    }
    
    func uploadROMFiles(for game: Game, extraFiles: [URL] = []) {
#if SIDE_LOAD
        return
#else
        guard FilesSyncPolicy.isDriveSyncAvailable else {
            Log.debug("[iCloud Sync] uploadROMFiles skipped (iCloud unavailable): \(game.name)")
            return
        }
        guard FilesSyncPolicy.shouldSyncROM(game) else {
            Log.debug("[iCloud Sync] uploadROMFiles skipped (ROM sync disabled): \(game.name)")
            return
        }
        var urls = game.iCloudROMFileURLs
        urls.append(contentsOf: extraFiles)
        Log.debug("[iCloud Sync] uploadROMFiles game=\(game.name) count=\(Set(urls).count) files=\(Set(urls).map(\.lastPathComponent).joined(separator: ","))")
        for url in Set(urls) {
            noteLocalChange(at: url)
        }
#endif
    }
    
    func handleDidBecomeActive() {
        Log.debug("[iCloud Sync] Manager.handleDidBecomeActive main=\(Thread.isMainThread)")
        engine.handleDidBecomeActive()
    }
    
    func handleAccountChange() {
        guard Settings.iCloudSyncEnableValue else { return }
        stop()
        start()
    }
    
    private func observeLifecycleIfNeeded() {
        if startPlayToken == nil {
            startPlayToken = NotificationCenter.default.addObserver(forName: R.NotificationName.StartPlayGame, object: nil, queue: .main) { [weak self] _ in
                self?.engine.setPausedForGameplay(true)
            }
        }
        if stopPlayToken == nil {
            stopPlayToken = NotificationCenter.default.addObserver(forName: R.NotificationName.StopPlayGame, object: nil, queue: .main) { [weak self] _ in
                self?.engine.setPausedForGameplay(false)
            }
        }
        if accountToken == nil {
            accountToken = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
                self?.handleAccountChange()
            }
        }
    }
    
    private func startPathMonitor() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            let becameSatisfied = satisfied && !self.networkSatisfied
            self.networkSatisfied = satisfied
            if becameSatisfied {
                Log.debug("[iCloud Sync] network became satisfied")
                self.engine.handleNetworkSatisfied()
            } else if !satisfied {
                Log.debug("[iCloud Sync] network unsatisfied")
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        Log.debug("[iCloud Sync] network path monitor started")
    }
    
    private func stopPathMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
        networkSatisfied = false
        Log.debug("[iCloud Sync] network path monitor stopped")
    }
    
    private func observeIntentRecords() {
#if SIDE_LOAD
        return
#else
        intentToken = Database.realm.objects(FilesSyncRecord.self).where { !$0.isDeleted }.observe { [weak self] changes in
            guard let self else { return }
            switch changes {
            case .initial:
                break
            case .update(let collection, _, let insertions, let modifications):
                var paths: [String] = []
                for index in insertions + modifications where index < collection.count {
                    paths.append(collection[index].path)
                }
                self.engine.handleIntentPaths(paths)
            case .error(let error):
                Log.debug("[iCloud Sync] intent observe error: \(error)")
            }
        }
#endif
    }
}
