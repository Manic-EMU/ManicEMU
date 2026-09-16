//
//  FilesSyncPolicy.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation
import CoreFoundation
import RealmSwift

struct FilesSyncROMExclusion {
    var files: Set<String> = []
    var prefixes: Set<String> = []
    /// Every game's ROM paths, regardless of their sync flag. Lets ROM-only transfer
    /// limits apply without touching saves, skins and other small data.
    var romFiles: Set<String> = []
    var romPrefixes: Set<String> = []
    
    /// ROM sync is off for this path, so uploads and downloads are skipped.
    func contains(_ relativePath: String) -> Bool {
        Self.matches(relativePath, files: files, prefixes: prefixes)
    }
    
    /// The path belongs to a game's ROM payload rather than to small app data.
    func isROM(_ relativePath: String) -> Bool {
        if FilesSyncPolicy.isROMContentTree(relativePath: relativePath) { return true }
        if FilesSyncPolicy.isInstalled3DSContent(relativePath: relativePath) { return true }
        return Self.matches(relativePath, files: romFiles, prefixes: romPrefixes)
    }
    
    private static func matches(_ relativePath: String, files: Set<String>, prefixes: Set<String>) -> Bool {
        if files.contains(relativePath) { return true }
        for prefix in prefixes {
            if relativePath == prefix || relativePath.hasPrefix(prefix + "/") {
                return true
            }
        }
        return false
    }
}

/// ROM-only transfer limits, snapshotted so the engine avoids per-path Realm reads.
struct FilesSyncROMTransferLimits {
    var wifiOnly: Bool = false
    var sizeLimit: Int64 = 0
    
    /// ROM exceeds the configured ceiling, so it must not reach iCloud Drive.
    func exceedsSize(_ bytes: Int64) -> Bool {
        sizeLimit > 0 && bytes > sizeLimit
    }
}

enum FilesSyncPolicy {
    private static let neverSyncPrefixes = [
        "wpkdata",
        "SYSTEM/CACHE",
        ".manic-sync",
        "cream_assets",
        "IceCream",
        "IceCreamAssets",
        "cream"
    ]
    
    static func documentsRelativePath(from url: URL) -> String? {
        documentsRelativePath(from: url.path)
    }
    
    static func documentsRelativePath(from path: String) -> String? {
        let document = R.Path.Document
        if path.hasPrefix(document) {
            var relative = String(path.dropFirst(document.count))
            if relative.hasPrefix("/") {
                relative.removeFirst()
            }
            return relative.isEmpty ? nil : relative
        }
        if let range = path.range(of: "/Documents/") {
            return String(path[range.upperBound...])
        }
        return nil
    }
    
    static func localURL(relativePath: String) -> URL {
        URL(fileURLWithPath: R.Path.Document.appendingPathComponent(relativePath))
    }
    
    static func cloudRootPath(relativePath: String) -> String {
        "Documents/\(relativePath)"
    }
    
    static func shouldNeverSync(relativePath: String) -> Bool {
        let last = (relativePath as NSString).lastPathComponent
        if last.hasPrefix(".") {
            return true
        }
        for prefix in neverSyncPrefixes {
            if relativePath == prefix || relativePath.hasPrefix(prefix + "/") {
                return true
            }
        }
        return false
    }
    
    static func isROMContentTree(relativePath: String) -> Bool {
        relativePath == "Datas"
            || relativePath.hasPrefix("Datas/")
            || relativePath == "PPSSPP/PSP/GAME"
            || relativePath.hasPrefix("PPSSPP/PSP/GAME/")
    }
    
    static func isInstalled3DSContent(relativePath: String) -> Bool {
        relativePath.contains("/title/") && (relativePath.contains("/content/") || relativePath.hasSuffix("/content"))
    }
    
    static func isImmutableResource(relativePath: String) -> Bool {
        isROMContentTree(relativePath: relativePath) || relativePath == "BIOS" || relativePath.hasPrefix("BIOS/")
    }
    
    static func shouldSkipOnSaveScan(relativePath: String) -> Bool {
        isROMContentTree(relativePath: relativePath) || isInstalled3DSContent(relativePath: relativePath)
    }
    
    static func configurableROMGameTypes() -> [GameType] {
        System.allGameTypes.filter { $0 != .symbian && !$0.externalType }
    }
    
