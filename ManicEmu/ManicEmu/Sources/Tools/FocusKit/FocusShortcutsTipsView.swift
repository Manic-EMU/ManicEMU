//
//  FocusShortcutsTipsView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit

/// Full-screen shortcut cheatsheet. Shown while Command / Control / Select is held;
/// not focusable and not interactive. Gameplay never reaches here because FocusKit is off.
final class FocusShortcutsTipsView: BaseView, ViewTransition {

    enum Source {
        case keyboard
        case controller
    }

    private static let shared = FocusShortcutsTipsView()
    private static var holdingKeys = Set<FocusKey>()

    private static let cellHeight = R.Size.ItemHeightTiny
    private static let rowSpacing = R.Size.ContentSpaceSmall
    private static let columnSpacing = R.Size.ContentSpaceLarge
    private static let maxColumnWidth: CGFloat = 340
    private static let badgeHeight: CGFloat = R.Size.IconSizeMedium.height

    private var source: Source = .keyboard
    private var items: [Item] = []
    private var paddedItems: [Item?] = []
    private var columnCount = 1
    private var rowCount = 1
    private var lastLayoutSize: CGSize = .zero

    private let headerIconView = ASIconView(.symbolImage(R.image.info_iconSymbols(), colors: [R.Color.LabelPrimary]))
    private let headerTitleView = ASLabelView(text: .extraLargeText(R.string.localizable.focusShortcutsTips()))
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.isScrollEnabled = false
        view.isUserInteractionEnabled = false
        view.isFocusable = false
        view.allowsSelection = false
        view.contentInsetAdjustmentBehavior = .never
        view.clipsToBounds = true
        view.dataSource = self
        view.register(Cell.self, forCellWithReuseIdentifier: Cell.reuseId)
        return view
    }()

    static func isTriggerKey(_ key: FocusKey) -> Bool {
        key == .command || key == .control || key == .select
    }

    /// Present while `key` is held. Stacks if several trigger keys are down; hides when the last one is released.
    static func show(source: Source, holding key: FocusKey) {
        guard FocusSystem.shared.isEnabled, FocusSystem.shared.currentContext != nil else { return }
        holdingKeys.insert(key)
        shared.present(source: source)
    }

    static func handleKeyUp(_ key: FocusKey) {
        guard holdingKeys.remove(key) != nil else { return }
        if holdingKeys.isEmpty {
            shared.dismiss()
        }
    }

    static func hide() {
        holdingKeys.removeAll()
        shared.dismiss()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isFocusable = false
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        isHidden = true
        alpha = 0
        backgroundColor = .clear
        makeBlur(blurColor: R.Color.BackgroundPrimary)

        let header = UIView()
        header.addSubviews([headerIconView, headerTitleView])
        headerIconView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(R.Size.IconSizeMedium)
        }
        headerTitleView.snp.makeConstraints { make in
            make.leading.equalTo(headerIconView.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.top.bottom.trailing.equalToSuperview()
        }

        addSubviews([header, collectionView])
        header.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(R.Size.ContentSpaceSmall)
            make.leading.equalTo(safeAreaLayoutGuide).offset(R.Size.ContentSpaceHuge)
            make.trailing.lessThanOrEqualTo(safeAreaLayoutGuide).inset(R.Size.ContentSpaceHuge)
        }
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(R.Size.ContentSpaceHuge)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(R.Size.ContentSpaceLarge)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGridIfNeeded()
    }

    func viewDidTransition() {
        updateGridIfNeeded(force: true)
    }

    private func present(source: Source) {
        guard let window = UIWindow.topWindow(in: FocusSystem.shared.currentContext?.rootView?.hostingWindowScene) else { return }
        self.source = source
        reloadItems()
        if superview !== window {
            removeFromSuperview()
            window.addSubview(self)
            snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        window.bringSubviewToFront(self)
        isHidden = false
        layoutIfNeeded()
        updateGridIfNeeded(force: true)
        if alpha < 1 {
            UIView.normalAnimate {
                self.alpha = 1
            }
        }
    }

    private func dismiss() {
        guard superview != nil, !isHidden else { return }
        UIView.normalAnimate {
            self.alpha = 0
        } completion: { _ in
            guard Self.holdingKeys.isEmpty else { return }
            self.isHidden = true
            self.removeFromSuperview()
        }
    }

    private func reloadItems() {
        let triggerKeys: Set<FocusKey> = [.command, .control, .select]
        items = FocusSystem.shared.currentHints.compactMap { hint in
            if hint.keys.contains(where: { triggerKeys.contains($0) }) { return nil }
            let keys = hint.keys.filter { key in
                switch source {
                case .keyboard:
                    return !key.isExclusiveControllerKey
                case .controller:
                    return key.isControllerKey
                }
            }
            guard !keys.isEmpty else { return nil }
            return Item(title: hint.title, badges: Self.compactBadges(keys.map { $0.badge(for: source) }))
        }
    }

    private func updateGridIfNeeded(force: Bool = false) {
        let available = collectionView.bounds.size
        guard available.width > 1, available.height > 1 else { return }
        collectionView.isHidden = items.isEmpty
        guard !items.isEmpty else {
            if force || !paddedItems.isEmpty {
                paddedItems = []
                lastLayoutSize = available
                collectionView.reloadData()
            }
            return
        }
        let grid = Self.grid(itemCount: items.count, in: available)
        let padded = Self.pad(items, columns: grid.columns, rows: grid.rows)
        let sizeChanged = lastLayoutSize != available
        let gridChanged = grid.columns != columnCount || grid.rows != rowCount
        guard force || sizeChanged || gridChanged else { return }

        columnCount = grid.columns
        rowCount = grid.rows
        lastLayoutSize = available
        paddedItems = padded
        collectionView.setCollectionViewLayout(
            makeLayout(columns: grid.columns, rows: grid.rows, availableWidth: available.width),
            animated: false
        )
        collectionView.reloadData()
    }

    private static func compactBadges(_ badges: [FocusKey.Badge]) -> [FocusKey.Badge] {
        var texts: [String] = []
        var result: [FocusKey.Badge] = []
        for badge in badges {
            switch badge {
            case .text(let string):
                texts.append(string)
            case .icon:
                if !texts.isEmpty {
                    result.append(.text(texts.joined(separator: " ")))
                    texts.removeAll()
                }
                result.append(badge)
            }
        }
        if !texts.isEmpty {
            result.append(.text(texts.joined(separator: " ")))
        }
        return result
    }

    private static func grid(itemCount: Int, in available: CGSize) -> (columns: Int, rows: Int) {
        let maxRows = max(1, Int(floor((available.height + rowSpacing) / (cellHeight + rowSpacing))))
        let columns = max(1, Int(ceil(Double(itemCount) / Double(maxRows))))
        let rows = min(maxRows, max(1, Int(ceil(Double(itemCount) / Double(columns)))))
        return (columns, rows)
    }

    private static func pad(_ items: [Item], columns: Int, rows: Int) -> [Item?] {
        let total = columns * rows
        return (0..<total).map { $0 < items.count ? items[$0] : nil }
    }

    private func makeLayout(columns: Int, rows: Int, availableWidth: CGFloat) -> UICollectionViewLayout {
        let spacing = Self.columnSpacing
        let columnWidth = min(
            Self.maxColumnWidth,
            (availableWidth - CGFloat(max(0, columns - 1)) * spacing) / CGFloat(columns)
        )
        let columnHeight = CGFloat(rows) * Self.cellHeight + CGFloat(max(0, rows - 1)) * Self.rowSpacing
        return UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .absolute(Self.cellHeight)
                )
            )
            let columnGroup: NSCollectionLayoutGroup
            let columnSize = NSCollectionLayoutSize(
                widthDimension: .absolute(columnWidth),
                heightDimension: .absolute(columnHeight)
            )
            if #available(iOS 16.0, tvOS 16.0, *) {
                columnGroup = NSCollectionLayoutGroup.vertical(layoutSize: columnSize, repeatingSubitem: item, count: rows)
            } else {
                columnGroup = NSCollectionLayoutGroup.vertical(layoutSize: columnSize, subitem: item, count: rows)
            }
            columnGroup.interItemSpacing = .fixed(Self.rowSpacing)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(columnWidth * CGFloat(columns) + spacing * CGFloat(max(0, columns - 1))),
                heightDimension: .absolute(columnHeight)
            )
            let group: NSCollectionLayoutGroup
            if #available(iOS 16.0, tvOS 16.0, *) {
                group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: columnGroup, count: columns)
            } else {
                group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: columnGroup, count: columns)
            }
            group.interItemSpacing = .fixed(spacing)
            let section = NSCollectionLayoutSection(group: group)
            // One column is narrower than the view; center it instead of pinning leading.
            if columns == 1 {
                let inset = max(0, (availableWidth - columnWidth) / 2)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: inset, bottom: 0, trailing: inset)
            }
            return section
        }
    }
}

