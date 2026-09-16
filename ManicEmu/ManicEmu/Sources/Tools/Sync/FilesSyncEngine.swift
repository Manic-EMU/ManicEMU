//
//  FilesSyncEngine.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation

enum FilesSyncOpKind: String, Codable {
    case upload
    case download
    case deleteCloud
    case deleteLocal
}

struct FilesSyncOp: Codable {
    enum CodingKeys: String, CodingKey {
        case relativePath, kind, tombstoneReason, isDirectory, isConflict, retries, token
    }
    
    var relativePath: String
    var kind: FilesSyncOpKind
    var tombstoneReason: FilesSyncTombstone.Reason?
    var isDirectory: Bool
    var isConflict: Bool
    var retries: Int
    /// Unique id so drain completion cannot drop a newer op for the same path.
    var token: Int
    
    init(relativePath: String,
         kind: FilesSyncOpKind,
         tombstoneReason: FilesSyncTombstone.Reason?,
         isDirectory: Bool = false,
         isConflict: Bool = false,
         retries: Int = 0,
         token: Int = 0) {
        self.relativePath = relativePath
        self.kind = kind
        self.tombstoneReason = tombstoneReason
        self.isDirectory = isDirectory
        self.isConflict = isConflict
        self.retries = retries
        self.token = token
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        relativePath = try container.decode(String.self, forKey: .relativePath)
        kind = try container.decode(FilesSyncOpKind.self, forKey: .kind)
        tombstoneReason = try container.decodeIfPresent(FilesSyncTombstone.Reason.self, forKey: .tombstoneReason)
        isDirectory = try container.decodeIfPresent(Bool.self, forKey: .isDirectory) ?? false
        isConflict = try container.decodeIfPresent(Bool.self, forKey: .isConflict) ?? false
        retries = try container.decodeIfPresent(Int.self, forKey: .retries) ?? 0
        token = try container.decodeIfPresent(Int.self, forKey: .token) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(relativePath, forKey: .relativePath)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(tombstoneReason, forKey: .tombstoneReason)
        try container.encode(isDirectory, forKey: .isDirectory)
        try container.encode(isConflict, forKey: .isConflict)
        try container.encode(retries, forKey: .retries)
        try container.encode(token, forKey: .token)
    }
}

private enum FilesSyncDecideAction {
    case skip
    case upload
    case download
    case deleteCloud
    case deleteLocal
}

final class FilesSyncEngine {
    private let io = FilesSyncIO()
    private let lock = NSLock()
    private var pending: [String: FilesSyncOp] = [:]
    private var deferred: [String: FilesSyncOp] = [:]
    private var inFlight: [String: FilesSyncOp] = [:]
    private var drainTask: Task<Void, Never>?
    private var workTail = Task<Void, Never> {}
    private var drainGeneration = 0
    private var workGeneration = 0
    private var nextOpToken = 0
    private let maxConcurrent = 3
    private let maxRetries = 5
    private var pausedForGameplay = false
    private var started = false
    private var latestCloudFiles: [String: FilesSyncFingerprint] = [:]
    private var notDownloaded = Set<String>()
    private var cloudListingReady = false
    private var romExclusion = FilesSyncROMExclusion()
    private var pendingLocalNotes: [URL] = []
    private var pendingLocalRemovals: [URL] = []
    private var pendingInventory: FilesSyncCloudInventory?
    private var repairInFlight = false
    private var lastProgressPostedAt: TimeInterval = 0
    
    var onProgress: ((FilesSyncProgress) -> Void)?
    
    private(set) var progress = FilesSyncProgress() {
        didSet { onProgress?(progress) }
    }
    
    var hasDownloadTask: Bool {
        withLock {
            pending.values.contains(where: { $0.kind == .download })
                || inFlight.values.contains(where: { $0.kind == .download })
        }
    }
    
    private var isStarted: Bool {
        withLock { started }
    }
    
    func start() {
#if SIDE_LOAD
        return
#else
        let alreadyStarted = withLock { () -> Bool in
            if started { return true }
            started = true
            return false
        }
        if alreadyStarted {
            Log.debug("[iCloud Sync] start ignored (already started) main=\(Thread.isMainThread)")
            return
        }
        Log.debug("[iCloud Sync] start queued main=\(Thread.isMainThread)")
        enqueueWork("bootstrap") { [weak self] in
            await self?.bootstrap()
        }
#endif
    }
    
    func stop() {
        Log.debug("[iCloud Sync] stop main=\(Thread.isMainThread) \(queueSummary())")
        let snapshot: [String: FilesSyncOp] = withLock {
            started = false
            drainGeneration += 1
            workGeneration += 1
            workTail = Task {}
            drainTask = nil
            var all = deferred
            for (path, op) in pending {
                all[path] = op
            }
            pending.removeAll()
            deferred.removeAll()
            inFlight.removeAll()
            pendingLocalNotes.removeAll()
            pendingLocalRemovals.removeAll()
            pendingInventory = nil
            repairInFlight = false
            return all
        }
        FilesSyncIndex.savePending(snapshot)
        publish {
            $0 = FilesSyncProgress()
            $0.phase = .idle
        }
    }
    
    /// Drop Drive ledger and in-memory queues after an iCloud account switch.
    func resetForAccountChange() {
        Log.debug("[iCloud Sync] reset ledger for account change")
        io.resetSession()
        FilesSyncIndex.reset()
        withLock {
            pending.removeAll()
            deferred.removeAll()
            inFlight.removeAll()
            latestCloudFiles.removeAll()
            notDownloaded.removeAll()
            pendingLocalNotes.removeAll()
            pendingLocalRemovals.removeAll()
            pendingInventory = nil
            cloudListingReady = false
            nextOpToken = 0
            repairInFlight = false
        }
    }
    
    func setPausedForGameplay(_ paused: Bool) {
        Log.debug("[iCloud Sync] gameplay pause=\(paused) \(queueSummary())")
        withLock { pausedForGameplay = paused }
        if paused {
            publish { $0.phase = .paused }
        } else {
            enqueueWork("resumeAfterGameplay") { [weak self] in
                self?.flushDeferredOps(reason: "resumeAfterGameplay")
                await self?.reconcile(full: false, saveRootsOnly: true)
            }
        }
    }
    
