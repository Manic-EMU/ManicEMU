//
//  J2MESettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/3/14.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import UIKit
import ProHUD


class J2MERotationSwitchCell: UICollectionViewCell {
    var didSwitchValueChange: ((Bool) -> Void)? = nil
    
    private lazy var itemView: ASListItemView = {
        let view = ASListItemView()
        view.didActionOccurred = { [weak self] style, value in
            guard let self,
                    case .switch = style,
                    let value = value as? Bool else { return }
            self.didSwitchValueChange?(value)
        }
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let enableContainer: UIView = {
            let view = UIView()
            view.backgroundColor = R.Color.BackgroundSecondary
            view.layerCornerRadius = R.Size.CornerRadiusMedium
            return view
        }()
        
        enableContainer.addSubview(itemView)
        itemView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.bottom.equalToSuperview()
        }
        
        addSubview(enableContainer)
        enableContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(isSelected: Bool) {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbol(.rotateLeft)))
        styles.append(.title(.largeText(R.string.localizable.rotateScreen())))
        styles.append(.switch(.init(state: isSelected ? .on : .off)))
        itemView.styles = styles
    }
}

class J2MEScreenSizeCell: UICollectionViewCell {
    
    var currentSize = J2MESize.defaultSize
    
    var didSetScreenSize: ((J2MESize)->Void)? = nil
    
