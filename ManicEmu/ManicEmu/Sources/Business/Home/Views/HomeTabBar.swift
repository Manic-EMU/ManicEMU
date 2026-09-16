//
//  HomeTabBar.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/26.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

///主页面的tabbar
class HomeTabBar: BaseView {
    /// 实现一个视图 拥有点击和非点击状态
    private class BarView: BaseView {
        var isSelected: Bool {
            willSet {
                if newValue != self.isSelected {
                    self.updateViews(isSelected: newValue)
                }
            }
        }
        
        /// 计算BarView的宽度
        var contentWidth: CGFloat {
            self.titleLabel.intrinsicContentSize.width +
            (isSelected ? R.Size.IconSizeSmall.width + R.Size.ContentSpaceTiny : 0)
        }
        
        private let symbolView = ASIconView()
        private let titleLabel = ASLabelView()
        private let normalSymbol: ASIcon
        private let selectedSymbol: ASIcon
        
        init(frame: CGRect, isSelected: Bool = false, normalSymbol: ASIcon, selectedSymbol: ASIcon, title: String) {
            self.isSelected = isSelected
            self.normalSymbol = normalSymbol
            self.selectedSymbol = selectedSymbol
            super.init(frame: .zero)
            
            symbolView.icon = isSelected ? selectedSymbol : normalSymbol
            
            titleLabel.text = ASText(attributes: ASText.Attributes(text: title,
                                                                   color: R.Color.LabelPrimary.forceStyle(.dark),
                                                                   font: R.Font.Subheadline(emphasis: true)))
            titleLabel.alpha = isSelected ? 1 : 0
            
            enablePressEffect = true
            enableFocusEffects = false
            
            let contentView = UIView()
            contentView.addSubviews([symbolView, titleLabel])
            symbolView.snp.makeConstraints { makeSymbolViewConstraints(make: $0, isSelected: isSelected) }
            titleLabel.snp.makeConstraints { make in
                make.trailing.centerY.equalToSuperview()
            }
            addSubview(contentView)
            contentView.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func updateViews(isSelected: Bool) {
            if isSelected {
                UIView.normalAnimate { [weak self] in
                    self?.titleLabel.alpha = 1
                }
            } else {
                titleLabel.alpha = 0
            }
            symbolView.snp.remakeConstraints { makeSymbolViewConstraints(make: $0, isSelected: isSelected) }
            symbolView.icon = isSelected ? selectedSymbol : normalSymbol
            
            UIView.springAnimate { [weak self] in
                self?.layoutIfNeeded()
            }
        }
        
        private func makeSymbolViewConstraints(make: ConstraintMaker, isSelected: Bool) {
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(R.Size.IconSizeMedium)
            if isSelected {
                make.trailing.equalTo(titleLabel.snp.leading).offset(-R.Size.ContentSpaceTiny)
            } else {
                make.trailing.equalToSuperview()
            }
        }
    }
    
    enum BarSelection: Int, CaseIterable {
        case games = 0, imports, settings
        
        func next() -> BarSelection {
            switch self {
            case .games:
                return .imports
            case .imports:
                return .settings
            case .settings:
                return .games
            }
        }
        
        func previous() -> BarSelection {
            switch self {
            case .games:
                return .settings
            case .imports:
                return .games
            case .settings:
                return .imports
            }
        }
    }
    
    private let gamesBar = BarView(frame: .zero,
                                   isSelected: true,
                                   normalSymbol: .symbolImage(R.image.games_iconSymbols(),
                                                              weight: .bold,
                                                              colors: [R.Color.LabelPrimary]),
                                   selectedSymbol: .symbolImage(R.image.gamesFill_iconSymbols(),
                                                                weight: .bold,
                                                                colors: [R.Color.LabelPrimary.forceStyle(.dark)]),
                                   title: R.string.localizable.tabbarTitleGames())
    private let importBar = BarView(frame: .zero,
                                    isSelected: false,
                                    normalSymbol: .symbolImage(R.image.import_iconSymbols(),
                                                               weight: .bold,
                                                               colors: [R.Color.LabelPrimary]),
                                    selectedSymbol: .symbolImage(R.image.importFill_iconSymbols(),
                                                                 weight: .bold,
                                                                 colors: [R.Color.LabelPrimary.forceStyle(.dark)]),
                                    title: R.string.localizable.tabbarTitleImport())
    private let settingsBar = BarView(frame: .zero,
                                      isSelected: false,
                                      normalSymbol: .symbolImage(R.image.settings_iconSymbols(),
                                                                 weight: .bold,
                                                                 colors: [R.Color.LabelPrimary]),
                                      selectedSymbol: .symbolImage(R.image.settingFill_iconSymbols(),
                                                                   weight: .bold,
                                                                   colors: [R.Color.LabelPrimary.forceStyle(.dark)]),
                                      title: R.string.localizable.tabbarTitleSettings())
    private var indicatorView: UIView = {
        let view = UIView()
        let animView = AnimatedGradientView(notifiedUpadate: true)
        view.addSubview(animView)
        animView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        view.layerCornerRadius = R.Size.ItemHeightTiny/2
        return view
    }()
    
    
    /// 选中状态更改回调
    var selectionChange: ((BarSelection) -> Void)?