// MARK: - Data source

extension FocusShortcutsTipsView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        paddedItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Cell.reuseId, for: indexPath) as! Cell
        cell.configure(paddedItems[indexPath.item])
        return cell
    }
}

// MARK: - Cell

private extension FocusShortcutsTipsView {
    struct Item {
        let title: String
        let badges: [FocusKey.Badge]
    }

    final class Cell: UICollectionViewCell {
        static let reuseId = "FocusShortcutsTipsCell"

        private let chromeView = UIView()
        private let titleLabel = ASLabelView()
        private let badgeStack = UIStackView()
        private var appliedChrome = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            isFocusable = false
            isUserInteractionEnabled = false
            backgroundColor = .clear
            contentView.backgroundColor = .clear

            chromeView.layerCornerRadius = FocusShortcutsTipsView.cellHeight / 2
            chromeView.layer.borderWidth = 1
            chromeView.layer.borderColor = R.Color.Border.cgColor
            chromeView.clipsToBounds = true

            badgeStack.axis = .horizontal
            badgeStack.spacing = R.Size.ContentSpaceTiny
            badgeStack.alignment = .center

            contentView.addSubview(chromeView)
            chromeView.addSubviews([titleLabel, badgeStack])
            chromeView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            titleLabel.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall)
                make.centerY.equalToSuperview()
            }
            badgeStack.snp.makeConstraints { make in
                make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
                make.trailing.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
                make.centerY.equalToSuperview()
                make.height.equalTo(FocusShortcutsTipsView.badgeHeight)
            }
            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            badgeStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                chromeView.layer.borderColor = R.Color.Border.cgColor
            }
        }

        func configure(_ item: Item?) {
            applyChromeIfNeeded()
            guard let item else {
                chromeView.isHidden = true
                return
            }
            chromeView.isHidden = false
            titleLabel.text = ASText(attributes: .footnote(
                text: item.title,
                color: R.Color.LabelPrimary
            ))
            rebuildBadges(item.badges)
        }

        private func applyChromeIfNeeded() {
            guard !appliedChrome else { return }
            appliedChrome = true
            if #available(iOS 26.0, tvOS 26.0, *) {
                chromeView.makeGlass()
            } else {
                chromeView.backgroundColor = R.Color.BackgroundSecondary.withAlphaComponent(0.7)
            }
        }

        private func rebuildBadges(_ badges: [FocusKey.Badge]) {
            badgeStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for badge in badges {
                badgeStack.addArrangedSubview(Self.makeBadgeView(badge))
            }
        }

        private static func makeBadgeView(_ badge: FocusKey.Badge) -> UIView {
            let view = UIView()
            view.backgroundColor = R.Color.BackgroundTertiary
            view.clipsToBounds = true

            switch badge {
            case .text(let string):
                let label = ASLabelView(text: ASText(attributes: ASText.Attributes(
                    text: string,
                    color: R.Color.LabelPrimary,
                    font: R.Font.Caption(emphasis: true),
                    alignment: .center
                )))
                view.addSubview(label)
                label.snp.makeConstraints { make in
                    make.centerY.equalToSuperview()
                    make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
                }
            case .icon(let icon):
                let iconView = ASIconView(icon)
                view.addSubview(iconView)
                iconView.snp.makeConstraints { make in
                    make.center.equalToSuperview()
                    make.size.equalTo(CGSize(width: 14, height: 14))
                }
            }

            view.snp.makeConstraints { make in
                make.height.equalTo(FocusShortcutsTipsView.badgeHeight)
                make.width.greaterThanOrEqualTo(FocusShortcutsTipsView.badgeHeight)
            }
            view.layerCornerRadius = FocusShortcutsTipsView.badgeHeight / 2
            return view
        }
    }
}

