//
//  ASListPageView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/8.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASListPageView: BaseView {
    //MARK: - Size constant
    private static let sectionTopInsetsWithoutHeader = R.Size.ContentSpaceLarge
    private static let sectionBottomInsetsWithFooter = R.Size.ContentSpaceSmall/2
    private static let sectionHorizontalInsets = R.Size.ContentSpaceMedium
    private static let supplementaryHorizontalInsets = R.Size.ContentSpaceExtraSmall
    private static let navigationHeight = R.Size.NavigationHeight
    private static let bottomButtonHeight = R.Size.ButtonExtraLarge
    private static let toolViewHeight = R.Size.ButtonLarge
    
    //MARK: - UI data source
    private var listPage: ASListPage
    var navigation: ASListPage.Navigation? {
        get { listPage.navigation }
        set {
            listPage.navigation = newValue
            updateNavigationView()
        }
    }
    var sections: [ASListPage.Section] {
        get { listPage.sections }
        set {
            listPage.sections = newValue
            updateCollectionView()
        }
    }
    var top: (view: UIView, layout: ASViewLayout, pin: Bool)? {
        get { listPage.top }
        set {
            listPage.top = newValue
            updateTopView()
        }
    }
    var tool: ASListPage.Tool? {
        get { listPage.tool }
        set {
            listPage.tool = newValue
            updateToolView()
        }
    }
    var bottom: ASButton?{
        get { listPage.bottom }
        set {
            listPage.bottom = newValue
            updateBottomView()
        }
    }
    var blankSlate: ASListPage.BlankSlate? {
        get { listPage.blankSlate }
        set {
            listPage.blankSlate = newValue
            updateBlankSlateView()
        }
    }
    var listInsets: UIEdgeInsets {
        get { listPage.listInsets }
        set {
            listPage.listInsets = newValue
            updateCollectionViewInsets()
        }
    }
    var pageInsets: UIEdgeInsets {
        get { listPage.pageInsets }
        set {
            listPage.pageInsets = newValue
            updateViews()
        }
    }
    var enableSafeAreaTopInsets: Bool {
        get { listPage.enableSafeAreaTopInsets }
        set {
            listPage.enableSafeAreaTopInsets = newValue
            if listPage.navigation != nil {
                updateNavigationView()
            } else if listPage.top != nil {
                updateTopView()
            } else {
                updateCollectionView()
            }
        }
    }
    var enableSafeAreaLeftInsets: Bool {
        get { listPage.enableSafeAreaLeftInsets }
        set {
            listPage.enableSafeAreaLeftInsets = newValue
            updateViews()
        }
    }
    var enableSafeAreaRightInsets: Bool {
        get { listPage.enableSafeAreaRightInsets }
        set {
            listPage.enableSafeAreaRightInsets = newValue
            updateViews()
        }
    }
    var enableSafeAreaBottomInsets: Bool {
        get { listPage.enableSafeAreaBottomInsets }
        set {
            listPage.enableSafeAreaBottomInsets = newValue
            updateCollectionViewInsets()
            if listPage.bottom != nil {
                updateBottomView()
            } else if listPage.tool != nil {
                updateToolView()
            }
        }
    }
    var enableIndexView: Bool {
        get { listPage.enableIndexView }
        set {
            listPage.enableIndexView = newValue
            updateIndexView()
        }
    }
    var contentsBottomInset: CGFloat {
        listInsets.bottom + pageInsets.bottom + (enableSafeAreaBottomInsets ? R.Size.SafeArea.bottom : 0)
    }
    
    //MARK: - Subviews
    private var navigationView: ASNavigationView? = nil
    private lazy var topContainer: UIView = UIView()
    private var mountedTopView: UIView? = nil
    lazy var collectionView: BlankSlateCollectionView = {
        let view = BlankSlateCollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        
        view.register(cellWithClass: ASListItemCollectionCell.self)
        view.register(cellWithClass: ASListInputCollectionCell.self)
        view.register(cellWithClass: ASListCustomCollectionCell.self)
        
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                      withClass: ASListSupplementaryReusableView.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                      withClass: ASListSupplementaryReusableView.self)
        
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.contentInset = listInsets
        view.isFocusable = true
        return view
    }()
    private var toolView: ASListToolView? = nil
    private var bottomButton: ASButtonView? = nil
    private var indexView: SectionIndexView? = nil
    
    //MARK: - Scroll-related
    private var collectionEqualToTopViewBottom: Constraint? = nil
    private var lastContentOffsetY = 0.0
    private var lastToolViewScrollTimestamp: TimeInterval = 0
    private var isToolViewScrollInitialized = false
    
    //MARK: - Reorder-related
    private var reorderScope: ReorderScope = .item
    private var keepSupplementaryPlace = false
    private var beginReorder: ((IndexPath) -> Bool)? = nil
    private var itemReorderDidUpdate: ((ItemReorderIntent) -> Bool)? = nil
    private var itemDidReorder: ((ItemReorderIntent) -> Void)? = nil
    private var sectionReorderDidUpdate: ((SectionReorderIntent) -> Bool)? = nil
    private var sectionDidReorder: ((SectionReorderIntent) -> Void)? = nil
    private var pendingItemIntent: ItemReorderIntent? = nil
    private var sectionDragOriginalIndex: Int?
    private var sectionDragCurrentIndex: Int?
    private var sectionDragDidComplete = false
    private var itemDragOriginalIndexPath: IndexPath?
    private var itemDragDidComplete = false
    private var itemDragGapPreviewAtSection: Int?
    private var gapPreviewHeight: CGFloat {
        if let source = itemDragOriginalIndexPath, source.section < listPage.sections.count {
            switch listPage.sections[source.section].itemLayout {
            case .fixedHeight(let height):
                return height
            default:
                break
            }
        }
        return R.Size.ItemHeightLarge
    }
    
    //MARK: - Blocks
    var didActionOccurred: ((ASListPage.Action) -> Void)? = nil
    var didScroll: ((UIScrollView)->Void)? = nil
    
    //MARK: - Functions
    init(_ listPage: ASListPage) {
        self.listPage = listPage
        if listPage.sections.count == 0 {
            //Prevent constraint errors
            super.init(frame: .init(origin: .zero, size: R.Size.WindowSize))
        } else {
            super.init(frame: .zero)
        }
        updateViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//MARK: - UI-related Functions
extension ASListPageView {
    /// Text width used by both supplementary items and decoration insets.
    /// Falls back when the collection view has not received a real bounds yet.
    private func supplementaryTextWidth(in env: NSCollectionLayoutEnvironment) -> CGFloat {
        let containerWidth = env.container.effectiveContentSize.width
        let fallbackWidth = max(collectionView.bounds.width, bounds.width)
        let width = containerWidth > 1 ? containerWidth : fallbackWidth
        let resolved = width > 1 ? width : R.Size.WindowWidth
        return max(resolved - Self.sectionHorizontalInsets * 2 - Self.supplementaryHorizontalInsets * 2, 1)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, env in
            guard let self else { return nil }
            
            //sectionData
            let sectionData = self.sections[sectionIndex]
            
            
            //HeightDimension
            let groupHeightDimension: NSCollectionLayoutDimension
            switch sectionData.itemLayout {
            case .fixedHeight(let height):
                groupHeightDimension = .absolute(height)
            default:
                groupHeightDimension = .estimated(R.Size.CellHeight)
            }
            
            //item
            let itemLayoutSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                        heightDimension: groupHeightDimension)
            let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
            
            //group
            let groupLayoutSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                         heightDimension: groupHeightDimension)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupLayoutSize,
                                                         subitems: [item])
            
            //section
            let section = NSCollectionLayoutSection(group: group)
            let supplementaryTextWidth = self.supplementaryTextWidth(in: env)
            
            //gen header or footer
            func generateSupplementaryItem(supplementary: ASListPage.Supplementary, isHeader: Bool) -> NSCollectionLayoutBoundarySupplementaryItem {
                let heightDimension: NSCollectionLayoutDimension
                var pinToVisibleBounds = false
                switch supplementary {
                case .texts(_, let pin):
                    // Absolute height must match decoration insets; estimated 44pt leaves a large
                    // gap until the footer is self-sized after scrolling.
                    let height = ASListSupplementaryView.calculateHeight(
                        width: supplementaryTextWidth,
                        supplementary: supplementary)
                    heightDimension = .absolute(height)
                    pinToVisibleBounds = pin
                case .buttons(_, let pin):
                    heightDimension = .absolute(R.Size.SupplementaryItemHeight)
                    pinToVisibleBounds = pin
                case .custom(_, let pin, let height):
                    heightDimension = .absolute(height)
                    pinToVisibleBounds = pin
                    
                }
                let layoutSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                        heightDimension: heightDimension)
                let elementKind = isHeader ? UICollectionView.elementKindSectionHeader : UICollectionView.elementKindSectionFooter
                let item = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: layoutSize,
                                                                       elementKind: elementKind,
                                                                       alignment: isHeader ? .top : .bottom)
                item.pinToVisibleBounds = pinToVisibleBounds
                return item
            }
            
            //supplementary
            var hasFooter = false
            var hasHeader = false
            var  boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem]()
            if let header = sectionData.header {
                //header
                boundarySupplementaryItems.append(generateSupplementaryItem(supplementary: header, isHeader: true))
                hasHeader = true
            }
            if let footer = sectionData.footer {
                //footer
                boundarySupplementaryItems.append(generateSupplementaryItem(supplementary: footer, isHeader: false))
                hasFooter = true
            }
            section.boundarySupplementaryItems = boundarySupplementaryItems
            
            //decoration
            if sectionData.decoration.enable {
                let decorationItem: NSCollectionLayoutDecorationItem
                
                switch sectionData.decoration.style {
                case .primary:
                    decorationItem = NSCollectionLayoutDecorationItem.background(
                        elementKind: String(describing: ASListDecorationPrimaryView.self)
                    )
                    
                case .secondary:
                    decorationItem = NSCollectionLayoutDecorationItem.background(
                        elementKind: String(describing: ASListDecorationSecondaryView.self)
                    )
                    
                }
                
                let calculateWidth = supplementaryTextWidth
                
                var insetsTop = 0.0
                if let header = sectionData.header {
                    insetsTop = ASListSupplementaryView.calculateHeight(width: calculateWidth, supplementary: header)
                }
                
                var insetsBottom = 0.0
                if let footer = sectionData.footer {
                    insetsBottom = ASListSupplementaryView.calculateHeight(width: calculateWidth, supplementary: footer)
                }
                
                var top = hasHeader ? insetsTop : Self.sectionTopInsetsWithoutHeader
                top += self.gapPreviewExtraTopInset(for: sectionIndex)
                
                decorationItem.contentInsets = NSDirectionalEdgeInsets(top: top,
                                                                       leading: Self.sectionHorizontalInsets,
                                                                       bottom: hasFooter ? insetsBottom + Self.sectionBottomInsetsWithFooter : 0,
                                                                       trailing: Self.sectionHorizontalInsets)
                section.decorationItems = [decorationItem]
            }
            
            //contentInsets
            var topInset = hasHeader ? 0 : Self.sectionTopInsetsWithoutHeader
            topInset += self.gapPreviewExtraTopInset(for: sectionIndex)
            section.contentInsets = NSDirectionalEdgeInsets(top: topInset,
                                                            leading: Self.sectionHorizontalInsets,
                                                            bottom: hasFooter ? Self.sectionBottomInsetsWithFooter : 0,
                                                            trailing: Self.sectionHorizontalInsets)
            
            return section
        }
        
        layout.register(ASListDecorationPrimaryView.self,
                        forDecorationViewOfKind: String(describing: ASListDecorationPrimaryView.self))
        
        layout.register(ASListDecorationSecondaryView.self,
                        forDecorationViewOfKind: String(describing: ASListDecorationSecondaryView.self))
        
        return layout
    }
    
    func updatePage(_ listPage: ASListPage) {
        self.listPage = listPage
        updateViews()
    }
    
    private func updateViews() {
        updateNavigationView()
        updateTopView()
        updateBlankSlateView()
        updateCollectionView()
        updateToolView()
        updateBottomView()
        updateIndexView()
        backgroundColor = listPage.backgroundColor
    }
    
    private func updateNavigationView() {
        guard let navigation else {
            navigationView?.removeFromSuperview()
            return
        }
        
        let view = ensureNavigationView()
        view.navigation = navigation
        
        if view.superview == nil {
            addSubview(view)
        }
        
        view.snp.remakeConstraints { make in
            make.top.equalTo(enableSafeAreaTopInsets ? safeAreaLayoutGuide : self).offset(pageInsets.top)
            make.leading.equalTo(enableSafeAreaLeftInsets ? safeAreaLayoutGuide : self).inset(listPage.pageInsets.left)
            make.trailing.equalTo(enableSafeAreaRightInsets ?  safeAreaLayoutGuide : self).inset(listPage.pageInsets.right)
            make.height.equalTo(Self.navigationHeight)
        }
        
        view.didTapClose = { [weak self] in
            self?.didActionOccurred?(.navigation(.tapClose))
        }
        view.didTapTools = { [weak self] index in
            self?.didActionOccurred?(.navigation(.tapTools(index)))
        }
        view.didTapCancel = { [weak self] in
            self?.didActionOccurred?(.navigation(.tapCancel))
        }
        view.didTapEdit = { [weak self] in
            self?.didActionOccurred?(.navigation(.tapEdit))
        }
        
        if navigation.enableTitleInteractive {
            view.didTapTitle = { [weak self] in
                self?.didActionOccurred?(.navigation(.tapTitle))
            }
        } else {
            view.didTapTitle = nil
        }
    }
    
    private func ensureNavigationView() -> ASNavigationView {
        if let navigationView {
            return navigationView
        }
        
        let view = ASNavigationView()
        navigationView = view
        return view
    }
    
    private func updateTopView() {
        guard let top = listPage.top else {
            topContainer.removeFromSuperview()
            return
        }
        
        let view = top.view
        let layout = top.layout
        
        if mountedTopView !== view {
            mountedTopView?.removeFromSuperview()
            topContainer.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            mountedTopView = view
        }
        
        if topContainer.superview == nil {
            addSubview(topContainer)
        }
        
        topContainer.snp.remakeConstraints { make in
            if let navigationView, navigationView.superview != nil {
                make.top.equalTo(navigationView.snp.bottom)
            } else {
                make.top.equalTo(enableSafeAreaTopInsets ? safeAreaLayoutGuide : self).offset(listPage.pageInsets.top)
            }
            switch layout {
            case .fixedHeight(let height):
                make.leading.equalTo(enableSafeAreaLeftInsets ? safeAreaLayoutGuide : self).inset(listPage.pageInsets.left)
                make.trailing.equalTo(enableSafeAreaRightInsets ? safeAreaLayoutGuide : self).inset(listPage.pageInsets.right)
                make.height.equalTo(height)
                
            case .fixedWidth(let width):
                make.width.equalTo(width)
                make.centerX.equalToSuperview()
                
            case .fixedSize(let size):
                make.size.equalTo(size)
                make.centerX.equalToSuperview()
                
            case .autoLayout:
                make.centerX.equalToSuperview()
            }
        }
    }
    
    private func updateCollectionView() {
        collectionEqualToTopViewBottom = nil
        
        if collectionView.superview == nil {
            addSubview(collectionView)
        }
        collectionView.snp.remakeConstraints { make in
            make.leading.equalTo(enableSafeAreaLeftInsets ? safeAreaLayoutGuide : self).inset(listPage.pageInsets.left)
            make.trailing.equalTo(enableSafeAreaRightInsets ? safeAreaLayoutGuide : self).inset(listPage.pageInsets.right)
            
            if listPage.top != nil, topContainer.superview != nil {
                self.collectionEqualToTopViewBottom = make.top.equalTo(topContainer.snp.bottom).constraint
            } else if let navigationView, navigationView.superview != nil {
                make.top.equalTo(navigationView.snp.bottom)
            } else {
                make.top.equalTo(enableSafeAreaTopInsets ? safeAreaLayoutGuide : self).offset(listPage.pageInsets.top)
            }
            make.bottom.equalToSuperview().inset(listPage.pageInsets.bottom)
        }
        updateCollectionViewInsets()
        collectionView.reloadData()
        indexView?.reloadData()
        
        if listPage.enableLongPress {
            collectionView.addLongPressGesture(handler: { [weak self] gesture in
                if gesture.state == .began {
                    guard let self,
                          self.listPage.enableLongPress,
                          let indexPath = self.collectionView.indexPathForItem(at: gesture.location(in: self.collectionView)) else { return }
                    UIDevice.generateHaptic(style: .heavy)
                    self.didActionOccurred?(.longPress(indexPath: indexPath))
                }
            }).delegate = self
        }
    }
    
    private func updateCollectionViewInsets() {
        var contentInset = listInsets

        if listPage.bottom != nil {
            contentInset.bottom += (Self.bottomButtonHeight + R.Size.ContentSpaceMedium)
        }
        if listPage.tool != nil {
            contentInset.bottom += (Self.toolViewHeight + R.Size.ContentSpaceMedium)
        }
        
        if enableSafeAreaBottomInsets {
            contentInset.bottom += R.Size.SafeArea.bottom
            if UIDevice.isSmallScreenPhone {
                contentInset.bottom += R.Size.ContentInsetBottom
            }
        }
        
        collectionView.contentInset = contentInset
    }
    
    private func updateToolView() {
        guard let tool = listPage.tool else {
            toolView?.removeFromSuperview()
            updateCollectionViewInsets()
            return
        }
        
        let view = ensureToolView(with: tool)
        if view.superview == nil {
            addSubview(view)
        }
        view.snp.remakeConstraints { make in
            let leadingInset = R.Size.ContentSpaceHuge + listPage.pageInsets.left
            let trailingInset = R.Size.ContentSpaceHuge + listPage.pageInsets.right
            make.leading.equalTo(enableSafeAreaLeftInsets ? safeAreaLayoutGuide : self).inset(leadingInset)
            make.trailing.equalTo(enableSafeAreaRightInsets ? safeAreaLayoutGuide : self).inset(trailingInset)
            
            if listPage.bottom != nil, let bottomButton, bottomButton.superview != nil {
                make.bottom.equalTo(bottomButton.snp.top).offset(-R.Size.ContentSpaceMedium)
            } else {
                make.bottom.equalToSuperview().inset(contentsBottomInset)
            }
            make.height.equalTo(Self.toolViewHeight)
        }
        
        updateCollectionViewInsets()
        
        view.didTapToolButtons = { [weak self] toolType in
            self?.didActionOccurred?(.tool(toolType))
        }
    }
    
    private func ensureToolView(with tool: ASListPage.Tool) -> ASListToolView {
        if let toolView {
            toolView.tool = tool
            return toolView
        }
        
        let view = ASListToolView(tool)
        toolView = view
        return view
    }
    
    private func updateBottomView() {
        guard let bottom = listPage.bottom else {
            bottomButton?.removeFromSuperview()
            if listPage.tool != nil {
                updateToolView()
            } else {
                updateCollectionViewInsets()
            }
            return
        }
        
        let view = ensureBottomButton(with: bottom)
        if view.superview == nil {
            addSubview(view)
            
        }
        
        view.snp.remakeConstraints { make in
            if UIDevice.isPad || (UIDevice.isPhone && UIDevice.isLandscape) {
                make.width.equalTo(R.Size.ButtonMaxWidth)
                make.centerX.equalToSuperview()
            } else {
                let leadingInset = R.Size.ContentSpaceHuge + listPage.pageInsets.left
                let trailingInset = R.Size.ContentSpaceHuge + listPage.pageInsets.right
                make.leading.equalTo(enableSafeAreaLeftInsets ? safeAreaLayoutGuide : self).inset(leadingInset)
                make.trailing.equalTo(enableSafeAreaRightInsets ? safeAreaLayoutGuide : self).inset(trailingInset)
            }
            make.bottom.equalToSuperview().inset(contentsBottomInset)
            make.height.equalTo(Self.bottomButtonHeight)
        }
        
        if listPage.tool != nil {
            updateToolView()
        } else {
            updateCollectionViewInsets()
        }
        
        view.didTapButton = { [weak self] in
            self?.didActionOccurred?(.bottom)
        }
    }
    
    private func ensureBottomButton(with bottom: ASButton) -> ASButtonView {
        if let bottomButton {
            bottomButton.button = bottom
            return bottomButton
        }
        let view = ASButtonView(bottom)
        view.enableFocusEffects = false
        bottomButton = view
        return view
    }
    
    private func updateBlankSlateView() {
        if let blankSlate {
            let view: ASBlankSlateView
            if let aView = collectionView.blankSlateView as? ASBlankSlateView {
                aView.blankSlate = blankSlate
                view = aView
            } else {
                collectionView.layoutInsets = blankSlate.layoutInsets
                view = ASBlankSlateView(blankSlate)
                collectionView.blankSlateView = view
            }
            view.didTapButton = { [weak self] in
                self?.didActionOccurred?(.blankSlate)
            }
        } else {
            collectionView.layoutInsets = .zero
            collectionView.blankSlateView = nil
        }
    }
    
    private func updateIndexView() {
        guard listPage.enableIndexView else {
            indexView?.removeFromSuperview()
            return
        }
        
        let view = ensureIndexView()
        if view.superview == nil {
            addSubview(view)
            
        }
        
        view.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.trailing.equalTo(enableSafeAreaRightInsets ? safeAreaLayoutGuide : self).inset(listPage.pageInsets.right)
            make.width.equalTo(31)
        }
    }
    
    private func ensureIndexView() -> SectionIndexView {
        if let indexView {
            return indexView
        }
        let view = SectionIndexView()
        view.delegate = self
        view.dataSource = self
        indexView = view
        return view
    }
    
    static func calculateMinHeight(listPage: ASListPage,
                                   containerWidth: CGFloat = R.Size.WindowSize.width) -> CGFloat {
        
        var height = 0.0
        
        height += listPage.pageInsets.vertical
        
        if let _ = listPage.navigation {
            height += navigationHeight
        }
        
        if let top = listPage.top {
            if case let .fixedHeight(topHeight) = top.1 {
                height += topHeight
            } else if case let .fixedSize(topSize) = top.1 {
                height += topSize.height
            }
        }
        
        var fixContainerWidth = 0.0
        for section in listPage.sections {
            if case let .fixedHeight(cellHeight) = section.itemLayout {
                height += (CGFloat(section.cells.count) * cellHeight)
            } else {
                for cell in section.cells {
                    switch cell {
                    case .normal, .input:
                        height += R.Size.CellHeight
                    case .custom(let view):
                        height += view.height
                    }
                }
            }
            
            if fixContainerWidth == 0 && (section.header != nil || section.footer != nil) {
                let countHorizontalSafeArea = containerWidth >= R.Size.WindowWidth - R.Size.SafeArea.horizontal
                let leftSafeArea = (countHorizontalSafeArea && listPage.enableSafeAreaLeftInsets) ? R.Size.SafeArea.left : 0
                let rightSafeArea = (countHorizontalSafeArea && listPage.enableSafeAreaRightInsets) ? R.Size.SafeArea.right : 0
                fixContainerWidth = containerWidth -
                //This part isn’t quite right—if the header or footer has line breaks, the calculation might be off.
                leftSafeArea -
                rightSafeArea -
                sectionHorizontalInsets*2 -
                supplementaryHorizontalInsets*2 -
                listPage.pageInsets.horizontal
            }
            
            if let header = section.header {
                height += ASListSupplementaryView.calculateHeight(width: fixContainerWidth, supplementary: header)
            }
            
            if let footer = section.footer {
                height += ASListSupplementaryView.calculateHeight(width: fixContainerWidth, supplementary: footer)
                height += sectionBottomInsetsWithFooter
            }
            
            if section.header == nil && section.footer == nil {
                height += sectionTopInsetsWithoutHeader
            }
            
        }
        
        if let _ = listPage.bottom {
            height += (R.Size.ButtonExtraLarge + R.Size.ContentSpaceMedium)
        }
        
        height += listPage.listInsets.bottom
        
        if height >= R.Size.WindowHeight - R.Size.SafeArea.vertical, listPage.enableSafeAreaTopInsets {
            height += R.Size.SafeArea.top
        }
        
        if listPage.enableSafeAreaBottomInsets {
            height += R.Size.SafeArea.bottom
            if UIDevice.isSmallScreenPhone {
                height += R.Size.ContentInsetBottom
            }
        }
        
        return height
    }
    
    func updateCellData(_ cellData: ASListPage.Cell, indexPath: IndexPath, reloadView: Bool = true) {
        guard indexPath.section < listPage.sections.count,
              indexPath.row < listPage.sections[indexPath.section].cells.count else { return }
        
        listPage.sections[indexPath.section].cells[indexPath.row] = cellData
        
        guard reloadView else { return }
        
        // Prefer in-place configuration for visible cells. `reloadItems` triggers
        // UICollectionView's item reload animation and causes icon/title flicker even
        // when ASListItemView reuses its subviews.
        if let cell = collectionView.cellForItem(at: indexPath) {
            configureCell(cell, at: indexPath, with: cellData)
        }
    }
    
    private func configureCell(_ cell: UICollectionViewCell,
                               at indexPath: IndexPath,
                               with cellData: ASListPage.Cell) {
        switch cellData {
        case .normal(let itemStyles, let enablePressEffect):
            guard let listCell = cell as? ASListItemCollectionCell else { return }
            listCell.setData(itemStyles: itemStyles, enablePressEffect: enablePressEffect)
            if didActionOccurred != nil {
                listCell.setActionCallback { [weak self] itemStyle, extraValue in
                    self?.didActionOccurred?(.normalItem(indexPath: indexPath,
                                                         cellData: cellData,
                                                         subActions: (itemStyle, extraValue)))
                }
            } else {
                listCell.setActionCallback(nil)
            }
            
        case .input(let input):
            guard let inputCell = cell as? ASListInputCollectionCell else { return }
            inputCell.setData(input: input)
            if didActionOccurred != nil {
                inputCell.setActionCallback { [weak self] inputActionType in
                    self?.didActionOccurred?(.inputItem(indexPath: indexPath, action: inputActionType))
                }
            } else {
                inputCell.setActionCallback(nil)
            }
            
        case .custom(let view):
            guard let customCell = cell as? ASListCustomCollectionCell else { return }
            customCell.setData(customView: view)
        }
    }
    
    func updateSectionData(_ sectionData: ASListPage.Section, section: Int, reloadView: Bool = true) {
        guard section < listPage.sections.count else { return }
        
        let oldCellCount = listPage.sections[section].cells.count
        listPage.sections[section] = sectionData
        
        guard reloadView else { return }
        
        if oldCellCount != sectionData.cells.count {
            UIView.performWithoutAnimation {
                collectionView.reloadSections(IndexSet(integer: section))
            }
            return
        }
        
        reconfigureVisibleCells(in: section)
    }
    
    private func reconfigureVisibleCells(in section: Int) {
        for indexPath in collectionView.indexPathsForVisibleItems where indexPath.section == section {
            guard indexPath.row < listPage.sections[section].cells.count else { continue }
            let cellData = listPage.sections[section].cells[indexPath.row]
            if let cell = collectionView.cellForItem(at: indexPath) {
                configureCell(cell, at: indexPath, with: cellData)
            }
        }
    }
    
    func insertSection(_ sectionData: ASListPage.Section, section: Int? = nil, reloadView: Bool = true) {
        var insertSection = min(listPage.sections.count - 1, 0)
        if let section {
            guard section < listPage.sections.count else { return }
            insertSection = section
            listPage.sections.insert(sectionData, at: section)
        } else {
            listPage.sections.append(sectionData)
        }
        
        guard reloadView else { return }
        
        collectionView.performBatchUpdates {
            collectionView.insertSections([insertSection])
        }
        indexView?.reloadData()
    }
    
    func removeSections(sections: [Int], reloadView: Bool = true) {
        let availableSections = sections.filter({ $0 < listPage.sections.count })
        guard availableSections.count > 0 else { return }
        availableSections.forEach({
            listPage.sections.remove(at: $0)
        })
        
        guard reloadView else { return }
        
        collectionView.performBatchUpdates {
            collectionView.deleteSections(IndexSet(availableSections))
        }
        indexView?.reloadData()
    }
}