    private weak var focusedBar: BarView?
    private weak var lastFocusedBar: BarView?
    
    /// 当前的选中状态 修改此值会回调selectionChange
    var currentSelection: BarSelection = .games {
        willSet {
            if newValue != currentSelection { //切换tab
                //反选上一次的tab
                var barView: BarView
                switch currentSelection {
                case .games:
                    barView = gamesBar
                case .imports:
                    barView = importBar
                case .settings:
                    barView = settingsBar
                }
                barView.isSelected = false
                
                //选择新tab
                switch newValue {
                case .games:
                    barView = gamesBar
                case .imports:
                    barView = importBar
                case .settings:
                    barView = settingsBar
                }
                barView.isSelected = true
                
                //更新约束和动画
                updateViewsConstraints()
                UIView.springAnimate { [weak self] in
                    self?.layoutIfNeeded()
                }
                UIDevice.generateHaptic()
            }
        }
        didSet {
            selectionChange?(currentSelection)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.layer.cornerRadius = R.Size.HomeTabBarSize.height/2
        if #available(iOS 26.0, tvOS 26.0, *) {
            self.makeGlass()
        } else {
            self.layer.borderWidth = 1
            self.layer.borderColor = R.Color.Border.cgColor
            self.makeBlur(blurColor: R.Color.BackgroundSecondary, cornerRadius: R.Size.HomeTabBarSize.height/2)
        }
        
        enablePressEffect = true
        isFocusable = true
        gamesBar.setPressEffectListener { [weak self] state in
            guard let self, FocusSystem.shared.currentFocusedView == nil else { return }
            self.focusEffect = state == .lift
        }
        importBar.setPressEffectListener { [weak self] state in
            guard let self, FocusSystem.shared.currentFocusedView == nil else { return }
            self.focusEffect = state == .lift
        }
        settingsBar.setPressEffectListener { [weak self] state in
            guard let self, FocusSystem.shared.currentFocusedView == nil else { return }
            self.focusEffect = state == .lift
        }
        
        addSubviews([indicatorView, gamesBar, importBar, settingsBar])
        updateViewsConstraints(isInit: true)
        gamesBar.addTapGesture { [weak self] gesture in
            self?.currentSelection = .games
        }
        importBar.addTapGesture { [weak self] gesture in
            self?.currentSelection = .imports
        }
        settingsBar.addTapGesture { [weak self] gesture in
            self?.currentSelection = .settings
        }
        gamesBar.onFocusConfirm = { [weak self] in
            self?.currentSelection = .games
            return true
        }
        importBar.onFocusConfirm = { [weak self] in
            self?.currentSelection = .imports
            return true
        }
        settingsBar.onFocusConfirm = { [weak self] in
            self?.currentSelection = .settings
            return true
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            if #available(iOS 26.0, tvOS 26.0, *) { } else {
                self.layer.borderWidth = 1
                self.layer.borderColor = R.Color.Border.cgColor
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    private func updateViewsConstraints(isInit: Bool = false) {
        let contentWidth = R.Size.HomeTabBarSize.width - 3*R.Size.ContentSpaceSmall
        let selectedBarConstraintsWidth = contentWidth * 1/2
        let unselectedBarConstraintsWidth = contentWidth * 1/4
        
        func makeWidthConstraints(_ make: ConstraintMaker, _ bar: BarView) {
            make.width.equalTo(bar.isSelected ? selectedBarConstraintsWidth : unselectedBarConstraintsWidth)
        }
        
        if isInit {
            let temp = [gamesBar, importBar, settingsBar]
            for (index, view) in temp.enumerated() {
                view.snp.makeConstraints { make in
                    if index == 0 {
                        make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall)
                    } else {
                        make.leading.equalTo(temp[index-1].snp.trailing).offset(index == 1 ? R.Size.ContentSpaceSmall*1.5 : 0)
                    }
                    make.top.bottom.equalToSuperview()
                    if index == temp.count - 1 {
                        make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceSmall*0.5)
                    } else {
                        makeWidthConstraints(make, view)
                    }
                }
            }
            
            indicatorView.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.height.equalTo(R.Size.ItemHeightTiny)
                if let view = [gamesBar, importBar, settingsBar].filter({ $0.isSelected }).first {
                    make.centerX.equalTo(view)
                    make.width.equalTo(view)
                }
                
            }
            
        } else {
            if gamesBar.isSelected {
                gamesBar.snp.updateConstraints { make in
                    make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall)
                }
                importBar.snp.updateConstraints { make in
                    make.leading.equalTo(gamesBar.snp.trailing).offset(R.Size.ContentSpaceSmall*1.5)
                }
                settingsBar.snp.updateConstraints { make in
                    make.leading.equalTo(importBar.snp.trailing)
                    make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceSmall*0.5)
                }
            } else if importBar.isSelected {
                gamesBar.snp.updateConstraints { make in
                    make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall*0.5)
                }
                importBar.snp.updateConstraints { make in
                    make.leading.equalTo(gamesBar.snp.trailing).offset(R.Size.ContentSpaceSmall)
                }
                settingsBar.snp.updateConstraints { make in
                    make.leading.equalTo(importBar.snp.trailing).offset(R.Size.ContentSpaceSmall)
                    make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceSmall*0.5)
                }
            } else if settingsBar.isSelected {
                gamesBar.snp.updateConstraints { make in
                    make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall*0.5)
                }
                importBar.snp.updateConstraints { make in
                    make.leading.equalTo(gamesBar.snp.trailing)
                }
                settingsBar.snp.updateConstraints { make in
                    make.leading.equalTo(importBar.snp.trailing).offset(R.Size.ContentSpaceSmall*1.5)
                    make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceSmall)
                }
            }
            
            [gamesBar, importBar].forEach { view in
                view.snp.updateConstraints { make in
                    makeWidthConstraints(make, view)
                }
            }
            indicatorView.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.height.equalTo(R.Size.ItemHeightTiny)
                if let view = [gamesBar, importBar, settingsBar].filter({ $0.isSelected }).first {
                    make.centerX.equalTo(view)
                    make.width.equalTo(view)
                }
                
            }
        }
    }
    
    func nextSelection() {
        switch currentSelection {
        case .games:
            currentSelection = .imports
        case .imports:
            currentSelection = .settings
        case .settings:
            currentSelection = .games
        }
    }
    
    func previousSelection() {
        switch currentSelection {
        case .games:
            currentSelection = .settings
        case .imports:
            currentSelection = .games
        case .settings:
            currentSelection = .imports
        }
    }
}

