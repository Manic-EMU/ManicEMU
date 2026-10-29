//
//  BitBopKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/27.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import CryptoKit

struct BitBopKit {
    /// Entitlement id shared with BitBop. Distinct from `R.DefaultKey.AppGroupName`, which only keys UserDefaults.
    private static let appGroupIdentifier = "group.aoshuang.manicemu"
    private static let importDirectoryName = "Import"
    private static let launchURL = URL(string: "bitbop://import")!
    /// Opens BitBop without starting an import. `bitbop://library` is ignored by BitBop's handoff route.
    private static let openURL = URL(string: "bitbop://library")!
    private static let stateLock = NSLock()
    private static var supportCache: CachedSupport?
    private static var libraryCache: CachedLibrary?
    private static var digestCache: [String: CachedDigest] = [:]
    private static let stagingQueue = DispatchQueue(label: "com.aoshuang.manicemu.bitbop", qos: .userInitiated)
    /// Touched only on the main thread, so a second tap cannot replace Import while the first copy is in flight.
    private static var isSending = false
    
    private enum StageError: Error {
        case missingContainer
        case noRom
    }
    
    private enum HandoffChoice {
        case unsupported
        case send([(source: URL, fileName: String)])
    }
    
    /// App Store builds copy into the shared Import folder, then open BitBop. Sideload builds have no App Group, so the user picks BitBop in the share sheet. Opens the App Store when BitBop cannot be launched.
    static func sendToBitBop(games: [Game], in scene: UIWindowScene?) {
        let supported = games.filter { $0.gameType.supportBitBop }
        guard !supported.isEmpty else { return }
        
        guard UIApplication.shared.canOpenURL(launchURL) else {
            UIApplication.shared.open(R.URLs.BitBopStoreUrl)
            return
        }
        
        // Capture paths and names on the caller thread. Realm objects must not be read from the staging queue.
        let roms = supported.compactMap { game -> (source: URL, fileName: String, gameType: GameType)? in
            let url = game.romUrl
            guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
            let fileName = game.fileName
            guard !fileName.isEmpty else { return nil }
            return (url, fileName, game.gameType)
        }
        guard !roms.isEmpty else {
            UIView.makeToast(message: R.string.localizable.bitBopSendFailed())
            return
        }
        guard !isSending else { return }
        isSending = true
        UIView.makeLoading()
        
        stagingQueue.async {
            switch handoffChoice(for: roms) {
            case .unsupported:
                DispatchQueue.main.async {
                    isSending = false
                    UIView.hideLoading {
                        UIView.makeToast(message: R.string.localizable.bitBopTracksUnavailable())
                    }
                }
            case .send(let ready):
#if SIDE_LOAD
                let readyPaths = Set(ready.map(\.source.path))
                DispatchQueue.main.async {
                    isSending = false
                    UIView.hideLoading {
                        let shareable = supported.filter { readyPaths.contains($0.romUrl.path) }
                        ShareManager.shareFiles(games: shareable, shareFileType: .rom, in: scene)
                    }
                }
#else
                let result = Result { try stageRoms(ready) }
                DispatchQueue.main.async {
                    isSending = false
                    UIView.hideLoading {
                        switch result {
                        case .success:
                            UIApplication.shared.open(launchURL, options: [:]) { success in
                                guard !success else { return }
                                DispatchQueue.main.async {
                                    UIApplication.shared.open(R.URLs.BitBopStoreUrl)
                                }
                            }
                        case .failure(let error):
                            Log.error("BitBop import staging failed: \(error)")
                            UIView.makeToast(message: R.string.localizable.bitBopSendFailed())
                        }
                    }
                }
#endif
            }
        }
    }
    
    /// GB, GBC, and GBA can still be scanned without a catalog hit. Other platforms need `support.bbix`; a missing file falls back to sending.
    private static func handoffChoice(for roms: [(source: URL, fileName: String, gameType: GameType)]) -> HandoffChoice {
#if SIDE_LOAD
        // Sideload builds cannot read the App Group indexes. Treat them as missing and share every captured ROM.
        return .send(roms.map { ($0.source, $0.fileName) })
#else
        let needsCatalog = roms.contains { !canScanWithoutCatalog($0.gameType) }
        let catalog = needsCatalog ? supportTable() : nil
        if needsCatalog && catalog == nil {
            return .send(roms.map { ($0.source, $0.fileName) })
        }
        var ready: [(source: URL, fileName: String)] = []
        for rom in roms {
            if canScanWithoutCatalog(rom.gameType) {
                ready.append((rom.source, rom.fileName))
                continue
            }
            guard let catalog, let digest = fileDigest(at: rom.source), catalog.contains(digest) else { continue }
            ready.append((rom.source, rom.fileName))
        }
        return ready.isEmpty ? .unsupported : .send(ready)
#endif
    }
    
