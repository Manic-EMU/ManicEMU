//
//  PlatformSelectionView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/6/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import ProHUD


class PlatformSelectionView: BaseView {
    static func show(games: [Game], cancelEnable: Bool = true, completion: (() -> Void)? = nil) {
        guard let firstGame = games.first else {
            completion?()
            return
        }
        
        let games = games.filter({ $0.fileExtension.lowercased() == firstGame.fileExtension.lowercased() })
        
        let detailString = games.reduce("", {
            $0 + ($0.isEmpty ? "" : ", ") + $1.displayName
        })
        
        //We’ve already made sure that all games have the same file extension, so just use the first one directly.
        let options = GameType.gameTypes(multiPlatformFileExtension: firstGame.fileExtension)
        
        var selectedIndexPath: Int? = nil
        if (games.count == 1 || (games.count > 1 && games.allSatisfy({ $0.fileExtension.lowercased() == firstGame.fileExtension.lowercased() }))),
           let currentIndex = options.firstIndex(of: firstGame.gameType) {
            selectedIndexPath = currentIndex
            
        }
        
        OptionsSheetView.show(icon: GameOption.platformChange.icon,
                               title: R.string.localizable.platformSelectionTitle(),
                               detail: R.string.localizable.platformSelectionDetail(detailString),
                               options: options.map({ $0.localizedName }),
                               selectedIndex: selectedIndexPath,
                               cancelEnable: cancelEnable, completion: { index in
            if let index {
                let gameType = options[index]
                Game.change { realm in
                    for game in games {
                        game.gameType = gameType
#if !SIDE_LOAD
                        if game.gameType == ._32x || game.gameType == .mcd {
                            game.defaultCore = 1
                        }
#endif
                        //Using the default core configured by the user.
                        let globalCoreSwitch = GlobalCoreSwitch.getConfig(realm: realm)
                        if let index = globalCoreSwitch.getUsingCoreIndex(gameType: gameType) {
                            Log.debug("[PlatformSelection] using \(globalCoreSwitch.getUsingCoreName(gameType: gameType) ?? "Unknown")(index) core for \(gameType.localizedShortName)")
                            game.defaultCore = index
                        }
#if !SIDE_LOAD
                        FilesSyncPolicy.applyDefaultROMSyncFlag(to: game)
#endif
                    }
                }
                // Fill PSP game code when switching to PSP.
                if gameType == .psp {
                    for game in games {
                        if game.gameCodeForPSP == nil,
                           let gameCode = LibretroCore.getPSPGameID(withRomPath: game.romUrl.path) {
                            game.updateExtra(key: ExtraKey.PSPGameCode.rawValue, value: gameCode)
                        }
                    }
                }

                if gameType == .ngc || gameType == .wii {
                    for game in games {
                        if game.gameIDForDolphin == nil {
                            if game.fileExtension.lowercased() == "elf" {
                                game.updateExtra(key: ExtraKey.dolphinGameID.rawValue,
                                                 value: DolphinGameID.makeElfOrDolID(fileName: game.fileName))
                            } else {
                                game.ensureDolphinGameID()
                            }
                        }
                    }
                }
                
                if gameType == .ps1 {
                    for game in games {
                        game.ensurePS1BinCueSheet()
                    }
                }
                
                NotificationCenter.default.post(name: R.NotificationName.PlatformSelectionChange, object: nil)
                for game in games {
                    game.matchCover(force: true)
                }
#if !SIDE_LOAD
                FilesSyncManager.shared.applyROMSyncAfterGameTypeChange(for: games)
#endif
            }
            completion?()
        })
    }
}