// MARK: - FocusContainer

extension HomeTabBar: FocusContainer {
    var isolatesFocusNavigation: Bool { true }

    var canEnterFocus: Bool {
        window != nil && !isHidden && alpha > 0.01
    }

    func enterFocus(from direction: FocusDirection?, preferred: UIView?) -> UIView? {
        _ = preferred
        // Content may only enter the tab bar by heading down. Left/right/up stay on the page.
        if let direction, direction != .down { return nil }
        let bar = barView(for: currentSelection)
        guard bar.fk_canFocus else { return nil }
        applyBarFocus(bar)
        return bar
    }

    func navigateFocus(_ direction: FocusDirection, current: UIView?) -> FocusContainerResult {
        switch direction {
        case .up, .down:
            return .exit
        case .left, .right:
            let origin = (current as? BarView) ?? focusedBar ?? barView(for: currentSelection)
            guard let next = adjacentBar(from: origin, direction: direction) else {
                return .handled(origin)
            }
            applyBarFocus(next)
            return .handled(next)
        }
    }

    var currentFocusedDescendant: UIView? { focusedBar }

    var lastFocusedDescendant: UIView? { lastFocusedBar }

    func resignFocus() {
        focusedBar = nil
    }

    func performPrimaryActionOnFocused() -> Bool {
        focusedBar?.fk_performPrimaryAction() ?? false
    }

    func focusEntryFrame(from direction: FocusDirection) -> CGRect? {
        FocusEngine.frameInWindow(of: barView(for: currentSelection))
    }
}

extension HomeTabBar {
    private var orderedBars: [BarView] { [gamesBar, importBar, settingsBar] }

    private func barView(for selection: BarSelection) -> BarView {
        switch selection {
        case .games: return gamesBar
        case .imports: return importBar
        case .settings: return settingsBar
        }
    }

    private func selection(for bar: BarView) -> BarSelection? {
        if bar === gamesBar { return .games }
        if bar === importBar { return .imports }
        if bar === settingsBar { return .settings }
        return nil
    }

    private func adjacentBar(from current: BarView, direction: FocusDirection) -> BarView? {
        let bars = orderedBars
        guard let index = bars.firstIndex(where: { $0 === current }) else { return bars.first }
        var delta = direction == .right ? 1 : -1
        if Locale.isRTLLanguage {
            delta = -delta
        }
        let next = (index + delta + bars.count) % bars.count
        return bars[next]
    }

    private func applyBarFocus(_ bar: BarView) {
        if let focusedBar, focusedBar !== bar {
            focusedBar.fk_applyFocus(false)
        }
        bar.fk_applyFocus(true)
        focusedBar = bar
        lastFocusedBar = bar
        if let selection = selection(for: bar), currentSelection != selection {
            currentSelection = selection
        }
    }
}
