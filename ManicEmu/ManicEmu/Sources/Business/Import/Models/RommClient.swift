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

struct RommAgeRating: Decodable {
    let rating: String?
    let category: String?

    init(rating: String?, category: String?) {
        self.rating = rating
        self.category = category
    }

    enum CodingKeys: String, CodingKey { case rating, category }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let string = try? container.decode(String.self, forKey: .rating) {
            rating = string
        } else if let number = try? container.decode(Int.self, forKey: .rating) {
            rating = String(number)
        } else {
            rating = nil
        }
        if let string = try? container.decode(String.self, forKey: .category) {
            category = string
        } else if let number = try? container.decode(Int.self, forKey: .category) {
            category = String(number)
        } else {
            category = nil
        }
    }
}

struct RommIGDBMetadata: Decodable {
    let age_ratings: [RommAgeRating]?

    enum CodingKeys: String, CodingKey { case age_ratings }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let objects = try? container.decode([RommAgeRating].self, forKey: .age_ratings) {
            age_ratings = objects
        } else if let strings = try? container.decode([String].self, forKey: .age_ratings) {
            age_ratings = strings.map { RommAgeRating(rating: $0, category: nil) }
        } else {
            age_ratings = nil
        }
    }
}

struct RommMetadatum: Decodable {
    let genres: [String]?
    let franchises: [String]?
    let companies: [String]?
    let age_ratings: [String]?
    let first_release_date: Int64?

    enum CodingKeys: String, CodingKey {
        case genres, franchises, companies, age_ratings, first_release_date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        genres = try? container.decode([String].self, forKey: .genres)
        franchises = try? container.decode([String].self, forKey: .franchises)
        companies = try? container.decode([String].self, forKey: .companies)
        first_release_date = try? container.decode(Int64.self, forKey: .first_release_date)
        if let list = try? container.decode([String].self, forKey: .age_ratings) {
            age_ratings = list
        } else if let one = try? container.decode(String.self, forKey: .age_ratings), !one.isEmpty {
            age_ratings = [one]
        } else if let objects = try? container.decode([RommAgeRating].self, forKey: .age_ratings) {
            age_ratings = objects.compactMap(\.rating)
        } else {
            age_ratings = nil
        }
    }
}

struct RommUser: Decodable {
    let last_played: Date?
}

struct RommRom: Decodable {
    let id: Int
    let name: String?
    let fs_name: String
    let fs_size_bytes: Int64?
    let summary: String?
    let path_cover_small: String?
    let path_cover_large: String?
    let url_cover: String?
    let has_manual: Bool?
    let path_manual: String?
    let url_manual: String?
    let platform_display_name: String?
    let metadatum: RommMetadatum?
    let igdb_metadata: RommIGDBMetadata?
    let rom_user: RommUser?

    enum CodingKeys: String, CodingKey {
        case id, name, fs_name, fs_size_bytes, summary
        case path_cover_small, path_cover_large, url_cover
        case has_manual, path_manual, url_manual
        case platform_display_name, metadatum, igdb_metadata, rom_user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        fs_name = try container.decode(String.self, forKey: .fs_name)
        fs_size_bytes = try container.decodeIfPresent(Int64.self, forKey: .fs_size_bytes)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        path_cover_small = try container.decodeIfPresent(String.self, forKey: .path_cover_small)
        path_cover_large = try container.decodeIfPresent(String.self, forKey: .path_cover_large)
        url_cover = try container.decodeIfPresent(String.self, forKey: .url_cover)
        has_manual = try? container.decode(Bool.self, forKey: .has_manual)
        path_manual = try? container.decode(String.self, forKey: .path_manual)
        url_manual = try? container.decode(String.self, forKey: .url_manual)
        platform_display_name = try container.decodeIfPresent(String.self, forKey: .platform_display_name)
        metadatum = try? container.decode(RommMetadatum.self, forKey: .metadatum)
        igdb_metadata = try? container.decode(RommIGDBMetadata.self, forKey: .igdb_metadata)
        rom_user = try? container.decode(RommUser.self, forKey: .rom_user)
    }