    private lazy var widthTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = R.Color.LabelSecondary
        textField.font = R.Font.Caption()
        textField.placeholder = R.string.localizable.width()
        textField.keyboardType = .asciiCapableNumberPad
        textField.clearButtonMode = .never
        textField.returnKeyType = .done
        textField.textAlignment = .center
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
        }
        textField.onChange { [weak textField] text in
            if text.contains(".") {
                textField?.text = text.replacingOccurrences(of: ".", with: "")
            }
            if text.count > 3 {
                if let markRange = textField?.markedTextRange, let _ = textField?.position(from: markRange.start, offset: 0) { } else {
                    textField?.text = String(text.prefix(3))
                }
            }
            if let num = text.int, num > 800 {
                textField?.text = "800"
            }
        }
        textField.didEndEditing { [weak self] in
            guard let self else { return }
            self.updateSize(width: self.widthTextField.text?.int ?? self.currentSize.width, height: self.heightTextField.text?.int ?? self.currentSize.height)
        }
        textField.isFocusable = true
        textField.onFocusConfirm = { [weak self] in
            self?.widthTextField.becomeFirstResponder()
            return true
        }
        return textField
    }()
    
    private lazy var heightTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = R.Color.LabelSecondary
        textField.font = R.Font.Caption()
        textField.placeholder = R.string.localizable.height()
        textField.keyboardType = .decimalPad
        textField.clearButtonMode = .never
        textField.returnKeyType = .done
        textField.textAlignment = .center
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
        }
        textField.onChange { [weak textField] text in
            if text.contains(".") {
                textField?.text = text.replacingOccurrences(of: ".", with: "")
            }
            if text.count > 3 {
                if let markRange = textField?.markedTextRange, let _ = textField?.position(from: markRange.start, offset: 0) { } else {
                    textField?.text = String(text.prefix(3))
                }
            }
            if let num = text.int, num > 800 {
                textField?.text = "800"
            }
        }
        textField.didEndEditing { [weak self] in
            guard let self else { return }
            self.updateSize(width: self.widthTextField.text?.int ?? self.currentSize.width, height: self.heightTextField.text?.int ?? self.currentSize.height)
        }
        textField.isFocusable = true
        textField.onFocusConfirm = { [weak self] in
            self?.heightTextField.becomeFirstResponder()
            return true
        }
        return textField
    }()
    
    private lazy var screenSizeInputView: UIView = {
        let view = UIView()
        view.layerCornerRadius = R.Size.CornerRadiusMedium
        view.backgroundColor = R.Color.BackgroundTertiary
        
        let iconView = ASIconView(.symbolImage(R.image.customArrowUpLeftAndArrowDownRightSquare(),
                                               weight: .regular))
        view.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.size.equalTo(R.Size.IconSizeLarge)
            make.centerY.equalToSuperview()
        }
        
        let titleLabel = UILabel()
        titleLabel.text = R.string.localizable.screenSize()
        titleLabel.textColor = R.Color.LabelPrimary
        titleLabel.font = R.Font.Body(emphasis: true)
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
        }
        
        view.addSubview(widthTextField)
        widthTextField.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(R.Size.ContentSpaceSmall)
            make.centerY.equalToSuperview()
            make.width.equalTo(40)
        }
        
        let xLabel = UILabel()
        xLabel.text = "X"
        xLabel.textColor = R.Color.LabelSecondary
        xLabel.font = R.Font.Caption()
        view.addSubview(xLabel)
        xLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(widthTextField.snp.trailing).offset(R.Size.ContentSpaceTiny)
        }
        
        view.addSubview(heightTextField)
        heightTextField.snp.makeConstraints { make in
            make.leading.equalTo(xLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.centerY.equalToSuperview()
            make.width.equalTo(40)
        }
        
        let moreButton: ASButtonView = {
            let view = ASButtonView(.iconOnly(icon: .symbol(.ellipsisCircle, colors: [R.Color.LabelSecondary]),
                                              iconSize: R.Size.IconSizeMedium))
            return view
        }()
        
        moreButton.didTapButton = {
            var screenSizes = R.Strings.J2MEScreenSizes
            ChevronSheetView.show(stringOptions: screenSizes,
                                  groupTogether: true,
                                  completion: { [weak self] index in
                guard let self, let index else { return }
                self.widthTextField.resignFirstResponder()
                self.heightTextField.resignFirstResponder()
                if let size = J2MESize(stringValue: screenSizes[index]) {
                    self.updateSize(width: size.width, height: size.height)
                }
            })
        }
        
        view.addSubview(moreButton)
        moreButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(heightTextField.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
        }
        
        return view
    }()
    
    private lazy var widthSliderView: AddTriggerButtonStyleView.SliderView = {
        let view = AddTriggerButtonStyleView.SliderView(title: R.string.localizable.width(), valueSufix: nil, minimumValue: 96, maximumValue: 800, numberOfDecimalPlaces: -1)
        view.didChangeEnd = { [weak self ] port in
            guard let self else { return }
            self.updateSize(width: port.int, height: currentSize.height)
        }
        return view
    }()
    
    private lazy var heightSliderView: AddTriggerButtonStyleView.SliderView = {
        let view = AddTriggerButtonStyleView.SliderView(title: R.string.localizable.height(), valueSufix: nil, minimumValue: 95, maximumValue: 800, numberOfDecimalPlaces: -1)
        view.didChangeEnd = { [weak self ] port in
            guard let self else { return }
            self.updateSize(width: currentSize.width, height: port.int)
        }
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        containerView.layerCornerRadius = R.Size.CornerRadiusLarge
        containerView.backgroundColor = R.Color.BackgroundSecondary
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(screenSizeInputView)
        screenSizeInputView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        containerView.addSubview(widthSliderView)
        widthSliderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(screenSizeInputView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        containerView.addSubview(heightSliderView)
        heightSliderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(widthSliderView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
    }
    
    func setData(size: J2MESize) {
        updateSize(width: size.width, height: size.height, callBlock: false)
    }
    
    private func updateSize(width: Int, height: Int, callBlock: Bool = true) {
        widthTextField.text = "\(width)"
        heightTextField.text = "\(height)"
        widthSliderView.value = Float(width)
        heightSliderView.value = Float(height)
        currentSize = J2MESize(width: width, height: height)
        if callBlock {
            didSetScreenSize?(currentSize)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class J2MESettingView: BaseView {
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation(title: game.gameType.coreConfigTitle,
                                                       titleIcon: .symbolImage(R.image.j2mesettings_iconSymbols())))
        view.didTapClose = { [weak self] in
            guard let self = self else { return }
            if PlayViewController.isGaming {
                var isChange: Bool = false
                if self.game.j2meScreenRotation != self.initScreenRotation {
                    isChange = true
                }
                if !isChange {
                    let currentSize = self.game.j2meScreenSize
                    if currentSize.cgSize != initScreenSize.cgSize {
                        isChange = true
                    }
                }
                if isChange {
                    UIView.makeAlert(title: R.string.localizable.headsUp(),
                                     detail: R.string.localizable.j2MEScreenChange(),
                                     cancelTitle: R.string.localizable.later(),
                                     confirmTitle: R.string.localizable.resetImmediately(), cancelAction: {
                        self.hide()
                    },confirmAction: {
                        NotificationCenter.default.post(name: R.NotificationName.ResetImmediately, object: nil)
                    })
                } else {
                    self.hide()
                }
            } else {
                self.hide()
            }
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: J2MERotationSwitchCell.self)
        view.register(cellWithClass: J2MEScreenSizeCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: BackgroundColorHaderReusableView.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: BackgroundColorDetailFooterReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        return view
    }()
    
    var game: Game
    private var initScreenRotation: Bool
    private var initScreenSize: J2MESize
    
    private var hideCompletion: (()->Void)? = nil
    
    required init?(parameters: Any...) {
        guard let game = parameters.compactMap({ $0 as? Game }).first else { return nil }
        self.game = game
        self.initScreenRotation = game.j2meScreenRotation
        self.initScreenSize = game.j2meScreenSize
        super.init(frame: .zero)
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalTo(navigationView.snp.bottom)
            make.bottom.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            let itemHeight: CGFloat
            if sectionIndex == 0 {
                itemHeight = R.Size.ItemHeightLarge
            } else {
                itemHeight = 252
            }

            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(itemHeight)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: R.Size.ContentSpaceMedium,
                                                            bottom: 0,
                                                            trailing: R.Size.ContentSpaceMedium)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: R.Size.ContentSpaceSmall, trailing: 0)
            
            //header布局
            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                            heightDimension: .absolute(44)),
                                                                         elementKind: UICollectionView.elementKindSectionHeader,
                                                                         alignment: .top)
            section.boundarySupplementaryItems = [headerItem]
            
            if sectionIndex != 0 {
                let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                heightDimension: .estimated(44)),
                                                                             elementKind: UICollectionView.elementKindSectionFooter,
                                                                             alignment: .bottom)
                section.boundarySupplementaryItems.append(footerItem)
            }
            
            return section
        }
        return layout
    }
}

