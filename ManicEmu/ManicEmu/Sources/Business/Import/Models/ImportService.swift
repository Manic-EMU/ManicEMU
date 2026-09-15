//
//  ImportService.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift
import CloudServiceKit
import IceCream

extension ImportService: CKRecordConvertible & CKRecordRecoverable { }

enum ImportServiceType: Int, PersistableEnum {
    case files, wifi, paste, googledrive, dropbox, onedrive, baiduyun, aliyun, samba, webdav, multiDisc, romPatcher, romm
}

class ImportService: Object, ObjectUpdatable {
    @Persisted(primaryKey: true) var id = PersistedKit.incrementID
    @Persisted var type: ImportServiceType
    ///如果是云服务则存储的是userInfo
    @Persisted var extras: String?
    
    //for cloud server
    @Persisted var detail: String?
    @Persisted var token: String?
    @Persisted var refreshToken: String?
    
    //for lan Serve
    @Persisted var scheme: String?
    @Persisted var host: String? //aliyun会存储默认根目录ID
    @Persisted var port: Int?
    @Persisted var path: String?
    @Persisted var user: String?
    @Persisted var password: String?
    
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
    
    static func genService(type: ImportServiceType,
                           detail: String? = nil,
                           token: String? = nil,
                           refreshToken: String? = nil,
                           host: String? = nil,
                           user: String? = nil,
                           password: String? = nil,
                           extras: String? = nil) -> ImportService  {
        let service = ImportService()
        service.type = type
        service.extras = extras
        service.detail = detail
        service.token = token
        service.refreshToken = refreshToken
        service.host = host
        service.user = user
        service.password = password
        return service
    }
    
    static func genCloudService(type: ImportServiceType,
                                detail: String? = nil,
                                token: String? = nil,
                                refreshToken: String? = nil,
                                extras: String? = nil) -> ImportService {
        return genService(type: type, detail: detail, token: token, refreshToken: refreshToken, extras: extras)
    }
    
    static func genLanService(type: ImportServiceType,
                              detail: String? = nil,
                              host: String? = nil,
                              user: String? = nil,
                              password: String? = nil,
                              extras: String? = nil) -> ImportService {
        return genService(type: type, detail: detail, host: host, user: user, password: password, extras: extras)
    }
    
    var title: String {
        switch type {
        case .files:
            R.string.localizable.importServiceListFilesTitle()
        case .wifi:
            R.string.localizable.importServiceListWiFiTitle()
        case .paste:
            R.string.localizable.importServiceListPasteTitle()
        case .googledrive:
            R.string.localizable.googleDrive()
        case .dropbox:
            R.string.localizable.dropbox()
        case .onedrive:
            R.string.localizable.oneDrive()
        case .baiduyun:
            R.string.localizable.baiduYun()
        case .aliyun:
            R.string.localizable.aliYun()
        case .samba:
            "SMB"
        case .webdav:
            "WebDav"
        case .multiDisc:
            R.string.localizable.multiDiscBuilder()
        case .romPatcher:
            "RomPatcher"
        case .romm:
            "Romm"
        }
    }
    
    lazy var iconImage: UIImage = {
        switch type {
        case .files:
            R.image.import_file_icon()!
        case .wifi:
            R.image.import_wifi_icon()!
        case .paste:
            R.image.import_paste_icon()!
        case .googledrive:
            R.image.import_google_drive()!
        case .dropbox:
            R.image.import_dropbox()!
        case .onedrive:
            R.image.import_onecloud()!
        case .baiduyun:
            R.image.import_baiduyun()!
        case .aliyun:
            R.image.import_aliyun()!
        case .samba:
            R.image.import_smb()!
        case .webdav:
            R.image.import_webdav()!
        case .multiDisc:
            R.image.import_multi_disc_icon()!
        case .romPatcher:
            R.image.import_rom_patcher()!
        case .romm:
            R.image.import_romm()!
        }
    }()
    
    var iconCornerRadius: Double {
        switch type {
        case .files:
            Constants.Size.CornerRadiusMin
        case .wifi, .paste, .googledrive, .dropbox, .onedrive, .baiduyun, .aliyun, .multiDisc, .romPatcher, .romm:
            Constants.Size.CornerRadiusTiny
        case .samba, .webdav:
            0
        }
    }
    
    var iconBackgroundColor: UIColor {
        switch type {
        case .files, .wifi, .paste, .googledrive, .dropbox, .onedrive, .baiduyun, .aliyun, .multiDisc, .romPatcher, .romm:
            Constants.Color.BackgroundPrimary
        case .samba, .webdav:
            UIColor.clear
        }
    }
    
    var iconBorderColor: UIColor {
        switch type {
        case .files, .wifi, .paste, .googledrive, .dropbox, .onedrive, .baiduyun, .aliyun, .multiDisc, .romPatcher, .romm:
            Constants.Color.Border
        case .samba, .webdav:
            UIColor.clear
        }
    }
    
    var cloudDriveProvider: CloudServiceProvider? {
        guard let token = token else { return nil }
        let provider: CloudServiceProvider?
        switch type {
        case .googledrive:
            provider = GoogleDriveServiceProvider(credential: URLCredential(user: "user", password: token, persistence: .permanent))
        case .dropbox:
            provider = DropboxServiceProvider(credential: URLCredential(user: "user", password: token, persistence: .permanent))
        case .onedrive:
            provider = OneDriveServiceProvider(credential: URLCredential(user: "user", password: token, persistence: .permanent))
        case .baiduyun:
            provider = BaiduPanServiceProvider(credential: URLCredential(user: "user", password: token, persistence: .permanent))
        case .aliyun:
            let aliyunDriveServiceProvider = AliyunDriveServiceProvider(credential: URLCredential(user: "user", password: token, persistence: .permanent))
            aliyunDriveServiceProvider.driveId = host ?? ""
            provider = aliyunDriveServiceProvider
        case .samba:
            provider = SMBServiceProvider(service: self)
        default:
            return nil
        }
        return provider
    }
    var lanDriveProvider: CloudServiceProvider? {
        let provider: CloudServiceProvider?
        switch type {
        case .samba:
            provider = SMBServiceProvider(service: self)
        case .webdav:
            provider = WebDavServiceProvider(service: self)
        case .romm:
            provider = RommServiceProvider(service: self)
        default:
            return nil
        }
        return provider
    }
    
    func getExtra(key: String) -> Any? {
        if let extras {
            return Self.getExtra(extras: extras, key: key)
        }
        return nil
    }
    
    func updateExtra(key: String, value: Any?) {
        if let extras, let data = Self.updateExtra(extras: extras, key: key, value: value) {
            Self.change { realm in
                self.extras = data.string(encoding: .utf8)
            }
        } else if let data = [key: value].jsonString() {
            Self.change { realm in
                self.extras = data
            }
        }
    }
}
