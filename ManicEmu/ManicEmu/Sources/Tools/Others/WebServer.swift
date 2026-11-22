//
//  WebServer.swift
//  ManicEmu
//
//  Created by Max on 2025/1/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import GCDWebUploader
import GCDWebServer
import RealmSwift

class WebServer: NSObject {
    static let shard = WebServer()
    private weak var scene: UIWindowScene? = nil

    /// Agent skill that drives this server. Linked from the transfer page.
    static let agentSkillURL = "https://github.com/Manic-EMU/ManicEMU/tree/main/skills/manic-emu"
    /// Header that library-changing requests must carry. Browsers can't add it cross-origin
    /// without a CORS preflight, which this server never approves, so other sites can't post here.
    static let agentHeader = "X-Manic-EMU"

    var ipAddress: String {
        if let webServer = webServer, let serverURL = webServer.serverURL, let host = serverURL.host, let port = serverURL.port {
             return "\(host):\(port)"
        }
        return ""
    }

    var isRunning: Bool {
        if let webServer = webServer {
            return webServer.isRunning
        }
        return false
    }

    private override init(){}
    private var webServer: GCDWebUploader?

    func start(in scene: UIWindowScene?) {
        guard webServer == nil else { return }
        self.scene = scene
        webServer = GCDWebUploader(uploadDirectory: R.Path.UploadWorkSpace)
        webServer?.allowedFileExtensions = FileType.allSupportFileExtension()
        webServer?.delegate = self
        webServer?.epilogue = Self.epilogueHTML
        if let webServer {
            addLibraryHandlers(to: webServer)
        }
        if FileManager.default.fileExists(atPath: R.Path.UploadWorkSpace) {
            try? FileManager.default.removeItem(atPath: R.Path.UploadWorkSpace)
        }
        try? FileManager.default.createDirectory(atPath: R.Path.UploadWorkSpace, withIntermediateDirectories: true)
        webServer?.start(withPort: 6969, bonjourName: nil)
    }

    func stop() {
        if let webServer = webServer {
            if webServer.isRunning {
                DispatchQueue.global().async { [weak self] in
                    guard let self = self else { return }
                    self.webServer?.stop()
                    self.webServer = nil
                }
            }
        }
    }
}

extension WebServer: GCDWebUploaderDelegate {
    func webUploader(_ uploader: GCDWebUploader, didUploadFileAtPath path: String) {
        FilesImporter.importFiles(urls: [URL(fileURLWithPath: path)], in: scene)
    }
}

// MARK: - Library API
//
// GET  /library[?platform=gba]   JSON array of the games in the library.
// POST /library/delete id=ID[,ID...] (header X-Manic-EMU: 1)
//      Removes games exactly like the in-app Remove Game action: ROM, saves, save states and cheats.
// POST /library/update id=ID [name=] [sound=true|false] [haptic=] [orientation=] (header X-Manic-EMU: 1)
//      Renames a game or changes its simple per-game settings. Returns the updated game.
// POST /library/upload multipart files[] [platform=ID] [bulk=1] [name=] (header X-Manic-EMU: 1)
//      Uploads and imports files, as the given platform if there is one. Archives that platform runs
//      zipped (arcade, DOS, C64, Amiga) are kept zipped without asking. bulk=1 imports without any
//      alerts or dialogs on the phone. name= (one file only) sets the game's display name.
//
// Handlers added after GCDWebUploader's own take priority over them.
extension WebServer {
    private static let platformPrefix = "public.aoshuang.game."

    private static func platformID(_ gameType: GameType) -> String {
        let raw = gameType.rawValue
        return raw.hasPrefix(platformPrefix) ? String(raw.dropFirst(platformPrefix.count)) : raw
    }

    private static func json(_ object: Any, status: Int = 200) -> GCDWebServerResponse {
        guard let response = GCDWebServerDataResponse(jsonObject: object) else {
            return GCDWebServerResponse(statusCode: 500)
        }
        response.statusCode = status
        response.cacheControlMaxAge = 0
        return response
    }