// MARK: - Key classification / badge text

private extension FocusKey {
    enum Badge {
        case text(String)
        case icon(ASIcon)
    }

    static let exclusiveControllerNames: Set<String> = [
        "leftShoulder", "rightShoulder", "leftTrigger", "rightTrigger",
        "leftThumbstickButton", "rightThumbstickButton",
        "leftThumbstickUp", "leftThumbstickDown", "leftThumbstickLeft", "leftThumbstickRight",
        "rightThumbstickUp", "rightThumbstickDown", "rightThumbstickLeft", "rightThumbstickRight",
        "menu", "select", "start", "plus", "minus", "home", "options",
        "l1", "l2", "l3", "r1", "r2", "r3"
    ]

    static let sharedControllerNames: Set<String> = [
        "a", "b", "x", "y", "up", "down", "left", "right"
    ]

    /// Shoulders, sticks, menu/select/start — never shown in the keyboard cheatsheet.
    var isExclusiveControllerKey: Bool {
        if rawValue.contains("+") { return false }
        return Self.exclusiveControllerNames.contains(rawValue)
    }

    var isControllerKey: Bool {
        if rawValue.contains("+") { return false }
        return isExclusiveControllerKey || Self.sharedControllerNames.contains(rawValue)
    }

    func badge(for source: FocusShortcutsTipsView.Source) -> Badge {
        if source == .controller, rawValue == "menu" || rawValue == "home" {
            return .icon(.symbolImage(R.image.home_iconSymbols(), colors: [R.Color.LabelPrimary]))
        }
        return .text(displayLabel(for: source))
    }

