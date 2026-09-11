//
//  swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ASListPage {
    var navigation: Navigation? = nil
    var top: (view: UIView, layout: ASViewLayout, pin: Bool)? = nil
    var sections = [Section]()
    //fixed height: ButtonLarge
    var tool: Tool? = nil
    ///fixed height: ButtonExtraLarge
    var bottom: ASButton? = nil
    var blankSlate: BlankSlate? = nil
    var backgroundColor: UIColor = R.Color.BackgroundPrimary
    ///Insets for the scroll list, not including navigation, top...
    var listInsets: UIEdgeInsets = .zero
    ///The padding of the entire page, including all elements.
    var pageInsets: UIEdgeInsets = .zero
    ///If the safe area is enabled, elements near the edges will automatically indent into the safe area.
    var enableSafeAreaTopInsets: Bool = false
    var enableSafeAreaLeftInsets: Bool = false
    var enableSafeAreaRightInsets: Bool = false
    var enableSafeAreaBottomInsets: Bool = true
    
    var enableIndexView: Bool = false
    
    var enableLongPress: Bool = false
    
    static func optionsList(icon: ASIcon,
                            title: String,
                            detail: ASText? = nil,
                            options: [[String]],
                            selectedIndexPath: IndexPath? = nil,
                            cancelEnable: Bool = true,
                            optionsType: ASSheet.Style.OptionsType) -> ASListPage {
        var navigation = ASListPage.Navigation.defaultNavigation(title: title, titleIcon: icon)
        navigation.enableClose = cancelEnable
        
        var sections = [Section]()
        
        func genCellStyle(isSelected: Bool) -> ASListPage.Cell.Style? {
            switch optionsType {
            case .simple:
                return nil
            case .radio:
                return .radio(.init(isSelected: isSelected))
            case .check:
                return .check(.init(isSelected: isSelected))
            case .chevron:
                return .chevron(.init())
            }
        }
        
        for (sectionIndex, subOptions) in options.enumerated() {
            
            var cells = [ASListPage.Cell]()
            for (cellIndex, option) in subOptions.enumerated() {
                
                var cellStyles: [ASListPage.Cell.Style] = [.title(.largeText(option))]
                
                if let selectedIndexPath,
                   selectedIndexPath.section == sectionIndex,
                   selectedIndexPath.row == cellIndex {
                    if let cellStyle = genCellStyle(isSelected: true) {
                        cellStyles.append(cellStyle)
                    }
                    cells.append(ASListPage.Cell.normal(cellStyles))
                } else {
                    if let cellStyle = genCellStyle(isSelected: false) {
                        cellStyles.append(cellStyle)
                    }
                    cells.append(ASListPage.Cell.normal(cellStyles))
                }
            }
            
            if sectionIndex == 0, let detail {
                let header = Supplementary.texts([detail], pin: false)
                let section = ASListPage.Section(cells: cells, header: header)
                sections.append(section)
            } else {
                sections.append(ASListPage.Section(cells: cells))
            }
        }
        
        return ASListPage(navigation: navigation,
                          sections: sections,
                          backgroundColor: .clear)
        
    }
    
    static func simpleList(icon: ASIcon? = nil,
                           title: String = "",
                           detail: ASText? = nil,
                           options: [[ASListPage.Cell]],
                           cancelEnable: Bool = true) -> ASListPage {
        
        var navigation = ASListPage.Navigation.defaultNavigation(title: title,
                                                                 titleIcon: icon)
        navigation.enableClose = cancelEnable
        
        var sections = options.map({ Section(cells: $0)})
        
        if let detail, sections.count > 0 {
            sections[0].header = Supplementary.texts([detail], pin: false)
        }
        
        return ASListPage(navigation: navigation,
                          sections: sections,
                          backgroundColor: .clear)
        
    }
    
    enum Action {
        case normalItem(indexPath: IndexPath,
                        cellData: Cell,
                        subActions: (itemStyle: Cell.Style,
                                     extraValue: Any?)?)
        case inputItem(indexPath: IndexPath, action: ASInput.Action)
        case navigation(Navigation.Action)
        case tool(Tool.Action)
        case bottom
        case blankSlate
        case longPress(indexPath: IndexPath)
        
        var normalItemValue: (indexPath: IndexPath,
                              cellData: Cell,
                              subActions: (itemStyle: Cell.Style,
                                           extraValue: Any?)?)? {
            if case let .normalItem(indexPath, cellData, subActions) = self {
                return (indexPath, cellData, subActions)
            }
            return nil
        }
        
        var inputValue: (indexPath: IndexPath, action: ASInput.Action)? {
            if case let .inputItem(indexPath, action) = self {
                return (indexPath, action)
            }
            return nil
        }
        
        var navigationValue: Navigation.Action? {
            if case let .navigation(value) = self {
                return value
            }
            return nil
        }
        
        var toolValue: Tool.Action? {
            if case let .tool(value) = self {
                return value
            }
            return nil
        }
        
        var isBottom: Bool {
            if case .bottom = self {
                return true
            }
            return false
        }
        
        var isBlankSlate: Bool {
            if case .blankSlate = self {
                return true
            }
            return false
        }
        
        var longPressValue: IndexPath? {
            if case .longPress(let indexPath) = self {
                return indexPath
            }
            return nil
        }
    }
}