    private static func header(_ name: String, in request: GCDWebServerRequest) -> String? {
        request.headers.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame })?.value
    }

    /// Only answer requests addressed to the phone by IP, `.local` name or localhost. A web page
    /// that rebinds its own domain to the phone's address still sends its own domain here.
    private static func isLocalHost(_ request: GCDWebServerRequest) -> Bool {
        guard let host = header("Host", in: request)?.lowercased() else { return false }
        var name = host
        if name.hasPrefix("[") {
            return true // IPv6 literal
        }
        if let colon = name.lastIndex(of: ":") {
            name = String(name[..<colon])
        }
        if name == "localhost" || name.hasSuffix(".local") {
            return true
        }
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { UInt8($0) != nil }
    }

    /// Runs `work` on the main thread and waits for it to call its completion.
    private static func onMainAndWait(timeout: TimeInterval = 120,
                                      _ work: @escaping (_ done: @escaping (GCDWebServerResponse) -> Void) -> Void) -> GCDWebServerResponse {
        let semaphore = DispatchSemaphore(value: 0)
        var result: GCDWebServerResponse?
        DispatchQueue.main.async {
            work { response in
                result = response
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            return json(["error": "Timed out"], status: 503)
        }
        return result ?? GCDWebServerResponse(statusCode: 500)
    }

    private func addLibraryHandlers(to server: GCDWebUploader) {
        server.addHandler(forMethod: "GET", path: "/library", request: GCDWebServerRequest.self) { request in
            guard WebServer.isLocalHost(request) else { return WebServer.json(["error": "Forbidden host"], status: 403) }
            let platform = request.query?["platform"]?.lowercased()
            return WebServer.onMainAndWait { done in
                done(WebServer.json(WebServer.libraryListing(platform: platform)))
            }
        }

        server.addHandler(forMethod: "POST", path: "/library/delete", request: GCDWebServerURLEncodedFormRequest.self) { [weak self] request in
            guard WebServer.isLocalHost(request) else { return WebServer.json(["error": "Forbidden host"], status: 403) }
            guard WebServer.header(WebServer.agentHeader, in: request) != nil else {
                return WebServer.json(["error": "Missing \(WebServer.agentHeader) header"], status: 403)
            }
            let raw = (request as? GCDWebServerURLEncodedFormRequest)?.arguments["id"] ?? ""
            let ids = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !ids.isEmpty else { return WebServer.json(["error": "No id given"], status: 400) }
            return WebServer.onMainAndWait { done in
                WebServer.deleteGames(ids: ids, in: self?.scene) { done(WebServer.json($0)) }
            }
        }

        server.addHandler(forMethod: "POST", path: "/library/update", request: GCDWebServerURLEncodedFormRequest.self) { request in
            guard WebServer.isLocalHost(request) else { return WebServer.json(["error": "Forbidden host"], status: 403) }
            guard WebServer.header(WebServer.agentHeader, in: request) != nil else {
                return WebServer.json(["error": "Missing \(WebServer.agentHeader) header"], status: 403)
            }
            let args = (request as? GCDWebServerURLEncodedFormRequest)?.arguments ?? [:]
            return WebServer.onMainAndWait { done in
                done(WebServer.updateGame(arguments: args))
            }
        }

        server.addHandler(forMethod: "POST", path: "/library/upload", request: GCDWebServerMultiPartFormRequest.self) { [weak self] request in
            guard WebServer.isLocalHost(request) else { return WebServer.json(["error": "Forbidden host"], status: 403) }
            guard WebServer.header(WebServer.agentHeader, in: request) != nil else {
                return WebServer.json(["error": "Missing \(WebServer.agentHeader) header"], status: 403)
            }
            guard let form = request as? GCDWebServerMultiPartFormRequest else {
                return WebServer.json(["error": "Expected multipart/form-data"], status: 400)
            }
            return WebServer.upload(form: form, in: self?.scene)
        }
    }

    /// True if `gameType` uses files with this extension. Archives count only for platforms that run
    /// them zipped; others are refused, because the app would unzip them and the files inside could be anything.
    private static func canImport(fileExtension ext: String, as gameType: GameType) -> Bool {
        if GameType.gameTypes(multiPlatformFileExtension: ext).contains(gameType) {
            return true
        }
        if FileType.zip.extensions.contains(ext) {
            return false
        }
        return GameType(fileExtension: ext) == gameType
    }

    /// Moves uploaded files into the transfer folder and imports them. With `platform=ID` (an id from
    /// `GET /library`) each file must be one that platform uses. The files then import as that platform
    /// instead of one guessed from the extension, and archives the platform runs zipped (arcade, DOS,
    /// C64, Amiga) stay zipped without the ZIP File Handling dialog, even when the app can't look an
    /// arcade title up in its MAME list. With `bulk=1` the import shows nothing on the phone: no progress,
    /// no "import successful" alert, no error alerts, no platform picker and no ZIP File Handling dialog
    /// (zips that would need it are imported as they are). Cover search still runs in the background.
    /// `name=` (one file only) sets the name shown in the library, which cover search also looks for.
    /// It applies when the game is new to the library.
    private static func upload(form: GCDWebServerMultiPartFormRequest, in scene: UIWindowScene?) -> GCDWebServerResponse {
        let platform = form.firstArgument(forControlName: "platform")?.string?.lowercased() ?? ""
        var chosenType: GameType?
        if !platform.isEmpty {
            guard let gameType = System.allCases.map({ $0.gameType }).first(where: { platformID($0) == platform }) else {
                let ids = System.allCases.map { platformID($0.gameType) }.sorted().joined(separator: ", ")
                return json(["error": "Unknown platform \(platform). Known platforms: \(ids)"], status: 400)
            }
            chosenType = gameType
        }
        let bulkValue = form.firstArgument(forControlName: "bulk")?.string?.lowercased() ?? ""
        let bulk = ["1", "true", "yes", "on"].contains(bulkValue)
        let files = form.files.filter { !$0.fileName.isEmpty }
        guard !files.isEmpty else { return json(["error": "No files given"], status: 400) }
        var chosenName: String?
        if let raw = form.firstArgument(forControlName: "name")?.string {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard files.count == 1 else {
                return json(["error": "name can only be given when uploading one file"], status: 400)
            }
            guard !trimmed.isEmpty, trimmed.count <= R.Size.GameNameMaxCount else {
                return json(["error": "name must be 1-\(R.Size.GameNameMaxCount) characters"], status: 400)
            }
            chosenName = trimmed
        }

        let allowed = Set(FileType.allSupportFileExtension().map { $0.lowercased() })
        var accepted = [String]()
        var rejected = [[String: String]]()
        var paths = [String]()
        for file in files {
            let name = (file.fileName as NSString).lastPathComponent
            let ext = (name as NSString).pathExtension.lowercased()
            if let chosenType {
                if !canImport(fileExtension: ext, as: chosenType) {
                    let reason = FileType.zip.extensions.contains(ext)
                        ? "\(platform) games can't be imported from a .\(ext); upload the ROM itself, or leave out platform"
                        : "\(platform) doesn't use .\(ext) files"
                    rejected.append(["fileName": name, "error": reason])
                    continue
                }
            } else if !allowed.contains(ext) {
                rejected.append(["fileName": name, "error": "Unsupported file type"])
                continue
            }
            let destination = (R.Path.UploadWorkSpace as NSString).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: destination) {
                rejected.append(["fileName": name, "error": "Already waiting to be imported"])
                continue
            }
            do {
                try FileManager.default.moveItem(atPath: file.temporaryPath, toPath: destination)
            } catch {
                rejected.append(["fileName": name, "error": "Could not save the file"])
                continue
            }
            if let chosenType {
                FilesImporter.setImportPlatform(chosenType, path: destination)
            }
            if let chosenName {
                FilesImporter.setImportName(chosenName, path: destination)
            }
            accepted.append(name)
            paths.append(destination)
        }
        if !paths.isEmpty {
            let urls = paths.map { URL(fileURLWithPath: $0) }
            DispatchQueue.main.async {
                if bulk {
                    FilesImporter.importFiles(urls: urls, silentMode: true, askAboutZips: false, in: scene)
                } else {
                    FilesImporter.importFiles(urls: urls, in: scene)
                }
            }
        }
        return json(["accepted": accepted, "rejected": rejected], status: accepted.isEmpty ? 400 : 200)
    }

    /// Main thread only.
    private static func libraryListing(platform: String?) -> [[String: Any]] {
        let formatter = ISO8601DateFormatter()
        var games = Array(Database.realm.objects(Game.self).where { !$0.isDeleted })
        if let platform, !platform.isEmpty {
            games = games.filter { platformID($0.gameType) == platform }
        }
        return games
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            .map { entry(for: $0, formatter: formatter) }
    }

    private static let hapticNames: [(String, GameOption.HapticType)] = [
        ("off", .off), ("soft", .soft), ("light", .light), ("medium", .medium), ("heavy", .heavy), ("rigid", .rigid),
    ]
    private static let orientationNames: [(String, GameOption.OrientationType)] = [
        ("auto", .auto), ("portrait", .portrait), ("landscape", .landscape),
    ]

    /// Main thread only.
    private static func entry(for game: Game, formatter: ISO8601DateFormatter = ISO8601DateFormatter()) -> [String: Any] {
        var entry: [String: Any] = [
            "id": game.id,
            "name": game.displayName,
            "fileName": game.fileName,
            "platform": platformID(game.gameType),
            "platformName": game.gameType.localizedShortName,
            "importDate": formatter.string(from: game.importDate),
            "playTimeSeconds": Int(game.totalPlayDuration / 1000),
            "hasSave": game.isSaveExtsts,
            "saveStates": game.gameSaveStates.filter { !$0.isDeleted }.count,
            "cheats": game.gameCheats.filter { !$0.isDeleted }.count,
            "sound": game.volume,
            "haptic": hapticNames.first { $0.1 == game.haptic }?.0 ?? "soft",
            "orientation": orientationNames.first { $0.1 == game.orientation }?.0 ?? "auto",
        ]
        if let lastPlayed = game.latestPlayDate {
            entry["lastPlayed"] = formatter.string(from: lastPlayed)
        }
        let url = game.romUrl
        if url.isFileURL,
           let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber {
            entry["size"] = size.int64Value
        }
        return entry
    }

    /// Main thread only. Validates every field before changing anything.
    private static func updateGame(arguments args: [String: String]) -> GCDWebServerResponse {
        guard let id = args["id"], !id.isEmpty,
              let game = Database.realm.object(ofType: Game.self, forPrimaryKey: id), !game.isDeleted else {
            return json(["error": "No game with that id"], status: 404)
        }
        if id == PlayViewController.currentGame?.id {
            return json(["error": "The game is being played. Close it on the phone and try again."], status: 409)
        }
        var name: String?
        if let raw = args["name"] {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= R.Size.GameNameMaxCount else {
                return json(["error": "name must be 1-\(R.Size.GameNameMaxCount) characters"], status: 400)
            }
            name = trimmed
        }
        var sound: Bool?
        if let raw = args["sound"]?.lowercased() {
            switch raw {
            case "true", "on", "1", "yes": sound = true
            case "false", "off", "0", "no": sound = false
            default: return json(["error": "sound must be true or false"], status: 400)
            }
        }
        var haptic: GameOption.HapticType?
        if let raw = args["haptic"]?.lowercased() {
            guard let match = hapticNames.first(where: { $0.0 == raw }) else {
                return json(["error": "haptic must be one of " + hapticNames.map { $0.0 }.joined(separator: ", ")], status: 400)
            }
            haptic = match.1
        }
        var orientation: GameOption.OrientationType?
        if let raw = args["orientation"]?.lowercased() {
            guard let match = orientationNames.first(where: { $0.0 == raw }) else {
                return json(["error": "orientation must be one of " + orientationNames.map { $0.0 }.joined(separator: ", ")], status: 400)
            }
            orientation = match.1
        }
        guard name != nil || sound != nil || haptic != nil || orientation != nil else {
            return json(["error": "Nothing to update: pass name, sound, haptic or orientation"], status: 400)
        }
        Game.change { _ in
            if let name, name != game.aliasName { game.aliasName = name }
            if let sound, sound != game.volume { game.volume = sound }
            if let haptic, haptic != game.haptic { game.haptic = haptic }
            if let orientation, orientation != game.orientation { game.orientation = orientation }
        }
        return json(entry(for: game))
    }

    /// Main thread only.
    private static func deleteGames(ids: [String], in scene: UIWindowScene?, completion: @escaping ([String: Any]) -> Void) {
        let realm = Database.realm
        let playingID = PlayViewController.currentGame?.id
        var found: [Game] = []
        var notFound: [String] = []
        var inUse: [String] = []
        for id in ids {
            guard let game = realm.object(ofType: Game.self, forPrimaryKey: id), !game.isDeleted else {
                notFound.append(id)
                continue
            }
            if id == playingID {
                inUse.append(id)
            } else if !found.contains(where: { $0.id == id }) {
                found.append(game)
            }
        }
        let names = Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0.displayName) })
        let finish = {
            realm.refresh()
            var deleted: [[String: String]] = []
            var failed: [String] = []
            for (id, name) in names {
                if let game = realm.object(ofType: Game.self, forPrimaryKey: id), !game.isDeleted {
                    failed.append(id)
                } else {
                    deleted.append(["id": id, "name": name])
                }
            }
            if !deleted.isEmpty {
                let list = deleted.compactMap { $0["name"] }.sorted().joined(separator: ", ")
                UIView.makeToast(message: "\(R.string.localizable.gamesDelete()): \(list)")
            }
            completion(["deleted": deleted, "notFound": notFound, "inUse": inUse, "failed": failed])
        }
        if found.isEmpty {
            finish()
        } else {
            Game.deleteFromLibrary(found, completion: finish)
        }
    }
}

