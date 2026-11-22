//
//  OnlineCoverManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/8.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import Fuse
import SwiftSoup
import CryptoKit
import IceCream

class OnlineCoverManager {
    struct CoverMatch {
        var gameType: GameType
        var gameID: String
        var gameName: String
        var fileExtension: String
        var isNaomi: Bool = false
        var isAtomiswave: Bool = false
        
        init(game: Game) {
            self.gameType = game.effectiveGameType
            self.gameID = game.id
            self.gameName = game.translatedName ?? game.displayName
            self.fileExtension = game.fileExtension
            self.isNaomi = game.isNaomiGame
            self.isAtomiswave = game.isAtomiswaveGame
        }
        
        init(gameType: GameType, gameID: String, gameName: String, fileExtension: String) {
            self.gameType = gameType
            self.gameID = gameID
            self.gameName = gameName
            self.fileExtension = fileExtension
        }
    }
    
    class MatchOperation: Operation, @unchecked Sendable {
        private let coverMatch: CoverMatch
        
        init(coverMatch: CoverMatch) {
            self.coverMatch = coverMatch
        }
        
        override func main() {
            guard !isCancelled else { return }
            let semaphore = DispatchSemaphore(value: 0)
            
            MatchOperation.searchCovers(coverMatch: coverMatch, fetchOne: true) { [weak self] urls, needMatchNextTime in
                guard let self = self else {
                    semaphore.signal()
                    return
                }
                guard !needMatchNextTime else {
                    semaphore.signal()
                    return
                }
                let realm = Database.realm
                if let game = realm.object(ofType: Game.self, forPrimaryKey: self.coverMatch.gameID) {
                    try? realm.write {
                        game.hasCoverMatch = true
                        if let onlineCoverUrl = urls.first {
                            game.onlineCoverUrl = onlineCoverUrl.absoluteString
                        }
                    }
                }
                semaphore.signal()
            }
            semaphore.wait() // 保证同步等待当前请求完成
        }
        