extension ASListPage {
    struct Section {
        var cells: [Cell] = []
        var header: Supplementary? = nil
        var footer: Supplementary? = nil
        var decoration = Decoration()
        var itemLayout: ASViewLayout = .fixedHeight(R.Size.ItemHeightLarge)
        
        struct Decoration {
            var enable: Bool = true
            var style: BackgroundStyle = .secondary
            
            enum BackgroundStyle {
                case primary
                case secondary
            }
        }
    }
}

extension ASListPage {
    enum Cell {
        case normal([Style], enablePressEffect: Bool = true)
        case input(ASInput)
        case custom(UIView)
        
        var normalValue: (styles: [Style], enablePressEffect: Bool)? {
            if case let .normal(value, enablePressEffect) = self {
                return (value, enablePressEffect)
            }
            return nil
        }
        
        var inputValue: ASInput? {
            if case let .input(value) = self {
                return value
            }
            return nil
        }
        
        var customValue: UIView? {
            if case let .custom(value) = self {
                return value
            }
            return nil
        }
        
        func updateNormalSwitch(state: ASSwitch.State) -> Self {
            if var styles = normalValue?.styles,
               let enablePressEffect = normalValue?.enablePressEffect,
               var style = styles.removeFirst(where: { $0.switchValue != nil })?.switchValue {
                style.state = state
                styles.append(.switch(style))
                return .normal(styles, enablePressEffect: enablePressEffect)
            }
            return self
        }
        
        func updateNormalChevron(title: String?) -> Self {
            if var styles = normalValue?.styles,
               let enablePressEffect = normalValue?.enablePressEffect,
               var style = styles.removeFirst(where: { $0.chevronValue != nil })?.chevronValue {
                style.title = title
                styles.append(.chevron(style))
                return .normal(styles, enablePressEffect: enablePressEffect)
            }
            return self
        }
        
        func updateNormalSegment(index: Int) -> Self {
            if var styles = normalValue?.styles,
               let enablePressEffect = normalValue?.enablePressEffect,
               var style = styles.removeFirst(where: { $0.segmentValue != nil })?.segmentValue {
                style.index = index
                styles.append(.segment(style))
                return .normal(styles, enablePressEffect: enablePressEffect)
            }
            return self
        }
        
        func updateNormalCheck(isSelected: Bool) -> Self {
            if var styles = normalValue?.styles,
               let enablePressEffect = normalValue?.enablePressEffect,
               var style = styles.removeFirst(where: { $0.checkValue != nil })?.checkValue {
                style.isSelected = isSelected
                styles.append(.check(.init(isSelected: isSelected)))
                return .normal(styles, enablePressEffect: enablePressEffect)
            }
            return self
        }
        
