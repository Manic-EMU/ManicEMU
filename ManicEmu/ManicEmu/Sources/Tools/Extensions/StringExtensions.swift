//
//  StringExtensions.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/25.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
//
//  StringExtensions.swift
//  ZNear
//
//  Created by Max on 2021/2/22.
//

import Foundation
import CommonCrypto

extension String {
    var a: String { return self + "a" }
    var b: String { return self + "b" }
    var c: String { return self + "c" }
    var d: String { return self + "d" }
    var e: String { return self + "e" }
    var f: String { return self + "f" }
    var g: String { return self + "g" }
    var h: String { return self + "h" }
    var i: String { return self + "i" }
    var j: String { return self + "j" }
    var k: String { return self + "k" }
    var l: String { return self + "l" }
    var m: String { return self + "m" }
    var n: String { return self + "n" }
    var o: String { return self + "o" }
    var p: String { return self + "p" }
    var q: String { return self + "q" }
    var r: String { return self + "r" }
    var s: String { return self + "s" }
    var t: String { return self + "t" }
    var u: String { return self + "u" }
    var v: String { return self + "v" }
    var w: String { return self + "w" }
    var x: String { return self + "x" }
    var y: String { return self + "y" }
    var z: String { return self + "z" }
    
    var A: String { return self + "A" }
    var B: String { return self + "B" }
    var C: String { return self + "C" }
    var D: String { return self + "D" }
    var E: String { return self + "E" }
    var F: String { return self + "F" }
    var G: String { return self + "G" }
    var H: String { return self + "H" }
    var I: String { return self + "I" }
    var J: String { return self + "J" }
    var K: String { return self + "K" }
    var L: String { return self + "L" }
    var M: String { return self + "M" }
    var N: String { return self + "N" }
    var O: String { return self + "O" }
    var P: String { return self + "P" }
    var Q: String { return self + "Q" }
    var R: String { return self + "R" }
    var S: String { return self + "S" }
    var T: String { return self + "T" }
    var U: String { return self + "U" }
    var V: String { return self + "V" }
    var W: String { return self + "W" }
    var X: String { return self + "X" }
    var Y: String { return self + "Y" }
    var Z: String { return self + "Z" }
    
    var _1 : String { get { return self + "1" } }
    var _2 : String { get { return self + "2" } }
    var _3 : String { get { return self + "3" } }
    var _4 : String { get { return self + "4" } }
    var _5 : String { get { return self + "5" } }
    var _6 : String { get { return self + "6" } }
    var _7 : String { get { return self + "7" } }
    var _8 : String { get { return self + "8" } }
    var _9 : String { get { return self + "9" } }
    var _0 : String { get { return self + "0" } }
}