        /// - Parameter normaliseNames: Opt-in. Matches on cleaned-up titles (tags stripped, articles/punctuation normalised) in ranked tiers. When false the original matching is used unchanged.
        static func searchCovers(coverMatch: CoverMatch, fetchOne: Bool = false, persistentedTranslation: Bool = true, isCallBackMain: Bool = false, normaliseNames: Bool = false, completion: (([URL], Bool)->Void)? = nil) {
            //请求封面列表
            let host = URL(string: "https://thumbnails.libretro.com")!
            var boxArtUrl: URL? = nil
            switch coverMatch.gameType {
            case ._3ds:
                boxArtUrl = host.appendingPathComponent("Nintendo - Nintendo 3DS/Named_Boxarts")
            case .ds:
                boxArtUrl = host.appendingPathComponent("Nintendo - Nintendo DS/Named_Boxarts")
            case .gba:
                boxArtUrl = host.appendingPathComponent("Nintendo - Game Boy Advance/Named_Boxarts")
            case .gbc:
                boxArtUrl = host.appendingPathComponent("Nintendo - Game Boy Color/Named_Boxarts")
            case .gb, .chm:
                boxArtUrl = host.appendingPathComponent("Nintendo - Game Boy/Named_Boxarts")
            case .nes:
                boxArtUrl = host.appendingPathComponent("Nintendo - Nintendo Entertainment System/Named_Boxarts")
            case .fds:
                boxArtUrl = host.appendingPathComponent("Nintendo - Family Computer Disk System/Named_Boxarts")
            case .snes:
                boxArtUrl = host.appendingPathComponent("Nintendo - Super Nintendo Entertainment System/Named_Boxarts")
            case .psp:
                boxArtUrl = host.appendingPathComponent("Sony - PlayStation Portable/Named_Boxarts")
            case .md:
                boxArtUrl = host.appendingPathComponent("Sega - Mega Drive - Genesis/Named_Boxarts")
            case .mcd:
                boxArtUrl = host.appendingPathComponent("Sega - Mega-CD - Sega CD/Named_Boxarts")
            case ._32x:
                boxArtUrl = host.appendingPathComponent("Sega - 32X/Named_Boxarts")
            case .gg:
                boxArtUrl = host.appendingPathComponent("Sega - Game Gear/Named_Boxarts")
            case .ms:
                boxArtUrl = host.appendingPathComponent("Sega - Master System - Mark III/Named_Boxarts")
            case .sg1000:
                boxArtUrl = host.appendingPathComponent("Sega - SG-1000/Named_Boxarts")
            case .ss:
                boxArtUrl = host.appendingPathComponent("Sega - Saturn/Named_Boxarts")
            case .n64:
                boxArtUrl = host.appendingPathComponent("Nintendo - Nintendo 64/Named_Boxarts")
            case .vb:
                boxArtUrl = host.appendingPathComponent("Nintendo - Virtual Boy/Named_Boxarts")
            case .pm:
                boxArtUrl = host.appendingPathComponent("Nintendo - Pokemon Mini/Named_Boxarts")
            case .ps1:
                boxArtUrl = host.appendingPathComponent("Sony - PlayStation/Named_Boxarts")
            case .dc:
                boxArtUrl = host.appendingPathComponent("Sega - Dreamcast/Named_Boxarts")
            case .arcade:
                if coverMatch.isNaomi {
                    boxArtUrl = host.appendingPathComponent("Sega - Naomi/Named_Boxarts")
                } else if coverMatch.isAtomiswave {
                    boxArtUrl = host.appendingPathComponent("Atomiswave/Named_Boxarts")
                } else {
                    boxArtUrl = host.appendingPathComponent("MAME/Named_Boxarts")
                }
            case .a2600:
                boxArtUrl = host.appendingPathComponent("Atari - 2600/Named_Boxarts")
            case .a5200:
                boxArtUrl = host.appendingPathComponent("Atari - 5200/Named_Boxarts")
            case .a7800:
                boxArtUrl = host.appendingPathComponent("Atari - 7800/Named_Boxarts")
            case .jaguar:
                boxArtUrl = host.appendingPathComponent("Atari - Jaguar/Named_Boxarts")
            case .lynx:
                boxArtUrl = host.appendingPathComponent("Atari - Lynx/Named_Boxarts")
            case .xbox360:
                boxArtUrl = host.appendingPathComponent("Microsoft - Xbox 360/Named_Boxarts")
            case .flash:
                if storeCoverFromSWF(gameID: coverMatch.gameID) {
                    completion?([], false)
                    return
                }
                searchCoversFromMoby(coverMatch: coverMatch,
                                     persistentedTranslation: persistentedTranslation,
                                     isCallBackMain: isCallBackMain,
                                     completion: completion)
                return
            case .ns, .j2me, .symbian:
                searchCoversFromMoby(coverMatch: coverMatch,
                                     persistentedTranslation: persistentedTranslation,
                                     isCallBackMain: isCallBackMain,
                                     completion: completion)
                return
            case .doom:
                boxArtUrl = host.appendingPathComponent("DOOM/Named_Boxarts")
            case .dos, .win95, .win98:
                boxArtUrl = host.appendingPathComponent("DOS/Named_Boxarts")
            case .xbox:
                boxArtUrl = host.appendingPathComponent("Microsoft - Xbox/Named_Boxarts")
            case .ps2:
                boxArtUrl = host.appendingPathComponent("Sony - PlayStation 2/Named_Boxarts")
            case .ngc:
                boxArtUrl = host.appendingPathComponent("Nintendo - GameCube/Named_Boxarts")
            case .wii:
                boxArtUrl = host.appendingPathComponent("Nintendo - Wii/Named_Boxarts")
            case .pce, .turbografx_16:
                boxArtUrl = host.appendingPathComponent("NEC - PC Engine - TurboGrafx 16/Named_Boxarts")
            case .turbografx_cd:
                boxArtUrl = host.appendingPathComponent("NEC - PC Engine CD - TurboGrafx-CD/Named_Boxarts")
            case .supergrafx:
                boxArtUrl = host.appendingPathComponent("NEC - PC Engine SuperGrafx/Named_Boxarts")
            case .ngp:
                boxArtUrl = host.appendingPathComponent("SNK - Neo Geo Pocket/Named_Boxarts")
            case .ngpc:
                boxArtUrl = host.appendingPathComponent("SNK - Neo Geo Pocket Color/Named_Boxarts")
            case .wsc:
                boxArtUrl = host.appendingPathComponent("Bandai - WonderSwan Color/Named_Boxarts")
            case .ws:
                boxArtUrl = host.appendingPathComponent("Bandai - WonderSwan/Named_Boxarts")
            case .c64:
                boxArtUrl = host.appendingPathComponent("Commodore - 64/Named_Boxarts")
            case .amiga:
                boxArtUrl = host.appendingPathComponent("Commodore - Amiga/Named_Boxarts")
            case .wiiu:
                boxArtUrl = host.appendingPathComponent("Nintendo - Wii U/Named_Boxarts")
            default:
                boxArtUrl = nil
            }
            guard let boxArtUrl else {
                completion?([], false)
                return
            }
            
            getMatchList(url: boxArtUrl) { matchList in
                translateGameName(coverMatch.gameName, gameID: persistentedTranslation ? coverMatch.gameID : nil) { gameName in
                    var onlineCoverUrls = [URL]()
                    let fuse = Fuse()
                    let pattern = fuse.createPattern(from: gameName)
                    if normaliseNames {
                        //规范化名称后分层匹配
                        let result = CoverNameNormalizer.rankedMatches(query: gameName, in: matchList, fetchOne: fetchOne)
                        onlineCoverUrls.append(contentsOf: result.map { boxArtUrl.appendingPathComponent($0) })
                    } else if fetchOne {
                        //只获取一个
                        if let result = matchList.min(by: {
                            if let result0 = fuse.search(pattern, in: $0) {
                                if let result1 = fuse.search(pattern, in: $1) {
                                    return result0.score < result1.score
                                } else {
                                    return true
                                }
                            } else if let _ = fuse.search(pattern, in: $1) {
                                return false
                            } else {
                                return true
                            }
                        }) {
                            if let score = fuse.search(pattern, in: result)?.score, score < 0.35 {
                                //匹配结果OK
                                onlineCoverUrls.append(boxArtUrl.appendingPathComponent(result))
                            }
                        }
                    } else {
                        //获取多个
                        let result = matchList.filter({
                            if let result = fuse.search(pattern, in: $0), result.score < 0.35 {
                                Log.debug("搜索参数:\(gameName) 结果:\($0) 分数:\(result.score)")
                                return true
                            } else {
                                return false
                            }
                        }).sorted(by: {
                            if let result0 = fuse.search(pattern, in: $0) {
                                if let result1 = fuse.search(pattern, in: $1) {
                                    return result0.score < result1.score
                                } else {
                                    return true
                                }
                            } else if let _ = fuse.search(pattern, in: $1) {
                                return false
                            } else {
                                return true
                            }
                        }).compactMap({  boxArtUrl.appendingPathComponent($0) })
                        onlineCoverUrls.append(contentsOf: result)
                    }
                    if isCallBackMain {
                        DispatchQueue.main.async {
                            completion?(onlineCoverUrls, matchList.count == 0)
                        }
                    } else {
                        completion?(onlineCoverUrls, matchList.count == 0)
                    }
                }
            }
        }