        func updateNormalRadio(isSelected: Bool) -> Self {
            if var styles = normalValue?.styles,
               let enablePressEffect = normalValue?.enablePressEffect,
               var style = styles.removeFirst(where: { $0.radioValue != nil })?.radioValue {
                style.isSelected = isSelected
                styles.append(.radio(.init(isSelected: isSelected)))
                return .normal(styles, enablePressEffect: enablePressEffect)
            }
            return self
        }
        
        ///icon: 24x24 title: 15 medium
        static func iconTitleChevronCell(icon: ASIcon? = nil,
                                         iconSize: CGFloat = R.Size.ButtonExtraExtraSmall,
                                         title: String? = nil,
                                         titleColor: UIColor = R.Color.LabelPrimary,
                                         chevronTitle: String? = nil) -> Self {
            var styles = [Style]()
            if let icon {
                styles.append(.icon(icon, iconSize: .fixSize(CGSize(iconSize))))
            }
            if let title {
                styles.append(.title(.largeText(title, color: titleColor)))
            }
            styles.append(.chevron(.init(title: chevronTitle)))
            return .normal(styles)
        }
        
        ///icon: 24x24 title: 15 medium
        static func iconTitleImageChevronCell(icon: ASIcon? = nil,
                                              title: String? = nil,
                                              titleColor: UIColor = R.Color.LabelPrimary,
                                              image: ASIcon? = nil) -> Self {
            var styles = [Style]()
            if let icon {
                styles.append(.icon(icon))
            }
            if let title {
                styles.append(.title(.largeText(title, color: titleColor)))
            }
            if let image {
                var button = ASButton.iconOnly(icon: image,
                                               iconSize: CGSize(R.Size.ButtonMedium))
                button.cornerStyle = .radius(R.Size.CornerRadiusMicro)
                styles.append(.button(button))
            }
            styles.append(.chevron(.init()))
            return .normal(styles)
        }
        
        ///icon: 24x24 title: 15 medium
        static func iconTitleDetailSwitchCell(icon: ASIcon? = nil,
                                              iconSize: ASListPage.Cell.Style.IconSize = .fixSize(CGSize(R.Size.ButtonExtraExtraSmall)),
                                              title: String? = nil,
                                              titleColor: UIColor = R.Color.LabelPrimary,
                                              detail: String? = nil,
                                              detailColor: UIColor = R.Color.LabelSecondary,
                                              state: ASSwitch.State = .off,
                                              enablePressEffect: Bool = true) -> Self {
            var styles = [Style]()
            if let icon {
                styles.append(.icon(icon, iconSize: iconSize))
            }
            if let title {
                styles.append(.title(.largeText(title, color: titleColor)))
            }
            if let detail {
                styles.append(.detail(.extraSmallText(detail, color: detailColor)))
            }
            styles.append(.switch(.init(state: state)))
            return .normal(styles, enablePressEffect: enablePressEffect)
        }
        
        static func iconTitleDetailCell(icon: ASIcon? = nil,
                                        iconSize: CGFloat = R.Size.ButtonExtraExtraSmall,
                                        title: String? = nil,
                                        titleColor: UIColor = R.Color.LabelPrimary,
                                        detail: String? = nil,
                                        detailColor: UIColor = R.Color.LabelSecondary,
                                        enablePressEffect: Bool = true) -> Self {
            var styles = [Style]()
            if let icon {
                styles.append(.icon(icon, iconSize: .fixSize(CGSize(iconSize))))
            }
            if let title {
                styles.append(.title(.largeText(title, color: titleColor)))
            }
            if let detail {
                styles.append(.detail(.extraSmallText(detail, color: detailColor)))
            }
            return .normal(styles, enablePressEffect: enablePressEffect)
        }
        