//MARK: - UICollectionViewDataSource
extension ASListPageView: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].cells.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellData = sections[indexPath.section].cells[indexPath.row]
        let cell: UICollectionViewCell
        switch cellData {
        case .normal:
            cell = collectionView.dequeueReusableCell(withClass: ASListItemCollectionCell.self, for: indexPath)
        case .input:
            cell = collectionView.dequeueReusableCell(withClass: ASListInputCollectionCell.self, for: indexPath)
        case .custom:
            cell = collectionView.dequeueReusableCell(withClass: ASListCustomCollectionCell.self, for: indexPath)
        }
        configureCell(cell, at: indexPath, with: cellData)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let reusableView: UICollectionReusableView
        let section = sections[indexPath.section]
        let supplementary: ASListPage.Supplementary?
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: ASListSupplementaryReusableView.self, for: indexPath)
            supplementary = section.header
            header.setData(supplementary: supplementary)
            reusableView = header
        } else {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: ASListSupplementaryReusableView.self, for: indexPath)
            supplementary = section.footer
            footer.setData(supplementary: supplementary)
            reusableView = footer
        }
        
        if let supplementary {
            var pinToBounds = false
            var isCustom = false
            switch supplementary {
            case .texts(_, let pin):
                pinToBounds = pin
            case .buttons(_, let pin):
                pinToBounds = pin
            case .custom(_, let pin, _):
                pinToBounds = pin
                isCustom = true
            }
            reusableView.backgroundColor = (pinToBounds && !isCustom) ? R.Color.BackgroundPrimary : .clear
        } else {
            reusableView.backgroundColor = .clear
        }
        
        return reusableView
    }
}