        /// Use an embedded SWF bitmap when Libretro/Moby have no Flash box art.
        static func storeCoverFromSWF(gameID: String) -> Bool {
            let realm = Database.realm
            guard let game = realm.object(ofType: Game.self, forPrimaryKey: gameID),
                  !game.isDeleted else { return false }
            if game.gameCover != nil { return true }
            guard FileManager.default.fileExists(atPath: game.romUrl.path),
                  let coverData = FLASHCover.extractJPEGData(from: game.romUrl) else { return false }
            do {
                try realm.write {
                    game.gameCover = CreamAsset.create(objectID: game.id, propName: "gameCover", data: coverData)
                }
                return true
            } catch {
                Log.debug("[FLASHCover] Failed to store SWF cover: \(error)")
                return false
            }
        }
        
        static func searchCoversFromMoby(coverMatch: CoverMatch, persistentedTranslation: Bool = true, isCallBackMain: Bool = false, completion: (([URL], Bool)->Void)? = nil) {
            translateGameName(coverMatch.gameName,
                              gameID: persistentedTranslation ? coverMatch.gameID : nil) { translatedName in
                MobyGamesKit.getGameInfoUrl(gameType: coverMatch.gameType, name: translatedName) { url in
                    func callback(urls: [URL], needMatchNextTime: Bool) {
                        if isCallBackMain {
                            DispatchQueue.main.async {
                                completion?(urls, needMatchNextTime)
                            }
                        } else {
                            completion?(urls, needMatchNextTime)
                        }
                    }
                    
                    if url == R.URLs.MobyGames {
                        callback(urls: [], needMatchNextTime: false)
                    } else {
                        //获取到结果
                        URLSession.shared.dataTask(with: url) { data, response, error in
                            if let data = data,
                                let html = String(data: data, encoding: .utf8),
                                let document = try? SwiftSoup.parse(html) {
                                let links = try? document.select("img.img-box").filter({ element in
                                    if element.hasAttr("src"), let alt = try? element.attr("alt"), alt == "box cover" {
                                        return true
                                    }
                                    return false
                                }).compactMap({
                                    if let src = try? $0.attr("src") {
                                        return URL(string: src.removingPercentEncoding)
                                    }
                                    return nil
                                })
                                if let links {
                                    callback(urls: links, needMatchNextTime: false)
                                } else {
                                    callback(urls: [], needMatchNextTime: false)
                                }
                                
                            } else {
                                callback(urls: [], needMatchNextTime: true)
                            }
                        }.resume()
                        
                    }
                }
            }
        }
        