    var preferredCoverPath: String? {
        if let path = path_cover_large, !path.isEmpty { return path }
        if let path = path_cover_small, !path.isEmpty { return path }
        return nil
    }

    /// Local resource path first. `url_manual` is the scraped source (ScreenScraper, etc.).
    var preferredManualPath: String? {
        if let path = path_manual, !path.isEmpty { return path }
        if let path = url_manual, !path.isEmpty { return path }
        return nil
    }
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

struct RommPlaySession: Decodable {
    let id: Int
    let rom_id: Int?
    let duration_ms: Int
    let start_time: Date?
    let end_time: Date?
}

final class RommClient {
    private let baseURL: URL
    private let session: URLSession
    private let authHeader: String

    private let PlatformApiStub = "/api/platforms"
    private let RomApiStub = "/api/roms"
    private let SaveApiStub = "/api/saves"
    private let StateApiStub = "/api/states"
    private let PlaySessionApiStub = "/api/play-sessions"

    var PaginationLimit: Int { 250 }

    init?(scheme: String, host: String, port: Int?, user: String?, password: String?, path: String? = nil) {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        if let path, !path.isEmpty, path != "/" {
            var normalized = path
            if !normalized.hasPrefix("/") { normalized = "/" + normalized }
            if normalized.hasSuffix("/") { normalized.removeLast() }
            components.path = normalized
        }
        guard let url = components.url else { return nil }
        self.baseURL = url
        self.authHeader = Self.makeAuthHeader(user: user, password: password)
        self.session = .shared
    }

    /// Bearer for Client API tokens (`rmm_…`); otherwise HTTP Basic.
    private static func makeAuthHeader(user: String?, password: String?) -> String {
        let trimmedUser = user?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedPassword = password?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedPassword.hasPrefix("rmm_") || (trimmedUser.isEmpty && !trimmedPassword.isEmpty) {
            return "Bearer \(trimmedPassword)"
        }
        let raw = "\(trimmedUser):\(trimmedPassword)"
        let token = raw.data(using: .utf8)?.base64EncodedString() ?? ""
        return "Basic \(token)"
    }

    func request(path: String, query: [URLQueryItem] = []) -> URLRequest? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        let api = path.hasPrefix("/") ? path : "/" + path
        if components.path.isEmpty || components.path == "/" {
            components.path = api
        } else {
            components.path += api
        }
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

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        guard let req = request(path: path, query: query) else {
            throw URLError(.badURL)
        }
        return try Self.jsonDecoder.decode(T.self, from: await data(for: req))
    }

    private func getList<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> [T] {
        guard let req = request(path: path, query: query) else {
            throw URLError(.badURL)
        }
        let payload = try await data(for: req)
        if let page = try? Self.jsonDecoder.decode(RommPage<T>.self, from: payload) {
            return page.items
        }
        return try Self.jsonDecoder.decode([T].self, from: payload)
    }

    func data(for request: URLRequest) async throws -> Data {
        let url = request.url?.absoluteString ?? "?"
        Log.debug("[RomM HTTP] \(request.httpMethod ?? "GET") \(url)")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            Log.debug("[RomM HTTP] ← non-HTTP response \(data.count) bytes \(url)")
            throw URLError(.badServerResponse)
        }
        if !(200..<300 ~= http.statusCode) {
            let body = String(data: data, encoding: .utf8).map { String($0.prefix(400)) } ?? "<\(data.count) bytes>"
            Log.debug("[RomM HTTP] ← \(http.statusCode) \(data.count) bytes \(url) body=\(body)")
            throw URLError(.userAuthenticationRequired)
        }
        Log.debug("[RomM HTTP] ← \(http.statusCode) \(data.count) bytes \(url)")
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

    func rom(id: Int) async throws -> RommRom {
        guard let req = request(path: "\(RomApiStub)/\(id)") else {
            throw URLError(.badURL)
        }
        let payload = try await data(for: req)
        Self.logRomPayload(id: id, payload: payload)
        return try Self.jsonDecoder.decode(RommRom.self, from: payload)
    }