    private static func canScanWithoutCatalog(_ gameType: GameType) -> Bool {
        gameType == .gb || gameType == .gbc || gameType == .gba
    }
    
    /// Replaces Import so BitBop receives only this selection.
    /// Destination name is `game.fileName`. A numeric suffix is added only when that name is already used in this batch.
    private static func stageRoms(_ roms: [(source: URL, fileName: String)]) throws {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw StageError.missingContainer
        }
        let importDirectory = container.appendingPathComponent(importDirectoryName, isDirectory: true)
        if FileManager.default.fileExists(atPath: importDirectory.path) {
            try FileManager.safeRemoveItem(at: importDirectory)
        }
        try FileManager.default.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        
        var usedNames = Set<String>()
        var copied = 0
        for rom in roms {
            let name = uniqueFileName(rom.fileName, usedNames: &usedNames)
            let destination = importDirectory.appendingPathComponent(name)
            try FileManager.safeCopyItem(at: rom.source, to: destination, shouldReplace: true)
            copied += 1
        }
        guard copied > 0 else { throw StageError.noRom }
    }
    
    private static func uniqueFileName(_ preferred: String, usedNames: inout Set<String>) -> String {
        if !usedNames.contains(preferred) {
            usedNames.insert(preferred)
            return preferred
        }
        let fileURL = URL(fileURLWithPath: preferred)
        let base = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension
        var index = 2
        var name = preferred
        repeat {
            name = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            index += 1
        } while usedNames.contains(name)
        usedNames.insert(name)
        return name
    }
    
    /// What the game-info cover button should do. `supportBitBop` stays a platform check; this reads the shared indexes for one ROM.
    enum CoverOffer {
        case hidden
        /// `scansCartridge` is a GB, GBC, or GBA revision that is absent from a readable support table.
        case send(scansCartridge: Bool)
        case open(LibraryAlbum)
        
        var showsButton: Bool {
            if case .hidden = self { return false }
            return true
        }
    }
    
    struct LibraryAlbum {
        var title: String
        var artist: String
        var system: String
        var hasSoundtrack: Bool
        var trackTitles: [String]
    }
    
    /// `canOpenURL` must run on the main thread. Both launch URLs share the `bitbop` scheme.
    static var isBitBopInstalled: Bool {
        UIApplication.shared.canOpenURL(openURL)
    }
    
    /// Platform gate first. Sideload builds and a missing BitBop install skip both index files.
    static func prepareCoverOffer(gameType: GameType, romURL: URL, bitbopInstalled: Bool) -> CoverOffer {
        guard gameType.supportBitBop else { return .hidden }
#if SIDE_LOAD
        _ = bitbopInstalled
        return .send(scansCartridge: false)
#else
        guard bitbopInstalled else { return .send(scansCartridge: false) }
        let digest = fileDigest(at: romURL)
        if let digest, let album = libraryIndex()?.albums[digest] { return .open(album) }
        if let support = supportTable(), let digest {
            let hit = support.contains(digest)
            let canScanWithoutAHit = gameType == .gb || gameType == .gbc || gameType == .gba
            if !hit && !canScanWithoutAHit { return .hidden }
            return .send(scansCartridge: !hit && canScanWithoutAHit)
        }
        return .send(scansCartridge: false)
#endif
    }
    
    static func presentCoverOffer(_ offer: CoverOffer, for game: Game, in scene: UIWindowScene?) {
        switch offer {
        case .hidden:
            return
        case .send(let scansCartridge):
            UIView.makeAlert(title: R.string.localizable.bitBopListenTitle(),
                             detail: scansCartridge ? R.string.localizable.bitBopScanRom() : R.string.localizable.bitBopParseRom(),
                             detailAlignment: .left,
                             cancelTitle: R.string.localizable.listenWithBitBop(),
                             cancelTitleColor: R.Color.Red,
                             cancelAction: { sendToBitBop(games: [game], in: scene) })
        case .open(let album):
            UIView.makeAlert(title: R.string.localizable.bitBopListenTitle(),
                             detail: albumDetail(album, fallbackTitle: game.displayName),
                             detailAlignment: .left,
                             cancelTitle: R.string.localizable.listenWithBitBop(),
                             cancelTitleColor: R.Color.Red,
                             cancelAction: { openBitBop() })
        }
    }
    
    /// Brings BitBop forward. Does not copy a ROM and does not open `bitbop://import`.
    static func openBitBop() {
        guard UIApplication.shared.canOpenURL(openURL) else {
            UIApplication.shared.open(R.URLs.BitBopStoreUrl)
            return
        }
        UIApplication.shared.open(openURL, options: [:]) { success in
            guard !success else { return }
            DispatchQueue.main.async {
                UIApplication.shared.open(R.URLs.BitBopStoreUrl)
            }
        }
    }
    
    private static func albumDetail(_ album: LibraryAlbum, fallbackTitle: String) -> String {
        let title = album.title.isEmpty ? fallbackTitle : album.title
        guard album.hasSoundtrack else {
            return R.string.localizable.bitBopAlbumQuiet(title)
        }
        var lines: [String] = []
        if !album.artist.isEmpty { lines.append(album.artist) }
        if !album.system.isEmpty { lines.append(album.system) }
        if !album.trackTitles.isEmpty {
            lines.append(R.string.localizable.bitBopTrackCount(album.trackTitles.count))
        }
        var detail = R.string.localizable.bitBopAlbumReady(title)
        if !lines.isEmpty {
            detail += "\n\n" + lines.joined(separator: "\n")
        }
        // Match the list punctuation to the language of the preview sentence.
        let separator = (Bundle.main.preferredLocalizations.first ?? "").hasPrefix("zh") ? "、" : ", "
        let preview = album.trackTitles.prefix(3).filter { !$0.isEmpty }.joined(separator: separator)
        if !preview.isEmpty {
            detail += "\n\n" + R.string.localizable.bitBopAlbumTrackPreview(preview)
        }
        return detail
    }
    
    private static func fileURL(_ name: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("BitBop", isDirectory: true)
            .appendingPathComponent(name)
    }
    
    private static func supportTable() -> SupportTable? {
        guard let url = fileURL("support.bbix"), let stamp = fileStamp(of: url) else { return nil }
        if let cached = locked({ supportCache }),
           cached.stamp == stamp,
           cached.generation == headerGeneration(of: url),
           cached.appVersion == headerAppVersion(of: url) {
            return cached.table
        }
        guard let data = try? Data(contentsOf: url), let table = SupportTable(data: data) else {
            return locked { supportCache?.table }
        }
        locked {
            supportCache = CachedSupport(stamp: stamp, generation: table.generation, appVersion: table.appVersion, table: table)
        }
        return table
    }
    
    private static func libraryIndex() -> LibraryIndex? {
        guard let url = fileURL("library.bbix"), let stamp = fileStamp(of: url) else { return nil }
        if let cached = locked({ libraryCache }),
           cached.stamp == stamp,
           cached.generation == headerGeneration(of: url) {
            return cached.index
        }
        guard let data = try? Data(contentsOf: url), let index = LibraryIndex(data: data) else {
            return locked { libraryCache?.index }
        }
        locked {
            libraryCache = CachedLibrary(stamp: stamp, generation: index.generation, index: index)
        }
        return index
    }
    
    /// Whole-file MD5, cached by path, size, and modification time. This is the expensive part, not parsing the index.
    private static func fileDigest(at url: URL) -> Data? {
        guard url.isFileURL else { return nil }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date else { return nil }
        let size: UInt64
        if let number = attributes[.size] as? NSNumber {
            size = number.uint64Value
        } else if let value = attributes[.size] as? UInt64 {
            size = value
        } else {
            return nil
        }
        if let cached = locked({ digestCache[url.path] }), cached.size == size, cached.modified == modified {
            return cached.digest
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = Insecure.MD5()
        while true {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let digest = Data(hasher.finalize())
        locked { digestCache[url.path] = CachedDigest(size: size, modified: modified, digest: digest) }
        return digest
    }
    
    private static func fileStamp(of url: URL) -> FileStamp? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
              values.isRegularFile == true,
              let size = values.fileSize,
              let modified = values.contentModificationDate else { return nil }
        return FileStamp(size: size, modified: modified.timeIntervalSince1970)
    }
    
    private static func headerGeneration(of url: URL) -> UInt32? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 16), header.count >= 16 else { return nil }
        return Cursor(data: header).uint32(at: 12)
    }
    
    private static func headerAppVersion(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 64), header.count >= 64 else { return nil }
        return Cursor(data: header).appVersion(at: 16, length: 48)
    }
    
    private static func locked<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }
}