//MARK: - UICollectionViewDelegate
extension ASListPageView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cellData = sections[indexPath.section].cells[indexPath.row]
        if let normalCell = sections[indexPath.section].cells[indexPath.row].normalValue,
           normalCell.enablePressEffect {
            didActionOccurred?(.normalItem(indexPath: indexPath,
                                                 cellData: cellData,
                                                 subActions: nil))
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScroll?(scrollView)
        updateTopViewVisibility(for: scrollView)
        updateIndexViewSelection(for: scrollView)
    }
}

//MARK: - Scroll-related Functions
private extension ASListPageView {
    enum ToolViewScroll {
        /// The offset threshold considered as "at the top"
        static let topThreshold: CGFloat = 1
        /// The minimum displacement for determining the scroll direction
        static let directionThreshold: CGFloat = 1.5
        /// When not at the top, the minimum speed required to swipe down and show the ToolView.
        static let showVelocityThreshold: CGFloat = 1200
        /// If the displacement exceeds this limit, it is considered a bounce / release rebound and will not be included in the show/hide judgment.
        static let maxDirectionDelta: CGFloat = 50
    }
    
    func clampedContentOffsetY(for scrollView: UIScrollView) -> CGFloat {
        let raw = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let maxOffsetY = max(
            0,
            scrollView.contentSize.height
            + scrollView.adjustedContentInset.top
            + scrollView.adjustedContentInset.bottom
            - scrollView.bounds.height
        )
        return min(max(raw, 0), maxOffsetY)
    }
    