extension String {
    var validateAndExtractURLComponents: (scheme: String?, host: String, port: Int?, path: String?)? {
        let trimmedInput = self.trimmingCharacters(in: .whitespacesAndNewlines)
        // Fix the regex grouping structure by using non-capturing groups to keep the indices.
        let pattern = #"^(([a-zA-Z][a-zA-Z0-9+.-]*)://)?((?:$$([0-9a-fA-F:]+)$$|([^/?#:]+)))(?::(\d+))?(?:/([^?#]*))?(?:[?#].*)?$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let range = NSRange(trimmedInput.startIndex..., in: trimmedInput)
        guard let match = regex.firstMatch(in: trimmedInput, options: [], range: range) else {
            return nil
        }
        
        // Extract scheme (Group 2)
        let schemeRange = Range(match.range(at: 2), in: trimmedInput)
        let scheme = schemeRange.flatMap { String(trimmedInput[$0]).lowercased() }
        
        // Extract host (Group 3 contains square brackets, the actual host is in Group 4 or 5)
        var host: String?
        var isIPv6 = false
        if let ipv6Range = Range(match.range(at: 4), in: trimmedInput), !ipv6Range.isEmpty {
            host = String(trimmedInput[ipv6Range]) // I Pv6 actual content is in Group 4
            isIPv6 = true
        } else if let normalHostRange = Range(match.range(at: 5), in: trimmedInput), !normalHostRange.isEmpty {
            host = String(trimmedInput[normalHostRange]) // Ordinary host in group 5
        }
        
        guard let validHost = host, !validHost.isEmpty else {
            return nil
        }
        
        // Strict host verification (keeping the original logic)
        let adjustedHost = isIPv6 ? validHost : validHost
        let isDomainValid = NSPredicate(format: "SELF MATCHES %@", #"^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"#).evaluate(with: adjustedHost)
        let isIPv4Valid = NSPredicate(format: "SELF MATCHES %@", #"^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)$"#).evaluate(with: adjustedHost)
        let isIPv6Valid = isIPv6 && NSPredicate(format: "SELF MATCHES %@", #"^[0-9a-fA-F:]+$"#).evaluate(with: adjustedHost)
        // Single-label names such as `nas`. Digit-only and 0x… labels are rejected because resolvers parse them as IPv4.
        let isSingleLabelHostValid = NSPredicate(format: "SELF MATCHES %@", #"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$"#).evaluate(with: adjustedHost)
            && adjustedHost.rangeOfCharacter(from: .letters) != nil
            && adjustedHost.range(of: #"^0[xX][0-9a-fA-F]+$"#, options: .regularExpression) == nil
        
        guard isIPv6Valid || isIPv4Valid || isDomainValid || isSingleLabelHostValid else {
            return nil
        }
        
        // Extract port (Group 6)
        let portString = Range(match.range(at: 6), in: trimmedInput).flatMap { String(trimmedInput[$0]) }
        let port = portString.flatMap { Int($0) }.flatMap { (1...65535).contains($0) ? $0 : nil }
        guard portString == nil || port != nil else { return nil }
        
        // Extract path (Group 7)
        let path = Range(match.range(at: 7), in: trimmedInput).flatMap {
            let str = String(trimmedInput[$0])
            return str.isEmpty ? nil : str
        }
        
        return (scheme, adjustedHost, port, path)
    }
    
    func calculateWidth(font: UIFont, height: CGFloat) -> CGFloat {
        let constraintRect = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: height
        )
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingBox.width)
    }
    
    static func errorMessage(from errors: [Error]) -> String {
        return errors.reduce("") { partialResult, error in
            if partialResult == "" {
                return error.localizedDescription
            } else {
                return partialResult + "\n" + error.localizedDescription
            }
        }
    }
    
    static func successMessage(from names: [String]) -> String {
        return names.reduce("") { partialResult, name in
            if partialResult == "" {
                return name
            } else {
                return partialResult + "\n" + name
            }
        }
    }
    
    func isEnglishLanguage() -> Bool {
        // Define the allowed character set: English letters, numbers, punctuation, spaces, emoji
        let allowedCharacterSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
            .union(.punctuationCharacters)
            .union(.whitespaces)
            .union(.symbols)          // 包括部分 emoji
            .union(.nonBaseCharacters)
            .union(.emojis)
        
        // Check if there are any characters that are not in the allowed set.
        return !self.unicodeScalars.contains { !allowedCharacterSet.contains($0) }
    }
    
    /// High-efficiency SHA256 (fixed 64-bit hex)
    @inline(__always)
    func sha256() -> String {
        let data = Data(self.utf8)
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    func trimedExceptNumberAndLetters() -> String {
        return self.filter { ($0 >= "a" && $0 <= "z") || ($0 >= "A" && $0 <= "Z") || ($0 >= "0" && $0 <= "9") }
    }
    
    func writeWithCompletePath(to path: String) throws {
        try writeWithCompletePath(to: URL(fileURLWithPath: path))
    }
    
    func writeWithCompletePath(to url: URL) throws {
        let parentUrl = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentUrl.path) {
            try FileManager.default.createDirectory(at: parentUrl, withIntermediateDirectories: true)
        }
        try write(to: url, atomically: true, encoding: .utf8)
    }
    
    func parseIPv4() -> (ips: [Int], port: Int)? {
        let parts = self.split(separator: ":")
        guard parts.count == 2,
              let port = Int(parts[1]) else {
            return nil
        }
        
        let ipDigits: [Int] = parts[0]
            .split(separator: ".")
            .flatMap { segment -> [Int] in
                let padded = String(format: "%03d", Int(segment)!)
                return padded.map { Int(String($0))! }
            }
        
        return (ipDigits, port)
    }
    
    func parseIPv4String() -> (ip: String, port: Int)? {
        let parts = self.split(separator: ":", omittingEmptySubsequences: false)
        
        // Handling port
        var ipPart: String
        var port: Int = 0
        
        switch parts.count {
        case 1:
            ipPart = String(parts[0])
        case 2:
            ipPart = String(parts[0])
            guard let p = Int(parts[1]), p >= 0 && p <= 65535 else {
                return nil
            }
            port = p
        default:
            return nil
        }
        
        // Handling IPv4
        let octets = ipPart.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }
        
        var normalized: [String] = []
        
        for octet in octets {
            // Leading zeros are allowed, but it must be purely numeric.
            guard !octet.isEmpty,
                  octet.allSatisfy({ $0.isNumber }),
                  let value = Int(octet),
                  value >= 0 && value <= 255 else {
                return nil
            }
            normalized.append(String(value)) // Remove leading zeros.
        }
        
        let ip = normalized.joined(separator: ".")
        return (ip: ip, port: port)
    }
    
    /// Escape special characters in JavaScript strings
    /// - Returns: The escaped string, safe to use in JavaScript single-quoted strings.
    func escapeJSString() -> String {
        var result = self
        result = result.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "'", with: "\\'")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r")
        result = result.replacingOccurrences(of: "\t", with: "\\t")
        return result
    }
    
    /// Remove all suffixes (including multi-level extensions), but keep the leading dot for hidden files.
    var deletingMultiPathExtension: String {
        // Handling Hidden Files
        if hasPrefix(".") {
            // After removing the initial ".", proceed with the translation into English.
            let trimmed = dropFirst()
            if let firstDotIndex = trimmed.firstIndex(of: ".") {
                return "." + trimmed[..<firstDotIndex]
            } else {
                // Only ".xxx" without an extension.
                return self
            }
        }
        
        // For regular files: take the part before the first "dot."
        if let firstDotIndex = firstIndex(of: ".") {
            return String(self[..<firstDotIndex])
        }
        
        return self
    }
    
    func nsRange(from range: Range<String.Index>) -> NSRange? {
        // Check whether the boundary is valid.
        guard range.lowerBound >= startIndex,
              range.upperBound <= endIndex,
              range.lowerBound <= range.upperBound else {
            return nil
        }
        
        return NSRange(range, in: self)
    }
    
    ///Replace the strings matched by the regular expression with the specified string
    ///- Parameters:
    ///  - pattern: regular expression
    ///  - text: the string to replace with
    ///- Returns: the string after replacement
    @discardableResult func replace(pattern: String, with text: String) -> String {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let result = regex?.stringByReplacingMatches(in: self, range: NSMakeRange(0, self.count), withTemplate: text)
        return result ?? self
    }
    
    func match(pattern: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        guard let regex = regex else { return false }
        let resultArray = regex.matches(in: self, range: NSRange(location: 0, length: self.count))
        guard resultArray.count == 1, let result = resultArray.first else {
            return false
        }
        return self.count == result.range.length
    }
    
    var queryDict: [String: String?]? {
        guard let urlComponents = URLComponents(string: self) else {
            return nil
        }
        var querys: [String: String] = [:]
        if let queryItems = urlComponents.queryItems {
            for (_, item) in queryItems.enumerated() {
                querys[item.name] = item.value
            }
        }
        return querys.keys.count > 0 ? querys : nil
    }
    
    var libretroPath: String {
        // Use .backwards for "/Library/" to match the app's Library directory,
        // not the user's ~/Library on macOS where the container path contains
        // "/Library/" twice (e.g., /Users/X/Library/Containers/.../Data/Library/...)
        if let range = self.range(of: "/Documents/") ?? self.range(of: "/Library/", options: .backwards) {
            return "~" + String(self[range.lowerBound...])
        }
        return self
    }
    
    var parsedVersionNumber: UInt64 {
        let digits = self.replacingOccurrences(ofPattern: "\\D", withTemplate: "")
        return UInt64(digits) ?? 0
    }
}

// Expand the character set used for recognizing emoji.
extension CharacterSet {
    static let emojis: CharacterSet = {
        var set = CharacterSet()

        // Common emoji range
        set.insert(charactersIn: "\u{1F300}"..."\u{1F5FF}")
        set.insert(charactersIn: "\u{1F600}"..."\u{1F64F}")
        set.insert(charactersIn: "\u{1F680}"..."\u{1F6FF}")
        set.insert(charactersIn: "\u{1F900}"..."\u{1F9FF}")
        set.insert(charactersIn: "\u{1FA70}"..."\u{1FAFF}")
        set.insert(charactersIn: "\u{2600}"..."\u{26FF}")
        set.insert(charactersIn: "\u{2700}"..."\u{27BF}")
        return set
    }()
}