    func handleDidBecomeActive() {
        guard isStarted else {
            Log.debug("[iCloud Sync] didBecomeActive ignored (not started)")
            return
        }
        if withLock({ pausedForGameplay }) {
            Log.debug("[iCloud Sync] didBecomeActive ignored (gameplay paused)")
            return
        }
        Log.debug("[iCloud Sync] didBecomeActive queued \(queueSummary())")
        enqueueWork("didBecomeActive") { [weak self] in
            self?.flushDeferredOps(reason: "foreground")
            await self?.reconcile(full: false, saveRootsOnly: true)
        }
    }
    
    func handleNetworkSatisfied() {
        guard isStarted else {
            Log.debug("[iCloud Sync] network satisfied ignored (not started)")
            return
        }
        if withLock({ pausedForGameplay }) {
            Log.debug("[iCloud Sync] network satisfied ignored (gameplay paused)")
            return
        }
        Log.debug("[iCloud Sync] network satisfied queued \(queueSummary())")
        enqueueWork("networkSatisfied") { [weak self] in
            self?.flushDeferredOps(reason: "network")
            self?.pump()
        }
    }
    
    @discardableResult
    func requestRepair(_ handler: @escaping (FilesSyncRepairEvent) -> Void) -> Bool {
        guard isStarted else {
            Log.debug("[iCloud Sync] repair ignored (not started)")
            DispatchQueue.main.async { handler(.notStarted) }
            return false
        }
        let accepted = withLock { () -> Bool in
            if repairInFlight { return false }
            repairInFlight = true
            return true
        }
        guard accepted else {
            Log.debug("[iCloud Sync] repair ignored (already running)")
            DispatchQueue.main.async { handler(.alreadyRunning) }
            return false
        }
        Log.debug("[iCloud Sync] repair queued \(queueSummary())")
        enqueueWork("repair") { [weak self] in
            guard let self else { return }
            defer { self.withLock { self.repairInFlight = false } }
            guard self.isStarted else {
                DispatchQueue.main.async { handler(.notStarted) }
                return
            }
            self.flushDeferredOps(reason: "repair")
            let stats = await self.reconcile(full: true)
            Log.debug("[iCloud Sync] repair scan uploads=\(stats.uploads) downloads=\(stats.downloads) deletes=\(stats.deletes)")
            DispatchQueue.main.async { handler(.scanFinished(stats)) }
            if stats.queued > 0 {
                await self.waitUntilIdle()
            }
            let remaining = self.withLock { self.deferred.count }
            Log.debug("[iCloud Sync] repair completed remaining=\(remaining)")
            DispatchQueue.main.async {
                handler(.completed(uploaded: stats.uploads, downloaded: stats.downloads, remaining: remaining))
            }
        }
        return true
    }
    
    func requestReconcile(full: Bool) {
        guard isStarted else {
            Log.debug("[iCloud Sync] reconcile ignored (not started)")
            return
        }
        enqueueWork("reconcile full=\(full)") { [weak self] in
            await self?.reconcile(full: full)
        }
    }
    
    func noteLocalChange(at url: URL) {
        if !isStarted {
            withLock { pendingLocalNotes.append(url) }
            Log.debug("[iCloud Sync] noteLocalChange queued (not started): \(url.path)")
            return
        }
        Log.debug("[iCloud Sync] noteLocalChange \(url.path) main=\(Thread.isMainThread)")
        enqueueWork("noteLocal \(url.lastPathComponent)") { [weak self] in
            await self?.processLocalChange(url)
        }
    }
    
    func noteLocalRemoval(at url: URL) {
        if !isStarted {
            withLock { pendingLocalRemovals.append(url) }
            Log.debug("[iCloud Sync] noteLocalRemoval queued (not started): \(url.path)")
            return
        }
        Log.debug("[iCloud Sync] noteLocalRemoval \(url.path)")
        enqueueWork("noteRemoval \(url.lastPathComponent)") { [weak self] in
            await self?.processLocalRemoval(url)
        }
    }
    
    func handleIntentPaths(_ paths: [String]) {
        guard isStarted, !paths.isEmpty else { return }
        Log.debug("[iCloud Sync] intent records changed count=\(paths.count)")
        enqueueWork("intentRecords") { [weak self] in
            await self?.applyIntentPaths(paths)
        }
    }
    
    func excludeCloudCopies(urls: [URL]) {
        guard isStarted else { return }
        Log.debug("[iCloud Sync] excludeCloudCopies count=\(urls.count)")
        enqueueWork("excludeCloudCopies") { [weak self] in
            await self?.processExcludeCloudCopies(urls)
        }
    }
    
    func ensureLocal(at url: URL) async -> Error? {
        Log.debug("[iCloud Sync] ensureLocal requested \(url.path) main=\(Thread.isMainThread)")
        return await performEnsureLocal(url)
    }
    
    func cloudFileExists(relativePath: String) async -> Bool {
        await io.fileExists(relativePath: relativePath)
    }
    
    func applyCloudInventory(_ inventory: FilesSyncCloudInventory) {
        let uploading = inventory.uploading.prefix(5).joined(separator: ",")
        let downloading = inventory.downloading.prefix(5).joined(separator: ",")
        Log.debug("[iCloud Sync] metadata files=\(inventory.files.count) uploading=\(inventory.uploading.count)[\(uploading)] downloading=\(inventory.downloading.count)[\(downloading)] notDownloaded=\(inventory.notDownloaded.count) main=\(Thread.isMainThread)")
        withLock { pendingInventory = inventory }
        enqueueWork("cloudInventory") { [weak self] in
            await self?.flushCloudInventory()
        }
    }
    
    private func bootstrap() async {
#if SIDE_LOAD
        return
#else
        guard isStarted else { return }
        let startedAt = Date()
        Log.debug("[iCloud Sync] bootstrap begin main=\(Thread.isMainThread)")
        FilesSyncIndex.load()
        loadDeferredFromDisk()
        Log.debug("[iCloud Sync] ledger files=\(FilesSyncIndex.store.files.count) needsInitialScan=\(FilesSyncIndex.needsInitialScan)")
        do {
            try await io.prepare()
        } catch {
            Log.debug("[iCloud Sync] CloudDrive init failed: \(error)")
            publish { $0.phase = .unavailable }
            return
        }
        flushDeferredOps(reason: "bootstrap")
        FilesSyncIntentStore.pruneExpiredDeleted()
        if FilesSyncIndex.needsInitialScan {
            await reconcile(full: true)
        } else {
            await reconcile(full: false, saveRootsOnly: true)
            catchUpUntrackedContentTrees()
        }
        let notes = withLock { () -> [URL] in
            let queued = pendingLocalNotes
            pendingLocalNotes.removeAll()
            return queued
        }
        if !notes.isEmpty {
            Log.debug("[iCloud Sync] flushing \(notes.count) local changes queued before bootstrap")
            for url in notes {
                guard isStarted else { return }
                await processLocalChange(url)
            }
        }
        let removals = withLock { () -> [URL] in
            let queued = pendingLocalRemovals
            pendingLocalRemovals.removeAll()
            return queued
        }
        if !removals.isEmpty {
            Log.debug("[iCloud Sync] flushing \(removals.count) local removals queued before bootstrap")
            for url in removals {
                guard isStarted else { return }
                await processLocalRemoval(url)
            }
        }
        Log.debug("[iCloud Sync] bootstrap end elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s \(queueSummary())")
#endif
    }
    
