//
//  EmulatorInteractionKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//


import IceCream

extension GameType {
    static let ns = GameType("public.aoshuang.game.ns")
    static let xbox360 = GameType("public.aoshuang.game.xbox360")
    static let xbox = GameType("public.aoshuang.game.xbox")
    static let ps2 = GameType("public.aoshuang.game.ps2")
}

struct EmulatorInteractionKit {
    enum EmulatorType {
        case meloNX, xeniOS, dukeX, armsx2
    }
    
    /// Display name plus the public URL scheme. Extra ARMSX2 aliases stay in `supportedLaunchSchemes`.
    static let supportedLaunchers: [(name: String, scheme: String)] = [
        ("Delta", "delta"),
        ("RetroArch", "retroarch"),
        ("PPSSPP", "ppsspp"),
        ("Provenance", "provenance"),
        ("Gamma", "gamma"),
        ("GBA4iOS", "gba4ios"),
        ("MeloNX", "atariemulator"),
        ("XeniOS", "xenios"),
        ("DukeX", "dukex"),
        ("ARMSX2", "armsx2"),
        ("Consoles", "consolesapp"),
        ("MeloCafe", "melocafe")
    ]
    
    /// Schemes that must also be listed in `LSApplicationQueriesSchemes`.
    static let supportedLaunchSchemes: Set<String> = Set(supportedLaunchers.map(\.scheme)).union([
        "armsx2-ios",
        "armsx2ios"
    ])
    
    enum LaunchURLValidation {
        case ok(URL)
        case invalid
        case unsupportedScheme
    }
    
    /// Parse a pasted emulator deep link. Rejects http(s)/file and unknown schemes.
    static func validateLaunchURL(_ string: String) -> LaunchURLValidation {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              !scheme.isEmpty else {
            return .invalid
        }
        if scheme == "http" || scheme == "https" || scheme == "file" || scheme == "ftp" {
            return .unsupportedScheme
        }
        guard supportedLaunchSchemes.contains(scheme) else {
            return .unsupportedScheme
        }
        if let url = components.url {
            return .ok(url)
        }
        if let url = URL(string: trimmed) {
            return .ok(url)
        }
        return .invalid
    }
    