// MARK: - Transfer page

extension WebServer {
    /// Inserted below the transfer folder listing: the library with Remove buttons, then how to
    /// connect an AI agent. Built with textContent so game names are never parsed as HTML.
    private static var epilogueHTML: String {
        #"""
        <style>
          #library-panel .btn-remove { background-color: #26262E; color: #ff6b6b; border: 0; padding: 2px 10px; }
          #library-panel td { vertical-align: middle; }
          #library-filter { background-color: #26262E; color: #fff; border: 0; margin-bottom: 8px; }
          .agent-help code { background-color: #26262E; color: #fff; }
          .agent-help { color: #aaaaaa; }
        </style>
        <div class="panel panel-default" id="library-panel">
          <div class="panel-heading">Games in your library
            <button type="button" class="btn btn-default btn-xs pull-right" id="library-reload">
              <span class="glyphicon glyphicon-refresh"></span> Refresh
            </button>
          </div>
          <input type="search" class="form-control" id="library-filter" placeholder="Filter by name or platform">
          <table class="table table-striped"><tbody id="library"></tbody></table>
        </div>
        <div class="panel panel-default agent-help">
          <div class="panel-heading">Use an AI agent</div>
          <ol>
            <li>Keep this screen open in Manic EMU. Your computer and phone must be on the same Wi-Fi.</li>
            <li>Give your agent the Manic EMU skill. In Claude Code, say:
              <code>Install the skill from <span class="skill-url"></span></code>.
              Or copy that <code>manic-emu</code> folder into <code>~/.claude/skills/</code>.</li>
            <li>Ask it things like <code>What games are on my Manic EMU?</code> or
              <code>Upload the ROMs in my Downloads folder to Manic EMU</code> or
              <code>Remove Pac-Man from Manic EMU</code>.</li>
          </ol>
          <p>The agent finds this phone on its own. If it can't, give it this address:
            <code class="server-url"></code></p>
        </div>
        <script type="text/javascript">
          (function () {
            var skillURL = "SKILL_URL";
            var games = [];
            $(".skill-url").text(skillURL);
            $(".server-url").text(window.location.origin);

            function formatSize(bytes) {
              if (bytes == null) return "";
              var units = ["B", "KB", "MB", "GB"], i = 0;
              while (bytes >= 1000 && i < units.length - 1) { bytes /= 1000; i++; }
              return bytes.toFixed(i ? 1 : 0) + " " + units[i];
            }

            function render() {
              var body = document.getElementById("library");
              var q = ($("#library-filter").val() || "").toLowerCase();
              body.innerHTML = "";
              var shown = games.filter(function (g) {
                return !q || g.name.toLowerCase().indexOf(q) >= 0 || g.fileName.toLowerCase().indexOf(q) >= 0 ||
                  g.platform.indexOf(q) >= 0 || (g.platformName || "").toLowerCase().indexOf(q) >= 0;
              });
              if (!shown.length) {
                var tr = body.insertRow(), td = tr.insertCell();
                td.colSpan = 4;
                td.textContent = games.length ? "No matches" : "No games yet";
                return;
              }
              shown.forEach(function (g) {
                var tr = body.insertRow();
                tr.insertCell().textContent = g.name;
                tr.insertCell().textContent = g.platformName || g.platform;
                tr.insertCell().textContent = formatSize(g.size);
                var btn = document.createElement("button");
                btn.className = "btn btn-xs btn-remove";
                btn.textContent = "Remove";
                btn.onclick = function () { remove(g); };
                var cell = tr.insertCell();
                cell.style.textAlign = "right";
                cell.appendChild(btn);
              });
            }

            function load() {
              $.getJSON("library").done(function (data) { games = data; render(); });
            }

            function remove(g) {
              if (!confirm("Remove \"" + g.name + "\" from Manic EMU?\n\nIts ROM, saves, save states and cheats are deleted from the phone. This can't be undone.")) return;
              $.ajax({ url: "library/delete", type: "POST", data: { id: g.id }, headers: { "X-Manic-EMU": "1" }, dataType: "json" })
                .done(function (r) {
                  if (r.inUse && r.inUse.length) alert("\"" + g.name + "\" is being played. Close it on the phone and try again.");
                  else if (r.failed && r.failed.length) alert("Couldn't remove \"" + g.name + "\".");
                  load();
                })
                .fail(function () { alert("Couldn't reach Manic EMU."); });
            }

            $("#library-reload").click(load);
            $("#library-filter").on("input", render);
            $("#reload").click(load);
            $(document).ajaxComplete(function (e, xhr, opts) {
              if (opts.url && opts.url.indexOf("upload") === 0) setTimeout(load, 1500);
            });
            load();
          })();
        </script>
        """#.replacingOccurrences(of: "SKILL_URL", with: agentSkillURL)
    }
}