    @discardableResult
    func reconcile(full: Bool, cloudFiles: [String: FilesSyncFingerprint]? = nil, saveRootsOnly: Bool = false) async -> FilesSyncRepairStats {
#if SIDE_LOAD
        return FilesSyncRepairStats()
#else
        guard isStarted else { return FilesSyncRepairStats() }
        if withLock({ pausedForGameplay }) {
            Log.debug("[iCloud Sync] reconcile skipped (gameplay paused) full=\(full) saveRootsOnly=\(saveRootsOnly)")
            publish { $0.phase = .paused }
            return FilesSyncRepairStats()
        }
        let startedAt = Date()
        Log.debug("[iCloud Sync] reconcile begin full=\(full) saveRootsOnly=\(saveRootsOnly) main=\(Thread.isMainThread)")
        publish { $0.phase = .scanning }
        refreshROMExclusion()
        let mode: FilesSyncIO.EnumerationMode = (full || !saveRootsOnly) ? .all : .saveRoots
        let local = FilesSyncIO.enumerateLocalFiles(mode: mode)
        var allCloud: [String: FilesSyncFingerprint]
        if let cloudFiles {
            allCloud = cloudFiles
            withLock { cloudListingReady = true }
        } else if withLock({ latestCloudFiles.isEmpty }) {
            if let listed = await io.listCloudFiles() {
                allCloud = listed
                withLock { cloudListingReady = true }
            } else {
                allCloud = [:]
            }
        } else {
            allCloud = withLock { latestCloudFiles }
        }
        withLock {
            if !allCloud.isEmpty {
                latestCloudFiles = allCloud
            }
        }
        let cloudForDecide: [String: FilesSyncFingerprint]
        if saveRootsOnly, !full {
            cloudForDecide = allCloud.filter { !FilesSyncPolicy.shouldSkipOnSaveScan(relativePath: $0.key) }
        } else {
            cloudForDecide = allCloud
        }
        let intentPaths = FilesSyncIntentStore.allActive().keys.filter { path in
            if saveRootsOnly, !full, FilesSyncPolicy.shouldSkipOnSaveScan(relativePath: path) {
                return false
            }
            return true
        }
        let keys = Set(local.keys).union(cloudForDecide.keys).union(intentPaths)
        Log.debug("[iCloud Sync] reconcile compare local=\(local.count) cloud=\(cloudForDecide.count) intents=\(intentPaths.count) keys=\(keys.count)")
        
        var stats = FilesSyncRepairStats()
        var skipCount = 0
        for relative in keys.sorted() {
            if FilesSyncPolicy.shouldNeverSync(relativePath: relative) {
                skipCount += 1
                continue
            }
            if saveRootsOnly, !full, FilesSyncPolicy.shouldSkipOnSaveScan(relativePath: relative) {
                skipCount += 1
                continue
            }
            switch decide(relativePath: relative, local: local[relative], cloud: cloudForDecide[relative]) {
            case .upload: stats.uploads += 1
            case .download: stats.downloads += 1
            case .skip: skipCount += 1
            case .deleteCloud, .deleteLocal: stats.deletes += 1
            }
        }
        
        if full {
            FilesSyncIndex.markFullScan()
        }
        FilesSyncIndex.save()
        persistQueuedOps()
        pump()
        let idle = withLock { pending.isEmpty && inFlight.isEmpty }
        if idle {
            publish {
                $0.phase = .idle
                $0.completedCount = 0
                $0.totalCount = 0
                $0.currentFileName = nil
            }
        }
        Log.debug("[iCloud Sync] reconcile end full=\(full) saveRootsOnly=\(saveRootsOnly) upload=\(stats.uploads) download=\(stats.downloads) delete=\(stats.deletes) skip=\(skipCount) idle=\(idle) elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s \(queueSummary())")
        return stats
#endif
    }
    
    private func catchUpUntrackedContentTrees() {
        refreshROMExclusion()
        let local = FilesSyncIO.enumerateLocalFiles(mode: .all)
        let ledger = FilesSyncIndex.store.files
        let cloud = withLock { latestCloudFiles }
        let cloudKnown = !cloud.isEmpty
        let intents = FilesSyncIntentStore.allActive()
        var untracked = 0
        var missingOnCloud = 0
        var considered = 0
        for (relative, localFp) in local {
            guard FilesSyncPolicy.shouldSkipOnSaveScan(relativePath: relative) else { continue }
            if FilesSyncPolicy.shouldNeverSync(relativePath: relative) { continue }
            considered += 1
            let inLedger = ledger[relative] != nil
            let inCloud = cloud[relative] != nil
            let intent = intents[relative]
            if romExclusion.contains(relative) {
                _ = decide(relativePath: relative, local: localFp, cloud: cloudKnown ? cloud[relative] : nil)
                continue
            }
            if !inLedger {
                untracked += 1
            }
            if cloudKnown {
                if decide(relativePath: relative, local: localFp, cloud: cloud[relative]) == .upload, !inCloud {
                    missingOnCloud += 1
                }
            } else if intent == nil, !inLedger {
                _ = decide(relativePath: relative, local: localFp, cloud: nil)
            }
        }
        for (relative, intent) in intents where FilesSyncPolicy.shouldSkipOnSaveScan(relativePath: relative) {
            if local[relative] != nil { continue }
            if FilesSyncPolicy.shouldNeverSync(relativePath: relative) { continue }
            _ = decide(relativePath: relative, local: nil, cloud: cloudKnown ? cloud[relative] : nil)
        }
        Log.debug("[iCloud Sync] catch-up content trees considered=\(considered) untracked=\(untracked) ledgerNotInCloud=\(missingOnCloud) cloudKnown=\(cloudKnown)")
        persistQueuedOps()
        pump()
    }
    
