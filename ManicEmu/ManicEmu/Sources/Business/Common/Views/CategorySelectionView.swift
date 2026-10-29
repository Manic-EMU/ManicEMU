//
//  CategorySelectionView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/29.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class CategorySelectionView: BaseView {
    static func show(games: [Game], completion: ((Bool) -> Void)? = nil) {
        guard let firstGame = games.first else {
            return
        }
        
        let games = games.filter({ $0.gameType == firstGame.gameType })
        
        //We've made sure that all incoming games are of the same game type.
        let supportedCategories = firstGame.supportedCategories
        
        let firstGameCategory = firstGame.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0
        var allGamesCategoryEqual = true
        for game in games {
            if (game.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0) != firstGameCategory {
                allGamesCategoryEqual = false
                break
            }
        }
        var selectedIndex: Int? = nil
        if allGamesCategoryEqual,
           firstGameCategory < supportedCategories.count,
        let index = supportedCategories.firstIndex(where: { $0 == supportedCategories[firstGameCategory] }) {
           selectedIndex = index
            
       }
        
        let cells = supportedCategories.enumerated().map { index, gameType in
            gameType.listCell(appending: .radio(.init(isSelected: selectedIndex == index)))
        }
        OptionsSheetView.show(icon: GameOption.changeCategory.icon,
                               title: R.string.localizable.changeCategory(),
                               cellOptions: cells,
                               completion: { index in
            if let index  {
                for game in games {
                    game.updateCategory(gameType: supportedCategories[index])
                    game.matchCover(force: true,
                                    useVirtualGameTypeIfNeed: true)
                }
                completion?(true)
            } else {
                completion?(false)
            }
        })
    }
}