private struct FileStamp: Equatable {
    var size: Int
    var modified: TimeInterval
}

private struct CachedDigest {
    var size: UInt64
    var modified: Date
    var digest: Data
}

private struct CachedSupport {
    var stamp: FileStamp
    var generation: UInt32
    var appVersion: String
    var table: SupportTable
}

private struct CachedLibrary {
    var stamp: FileStamp
    var generation: UInt32
    var index: LibraryIndex
}

private struct SupportTable {
    var generation: UInt32
    var appVersion: String
    var hashes: Data
    
    init?(data: Data) {
        let cursor = Cursor(data: data)
        guard data.count >= 64,
              cursor.ascii(at: 0, equals: "BBIX"),
              cursor.uint16(at: 4) == UInt16(2),
              cursor.uint16(at: 6) == UInt16(64),
              let countValue = cursor.uint32(at: 8),
              let generation = cursor.uint32(at: 12) else { return nil }
        let count = Int(countValue)
        guard count >= 1, data.count == 64 + count * 16 else { return nil }
        self.generation = generation
        appVersion = cursor.appVersion(at: 16, length: 48)
        hashes = data.subdata(in: 64..<data.count)
        guard Self.isStrictlySorted(hashes, count: count) else { return nil }
    }
    
    func contains(_ digest: Data) -> Bool {
        guard digest.count == 16 else { return false }
        let count = hashes.count / 16
        return digest.withUnsafeBytes { digestBytes in
            hashes.withUnsafeBytes { hashBytes in
                guard let digestBase = digestBytes.bindMemory(to: UInt8.self).baseAddress,
                      let hashBase = hashBytes.bindMemory(to: UInt8.self).baseAddress else { return false }
                var lo = 0
                var hi = count
                while lo < hi {
                    let mid = (lo + hi) / 2
                    let compared = memcmp(hashBase + mid * 16, digestBase, 16)
                    if compared == 0 { return true }
                    if compared < 0 { lo = mid + 1 } else { hi = mid }
                }
                return false
            }
        }
    }
    