extension J2MESettingView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: J2MERotationSwitchCell.self, for: indexPath)
            cell.setData(isSelected: game.j2meScreenRotation)
            cell.didSwitchValueChange = { [weak self] value in
                guard let self else { return }
                self.game.updateExtra(key: ExtraKey.j2meScreenRotate.rawValue, value: value)
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: J2MEScreenSizeCell.self, for: indexPath)
            cell.setData(size: game.j2meScreenSize)
            cell.didSetScreenSize = { [weak self] size in
                guard let self else { return }
                self.game.updateExtra(key: ExtraKey.j2meScreenSize.rawValue, value: size.stringValue)
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorHaderReusableView.self, for: indexPath)
            header.titleLabel.text = indexPath.section == 0 ? R.string.localizable.rotateScreen() : R.string.localizable.screenSize()
            return header
        } else {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorDetailFooterReusableView.self, for: indexPath)
            footer.titleLabel.text = R.string.localizable.j2MESettingsTips()
            return footer
        }
    }
}

extension J2MESettingView: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        collectionView.endEditing(true)
    }
}

extension J2MESettingView: ShowableView {
    static func show(game: Game, hideCompletion: (()->Void)? = nil) {
        Self.show(parameters: game)?.hideCompletion = hideCompletion
    }
    
    func didHide() {
        hideCompletion?()
    }
}