        static func iconTitleDetailChevronCell(icon: ASIcon? = nil,
                                               iconSize: CGFloat = R.Size.ButtonExtraExtraSmall,
                                               title: String? = nil,
                                               titleColor: UIColor = R.Color.LabelPrimary,
                                               detail: String? = nil,
                                               detailColor: UIColor = R.Color.LabelSecondary,
                                               chevronTitle: String? = nil) -> Self {
            let cell = iconTitleDetailCell(icon: icon,
                                           iconSize: iconSize,
                                           title: title,
                                           titleColor: titleColor,
                                           detail: detail,
                                           detailColor: detailColor)
            if var styles = cell.normalValue?.styles {
                styles.append(.chevron(.init(title: chevronTitle)))
                return .normal(styles)
            }
            return cell
        }
        
        static func iconTitleDetailRadioCell(icon: ASIcon? = nil,
                                             iconSize: CGFloat = R.Size.ButtonExtraExtraSmall,
                                             title: String? = nil,
                                             titleColor: UIColor = R.Color.LabelPrimary,
                                             detail: String? = nil,
                                             detailColor: UIColor = R.Color.LabelSecondary,
                                             isSelected: Bool = false) -> Self {
            let cell = iconTitleDetailCell(icon: icon,
                                           iconSize: iconSize,
                                           title: title,
                                           titleColor: titleColor,
                                           detail: detail,
                                           detailColor: detailColor)
            if var styles = cell.normalValue?.styles {
                styles.append(.radio(.init(isSelected: isSelected)))
                return .normal(styles)
            }
            
            return cell
        }
        
        static func iconTitleDetailCheckCell(icon: ASIcon? = nil,
                                             iconSize: CGFloat = R.Size.ButtonExtraExtraSmall,
                                             title: String? = nil,
                                             titleColor: UIColor = R.Color.LabelPrimary,
                                             detail: String? = nil,
                                             detailColor: UIColor = R.Color.LabelSecondary,
                                             isSelected: Bool = false) -> Self {
            let cell = iconTitleDetailCell(icon: icon,
                                           iconSize: iconSize,
                                           title: title,
                                           titleColor: titleColor,
                                           detail: detail,
                                           detailColor: detailColor)
            if var styles = cell.normalValue?.styles {
                styles.append(.check(.init(isSelected: isSelected)))
                return .normal(styles)
            }
            
            return cell
        }
        
        ///icon: 24x24 title: 15 medium
        static func iconTitleIconButtonChevronCell(icon: ASIcon? = nil,
                                                   title: String? = nil,
                                                   titleColor: UIColor = R.Color.LabelPrimary,
                                                   iconButton: ASIcon? = nil,
                                                   iconButtonBackground: UIColor? = nil,
                                                   iconInset: UIEdgeInsets = .init(inset: R.Size.ContentSpaceExtraSmall),
                                                   chevronTitle: String? = nil) -> Self {
            var styles = [Style]()
            if let icon {
                styles.append(.icon(icon))
            }
            if let title {
                styles.append(.title(.largeText(title, color: titleColor)))
            }
            if let iconButton {
                if let iconButtonBackground {
                    styles.append(.button(.smallIconButton(icon: iconButton,
                                                           background: iconButtonBackground,
                                                           insets: iconInset)))
                } else {
                    styles.append(.button(.smallIconButton(icon: iconButton,
                                                           insets: iconInset)))
                }
            }
            styles.append(.chevron(.init(title: chevronTitle)))
            return .normal(styles)
        }
        
        ///icon: 24x24 title: 15 medium
        static func iconTitleIconButtonRadioCell(icon: ASIcon? = nil,
                                                 iconSize: CGFloat = R.Size.ButtonExtraExtraSmall,
                                                 title: String? = nil,
                                                 titleColor: UIColor = R.Color.LabelPrimary,
                                                 button: ASButton? = nil,
                                                 isSelected: Bool = false) -> Self {
            var styles = [Style]()
            if let icon {
                styles.append(.icon(icon, iconSize: .fixSize(CGSize(iconSize))))
            }
            if let title {
                styles.append(.title(.largeText(title, color: titleColor)))
            }
            if let button {
                styles.append(.button(button))
            }
            styles.append(.radio(.init(isSelected: isSelected)))
            return .normal(styles)
        }
        