    func updateTopViewVisibility(for scrollView: UIScrollView) {
        guard let top,
              top.pin == false,
              let collectionEqualToTopViewBottom,
              topContainer.superview != nil else {
            return
        }
        
        
        let contentOffsetY = clampedContentOffsetY(for: scrollView)
        let now = CACurrentMediaTime()
        
        if !isToolViewScrollInitialized {
            syncToolViewScrollBaseline(offset: contentOffsetY, time: now)
            isToolViewScrollInitialized = true
            return
        }
        
        let deltaY = contentOffsetY - lastContentOffsetY
        let timeDelta = now - lastToolViewScrollTimestamp
        // Instantaneous speed (pt/s) between two consecutive scroll callbacks, recalculated per frame without cross-frame accumulation.
        let scrollVelocity = timeDelta > 0 ? deltaY / CGFloat(timeDelta) : 0
        
        defer {
            syncToolViewScrollBaseline(offset: contentOffsetY, time: now)
        }
        
        // Force display the list when it's at the top
        if contentOffsetY <= ToolViewScroll.topThreshold, topContainer.alpha == 0 {
            collectionEqualToTopViewBottom.update(offset: 0)
            UIView.springAnimate {
                self.topContainer.alpha = 1
                self.collectionView.layoutIfNeeded()
            }
            print(">>>>>Force display")
            return
        }
        
        // Ignore the minor jitters when the direction is unclear.
        guard abs(deltaY) >= ToolViewScroll.directionThreshold else { return }
        
        // Ignore large jumps caused by edge bounce or snap-back.
        guard abs(deltaY) <= ToolViewScroll.maxDirectionDelta else { return }
        
        if deltaY > 0, contentOffsetY >= topContainer.height, topContainer.alpha == 1 {
            // Swipe up to force hide
            collectionEqualToTopViewBottom.update(offset: -topContainer.height)
            UIView.springAnimate {
                self.topContainer.alpha = 0
                self.collectionView.layoutIfNeeded()
            }
            print(">>>>>Swipe up to force hide")
            return
        }
        
        // Swipe down to reveal: Use the pan gesture speed while dragging, and use the instantaneous speed between frames when decelerating.
        let downwardSpeed: CGFloat
        if scrollView.isDragging {
            // When dragging your finger downward, velocity.y is positive, measured in pt/s.
            downwardSpeed = scrollView.panGestureRecognizer.velocity(in: scrollView).y
        } else {
            // When offset decreases, scrollVelocity becomes negative. Inverting it gives the downward scrolling speed.
            downwardSpeed = -scrollVelocity
        }
        
        if downwardSpeed >= ToolViewScroll.showVelocityThreshold, self.topContainer.alpha == 0 {
            collectionEqualToTopViewBottom.update(offset: 0)
            UIView.springAnimate {
                self.topContainer.alpha = 1
                self.collectionView.layoutIfNeeded()
            }
            print(">>>>>Swipe down to force show")
        }
    }
    
