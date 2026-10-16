//
//  AddTriggerMappingListView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/4.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import ProHUD

class AddTriggerMappingListView: BaseView {
    
    private lazy var blankStateView: UIView = {
        let view = UIView()
        
        var button = ASButton.smallIconButton(icon: .symbol(.plus),
                                              background: R.Color.BackgroundTertiary)
        button.state = .disabled
        let addMappingButton = ASButtonView(button)
        view.addSubview(addMappingButton)
        addMappingButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        
        let label = ASLabelView(text: .init(attributes: .init(text: R.string.localizable.addMapping(),
                                                              font: R.Font.Body(emphasis: true))))
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalTo(addMappingButton.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        view.isHidden = triggerItem.mappings.count > 0
        view.enablePressEffect = true
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            self.didTapAddMapping?({ [weak self] in
                guard let self else { return }
                self.updateViews()
            })
        }
        return view
    }()
    
    private lazy var addMappingButton: UIView = {
        let view = RoundAndBorderView(roundCorner: [.topRight, .bottomRight], radius: R.Size.CornerRadiusMedium, borderColor: .clear)
        let gradientView = GradientView()
        
        view.addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        gradientView.setupGradient(colors: [
            R.Color.BackgroundSecondary.withAlphaComponent(0),
            R.Color.BackgroundSecondary,
            R.Color.BackgroundSecondary],
                           locations: [0, 0.25, 1],
                           direction: .leftToRight)
        
        let button = ASButtonView(.smallIconButton(icon: .symbol(.plus),
                                                   background: R.Color.BackgroundTertiary))
        button.didTapButton = { [weak self] in
            guard let self else { return }
            self.didTapAddMapping?({ [weak self] in
                guard let self else { return }
                self.updateViews()
            })
        }
        gradientView.addSubview(button)
        button.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        view.isHidden = triggerItem.mappings.count == 0
        return view
    }()
    
    private lazy var mappingListView: TriggerProMappingListView = {
        let view = TriggerProMappingListView(inputs: [triggerItem.mappings.map({ $0 })], style: .display)
        view.updateContentInsets(.insets(right: 66))
        view.didDeleteInput = { [weak self] index in
            guard let self else { return }
            if self.triggerItem.mappings.count > index {
                self.triggerItem.mappings.remove(at: index)
                self.blankStateView.isHidden = triggerItem.mappings.count > 0
                self.addMappingButton.isHidden = triggerItem.mappings.count == 0
            }
        }
        view.didChangeInputIndex = { [weak self] fromIndex, toIndex in
            guard let self else { return }
            if self.triggerItem.mappings.count > fromIndex, self.triggerItem.mappings.count > toIndex {
                self.triggerItem.mappings.move(from: fromIndex, to: toIndex)
            }
        }
        return view
    }()
    
    private var triggerItem: TriggerItem
    var didTapAddMapping: ((_ updateViews: (() -> Void)?)->Void)? = nil
    
    init(triggerItem: TriggerItem) {
        self.triggerItem = triggerItem
        super.init(frame: .zero)
        
        addSubview(mappingListView)
        mappingListView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(blankStateView)
        blankStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        addSubview(addMappingButton)
        addMappingButton.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.width.equalTo(addMappingButton.snp.height)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateViews() {
        mappingListView.inputs = [triggerItem.mappings.map({ $0 })]
        blankStateView.isHidden = triggerItem.mappings.count > 0
        addMappingButton.isHidden = triggerItem.mappings.count == 0
    }
}

class TriggerProMappingListView: BaseView {
    enum Style {
        case display, selection
    }
    
    class TriggerProMappingEditCell: UICollectionViewCell {
        let titleLabel: UILabel = {
            let view = UILabel()
            view.textColor = R.Color.LabelPrimary
            view.font = R.Font.Footnote()
            return view
        }()
        
        lazy var deleteButton: SymbolButton = {
            let view = SymbolButton(image: UIImage(symbol: .minusCircleFill, font: UIFont.systemFont(ofSize: 20), colors: [R.Color.LabelPrimary.forceStyle(.dark), R.Color.Red]), enableGlass: true)
            view.enableRoundCorner = true
            view.addTapGesture { [weak self] gesture in
                guard let self else { return }
                self.didDeleteItem?()
            }
            return view
        }()
        