        private static func getMatchList(url: URL, completion: @escaping ([String])->Void) {
            let matchListPath = R.Path.BoxArtsCache.appendingPathComponent("\(Insecure.MD5.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined())")
            try? FileManager.default.createDirectory(atPath: R.Path.BoxArtsCache, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: matchListPath) {
                //已经有搜索列表缓存
                if let content = try? String(contentsOf: URL(fileURLWithPath: matchListPath), encoding: .utf8) {
                    let result = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    DispatchQueue.global().async {
                        if let attributes = try? FileManager.default.attributesOfItem(atPath: matchListPath), let creationDate = attributes[.creationDate] as? Date {
                            if creationDate.daysSince(Date.now.tomorrow) < -7 {
                               //需要更新缓存
                                self.updateCache(url: url, cachePath: matchListPath)
                            }
                            
                        } else {
                            //无法获取创建时间 去更新缓存
                            self.updateCache(url: url, cachePath: matchListPath)
                        }
                    }
                    completion(result)
                }
            } else {
                self.updateCache(url: url, cachePath: matchListPath, completion: completion)
            }
        }
        
        private static func updateCache(url: URL, cachePath: String, completion: (([String])->Void)? = nil) {
            //没有搜索列表的缓存 尝试查找请求网络
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, let html = String(data: data, encoding: .utf8), let document = try? SwiftSoup.parse(html) {
                    let links = try? document.select("a").filter({ $0.hasAttr("href") }).compactMap({
                        if let href = try? $0.attr("href"), href.hasSuffix(".png") {
                            return href.removingPercentEncoding
                        }
                        return nil
                    })
                        
                    if let links {
                        //进行缓存
                        DispatchQueue.global().async {
                            try? links.joined(separator: "\n").writeWithCompletePath(to: URL(fileURLWithPath: cachePath))
                        }
                        completion?(links)
                    } else {
                        completion?([])
                    }
                } else {
                    completion?([])
                }
            }.resume()
        }
        
        static func translateGameName(_ name: String, gameID: String? = nil, completion:((String)->Void)? = nil) {
            if name.isEnglishLanguage() {
                Log.debug("英文语言无需翻译!")
                completion?(name)
            } else {
                if let gameID {
                    let realm = Database.realm
                    if let game = realm.object(ofType: Game.self, forPrimaryKey: gameID), let translatedName = game.translatedName {
                        Log.debug("已经处理过翻译!直接返回")
                        completion?(translatedName)
                        return
                    }
                }
                
                
                var request = URLRequest(url: R.URLs.CoverTranslate)
                request.timeoutInterval = 10
                request.httpMethod = "POST"
                request.addValue(R.Cipher.CoverTranslate, forHTTPHeaderField: "X-Cover-Token")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                request.httpBody = ["name": name].jsonData()
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let _ = error {
                        completion?(name)
                        return
                    }
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        completion?(name)
                        return
                    }
                    if let response = try? data?.jsonObject() as? [String: Any],
                       let translatedName = response["name"] as? String,
                       !translatedName.isEmpty {
                        Log.debug("获取翻译结果:\(translatedName)")
                        completion?(translatedName)
                        if let gameID {
                            let realm = Database.realm
                            if let game = realm.object(ofType: Game.self, forPrimaryKey: gameID) {
                                var extras = (try? game.extras?.jsonObject() as? [String: Any]) ?? [String: Any]()
                                extras["translatedName"] = translatedName
                                if let extrasData = extras.jsonData() {
                                    try? realm.write {
                                        game.extras = extrasData
                                    }
                                }
                            }
                        }
                    } else {
                        Log.debug("解析封面翻译失败")
                        completion?(name)
                    }
                }
                task.resume()
            }
        }
    }
    
    static func translateGameName(_ name: String, gameID: String? = nil, completion: ((String) -> Void)? = nil) {
        MatchOperation.translateGameName(name, gameID: gameID, completion: completion)
    }
    
    static let shared = OnlineCoverManager()
    private let queue: OperationQueue
    
    init() {
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
    }
    
    func addCoverMatch(_ coverMatch: CoverMatch) {
        guard coverMatch.gameType != .unknown && coverMatch.gameType != .notSupport else { return }
        let operation = MatchOperation(coverMatch: coverMatch)
        queue.addOperation(operation)
    }
    
    
}

