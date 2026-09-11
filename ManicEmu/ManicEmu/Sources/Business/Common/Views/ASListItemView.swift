//
//  ASListItemView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/8.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASListItemCollectionCell: UICollectionViewCell {
    private let itemView = ASListItemView()
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        addSubview(itemView)
        itemView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(itemStyles: [ASListPage.Cell.Style], enablePressEffect: Bool) {
        itemView.styles = itemStyles
        if enablePressEffect {
            if !self.enablePressEffect {
                self.enablePressEffect = true
                enablePressEffectOverlay(cornerStyle: .radius(R.Size.CornerRadiusLarge),
                                         enableLiftEffect: false)
            }
        } else if self.enablePressEffect {
            self.enablePressEffect = false
        }
    }
    
    func setActionCallback(_ callback: ((ASListPage.Cell.Style, _ extraValue: Any?) -> Void)? = nil) {
        itemView.didActionOccurred = callback
    }
    
}

class ASListItemView: BaseView {
    
    // Leaf views — created on demand, retained for reuse until this view is deallocated.
    var iconView: ASIconView? = nil
    var titlelabel: ASLabelView? = nil
    var subTitlelabel: ASLabelView? = nil
    var detaillabel: ASLabelView? = nil
    var buttonViews = [ASButtonView]()
    var switchButtons = [ASSwitchView]()
    var stepViews = [ASStepView]()
    var checkButtons = [ASCheckView]()
    var radioButtons = [ASRadioView]()
    var chevronViews = [ASButtonView]()
    var segmentViews = [ASSegmentView]()
    /// ASProgressView interaction mode is fixed at init; recreate when styles change.
    var progressView: ASProgressView? = nil
    
