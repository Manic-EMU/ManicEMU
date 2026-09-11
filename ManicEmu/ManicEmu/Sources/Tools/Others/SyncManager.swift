//
//  SyncManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/12.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import Foundation
import IceCream
import CloudKit

class SyncManager: NSObject {
    static let shared = SyncManager()
    private var realmSyncEngine: SyncEngine?
    var iCloudServiceEnable: Bool? = nil
    private var iCloudAccountChangedNotification: Any?
    
    enum SyncState: String {
        case undefine
        case idle
        case syncing
    }
    
    var hasDownloadTask: Bool {
        FilesSyncManager.shared.hasDownloadTask
    }
    
    var syncState: SyncState {
        FilesSyncManager.shared.syncState
    }
    
    private override init() {
        super.init()
        updateiCloudAccountstatus()
        iCloudAccountChangedNotification = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            self?.updateiCloudAccountstatus()
        }
    }
    
    func startSync() {
        if realmSyncEngine == nil {
            setupRealmSync()
        }
        FilesSyncManager.shared.start()
    }
    
    func stopSync() {
        realmSyncEngine = nil
        FilesSyncManager.shared.stop()
    }
    
    private func setupRealmSync() {
        guard realmSyncEngine == nil else { return }
        IceCream.shared.logAction = { Log.debug($0) }
        let configuration = Database.realm.configuration
        realmSyncEngine = SyncEngine(objects: [
            SyncObject(realmConfiguration: configuration, type: Game.self, uListElementType: GameSaveState.self, vListElementType: GameCheat.self),
            SyncObject(realmConfiguration: configuration, type: GameCheat.self),
            SyncObject(realmConfiguration: configuration, type: Skin.self),
            SyncObject(realmConfiguration: configuration, type: GameSaveState.self),
            SyncObject(realmConfiguration: configuration, type: ImportService.self),
            SyncObject(realmConfiguration: configuration, type: Settings.self),
            SyncObject(realmConfiguration: configuration, type: ControllerMapping.self),
            SyncObject(realmConfiguration: configuration, type: Theme.self),
            SyncObject(realmConfiguration: configuration, type: Trigger.self, uListElementType: TriggerItem.self),
            SyncObject(realmConfiguration: configuration, type: TriggerItem.self),
            SyncObject(realmConfiguration: configuration, type: Prefference.self),
            SyncObject(realmConfiguration: configuration, type: FilesSyncRecord.self)
        ])
        realmSyncEngine?.setupCompletion = { error in
            if let error = error {
                Log.debug("[iCloud Sync]数据库同步初始化结束 error:\(error)")
            } else {
                Skin.polishSkinsAfterRealmSync()
                Log.debug("[iCloud Sync]数据库同步初始化结束")
            }
        }
    }
    
    private func updateiCloudAccountstatus() {
#if !SIDE_LOAD
        CKContainer.default().accountStatus { [weak self] status, error in
            self?.iCloudServiceEnable = status == .available
        }
#endif
    }
    
    static func upload(localFilePath: String) {
        FilesSyncManager.shared.noteLocalChange(path: localFilePath)
    }
    
    static func download(to localFilePath: String, completion: ((Error?) -> Void)? = nil) {
        FilesSyncManager.shared.ensureLocal(at: URL(fileURLWithPath: localFilePath), completion: completion)
    }
    
    static func delete(localFilePath: String) {
        FilesSyncManager.shared.noteLocalRemoval(path: localFilePath)
    }
    
    static func deletePath(localPath: String) {
        FilesSyncManager.shared.noteLocalRemoval(path: localPath)
    }
    
    static func isiCloudFileExist(localFilePath: String, completion: ((Bool) -> Void)? = nil) {
        FilesSyncManager.shared.cloudFileExists(localFilePath: localFilePath, completion: completion)
    }
    
    static func syncDocument() {
        FilesSyncManager.shared.reconcile()
    }
    
    static func convertToLocalUrl(fromCloudUrl: URL) -> URL? {
        guard let relative = FilesSyncPolicy.documentsRelativePath(from: fromCloudUrl) else { return nil }
        return FilesSyncPolicy.localURL(relativePath: relative)
    }
}