    private static func logRomPayload(id: Int, payload: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            Log.debug("[RomM] GET /api/roms/\(id) payload is not a JSON object (\(payload.count) bytes)")
            return
        }
        let keys = json.keys.sorted()
        Log.debug("[RomM] GET /api/roms/\(id) keys=\(keys)")
        for key in ["id", "name", "fs_name", "summary", "path_cover_small", "path_cover_large", "url_cover", "has_cover", "has_manual", "path_manual", "url_manual", "platform_name", "platform_display_name"] {
            if let value = json[key] {
                Log.debug("[RomM]   \(key)=\(Self.shortValue(value))")
            }
        }
        if let metadatum = json["metadatum"] {
            Log.debug("[RomM]   metadatum=\(Self.shortValue(metadatum))")
        }
        if let igdb = json["igdb_metadata"] {
            Log.debug("[RomM]   igdb_metadata=\(Self.shortValue(igdb))")
        }
        if let romUser = json["rom_user"] {
            Log.debug("[RomM]   rom_user=\(Self.shortValue(romUser))")
        }
        let coverKeys = keys.filter { $0.lowercased().contains("cover") }
        if !coverKeys.isEmpty {
            Log.debug("[RomM]   cover-related keys=\(coverKeys)")
        }
    }

    private static func shortValue(_ value: Any, limit: Int = 240) -> String {
        let raw: String
        if let string = value as? String {
            raw = string
        } else if JSONSerialization.isValidJSONObject(value),
                  let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                  let string = String(data: data, encoding: .utf8) {
            raw = string
        } else {
            raw = String(describing: value)
        }
        if raw.count <= limit { return raw }
        return String(raw.prefix(limit)) + "…"
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

    func saves(romID: Int) async throws -> [RommSave] {
        try await getList(SaveApiStub, query: [.init(name: "rom_id", value: "\(romID)")])
    }

    func states(romID: Int) async throws -> [RommState] {
        try await getList(StateApiStub, query: [.init(name: "rom_id", value: "\(romID)")])
    }

    func playSessions(romID: Int) async throws -> [RommPlaySession] {
        try await getList(PlaySessionApiStub, query: [.init(name: "rom_id", value: "\(romID)")])
    }

    func saveContentRequest(saveID: Int) -> URLRequest? {
        request(path: "\(SaveApiStub)/\(saveID)/content")
    }

    func stateContentRequest(stateID: Int) -> URLRequest? {
        request(path: "\(StateApiStub)/\(stateID)/content")
    }

    func assetDownloadRequest(downloadPath: String, ignoreCache: Bool = false) -> URLRequest? {
        let rawPath = String(downloadPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0])
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.percentEncodedPath = rawPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? rawPath
        guard let url = components.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        if ignoreCache {
            req.cachePolicy = .reloadIgnoringLocalCacheData
        }
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

    func uploadManual(romID: Int, fileName: String, fileData: Data) async throws {
        guard var req = request(path: "\(RomApiStub)/\(romID)/manuals") else { throw URLError(.badURL) }
        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        let boundary = "ManicEmuBoundary-manual-\(romID)"
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(safeName, forHTTPHeaderField: "x-upload-filename")
        var body = Data()
        body.appendFormFile(boundary: boundary,
                            name: safeName,
                            fileName: safeName,
                            mime: "application/pdf",
                            data: fileData)
        body.append("--\(boundary)--\r\n")
        Log.debug("[RomM HTTP] POST \(req.url?.absoluteString ?? "?") manual=\(safeName) bytes=\(fileData.count)")
        let (data, response) = try await session.upload(for: req, from: body)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8).map { String($0.prefix(400)) } ?? "<\(data.count) bytes>"
            Log.debug("[RomM HTTP] ← \(status) POST /api/roms/\(romID)/manuals body=\(bodyText)")
            throw URLError(.userAuthenticationRequired)
        }
        Log.debug("[RomM HTTP] ← \(http.statusCode) POST /api/roms/\(romID)/manuals \(data.count) bytes")
    }

    func deleteManual(romID: Int) async throws {
        guard var req = request(path: "\(RomApiStub)/\(romID)/manuals") else { throw URLError(.badURL) }
        req.httpMethod = "DELETE"
        Log.debug("[RomM HTTP] DELETE \(req.url?.absoluteString ?? "?")")
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 404 {
            Log.debug("[RomM HTTP] ← 404 DELETE /api/roms/\(romID)/manuals (already gone)")
            return
        }
        if !(200..<300 ~= http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8).map { String($0.prefix(400)) } ?? "<\(data.count) bytes>"
            Log.debug("[RomM HTTP] ← \(http.statusCode) DELETE /api/roms/\(romID)/manuals body=\(bodyText)")
            throw URLError(.userAuthenticationRequired)
        }
        Log.debug("[RomM HTTP] ← \(http.statusCode) DELETE /api/roms/\(romID)/manuals")
    }

    func updateLastPlayed(romID: Int) async throws {
        guard var req = request(path: "\(RomApiStub)/\(romID)/props",
                                query: [.init(name: "update_last_played", value: "true")]) else {
            throw URLError(.badURL)
        }
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{}".utf8)
        _ = try await data(for: req)
    }

    func ingestPlaySession(romID: Int, durationMs: Int, endedAt: Date = Date()) async throws {
        guard durationMs > 0 else { return }
        guard var req = request(path: PlaySessionApiStub) else { throw URLError(.badURL) }
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let startedAt = endedAt.addingTimeInterval(-Double(durationMs) / 1000)
        let body: [String: Any] = [
            "sessions": [[
                "rom_id": romID,
                "start_time": Self.isoFormatter.string(from: startedAt),
                "end_time": Self.isoFormatter.string(from: endedAt),
                "duration_ms": durationMs
            ]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await data(for: req)
    }

    func updateRom(romID: Int,
                   name: String?,
                   summary: String?,
                   artwork: (fileName: String, data: Data)?) async throws {
        guard var req = request(path: "\(RomApiStub)/\(romID)") else { throw URLError(.badURL) }
        let boundary = "ManicEmuBoundary-rom-\(romID)"
        req.httpMethod = "PUT"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        if let name, !name.isEmpty {
            body.appendFormField(boundary: boundary, name: "name", value: name)
        }
        if let summary {
            body.appendFormField(boundary: boundary, name: "summary", value: summary)
        }
        if let artwork {
            body.appendFormFile(boundary: boundary,
                                name: "artwork",
                                fileName: artwork.fileName,
                                mime: "image/jpeg",
                                data: artwork.data)
        }
        body.append("--\(boundary)--\r\n")
        Log.debug("[RomM HTTP] PUT \(req.url?.absoluteString ?? "?") name=\(name ?? "nil") summaryChars=\(summary?.count ?? 0) artworkBytes=\(artwork?.data.count ?? 0)")
        let (data, response) = try await session.upload(for: req, from: body)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8).map { String($0.prefix(400)) } ?? "<\(data.count) bytes>"
            Log.debug("[RomM HTTP] ← \(status) PUT /api/roms/\(romID) body=\(bodyText)")
            throw URLError(.userAuthenticationRequired)
        }
        Log.debug("[RomM HTTP] ← \(http.statusCode) PUT /api/roms/\(romID) \(data.count) bytes")
        _ = data
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
            body.appendFormFile(boundary: boundary,
                                name: part.name,
                                fileName: part.fileName,
                                mime: part.mime,
                                data: part.data)
        }
        body.append("--\(boundary)--\r\n")

        Log.debug("[RomM HTTP] POST \(req.url?.absoluteString ?? "?") field=\(fileField) file=\(fileName) bytes=\(fileData.count) screenshot=\(screenshot?.fileName ?? "nil")")
        let (data, response) = try await session.upload(for: req, from: body)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8).map { String($0.prefix(400)) } ?? "<\(data.count) bytes>"
            Log.debug("[RomM HTTP] ← \(status) POST \(stub) \(fileName) body=\(bodyText)")
            throw URLError(.userAuthenticationRequired)
        }
        Log.debug("[RomM HTTP] ← \(http.statusCode) POST \(stub) \(fileName) \(data.count) bytes")
        return try Self.jsonDecoder.decode(T.self, from: data)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendFormField(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func appendFormFile(boundary: String, name: String, fileName: String, mime: String, data: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mime)\r\n\r\n")
        append(data)
        append("\r\n")
    }
}