    // Container views — reused across updates; only arranged subviews and constraints change.
    private lazy var textBlock: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = textVerticalSpacing
        stack.setContentHuggingPriority(.required, for: .vertical)
        stack.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        stack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }()
    
    private lazy var titleRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = R.Size.ContentSpaceTiny
        return stack
    }()
    
    private lazy var titleRowMiddleSpacer: UIView = {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return spacer
    }()
    
    private lazy var titleRowTrailingSpacer: UIView = {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return spacer
    }()
    
    private lazy var textBlockContainer: UIView = {
        let container = UIView()
        container.setContentHuggingPriority(.defaultLow, for: .horizontal)
        container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        container.addSubview(textBlock)
        textBlock.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        return container
    }()
    
    private lazy var accessoryStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = accessorySpacing
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stack
    }()
    
    ///When grouped vertically with progress, it serves as a layout reference for overall centering.
    private var groupGuide: UILayoutGuide? = nil
    
    ///icon default size
    private var iconSize: ASListPage.Cell.Style.IconSize = .fixSize(CGSize(R.Size.ButtonExtraExtraSmall))
    ///accessory horizontal spacing
    private let accessorySpacing = R.Size.ContentSpaceMedium
    ///icon text spacing
    private let iconTextSpacing = R.Size.ContentSpaceExtraSmall
    ///The spacing between the horizontal elements
    private let horizontalSpacing = R.Size.ContentSpaceSmall
    ///Minimum spacing between content and the top/bottom
    private let verticalPadding = R.Size.ContentSpaceExtraSmall
    ///text 与 progress 之间的间距
    private let textProgressSpacing = R.Size.ContentSpaceExtraSmall
    
    private let textVerticalSpacing = 0.0
    
    /// Describes row layout structure; content-only updates skip hierarchy teardown when unchanged.
    private struct LayoutSignature: Equatable {
        enum AccessoryKind: Equatable {
            case button, `switch`, step, check, radio, chevron, segment
        }
        
        enum ProgressInteractionKind: Equatable {
            case enabled
            case disabledSmall
            case disabledLarge
        }
        
        let hasIcon: Bool
        let iconSize: ASListPage.Cell.Style.IconSize
        let hasTitle: Bool
        let hasSubTitle: Bool
        let subtitleFollows: Bool
        let hasDetail: Bool
        let hasProgress: Bool
        let progressInteraction: ProgressInteractionKind?
        let accessoryKinds: [AccessoryKind]
        
        static func make(from styles: [ASListPage.Cell.Style]) -> LayoutSignature {
            var icon: ASListPage.Cell.Style?
            var title: ASListPage.Cell.Style?
            var detail: ASListPage.Cell.Style?
            var progress: ASListPage.Cell.Style?
            var accessoryKinds = [AccessoryKind]()
            
            for style in styles {
                switch style {
                case .icon: icon = style
                case .title: title = style
                case .detail: detail = style
                case .progress: progress = style
                case .button: accessoryKinds.append(.button)
                case .switch: accessoryKinds.append(.switch)
                case .step: accessoryKinds.append(.step)
                case .check: accessoryKinds.append(.check)
                case .radio: accessoryKinds.append(.radio)
                case .chevron: accessoryKinds.append(.chevron)
                case .segment: accessoryKinds.append(.segment)
                }
            }
            
            var hasIcon = false
            var iconSize: ASListPage.Cell.Style.IconSize = .fixSize(CGSize(R.Size.ButtonExtraExtraSmall))
            if case let .icon(_, size) = icon {
                hasIcon = true
                iconSize = size
            }
            
            var hasTitle = false
            var hasSubTitle = false
            var subtitleFollows = true
            if case let .title(_, subTitle, follows, _) = title {
                hasTitle = true
                hasSubTitle = subTitle != nil
                subtitleFollows = follows
            }
            
            let hasDetail = detail != nil
            
            var hasProgress = false
            var progressInteraction: ProgressInteractionKind?
            if case let .progress(itemProgress) = progress {
                hasProgress = true
                switch itemProgress.interaction {
                case .enabled:
                    progressInteraction = .enabled
                case .disabled(.small):
                    progressInteraction = .disabledSmall
                case .disabled(.large):
                    progressInteraction = .disabledLarge
                }
            }
            
            return LayoutSignature(hasIcon: hasIcon,
                                   iconSize: iconSize,
                                   hasTitle: hasTitle,
                                   hasSubTitle: hasSubTitle,
                                   subtitleFollows: subtitleFollows,
                                   hasDetail: hasDetail,
                                   hasProgress: hasProgress,
                                   progressInteraction: progressInteraction,
                                   accessoryKinds: accessoryKinds)
        }
    }
    
    private struct ParsedStyles {
        var icon: ASListPage.Cell.Style?
        var title: ASListPage.Cell.Style?
        var detail: ASListPage.Cell.Style?
        var progress: ASListPage.Cell.Style?
        
        static func make(from styles: [ASListPage.Cell.Style]) -> ParsedStyles {
            var parsed = ParsedStyles()
            for style in styles {
                switch style {
                case .icon: parsed.icon = style
                case .title: parsed.title = style
                case .detail: parsed.detail = style
                case .progress: parsed.progress = style
                default: break
                }
            }
            return parsed
        }
    }
    
    private var lastLayoutSignature: LayoutSignature?
    
    var styles: [ASListPage.Cell.Style] {
        didSet {
            updateViews()
        }
    }
    
    ///Component interaction callback
    var didActionOccurred: ((ASListPage.Cell.Style, _ extraValue: Any?) -> Void)? = nil {
        didSet {
            updateActionCallbacks()
        }
    }
    
    ///Should the interaction of certain components be disabled?
    var didActionEnable: ((ASListPage.Cell.Style) -> Bool)? = nil
    
    init(_ styles: ASListPage.Cell.Style...) {
        self.styles = styles
        super.init(frame: .zero)
        
        //Make the view fit its content height even when there’s no external height constraint.
        snp.makeConstraints { make in
            make.height.equalTo(0).priority(.low)
        }
        
        updateViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func getStyles() -> [ASListPage.Cell.Style] {
        var temp = styles
        var switchIndex = 0
        var stepIndex = 0
        var checkIndex = 0
        var radioIndex = 0
        var segmentIndex = 0
        for (styleIndex, style) in styles.enumerated() {
            switch style {
            case .switch:
                if case var .switch(aSwitch) = style {
                    let switchButton = switchButtons[switchIndex]
                    if switchButton.isEnabled {
                        aSwitch.state = switchButton.on ? .on : .off
                    } else {
                        aSwitch.state = .disabled
                    }
                    temp[styleIndex] = .switch(aSwitch)
                }
                switchIndex += 1
                
            case .step:
                if case .step = style {
                    temp[styleIndex] = .step(stepViews[stepIndex].step)
                }
                stepIndex += 1
                
            case .check:
                if case var .check(check) = style {
                    check.isSelected = checkButtons[checkIndex].isSelected
                    temp[styleIndex] = .check(check)
                }
                checkIndex += 1
                
            case .radio:
                if case var .radio(radio) = style {
                    radio.isSelected = radioButtons[radioIndex].isSelected
                    temp[styleIndex] = .radio(radio)
                }
                radioIndex += 1
                
            case .progress:
                if case var .progress(progress) = style {
                    progress.value = progressView?.value ?? 0
                    temp[styleIndex] = .progress(progress)
                }
                
            case .segment:
                if case .segment = style {
                    temp[styleIndex] = .segment(segmentViews[segmentIndex].segment)
                }
                segmentIndex += 1
            default:
                break
            }
        }
        return temp
    }
    
    private func updateViews() {
        let parsed = ParsedStyles.make(from: styles)
        let signature = LayoutSignature.make(from: styles)
        
        if signature == lastLayoutSignature {
            applyContentUpdates(parsed: parsed)
            updateActionCallbacks()
            return
        }
        
        lastLayoutSignature = signature
        rebuildStructure(parsed: parsed)
    }
    
    /// Structure unchanged: update leaf content in place without detaching views or rebuilding constraints.
    private func applyContentUpdates(parsed: ParsedStyles) {
        if let iconView = configureIcon(from: parsed.icon) {
            applyIconPositionAndSize(iconView)
        }
        updateTextContentInPlace(title: parsed.title, detail: parsed.detail)
        updateAccessoriesInPlace(from: styles)
        
        if case let .progress(progressModel) = parsed.progress {
            progressView?.value = progressModel.value
        }
    }
    
    /// Structure changed: detach containers, rebuild hierarchy and constraints.
    private func rebuildStructure(parsed: ParsedStyles) {
        subviews.forEach { $0.removeFromSuperview() }
        if let groupGuide {
            removeLayoutGuide(groupGuide)
            self.groupGuide = nil
        }
        
        let activeIconView = configureIcon(from: parsed.icon)
        let hasTextContent = configureTextBlock(title: parsed.title, detail: parsed.detail)
        let activeAccessoryStack = configureAccessoryStack(from: styles)
        
        var itemProgress: ASProgress? = nil
        var activeProgressView: ASProgressView? = nil
        if case let .progress(progressModel) = parsed.progress {
            progressView = ASProgressView(progressModel)
            activeProgressView = progressView
            itemProgress = progressModel
        } else {
            progressView = nil
        }
        
        layout(iconView: activeIconView,
               textBlockContainer: hasTextContent ? textBlockContainer : nil,
               accessoryStack: activeAccessoryStack,
               progressView: activeProgressView,
               itemProgress: itemProgress)
        
        updateActionCallbacks()
    }
    
    //MARK: - Leaf view reuse
    
    private func configureIcon(from icon: ASListPage.Cell.Style?) -> ASIconView? {
        guard case let .icon(itemIcon, iconSize) = icon else { return nil }
        self.iconSize = iconSize
        if iconView == nil {
            iconView = ASIconView(itemIcon)
        } else {
            iconView?.icon = itemIcon
        }
        switch iconSize {
        case .fixHeight(let height):
            iconView?.sizeStyle = .fixHeight(height)
        case .fixSize(let size):
            iconView?.sizeStyle = .fixSize(size)
        case .autoLayout:
            iconView?.sizeStyle = .auto
        }
        return iconView
    }
    
    private func ensureTitleLabel() -> ASLabelView {
        if let titlelabel {
            return titlelabel
        }
        let label = ASLabelView()
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titlelabel = label
        return label
    }
    
    private func ensureSubTitleLabel() -> ASLabelView {
        if let subTitlelabel {
            return subTitlelabel
        }
        let label = ASLabelView()
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        subTitlelabel = label
        return label
    }
    
    private func ensureDetailLabel() -> ASLabelView {
        if let detaillabel {
            return detaillabel
        }
        let label = ASLabelView()
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        detaillabel = label
        return label
    }
    
    private func applySwitch(_ view: ASSwitchView, _ aSwitch: ASSwitch) {
        view.onColor = aSwitch.onColor
        view.offColor = aSwitch.offColor
        view.isEnabled = aSwitch.state != .disabled
        view.on = aSwitch.state == .on
    }
    
    private func applyCheck(_ view: ASCheckView, _ check: ASCheck) {
        view.isSelected = check.isSelected
    }
    
    private func applyRadio(_ view: ASRadioView, _ radio: ASRadio) {
        view.isSelected = radio.isSelected
    }
    
    private func configureAccessoryPriorities(_ view: UIView) {
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    //MARK: - building text
    
    private func updateTextContentInPlace(title: ASListPage.Cell.Style?, detail: ASListPage.Cell.Style?) {
        if case let .title(titleText, subTitleText, _, _) = title {
            ensureTitleLabel().text = enforce(titleText, numberOfLines: 1)
            if let subTitleText {
                ensureSubTitleLabel().text = enforce(subTitleText, numberOfLines: 1)
            }
        }
        
        if case let .detail(detailText, _) = detail {
            ensureDetailLabel().text = enforce(detailText, numberOfLines: 2)
        }
    }
    
    private func updateAccessoriesInPlace(from styles: [ASListPage.Cell.Style]) {
        var buttonIndex = 0
        var switchIndex = 0
        var stepIndex = 0
        var checkIndex = 0
        var radioIndex = 0
        var chevronIndex = 0
        var segmentIndex = 0
        
        for style in styles {
            switch style {
            case .button(let itemButton):
                if buttonIndex < buttonViews.count {
                    buttonViews[buttonIndex].button = itemButton
                }
                buttonIndex += 1
                
            case .switch(let aSwitch):
                if switchIndex < switchButtons.count {
                    applySwitch(switchButtons[switchIndex], aSwitch)
                }
                switchIndex += 1
                
            case .step(let itemStep):
                if stepIndex < stepViews.count {
                    stepViews[stepIndex].step = itemStep
                }
                stepIndex += 1
                
            case .check(let check):
                if checkIndex < checkButtons.count {
                    applyCheck(checkButtons[checkIndex], check)
                }
                checkIndex += 1
                
            case .radio(let radio):
                if radioIndex < radioButtons.count {
                    applyRadio(radioButtons[radioIndex], radio)
                }
                radioIndex += 1
                
            case .chevron(let chevron):
                if chevronIndex < chevronViews.count {
                    chevronViews[chevronIndex].button = chevron.button
                }
                chevronIndex += 1
                
            case .segment(let itemSegment):
                if segmentIndex < segmentViews.count {
                    segmentViews[segmentIndex].segment = itemSegment
                }
                segmentIndex += 1
                
            default:
                break
            }
        }
    }
    
    ///The title and subtitle are placed horizontally in one line (single line), with the detail in the second line (up to two lines), and all three are arranged vertically.
    @discardableResult
    private func configureTextBlock(title: ASListPage.Cell.Style?, detail: ASListPage.Cell.Style?) -> Bool {
        textBlock.removeAllArrangedSubviews()
        titleRow.removeAllArrangedSubviews()
        
        var hasContent = false
        
        if case let .title(titleText, subTitleText, subtitleFollows, _) = title {
            let titleLabel = ensureTitleLabel()
            titleLabel.text = enforce(titleText, numberOfLines: 1)
            titleRow.addArrangedSubview(titleLabel)
            
            if let subTitleText {
                let subTitleLabel = ensureSubTitleLabel()
                subTitleLabel.text = enforce(subTitleText, numberOfLines: 1)
                titleRow.addArrangedSubview(subTitleLabel)
                
                if subtitleFollows {
                    titleRow.addArrangedSubview(titleRowTrailingSpacer)
                } else {
                    titleRow.insertArrangedSubview(titleRowMiddleSpacer, at: 1)
                }
            }
            
            textBlock.addArrangedSubview(titleRow)
            hasContent = true
        }
        
        if case let .detail(detailText, _) = detail {
            let detailLabel = ensureDetailLabel()
            detailLabel.text = enforce(detailText, numberOfLines: 2)
            textBlock.addArrangedSubview(detailLabel)
            hasContent = true
        }
        
        return hasContent
    }
    
    private func enforce(_ text: ASText, numberOfLines: Int) -> ASText {
        var temp = text
        temp.attributes?.numberOfLines = numberOfLines
        return temp
    }
    
    //MARK: - Build accessories
    
    ///Build accessories in the order of styles appearance. Buttons / switch / step / check / radio / chevron / segment — duplicates are allowed.
    private func configureAccessoryStack(from styles: [ASListPage.Cell.Style]) -> UIStackView? {
        accessoryStack.removeAllArrangedSubviews()
        
        var buttonIndex = 0
        var switchIndex = 0
        var stepIndex = 0
        var checkIndex = 0
        var radioIndex = 0
        var chevronIndex = 0
        var segmentIndex = 0
        var hasAccessory = false
        
        for style in styles {
            switch style {
            case .button(let itemButton):
                if buttonIndex >= buttonViews.count {
                    buttonViews.append(ASButtonView(itemButton))
                } else {
                    buttonViews[buttonIndex].button = itemButton
                }
                let view = buttonViews[buttonIndex]
                configureAccessoryPriorities(view)
                accessoryStack.addArrangedSubview(view)
                buttonIndex += 1
                hasAccessory = true
                
            case .switch(let aSwitch):
                if switchIndex >= switchButtons.count {
                    switchButtons.append(ASSwitchView(aSwitch))
                } else {
                    applySwitch(switchButtons[switchIndex], aSwitch)
                }
                let view = switchButtons[switchIndex]
                configureAccessoryPriorities(view)
                accessoryStack.addArrangedSubview(view)
                switchIndex += 1
                hasAccessory = true
                
            case .step(let itemStep):
                if stepIndex >= stepViews.count {
                    stepViews.append(ASStepView(itemStep))
                } else {
                    stepViews[stepIndex].step = itemStep
                }
                let view = stepViews[stepIndex]
                configureAccessoryPriorities(view)
                accessoryStack.addArrangedSubview(view)
                stepIndex += 1
                hasAccessory = true
                
            case .check(let check):
                if checkIndex >= checkButtons.count {
                    checkButtons.append(ASCheckView(check))
                } else {
                    applyCheck(checkButtons[checkIndex], check)
                }
                let view = checkButtons[checkIndex]
                configureAccessoryPriorities(view)
                accessoryStack.addArrangedSubview(view)
                checkIndex += 1
                hasAccessory = true
                
            case .radio(let radio):
                if radioIndex >= radioButtons.count {
                    radioButtons.append(ASRadioView(radio))
                } else {
                    applyRadio(radioButtons[radioIndex], radio)
                }
                let view = radioButtons[radioIndex]
                configureAccessoryPriorities(view)
                accessoryStack.addArrangedSubview(view)
                radioIndex += 1
                hasAccessory = true
                
            case .chevron(let chevron):
                if chevronIndex >= chevronViews.count {
                    chevronViews.append(ASButtonView(chevron.button))
                } else {
                    chevronViews[chevronIndex].button = chevron.button
                }
                let view = chevronViews[chevronIndex]
                configureAccessoryPriorities(view)
                accessoryStack.addArrangedSubview(view)
                chevronIndex += 1
                hasAccessory = true
                
            case .segment(let itemSegment):
                if segmentIndex >= segmentViews.count {
                    segmentViews.append(ASSegmentView(itemSegment))
                } else {
                    segmentViews[segmentIndex].segment = itemSegment
                }
                let view = segmentViews[segmentIndex]
                configureAccessoryPriorities(view)
                accessoryStack.addArrangedSubview(view)
                segmentIndex += 1
                hasAccessory = true
                
            default:
                break
            }
        }
        
        return hasAccessory ? accessoryStack : nil
    }
    
    //MARK: - Layout constraints
    
    private func applyIconPositionAndSize(_ iconView: ASIconView) {
        iconView.snp.remakeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            switch iconSize {
            case .fixHeight(let height):
                make.height.equalTo(height)
                make.width.equalTo(iconView.snp.height).multipliedBy(iconView.contentAspectRatio)
            case .fixSize(let size):
                make.size.equalTo(size)
            case .autoLayout:
                make.top.greaterThanOrEqualToSuperview().inset(verticalPadding)
                make.bottom.lessThanOrEqualToSuperview().inset(verticalPadding)
            }
        }
        iconView.invalidateIntrinsicContentSize()
    }
    
    private func layout(iconView: ASIconView?,
                        textBlockContainer: UIView?,
                        accessoryStack: UIStackView?,
                        progressView: ASProgressView?,
                        itemProgress: ASProgress?) {
        
        // Icon: leading aligned, vertically centered. Remake is required: reused cells keep old
        // size constants (often the default 24); stacking with makeConstraints conflicts and
        // Auto Layout typically drops the larger one, shrinking icons like ESRP to 24.
        if let iconView {
            addSubview(iconView)
            applyIconPositionAndSize(iconView)
        }
        
        //accessory: Keep its own size by trailing, and center it vertically relative to the entire line.
        if let accessoryStack {
            addSubview(accessoryStack)
            accessoryStack.snp.remakeConstraints { make in
                make.trailing.equalToSuperview()
                make.centerY.equalToSuperview()
                make.top.greaterThanOrEqualToSuperview().inset(verticalPadding)
                make.bottom.lessThanOrEqualToSuperview().inset(verticalPadding)
            }
        }
        
        //Fill the horizontal space between the icon and the accessory; the wrapper keeps accessories hugging ahead of text.
        if let textBlockContainer {
            addSubview(textBlockContainer)
            textBlockContainer.snp.remakeConstraints { make in
                if let iconView {
                    make.leading.equalTo(iconView.snp.trailing).offset(iconTextSpacing)
                } else {
                    make.leading.equalToSuperview()
                }
                if let accessoryStack {
                    make.trailing.equalTo(accessoryStack.snp.leading).offset(-horizontalSpacing)
                } else {
                    make.trailing.equalToSuperview()
                }
                // 无 progress 时垂直约束一并 remake，避免 rebuild 叠加 centerY
                if progressView == nil {
                    make.centerY.equalToSuperview()
                    make.top.greaterThanOrEqualToSuperview().inset(verticalPadding).priority(.low)
                    make.bottom.lessThanOrEqualToSuperview().inset(verticalPadding).priority(.low)
                }
            }
        }
        
        //progress: When set to "leading," it behaves the same as "text"; when set to "interactive," the "trailing" stops at the leading edge of the accessory to avoid overlapping with it.
        if let progressView, let itemProgress {
            addSubview(progressView)
            progressView.snp.remakeConstraints { make in
                if let textBlockContainer {
                    make.leading.equalTo(textBlockContainer.snp.leading)
                } else if let iconView {
                    make.leading.equalTo(iconView.snp.trailing).offset(iconTextSpacing)
                } else {
                    make.leading.equalToSuperview()
                }
                if case .enabled = itemProgress.interaction, let accessoryStack {
                    make.trailing.equalTo(accessoryStack.snp.leading).offset(-horizontalSpacing)
                } else {
                    make.trailing.equalToSuperview()
                }
            }
            progressView.value = itemProgress.value
        }
        
        //MARK: - Vertically centered
        applyVerticalLayout(textBlockContainer: textBlockContainer, progressView: progressView)
    }
    
    ///Vertical centering of text and progress
    private func applyVerticalLayout(textBlockContainer: UIView?, progressView: ASProgressView?) {
        guard textBlockContainer != nil || progressView != nil else { return }
        
        if let progressView {
            //Group "text" and "progress" vertically, centering them as a whole; keep "icon" and accessories centered relative to the entire row.
            let guide = UILayoutGuide()
            addLayoutGuide(guide)
            groupGuide = guide
            
            var constraints: [NSLayoutConstraint] = [
                guide.bottomAnchor.constraint(equalTo: progressView.bottomAnchor),
                guide.centerYAnchor.constraint(equalTo: centerYAnchor),
                guide.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: verticalPadding),
                guide.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -verticalPadding)
            ]
            
            if let textBlockContainer {
                constraints.append(guide.topAnchor.constraint(equalTo: textBlockContainer.topAnchor))
                progressView.snp.makeConstraints { make in
                    make.top.equalTo(textBlockContainer.snp.bottom).offset(textProgressSpacing)
                }
            } else {
                constraints.append(guide.topAnchor.constraint(equalTo: progressView.topAnchor))
            }
            
            NSLayoutConstraint.activate(constraints)
        }
        // 仅 text 的垂直约束已在 layout() 的 textBlockContainer.remakeConstraints 中设置
    }
    
    private func updateActionCallbacks() {
        //Clear the callback events.
        if didActionOccurred == nil {
            func removeLabelActionCallbacks(label: ASLabelView?) {
                label?.didTapLabelView = nil
            }
            iconView?.gestureRecognizers?.filter({ $0 is UITapGestureRecognizer }).forEach({ $0.removeFromView() })
            removeLabelActionCallbacks(label: titlelabel)
            removeLabelActionCallbacks(label: subTitlelabel)
            removeLabelActionCallbacks(label: detaillabel)
            buttonViews.forEach({ $0.didTapButton = nil })
            switchButtons.forEach({ $0.didValueChange = nil; $0.disabledTapAction = nil })
            stepViews.forEach({ $0.didStepChange = nil })
            checkButtons.forEach({ $0.didTapButton = nil })
            radioButtons.forEach({ $0.didTapButton = nil })
            chevronViews.forEach({ $0.didTapButton = nil })
            segmentViews.forEach({ $0.didSelectIndex = nil })
            progressView?.didValueChange = nil
            return
        }
        
        func addLabelActionCallbacks(label: ASLabelView?, style: ASListPage.Cell.Style) {
            label?.didTapLabelView = { [weak self] tapType in
                guard let self else { return }
                switch tapType {
                case .highlight(let highlight):
                    self.didActionOccurred?(style, highlight)
                case .icon(let icon):
                    self.didActionOccurred?(style, icon)
                case .label:
                    self.didActionOccurred?(style, label?.text)
                }
            }
        }
        
        func defaultActionCallbackAllow(_ style: ASListPage.Cell.Style) -> Bool {
            switch style {
            case .icon: return false
            case .title(_, _, _, let enabledInteraction): return enabledInteraction
            case .detail: return false
            case .button: return true
            case .switch: return true
            case .step: return true
            case .check: return false
            case .radio: return false
            case .chevron: return false
            case .progress(let progress):
                if case .enabled = progress.interaction {
                    return true
                }
                return false
            case .segment: return true
            }
        }
        
        var buttonIndex = 0
        var switchIndex = 0
        var stepIndex = 0
        var checkIndex = 0
        var radioIndex = 0
        var chevronIndex = 0
        var segmentIndex = 0
        
        for style in styles {
            if didActionEnable?(style) ?? defaultActionCallbackAllow(style) {
                switch style {
                case .icon:
                    iconView?.addTapGesture { [weak self] gesture in
                        guard let self else { return }
                        self.didActionOccurred?(style, nil)
                    }
                    
                case .title(_, _, _, let enabledInteraction):
                    if enabledInteraction {
                        addLabelActionCallbacks(label: titlelabel, style: style)
                        addLabelActionCallbacks(label: subTitlelabel, style: style)
                    }
                    
                case .detail(_, let enabledInteraction):
                    if enabledInteraction {
                        addLabelActionCallbacks(label: detaillabel, style: style)
                    }
                    
                case .button:
                    if buttonIndex < buttonViews.count {
                        let view = buttonViews[buttonIndex]
                        view.didTapButton = { [weak self] in
                            guard let self else { return }
                            self.didActionOccurred?(style, view.button)
                        }
                    }
                    buttonIndex += 1
                    
                case .switch:
                    if switchIndex < switchButtons.count {
                        let view = switchButtons[switchIndex]
                        view.didValueChange = { [weak self] value in
                            guard let self else { return }
                            var switchValue = style.switchValue!
                            switchValue.state = value ? .on : .off
                            self.didActionOccurred?(ASListPage.Cell.Style.switch(switchValue), value)
                        }
                        
                        view.disabledTapAction = { [weak self] in
                            guard let self else { return }
                            var switchValue = style.switchValue!
                            switchValue.state = .disabled
                            self.didActionOccurred?(ASListPage.Cell.Style.switch(switchValue), nil)
                        }
                    }
                    switchIndex += 1
                    
                case .step:
                    if stepIndex < stepViews.count {
                        let view = stepViews[stepIndex]
                        view.didStepChange = { [weak self] value in
                            guard let self else { return }
                            self.didActionOccurred?(style, value)
                        }
                    }
                    stepIndex += 1
                    
                case .check:
                    if checkIndex < checkButtons.count {
                        let view = checkButtons[checkIndex]
                        view.didTapButton = { [weak self] in
                            guard let self else { return }
                            self.didActionOccurred?(style, view.isSelected)
                        }
                    }
                    checkIndex += 1
                    
                case .radio:
                    if radioIndex < radioButtons.count {
                        let view = radioButtons[radioIndex]
                        view.didTapButton = { [weak self] in
                            guard let self else { return }
                            self.didActionOccurred?(style, view.isSelected)
                        }
                    }
                    radioIndex += 1
                    
                case .chevron:
                    if chevronIndex < chevronViews.count {
                        let view = chevronViews[chevronIndex]
                        view.didTapButton = { [weak self] in
                            guard let self else { return }
                            self.didActionOccurred?(style, view.button)
                        }
                    }
                    chevronIndex += 1
                    
                case .progress(let progress):
                    if case .enabled = progress.interaction {
                        progressView?.didValueChange = { [weak self] value in
                            guard let self else { return }
                            self.didActionOccurred?(style, value)
                        }
                    }
                    
                case .segment:
                    if segmentIndex < segmentViews.count {
                        let view = segmentViews[segmentIndex]
                        view.didSelectIndex = { [weak self] value in
                            guard let self else { return }
                            self.didActionOccurred?(style, value)
                        }
                    }
                    segmentIndex += 1
                }
            }
        }
    }
}
