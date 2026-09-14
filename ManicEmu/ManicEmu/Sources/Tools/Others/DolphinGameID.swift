//
//  DolphinGameID.swift
//  ManicEmu
//
//  Reads the 6-character Game ID from common GC/Wii image headers.
//  Covers iso/gcm, rvz/wia, wbfs, elf/dol, and m3u (first readable disc). Skips gcz/ciso/wad.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

enum DolphinGameID {
    private static let gamecubeMagic: UInt32 = 0xC233_9F3D
    private static let wiiMagic: UInt32 = 0x5D1C_9EA3

    /// File types that can yield a Game ID without a full DiscIO stack.
    static let readableExtensions: Set<String> = ["iso", "gcm", "rvz", "wia", "wbfs", "dol"]

    static func read(from url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "m3u":
            return readFromM3U(url)
        case "iso", "gcm":
            return readDiscHeader(from: url, offset: 0)
        case "rvz", "wia":
            return readRVZOrWIA(from: url)
        case "wbfs":
            return readWBFS(from: url)
        case "dol":
            return makeElfOrDolID(fileName: url.lastPathComponent)
        default:
            return nil
        }
    }
    
    /// m3u playlists point at the real discs; use the first readable entry.
    private static func readFromM3U(_ url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let directory = url.deletingLastPathComponent()
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if let id = read(from: directory.appendingPathComponent(trimmed)) {
                return id
            }
        }
        return nil
    }

    /// ELF is shared with PSP; only call after the game is known to be NGC/Wii.
    static func makeElfOrDolID(fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return "ID-" + base
    }

    private static func readDiscHeader(from url: URL, offset: UInt64) -> String? {
        guard let header = readBytes(at: url, offset: offset, count: 0x20) else { return nil }
        return parseDiscHeader(header)
    }

    private static func parseDiscHeader(_ header: Data) -> String? {
        guard header.count >= 0x20 else { return nil }
        // Wii magic is at 0x18, GameCube magic is at 0x1C (DiscIO/Volume.cpp).
        let isWii = be32(header, offset: 0x18) == wiiMagic
        let isGameCube = be32(header, offset: 0x1C) == gamecubeMagic
        guard isWii || isGameCube else { return nil }
        let id = String(bytes: header.prefix(6), encoding: .ascii) ?? ""
        guard isValidGameID(id) else { return nil }
        return id
    }

    /// RVZ/WIA store a copy of the first 0x80 disc bytes at header2.disc_header (file offset 0x58).
    private static func readRVZOrWIA(from url: URL) -> String? {
        guard let magicData = readBytes(at: url, offset: 0, count: 4), magicData.count == 4 else { return nil }
        let tag = String(bytes: magicData.prefix(3), encoding: .ascii)
        guard magicData[3] == 1, tag == "RVZ" || tag == "WIA" else { return nil }
        return readDiscHeader(from: url, offset: 0x58)
    }

    private static func readWBFS(from url: URL) -> String? {
        guard let prefix = readBytes(at: url, offset: 0, count: 9),
              String(bytes: prefix.prefix(4), encoding: .ascii) == "WBFS" else {
            return nil
        }
        var offsets: [UInt64] = [0x200]
        for shift in [Int(prefix[4]), Int(prefix[8])] where (9...16).contains(shift) {
            offsets.append(1 << shift)
        }
        for offset in Set(offsets) {
            if let id = readDiscHeader(from: url, offset: offset) {
                return id
            }
        }
        return nil
    }

    private static func isValidGameID(_ id: String) -> Bool {
        id.count == 6 && id.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    private static func be32(_ data: Data, offset: Int) -> UInt32? {
        guard data.count >= offset + 4 else { return nil }
        return (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }

    private static func readBytes(at url: URL, offset: UInt64, count: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset)
            return try handle.read(upToCount: count)
        } catch {
            return nil
        }
    }
}