    private func processLocalChange(_ url: URL) async {
        guard isStarted else { return }
        refreshROMExclusion()
        if url.hasDirectoryPath || isDirectory(url) {
            let files = FilesSyncIO.enumerateLocalFiles(root: url)
            Log.debug("[iCloud Sync] local directory change \(url.path) files=\(files.count)")
            for (relative, _) in files {
                enqueueChange(relativePath: relative)
            }
        } else if let relative = FilesSyncPolicy.documentsRelativePath(from: url) {
            Log.debug("[iCloud Sync] local file change \(relative) exists=\(FileManager.default.fileExists(atPath: url.path))")
            enqueueChange(relativePath: relative)
        } else {
            Log.debug("[iCloud Sync] local change skipped (not under Documents): \(url.path)")
        }
    }
    
    private func processLocalRemoval(_ url: URL) async {
        guard isStarted else { return }
        guard let relative = FilesSyncPolicy.documentsRelativePath(from: url) else { return }
        let directory = isDirectory(url) || url.hasDirectoryPath
        // Local file may already be gone; still collect children from the ledger/intents.
        let ledgerHits = FilesSyncIndex.store.files.keys.filter { $0 == relative || $0.hasPrefix(relative + "/") }
        let intentHits = FilesSyncIntentStore.paths(matchingPrefix: relative)
        var paths = Array(Set(ledgerHits).union(intentHits))
        if !paths.contains(relative) {
            paths.append(relative)
        }
        Log.debug("[iCloud Sync] local removal \(relative) directory=\(directory) matching=\(paths.count)")
        for path in paths {
            FilesSyncIntentStore.markDeleted(relativePath: path)
            let isDir = (path == relative && directory)
                || paths.contains { $0 != path && $0.hasPrefix(path + "/") }
            enqueue(FilesSyncOp(relativePath: path, kind: .deleteCloud, tombstoneReason: .deleted, isDirectory: isDir))
        }
        FilesSyncIndex.save()
        persistQueuedOps()
        pump()
    }
    
    private func processExcludeCloudCopies(_ urls: [URL]) async {
        guard isStarted else { return }
        for url in urls {
            guard let relative = FilesSyncPolicy.documentsRelativePath(from: url) else { continue }
            let directory = isDirectory(url) || url.hasDirectoryPath
            if directory {
                let localFiles = FilesSyncIO.enumerateLocalFiles(root: url)
                var paths = Array(localFiles.keys)
                paths.append(contentsOf: FilesSyncIntentStore.paths(matchingPrefix: relative))
                paths.append(relative)
                Log.debug("[iCloud Sync] exclude cloud directory \(relative) files=\(Set(paths).count)")
                for path in Set(paths) {
                    FilesSyncIntentStore.markExcluded(relativePath: path)
                    let isDir = (path == relative && directory)
                        || paths.contains { $0 != path && $0.hasPrefix(path + "/") }
                    enqueue(FilesSyncOp(relativePath: path, kind: .deleteCloud, tombstoneReason: .excluded, isDirectory: isDir))
                }
            } else {
                Log.debug("[iCloud Sync] exclude cloud file \(relative)")
                FilesSyncIntentStore.markExcluded(relativePath: relative)
                enqueue(FilesSyncOp(relativePath: relative, kind: .deleteCloud, tombstoneReason: .excluded, isDirectory: false))
            }
        }
        FilesSyncIndex.save()
        persistQueuedOps()
        pump()
    }
    