    private static func isStrictlySorted(_ hashes: Data, count: Int) -> Bool {
        guard count > 1 else { return count == 1 }
        return hashes.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            for index in 1..<count {
                if memcmp(base + (index - 1) * 16, base + index * 16, 16) >= 0 { return false }
            }
            return true
        }
    }
}

private struct LibraryIndex {
    var generation: UInt32
    var albums: [Data: BitBopKit.LibraryAlbum]
    
    init?(data: Data) {
        var cursor = Cursor(data: data)
        guard data.count >= 32,
              cursor.ascii(at: 0, equals: "BBLB"),
              cursor.uint16(at: 4) == UInt16(1),
              cursor.uint16(at: 6) == UInt16(32),
              let countValue = cursor.uint32(at: 8),
              let generation = cursor.uint32(at: 12),
              let payloadValue = cursor.uint32(at: 16) else { return nil }
        let count = Int(countValue)
        self.generation = generation
        let payloadBytes = Int(payloadValue)
        guard data.count == 32 + payloadBytes else { return nil }
        cursor.index = 32
        var albums: [Data: BitBopKit.LibraryAlbum] = [:]
        for _ in 0..<count {
            guard let record = cursor.album() else { return nil }
            albums[record.md5] = record.album
        }
        guard cursor.index == data.count else { return nil }
        self.albums = albums
    }
}

private struct Cursor {
    let data: Data
    var index = 0
    
    func ascii(at offset: Int, equals text: String) -> Bool {
        guard let bytes = bytes(at: offset, count: text.utf8.count) else { return false }
        return bytes == Data(text.utf8)
    }
    
    func uint16(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= data.count else { return nil }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    
    func uint32(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        return UInt32(data[offset])
        | (UInt32(data[offset + 1]) << 8)
        | (UInt32(data[offset + 2]) << 16)
        | (UInt32(data[offset + 3]) << 24)
    }
    
    func appVersion(at offset: Int, length: Int) -> String {
        guard let bytes = bytes(at: offset, count: length) else { return "" }
        let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
        return String(data: bytes.prefix(upTo: end), encoding: .utf8) ?? ""
    }
    
    mutating func album() -> (md5: Data, album: BitBopKit.LibraryAlbum)? {
        guard let md5 = take(16),
              let flags = take(1)?.first,
              take(1) != nil,
              let trackCountBytes = take(2),
              let title = takeString(),
              let artist = takeString(),
              let system = takeString() else { return nil }
        let trackCount = Int(UInt16(trackCountBytes[0]) | (UInt16(trackCountBytes[1]) << 8))
        var titles: [String] = []
        titles.reserveCapacity(trackCount)
        for _ in 0..<trackCount {
            guard take(2) != nil, take(4) != nil, take(1) != nil, let trackTitle = takeString() else { return nil }
            titles.append(trackTitle)
        }
        return (md5, .init(title: title, artist: artist, system: system, hasSoundtrack: flags & 1 == 1, trackTitles: titles))
    }
    
    private mutating func takeString() -> String? {
        guard let lengthBytes = take(2) else { return nil }
        let length = Int(UInt16(lengthBytes[0]) | (UInt16(lengthBytes[1]) << 8))
        guard let bytes = take(length) else { return nil }
        return String(data: bytes, encoding: .utf8) ?? ""
    }
    
    private mutating func take(_ count: Int) -> Data? {
        guard let bytes = bytes(at: index, count: count) else { return nil }
        index += count
        return bytes
    }
    
    private func bytes(at offset: Int, count: Int) -> Data? {
        guard offset >= 0, count >= 0, offset + count <= data.count else { return nil }
        return data.subdata(in: offset..<(offset + count))
    }
}
