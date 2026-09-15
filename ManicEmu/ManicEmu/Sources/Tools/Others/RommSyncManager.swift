//
//  RommSyncManager.swift
//  ManicEmu
//
//  Created by Chris Habibi on 6/29/26.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import RealmSwift
import IceCream

final class RommSyncManager {
    static let shared = RommSyncManager()
    private init() {}

    private static let pendingLinksKey = "RomMPendingSaveLinks"
    private static let stateFileSuffix = ".manicstate"
    private static let timeTolerance: TimeInterval = 2

    static func registerDownloadedRom(fileName: String, romId: Int, serviceId: String) {
        var map = UserDefaults.standard.dictionary(forKey: pendingLinksKey) as? [String: [String: Any]] ?? [:]
        map[fileName] = ["romId": romId, "serviceId": serviceId]
        UserDefaults.standard.set(map, forKey: pendingLinksKey)
    }

    private static func consumePendingLink(fileName: String) -> (romId: Int, serviceId: String)? {
        guard var map = UserDefaults.standard.dictionary(forKey: pendingLinksKey) as? [String: [String: Any]],
              let entry = map[fileName],
              let romId = entry["romId"] as? Int,
              let serviceId = entry["serviceId"] as? String else { return nil }
        map[fileName] = nil
        UserDefaults.standard.set(map, forKey: pendingLinksKey)
        return (romId, serviceId)
    }

    private static func hasPendingLink(fileName: String) -> Bool {
        guard let map = UserDefaults.standard.dictionary(forKey: pendingLinksKey) as? [String: [String: Any]] else { return false }
        return map[fileName] != nil
    }