        var didDeleteItem: (()->Void)? = nil
        
        
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            
            let containerView = RoundAndBorderView(roundCorner: .allCorners, radius: R.Size.CornerRadiusSmall)
            containerView.backgroundColor = R.Color.BackgroundTertiary
            addSubview(containerView)
            containerView.snp.makeConstraints { make in
                make.leading.equalToSuperview()
                make.top.bottom.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                make.height.equalTo(40)
            }
            
            containerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
            
            addSubview(deleteButton)
            deleteButton.snp.makeConstraints { make in
                make.size.equalTo(20)
                make.trailing.equalTo(containerView).offset(10)
                make.top.equalTo(containerView).offset(-10)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class TriggerProMappingNormalCell: UICollectionViewCell {
        let titleLabel: UILabel = {
            let view = UILabel()
            view.textColor = R.Color.LabelPrimary
            view.font = R.Font.Footnote()
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            enablePressEffect = true
            
            
            let containerView = RoundAndBorderView(roundCorner: .allCorners, radius: R.Size.CornerRadiusSmall)
            containerView.backgroundColor = R.Color.BackgroundSecondary
            addSubview(containerView)
            containerView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                make.height.equalTo(40)
            }
            
            containerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class SeperatorHeader: UICollectionReusableView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            let sparkleSeperatorView = SparkleSeperatorView(starSize: 16)
            addSubview(sparkleSeperatorView)
            sparkleSeperatorView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation())
        view.didTapClose = { [weak self] in
            self?.hide()
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: TriggerProMappingEditCell.self)
        view.register(cellWithClass: TriggerProMappingNormalCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: SeperatorHeader.self)
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.dragInteractionEnabled = isEditMode
        view.dragDelegate = self
        view.dropDelegate = self
        view.alwaysBounceHorizontal = isEditMode ? true : false
        view.alwaysBounceVertical = isEditMode ? false : true
        return view
    }()
    
    var inputs: [[String]] {
        didSet {
            collectionView.reloadData()
        }
    }
    private var style: Style
    private var isHorizontalScroll: Bool {
        switch style {
        case .display:
            return true
        case .selection:
            return false
        }
    }
    private var isEditMode: Bool {
        switch style {
        case .display:
            return true
        case .selection:
            return false
        }
    }
    var didSelectInput: ((String)->Void)? = nil
    var didDeleteInput: ((_ index: Int)->Void)? = nil
    var didChangeInputIndex: ((_ fromIndex: Int, _ toIndex: Int)->Void)? = nil
    
    required init?(parameters: Any...) {
        guard let inputs = parameters.compactMap({ $0 as? [[String]] }).first else { return nil }
        guard let style = parameters.compactMap({ $0 as? Style }).first else { return nil }
        self.inputs = inputs
        self.style = style
        super.init(frame: .zero)
        
        if style == .selection {
            addSubview(navigationView)
            navigationView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
                make.leading.trailing.equalTo(self.safeAreaLayoutGuide)
                make.height.equalTo(R.Size.NavigationHeight)
            }
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            switch style {
            case .display:
                make.leading.top.bottom.equalToSuperview()
                make.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            case .selection:
                make.top.equalTo(navigationView.snp.bottom).offset(R.Size.ContentSpaceSmall)
                make.leading.bottom.trailing.equalToSuperview()
            }
        }
    }
    
