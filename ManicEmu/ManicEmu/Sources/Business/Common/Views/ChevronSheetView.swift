//
//  ChevronSheetView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/29.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ChevronSheetView: BaseView {
    
    ///Show commonly used chevron sheet
    ///cancelEnable：If disabled, users won’t be able to close the form unless they make a selection.
    ///groupTogether: Should the options be grouped together, or should each option be treated as a separate group?
    ///completion：If dismissOnTap is true, this callback will be executed after the sheet is dismissed. If dismissOnTap is false, this callback will be executed immediately after the user taps.
    static func show(icon: ASIcon = .symbolImage(R.image.ellipsis_iconSymbols()),
                     title: String = R.string.localizable.moreSettingTitle(),
                     detail: String? = nil,
                     stringOptions: [String],
                     cancelEnable: Bool = true,
                     groupTogether: Bool = false,
                     dismissOnTap: Bool = true,
                     completion: ((_ index: Int?)->Void)? = nil ) {
        show(icon: icon,
             title: title,
             detail: detail,
             cellOptions: stringOptions.map({ ASListPage.Cell.iconTitleChevronCell(title: $0) }),
             cancelEnable: cancelEnable,
             groupTogether: groupTogether,
             dismissOnTap: dismissOnTap,
             completion: completion)
    }
    
    static func show(icon: ASIcon = .symbolImage(R.image.ellipsis_iconSymbols()),
                     title: String = R.string.localizable.moreSettingTitle(),
                     detail: String? = nil,
                     cellOptions: [ASListPage.Cell],
                     cancelEnable: Bool = true,
                     groupTogether: Bool = false,
                     dismissOnTap: Bool = true,
                     completion: ((_ index: Int?)->Void)? = nil ) {
        guard cellOptions.count > 0 else {
            completion?(nil)
            return
        }
        
        var detailText: ASText? = nil
        if let detail {
            detailText = .smallText(detail, numberOfLines: 0)
        }
        
        let sheetData = ASSheet(style: .simpleList(icon: icon,
                                                   title: title,
                                                   detail: detailText,
                                                   options: groupTogether ? [cellOptions] : cellOptions.map({ [$0] }),
                                                   cancelEnable: cancelEnable))
        
        var didComplete = false
        
        ASSheetView.show(sheetData, action: { sheetAction, _ in
            if let indexPath = sheetAction.listPageValue?.normalItemValue?.indexPath {
                let index = groupTogether ? indexPath.row : indexPath.section
                if dismissOnTap {
                    didComplete = true
                    return .dismiss {
                        completion?(index)
                    }
                } else {
                    completion?(index)
                    return .none
                }
            } else if let isTapClose = sheetAction.listPageValue?.navigationValue?.isTapClose, isTapClose {
                didComplete = true
                return .dismiss {
                    completion?(nil)
                }
            }
            return .none
        }, dismiss: {
            if !didComplete {
                completion?(nil)
            }
        })
    }
    
    /// Chevron sheet with named sections. `completion` receives the tapped `IndexPath`.
    static func show(icon: ASIcon = .symbolImage(R.image.ellipsis_iconSymbols()),
                     title: String = R.string.localizable.moreSettingTitle(),
                     detail: String? = nil,
                     sections: [(header: String?, cells: [ASListPage.Cell])],
                     cancelEnable: Bool = true,
                     dismissOnTap: Bool = true,
                     completion: ((_ indexPath: IndexPath?) -> Void)? = nil) {
        let validSections = sections.filter({ !$0.cells.isEmpty })
        guard validSections.count > 0 else {
            completion?(nil)
            return
        }
        
        var navigation = ASListPage.Navigation.defaultNavigation(title: title, titleIcon: icon)
        navigation.enableClose = cancelEnable
        
        let listSections: [ASListPage.Section] = validSections.enumerated().map { index, section in
            var header: ASListPage.Supplementary? = nil
            if let headerTitle = section.header, !headerTitle.isEmpty {
                header = .defaultHeader(title: headerTitle)
            }
            if index == 0, let detail, !detail.isEmpty {
                var texts = [ASText.smallText(detail, numberOfLines: 0)]
                if let headerTitle = section.header, !headerTitle.isEmpty {
                    texts.append(.init(attributes: .init(text: headerTitle,
                                                         color: R.Color.LabelSecondary,
                                                         font: R.Font.Subheadline(emphasis: true))))
                }
                header = .texts(texts, pin: false)
            }
            return .init(cells: section.cells, header: header)
        }
        
        let listPage = ASListPage(navigation: navigation,
                                  sections: listSections,
                                  backgroundColor: .clear)
        var didComplete = false
        ASSheetView.show(.init(style: .listPage(listPage)), action: { sheetAction, _ in
            if let indexPath = sheetAction.listPageValue?.normalItemValue?.indexPath {
                if dismissOnTap {
                    didComplete = true
                    return .dismiss {
                        completion?(indexPath)
                    }
                } else {
                    completion?(indexPath)
                    return .none
                }
            } else if let isTapClose = sheetAction.listPageValue?.navigationValue?.isTapClose, isTapClose {
                didComplete = true
                return .dismiss {
                    completion?(nil)
                }
            }
            return .none
        }, dismiss: {
            if !didComplete {
                completion?(nil)
            }
        })
    }
}