    @MainActor
    func syncAfterImport(gameId: String) {
        guard isConfigured() else { return }
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId) else { return }
        guard Self.hasPendingLink(fileName: game.fileName) else { return }
        guard let snapshot = makeSnapshot(game: game) else { return }
        Task.detached {
            guard let (client, romId) = await self.resolve(snapshot) else { return }
            await self.fullSync(snapshot, client: client, romId: romId)
        }
    }

    enum SyncOutcome {
        case success
        case notConnected
        case noMatch
    }

    /// If RomM is configured, then show the new UI
    @MainActor
    func isConfigured() -> Bool {
        !Database.realm.objects(ImportService.self).where({ $0.type == .romm && !$0.isDeleted }).isEmpty
    }

    @MainActor
    func syncAllOnLaunch() {
        guard isConfigured() else { return }
        guard Settings.defalut.getExtraBool(key: ExtraKey.rommSyncOnLaunch.rawValue) ?? true else { return }
        Task.detached(priority: .utility) {
            let linkedIds: [String] = {
                let realm = Database.realm
                return realm.objects(Game.self)
                    .where { !$0.isDeleted }
                    .filter { $0.rommRomId != nil }
                    .map { $0.id }
            }()
            guard !linkedIds.isEmpty else { return }

            let snapshots: [GameSnapshot] = await MainActor.run {
                linkedIds.compactMap { id in
                    Database.realm.object(ofType: Game.self, forPrimaryKey: id)
                        .flatMap { self.makeSnapshot(game: $0) }
                }
            }

            for snapshot in snapshots {
                guard let (client, romId) = await self.resolve(snapshot) else { continue }
                await self.fullSync(snapshot, client: client, romId: romId)
            }
        }
    }

    @MainActor
    func manualSync(game: Game) async -> SyncOutcome {
        guard let snapshot = makeSnapshot(game: game) else { return .notConnected }
        switch await resolveForManualSync(snapshot) {
        case .notConnected: return .notConnected
        case .noMatch: return .noMatch
        case .resolved(let client, let romId):
            await fullSync(snapshot, client: client, romId: romId)
            return .success
        }
    }

    @MainActor
    func manualSync(game: Game, states: [GameSaveState]) async -> SyncOutcome {
        guard let snapshot = makeSnapshot(game: game) else { return .notConnected }
        let selectedNames = Set(states.map { $0.name })
        let selected = snapshot.states.filter { selectedNames.contains($0.name) }
        switch await resolveForManualSync(snapshot) {
        case .notConnected: return .notConnected
        case .noMatch: return .noMatch
        case .resolved(let client, let romId):
            await pushStates(client: client, romId: romId, snap: snapshot, states: selected)
            return .success
        }
    }

    private func fullSync(_ snap: GameSnapshot, client: RommClient, romId: Int) async {
        if snap.supportsBatterySave {
            await syncBatterySave(client: client, romId: romId, snap: snap, isClosing: false)
        }
        await pullStates(client: client, romId: romId, snap: snap)
        await pushStates(client: client, romId: romId, snap: snap)
    }

    @MainActor
    func syncOnClose(game: Game) {
        guard Settings.defalut.getExtraBool(key: ExtraKey.rommSyncOnGameExit.rawValue) ?? true else { return }
        guard let snapshot = makeSnapshot(game: game) else { return }
        Task.detached { await self.push(snapshot) }
    }

    private struct ServiceInfo: Sendable {
        let id: String
        let scheme: String
        let host: String
        let port: Int?
        let user: String?
        let password: String?

        func makeClient() -> RommClient? {
            RommClient(scheme: scheme, host: host, port: port, user: user, password: password)
        }
    }

    private struct StateSnapshot: Sendable {
        let name: String
        let date: Date
        let dataURL: URL?
        let coverURL: URL?
    }

    private struct GameSnapshot: Sendable {
        let gameId: String
        let searchName: String
        let fileName: String
        let saveURL: URL
        let supportsBatterySave: Bool
        let saveWatermark: Date?
        let rommRomId: Int?
        let rommServiceId: String?
        let states: [StateSnapshot]
        let services: [ServiceInfo]

        func service(for id: String?) -> ServiceInfo? {
            guard let id else { return nil }
            return services.first { $0.id == id }
        }
    }

    @MainActor
    private func makeSnapshot(game: Game) -> GameSnapshot? {
        let services = Database.realm.objects(ImportService.self)
            .where({ $0.type == .romm && !$0.isDeleted })
            .map { ServiceInfo(id: "\($0.id)",
                               scheme: $0.scheme ?? "http",
                               host: $0.host ?? "",
                               port: $0.port,
                               user: $0.user,
                               password: $0.password) }
        guard !services.isEmpty else { return nil }

        let states = game.gameSaveStates.map {
            StateSnapshot(name: $0.name, date: $0.date,
                          dataURL: $0.stateData?.filePath,
                          coverURL: $0.stateCover?.filePath)
        }
        let watermark = game.getExtraDouble(key: ExtraKey.rommSaveSyncedAt.rawValue).map { Date(timeIntervalSince1970: $0) }

        return GameSnapshot(
            gameId: game.id,
            searchName: game.aliasName ?? game.name,
            fileName: game.fileName,
            saveURL: game.gameSaveUrl,
            supportsBatterySave: game.gameType != ._3ds && game.gameType != .psp,
            saveWatermark: watermark,
            rommRomId: game.rommRomId,
            rommServiceId: game.rommServiceId,
            states: Array(states),
            services: Array(services)
        )
    }

    private func resolve(_ snap: GameSnapshot) async -> (client: RommClient, romId: Int)? {
        if let romId = snap.rommRomId,
           let svc = snap.service(for: snap.rommServiceId) ?? snap.services.first,
           let client = svc.makeClient() {
            return (client, romId)
        }
        if let pending = Self.consumePendingLink(fileName: snap.fileName),
           let svc = snap.service(for: pending.serviceId) ?? snap.services.first,
           let client = svc.makeClient() {
            await persistLink(gameId: snap.gameId, romId: pending.romId, serviceId: svc.id)
            return (client, pending.romId)
        }
        for svc in snap.services {
            guard let client = svc.makeClient() else { continue }
            guard let roms = try? await client.searchRoms(term: snap.searchName) else { continue }
            if let rom = roms.first(where: { $0.fs_name.caseInsensitiveCompare(snap.fileName) == .orderedSame }) {
                await persistLink(gameId: snap.gameId, romId: rom.id, serviceId: svc.id)
                return (client, rom.id)
            }
        }
        return nil
    }

    private enum ResolveOutcome {
        case resolved(client: RommClient, romId: Int)
        case notConnected
        case noMatch
    }

    private func resolveForManualSync(_ snap: GameSnapshot) async -> ResolveOutcome {
        if let romId = snap.rommRomId,
           let svc = snap.service(for: snap.rommServiceId) ?? snap.services.first,
           let client = svc.makeClient() {
            do {
                _ = try await client.saves(romID: romId)
                return .resolved(client: client, romId: romId)
            } catch {
                return .notConnected
            }
        }
        if let pending = Self.consumePendingLink(fileName: snap.fileName),
           let svc = snap.service(for: pending.serviceId) ?? snap.services.first,
           let client = svc.makeClient() {
            await persistLink(gameId: snap.gameId, romId: pending.romId, serviceId: svc.id)
            return .resolved(client: client, romId: pending.romId)
        }
        var reachedAnyServer = false
        for svc in snap.services {
            guard let client = svc.makeClient() else { continue }
            do {
                let roms = try await client.searchRoms(term: snap.searchName)
                reachedAnyServer = true
                if let rom = roms.first(where: { $0.fs_name.caseInsensitiveCompare(snap.fileName) == .orderedSame }) {
                    await persistLink(gameId: snap.gameId, romId: rom.id, serviceId: svc.id)
                    return .resolved(client: client, romId: rom.id)
                }
            } catch {
                continue
            }
        }
        return reachedAnyServer ? .noMatch : .notConnected
    }


    private func push(_ snap: GameSnapshot) async {
        guard let (client, romId) = await resolve(snap) else { return }
        if snap.supportsBatterySave {
            await syncBatterySave(client: client, romId: romId, snap: snap, isClosing: true)
        }
        await pushStates(client: client, romId: romId, snap: snap)
    }


    private func syncBatterySave(client: RommClient, romId: Int, snap: GameSnapshot, isClosing: Bool) async {
        let remote = (try? await client.saves(romID: romId))?
            .sorted(by: { ($0.updated_at ?? .distantPast) > ($1.updated_at ?? .distantPast) })
            .first
        let localExists = FileManager.default.fileExists(atPath: snap.saveURL.path)
        let localDate = (try? FileManager.default.attributesOfItem(atPath: snap.saveURL.path)[.modificationDate]) as? Date

        switch (localExists, remote) {
        case (false, nil):
            return
        case (false, .some(let remote)):
            await downloadSave(client: client, save: remote, to: snap.saveURL, gameId: snap.gameId)
        case (true, nil):
            await uploadSave(client: client, romId: romId, snap: snap)
        case (true, .some(let remote)):
            let remoteDate = remote.updated_at
            let watermark = snap.saveWatermark
            let localChanged = changed(localDate, since: watermark)
            let remoteChanged = changed(remoteDate, since: watermark)

            if localChanged && remoteChanged {
                await promptBatteryConflict(client: client, romId: romId, save: remote,
                                            snap: snap, localDate: localDate, remoteDate: remoteDate)
            } else if remoteChanged {
                await downloadSave(client: client, save: remote, to: snap.saveURL, gameId: snap.gameId)
            } else if localChanged {
                await uploadSave(client: client, romId: romId, snap: snap)
            } else if let localDate, let remoteDate {
                if isClosing, localDate > remoteDate.addingTimeInterval(Self.timeTolerance) {
                    await uploadSave(client: client, romId: romId, snap: snap)
                } else if !isClosing, remoteDate > localDate.addingTimeInterval(Self.timeTolerance) {
                    await downloadSave(client: client, save: remote, to: snap.saveURL, gameId: snap.gameId)
                }
            }
        }
    }

    private func changed(_ date: Date?, since watermark: Date?) -> Bool {
        guard let date else { return false }
        guard let watermark else { return true }
        return date > watermark.addingTimeInterval(Self.timeTolerance)
    }

    private func downloadSave(client: RommClient, save: RommSave, to saveURL: URL, gameId: String) async {
        guard let request = client.saveContentRequest(saveID: save.id),
              let data = try? await client.data(for: request) else { return }
        let directory = saveURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try data.write(to: saveURL, options: .atomic)
            if let date = save.updated_at {
                try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: saveURL.path)
            }
            await stampSyncTime(gameId: gameId)
        } catch {
            Log.debug("[RomM Sync] write save failed: \(error)")
        }
    }

    private func uploadSave(client: RommClient, romId: Int, snap: GameSnapshot) async {
        guard let data = try? Data(contentsOf: snap.saveURL) else { return }
        do {
            try await client.uploadSave(romID: romId,
                                        emulator: nil,
                                        fileName: snap.saveURL.lastPathComponent,
                                        fileData: data)
            await stampSyncTime(gameId: snap.gameId)
        } catch {
            Log.debug("[RomM Sync] upload save failed: \(error)")
        }
    }

    @MainActor
    private func promptBatteryConflict(client: RommClient, romId: Int, save: RommSave,
                                       snap: GameSnapshot, localDate: Date?, remoteDate: Date?) async {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let localText = localDate.map { formatter.string(from: $0) } ?? "—"
        let remoteText = remoteDate.map { formatter.string(from: $0) } ?? "—"
        let detail = R.string.localizable.rommSaveConflictDetail(snap.fileName, localText, remoteText)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            let finish = { if !resumed { resumed = true; continuation.resume() } }
            UIView.makeAlert(title: R.string.localizable.rommSaveConflictTitle(),
                             detail: detail,
                             cancelTitle: R.string.localizable.rommSaveConflictKeepRemote(),
                             confirmTitle: R.string.localizable.rommSaveConflictKeepLocal(),
                             enableForceHide: false,
                             cancelAction: {
                Task {
                    await self.downloadSave(client: client, save: save, to: snap.saveURL, gameId: snap.gameId)
                    finish()
                }
            },
                             confirmAction: {
                Task {
                    await self.uploadSave(client: client, romId: romId, snap: snap)
                    finish()
                }
            })
        }
    }


    private func pullStates(client: RommClient, romId: Int, snap: GameSnapshot) async {
        guard let remoteStates = try? await client.states(romID: romId) else { return }
        let localKeys = Set(snap.states.map { normalizedKey($0.name) })
        for remote in remoteStates {
            guard !localKeys.contains(normalizedKey(remote.file_name)) else { continue }
            guard let request = client.assetDownloadRequest(downloadPath: remote.download_path),
                  let data = try? await client.data(for: request) else { continue }
            var coverData: Data?
            if let screenshot = remote.screenshot,
               let coverRequest = client.assetDownloadRequest(downloadPath: screenshot.download_path) {
                coverData = try? await client.data(for: coverRequest)
            }
            await createLocalState(gameId: snap.gameId,
                                   name: deriveStateName(from: remote.file_name),
                                   date: remote.updated_at ?? Date(),
                                   data: data,
                                   cover: coverData)
        }
    }

    private func pushStates(client: RommClient, romId: Int, snap: GameSnapshot, states: [StateSnapshot]? = nil) async {
        guard let remoteStates = try? await client.states(romID: romId) else { return }
        let remoteKeys = Set(remoteStates.map { normalizedKey($0.file_name) })
        for state in (states ?? snap.states) {
            guard !remoteKeys.contains(normalizedKey(state.name)) else { continue }
            guard let dataURL = state.dataURL, let data = try? Data(contentsOf: dataURL) else { continue }
            var screenshot: (fileName: String, data: Data)?
            if let coverURL = state.coverURL, let coverData = try? Data(contentsOf: coverURL) {
                screenshot = (fileName: "\(state.name).jpg", data: coverData)
            }
            _ = try? await client.uploadState(romID: romId,
                                              emulator: nil,
                                              fileName: "\(state.name)\(Self.stateFileSuffix)",
                                              fileData: data,
                                              screenshot: screenshot)
        }
    }

    private func normalizedKey(_ raw: String) -> String {
        var value = raw
        if value.hasSuffix(Self.stateFileSuffix) {
            value = String(value.dropLast(Self.stateFileSuffix.count))
        }
        return value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func deriveStateName(from fileName: String) -> String {
        if fileName.hasSuffix(Self.stateFileSuffix) {
            return String(fileName.dropLast(Self.stateFileSuffix.count))
        }
        return fileName
    }


    @MainActor
    private func persistLink(gameId: String, romId: Int, serviceId: String) {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId) else { return }
        game.rommRomId = romId
        game.rommServiceId = serviceId
    }

    @MainActor
    private func stampSyncTime(gameId: String) {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId) else { return }
        game.updateExtra(key: ExtraKey.rommSaveSyncedAt.rawValue, value: Date().timeIntervalSince1970)
    }

    @MainActor
    private func createLocalState(gameId: String, name: String, date: Date, data: Data, cover: Data?) {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameId) else { return }
        guard !game.gameSaveStates.contains(where: { $0.name == name }) else { return }
        Game.change { realm in
            guard let game = realm.object(ofType: Game.self, forPrimaryKey: gameId) else { return }
            let state = GameSaveState()
            state.name = name
            state.type = .manualSaveState
            state.date = date
            if let cover {
                state.stateCover = CreamAsset.create(objectID: state.name, propName: "stateCover", data: cover)
            }
            state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", data: data)
            game.gameSaveStates.append(state)
        }
    }
}