// MARK: - Normalised name matching (opt-in via `normaliseNames`)
extension OnlineCoverManager {
    /// Cleans up game names and libretro boxart file names so they can be matched on their title,
    /// then ranks candidates in tiers: exact title + tags, exact title, all query words, fuzzy title.
    enum CoverNameNormalizer {
        struct Name {
            /// Normalised title without tags, e.g. "the legend of zelda a link to the past"
            let title: String
            let words: [String]
            /// Normalised values from (...) tags, e.g. ["usa", "europe"]
            let tags: Set<String>
            /// TOSEC-style name with a year tag, e.g. "Commando (1986-11)(Capcom)(US)"
            let isLegacyStyle: Bool
            /// Has dump flags such as [b], [h], [a], [t]
            let isFlagged: Bool
        }

        private static let tagRegex = try! NSRegularExpression(pattern: #"\(([^)]*)\)|\[([^\]]*)\]"#)
        /// "Legend of Zelda, The - A Link to the Past" -> "The Legend of Zelda - A Link to the Past"
        private static let articleRegex = try! NSRegularExpression(pattern: #"^(.+?),\s+(the|a|an|le|la|les|el|los|las|il|der|die|das)(\s*[-:_].*)?$"#,
                                                                   options: [.caseInsensitive])
        private static let yearRegex = try! NSRegularExpression(pattern: #"^\s*(19|20)\d\d"#)
        private static let dumpFlagRegex = try! NSRegularExpression(pattern: #"^\s*(b|h|a|o|t|f|p|tr|cr|u)(\d|\s|$)"#,
                                                                    options: [.caseInsensitive])
        /// Fuse (Bitap) returns nil for patterns longer than this
        private static let maxFuzzyLength = 32
        private static let fuzzyThreshold = 0.35
        private static let maxResults = 100

        /// Lower-cases, folds accents, drops apostrophes and turns every other non-alphanumeric
        /// character (including libretro's "_" substitutes for & : / etc.) into a single space.
        /// The word "and" is dropped so "&", "and" and "_" all compare equal.
        static func clean(_ string: String) -> String {
            let folded = string
                .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
                .lowercased()
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "\u{2019}", with: "")
            var scalars = String.UnicodeScalarView()
            for scalar in folded.unicodeScalars {
                scalars.append(CharacterSet.alphanumerics.contains(scalar) ? scalar : " ")
            }
            return String(scalars)
                .split(separator: " ")
                .filter { $0 != "and" }
                .joined(separator: " ")
        }

        static func parse(_ raw: String, stripExtension: Bool) -> Name {
            var text = raw
            if stripExtension, text.lowercased().hasSuffix(".png") {
                text = String(text.dropLast(4))
            }
            let ns = text as NSString
            var base = ""
            var tags = Set<String>()
            var isLegacyStyle = false
            var isFlagged = false
            var last = 0
            for match in tagRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                base += ns.substring(with: NSRange(location: last, length: match.range.location - last)) + " "
                last = match.range.location + match.range.length
                if match.range(at: 1).location != NSNotFound {
                    let content = ns.substring(with: match.range(at: 1))
                    let contentRange = NSRange(location: 0, length: (content as NSString).length)
                    if yearRegex.firstMatch(in: content, range: contentRange) != nil {
                        isLegacyStyle = true
                    }
                    for part in content.split(separator: ",") {
                        let tag = clean(String(part))
                        if !tag.isEmpty { tags.insert(tag) }
                    }
                } else {
                    let content = ns.substring(with: match.range(at: 2))
                    if dumpFlagRegex.firstMatch(in: content, range: NSRange(location: 0, length: (content as NSString).length)) != nil {
                        isFlagged = true
                    }
                }
            }
            base += ns.substring(from: last)
            base = base.trimmingCharacters(in: .whitespaces)
            let baseRange = NSRange(location: 0, length: (base as NSString).length)
            base = articleRegex.stringByReplacingMatches(in: base, range: baseRange, withTemplate: "$2 $1$3")
            let title = clean(base)
            return Name(title: title,
                        words: title.split(separator: " ").map(String.init),
                        tags: tags,
                        isLegacyStyle: isLegacyStyle,
                        isFlagged: isFlagged)
        }