    func syncToolViewScrollBaseline(offset: CGFloat, time: TimeInterval) {
        lastContentOffsetY = offset
        lastToolViewScrollTimestamp = time
    }
}

//MARK: - ViewTransition
extension ASListPageView: ViewTransition {
    func viewAlongsideTransition() {
        if enableSafeAreaTopInsets {
            self.enableSafeAreaTopInsets = true
        }
        if enableSafeAreaLeftInsets {
            self.enableSafeAreaLeftInsets = true
        }
        if enableSafeAreaRightInsets {
            self.enableSafeAreaRightInsets = true
        }
        if enableSafeAreaBottomInsets {
            self.enableSafeAreaBottomInsets = true
        }
    }
}

//MARK: - IndexView-related
extension ASListPageView: SectionIndexViewDataSource, SectionIndexViewDelegate {
    func numberOfScetions(in sectionIndexView: SectionIndexView) -> Int {
        sections.count
    }
    
    func sectionIndexView(_ sectionIndexView: SectionIndexView, itemAt section: Int) -> any SectionIndexViewItem {
        let item = SectionIndexViewItemView()
        var indicatorContentView: UIView? = nil
        if let header = sections[section].header {
            switch header {
            case .texts(let texts, _):
                let text = texts.first?.attributes?.text
                item.title = text?.first?.uppercased() ?? "?"
                if let text {
                    indicatorContentView = ASLabelView(text: .extraLargeText(text))
                }
                
            case .buttons(let buttons, _):
                let text = buttons.first?.allAttributes[.normal]?.title?.attributes?.text
                item.title = text?.first?.uppercased() ?? "?"
                if let text {
                    indicatorContentView = ASLabelView(text: .extraLargeText(text))
                }
                
            case .custom:
                item.title = "?"
            }
        } else {
            item.title = "?"
        }
        item.titleColor = R.Color.LabelTertiary
        item.titleSelectedColor = R.Color.LabelPrimary.forceStyle(.dark)
        item.selectedColor = R.Color.Main
        item.titleFont = R.Font.Caption2(emphasis: true)
        
        if let indicatorContentView {
            let indicatorView = UIView()
            indicatorView.backgroundColor = R.Color.BackgroundPrimary
            indicatorView.layerCornerRadius = R.Size.ItemHeightSmall/2
            indicatorView.addSubview(indicatorContentView)
            indicatorContentView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(R.Size.ContentSpaceSmall)
                make.height.equalTo(R.Size.IconMedium)
            }
            indicatorView.overrideUserInterfaceStyle = UIDevice.isDarkMode ? .light : .dark
            item.indicator = indicatorView
        }
        