    func displayLabel(for source: FocusShortcutsTipsView.Source) -> String {
        switch source {
        case .keyboard:
            switch self {
            case .a: return "return"
            case .b: return "escape"
            default: return rawValue
            }
        case .controller:
            return controllerShortName
        }
    }

    /// Same abbreviations as controller mapping bubbles (L1/L2/L3…).
    var controllerShortName: String {
        switch rawValue {
        case "leftShoulder", "l1": return "L1"
        case "leftTrigger", "l2": return "L2"
        case "leftThumbstickButton", "l3": return "L3"
        case "leftThumbstickDown": return "L↓"
        case "leftThumbstickLeft": return "L←"
        case "leftThumbstickRight": return "L→"
        case "leftThumbstickUp": return "L↑"
        case "rightShoulder", "r1": return "R1"
        case "rightTrigger", "r2": return "R2"
        case "rightThumbstickButton", "r3": return "R3"
        case "rightThumbstickDown": return "R↓"
        case "rightThumbstickLeft": return "R←"
        case "rightThumbstickRight": return "R→"
        case "rightThumbstickUp": return "R↑"
        case "up": return "↑"
        case "down": return "↓"
        case "left": return "←"
        case "right": return "→"
        case "plus": return "+"
        case "minus": return "-"
        case "a", "b", "x", "y":
            return rawValue.uppercased()
        default:
            if let first = rawValue.first {
                return first.uppercased() + rawValue.dropFirst()
            }
            return rawValue
        }
    }
}
