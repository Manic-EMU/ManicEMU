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
    }

    func hasPendingLink(fileName: String) -> Bool {
        pendingMap()[fileName] != nil
    }

    func discardPendingLink(fileName: String) {
        var map = pendingMap()
        guard map[fileName] != nil else { return }
        map[fileName] = nil
        UserDefaults.standard.set(map, forKey: Self.pendingLinksKey)
    }

    /// Bind extras and pull sidecar data after a newly created game import.
    func applyAfterImport(gameId: String, fileName: String? = nil) {
        Task { @MainActor in
            await self.applyAfterImportOnMain(gameId: gameId, fileName: fileName)
        }
    }

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
        guard let entry = map[fileName],
              let romId = Self.intValue(entry["romId"]),
              let serviceId = entry["serviceId"] as? String else { return nil }
        map[fileName] = nil
        UserDefaults.standard.set(map, forKey: Self.pendingLinksKey)
        return (romId, serviceId)
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let value = any as? Int { return value }
        if let number = any as? NSNumber { return number.intValue }
        if let string = any as? String { return Int(string) }
        return nil
    }

    // MARK: - Import sidecar

    @MainActor
    private func applyAfterImportOnMain(gameId: String, fileName: String?) async {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else {
            if let fileName { discardPendingLink(fileName: fileName) }
            return
        }
        let pendingName = fileName ?? game.fileName
        guard let pending = consumePendingLink(fileName: pendingName) ?? consumePendingLink(fileName: game.fileName) else {
            return
        }
        persistLink(gameId: gameId, romId: pending.romId, serviceId: pending.serviceId)
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

    // MARK: - Service transfer

    private enum Direction {
        case pull, push
    }

    private func transfer(service: ImportService, direction: Direction) async -> TransferSummary {
        let snapshot = await MainActor.run { ServiceSnapshot(service: service) }
        guard let client = snapshot.makeClient() else {
            return TransferSummary(succeeded: 0, failed: 1)
        }
        do {
            _ = try await client.platforms()
        } catch {
            Log.debug("[RomM] cannot reach service \(snapshot.id): \(error)")
            return TransferSummary(succeeded: 0, failed: 1)
        }

        let gameIds = await MainActor.run { linkedGameIds(serviceId: snapshot.id) }
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
        return summary
    }

    @MainActor
    private func linkedGameIds(serviceId: String) -> [String] {
        Database.realm.objects(Game.self)
            .where { !$0.isDeleted }
            .filter { $0.rommServiceId == serviceId && $0.rommRomId != nil }
            .map { $0.id }
    }

    @MainActor
    private func persistLink(gameId: String, romId: Int, serviceId: String) {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId) else { return }
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
        let rom = try await client.rom(id: resolvedRomId)
        await applyCover(gameId: gameId, client: client, rom: rom)
        await applyMetadata(gameId: gameId, rom: rom)
        await applyPlayTime(gameId: gameId, client: client, rom: rom)
        await pullSave(gameId: gameId, client: client, romId: resolvedRomId)
        await pullStates(gameId: gameId, client: client, romId: resolvedRomId)
    }

    private func applyCover(gameId: String, client: RommClient, rom: RommRom) async {
        guard let data = await downloadCover(client: client, rom: rom), !data.isEmpty else { return }
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
            if didWrite {
                NotificationCenter.default.post(name: R.NotificationName.GameCoverChange, object: nil)
            }
        }
    }

    private func downloadCover(client: RommClient, rom: RommRom) async -> Data? {
        if let path = rom.preferredCoverPath,
           let request = client.assetDownloadRequest(downloadPath: path),
           let data = try? await client.data(for: request),
           !data.isEmpty {
            return data
        }
        guard let urlCover = rom.url_cover, !urlCover.isEmpty else { return nil }
        if urlCover.hasPrefix("http"), let url = URL(string: urlCover) {
            return try? await client.data(for: URLRequest(url: url))
        }
        if let request = client.assetDownloadRequest(downloadPath: urlCover) {
            return try? await client.data(for: request)
        }
        return nil
    }

    private func applyMetadata(gameId: String, rom: RommRom) async {
        await MainActor.run {
            guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else { return }
            var metadata = GameMetadata.getGameMetadata(game: game) ?? GameMetadata()
            if let name = rom.name, !name.isEmpty {
                metadata.displayName = name
                metadata.fullName = name
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
            if let ratings = rom.metadatum?.age_ratings, let esrp = Self.esrp(from: ratings) {
                metadata.ratingId = esrp.ratingId
            }
            metadata.persist(to: game)
            game.updateExtra(key: ExtraKey.hasQueryMetadata.rawValue, value: true)
        }
    }

    private func applyPlayTime(gameId: String, client: RommClient, rom: RommRom) async {
        let sessions = (try? await client.playSessions(romID: rom.id)) ?? []
        let remoteTotal = Double(sessions.reduce(0) { $0 + $1.duration_ms })
        let lastPlayed = rom.rom_user?.last_played ?? sessions.compactMap(\.end_time).max()
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
        guard let context, !context.skip else { return }
        let remote = (try? await client.saves(romID: romId))?
            .sorted(by: { ($0.updated_at ?? .distantPast) > ($1.updated_at ?? .distantPast) })
            .first
        guard let remote,
              let request = client.saveContentRequest(saveID: remote.id),
              let data = try? await client.data(for: request) else { return }
        let directory = context.url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try data.write(to: context.url, options: .atomic)
            if let date = remote.updated_at {
                try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: context.url.path)
            }
            SyncManager.upload(localFilePath: context.url.path)
        } catch {
            Log.debug("[RomM] write save failed: \(error)")
        }
    }

    private func pullStates(gameId: String, client: RommClient, romId: Int) async {
        guard let remoteStates = try? await client.states(romID: romId) else { return }
        for remote in remoteStates {
            guard let request = client.assetDownloadRequest(downloadPath: remote.download_path),
                  let data = try? await client.data(for: request) else { continue }
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
        try await pushCoverAndMetadata(client: client, snapshot: snapshot)
        try await pushPlayTime(client: client, snapshot: snapshot)
        await pushSave(client: client, snapshot: snapshot)
        await pushStates(client: client, snapshot: snapshot)
    }

    private func pushCoverAndMetadata(client: RommClient, snapshot: PushSnapshot) async throws {
        var artwork: (fileName: String, data: Data)?
        if let cover = snapshot.coverData, !cover.isEmpty {
            artwork = (fileName: "cover.jpg", data: cover)
        }
        try await client.updateRom(romID: snapshot.romId,
                                   name: snapshot.displayName,
                                   summary: snapshot.overview,
                                   artwork: artwork)
    }

    private func pushPlayTime(client: RommClient, snapshot: PushSnapshot) async throws {
        let delta = Int(snapshot.totalPlayDuration - snapshot.playDurationPushed)
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
              let data = try? Data(contentsOf: snapshot.saveURL) else { return }
        do {
            try await client.uploadSave(romID: snapshot.romId,
                                        emulator: nil,
                                        fileName: snapshot.saveURL.lastPathComponent,
                                        fileData: data)
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
            do {
                _ = try await client.uploadState(romID: snapshot.romId,
                                                 emulator: nil,
                                                 fileName: remoteName,
                                                 fileData: data,
                                                 screenshot: screenshot)
            } catch {
                Log.debug("[RomM] upload state failed (\(state.name)): \(error)")
            }
        }
    }

    // MARK: - Mapping

    private static func esrp(from ratings: [String]) -> ESRP? {
        let joined = ratings.joined(separator: " ").lowercased()
        if joined.contains("adults only") || joined.contains("esrb: ao") || joined.contains("esrb ao") { return .AO }
        if joined.contains("everyone 10") || joined.contains("e10") { return .E10 }
        if joined.contains("early childhood") || joined.contains("esrb: ec") { return .EC }
        if joined.contains("kids to adults") || joined.contains("k-a") || joined.contains("k–a") { return .K_A }
        if joined.contains("rating pending") && joined.contains("17") { return .RP17 }
        if joined.contains("rating pending") || joined.contains("esrb: rp") { return .RP }
        if joined.contains("mature") || joined.contains("esrb: m") { return .M }
        if joined.contains("teen") || joined.contains("esrb: t") { return .T }
        if joined.contains("everyone") || joined.contains("esrb: e") { return .E }
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