        return item
    }
    
    func sectionIndexView(_ sectionIndexView: SectionIndexView, didSelect section: Int) {
        sectionIndexView.hideCurrentItemIndicator()
        sectionIndexView.deselectCurrentItem()
        sectionIndexView.selectItem(at: section)
        sectionIndexView.showCurrentItemIndicator()
        sectionIndexView.impact()
        collectionView.panGestureRecognizer.isEnabled = false
        let numberOfSections = collectionView.numberOfSections
        if numberOfSections < section {
            return
        }
        if collectionView.numberOfItems(inSection: section) == 0 {
            if let sectionWithItems = nearestSectionWithItems(from: section) {
                collectionView.scrollToItem(at: IndexPath(row: 0, section: sectionWithItems), at: .top, animated: true)
            }
            return
        }
        collectionView.scrollToItem(at: IndexPath(row: 0, section: section), at: .top, animated: true)
    }
    
    func sectionIndexViewToucheEnded(_ sectionIndexView: SectionIndexView) {
        UIView.animate(withDuration: 0.3) {
            sectionIndexView.hideCurrentItemIndicator()
        }
        collectionView.panGestureRecognizer.isEnabled = true
    }
    
    func sectionIndexViewDidSelectSearch(_ sectionIndexView: SectionIndexView) {
        collectionView.scrollToTop(animated: true)
    }
    
    //从指定 section 向两边扩散查找最近的非空 section（双向 BFS）
    private func nearestSectionWithItems(from section: Int) -> Int? {
        let total = collectionView.numberOfSections
        guard total > 0, section >= 0, section < total else { return nil }
        
        // 如果当前 section 本身就有
        if collectionView.numberOfItems(inSection: section) > 0 {
            return section
        }
        
        var offset = 1
        
        while section - offset >= 0 || section + offset < total {
            
            // 左边
            let left = section - offset
            if left >= 0,
               collectionView.numberOfItems(inSection: left) > 0 {
                return left
            }
            
            // 右边
            let right = section + offset
            if right < total,
               collectionView.numberOfItems(inSection: right) > 0 {
                return right
            }
            
            offset += 1
        }
        
        return nil
    }
    
    private func updateIndexViewSelection(for scrollView: UIScrollView) {
        guard listPage.enableIndexView else { return }
        guard let indexView else { return }
        guard !indexView.isTouching else { return }
        let contentOffsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let sections = collectionView.numberOfSections
        var pinnedSection: Int?
        for section in 0..<sections {
            if let layoutAttributes = collectionView.layoutAttributesForSupplementaryElement(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: section)
            ) {
                let headerFrame = layoutAttributes.frame
                if contentOffsetY + 5 >= floor(headerFrame.origin.y) {
                    pinnedSection = section
                } else {
                    break
                }
            }
        }
        
        if let pinnedSection = pinnedSection {
            guard let item = indexView.item(at: pinnedSection), item.bounds != .zero  else { return }
            guard !(indexView.selectedItem?.isEqual(item) ?? false) else { return }
            indexView.deselectCurrentItem()
            indexView.selectItem(at: pinnedSection)
        }
    }
}