    convenience init(inputs: [[String]], style: Style) {
        self.init(parameters: inputs, style)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, env in
            guard let self else { return nil }
            if self.isEditMode {
                //item布局
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .estimated(56),
                                                                                     heightDimension: .estimated(72)))
                

                
                //group布局
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .estimated(56), heightDimension: .estimated(72)), subitems: [item])
                group.interItemSpacing = NSCollectionLayoutSpacing.fixed(0)
                group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                              leading: 0,
                                                              bottom: 0,
                                                              trailing: 0)
                
                //section布局
                let section = NSCollectionLayoutSection(group: group)
                if self.isHorizontalScroll {
                    section.orthogonalScrollingBehavior = .continuous
                }
                section.interGroupSpacing = 0
                

                section.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                                leading: R.Size.ContentSpaceMedium,
                                                                bottom: 0,
                                                                trailing: R.Size.ContentSpaceMedium)
                
                return section
            } else {
                //item布局
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .estimated(40),
                                                                                     heightDimension: .estimated(40)))
                

                
                //group布局
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(40)), subitems: [item])
                group.interItemSpacing = NSCollectionLayoutSpacing.fixed(R.Size.ContentSpaceSmall)
                group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                              leading: R.Size.ContentSpaceMedium,
                                                              bottom: 0,
                                                              trailing: R.Size.ContentSpaceMedium)
                
                //section布局
                let section = NSCollectionLayoutSection(group: group)
                if self.isHorizontalScroll {
                    section.orthogonalScrollingBehavior = .continuous
                }
                section.interGroupSpacing = R.Size.ContentSpaceSmall
                

                let isLastSection = sectionIndex == (self.inputs.count - 1)
                section.contentInsets = NSDirectionalEdgeInsets(top: sectionIndex == 0 ? R.Size.ContentSpaceSmall : R.Size.ContentSpaceHuge, leading: 0, bottom: R.Size.ContentSpaceHuge + (isLastSection ? self.safeAreaInsets.bottom : 0), trailing: 0)
                
                //header
                if sectionIndex != 0 {
                    let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                    heightDimension: .absolute(16)),
                                                                                 elementKind: UICollectionView.elementKindSectionHeader,
                                                                                 alignment: .top)
                    section.boundarySupplementaryItems = [headerItem]
                }
                
                return section
            }
        }
        return layout
    }
    
    func updateContentInsets(_ insets: UIEdgeInsets) {
        collectionView.contentInset = insets
    }
}

extension TriggerProMappingListView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return inputs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return inputs[section].count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isEditMode {
            let cell = collectionView.dequeueReusableCell(withClass: TriggerProMappingEditCell.self, for: indexPath)
            cell.titleLabel.text = inputs[indexPath.section][indexPath.row]
            cell.didDeleteItem = { [weak self, weak cell] in
                guard let self, let cell else { return }
                collectionView.performBatchUpdates({
                    if let indexPath = collectionView.indexPath(for: cell) {
                        self.inputs[indexPath.section].remove(at: indexPath.row)
                        self.collectionView.deleteItems(at: [indexPath])
                        self.didDeleteInput?(indexPath.row)
                    }
                }) { _ in
                    
                }
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: TriggerProMappingNormalCell.self, for: indexPath)
            cell.titleLabel.text = inputs[indexPath.section][indexPath.row]
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: SeperatorHeader.self, for: indexPath)
        return header
    }
}

extension TriggerProMappingListView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if !isEditMode {
            didSelectInput?(inputs[indexPath.section][indexPath.row])
            self.hide()
        }
    }
}

extension TriggerProMappingListView: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let input = inputs[indexPath.section][indexPath.row]
        let itemProvider = NSItemProvider(object: input as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = input
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        if let cell = collectionView.cellForItem(at: indexPath) {
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: R.Size.CornerRadiusMedium)
            return parameters
        }
        return nil
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }
        
        coordinator.items.forEach { dropItem in
            guard let sourceIndexPath = dropItem.sourceIndexPath,
                  let input = dropItem.dragItem.localObject as? String else { return }
            
            collectionView.performBatchUpdates({
                inputs[sourceIndexPath.section].remove(at: sourceIndexPath.item)
                inputs[destinationIndexPath.section].insert(input, at: destinationIndexPath.item)
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [destinationIndexPath])
                didChangeInputIndex?(sourceIndexPath.item, destinationIndexPath.item)
            }) { _ in
                
            }
            
            coordinator.drop(dropItem.dragItem, toItemAt: destinationIndexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        canHandle session: UIDropSession) -> Bool {
        return session.localDragSession != nil
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        guard let _ = destinationIndexPath else {
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
}

extension TriggerProMappingListView: ShowableView {
    static func show(inputs:[String],
                     gameType: GameType,
                     didSelectInput: ((String)->Void)? = nil) {
        let game = Game()
        game.gameType = gameType
        let mappingOptions = MappingOption.availableOptions(games: [game]).map({ $0.rawValue })
        Self.show(parameters: [inputs,
                               mappingOptions,
                               LibretroKeyboardCode.getAllKeyboarLabels().map({ "KB_" + $0 })],
                  Style.selection)?.didSelectInput = didSelectInput
    }
}