        /// Shortens a title to whole words that fit Fuse's pattern limit, so long titles still fuzzy-match.
        static func fuzzyPattern(for title: String) -> String {
            guard title.count > maxFuzzyLength else { return title }
            var result = ""
            for word in title.split(separator: " ") {
                let next = result.isEmpty ? String(word) : result + " " + word
                if next.count > maxFuzzyLength { break }
                result = next
            }
            return result.isEmpty ? String(title.prefix(maxFuzzyLength)) : result
        }

        private struct Ranked {
            let file: String
            /// 0 exact title + tags, 1 exact title, 2 contains all query words, 3 fuzzy title
            let tier: Int
            let score: Double
            let extraWords: Int
            let regionMiss: Int
            /// Tags beyond the query's, e.g. (Beta), (Virtual Console)
            let extraTags: Int
            let legacy: Int
            let flagged: Int

            func isOrderedBefore(_ other: Ranked) -> Bool {
                if tier != other.tier { return tier < other.tier }
                if score != other.score { return score < other.score }
                if extraWords != other.extraWords { return extraWords < other.extraWords }
                if regionMiss != other.regionMiss { return regionMiss < other.regionMiss }
                if extraTags != other.extraTags { return extraTags < other.extraTags }
                if legacy != other.legacy { return legacy < other.legacy }
                if flagged != other.flagged { return flagged < other.flagged }
                return file < other.file
            }
        }

        /// Returns candidate file names (unchanged, for building URLs) best match first.
        /// With `fetchOne` only a confident match (tiers 0, 1 or 3) is returned.
        static func rankedMatches(query: String, in candidates: [String], fetchOne: Bool) -> [String] {
            let q = parse(query, stripExtension: false)
            guard !q.words.isEmpty else { return [] }
            let queryWords = Set(q.words)
            let fuse = Fuse()
            let pattern = fuse.createPattern(from: fuzzyPattern(for: q.title))

            var ranked = [Ranked]()
            for file in candidates {
                let c = parse(file, stripExtension: true)
                guard !c.words.isEmpty else { continue }
                let tier: Int
                var score = 0.0
                if c.title == q.title {
                    tier = (!q.tags.isEmpty && c.tags == q.tags) ? 0 : 1
                } else if queryWords.isSubset(of: c.words) {
                    tier = 2
                } else if let fuzzyScore = fuse.search(pattern, in: c.title)?.score, fuzzyScore < fuzzyThreshold {
                    tier = 3
                    score = fuzzyScore
                } else {
                    continue
                }
                ranked.append(Ranked(file: file,
                                     tier: tier,
                                     score: score,
                                     extraWords: max(0, c.words.count - q.words.count),
                                     regionMiss: (q.tags.isEmpty || !c.tags.isDisjoint(with: q.tags)) ? 0 : 1,
                                     extraTags: max(0, c.tags.count - q.tags.count),
                                     legacy: c.isLegacyStyle ? 1 : 0,
                                     flagged: c.isFlagged ? 1 : 0))
            }
            ranked.sort { $0.isOrderedBefore($1) }

            if fetchOne {
                return ranked.first(where: { $0.tier != 2 }).map { [$0.file] } ?? []
            }
            Log.debug("规范化搜索:\(query) -> \(q.title) 结果数:\(ranked.count)")
            return ranked.prefix(maxResults).map(\.file)
        }
    }
}
