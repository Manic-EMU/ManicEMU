//
//  CloudDriveConnetor.swift
//  ManicEmu
//
//  Created by Max on 2025/1/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import CloudServiceKit
import RealmSwift

class CloudDriveConnetor {
    static let shard = CloudDriveConnetor()
    private var currentConnector: CloudServiceConnector?
    
    private init(){}
    
    
    private func genConnector(for type: ImportServiceType) -> CloudServiceConnector? {
        let connector: CloudServiceConnector
        let cllbackUrl = R.Strings.OAuthCallbackHost
        switch type {
        case .googledrive:
            connector = GoogleDriveConnector(appId: R.Cipher.GoogleDriveAppId, appSecret: "", callbackUrl: R.Strings.OAuthGoogleDriveCallbackHost + "://")
        case .dropbox:
            connector = DropboxConnector(appId: R.Cipher.DropboxAppKey, appSecret: R.Cipher.DropboxAppSecret, callbackUrl: cllbackUrl + "://dropbox", responseType: "token")
        case .onedrive:
            connector = OneDriveConnector(appId: R.Cipher.OneDriveAppId, appSecret: "", callbackUrl: R.Strings.OAuthOneDriveCallbackHost + "://auth")
        case .baiduyun:
            connector = BaiduPanConnector(appId: R.Cipher.BaiduYunAppKey, appSecret: R.Cipher.BaiduYunSecretKey, callbackUrl: cllbackUrl + "://baiduyun")
        case .aliyun:
            connector = AliyunDriveConnector(appId: R.Cipher.AliYunAppId, appSecret: R.Cipher.AliYunSecrectKey, callbackUrl: cllbackUrl + "://aliyun")
        default:
            return nil
        }
        
        return connector
    }
    
    func connect(service: ImportService, in scene: UIWindowScene?) {
        Log.debug("开始连接云服务:\(service.title)")
        currentConnector = genConnector(for: service.type)
        guard let connector = currentConnector else { return }
        guard let topViewController = topViewController(in: scene) else { return }
        connector.connect(viewController: topViewController) { [weak self] connectResult in
            switch connectResult {
            case .success(let connectSuccess):
                UIView.makeLoading()
                //连接成功则存储连接信息
                let credential = connectSuccess.credential
                Log.debug("云服务:\(service.title) 连接成功 oauthToken:\(credential.oauthToken), refreshToken:\(credential.oauthRefreshToken)")
                let storeService = ImportService.genCloudService(type: service.type, token: credential.oauthToken, refreshToken: credential.oauthRefreshToken)
                
                let group = DispatchGroup()
                var aliyunDriveId: String? = nil
                //阿里云盘的话需要额外获取根目录的drive_id
                if storeService.type == .aliyun, let provider = storeService.cloudDriveProvider as? AliyunDriveServiceProvider {
                    group.enter()
                    provider.getDriveInfo { driveInfoResult in
                        switch driveInfoResult {
                        case .success(let driveInfoSuccess):
                            aliyunDriveId = driveInfoSuccess.defaultDriveId
                        case .failure(_):
                            UIView.hideLoading()
                            UIView.makeToast(message: R.string.localizable.importAliyunNotGetDriveId())
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: DispatchQueue.main) {
                    if storeService.type == .aliyun {
                        //如果阿里云driveId没有获取到 那么就没有继续的必要
                        if aliyunDriveId == nil {
                            return
                        } else {
                            storeService.host = aliyunDriveId
                        }
                    }
                    
                    //获取用户信息
                    storeService.cloudDriveProvider?.getCurrentUserInfo(completion: { userResult in
                        switch userResult {
                        case .success(let userSuccess):
                            //填充用户信息
                            storeService.detail = userSuccess.username
                            storeService.extras = userSuccess.json.jsonString()
                            Log.debug("云服务:\(service.title) 获取用户信息成功 \(storeService.extras ?? "")")
                        case .failure(let userFailure):
                            Log.error("云服务:\(service.title) 获取用户信息失败 \(userFailure)")
                            self?.currentConnector = nil
                            return
                        }
                        //数据存储成功
                        ImportService.change { realm in
                            realm.add(storeService)
                        }
                        UIView.hideLoading()
                        UIView.makeToast(message: R.string.localizable.toastConnectCloudDriveSuccess(storeService.title))
                        self?.currentConnector = nil
                    })
                }
            case .failure(let connectFailure):
                Log.error("云服务:\(service.title) 连接失败 \(connectFailure)")
                UIView.makeAlert(title: R.string.localizable.errorConnectCloudDrive(),
                                 detail: R.string.localizable.reasonConncetCloudDriveFail())
                self?.currentConnector = nil
            }
        }
    }
    
    func renewToken(service: ImportService, provider: CloudServiceProvider, completion: (()->Void)? = nil) {
        guard let refreshToken = service.refreshToken else {
            completion?()
            return
        }
        currentConnector = genConnector(for: service.type)
        if service.type == .baiduyun {
            //百度网盘只要设置handler了就可以 过期再续token
            provider.refreshAccessTokenHandler = { [weak self] callback in
                guard let self = self else { return }
                Log.debug("开始刷新\(service.title) token")
                self.currentConnector?.renewToken(with: refreshToken, completion: { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let token):
                        Log.debug("\(service.title) token刷新成功")
                        //更新数据库
                        DispatchQueue.main.async {
                            ImportService.change { realm in
                                service.token = token.credential.oauthToken
                                if !token.credential.oauthRefreshToken.isEmpty {
                                    service.refreshToken = token.credential.oauthRefreshToken
                                }
                            }
                        }
                        let credential = URLCredential(user: "user", password: token.credential.oauthToken, persistence: .permanent)
                        callback?(.success(credential))
                    case .failure(let error):
                        Log.debug("\(service.title) token刷新失败:\(error)")
                        callback?(.failure(error))
                    }
                    self.currentConnector = nil
                })
            }
            DispatchQueue.main.asyncAfter(delay: 0.35) {
                completion?()
            }
        } else if service.type == .googledrive || service.type == .dropbox || service.type == .onedrive || service.type == .aliyun {
            Log.debug("开始刷新\(service.title) token")
            //其他网盘直接就开始更新token
            currentConnector?.renewToken(with: refreshToken) { result in
                switch result {
                case .success(let token):
                    Log.debug("\(service.title) token刷新成功")
                    //更新数据库
                    DispatchQueue.main.async {
                        ImportService.change { realm in
                            service.token = token.credential.oauthToken
                            if !token.credential.oauthRefreshToken.isEmpty {
                                service.refreshToken = token.credential.oauthRefreshToken
                            }
                        }
                    }
                    let credential = URLCredential(user: "user", password: token.credential.oauthToken, persistence: .permanent)
                    provider.credential = credential
                case .failure(let error):
                    Log.debug("\(service.title) token刷新失败:\(error)")
                }
                completion?()
            }
        }
    }
}