    static func openExternalGameURL(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) ?? URLComponents(string: trimmed)?.url else {
            UIView.makeToast(message: R.string.localizable.addUrlGameInvalidUrl())
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            guard !success else { return }
            DispatchQueue.main.async {
                let scheme = url.scheme ?? ""
                UIView.makeToast(message: scheme.isEmpty
                                 ? R.string.localizable.addUrlGameInvalidUrl()
                                 : R.string.localizable.notInstall(scheme))
            }
        }
    }
    
    static func isInstalled(type: EmulatorType) -> Bool {
        switch type {
        case .meloNX:
            return UIApplication.shared.canOpenURL(R.URLs.FetchMeloNXGames)
        case .xeniOS:
            return UIApplication.shared.canOpenURL(R.URLs.FetchXeniOSGames)
        case .dukeX:
            return UIApplication.shared.canOpenURL(R.URLs.FetchDukeXGames)
        case .armsx2:
            return UIApplication.shared.canOpenURL(R.URLs.FetchARMSX2Games)
                || UIApplication.shared.canOpenURL(URL(string: "\(R.Strings.ARMSX2Scheme)-ios://library")!)
                || UIApplication.shared.canOpenURL(URL(string: "\(R.Strings.ARMSX2Scheme)ios://library")!)
        }
    }
    
    static func startGame(type: EmulatorType, id: String) {
        if isInstalled(type: type) {
            switch type {
            case .meloNX:
                UIApplication.shared.open(R.URLs.MeloNXGameLaunch(gameId: id))
            case .xeniOS:
                UIApplication.shared.open(R.URLs.XeniOSGameLaunch(gameId: id))
            case .dukeX:
                UIApplication.shared.open(R.URLs.DukeXGameLaunch(gameId: id))
            case .armsx2:
                UIApplication.shared.open(R.URLs.ARMSX2GameLaunch(gameId: id))
            }
        } else {
            DispatchQueue.main.asyncAfter(delay: 0.35) {
                switch type {
                case .meloNX:
                    UIView.makeToast(message: R.string.localizable.notInstallMeloNX())
                case .xeniOS:
                    UIView.makeToast(message: R.string.localizable.notInstall("XeniOS"))
                case .dukeX:
                    UIView.makeToast(message: R.string.localizable.notInstall("DukeX"))
                case .armsx2:
                    UIView.makeToast(message: R.string.localizable.notInstall("ARMSX2"))
                }
            }
        }
    }
    
    static func fetchGames(type: EmulatorType) {
        if isInstalled(type: type) {
            switch type {
            case .meloNX:
                UIApplication.shared.open(R.URLs.FetchMeloNXGames)
            case .xeniOS:
                UIApplication.shared.open(R.URLs.FetchXeniOSGames)
            case .dukeX:
                UIApplication.shared.open(R.URLs.FetchDukeXGames)
            case .armsx2:
                UIApplication.shared.open(R.URLs.FetchARMSX2Games)
            }
            
        } else {
            switch type {
            case .meloNX:
                UIView.makeToast(message: R.string.localizable.notInstallMeloNX())
            case .xeniOS:
                UIView.makeToast(message: R.string.localizable.notInstall("XeniOS"))
            case .dukeX:
                UIView.makeToast(message: R.string.localizable.notInstall("DukeX"))
            case .armsx2:
                UIView.makeToast(message: R.string.localizable.notInstall("ARMSX2"))
            }
        }
    }
    
    static func processGames(type: EmulatorType, callbackUrl: URL) {
        var delay: Double
        if let _ = ApplicationSceneDelegate.applicationWindow {
            delay = 0.0
        } else {
            delay = 3.0
        }
        DispatchQueue.global().asyncAfter(delay: delay) {
            let fromGames = GameScheme.pullFromURL(callbackUrl)
            var games = [Game]()
            let realm = Database.realm
            for mg in fromGames {
                if let _ = realm.object(ofType: Game.self, forPrimaryKey: mg.titleId) {
                    Log.debug("MeloNX游戏已存在:\(mg.titleId) \(mg.titleName)")
                } else {
                    let game = Game()
                    switch type {
                    case .meloNX:
                        game.fileExtension = "xci"
                        game.gameType = .ns
                    case .xeniOS:
                        game.fileExtension = "iso"
                        game.gameType = .xbox360
                    case .dukeX:
                        game.fileExtension = "xiso"
                        game.gameType = .xbox
                    case .armsx2:
                        let ext = URL(fileURLWithPath: mg.titleId).pathExtension.lowercased()
                        game.fileExtension = ext.isEmpty ? "iso" : ext
                        game.gameType = .ps2
                    }
                    game.id = mg.titleId
                    game.name = mg.titleName
                    game.importDate = Date()
                    if let icon = mg.iconData {
                        game.gameCover = CreamAsset.create(objectID: game.id, propName: "gameCover", data: icon)
                    } else {
                        OnlineCoverManager.shared.addCoverMatch(.init(game: game))
                    }
                    games.append(game)
                }
            }
            if games.count > 0 {
                try? realm.write({
                    realm.add(games)
                })
                DispatchQueue.main.asyncAfter(delay: 1) {
                    switch type {
                    case .meloNX:
                        UIView.makeToast(message: R.string.localizable.biosImportSuccess("MeloNX Games"))
                    case .xeniOS:
                        UIView.makeToast(message: R.string.localizable.biosImportSuccess("Xenios Games"))
                    case .dukeX:
                        UIView.makeToast(message: R.string.localizable.biosImportSuccess("DukeX Games"))
                    case .armsx2:
                        UIView.makeToast(message: R.string.localizable.biosImportSuccess("ARMSX2 Games"))
                    }
                }
            }
        }
    }
}

struct GameScheme: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID().uuidString
    
    var titleName: String
    var titleId: String
    var developer: String
    var version: String
    var iconData: Data?
    
    static func pullFromURL(_ url: URL) -> [GameScheme] {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            let items = components.queryItems ?? []
            if let text = items.first(where: { $0.name == "games" })?.value,
                let data = GameScheme.base64URLDecode(text),
                let decoded = try? JSONDecoder().decode([GameScheme].self, from: data) {
                return decoded
            }
            // ARMSX2 sends `payload` wrapping `{ games: [{ title, fileName, ... }] }`.
            if let text = items.first(where: { $0.name == "payload" })?.value,
                let data = GameScheme.base64URLDecode(text),
                let library = try? JSONDecoder().decode(ARMSX2Library.self, from: data) {
                return library.gameSchemes
            }
        }
        return []
    }
    
    private static func base64URLDecode(_ text: String) -> Data? {
        var base64 = text
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 = base64.appending("=")
        }
        return Data(base64Encoded: base64)
    }
}

/// ARMSX2 `com.armsx2.library.v1` callback body. Launch key is `fileName`.
private struct ARMSX2Library: Decodable {
    let games: [ARMSX2Game]
    
    var gameSchemes: [GameScheme] {
        games.compactMap(\.gameScheme)
    }
}

private struct ARMSX2Game: Decodable {
    let title: String?
    let fileName: String?
    let serial: String?
    
    var gameScheme: GameScheme? {
        guard let fileName, !fileName.isEmpty else {
            return nil
        }
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let titleName = trimmedTitle.isEmpty
            ? URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
            : trimmedTitle
        return GameScheme(
            id: fileName,
            titleName: titleName,
            titleId: fileName,
            developer: serial ?? "",
            version: "1.0",
            iconData: nil
        )
    }
}