    private func performEnsureLocal(_ url: URL) async -> Error? {
        guard let relative = FilesSyncPolicy.documentsRelativePath(from: url) else { return nil }
        refreshROMExclusion()
        if romExclusion.contains(relative) {
            Log.debug("[iCloud Sync] ensureLocal skipped (ROM excluded): \(relative)")
            return NSError(domain: "FilesSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "ROM sync disabled"])
        }
        if let intent = FilesSyncIntentStore.snapshot(relativePath: relative),
           intent.intent == .deleted || intent.intent == .excluded {
            Log.debug("[iCloud Sync] ensureLocal skipped (intent \(intent.intent.debugLabel)): \(relative)")
            return NSError(domain: "FilesSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "ROM sync disabled"])
        }
        if FileManager.default.fileExists(atPath: url.path) {
            Log.debug("[iCloud Sync] ensureLocal already local: \(relative)")
            return nil
        }
        Log.debug("[iCloud Sync] ensureLocal download \(relative)")
        do {
            try await io.download(relativePath: relative, localURL: url)
            if let fingerprint = FilesSyncIndex.fingerprint(for: url, preferHash: false) {
                let generation = FilesSyncIntentStore.snapshot(relativePath: relative)?.generation
                    ?? FilesSyncIndex.appliedGeneration(for: relative)
                FilesSyncIndex.recordSynced(relativePath: relative, fingerprint: fingerprint, generation: generation)
                FilesSyncIndex.save()
            }
            return nil
        } catch {
            Log.debug("[iCloud Sync] ensureLocal failed \(relative): \(error)")
            return error
        }
    }
    
    private func flushCloudInventory() async {
        let inventory: FilesSyncCloudInventory? = withLock {
            let value = pendingInventory
            pendingInventory = nil
            return value
        }
        guard let inventory else {
            Log.debug("[iCloud Sync] cloud inventory coalesced away")
            return
        }
        await handleCloudInventory(inventory)
    }
    
    private func handleCloudInventory(_ inventory: FilesSyncCloudInventory) async {
        let (previous, previousNotDownloaded) = withLock { () -> ([String: FilesSyncFingerprint], Set<String>) in
            let old = latestCloudFiles
            let oldNotDownloaded = notDownloaded
            latestCloudFiles = inventory.files
            notDownloaded = inventory.notDownloaded
            cloudListingReady = true
            return (old, oldNotDownloaded)
        }
        if progress.isBusy || !inventory.uploading.isEmpty || !inventory.downloading.isEmpty {
            publish { progress in
                progress.currentFileName = inventory.uploading.first ?? inventory.downloading.first ?? progress.currentFileName
                progress.bytesTransferred = inventory.bytesTransferred
                progress.bytesTotal = inventory.bytesTotal
            }
        }
        guard isStarted, !withLock({ pausedForGameplay }) else {
            Log.debug("[iCloud Sync] cloud inventory stored, reconcile deferred started=\(isStarted) paused=\(withLock { pausedForGameplay })")
            return
        }
        // Upload percent ticks keep size/mtime the same. Skip a full decide pass.
        if previous == inventory.files, previousNotDownloaded == inventory.notDownloaded {
            Log.debug("[iCloud Sync] cloud inventory progress-only files=\(inventory.files.count)")
            return
        }
        await reconcileCloudDelta(previous: previous, inventory: inventory)
    }
    
    private func reconcileCloudDelta(previous: [String: FilesSyncFingerprint], inventory: FilesSyncCloudInventory) async {
        refreshROMExclusion()
        var changed = Set<String>()
        if previous.isEmpty {
            changed.formUnion(inventory.files.keys)
        } else {
            for (relative, cloud) in inventory.files where previous[relative] != cloud {
                changed.insert(relative)
            }
        }
        var missing = 0
        for relative in previous.keys where inventory.files[relative] == nil {
            changed.insert(relative)
        }
        var decided = 0
        for relative in changed {
            if FilesSyncPolicy.shouldNeverSync(relativePath: relative) { continue }
            let cloud = inventory.files[relative]
            if cloud == nil {
                guard let intent = FilesSyncIntentStore.snapshot(relativePath: relative),
                      intent.intent == .deleted || intent.intent == .excluded,
                      FilesSyncIndex.appliedGeneration(for: relative) < intent.generation else { continue }
            }
            let localURL = FilesSyncPolicy.localURL(relativePath: relative)
            let localExists = FileManager.default.fileExists(atPath: localURL.path)
            if cloud != nil, inventory.notDownloaded.contains(relative), localExists {
                continue
            }
            let local = localExists ? FilesSyncIndex.fingerprint(for: localURL, preferHash: false) : nil
            if cloud == nil { missing += 1 }
            _ = decide(relativePath: relative, local: local, cloud: cloud)
            decided += 1
        }
        Log.debug("[iCloud Sync] cloud delta decided=\(decided) intentGaps=\(missing) changed=\(changed.count) \(queueSummary())")
        persistQueuedOps()
        pump()
    }
    
    private func enqueueChange(relativePath: String) {
        if FilesSyncPolicy.shouldNeverSync(relativePath: relativePath) {
            Log.debug("[iCloud Sync] skip local change (never sync): \(relativePath)")
            return
        }
        if romExclusion.contains(relativePath) {
            Log.debug("[iCloud Sync] skip local change (ROM sync off, leave cloud): \(relativePath)")
            return
        }
        Log.debug("[iCloud Sync] enqueue upload \(relativePath)")
        enqueue(FilesSyncOp(relativePath: relativePath, kind: .upload, tombstoneReason: nil))
        persistQueuedOps()
        pump()
    }
    
    @discardableResult
    private func decide(relativePath: String, local: FilesSyncFingerprint?, cloud: FilesSyncFingerprint?) -> FilesSyncDecideAction {
        let intent = FilesSyncIntentStore.snapshot(relativePath: relativePath)
        let applied = FilesSyncIndex.appliedGeneration(for: relativePath)
        let ledger = FilesSyncIndex.store.files[relativePath]?.fingerprint
        
        // Exclude/delete intents win over "ROM sync off". Turning sync off keeps
        // Drive copies; deleting the game or confirming evict must still remove them.
        if let intent, intent.intent == .excluded {
            if cloud != nil, applied < intent.generation {
                Log.debug("[iCloud Sync] decide \(relativePath) -> deleteCloud (intent excluded gen=\(intent.generation))")
                enqueue(FilesSyncOp(relativePath: relativePath, kind: .deleteCloud, tombstoneReason: .excluded))
                return .deleteCloud
            }
            Log.debug("[iCloud Sync] decide \(relativePath) -> skip (intent excluded gen=\(intent.generation))")
            return .skip
        }
        
        if let intent, intent.intent == .deleted {
            if applied >= intent.generation {
                Log.debug("[iCloud Sync] decide \(relativePath) -> skip (delete gen=\(intent.generation) already applied)")
                return .skip
            }
            if local != nil {
                Log.debug("[iCloud Sync] decide \(relativePath) -> deleteLocal (intent deleted gen=\(intent.generation) applied=\(applied))")
                enqueue(FilesSyncOp(relativePath: relativePath, kind: .deleteLocal, tombstoneReason: .deleted))
                return .deleteLocal
            }
            if cloud != nil {
                Log.debug("[iCloud Sync] decide \(relativePath) -> deleteCloud (intent deleted gen=\(intent.generation))")
                enqueue(FilesSyncOp(relativePath: relativePath, kind: .deleteCloud, tombstoneReason: .deleted))
                return .deleteCloud
            }
            Log.debug("[iCloud Sync] decide \(relativePath) -> skip (delete gen=\(intent.generation), nothing left)")
            FilesSyncIndex.setAppliedGeneration(relativePath, intent.generation)
            return .skip
        }
        
        // Policy off only stops upload/download. Cloud copies stay until the user
        // confirms excludeCloudCopies or deletes the game.
        if romExclusion.contains(relativePath) {
            Log.debug("[iCloud Sync] decide \(relativePath) -> skip (ROM sync off)")
            return .skip
        }
        
        if let intent {
            switch intent.intent {
            case .excluded, .deleted:
                return .skip
            case .present:
                if applied >= intent.generation, local != nil {
                    return compareReplicas(relativePath: relativePath, local: local, cloud: cloud, ledger: ledger, intent: intent)
                }
                if local == nil {
                    Log.debug("[iCloud Sync] decide \(relativePath) -> download (intent present gen=\(intent.generation) applied=\(applied) cloud=\(cloud != nil))")
                    enqueue(FilesSyncOp(relativePath: relativePath, kind: .download, tombstoneReason: nil))
                    return .download
                }
                if cloud == nil {
                    // Newer remote generation: wait for the blob instead of re-uploading our older copy.
                    Log.debug("[iCloud Sync] decide \(relativePath) -> download (wait for present gen=\(intent.generation) blob) applied=\(applied)")
                    enqueue(FilesSyncOp(relativePath: relativePath, kind: .download, tombstoneReason: nil))
                    return .download
                }
                return compareReplicas(relativePath: relativePath, local: local, cloud: cloud, ledger: ledger, intent: intent)
            }
        }
        
        // No CloudKit intent yet: never infer delete from a listing gap.
        if let local, let cloud {
            return compareReplicas(relativePath: relativePath, local: local, cloud: cloud, ledger: ledger, intent: nil)
        }
        if let local, cloud == nil {
            Log.debug("[iCloud Sync] decide \(relativePath) -> upload (local only, no intent) \(describe(local))")
            enqueue(FilesSyncOp(relativePath: relativePath, kind: .upload, tombstoneReason: nil))
            return .upload
        }
        if local == nil, cloud != nil {
            Log.debug("[iCloud Sync] decide \(relativePath) -> skip (cloud only, intent unknown)")
            return .skip
        }
        return .skip
    }
    
    @discardableResult
    private func compareReplicas(relativePath: String,
                                 local: FilesSyncFingerprint?,
                                 cloud: FilesSyncFingerprint?,
                                 ledger: FilesSyncFingerprint?,
                                 intent: FilesSyncIntentSnapshot?) -> FilesSyncDecideAction {
        guard let local, let cloud else { return .skip }
        if let ledger, local.matches(ledger), cloud.matches(ledger) {
            if let intent { FilesSyncIndex.setAppliedGeneration(relativePath, intent.generation) }
            return .skip
        }
        if let ledger, local.matches(ledger), !cloud.matches(ledger) {
            if local.samePayload(cloud) {
                Log.debug("[iCloud Sync] decide \(relativePath) -> skip (iCloud mtime drift) local=\(describe(local)) cloud=\(describe(cloud))")
                if let intent { FilesSyncIndex.setAppliedGeneration(relativePath, intent.generation) }
                return .skip
            }
            if withLock({ notDownloaded.contains(relativePath) }) {
                Log.debug("[iCloud Sync] decide \(relativePath) -> skip (cloud not downloaded yet)")
                return .skip
            }
            Log.debug("[iCloud Sync] decide \(relativePath) -> download (cloud changed) local=\(describe(local)) cloud=\(describe(cloud))")
            enqueue(FilesSyncOp(relativePath: relativePath, kind: .download, tombstoneReason: nil))
            return .download
        }
        if let ledger, cloud.matches(ledger), !local.matches(ledger) {
            Log.debug("[iCloud Sync] decide \(relativePath) -> upload (local changed) local=\(describe(local)) cloud=\(describe(cloud))")
            enqueue(FilesSyncOp(relativePath: relativePath, kind: .upload, tombstoneReason: nil))
            return .upload
        }
        if local.matches(cloud) {
            FilesSyncIndex.recordSynced(relativePath: relativePath, fingerprint: local, generation: intent?.generation)
            return .skip
        }
        if ledger == nil, local.samePayload(cloud) {
            FilesSyncIndex.recordSynced(relativePath: relativePath, fingerprint: local, generation: intent?.generation)
            Log.debug("[iCloud Sync] decide \(relativePath) -> skip (size match, first ledger)")
            return .skip
        }
        if withLock({ notDownloaded.contains(relativePath) }) {
            Log.debug("[iCloud Sync] decide \(relativePath) -> skip (cloud not downloaded yet)")
            return .skip
        }
        let localWins = local.mtime >= cloud.mtime
        Log.debug("[iCloud Sync] decide \(relativePath) -> \(localWins ? "upload" : "download") (conflict) local=\(describe(local)) cloud=\(describe(cloud))")
        enqueue(FilesSyncOp(relativePath: relativePath,
                            kind: localWins ? .upload : .download,
                            tombstoneReason: nil,
                            isConflict: true))
        return localWins ? .upload : .download
    }
    
    private func applyIntentPaths(_ paths: [String]) async {
        refreshROMExclusion()
        let cloud = withLock { latestCloudFiles }
        for relative in Set(paths) {
            if FilesSyncPolicy.shouldNeverSync(relativePath: relative) { continue }
            let localURL = FilesSyncPolicy.localURL(relativePath: relative)
            let localExists = FileManager.default.fileExists(atPath: localURL.path)
            let local = localExists ? FilesSyncIndex.fingerprint(for: localURL, preferHash: false) : nil
            _ = decide(relativePath: relative, local: local, cloud: cloud[relative])
        }
        persistQueuedOps()
        pump()
    }
    
    private func enqueue(_ op: FilesSyncOp) {
        withLock {
            nextOpToken += 1
            var stamped = op
            stamped.token = nextOpToken
            pending[op.relativePath] = stamped
        }
        Log.debug("[iCloud Sync] queue \(op.kind) \(op.relativePath) \(queueSummary())")
    }
    
    private func pump() {
        withLock {
            if drainTask != nil {
                Log.debug("[iCloud Sync] pump: drain already running pending=\(pending.count) inFlight=\(inFlight.count)")
                return
            }
            if pending.isEmpty, inFlight.isEmpty {
                Log.debug("[iCloud Sync] pump: nothing to drain")
                return
            }
            Log.debug("[iCloud Sync] pump: start drain pending=\(pending.count)")
            drainTask = Task.detached { [weak self] in
                await self?.drain()
            }
        }
    }
    
    private func drain() async {
        let generation = withLock { drainGeneration }
        Log.debug("[iCloud Sync] drain begin gen=\(generation) \(queueSummary()) main=\(Thread.isMainThread)")
        while true {
            let state = withLock { (pausedForGameplay, started, drainGeneration) }
            if state.2 != generation {
                Log.debug("[iCloud Sync] drain superseded gen=\(generation)")
                break
            }
            if state.0 {
                withLock { if drainGeneration == generation { drainTask = nil } }
                Log.debug("[iCloud Sync] drain paused for gameplay")
                publish { $0.phase = .paused }
                break
            }
            if !state.1 {
                withLock { if drainGeneration == generation { drainTask = nil } }
                Log.debug("[iCloud Sync] drain stopped")
                break
            }
            let batch: [(key: String, value: FilesSyncOp)]
            let remaining: Int
            (batch, remaining) = withLock {
                guard drainGeneration == generation else { return ([], pending.count) }
                let ready = pending.filter { !inFlight.keys.contains($0.key) }
                let next = Array(ready.prefix(maxConcurrent))
                for item in next {
                    inFlight[item.key] = item.value
                }
                return (next.map { (key: $0.key, value: $0.value) }, pending.count)
            }
            
            if batch.isEmpty {
                let idle = withLock { () -> Bool in
                    guard drainGeneration == generation else { return true }
                    let idle = inFlight.isEmpty && pending.isEmpty
                    if idle { drainTask = nil }
                    return idle
                }
                if idle {
                    Log.debug("[iCloud Sync] drain idle")
                    if withLock({ drainGeneration == generation }) {
                        persistQueuedOps()
                        publish {
                            $0.phase = .idle
                            $0.completedCount = 0
                            $0.totalCount = 0
                            $0.currentFileName = nil
                        }
                    }
                    break
                }
                Log.debug("[iCloud Sync] drain waiting for in-flight \(queueSummary())")
                try? await Task.sleep(nanoseconds: 200_000_000)
                continue
            }
            
            let names = batch.map { "\($0.value.kind):\($0.value.relativePath)" }.joined(separator: ", ")
            Log.debug("[iCloud Sync] drain batch remaining=\(remaining) [\(names)]")
            publish { progress in
                progress.phase = .syncing
                progress.totalCount = remaining
                progress.currentFileName = batch.first?.value.relativePath
            }
            
            var completed: [String: Bool] = [:]
            await withTaskGroup(of: (String, Bool).self) { group in
                for item in batch {
                    group.addTask { [weak self] in
                        let ok = await self?.run(item.value, drainGeneration: generation) ?? true
                        return (item.key, ok)
                    }
                }
                for await result in group {
                    completed[result.0] = result.1
                }
            }
            
            let finished = withLock { () -> Int in
                guard drainGeneration == generation else { return 0 }
                var count = 0
                for item in batch {
                    inFlight[item.key] = nil
                    if completed[item.key] == true, pending[item.key]?.token == item.value.token {
                        pending[item.key] = nil
                        count += 1
                    }
                }
                return count
            }
            Log.debug("[iCloud Sync] drain batch finished=\(finished)/\(batch.count) \(queueSummary())")
            publish { $0.completedCount += finished }
        }
        if withLock({ drainGeneration == generation }) {
            FilesSyncIndex.save()
            persistQueuedOps()
        }
        Log.debug("[iCloud Sync] drain end gen=\(generation) \(queueSummary())")
    }
    
    /// Returns false when the op should stay queued (e.g. paused during gameplay).
    private func run(_ op: FilesSyncOp, drainGeneration session: Int) async -> Bool {
        if withLock({ pausedForGameplay }), op.kind == .upload || op.kind == .download {
            Log.debug("[iCloud Sync] run deferred (gameplay) \(op.kind) \(op.relativePath)")
            return false
        }
        let localURL = FilesSyncPolicy.localURL(relativePath: op.relativePath)
        switch op.kind {
        case .upload:
            guard FileManager.default.fileExists(atPath: localURL.path) else {
                Log.debug("[iCloud Sync] upload missing local \(op.relativePath) retry=\(op.retries)")
                if op.retries < 2 {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    return retryOrDrop(op, drainGeneration: session)
                }
                return true
            }
            do {
                if op.isConflict {
                    await preserveCloudLoser(op: op, localURL: localURL)
                }
                try await io.upload(localURL: localURL, relativePath: op.relativePath)
                if let fingerprint = FilesSyncIndex.fingerprint(for: localURL, preferHash: false) {
                    let generation = FilesSyncIntentStore.markPresent(relativePath: op.relativePath, size: fingerprint.size)
                    FilesSyncIndex.recordSynced(relativePath: op.relativePath, fingerprint: fingerprint, generation: generation)
                }
                Log.debug("[iCloud Sync] Uploaded \(op.relativePath)")
            } catch {
                Log.debug("[iCloud Sync] Upload failed \(op.relativePath) retry=\(op.retries): \(error)")
                try? await Task.sleep(nanoseconds: 400_000_000)
                return retryOrDrop(op, drainGeneration: session)
            }
        case .download:
            do {
                let cloud = withLock { latestCloudFiles[op.relativePath] }
                if FileManager.default.fileExists(atPath: localURL.path),
                   let local = FilesSyncIndex.fingerprint(for: localURL, preferHash: false),
                   let cloud,
                   !local.matches(cloud) || op.isConflict {
                    preserveLocalLoser(localURL: localURL, relativePath: op.relativePath)
                }
                try await io.download(relativePath: op.relativePath, localURL: localURL)
                if let fingerprint = FilesSyncIndex.fingerprint(for: localURL, preferHash: false) {
                    let generation = FilesSyncIntentStore.snapshot(relativePath: op.relativePath)?.generation
                        ?? FilesSyncIndex.appliedGeneration(for: op.relativePath)
                    FilesSyncIndex.recordSynced(relativePath: op.relativePath, fingerprint: fingerprint, generation: generation)
                }
                Log.debug("[iCloud Sync] Downloaded \(op.relativePath)")
            } catch {
                let localExists = FileManager.default.fileExists(atPath: localURL.path)
                let uploadInstead = withLock {
                    cloudListingReady
                        && latestCloudFiles[op.relativePath] == nil
                        && !notDownloaded.contains(op.relativePath)
                }
                if localExists, uploadInstead {
                    Log.debug("[iCloud Sync] download missing on cloud, upload local instead \(op.relativePath)")
                    enqueue(FilesSyncOp(relativePath: op.relativePath, kind: .upload, tombstoneReason: nil, isConflict: op.isConflict))
                    return true
                }
                Log.debug("[iCloud Sync] Download failed \(op.relativePath) retry=\(op.retries): \(error)")
                try? await Task.sleep(nanoseconds: 400_000_000)
                return retryOrDrop(op, drainGeneration: session)
            }
        case .deleteCloud:
            do {
                try await io.removeCloudItem(relativePath: op.relativePath, isDirectory: op.isDirectory)
                if op.tombstoneReason == .deleted {
                    FilesSyncIndex.removeFile(op.relativePath)
                }
                if let intent = FilesSyncIntentStore.snapshot(relativePath: op.relativePath) {
                    FilesSyncIndex.setAppliedGeneration(op.relativePath, intent.generation)
                }
                Log.debug("[iCloud Sync] Deleted cloud \(op.relativePath)")
            } catch {
                Log.debug("[iCloud Sync] Delete cloud failed \(op.relativePath) retry=\(op.retries): \(error)")
                try? await Task.sleep(nanoseconds: 400_000_000)
                return retryOrDrop(op, drainGeneration: session)
            }
        case .deleteLocal:
            try? FileManager.safeRemoveItem(at: localURL)
            FilesSyncIndex.removeFile(op.relativePath)
            if let intent = FilesSyncIntentStore.snapshot(relativePath: op.relativePath) {
                FilesSyncIndex.setAppliedGeneration(op.relativePath, intent.generation)
            }
            Log.debug("[iCloud Sync] Deleted local \(op.relativePath)")
        }
        return true
    }
    
    private func retryOrDrop(_ op: FilesSyncOp, drainGeneration session: Int) -> Bool {
        let keepQueued = withLock { () -> Bool in
            guard drainGeneration == session else { return false }
            if let current = pending[op.relativePath], current.token != op.token {
                return true
            }
            if op.retries < maxRetries {
                var retry = op
                retry.retries += 1
                pending[op.relativePath] = retry
                return true
            }
            var stored = op
            stored.retries = 0
            if pending[op.relativePath]?.token == op.token {
                pending[op.relativePath] = nil
            }
            deferred[op.relativePath] = stored
            return false
        }
        if keepQueued {
            if withLock({ pending[op.relativePath]?.token == op.token }) {
                Log.debug("[iCloud Sync] will retry \(op.kind) \(op.relativePath) (\(op.retries + 1)/\(maxRetries))")
            }
            return false
        }
        if withLock({ drainGeneration == session && deferred[op.relativePath] != nil }) {
            persistQueuedOps()
            Log.debug("[iCloud Sync] deferred \(op.kind) \(op.relativePath) after \(op.retries) retries")
        }
        return true
    }
    
    private func loadDeferredFromDisk() {
        let ops = FilesSyncIndex.loadPending()
        guard !ops.isEmpty else { return }
        withLock {
            for (path, op) in ops {
                if pending[path] == nil {
                    deferred[path] = op
                }
            }
        }
        Log.debug("[iCloud Sync] loaded deferred from disk count=\(ops.count) \(queueSummary())")
    }
    
    private func flushDeferredOps(reason: String) {
        let ops: [FilesSyncOp] = withLock {
            let values = Array(deferred.values)
            deferred.removeAll()
            return values
        }
        guard !ops.isEmpty else {
            Log.debug("[iCloud Sync] flush deferred skipped (\(reason)): empty")
            return
        }
        Log.debug("[iCloud Sync] flush deferred (\(reason)) count=\(ops.count)")
        for var op in ops {
            op.retries = 0
            enqueue(op)
        }
        persistQueuedOps()
    }
    
    private func persistQueuedOps() {
        let snapshot: [String: FilesSyncOp] = withLock {
            var all = deferred
            for (path, op) in pending {
                all[path] = op
            }
            return all
        }
        FilesSyncIndex.savePending(snapshot)
    }
    
    private func waitUntilIdle() async {
        while isStarted {
            if withLock({ pausedForGameplay }) {
                Log.debug("[iCloud Sync] waitUntilIdle stopped (gameplay paused)")
                return
            }
            let busy = withLock { drainTask != nil || !pending.isEmpty || !inFlight.isEmpty }
            if !busy { return }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }
    
    private func preserveLocalLoser(localURL: URL, relativePath: String) {
        if FilesSyncPolicy.isImmutableResource(relativePath: relativePath) {
            let sibling = FilesSyncIndex.conflictSiblingURL(for: localURL)
            try? FileManager.safeCopyItem(at: localURL, to: sibling, shouldReplace: true)
            Log.debug("[iCloud Sync] Kept local conflict copy: \(sibling.lastPathComponent)")
        } else {
            FilesSyncIndex.backupLoser(localURL: localURL, relativePath: relativePath)
        }
    }
    
    private func preserveCloudLoser(op: FilesSyncOp, localURL: URL) async {
        if FilesSyncPolicy.isImmutableResource(relativePath: op.relativePath) {
            let sibling = FilesSyncIndex.conflictSiblingURL(for: localURL)
            try? await io.download(relativePath: op.relativePath, localURL: sibling)
            Log.debug("[iCloud Sync] Kept cloud conflict copy: \(sibling.lastPathComponent)")
        } else {
            try? FileManager.default.createDirectory(atPath: R.Path.FilesSyncConflicts, withIntermediateDirectories: true)
            let dest = URL(fileURLWithPath: R.Path.FilesSyncConflicts)
                .appendingPathComponent("cloud_\(op.relativePath.replacingOccurrences(of: "/", with: "_"))")
            try? await io.download(relativePath: op.relativePath, localURL: dest)
        }
    }
    
    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    private func refreshROMExclusion() {
        romExclusion = FilesSyncPolicy.romExclusionSnapshot()
        Log.debug("[iCloud Sync] ROM exclusion files=\(romExclusion.files.count) prefixes=\(romExclusion.prefixes.count)")
        if !romExclusion.files.isEmpty {
            Log.debug("[iCloud Sync] ROM excluded files: \(romExclusion.files.sorted().prefix(10).joined(separator: ", "))")
        }
    }
    
    private func enqueueWork(_ name: String, _ body: @escaping () async -> Void) {
        lock.lock()
        let previous = workTail
        let generation = workGeneration
        let next = Task.detached(priority: .utility) { [weak self] in
            await previous.value
            guard let self, self.withLock({ self.started && self.workGeneration == generation }) else { return }
            Log.debug("[iCloud Sync] work begin: \(name) main=\(Thread.isMainThread)")
            await body()
            Log.debug("[iCloud Sync] work end: \(name)")
        }
        workTail = next
        lock.unlock()
    }
    
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
    
    private func queueSummary() -> String {
        withLock {
            "pending=\(pending.count) deferred=\(deferred.count) inFlight=\(inFlight.count) draining=\(drainTask != nil)"
        }
    }
    
    private func describe(_ fingerprint: FilesSyncFingerprint?) -> String {
        guard let fingerprint else { return "nil" }
        return "size=\(fingerprint.size) mtime=\(Int(fingerprint.mtime))"
    }
    
    private func publish(_ update: (inout FilesSyncProgress) -> Void) {
        var next = progress
        update(&next)
        let phaseChanged = next.phase != progress.phase
        if phaseChanged || next.currentFileName != progress.currentFileName || next.totalCount != progress.totalCount {
            Log.debug("[iCloud Sync] progress phase=\(next.phase.rawValue) file=\(next.currentFileName ?? "-") completed=\(next.completedCount)/\(next.totalCount)")
        }
        progress = next
        let shouldPost = withLock { () -> Bool in
            let now = Date().timeIntervalSince1970
            if phaseChanged || next.phase == .idle || now - lastProgressPostedAt >= 0.25 {
                lastProgressPostedAt = now
                return true
            }
            return false
        }
        guard shouldPost else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: R.NotificationName.iCloudDriveSyncChange, object: next)
        }
    }
}
