//
//  RommServiceProvider.swift
//  ManicEmu
//
//  Created by Chris Habibi on 6/29/26.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import CloudServiceKit

class RommServiceProvider: CloudServiceProvider {
    var delegate: CloudServiceProviderDelegate?
    var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    var credential: URLCredential?
    var name: String { "RomM" }

    private let client: RommClient?

    let serviceId: String

    private let romContentPathTemplate = "/api/roms/{romID}/content/{fileName}"

    private func romContentPath(romID: Int, fileName: String) -> String {
        romContentPathTemplate
            .replacingOccurrences(of: "{romID}", with: "\(romID)")
            .replacingOccurrences(of: "{fileName}", with: fileName)
    }

    var rootItem: CloudItem {
        CloudItem(id: name, name: name, path: "/", isDirectory: true)
    }

    required init(credential: URLCredential?) {
        fatalError("Use init(service:)")
    }

    init(service: ImportService) {
        self.serviceId = "\(service.id)"
        self.client = RommClient(scheme: service.scheme ?? "http",
                                 host: service.host ?? "",
                                 port: service.port,
                                 user: service.user,
                                 password: service.password)
    }

    func contentsOfDirectory(_ directory: CloudItem,
                             completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        guard let client else {
            completion(.failure(ImportError.lanServiceInitFailed(serviceName: name)))
            return
        }
        Task {
            do {
                let items: [CloudItem]
                if directory.path == "/" {
                    items = try await client.platforms().map { platform in
                        CloudItem(id: "\(platform.id)",
                                  name: platform.name,
                                  path: "/\(platform.id)",
                                  isDirectory: true)
                    }
                } else {
                    let platformID = Int(directory.id) ?? 0
                    items = try await client.roms(platformID: platformID).map { rom in
                        let item = CloudItem(id: "\(rom.id)/\(rom.fs_name)",
                                             name: rom.fs_name,
                                             path: romContentPath(romID: rom.id, fileName: rom.fs_name),
                                             isDirectory: false)
                        item.size = rom.fs_size_bytes ?? 0
                        return item
                    }
                }
                await MainActor.run { completion(.success(items)) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    func downloadableRequest(of item: CloudItem) -> URLRequest? {
        guard !item.isDirectory else { return nil }
        return client?.request(path: item.path)
    }


    func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {}

    func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {}

    func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {}

    func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {}

    func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {}

    func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {}

    func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {}

    func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {}

    func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {}

    func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {}

    func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {}

    static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? { nil }
}
