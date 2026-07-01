//
//  RommClient.swift
//  ManicEmu
//
//  Created by Chris Habibi on 6/29/26.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation


struct RommPage<T: Decodable>: Decodable {
    let items: [T]
    let total: Int?
}

struct RommPlatform: Decodable {
    let id: Int
    let name: String
    let rom_count: Int?
}

struct RommRom: Decodable {
    let id: Int
    let name: String?
    let fs_name: String
    let fs_size_bytes: Int64?
}

struct RommScreenshot: Decodable {
    let id: Int
    let download_path: String
}

struct RommSave: Decodable {
    let id: Int
    let rom_id: Int
    let file_name: String
    let file_size_bytes: Int64?
    let download_path: String
    let emulator: String?
    let updated_at: Date?
    let screenshot: RommScreenshot?
}

struct RommState: Decodable {
    let id: Int
    let rom_id: Int
    let file_name: String
    let file_size_bytes: Int64?
    let download_path: String
    let emulator: String?
    let updated_at: Date?
    let screenshot: RommScreenshot?
}


final class RommClient {
    private let baseURL: URL
    private let session: URLSession
    private let authHeader: String
    
    private let PlatformApiStub = "/api/platforms"
    private let RomApiStub = "/api/roms"
    private let SaveApiStub = "/api/saves"
    private let StateApiStub = "/api/states"
    
    var PaginationLimit: Int { 250 }
    
    
    init?(scheme: String, host: String, port: Int?, user: String?, password: String?) {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        guard let url = components.url else { return nil }
        self.baseURL = url

        let raw = "\(user ?? ""):\(password ?? "")"
        guard let token = raw.data(using: .utf8)?.base64EncodedString() else { return nil }
        self.authHeader = "Basic \(token)"
        self.session = .shared
    }

    func request(path: String, query: [URLQueryItem] = []) -> URLRequest? {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                             resolvingAgainstBaseURL: false) else { return nil }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        return req
    }

    /// JSON decoder that understands RomM's UTC ISO-8601 timestamps
    private static let jsonDecoder: JSONDecoder = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = withFraction.date(from: raw) ?? plain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unrecognised RomM date: \(raw)")
        }
        return decoder
    }()

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        guard let req = request(path: path, query: query) else {
            throw URLError(.badURL)
        }
        return try Self.jsonDecoder.decode(T.self, from: await data(for: req))
    }

    func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.userAuthenticationRequired)
        }
        return data
    }

    func platforms() async throws -> [RommPlatform] {
        try await get(PlatformApiStub)
    }

    func roms(platformID: Int) async throws -> [RommRom] {
        // platform_ids and platform_id is kept for backward compatibilty with old RomM versions
        try await fetchAllRoms(baseQuery: [.init(name: "platform_ids", value: "\(platformID)"),
                                           .init(name: "platform_id", value: "\(platformID)")])
    }

    func searchRoms(term: String) async throws -> [RommRom] {
        try await fetchAllRoms(baseQuery: [.init(name: "search_term", value: term)])
    }


    private func fetchAllRoms(baseQuery: [URLQueryItem]) async throws -> [RommRom] {
        var all: [RommRom] = []
        var seen = Set<Int>()
        var offset = 0
        while true {
            var query = baseQuery
            query.append(.init(name: "limit", value: String(PaginationLimit)))
            query.append(.init(name: "offset", value: String(offset)))
            let page: RommPage<RommRom> = try await get(RomApiStub, query: query)
            let fresh = page.items.filter { seen.insert($0.id).inserted }
            all.append(contentsOf: fresh)

            if page.items.count < PaginationLimit { break }
            if fresh.isEmpty { break }
            if let total = page.total, all.count >= total { break }
            offset += PaginationLimit
        }
        return all
    }

    // These functions are not paginated - hopefully you don't have a saves
    func saves(romID: Int) async throws -> [RommSave] {
        try await get(SaveApiStub, query: [.init(name: "rom_id", value: "\(romID)")])
    }

    func states(romID: Int) async throws -> [RommState] {
        try await get(StateApiStub, query: [.init(name: "rom_id", value: "\(romID)")])
    }

    func saveContentRequest(saveID: Int) -> URLRequest? {
        request(path: "\(SaveApiStub)/\(saveID)/content")
    }

    func assetDownloadRequest(downloadPath: String) -> URLRequest? {
        let rawPath = String(downloadPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0])
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.percentEncodedPath = rawPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? rawPath
        guard let url = components.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        return req
    }

    @discardableResult
    func uploadSave(romID: Int,
                    emulator: String?,
                    fileName: String,
                    fileData: Data,
                    screenshot: (fileName: String, data: Data)? = nil) async throws -> RommSave {
        try await upload(stub: SaveApiStub,
                         fileField: "saveFile",
                         romID: romID,
                         emulator: emulator,
                         fileName: fileName,
                         fileData: fileData,
                         screenshot: screenshot)
    }

    @discardableResult
    func uploadState(romID: Int,
                     emulator: String?,
                     fileName: String,
                     fileData: Data,
                     screenshot: (fileName: String, data: Data)? = nil) async throws -> RommState {
        try await upload(stub: StateApiStub,
                         fileField: "stateFile",
                         romID: romID,
                         emulator: emulator,
                         fileName: fileName,
                         fileData: fileData,
                         screenshot: screenshot)
    }

    private func upload<T: Decodable>(stub: String,
                                      fileField: String,
                                      romID: Int,
                                      emulator: String?,
                                      fileName: String,
                                      fileData: Data,
                                      screenshot: (fileName: String, data: Data)?) async throws -> T {
        var query = [URLQueryItem(name: "rom_id", value: "\(romID)"),
                     URLQueryItem(name: "overwrite", value: "true")]
        if let emulator, !emulator.isEmpty {
            query.append(.init(name: "emulator", value: emulator))
        }
        guard var req = request(path: stub, query: query) else { throw URLError(.badURL) }
        
        let boundary = "ManicEmuBoundary-\(romID)-\(fileName.count)-\(fileData.count)"

        var parts: [(name: String, fileName: String, mime: String, data: Data)] = [
            (fileField, fileName, "application/octet-stream", fileData)
        ]
        if let screenshot {
            parts.append(("screenshotFile", screenshot.fileName, "image/png", screenshot.data))
        }
        
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        for part in parts {
            body.append("""
            --\(boundary)\r
            Content-Disposition: form-data; name="\(part.name)"; filename="\(part.fileName)"\r
            Content-Type: \(part.mime)\r
            \r

            """)
            body.append(part.data)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")

        let (data, response) = try await session.upload(for: req, from: body)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.userAuthenticationRequired)
        }
        return try Self.jsonDecoder.decode(T.self, from: data)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