        ///icon: 24x24 title: 15 medium
        static func iconTitleProgressCell(icon: ASIcon? = nil,
                                                title: String? = nil,
                                                titleColor: UIColor = R.Color.LabelPrimary,
                                                progress: ASProgress) -> Self {
            var styles = [Style]()
            if let icon {
                styles.append(.icon(icon))
            }
            if let title {
                styles.append(.title(.largeText(title, color: titleColor)))
            }
            styles.append(.progress(progress))
            return .normal(styles, enablePressEffect: false)
        }
        
        enum Style {
            enum IconSize: Equatable {
                case fixHeight(CGFloat)
                case fixSize(CGSize)
                case autoLayout
            }
            
            case icon(ASIcon, iconSize: IconSize = .fixSize(CGSize(R.Size.ButtonExtraExtraSmall)))
            case title(ASText, subTitle: ASText? = nil, subtitleFollows: Bool = true, enabledInteraction: Bool = false)
            case detail(ASText, enabledInteraction: Bool = false)
            case button(ASButton)
            case `switch`(ASSwitch)
            case step(ASStep)
            case check(ASCheck)
            case radio(ASRadio)
            case chevron(ASChevron)
            case progress(ASProgress) //0-1
            case segment(ASSegment)
            
            var iconValue: (ASIcon, iconSize: IconSize)? {
                if case let .icon(icon, iconSize) = self {
                    return (icon, iconSize)
                }
                return nil
            }
            
            var titleValue: (ASText, subTitle: ASText?, subtitleFollows: Bool, enabledInteraction: Bool)? {
                if case let .title(text, subTitle, subtitleFollows, enabledInteraction) = self {
                    return (text, subTitle, subtitleFollows, enabledInteraction)
                }
                return nil
            }
            
            var detailValue: (ASText, enabledInteraction: Bool)? {
                if case let .detail(value, enabledInteraction) = self {
                    return (value, enabledInteraction)
                }
                return nil
            }
            
            var buttonValue: ASButton? {
                if case let .button(value) = self {
                    return value
                }
                return nil
            }
            
            var switchValue: ASSwitch? {
                if case let .switch(value) = self {
                    return value
                }
                return nil
            }
            
            var stepValue: ASStep? {
                if case let .step(value) = self {
                    return value
                }
                return nil
            }
            
            var checkValue: ASCheck? {
                if case let .check(value) = self {
                    return value
                }
                return nil
            }
            
            var radioValue: ASRadio? {
                if case let .radio(value) = self {
                    return value
                }
                return nil
            }
            
            var chevronValue: ASChevron? {
                if case let .chevron(value) = self {
                    return value
                }
                return nil
            }
            
            var progressValue: ASProgress? {
                if case let .progress(value) = self {
                    return value
                }
                return nil
            }
            
            var segmentValue: ASSegment? {
                if case let .segment(value) = self {
                    return value
                }
                return nil
            }
        }
    }
}

extension ASListPage {
    enum Supplementary {
        case texts([ASText], pin: Bool)
        case buttons([ASButton], pin: Bool)
        case custom(UIView, pin: Bool, height: CGFloat)
        
        static func defaultHeader(title: String) -> Self {
            var button = ASButton.headerTitle(title: title)
            button.state = .disabled
            return .buttons([button], pin: false)
        }
    }
}

extension ASListPage {
    struct Navigation {
        var title: ASText? = nil
        var titleIcon: ASIcon? = nil
        var detail: ASText? = nil
        var tools: [ASIcon] = []
        var edit: String? = nil
        var backgroundColor: UIColor = .clear
        var enableClose = true
        var state: State = .normal
        var enableTitleInteractive: Bool = false
        var toolsBackground: UIColor = R.Color.BackgroundSecondary
        var closeBackground: UIColor = R.Color.BackgroundSecondary
        