//MARK: - Reorder-related Functions
extension ASListPageView: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    enum ReorderScope {
        case item
        case section
    }
    
    enum ItemReorderIntent {
        case moveItem(from: IndexPath, to: IndexPath)
        case extractToNewSection(from: IndexPath, atSection: Int)
    }
    
    enum SectionReorderIntent {
        case moveSection(from: Int, to: Int)
    }
    
    func enableReorder(_ enable: Bool,
                       scope: ReorderScope = .item,
                       keepSupplementaryPlace: Bool = false,
                       beginReorder: ((IndexPath) -> Bool)? = nil,
                       itemReorderDidUpdate: ((ItemReorderIntent) -> Bool)? = nil,
                       itemDidReorder: ((ItemReorderIntent) -> Void)? = nil,
                       sectionReorderDidUpdate: ((SectionReorderIntent) -> Bool)? = nil,
                       sectionDidReorder: ((SectionReorderIntent) -> Void)? = nil) {
        if enable {
            collectionView.dragInteractionEnabled = true
            collectionView.dragDelegate = self
            collectionView.dropDelegate = self
            reorderScope = scope
            self.keepSupplementaryPlace = keepSupplementaryPlace
            self.beginReorder = beginReorder
            self.itemReorderDidUpdate = itemReorderDidUpdate
            self.itemDidReorder = itemDidReorder
            self.sectionReorderDidUpdate = sectionReorderDidUpdate
            self.sectionDidReorder = sectionDidReorder
        } else {
            collectionView.dragInteractionEnabled = false
            collectionView.dragDelegate = nil
            collectionView.dropDelegate = nil
            reorderScope = .item
            self.keepSupplementaryPlace = false
            self.beginReorder = nil
            self.itemReorderDidUpdate = nil
            self.itemDidReorder = nil
            self.sectionReorderDidUpdate = nil
            self.sectionDidReorder = nil
            pendingItemIntent = nil
            resetDragState()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        if reorderScope == .section {
            guard !sectionDragDidComplete else {
                resetDragState()
                return
            }
            
            if let original = sectionDragOriginalIndex,
               let current = sectionDragCurrentIndex,
               original != current {
                applyLiveSectionMove(from: current, to: original)
            }
            
            restoreVisibleCells()
            resetDragState()
            return
        }
        
        guard !itemDragDidComplete else {
            restoreVisibleCells()
            resetDragState()
            return
        }
        
        removeGapPreviewIfNeeded(animated: false)
        restoreVisibleCells()
        resetDragState()
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        if beginReorder?(indexPath) ?? false {
            if reorderScope == .section {
                sectionDragOriginalIndex = indexPath.section
                sectionDragCurrentIndex = indexPath.section
                sectionDragDidComplete = false
                collectionView.cellForItem(at: indexPath)?.alpha = 0
            } else {
                itemDragOriginalIndexPath = indexPath
                itemDragDidComplete = false
                itemDragGapPreviewAtSection = nil
                collectionView.cellForItem(at: indexPath)?.alpha = 0
            }
            
            let item = UIDragItem(itemProvider: NSItemProvider())
            item.localObject = indexPath
            return [item]
        }
        return []
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        return reorderPreviewParameters(for: cell.bounds)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        dropPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        if let cell = collectionView.cellForItem(at: indexPath) {
            return reorderPreviewParameters(for: cell.bounds)
        }
        let width = max(collectionView.bounds.width - Self.sectionHorizontalInsets * 2, gapPreviewHeight)
        return reorderPreviewParameters(for: CGRect(x: 0, y: 0, width: width, height: gapPreviewHeight))
    }
    
    private func reorderPreviewParameters(for rect: CGRect) -> UIDragPreviewParameters {
        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = R.Color.BackgroundSecondary
        parameters.visiblePath = UIBezierPath(roundedRect: rect, cornerRadius: R.Size.CornerRadiusMedium)
        parameters.shadowPath = parameters.visiblePath
        return parameters
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        canHandle session: UIDropSession) -> Bool {
        return session.localDragSession != nil
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        guard let sourceIndexPath = session.localDragSession?.items.first?.localObject as? IndexPath else {
            pendingItemIntent = nil
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        
        if reorderScope == .section {
            return updateSectionDragSession(sourceIndexPath: sourceIndexPath, session: session)
        }
        
        return updateItemDragSession(sourceIndexPath: sourceIndexPath,
                                     session: session,
                                     destinationIndexPath: destinationIndexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator) {
        if reorderScope == .section {
            performSectionDrop(with: coordinator)
            return
        }
        
        performItemDrop(with: coordinator)
    }
    
    private func updateItemDragSession(sourceIndexPath: IndexPath,
                                       session: UIDropSession,
                                       destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        let originalSource = itemDragOriginalIndexPath ?? sourceIndexPath
        let location = session.location(in: collectionView)
        
        if let gapAt = itemDragGapPreviewAtSection,
           isLocationInGapPreview(location, at: gapAt) {
            return acceptItemIntent(.extractToNewSection(from: originalSource, atSection: gapAt))
        }
        
        if let destinationIndexPath {
            removeGapPreviewIfNeeded()
            
            if destinationIndexPath != sourceIndexPath {
                return acceptItemIntent(.moveItem(from: originalSource, to: destinationIndexPath))
            }
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        
        if let atSection = newSectionIndex(at: location) {
            updateGapPreview(at: atSection)
            return acceptItemIntent(.extractToNewSection(from: originalSource, atSection: atSection))
        }
        
        pendingItemIntent = nil
        return UICollectionViewDropProposal(operation: .forbidden)
    }
    
    private func performItemDrop(with coordinator: UICollectionViewDropCoordinator) {
        guard let dropItem = coordinator.items.first,
              let sourceIndexPath = dropItem.sourceIndexPath else { return }
        let originalSource = itemDragOriginalIndexPath ?? sourceIndexPath
        
        itemDragDidComplete = true
        removeGapPreviewIfNeeded(animated: false)
        defer {
            pendingItemIntent = nil
            resetDragState()
        }
        
        switch pendingItemIntent {
        case .moveItem(_, let to):
            let destinationIndexPath = coordinator.destinationIndexPath ?? to
            commitMoveItemDrop(from: sourceIndexPath,
                               to: destinationIndexPath,
                               originalSource: originalSource,
                               dropItem: dropItem,
                               coordinator: coordinator)
        case .extractToNewSection(_, let atSection):
            commitExtractToNewSectionDrop(from: sourceIndexPath,
                                          atSection: atSection,
                                          originalSource: originalSource,
                                          dropItem: dropItem,
                                          coordinator: coordinator)
        case nil:
            guard let destinationIndexPath = coordinator.destinationIndexPath,
                  destinationIndexPath != sourceIndexPath else { return }
            commitMoveItemDrop(from: sourceIndexPath,
                               to: destinationIndexPath,
                               originalSource: originalSource,
                               dropItem: dropItem,
                               coordinator: coordinator)
        }
    }
    
    private func commitMoveItemDrop(from sourceIndexPath: IndexPath,
                                    to destinationIndexPath: IndexPath,
                                    originalSource: IndexPath,
                                    dropItem: UICollectionViewDropItem,
                                    coordinator: UICollectionViewDropCoordinator) {
        guard destinationIndexPath != sourceIndexPath else { return }
        
        collectionView.cellForItem(at: sourceIndexPath)?.alpha = 1
        
        collectionView.performBatchUpdates { [weak self] in
            guard let self else { return }
            self.applyMoveItem(from: sourceIndexPath, to: destinationIndexPath)
        }
        coordinator.drop(dropItem.dragItem, toItemAt: destinationIndexPath)
        itemDidReorder?(.moveItem(from: originalSource, to: destinationIndexPath))
    }
    
    private func commitExtractToNewSectionDrop(from sourceIndexPath: IndexPath,
                                               atSection: Int,
                                               originalSource: IndexPath,
                                               dropItem: UICollectionViewDropItem,
                                               coordinator: UICollectionViewDropCoordinator) {
        let finalSection = applyExtractToNewSection(from: sourceIndexPath, atSection: atSection)
        coordinator.drop(dropItem.dragItem, toItemAt: IndexPath(item: 0, section: finalSection))
        itemDidReorder?(.extractToNewSection(from: originalSource, atSection: finalSection))
    }
    
    private func invalidateGapPreviewLayout(animated: Bool) {
        let updates = { [weak self] in
            self?.collectionView.collectionViewLayout.invalidateLayout()
            self?.collectionView.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.25, animations: updates)
        } else {
            updates()
        }
    }
    
    private func updateGapPreview(at section: Int) {
        guard itemDragGapPreviewAtSection != section else { return }
        itemDragGapPreviewAtSection = section
        invalidateGapPreviewLayout(animated: true)
    }
    
    private func removeGapPreviewIfNeeded(animated: Bool = true) {
        guard itemDragGapPreviewAtSection != nil else { return }
        itemDragGapPreviewAtSection = nil
        invalidateGapPreviewLayout(animated: animated)
    }
    
    private func notifyItemReorderDidUpdate(_ intent: ItemReorderIntent) -> Bool {
        itemReorderDidUpdate?(intent) ?? true
    }
    
    private func acceptItemIntent(_ intent: ItemReorderIntent) -> UICollectionViewDropProposal {
        guard notifyItemReorderDidUpdate(intent) else {
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        pendingItemIntent = intent
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
    
    private func gapPreviewExtraTopInset(for sectionIndex: Int) -> CGFloat {
        itemDragGapPreviewAtSection == sectionIndex ? gapPreviewHeight : 0
    }
    
    private func isLocationInGapPreview(_ location: CGPoint, at section: Int) -> Bool {
        guard itemDragGapPreviewAtSection == section,
              let firstCellFrame = cellFrame(at: section) else { return false }
        let gapMinY = firstCellFrame.minY - gapPreviewHeight
        return location.y >= gapMinY && location.y < firstCellFrame.minY
    }
    
    private func updateSectionDragSession(sourceIndexPath: IndexPath,
                                          session: UIDropSession) -> UICollectionViewDropProposal {
        let location = session.location(in: collectionView)
        let targetSection = resolveTargetSectionIndex(at: location)
        let currentSection = sectionDragCurrentIndex ?? sourceIndexPath.section
        
        if targetSection != currentSection {
            let intent = SectionReorderIntent.moveSection(from: currentSection, to: targetSection)
            guard sectionReorderDidUpdate?(intent) ?? true else {
                return UICollectionViewDropProposal(operation: .forbidden)
            }
            UIDevice.generateHaptic(style: .rigid)
            applyLiveSectionMove(from: currentSection, to: targetSection)
            sectionDragCurrentIndex = targetSection
        }
        return UICollectionViewDropProposal(operation: .move, intent: .unspecified)
    }
    
    private func performSectionDrop(with coordinator: UICollectionViewDropCoordinator) {
        sectionDragDidComplete = true
        
        if let original = sectionDragOriginalIndex,
           let current = sectionDragCurrentIndex,
           original != current {
            sectionDidReorder?(.moveSection(from: original, to: current))
        }
        
        restoreVisibleCells()
        resetDragState()
    }
    
    private func restoreVisibleCells() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) else { continue }
            cell.alpha = 1
            cell.isHidden = false
        }
    }
    
    private func resetDragState() {
        sectionDragOriginalIndex = nil
        sectionDragCurrentIndex = nil
        sectionDragDidComplete = false
        itemDragOriginalIndexPath = nil
        itemDragDidComplete = false
        itemDragGapPreviewAtSection = nil
    }
    
    func resolveTargetSectionIndex(at location: CGPoint) -> Int {
        guard !sections.isEmpty else { return 0 }
        
        let groupFrames = sections.indices.compactMap { sectionFrame(at: $0) }
        guard !groupFrames.isEmpty else { return 0 }
        guard groupFrames.count > 1 else { return 0 }
        
        for index in 0..<(groupFrames.count - 1) {
            let boundary = (groupFrames[index].maxY + groupFrames[index + 1].minY) / 2
            if location.y < boundary {
                return index
            }
        }
        
        return groupFrames.count - 1
    }
    
    func sectionHasFixedSupplementary(_ section: Int) -> Bool {
        guard keepSupplementaryPlace else { return false }
        return sections[section].header != nil || sections[section].footer != nil
    }
    
    func applyLiveSectionMove(from: Int, to: Int) {
        guard from != to else { return }
        
        if keepSupplementaryPlace {
            applyLiveSectionMoveKeepingSupplementary(from: from, to: to)
            return
        }
        
        collectionView.performBatchUpdates { [weak self] in
            guard let self else { return }
            let section = self.sections.remove(at: from)
            self.sections.insert(section, at: to)
            self.collectionView.moveSection(from, toSection: to)
        }
    }
    
    func applyLiveSectionMoveKeepingSupplementary(from: Int, to: Int) {
        guard from != to else { return }
        
        if !requiresSupplementaryAwareMove(from: from, to: to) {
            collectionView.performBatchUpdates { [weak self] in
                guard let self else { return }
                let section = self.sections.remove(at: from)
                self.sections.insert(section, at: to)
                self.collectionView.moveSection(from, toSection: to)
            }
            return
        }
        
        var current = from
        let step = from < to ? 1 : -1
        while current != to {
            let next = current + step
            swapSectionSupplementary(current, with: next)
            let fromIndex = current
            collectionView.performBatchUpdates { [weak self] in
                guard let self else { return }
                let section = self.sections.remove(at: fromIndex)
                self.sections.insert(section, at: next)
                self.collectionView.moveSection(fromIndex, toSection: next)
            }
            current = next
        }
    }
    
    func requiresSupplementaryAwareMove(from: Int, to: Int) -> Bool {
        let lower = min(from, to)
        let upper = max(from, to)
        for section in lower...upper where sectionHasFixedSupplementary(section) {
            return true
        }
        return false
    }
    
    func swapSectionSupplementary(_ a: Int, with b: Int) {
        guard a >= 0, b >= 0, a < listPage.sections.count, b < listPage.sections.count, a != b else { return }
        
        let headerA = listPage.sections[a].header
        listPage.sections[a].header = listPage.sections[b].header
        listPage.sections[b].header = headerA
        
        let footerA = listPage.sections[a].footer
        listPage.sections[a].footer = listPage.sections[b].footer
        listPage.sections[b].footer = footerA
    }
    
    func cellFrame(at section: Int) -> CGRect? {
        guard section < sections.count else { return nil }
        
        var frame = CGRect.null
        for row in 0..<sections[section].cells.count {
            if let attributes = collectionView.layoutAttributesForItem(at: IndexPath(item: row, section: section)) {
                frame = frame.union(attributes.frame)
            }
        }
        
        return frame.isNull ? nil : frame
    }
    
    func newSectionIndex(at location: CGPoint) -> Int? {
        guard sections.count > 0 else { return nil }
        
        if collectionView.indexPathForItem(at: location) != nil {
            return nil
        }
        
        if let firstFrame = sectionFrame(at: 0), location.y < firstFrame.minY {
            return 0
        }
        
        for section in 0..<(sections.count - 1) {
            guard let currentFrame = sectionFrame(at: section),
                  let nextFrame = sectionFrame(at: section + 1) else { continue }
            
            if location.y > currentFrame.maxY && location.y < nextFrame.minY {
                return section + 1
            }
        }
        
        if let lastFrame = sectionFrame(at: sections.count - 1), location.y > lastFrame.maxY {
            return sections.count
        }
        
        return nil
    }
    
    func sectionFrame(at section: Int) -> CGRect? {
        guard section < sections.count else { return nil }
        
        var frame = CGRect.null
        let supplementaryIndexPath = IndexPath(item: 0, section: section)
        
        if sections[section].header != nil,
           let attributes = collectionView.layoutAttributesForSupplementaryElement(ofKind: UICollectionView.elementKindSectionHeader,
                                                                                   at: supplementaryIndexPath) {
            frame = frame.union(attributes.frame)
        }
        
        for row in 0..<sections[section].cells.count {
            if let attributes = collectionView.layoutAttributesForItem(at: IndexPath(item: row, section: section)) {
                frame = frame.union(attributes.frame)
            }
        }
        
        if sections[section].footer != nil,
           let attributes = collectionView.layoutAttributesForSupplementaryElement(ofKind: UICollectionView.elementKindSectionFooter,
                                                                                   at: supplementaryIndexPath) {
            frame = frame.union(attributes.frame)
        }
        
        return frame.isNull ? nil : frame
    }
    
    func applyMoveItem(from: IndexPath, to: IndexPath) {
        if from.section == to.section {
            let cell = listPage.sections[from.section].cells.remove(at: from.row)
            listPage.sections[to.section].cells.insert(cell, at: to.row)
            collectionView.deleteItems(at: [from])
            collectionView.insertItems(at: [to])
            return
        }
        
        let (cell, sourceSectionRemoved) = removeItemFromSource(at: from)
        let toSection = adjustedSectionIndex(to.section, sourceSection: from.section, sourceRemoved: sourceSectionRemoved)
        let toRow = to.row
        
        listPage.sections[toSection].cells.insert(cell, at: toRow)
        collectionView.insertItems(at: [IndexPath(item: toRow, section: toSection)])
    }
    
    @discardableResult
    func applyExtractToNewSection(from: IndexPath, atSection: Int) -> Int {
        let resolvedSection = adjustedSectionIndex(atSection,
                                                   sourceSection: from.section,
                                                   sourceRemoved: listPage.sections[from.section].cells.count == 1)
        
        collectionView.performBatchUpdates { [weak self] in
            guard let self else { return }
            let templateSection = self.listPage.sections[from.section]
            let (cell, _) = self.removeItemFromSource(at: from)
            
            let newSection = ASListPage.Section(cells: [cell],
                                                decoration: templateSection.decoration,
                                                itemLayout: templateSection.itemLayout)
            self.listPage.sections.insert(newSection, at: resolvedSection)
            self.collectionView.insertSections(IndexSet(integer: resolvedSection))
        }
        return resolvedSection
    }
    
    func removeItemFromSource(at from: IndexPath) -> (cell: ASListPage.Cell, sourceSectionRemoved: Bool) {
        let cell = listPage.sections[from.section].cells.remove(at: from.row)
        let sourceSection = from.section
        let sourceSectionRemoved = listPage.sections[sourceSection].cells.isEmpty
        
        if sourceSectionRemoved {
            listPage.sections.remove(at: sourceSection)
            collectionView.deleteSections(IndexSet(integer: sourceSection))
        } else {
            collectionView.deleteItems(at: [from])
        }
        return (cell, sourceSectionRemoved)
    }
    
    func adjustedSectionIndex(_ section: Int, sourceSection: Int, sourceRemoved: Bool) -> Int {
        guard sourceRemoved, sourceSection < section else { return section }
        return section - 1
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ASListPageView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        //When long-press is triggered, disable the cell's tap response.
        return false
    }
}
