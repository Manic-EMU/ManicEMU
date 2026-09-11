//
//  GameMetadataView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/12.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class GameMetadataView: BaseView {
    private static let overviewMaxHeight: CGFloat = 90
    private static let esrpSectionHeight: CGFloat = 90
    private static let overviewSectionHeight: CGFloat = 200
    
    private lazy var overviewLabel: ASLabelView = {
        let view = ASLabelView()
        view.setContentHuggingPriority(.defaultHigh, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var moreMetadataButton: ASButtonView = {
        let view = ASButtonView(.small(icon: .symbol(.chevronRight, colors: [R.Color.LabelSecondary]),
                                       title: R.string.localizable.checkMetadata(),
                                       titleColor: R.Color.LabelSecondary,
                                       titlePosition: .left,
                                       background: R.Color.BackgroundTertiary,
                                       sizeStyle: .fixHeight(R.Size.ButtonSmall,
                                                             insets: UIEdgeInsets(horizontal: R.Size.ContentSpaceSmall*2, vertical: R.Size.ContentSpaceTiny*2))))
        view.didTapButton = { [weak self] in
            self?.didTapMoreMetadata?()
        }
        return view
    }()
    
    var didTapMoreMetadata: (() -> Void)? = nil
    
    init(overview: String) {
        super.init(frame: .zero)
        
        var text = ASText.mediumText(overview, numberOfLines: 0)
        if var attributes = text.attributes {
            attributes.lineBreakMode = .byTruncatingTail
            text.attributes = attributes
        }
        overviewLabel.text = text
        
        addSubview(overviewLabel)
        addSubview(moreMetadataButton)
        
        overviewLabel.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.lessThanOrEqualTo(Self.overviewMaxHeight)
        }
        
        moreMetadataButton.snp.makeConstraints { make in
            make.top.equalTo(overviewLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.centerX.equalToSuperview()
            make.height.equalTo(R.Size.ButtonSmall)
            // GameOptions 里该 view 用 .autoLayout，compositional 估高先给 Encapsulated-Height=60；
            // bottom 用高优先级而非 required，避免测量阶段把按钮/图标约束打断。
            make.bottom.equalToSuperview().inset(R.Size.ContentSpaceMedium).priority(.high)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let maxWidth = bounds.width - R.Size.ContentSpaceMedium * 2
        if maxWidth > 0 {
            overviewLabel.preferredMaxLayoutWidth = maxWidth
        }
    }
}

extension GameMetadataView {
    private enum Section: Int, CaseIterable {
        case developer
        case publisher
        case esrpRating
        case franchise
        case releaseDate
        case region
        case genre
        case overview
        
        var title: String {
            switch self {
            case .developer: return R.string.localizable.developer()
            case .publisher: return R.string.localizable.publisher()
            case .esrpRating: return R.string.localizable.esrbRating()
            case .franchise: return R.string.localizable.franchise()
            case .releaseDate: return R.string.localizable.releaseDate()
            case .region: return R.string.localizable.region()
            case .genre: return R.string.localizable.genre()
            case .overview: return R.string.localizable.overview()
            }
        }
    }
    
    private enum NavTool: Int {
        case refresh = 0
        case search = 1
    }
    
    private final class MetadataBox {
        var value: GameMetadata
        init(_ value: GameMetadata) {
            self.value = value
        }
    }
    
    /// Overview 可编辑输入容器，样式对齐 ASListInputView（圆角 + 描边）
    private final class OverviewEditorView: BaseView {
        private let textView = ASTextView()
        var didTextChange: ((String) -> Void)?
        
        init(text: String) {
            super.init(frame: .zero)
            isFocusable = true
            onFocusConfirm = { [weak self] in
                self?.textView.becomeFirstResponder()
                return true
            }
            
            
            backgroundColor = R.Color.InputBox
            masksToBounds = true
            layerBorderWidth = R.Size.Border
            
            textView.isEditable = true
            textView.text = ASText.mediumText(text, numberOfLines: 0)
            textView.didTextChange = { [weak self] value in
                self?.didTextChange?(value)
            }
            
            addSubview(textView)
            textView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(R.Size.ContentSpaceSmall)
            }
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layerCornerRadius = R.Size.ContentSpaceMedium
            layerBorderColor = R.Color.Border
        }
    }
    
    static func show(game: Game) {
        let box = MetadataBox(GameMetadata.resolved(for: game))
        
        func persist() {
            box.value.persist(to: game)
        }
        
        func makeListPage() -> ASListPage {
            ASListPage(navigation: makeNavigation(game: game),
                       sections: makeSections(box: box, persist: persist),
                       backgroundColor: .clear,
                       pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
        }
        
        ASSheetView.show(.init(style: .listPage(makeListPage())), action: { action, updation in
            if action.listPageValue?.navigationValue?.isTapClose == true {
                return .dismiss()
            }
            
            if let toolIndex = action.listPageValue?.navigationValue?.tapToolsValue {
                handleNavTool(index: toolIndex,
                              box: box,
                              game: game,
                              updation: updation,
                              makeListPage: makeListPage)
                return .none
            }
            
            if let inputValue = action.listPageValue?.inputValue {
                applyInput(box: box,
                           indexPath: inputValue.indexPath,
                           inputAction: inputValue.action)
                persist()
                return .none
            }
            
            if let normal = action.listPageValue?.normalItemValue,
               let section = Section(rawValue: normal.indexPath.section) {
                switch section {
                case .esrpRating:
                    showESRPOptions(box: box, game: game, updation: updation, makeListPage: makeListPage)
                case .releaseDate:
                    showReleaseDatePicker(box: box, game: game, updation: updation, makeListPage: makeListPage)
                default:
                    break
                }
            }
            
            return .none
        })
    }
    
    private static func makeNavigation(game: Game) -> ASListPage.Navigation {
        .defaultNavigation(title: game.displayName,
                           titleIcon: game.gameCoverIcon,
                           tools: [
                            .symbolImage(R.image.refresh_iconSymbols()),
                            .symbolImage(R.image.searchRegular_iconSymbols())
                           ])
    }
    
    private static func handleNavTool(index: Int,
                                      box: MetadataBox,
                                      game: Game,
                                      updation: ASSheetView.ASSheetViewUpdation?,
                                      makeListPage: @escaping () -> ASListPage) {
        guard let tool = NavTool(rawValue: index) else { return }
        switch tool {
        case .refresh:
            // Kit miss still resets: custom extras must be clearable even without an official record.
            let metadata = GameMetadataKit.getGameInfo(game: game) ?? GameMetadata()
            box.value = metadata
            metadata.persist(to: game)
            updation?(.listPage(makeListPage()))
        case .search:
            GameMetadataSearchView.show(game: game) { metadata in
                box.value = metadata
                metadata.persist(to: game)
                updation?(.listPage(makeListPage()))
            }
        }
    }
    
    private static func makeSections(box: MetadataBox,
                                     persist: @escaping () -> Void) -> [ASListPage.Section] {
        let metadata = box.value
        return Section.allCases.map { section in
            switch section {
            case .developer:
                return .init(cells: [.input(.large(text: metadata.developer, placeholder: "Developer"))],
                             header: .defaultHeader(title: section.title),
                             decoration: .init(style: .primary))
            case .publisher:
                return .init(cells: [.input(.large(text: metadata.publisher, placeholder: "Publisher"))],
                             header: .defaultHeader(title: section.title),
                             decoration: .init(style: .primary))
            case .esrpRating:
                var noESRP: Bool = true
                if let _ = metadata.ESRPRating {
                    noESRP = false
                }
                
                return .init(cells: [makeESRPCell(metadata: metadata)],
                             header: .defaultHeader(title: section.title),
                             decoration: .init(style: .primary),
                             itemLayout: noESRP ? .fixedHeight(R.Size.ItemHeightLarge) : .fixedHeight(esrpSectionHeight))
            case .franchise:
                return .init(cells: [.input(.large(text: metadata.franchise, placeholder: "Franchise"))],
                             header: .defaultHeader(title: section.title),
                             decoration: .init(style: .primary))
            case .releaseDate:
                return .init(cells: [.iconTitleDetailChevronCell(icon: .symbol(.calendar),
                                                                 title: "Release Date",
                                                                 detail: metadata.releaseDateDisplay)],
                             header: .defaultHeader(title: section.title),
                             decoration: .init(style: .primary))
            case .region:
                return .init(cells: [.input(.large(text: metadata.region, placeholder: "Region"))],
                             header: .defaultHeader(title: section.title),
                             decoration: .init(style: .primary))
            case .genre:
                return .init(cells: [.input(.large(text: metadata.genre, placeholder: "Genre"))],
                             header: .defaultHeader(title: section.title),
                             decoration: .init(style: .primary))
            case .overview:
                let editor = OverviewEditorView(text: metadata.overview)
                editor.didTextChange = { text in
                    box.value.overview = text
                    persist()
                }
                return .init(cells: [.custom(editor)],
                             header: .defaultHeader(title: section.title),
                             decoration: .init(style: .primary),
                             itemLayout: .fixedHeight(overviewSectionHeight))
            }
        }
    }
    
    private static func makeESRPCell(metadata: GameMetadata) -> ASListPage.Cell {
        if let rating = metadata.ESRPRating {
            return .normal([
                .icon(rating.icon, iconSize: .fixSize(CGSize(R.Size.ButtonExtraLarge))),
                .title(.largeText(rating.abbr)),
                .detail(.extraSmallText(rating.desc, numberOfLines: 0)),
                .chevron(.init())
            ])
        }
        return .iconTitleDetailChevronCell(icon: .symbol(.starCircle),
                                           iconSize: R.Size.ButtonExtraSmall,
                                           title: "未分级")
    }
    
    private static func makeESRPOptionCell(rating: ESRP?, isSelected: Bool) -> ASListPage.Cell {
        if let rating {
            return .normal([
                .icon(rating.icon, iconSize: .fixSize(CGSize(R.Size.ButtonSmall))),
                .title(.largeText(rating.abbr)),
                .detail(.extraSmallText(rating.desc, numberOfLines: 0)),
                .radio(.init(isSelected: isSelected))
            ])
        }
        return .iconTitleDetailRadioCell(icon: .symbol(.starCircle),
                                         iconSize: R.Size.ButtonExtraSmall,
                                         title: "未分级",
                                         isSelected: isSelected)
    }
    
    private static func applyInput(box: MetadataBox,
                                   indexPath: IndexPath,
                                   inputAction: ASInput.Action) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        
        let text: String
        switch inputAction {
        case .textChange(let value):
            text = value ?? ""
        case .tapClear:
            text = ""
        case .tapReturn(let value):
            text = value ?? ""
        }
        
        switch section {
        case .developer:
            box.value.developer = text
        case .publisher:
            box.value.publisher = text
        case .franchise:
            box.value.franchise = text
        case .region:
            box.value.region = text
        case .genre:
            box.value.genre = text
        case .overview, .esrpRating, .releaseDate:
            break
        }
    }
    
    private static func showESRPOptions(box: MetadataBox,
                                        game: Game,
                                        updation: ASSheetView.ASSheetViewUpdation?,
                                        makeListPage: @escaping () -> ASListPage) {
        let ratings: [ESRP?] = [nil] + ESRP.allCases.map { Optional($0) }
        let sections = ratings.map { rating in
            var noESRP: Bool = true
            if let _ = rating {
                noESRP = false
            }
            
            return ASListPage.Section(cells: [makeESRPOptionCell(rating: rating,
                                                                 isSelected: box.value.ESRPRating == rating)],
                                      itemLayout: noESRP ? .fixedHeight(R.Size.ItemHeightLarge) : .fixedHeight(esrpSectionHeight))
        }
        
        let listPage = ASListPage(navigation: .defaultNavigation(title: "ESRB Rating",
                                                                 titleIcon: box.value.ESRPRating?.icon ?? .symbol(.starCircle)),
                                  sections: sections,
                                  backgroundColor: .clear)
        
        ASSheetView.show(.init(style: .listPage(listPage)), action: { action, _ in
            if action.listPageValue?.navigationValue?.isTapClose == true {
                return .dismiss()
            }
            if let indexPath = action.listPageValue?.normalItemValue?.indexPath,
               ratings.indices.contains(indexPath.section) {
                box.value.setESRP(ratings[indexPath.section])
                box.value.persist(to: game)
                return .dismiss {
                    updation?(.listPage(makeListPage()))
                }
            }
            return .none
        })
    }
    
    private static func showReleaseDatePicker(box: MetadataBox,
                                              game: Game,
                                              updation: ASSheetView.ASSheetViewUpdation?,
                                              makeListPage: @escaping () -> ASListPage) {
        let currentYear = Calendar.current.component(.year, from: Date())
        let years = Array(1970...(currentYear + 1))
        let yearDatas = [R.string.localizable.unknown()] + years.map { "\($0)" }
        var selectedYearIndex = 0
        if box.value.releaseYear > 0,
           let index = years.firstIndex(of: box.value.releaseYear) {
            selectedYearIndex = index + 1
        }
        var pendingYearIndex = selectedYearIndex
        
        ASSheetView.show(.init(style: .picker(title: "Release Year",
                                              datas: yearDatas,
                                              selectedIndex: selectedYearIndex)),
                         action: { action, _ in
            if let index = action.pickerValue?.index {
                pendingYearIndex = index
            }
            return .none
        }, dismiss: {
            if pendingYearIndex == 0 {
                box.value.releaseYear = 0
                box.value.releaseMonth = 0
                box.value.persist(to: game)
                updation?(.listPage(makeListPage()))
                return
            }
            
            let year = years[pendingYearIndex - 1]
            showReleaseMonthPicker(year: year,
                                   box: box,
                                   game: game,
                                   updation: updation,
                                   makeListPage: makeListPage)
        })
    }
    
    private static func showReleaseMonthPicker(year: Int,
                                               box: MetadataBox,
                                               game: Game,
                                               updation: ASSheetView.ASSheetViewUpdation?,
                                               makeListPage: @escaping () -> ASListPage) {
        let months = Array(1...12)
        let monthDatas = months.map { String(format: "%02d", $0) }
        let selectedMonthIndex = max(0, min(11, (box.value.releaseMonth > 0 ? box.value.releaseMonth : 1) - 1))
        var pendingMonthIndex = selectedMonthIndex
        
        ASSheetView.show(.init(style: .picker(title: "Release Month",
                                              datas: monthDatas,
                                              selectedIndex: selectedMonthIndex)),
                         action: { action, _ in
            if let index = action.pickerValue?.index {
                pendingMonthIndex = index
            }
            return .none
        }, dismiss: {
            box.value.releaseYear = year
            box.value.releaseMonth = months[pendingMonthIndex]
            box.value.persist(to: game)
            updation?(.listPage(makeListPage()))
        })
    }
}