        static func defaultNavigation(title: String? = nil,
                                      titleLineBreakMode: NSLineBreakMode = .byTruncatingTail,
                                      titleIcon: ASIcon? = nil,
                                      detail: String? = nil,
                                      detailIcon: ASIcon? = nil,
                                      tools: [ASIcon] = [],
                                      edit: String? = nil,
                                      backgroundColor: UIColor = .clear) -> Self {
            var newTitleIcon = titleIcon
            if let titleIcon {
                switch titleIcon {
                case .symbol(let sFSymbol, _, _, _, let animated):
                    newTitleIcon = .symbol(sFSymbol, weight: .bold, animated: animated)
                case .symbolImage(let uIImage, _, _, _, let animated):
                    newTitleIcon = .symbolImage(uIImage, weight: .bold, animated: animated)
                default:
                    break
                }
            }
            
            var newTitle: ASText? = nil
            if let title {
                newTitle = .init(attributes: .init(text: title,
                                                   font: R.Font.Headline(emphasis: true),
                                                   lineBreakMode: titleLineBreakMode))
            }
            
            var newDetail: ASText? = nil
            if let detail {
                newDetail = .extraSmallText(detail)
            }
            
            if let detailIcon {
                let icon = detailIcon.updateColorsIfNeed(colors: [R.Color.LabelSecondary], forceUpdate: true)
                let iconSize = R.Font.Caption().pointSize
                if newDetail == nil {
                    newDetail = .init(textIcons: [.init(icon: icon, iconSize: iconSize)])
                } else {
                    newDetail?.textIcons = [.init(icon: icon, iconSize: iconSize)]
                }
            }
            
            return Navigation(title: newTitle,
                              titleIcon: newTitleIcon,
                              detail: newDetail,
                              tools: tools,
                              edit: edit)
            
        }
        
        static func moreSettings() -> Self {
            return .defaultNavigation(title: R.string.localizable.moreSettingTitle(), titleIcon: .symbolImage(R.image.ellipsis_iconSymbols()))
        }
        
        enum Action {
            case tapClose
            case tapTools(Int)
            case tapTitle
            case tapCancel
            case tapEdit
            
            var isTapClose: Bool {
                if case .tapClose = self {
                    return true
                }
                return false
            }
            
            var tapToolsValue: Int? {
                if case .tapTools(let index) = self {
                    return index
                }
                return nil
            }
            
            var isTapTitle: Bool {
                if case .tapTitle = self {
                    return true
                }
                return false
            }
            
            var isTapCancel: Bool {
                if case .tapCancel = self {
                    return true
                }
                return false
            }
            
            var isTapEdit: Bool {
                if case .tapEdit = self {
                    return true
                }
                return false
            }
        }
        
        enum State {
            case normal
            case edit
        }
    }
}

extension ASListPage {
    struct Tool {
        enum Action {
            case tapMain
            case tapOthers(index: Int)
            
            var isTapMain: Bool {
                if case .tapMain  = self {
                    return true
                }
                return false
            }
            
            var tapOthersValue: Int? {
                if case let .tapOthers(index)  = self {
                    return index
                }
                return nil
            }
        }
        
        var mainIcon: ASIcon
        var otherIcons: [ASIcon] = []
        var hideMainIcon: Bool = false
        
        static func defaultTool(otherIcons: [ASIcon], hideMainIcon: Bool = false) -> Self {
            Self(mainIcon: .symbolImage(R.image.ellipsis_iconSymbols()),
                 otherIcons: otherIcons,
                 hideMainIcon: hideMainIcon)
        }
    }
}

extension ASListPage {
    struct BlankSlate {
        var icon: ASIcon = .image(R.image.empty_icon()!)
        var iconLayout: ASViewLayout = .fixedSize(CGSize(width: 100, height: 72))
        var title: String = R.string.localizable.blankStateTitle()
        var detail: String? = nil
        var button: ASButton? = nil
        var layoutInsets: UIEdgeInsets = .zero
    }
}
