//
//  RommLibrary.swift
//  ManicEmu
//
//  Created by Chris Habibi on 6/29/26.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import IceCream
import RealmSwift

/// Pending download links plus manual pull/push for games imported from a RomM service.
final class RommLibrary {
    static let shared = RommLibrary()
    private init() {}

    private static let pendingLinksKey = "RomMPendingSaveLinks"
    private static let stateFileSuffix = ".manicstate"

    struct TransferSummary {
        var succeeded = 0
        var failed = 0
    }

    // MARK: - Pending download → import bind

    func registerDownloadedRom(fileName: String, romId: Int, serviceId: String) {
        var map = pendingMap()
        map[fileName] = ["romId": romId, "serviceId": serviceId]
        UserDefaults.standard.set(map, forKey: Self.pendingLinksKey)
        Log.debug("[RomM] pending register file=\(fileName) romId=\(romId) serviceId=\(serviceId)")
    }

    func hasPendingLink(fileName: String) -> Bool {
        pendingMap()[fileName] != nil
    }

    func discardPendingLink(fileName: String) {
        var map = pendingMap()
        guard map[fileName] != nil else { return }
        map[fileName] = nil
        UserDefaults.standard.set(map, forKey: Self.pendingLinksKey)
        Log.debug("[RomM] pending discarded file=\(fileName)")
    }

    /// Bind extras and pull sidecar data after a newly created game import.
    func applyAfterImport(gameId: String, fileName: String? = nil) {
        Log.debug("[RomM] applyAfterImport start gameId=\(gameId) file=\(fileName ?? "nil") main=\(Thread.isMainThread)")
        let bound = bindPendingIfPossible(gameId: gameId, fileName: fileName)
        Task { @MainActor in
            await self.continueAfterImport(gameId: gameId, fileName: fileName, bound: bound)
        }
    }

    /// The importer writes the Game on a background Realm. Bind extras on that same thread
    /// so the link is not lost when the main Realm has not refreshed yet.
    private func bindPendingIfPossible(gameId: String, fileName: String?) -> (romId: Int, serviceId: String)? {
        let realm = Database.realm
        realm.refresh()
        guard let game = realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else {
            Log.debug("[RomM] bind deferred; game not on caller Realm yet gameId=\(gameId)")
            return nil
        }
        let pendingName = fileName ?? game.fileName
        guard let pending = consumePendingLink(fileName: pendingName) ?? consumePendingLink(fileName: game.fileName) else {
            Log.debug("[RomM] bind skipped; no pending file=\(pendingName) gameFile=\(game.fileName)")
            return nil
        }
        persistLink(gameId: gameId, romId: pending.romId, serviceId: pending.serviceId)
        Log.debug("[RomM] bind on caller thread game=\(game.fileName) romId=\(pending.romId) serviceId=\(pending.serviceId)")
        return pending
    }

    @MainActor
    private func continueAfterImport(gameId: String, fileName: String?, bound: (romId: Int, serviceId: String)?) async {
        guard let game = await waitForGame(gameId: gameId) else {
            Log.debug("[RomM] applyAfterImport aborted; game still missing after refresh gameId=\(gameId) file=\(fileName ?? "nil")")
            return
        }
        let pending: (romId: Int, serviceId: String)
        if let bound {
            pending = bound
        } else if let consumed = consumePendingLink(fileName: fileName ?? game.fileName) ?? consumePendingLink(fileName: game.fileName) {
            persistLink(gameId: gameId, romId: consumed.romId, serviceId: consumed.serviceId)
            Log.debug("[RomM] bind on main after refresh game=\(game.fileName) romId=\(consumed.romId) serviceId=\(consumed.serviceId)")
            pending = consumed
        } else if let romId = game.rommRomId, let serviceId = game.rommServiceId {
            pending = (romId, serviceId)
            Log.debug("[RomM] applyAfterImport using existing bind romId=\(romId) serviceId=\(serviceId)")
        } else {
            Log.debug("[RomM] applyAfterImport skipped: no pending link file=\(fileName ?? game.fileName) gameFile=\(game.fileName) gameId=\(gameId)")
            return
        }
        guard let client = makeClient(serviceId: pending.serviceId) else {
            Log.debug("[RomM] applyAfterImport: client unavailable for service \(pending.serviceId)")
            return
        }
        do {
            try await pullSidecar(gameId: gameId, client: client, romId: pending.romId)
        } catch {
            Log.debug("[RomM] applyAfterImport failed for \(game.fileName): \(error)")
        }
    }

    @MainActor
    private func waitForGame(gameId: String) async -> Game? {
        let realm = Database.realm
        realm.refresh()
        if let game = realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted {
            return game
        }
        for attempt in 1...8 {
            try? await Task.sleep(nanoseconds: 50_000_000 * UInt64(attempt))
            realm.refresh()
            if let game = realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted {
                Log.debug("[RomM] game appeared on main Realm after attempt \(attempt) gameId=\(gameId)")
                return game
            }
        }
        return nil
    }