    /// Settings for the calling thread. `Settings.defalut` is confined to the thread that first loaded it.
    private static func threadLocalSettings() -> Settings? {
        Database.realm.object(ofType: Settings.self, forPrimaryKey: Settings.defaultName)
    }
    
    /// iCloud Drive file sync is on and the user can use it.
    static var isDriveSyncAvailable: Bool {
#if SIDE_LOAD
        return false
#else
        return Settings.iCloudSyncEnableValue && PurchaseManager.isMember
#endif
    }
    
    static func isPlatformROMSyncEnabled(_ gameType: GameType) -> Bool {
#if SIDE_LOAD
        return false
#else
        if gameType == .unknown || gameType == .notSupport { return false }
        if gameType == .symbian { return true }
        let key = gameType.localizedShortName
        guard let raw = threadLocalSettings()?.getExtra(key: ExtraKey.iCloudSyncROMPlatforms.rawValue) else {
            return true
        }
        if let dict = raw as? [String: Bool] {
            return dict[key] ?? true
        }
        if let dict = raw as? [String: Any] {
            if let value = dict[key] as? Bool { return value }
            if let number = dict[key] as? NSNumber { return number.boolValue }
        }
        return true
#endif
    }
    
    static func setPlatformROMSyncEnabled(_ gameType: GameType, enabled: Bool) {
#if SIDE_LOAD
        return
#else
        guard let settings = threadLocalSettings() else { return }
        var map: [String: Bool] = [:]
        if let raw = settings.getExtra(key: ExtraKey.iCloudSyncROMPlatforms.rawValue) as? [String: Bool] {
            map = raw
        } else if let raw = settings.getExtra(key: ExtraKey.iCloudSyncROMPlatforms.rawValue) as? [String: Any] {
            for (key, value) in raw {
                if let flag = value as? Bool {
                    map[key] = flag
                } else if let number = value as? NSNumber {
                    map[key] = number.boolValue
                }
            }
        }
        map[gameType.localizedShortName] = enabled
        settings.updateExtra(key: ExtraKey.iCloudSyncROMPlatforms.rawValue, value: map)
#endif
    }
    
    static func shouldSyncROM(_ game: Game) -> Bool {
#if SIDE_LOAD
        return false
#else
        if game.gameType == .unknown || game.gameType == .notSupport { return false }
        if game.isUrlGame { return false }
        if game.gameType == .symbian { return true }
        if game.isAzaharArticBase { return false }
        if let explicit = explicitROMSyncFlag(game) {
            return explicit
        }
        return isPlatformROMSyncEnabled(game.gameType)
#endif
    }
    
    static func explicitROMSyncFlag(_ game: Game) -> Bool? {
        if let explicit = game.getExtraBool(key: ExtraKey.iCloudSyncROM.rawValue) {
            return explicit
        }
        if let number = game.getExtra(key: ExtraKey.iCloudSyncROM.rawValue) as? NSNumber {
            return number.boolValue
        }
        return nil
    }
    
    static func setGameROMSyncEnabled(_ game: Game, enabled: Bool) {
        if let extras = game.extras,
           let data = Game.updateExtra(extras: extras, key: ExtraKey.iCloudSyncROM.rawValue, value: enabled) {
            game.extras = data
        } else {
            game.extras = [ExtraKey.iCloudSyncROM.rawValue: enabled].jsonData()
        }
    }
    
    static func applyDefaultROMSyncFlag(to game: Game) {
        setGameROMSyncEnabled(game, enabled: isPlatformROMSyncEnabled(game.gameType))
    }
    
    static func isROMExcluded(relativePath: String) -> Bool {
        romExclusionSnapshot().contains(relativePath)
    }
    
    /// Opens Realm on the calling thread and copies ROM paths into a value type.
    static func romExclusionSnapshot() -> FilesSyncROMExclusion {
        var snapshot = FilesSyncROMExclusion()
#if SIDE_LOAD
        return snapshot
#else
        let games = Database.realm.objects(Game.self).where { !$0.isDeleted }
        for game in games {
            collectROMPaths(game: game, files: &snapshot.romFiles, prefixes: &snapshot.romPrefixes)
            guard !shouldSyncROM(game) else { continue }
            collectROMPaths(game: game, files: &snapshot.files, prefixes: &snapshot.prefixes)
        }
        Log.debug("[iCloud Sync] ROM exclusion snapshot games=\(games.count) files=\(snapshot.files.count) prefixes=\(snapshot.prefixes.count) romFiles=\(snapshot.romFiles.count) romPrefixes=\(snapshot.romPrefixes.count)")
        return snapshot
#endif
    }
    