    @MainActor
    func linkedGameCount(service: ImportService) -> Int {
        linkedGameIds(serviceId: "\(service.id)").count
    }

    func pull(service: ImportService) async -> TransferSummary {
        await transfer(service: service, direction: .pull)
    }

    func push(service: ImportService) async -> TransferSummary {
        await transfer(service: service, direction: .push)
    }

    // MARK: - Pending helpers

    private func pendingMap() -> [String: [String: Any]] {
        UserDefaults.standard.dictionary(forKey: Self.pendingLinksKey) as? [String: [String: Any]] ?? [:]
    }

    private func consumePendingLink(fileName: String) -> (romId: Int, serviceId: String)? {
        var map = pendingMap()
        guard let entry = map[fileName] else { return nil }
        guard let romId = Self.intValue(entry["romId"]),
              let serviceId = entry["serviceId"] as? String else {
            Log.debug("[RomM] pending parse failed file=\(fileName) entry=\(entry)")
            return nil
        }
        map[fileName] = nil
        UserDefaults.standard.set(map, forKey: Self.pendingLinksKey)
        Log.debug("[RomM] pending consumed file=\(fileName) romId=\(romId) serviceId=\(serviceId)")
        return (romId, serviceId)
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let value = any as? Int { return value }
        if let number = any as? NSNumber { return number.intValue }
        if let string = any as? String { return Int(string) }
        return nil
    }

    // MARK: - Service transfer

    private enum Direction {
        case pull, push
    }

    private func transfer(service: ImportService, direction: Direction) async -> TransferSummary {
        let snapshot = await MainActor.run { ServiceSnapshot(service: service) }
        Log.debug("[RomM] \(direction == .pull ? "PULL" : "PUSH") start service=\(snapshot.id) host=\(snapshot.host) port=\(snapshot.port ?? -1)")
        guard let client = snapshot.makeClient() else {
            Log.debug("[RomM] \(direction == .pull ? "PULL" : "PUSH") aborted: client init failed")
            return TransferSummary(succeeded: 0, failed: 1)
        }
        do {
            let platforms = try await client.platforms()
            Log.debug("[RomM] connected platforms=\(platforms.count)")
        } catch {
            Log.debug("[RomM] cannot reach service \(snapshot.id): \(error)")
            return TransferSummary(succeeded: 0, failed: 1)
        }

        let gameIds = await MainActor.run { linkedGameIds(serviceId: snapshot.id) }
        Log.debug("[RomM] \(direction == .pull ? "PULL" : "PUSH") linked games=\(gameIds.count) ids=\(gameIds)")
        var summary = TransferSummary()
        for gameId in gameIds {
            do {
                switch direction {
                case .pull:
                    try await pullSidecar(gameId: gameId, client: client)
                case .push:
                    try await pushSidecar(gameId: gameId, client: client)
                }
                summary.succeeded += 1
            } catch {
                summary.failed += 1
                Log.debug("[RomM] \(direction == .pull ? "pull" : "push") failed for \(gameId): \(error)")
            }
        }
        Log.debug("[RomM] \(direction == .pull ? "PULL" : "PUSH") done succeeded=\(summary.succeeded) failed=\(summary.failed)")
        return summary
    }

    @MainActor
    private func linkedGameIds(serviceId: String) -> [String] {
        Database.realm.objects(Game.self)
            .where { !$0.isDeleted }
            .filter { $0.rommServiceId == serviceId && $0.rommRomId != nil }
            .map { $0.id }
    }

    private func persistLink(gameId: String, romId: Int, serviceId: String) {
        let realm = Database.realm
        realm.refresh()
        guard let game = realm.object(ofType: Game.self, forPrimaryKey: gameId) else {
            Log.debug("[RomM] persistLink miss gameId=\(gameId) main=\(Thread.isMainThread)")
            return
        }
        game.rommRomId = romId
        game.rommServiceId = serviceId
    }

    @MainActor
    private func makeClient(serviceId: String) -> RommClient? {
        guard let serviceIdValue = Int(serviceId),
              let service = Database.realm.object(ofType: ImportService.self, forPrimaryKey: serviceIdValue),
              !service.isDeleted else { return nil }
        return ServiceSnapshot(service: service).makeClient()
    }

    // MARK: - Pull sidecar

    private func pullSidecar(gameId: String, client: RommClient, romId: Int? = nil) async throws {
        let resolvedRomId = try await MainActor.run { () -> Int in
            if let romId { return romId }
            guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId),
                  let linked = game.rommRomId else {
                throw RommLibraryError.missingGame
            }
            return linked
        }
        Log.debug("[RomM] PULL sidecar gameId=\(gameId) romId=\(resolvedRomId)")
        let rom = try await client.rom(id: resolvedRomId)
        Log.debug("[RomM] PULL decoded rom id=\(rom.id) name=\(rom.name ?? "nil") fs=\(rom.fs_name) coverLarge=\(rom.path_cover_large ?? "nil") coverSmall=\(rom.path_cover_small ?? "nil") urlCover=\(rom.url_cover ?? "nil") preferred=\(rom.preferredCoverPath ?? "nil") hasManual=\(rom.has_manual ?? false) pathManual=\(rom.path_manual ?? "nil") urlManual=\(rom.url_manual ?? "nil") preferredManual=\(rom.preferredManualPath ?? "nil") ageRatings=\(rom.metadatum?.age_ratings ?? []) igdbAgeRatings=\(rom.igdb_metadata?.age_ratings?.map { "\($0.category ?? "?"):\($0.rating ?? "?")" } ?? []) summaryChars=\(rom.summary?.count ?? 0) genres=\(rom.metadatum?.genres ?? []) companies=\(rom.metadatum?.companies ?? []) lastPlayed=\(String(describing: rom.rom_user?.last_played))")
        await applyCover(gameId: gameId, client: client, rom: rom)
        await applyMetadata(gameId: gameId, rom: rom)
        await pullManual(gameId: gameId, client: client, rom: rom)
        await applyPlayTime(gameId: gameId, client: client, rom: rom)
        await pullSave(gameId: gameId, client: client, romId: resolvedRomId)
        await pullStates(gameId: gameId, client: client, romId: resolvedRomId)
        Log.debug("[RomM] PULL sidecar finished gameId=\(gameId) romId=\(resolvedRomId)")
    }

    private func applyCover(gameId: String, client: RommClient, rom: RommRom) async {
        guard let data = await downloadCover(client: client, rom: rom), !data.isEmpty else {
            Log.debug("[RomM] PULL cover skipped gameId=\(gameId) romId=\(rom.id) no image data")
            return
        }
        await MainActor.run {
            var didWrite = false
            Game.change { realm in
                guard let game = realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else { return }
                game.gameCover?.deleteAndClean(realm: realm)
                game.gameCover = CreamAsset.create(objectID: game.id, propName: "gameCover", data: data)
                game.hasCoverMatch = true
                game.onlineCoverUrl = nil
                didWrite = true
            }
            Log.debug("[RomM] PULL cover wrote gameId=\(gameId) bytes=\(data.count) didWrite=\(didWrite)")
            if didWrite {
                NotificationCenter.default.post(name: R.NotificationName.GameCoverChange, object: nil)
            }
        }
    }

    private func downloadCover(client: RommClient, rom: RommRom) async -> Data? {
        Log.debug("[RomM] PULL cover try romId=\(rom.id) large=\(rom.path_cover_large ?? "nil") small=\(rom.path_cover_small ?? "nil") url=\(rom.url_cover ?? "nil")")
        if let path = rom.preferredCoverPath {
            if let data = await downloadCoverResource(client: client, source: path, label: "preferred") {
                return data
            }
        }
        if let urlCover = rom.url_cover, !urlCover.isEmpty, urlCover != rom.preferredCoverPath {
            if let data = await downloadCoverResource(client: client, source: urlCover, label: "url_cover") {
                return data
            }
        }
        Log.debug("[RomM] PULL cover all sources failed romId=\(rom.id)")
        return nil
    }

    private func downloadCoverResource(client: RommClient, source: String, label: String, ignoreCache: Bool = false) async -> Data? {
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            guard let url = URL(string: source) else {
                Log.debug("[RomM] PULL \(label): invalid URL \(source)")
                return nil
            }
            var request = URLRequest(url: url)
            if ignoreCache {
                request.cachePolicy = .reloadIgnoringLocalCacheData
            }
            return await fetchBytes(label: label, client: client, request: request)
        }
        let path = Self.resolvedAssetPath(source)
        guard let request = client.assetDownloadRequest(downloadPath: path, ignoreCache: ignoreCache) else {
            Log.debug("[RomM] PULL \(label): could not build request path=\(path)")
            return nil
        }
        Log.debug("[RomM] PULL \(label): path=\(path) url=\(request.url?.absoluteString ?? "nil")")
        return await fetchBytes(label: label, client: client, request: request)
    }

    private static func resolvedAssetPath(_ path: String) -> String {
        if path.hasPrefix("http://") || path.hasPrefix("https://") || path.hasPrefix("/assets/") {
            return path
        }
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return "/assets/romm/resources/" + relative
    }

    private func pullManual(gameId: String, client: RommClient, rom: RommRom) async {
        let remoteHasManual = rom.has_manual == true || !(rom.path_manual ?? "").isEmpty
        Log.debug("[RomM] PULL manual try romId=\(rom.id) remoteHasManual=\(remoteHasManual) hasManual=\(rom.has_manual ?? false) url=\(rom.url_manual ?? "nil") path=\(rom.path_manual ?? "nil")")
        if !remoteHasManual {
            await MainActor.run { Self.removeLocalManual(gameId: gameId, reason: "remote removed") }
            return
        }
        var data: Data?
        if let path = rom.path_manual, !path.isEmpty {
            data = await downloadCoverResource(client: client, source: path, label: "manual path", ignoreCache: true)
        }
        if data == nil, let url = rom.url_manual, !url.isEmpty, url != rom.path_manual {
            data = await downloadCoverResource(client: client, source: url, label: "manual url", ignoreCache: true)
        }
        guard let data, Self.isPDF(data) else {
            if let data {
                Log.debug("[RomM] PULL manual skipped romId=\(rom.id) not a PDF (\(data.count) bytes)")
            } else {
                Log.debug("[RomM] PULL manual skipped romId=\(rom.id) download failed; keep local")
            }
            return
        }
        await MainActor.run {
            Self.writeLocalManual(gameId: gameId, data: data)
        }
    }

    /// Clears extras and the PDF when RomM no longer has a manual.
    @MainActor
    private static func removeLocalManual(gameId: String, reason: String) {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else {
            Log.debug("[RomM] PULL manual \(reason) skipped: game missing \(gameId)")
            return
        }
        let directory = URL(fileURLWithPath: R.Path.GameplayManuals, isDirectory: true)
        var removed: [String] = []
        if let fileName = game.getExtraString(key: ExtraKey.manualFileName.rawValue), !fileName.isEmpty {
            let url = directory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.safeRemoveItem(at: url)
                SyncManager.delete(localFilePath: url.path)
                removed.append(url.path)
            }
        }
        let canonical = directory.appendingPathComponent("\(game.id).pdf")
        if FileManager.default.fileExists(atPath: canonical.path), !removed.contains(canonical.path) {
            try? FileManager.safeRemoveItem(at: canonical)
            SyncManager.delete(localFilePath: canonical.path)
            removed.append(canonical.path)
        }
        game.updateExtra(key: ExtraKey.manualFileName.rawValue, value: nil)
        game.updateExtra(key: ExtraKey.manualPage.rawValue, value: nil)
        game.updateExtra(key: ExtraKey.manualScaleFactor.rawValue, value: nil)
        Log.debug("[RomM] PULL manual \(reason) gameId=\(gameId) removed=\(removed) manualsPath=\(game.manualsPath ?? "nil")")
    }

    @MainActor
    private static func writeLocalManual(gameId: String, data: Data) {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else {
            Log.debug("[RomM] PULL manual skipped: game missing \(gameId)")
            return
        }
        let pdfName = "\(game.id).pdf"
        let directory = URL(fileURLWithPath: R.Path.GameplayManuals, isDirectory: true)
        let destination = directory.appendingPathComponent(pdfName)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let previous = game.getExtraString(key: ExtraKey.manualFileName.rawValue),
               previous != pdfName {
                let oldURL = directory.appendingPathComponent(previous)
                try? FileManager.safeRemoveItem(at: oldURL)
                SyncManager.delete(localFilePath: oldURL.path)
            }
            if FileManager.default.fileExists(atPath: destination.path),
               let existing = try? Data(contentsOf: destination),
               existing == data {
                if game.getExtraString(key: ExtraKey.manualFileName.rawValue) != pdfName {
                    game.updateExtra(key: ExtraKey.manualFileName.rawValue, value: pdfName)
                }
                Log.debug("[RomM] PULL manual unchanged \(data.count) bytes \(destination.path)")
                return
            }
            try data.write(to: destination, options: .atomic)
            game.updateExtra(key: ExtraKey.manualFileName.rawValue, value: pdfName)
            game.updateExtra(key: ExtraKey.manualPage.rawValue, value: nil)
            game.updateExtra(key: ExtraKey.manualScaleFactor.rawValue, value: nil)
            SyncManager.upload(localFilePath: destination.path)
            Log.debug("[RomM] PULL manual wrote \(data.count) bytes to \(destination.path) manualsPath=\(game.manualsPath ?? "nil")")
        } catch {
            Log.debug("[RomM] PULL manual write failed: \(error)")
        }
    }

    private func fetchBytes(label: String, client: RommClient, request: URLRequest) async -> Data? {
        do {
            let data = try await client.data(for: request)
            if data.isEmpty {
                Log.debug("[RomM] \(label): empty body \(request.url?.absoluteString ?? "?")")
                return nil
            }
            Log.debug("[RomM] \(label): got \(data.count) bytes")
            return data
        } catch {
            Log.debug("[RomM] \(label): failed \(request.url?.absoluteString ?? "?") error=\(error)")
            return nil
        }
    }

    private func applyMetadata(gameId: String, rom: RommRom) async {
        await MainActor.run {
            guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else {
                Log.debug("[RomM] PULL metadata skipped: game missing \(gameId)")
                return
            }
            var metadata = GameMetadata.getGameMetadata(game: game) ?? GameMetadata()
            if let name = rom.name, !name.isEmpty {
                metadata.displayName = name
                metadata.fullName = name
                Game.change { _ in
                    game.aliasName = name
                }
            }
            if let summary = rom.summary {
                metadata.overview = summary
            }
            if let genres = rom.metadatum?.genres, !genres.isEmpty {
                metadata.genre = genres.joined(separator: ", ")
            }
            if let franchises = rom.metadatum?.franchises, !franchises.isEmpty {
                metadata.franchise = franchises.joined(separator: ", ")
            }
            if let companies = rom.metadatum?.companies, !companies.isEmpty {
                metadata.developer = companies[0]
                metadata.publisher = companies.count > 1 ? companies[companies.count - 1] : companies[0]
            }
            if let timestamp = rom.metadatum?.first_release_date {
                let seconds = timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp
                let date = Date(timeIntervalSince1970: TimeInterval(seconds))
                let calendar = Calendar(identifier: .gregorian)
                metadata.releaseYear = calendar.component(.year, from: date)
                metadata.releaseMonth = calendar.component(.month, from: date)
            }
            if let esrp = Self.esrp(metadatumRatings: rom.metadatum?.age_ratings,
                                    igdbRatings: rom.igdb_metadata?.age_ratings) {
                metadata.ratingId = esrp.ratingId
                Log.debug("[RomM] PULL ESRB mapped \(esrp.abbr) ratingId=\(esrp.ratingId) from metadatum=\(rom.metadatum?.age_ratings ?? []) igdb=\(rom.igdb_metadata?.age_ratings?.map { "\($0.category ?? "?"):\($0.rating ?? "?")" } ?? [])")
            } else {
                Log.debug("[RomM] PULL ESRB skipped metadatum=\(rom.metadatum?.age_ratings ?? []) igdb=\(rom.igdb_metadata?.age_ratings?.map { "\($0.category ?? "?"):\($0.rating ?? "?")" } ?? [])")
            }
            metadata.persist(to: game)
            game.updateExtra(key: ExtraKey.hasQueryMetadata.rawValue, value: true)
            Log.debug("[RomM] PULL metadata wrote aliasName=\(game.aliasName ?? "nil") displayName=\(metadata.displayName) genre=\(metadata.genre) franchise=\(metadata.franchise) developer=\(metadata.developer) publisher=\(metadata.publisher) release=\(metadata.releaseYear)-\(metadata.releaseMonth) ratingId=\(metadata.ratingId) overviewChars=\(metadata.overview.count)")
        }
    }

    private func applyPlayTime(gameId: String, client: RommClient, rom: RommRom) async {
        let sessions = (try? await client.playSessions(romID: rom.id)) ?? []
        let remoteTotal = Double(sessions.reduce(0) { $0 + $1.duration_ms })
        let lastPlayed = rom.rom_user?.last_played ?? sessions.compactMap(\.end_time).max()
        Log.debug("[RomM] PULL play-time romId=\(rom.id) sessions=\(sessions.count) durationMs=\(Int(remoteTotal)) lastPlayed=\(String(describing: lastPlayed))")
        await MainActor.run {
            Game.change { realm in
                guard let game = realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else { return }
                if remoteTotal > 0 {
                    game.totalPlayDuration = remoteTotal
                }
                if let lastPlayed {
                    game.latestPlayDate = lastPlayed
                }
            }
            if let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId) {
                let watermark = remoteTotal > 0 ? remoteTotal : game.totalPlayDuration
                game.rommPlayDurationPushed = watermark
            }
        }
    }

    private func pullSave(gameId: String, client: RommClient, romId: Int) async {
        let context = await MainActor.run { () -> (url: URL, skip: Bool)? in
            guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else { return nil }
            return (game.gameSaveUrl, game.gameType == ._3ds || game.gameType == .psp)
        }
        guard let context, !context.skip else {
            Log.debug("[RomM] PULL save skipped gameId=\(gameId) romId=\(romId) reason=\(context == nil ? "missing game" : "3DS/PSP")")
            return
        }
        let remotes = (try? await client.saves(romID: romId)) ?? []
        let remote = remotes
            .sorted(by: { ($0.updated_at ?? .distantPast) > ($1.updated_at ?? .distantPast) })
            .first
        Log.debug("[RomM] PULL saves romId=\(romId) count=\(remotes.count) chosen=\(remote.map { "id=\($0.id) file=\($0.file_name) bytes=\($0.file_size_bytes ?? 0)" } ?? "none")")
        guard let remote,
              let request = client.saveContentRequest(saveID: remote.id),
              let data = await fetchBytes(label: "save \(remote.file_name)", client: client, request: request) else { return }
        let directory = context.url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try data.write(to: context.url, options: .atomic)
            if let date = remote.updated_at {
                try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: context.url.path)
            }
            SyncManager.upload(localFilePath: context.url.path)
            Log.debug("[RomM] PULL save wrote \(data.count) bytes to \(context.url.lastPathComponent)")
        } catch {
            Log.debug("[RomM] write save failed: \(error)")
        }
    }

    private func pullStates(gameId: String, client: RommClient, romId: Int) async {
        guard let remoteStates = try? await client.states(romID: romId) else {
            Log.debug("[RomM] PULL states failed to list romId=\(romId)")
            return
        }
        Log.debug("[RomM] PULL states romId=\(romId) count=\(remoteStates.count) files=\(remoteStates.map(\.file_name))")
        for remote in remoteStates {
            guard let request = client.assetDownloadRequest(downloadPath: remote.download_path),
                  let data = await fetchBytes(label: "state \(remote.file_name)", client: client, request: request) else { continue }
            var coverData: Data?
            if let screenshot = remote.screenshot,
               let coverRequest = client.assetDownloadRequest(downloadPath: screenshot.download_path) {
                coverData = try? await client.data(for: coverRequest)
            }
            await upsertLocalState(gameId: gameId,
                                   remoteName: remote.file_name,
                                   date: remote.updated_at ?? Date(),
                                   data: data,
                                   cover: coverData)
            Log.debug("[RomM] PULL state upsert file=\(remote.file_name) bytes=\(data.count) coverBytes=\(coverData?.count ?? 0)")
        }
    }

    @MainActor
    private func upsertLocalState(gameId: String, remoteName: String, date: Date, data: Data, cover: Data?) {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else { return }
        let key = Self.normalizedKey(remoteName)
        if let existing = game.gameSaveStates.first(where: { Self.normalizedKey($0.name) == key }) {
            Game.change { realm in
                existing.date = date
                existing.stateData?.deleteAndClean(realm: realm)
                existing.stateData = CreamAsset.create(objectID: existing.name, propName: "stateData", data: data)
                if let cover {
                    existing.stateCover?.deleteAndClean(realm: realm)
                    existing.stateCover = CreamAsset.create(objectID: existing.name, propName: "stateCover", data: cover)
                }
            }
            return
        }
        let preferred = Self.deriveStateName(from: remoteName)
        var stateName = preferred
        if Database.realm.object(ofType: GameSaveState.self, forPrimaryKey: stateName) != nil {
            stateName = "\(gameId)_\(preferred)"
        }
        if Database.realm.object(ofType: GameSaveState.self, forPrimaryKey: stateName) != nil {
            stateName = "\(gameId)_\(Int(Date().timeIntervalSince1970))_\(preferred)"
        }
        Game.change { realm in
            guard let game = realm.object(ofType: Game.self, forPrimaryKey: gameId) else { return }
            let state = GameSaveState()
            state.name = stateName
            state.type = .manualSaveState
            state.date = date
            if let cover {
                state.stateCover = CreamAsset.create(objectID: state.name, propName: "stateCover", data: cover)
            }
            state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", data: data)
            game.gameSaveStates.append(state)
        }
    }

    // MARK: - Push sidecar

    private func pushSidecar(gameId: String, client: RommClient) async throws {
        let snapshot = try await MainActor.run { () -> PushSnapshot in
            guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId),
                  !game.isDeleted,
                  let romId = game.rommRomId else {
                throw RommLibraryError.missingGame
            }
            return PushSnapshot(game: game, romId: romId)
        }
        Log.debug("[RomM] PUSH sidecar gameId=\(snapshot.gameId) romId=\(snapshot.romId) displayName=\(snapshot.displayName) overviewChars=\(snapshot.overview?.count ?? 0) coverBytes=\(snapshot.coverData?.count ?? 0) manualBytes=\(snapshot.manualData?.count ?? 0) save=\(snapshot.saveURL.lastPathComponent) battery=\(snapshot.supportsBatterySave) playMs=\(Int(snapshot.totalPlayDuration)) pushedMs=\(Int(snapshot.playDurationPushed)) lastPlayed=\(String(describing: snapshot.latestPlayDate)) states=\(snapshot.states.map { "\($0.name):\($0.data?.count ?? 0)" })")
        try await pushCoverAndMetadata(client: client, snapshot: snapshot)
        await pushManual(client: client, snapshot: snapshot)
        try await pushPlayTime(client: client, snapshot: snapshot)
        await pushSave(client: client, snapshot: snapshot)
        await pushStates(client: client, snapshot: snapshot)
        Log.debug("[RomM] PUSH sidecar finished gameId=\(snapshot.gameId) romId=\(snapshot.romId)")
    }

    private func pushCoverAndMetadata(client: RommClient, snapshot: PushSnapshot) async throws {
        var artwork: (fileName: String, data: Data)?
        if let cover = snapshot.coverData, !cover.isEmpty {
            artwork = (fileName: "cover.jpg", data: cover)
        }
        Log.debug("[RomM] PUSH rom romId=\(snapshot.romId) name=\(snapshot.displayName) summaryChars=\(snapshot.overview?.count ?? 0) artwork=\(artwork.map { "\($0.fileName) \($0.data.count) bytes" } ?? "nil")")
        try await client.updateRom(romID: snapshot.romId,
                                   name: snapshot.displayName,
                                   summary: snapshot.overview,
                                   artwork: artwork)
    }

    private func pushManual(client: RommClient, snapshot: PushSnapshot) async {
        if let data = snapshot.manualData, Self.isPDF(data) {
            let fileName = snapshot.manualFileName ?? "manual.pdf"
            Log.debug("[RomM] PUSH manual romId=\(snapshot.romId) file=\(fileName) bytes=\(data.count)")
            do {
                try await client.uploadManual(romID: snapshot.romId, fileName: fileName, fileData: data)
                Log.debug("[RomM] PUSH manual ok romId=\(snapshot.romId)")
            } catch {
                Log.debug("[RomM] PUSH manual failed romId=\(snapshot.romId): \(error)")
            }
            return
        }
        Log.debug("[RomM] PUSH manual none locally romId=\(snapshot.romId); delete remote")
        do {
            try await client.deleteManual(romID: snapshot.romId)
            Log.debug("[RomM] PUSH manual deleted remote romId=\(snapshot.romId)")
        } catch {
            Log.debug("[RomM] PUSH manual delete failed romId=\(snapshot.romId): \(error)")
        }
    }

    private func pushPlayTime(client: RommClient, snapshot: PushSnapshot) async throws {
        let delta = Int(snapshot.totalPlayDuration - snapshot.playDurationPushed)
        Log.debug("[RomM] PUSH play-time romId=\(snapshot.romId) localMs=\(Int(snapshot.totalPlayDuration)) watermarkMs=\(Int(snapshot.playDurationPushed)) deltaMs=\(delta) lastPlayed=\(String(describing: snapshot.latestPlayDate))")
        if delta > 0 {
            try await client.ingestPlaySession(romID: snapshot.romId, durationMs: delta)
        }
        if snapshot.latestPlayDate != nil {
            try? await client.updateLastPlayed(romID: snapshot.romId)
        }
        await MainActor.run {
            guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: snapshot.gameId) else { return }
            game.rommPlayDurationPushed = snapshot.totalPlayDuration
        }
    }

    private func pushSave(client: RommClient, snapshot: PushSnapshot) async {
        guard snapshot.supportsBatterySave,
              FileManager.default.fileExists(atPath: snapshot.saveURL.path),
              let data = try? Data(contentsOf: snapshot.saveURL) else {
            Log.debug("[RomM] PUSH save skipped romId=\(snapshot.romId) battery=\(snapshot.supportsBatterySave) exists=\(FileManager.default.fileExists(atPath: snapshot.saveURL.path))")
            return
        }
        Log.debug("[RomM] PUSH save romId=\(snapshot.romId) file=\(snapshot.saveURL.lastPathComponent) bytes=\(data.count)")
        do {
            try await client.uploadSave(romID: snapshot.romId,
                                        emulator: nil,
                                        fileName: snapshot.saveURL.lastPathComponent,
                                        fileData: data)
            Log.debug("[RomM] PUSH save ok romId=\(snapshot.romId)")
        } catch {
            Log.debug("[RomM] upload save failed: \(error)")
        }
    }

    private func pushStates(client: RommClient, snapshot: PushSnapshot) async {
        for state in snapshot.states {
            guard let data = state.data, !data.isEmpty else { continue }
            var screenshot: (fileName: String, data: Data)?
            if let cover = state.cover, !cover.isEmpty {
                screenshot = (fileName: "\(state.name).jpg", data: cover)
            }
            let remoteName = state.name.hasSuffix(Self.stateFileSuffix)
                ? state.name
                : "\(state.name)\(Self.stateFileSuffix)"
            Log.debug("[RomM] PUSH state romId=\(snapshot.romId) file=\(remoteName) bytes=\(data.count) screenshot=\(screenshot?.fileName ?? "nil")")
            do {
                _ = try await client.uploadState(romID: snapshot.romId,
                                                 emulator: nil,
                                                 fileName: remoteName,
                                                 fileData: data,
                                                 screenshot: screenshot)
                Log.debug("[RomM] PUSH state ok \(remoteName)")
            } catch {
                Log.debug("[RomM] upload state failed (\(state.name)): \(error)")
            }
        }
    }

    // MARK: - Mapping

    private static func isPDF(_ data: Data) -> Bool {
        if let range = data.range(of: Data("%PDF".utf8)), range.lowerBound < 8 {
            return true
        }
        return false
    }

    private static func esrp(metadatumRatings: [String]?, igdbRatings: [RommAgeRating]?) -> ESRP? {
        if let igdbRatings {
            let esrb = igdbRatings.filter { isESRBCategory($0.category) }
            for item in esrb {
                if let mapped = esrp(rating: item.rating, category: item.category) { return mapped }
            }
            for item in igdbRatings {
                if let mapped = esrpFromToken(item.rating ?? "") { return mapped }
            }
        }
        guard let metadatumRatings else { return nil }
        for raw in metadatumRatings where raw.localizedCaseInsensitiveContains("esrb") {
            if let mapped = esrpFromToken(raw) { return mapped }
        }
        for raw in metadatumRatings {
            if let mapped = esrpFromToken(raw) { return mapped }
        }
        return nil
    }

    private static func isESRBCategory(_ raw: String?) -> Bool {
        guard let raw, !raw.isEmpty else { return false }
        let folded = raw.lowercased()
        return folded.contains("esrb") || folded == "1"
    }

    private static func esrp(rating: String?, category: String?) -> ESRP? {
        if let mapped = esrpFromToken(rating ?? "") { return mapped }
        guard isESRBCategory(category), let id = Int(rating ?? "") else { return nil }
        switch id {
        case 1: return .RP
        case 2: return .EC
        case 3: return .E
        case 4: return .E10
        case 5: return .T
        case 6: return .M
        case 7: return .AO
        default: return nil
        }
    }

    /// RomM stores IGDB letters (`E`, `T`, `E10+`) in `metadatum.age_ratings`, not "Everyone".
    private static func esrpFromToken(_ raw: String) -> ESRP? {
        let folded = raw.lowercased()
            .replacingOccurrences(of: "esrb", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = folded
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "–", with: "")
            .replacingOccurrences(of: " ", with: "")
        switch compact {
        case "ao", "adultsonly": return .AO
        case "e10", "everyone10": return .E10
        case "ec", "earlychildhood": return .EC
        case "ka", "kidstoadults": return .K_A
        case "rp17", "ratingpending17": return .RP17
        case "rp", "ratingpending": return .RP
        case "m", "mature": return .M
        case "t", "teen": return .T
        case "e", "everyone": return .E
        default: break
        }
        if folded.contains("adults only") { return .AO }
        if folded.contains("everyone 10") { return .E10 }
        if folded.contains("early childhood") { return .EC }
        if folded.contains("kids to adults") { return .K_A }
        if folded.contains("rating pending") && folded.contains("17") { return .RP17 }
        if folded.contains("rating pending") { return .RP }
        return nil
    }

    private static func normalizedKey(_ raw: String) -> String {
        var value = raw
        if value.hasSuffix(stateFileSuffix) {
            value = String(value.dropLast(stateFileSuffix.count))
        }
        return value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func deriveStateName(from fileName: String) -> String {
        if fileName.hasSuffix(stateFileSuffix) {
            return String(fileName.dropLast(stateFileSuffix.count))
        }
        return fileName
    }

    // MARK: - Snapshots

    private struct ServiceSnapshot {
        let id: String
        let scheme: String
        let host: String
        let port: Int?
        let user: String?
        let password: String?
        let path: String?

        init(service: ImportService) {
            id = "\(service.id)"
            scheme = service.scheme ?? "http"
            host = service.host ?? ""
            port = service.port
            user = service.user
            password = service.password
            path = service.path
        }

        func makeClient() -> RommClient? {
            RommClient(scheme: scheme, host: host, port: port, user: user, password: password, path: path)
        }
    }

    private struct StatePushSnapshot {
        let name: String
        let data: Data?
        let cover: Data?
    }

    private struct PushSnapshot {
        let gameId: String
        let romId: Int
        let displayName: String
        let overview: String?
        let coverData: Data?
        let manualData: Data?
        let manualFileName: String?
        let saveURL: URL
        let supportsBatterySave: Bool
        let totalPlayDuration: Double
        let playDurationPushed: Double
        let latestPlayDate: Date?
        let states: [StatePushSnapshot]

        init(game: Game, romId: Int) {
            gameId = game.id
            self.romId = romId
            displayName = game.displayName
            overview = GameMetadata.getGameMetadata(game: game)?.overview
            coverData = game.gameCover?.storedData()
            if let path = game.manualsPath,
               FileManager.default.fileExists(atPath: path),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               RommLibrary.isPDF(data) {
                manualData = data
                manualFileName = URL(fileURLWithPath: path).lastPathComponent
            } else {
                manualData = nil
                manualFileName = nil
            }
            saveURL = game.gameSaveUrl
            supportsBatterySave = game.gameType != ._3ds && game.gameType != .psp
            totalPlayDuration = game.totalPlayDuration
            playDurationPushed = game.rommPlayDurationPushed
            latestPlayDate = game.latestPlayDate
            states = game.gameSaveStates.map {
                StatePushSnapshot(name: $0.name,
                                  data: $0.stateData?.storedData(),
                                  cover: $0.stateCover?.storedData())
            }
        }
    }

    private enum RommLibraryError: Error {
        case missingGame
    }
}