    // MARK: - ROM Transfer Limits
    
    /// Selectable ceilings for a single ROM reaching iCloud Drive. 0 means no limit.
    static let romSizeLimitOptions: [Int64] = [
        100 * 1024 * 1024,
        200 * 1024 * 1024,
        500 * 1024 * 1024,
        1024 * 1024 * 1024,
        0
    ]
    
    static let defaultROMSizeLimit: Int64 = 1024 * 1024 * 1024
    
    /// Transfer ROM payloads only on unmetered networks. Off by default so ROM sync
    /// works out of the box; saves and other small data ignore this entirely.
    static var isROMWiFiOnly: Bool {
#if SIDE_LOAD
        return false
#else
        guard let raw = threadLocalSettings()?.getExtra(key: ExtraKey.iCloudSyncROMWiFiOnly.rawValue) else {
            return false
        }
        if let flag = raw as? Bool { return flag }
        if let number = raw as? NSNumber { return number.boolValue }
        return false
#endif
    }
    
    static func setROMWiFiOnly(_ enabled: Bool) {
#if SIDE_LOAD
        return
#else
        threadLocalSettings()?.updateExtra(key: ExtraKey.iCloudSyncROMWiFiOnly.rawValue, value: enabled)
#endif
    }
    
    /// Largest ROM allowed to reach iCloud Drive, in bytes. 0 means no limit.
    static var romSizeLimit: Int64 {
#if SIDE_LOAD
        return 0
#else
        guard let raw = threadLocalSettings()?.getExtra(key: ExtraKey.iCloudSyncROMSizeLimit.rawValue) else {
            return defaultROMSizeLimit
        }
        return extraInt64(raw) ?? defaultROMSizeLimit
#endif
    }
    
    static func setROMSizeLimit(_ bytes: Int64) {
#if SIDE_LOAD
        return
#else
        // Persist as NSNumber so JSON 0 (No Limit) does not disappear or become a Bool.
        threadLocalSettings()?.updateExtra(key: ExtraKey.iCloudSyncROMSizeLimit.rawValue, value: NSNumber(value: bytes))
#endif
    }
    
    /// JSON extras type-erase numbers. NSNumber 0 also bridges to `false`, which must
    /// still mean "No Limit" rather than falling back to the 1 GB default.
    private static func extraInt64(_ raw: Any) -> Int64? {
        if let number = raw as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? 1 : 0
            }
            return number.int64Value
        }
        if let value = raw as? Int64 { return value }
        if let value = raw as? Int { return Int64(value) }
        if let value = raw as? Double { return Int64(value) }
        if let value = raw as? String { return Int64(value) }
        if let value = raw as? Bool { return value ? 1 : 0 }
        return nil
    }
    
    /// Snapshot of both ROM limits, so the engine reads Realm once per scan.
    static func romTransferLimits() -> FilesSyncROMTransferLimits {
        FilesSyncROMTransferLimits(wifiOnly: isROMWiFiOnly, sizeLimit: romSizeLimit)
    }
    
    static func collectROMPaths(game: Game, files: inout Set<String>, prefixes: inout Set<String>) {
        for url in game.iCloudROMFileURLs {
            guard let relative = documentsRelativePath(from: url) else { continue }
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                prefixes.insert(relative)
            } else if url.hasDirectoryPath {
                prefixes.insert(relative)
            } else {
                files.insert(relative)
            }
        }
    }
}

extension Game {
    /// Local ROM files/directories that belong to this game for iCloud Drive include/exclude.
    var iCloudROMFileURLs: [URL] {
        if isUrlGame || isAzaharArticBase || gameType == .symbian {
            return []
        }
        let url = romUrl
        guard url.isFileURL else { return [] }
        
        if gameType == ._3ds, fileExtension.lowercased() == "app", let range = url.path.range(of: "/content/") {
            let gamePath = String(url.path[...range.lowerBound])
            let updatePath = gamePath.replacingOccurrences(of: "/00040000/", with: "/0004000e/")
            let dlcPath = gamePath.replacingOccurrences(of: "/00040000/", with: "/0004008c/")
            return [gamePath, updatePath, dlcPath].map { URL(fileURLWithPath: $0, isDirectory: true) }
        }
        
        if isPSPPBPGame {
            return [URL(fileURLWithPath: url.deletingLastPathComponent().path, isDirectory: true)]
        }
        
        if isMultiFileGame {
            let parsed = Self.parseMultiFileROMURLs(playlist: url)
            if parsed.isEmpty {
                Log.debug("[iCloud Sync] Failed to parse multi-file ROM playlist, falling back to parent directory: \(url.lastPathComponent)")
                return [url.deletingLastPathComponent()]
            }
            return parsed
        }
        
        if gameType == .ps1, fileExtension.lowercased() == "bin" {
            let binUrl = URL(fileURLWithPath: R.Path.Data.appendingPathComponent(fileName))
            let cueUrl = binUrl.deletingPathExtension().appendingPathExtension("cue")
            var urls = [binUrl]
            if FileManager.default.fileExists(atPath: cueUrl.path) {
                urls.append(cueUrl)
            }
            return urls
        }
        
        return [url]
    }
    
    private static func parseMultiFileROMURLs(playlist: URL) -> [URL] {
        let directory = playlist.deletingLastPathComponent()
        guard let text = try? String(contentsOf: playlist, encoding: .utf8) else {
            return []
        }
        let ext = playlist.pathExtension.lowercased()
        var names: [String] = []
        if ext == "m3u" {
            names = text.components(separatedBy: .newlines).compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { return nil }
                return trimmed
            }
        } else if ext == "cue" {
            names = cueFileNames(in: text)
        } else if ext == "gdi" {
            names = gdiFileNames(in: text)
        }
        
        var urls: [URL] = [playlist]
        var seen = Set([playlist.lastPathComponent.lowercased()])
        for name in names {
            let fileURL = directory.appendingPathComponent(name)
            let key = fileURL.lastPathComponent.lowercased()
            if seen.insert(key).inserted {
                urls.append(fileURL)
            }
            if fileURL.pathExtension.lowercased() == "cue" || fileURL.pathExtension.lowercased() == "gdi",
               fileURL != playlist,
               let nested = try? String(contentsOf: fileURL, encoding: .utf8) {
                let nestedNames = fileURL.pathExtension.lowercased() == "cue" ? cueFileNames(in: nested) : gdiFileNames(in: nested)
                for nestedName in nestedNames {
                    let nestedURL = fileURL.deletingLastPathComponent().appendingPathComponent(nestedName)
                    let nestedKey = nestedURL.lastPathComponent.lowercased()
                    if seen.insert(nestedKey).inserted {
                        urls.append(nestedURL)
                    }
                }
            }
        }
        return urls
    }
    
    private static func cueFileNames(in text: String) -> [String] {
        var names: [String] = []
        let quoted = try? NSRegularExpression(pattern: #"FILE\s+"([^"]+)""#, options: [.caseInsensitive])
        let unquoted = try? NSRegularExpression(pattern: #"FILE\s+(\S+)"#, options: [.caseInsensitive])
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        quoted?.matches(in: text, range: range).forEach { match in
            if match.numberOfRanges > 1 {
                names.append(nsText.substring(with: match.range(at: 1)))
            }
        }
        if names.isEmpty {
            unquoted?.matches(in: text, range: range).forEach { match in
                if match.numberOfRanges > 1 {
                    names.append(nsText.substring(with: match.range(at: 1)))
                }
            }
        }
        return names
    }
    
    private static func gdiFileNames(in text: String) -> [String] {
        var names: [String] = []
        let quoted = try? NSRegularExpression(pattern: #""([^"]+)""#)
        let nsText = text as NSString
        quoted?.matches(in: text, range: NSRange(location: 0, length: nsText.length)).forEach { match in
            if match.numberOfRanges > 1 {
                names.append(nsText.substring(with: match.range(at: 1)))
            }
        }
        if !names.isEmpty {
            return names
        }
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        for line in lines.dropFirst() {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            if components.count >= 5 {
                names.append(String(components[components.count - 2]))
            }
        }
        return names
    }
}
