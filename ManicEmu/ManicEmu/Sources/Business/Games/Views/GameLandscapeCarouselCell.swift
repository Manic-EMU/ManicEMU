//
//  GameLandscapeCarouselCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import CollectionViewPagingLayout

///横屏轮播样式族（Scale / Stack / Snapshot）每种族下还有多种Layout预设
enum LandscapeCarouselStyle: Int, CaseIterable {
    case scale, stack, snapshot
    
    /// Active style family, persisted in Theme extras. Default Scale.
    static var current: LandscapeCarouselStyle {
        get {
            LandscapeCarouselStyle(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.landscapeListStyle.rawValue) ?? 0) ?? .scale
        }
        set {
            Theme.defalut.updateExtra(key: ExtraKey.landscapeListStyle.rawValue, value: newValue.rawValue)
        }
    }
    
    /// Cover-flow carousel when true (default). Sectioned list rows when false.
    static var isCarouselEnabled: Bool {
        get { Theme.defalut.getExtraBool(key: ExtraKey.landscapeCarouselEnabled.rawValue) ?? true }
        set { Theme.defalut.updateExtra(key: ExtraKey.landscapeCarouselEnabled.rawValue, value: newValue) }
    }
    
    var title: String {
        switch self {
        case .scale: return "Scale"
        case .stack: return "Stack"
        case .snapshot: return "Snapshot"
        }
    }
    
    ///当前样式族下选中的Layout展示名
    var layoutTitle: String {
        switch self {
        case .scale: return Self.displayTitle(for: Self.currentScaleLayout.rawValue)
        case .stack: return Self.displayTitle(for: Self.currentStackLayout.rawValue)
        case .snapshot: return Self.displayTitle(for: Self.currentSnapshotLayout.rawValue)
        }
    }
    
    var cellClass: GameLandscapeCarouselCell.Type {
        switch self {
        case .scale: return GameLandscapeScaleCell.self
        case .stack: return GameLandscapeStackCell.self
        case .snapshot: return GameLandscapeSnapshotCell.self
        }
    }
    
    /// Snapshot slices are captured per page and tear if a flick lands mid-transform.
    var usesSystemPaging: Bool { self == .snapshot }
    
    //MARK: Layout selection (each style remembers its last preset)
    
    static var currentScaleLayout: ScaleTransformViewOptions.Layout {
        get {
            if let raw = Theme.defalut.getExtraString(key: selectedLayoutKey(for: .scale)),
               let layout = ScaleTransformViewOptions.Layout(rawValue: raw) {
                return layout
            }
            return .linear
        }
        set {
            Theme.defalut.updateExtra(key: selectedLayoutKey(for: .scale), value: newValue.rawValue)
        }
    }
    
    static var currentStackLayout: StackTransformViewOptions.Layout {
        get {
            if let raw = Theme.defalut.getExtraString(key: selectedLayoutKey(for: .stack)),
               let layout = StackTransformViewOptions.Layout(rawValue: raw) {
                return layout
            }
            return .perspective
        }
        set {
            Theme.defalut.updateExtra(key: selectedLayoutKey(for: .stack), value: newValue.rawValue)
        }
    }
    
    static var currentSnapshotLayout: SnapshotTransformViewOptions.Layout {
        get {
            if let raw = Theme.defalut.getExtraString(key: selectedLayoutKey(for: .snapshot)),
               let layout = SnapshotTransformViewOptions.Layout(rawValue: raw) {
                return layout
            }
            return .fade
        }
        set {
            Theme.defalut.updateExtra(key: selectedLayoutKey(for: .snapshot), value: newValue.rawValue)
        }
    }
    
    private static func selectedLayoutKey(for style: LandscapeCarouselStyle) -> String {
        "landscapeCarousel_selectedLayout_\(style.rawValue)"
    }
    
    ///camelCase rawValue -> "Cover Flow"
    static func displayTitle(for layoutRawValue: String) -> String {
        let spaced = layoutRawValue.unicodeScalars.reduce(into: "") { result, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar), !result.isEmpty {
                result += " "
            }
            result += String(scalar)
        }
        return spaced.capitalized
    }
    
    ///切换到指定样式族+Layout：更新选择、重建出厂options并叠加该Layout的持久化自定义
    static func select(style: LandscapeCarouselStyle, scaleLayout: ScaleTransformViewOptions.Layout? = nil, stackLayout: StackTransformViewOptions.Layout? = nil, snapshotLayout: SnapshotTransformViewOptions.Layout? = nil) {
        current = style
        if let scaleLayout { currentScaleLayout = scaleLayout }
        if let stackLayout { currentStackLayout = stackLayout }
        if let snapshotLayout { currentSnapshotLayout = snapshotLayout }
        activateCurrentLayout()
    }
    
    ///按当前选中的Layout重置Cell静态options，再叠加该Layout已持久化的自定义项
    static func activateCurrentLayout() {
        switch current {
        case .scale:
            GameLandscapeScaleCell.options = .layout(currentScaleLayout)
        case .stack:
            GameLandscapeStackCell.options = .layout(currentStackLayout)
        case .snapshot:
            GameLandscapeSnapshotCell.options = .layout(currentSnapshotLayout)
        }
        current.applyPersistedOptions()
    }
}

///横屏游戏轮播Cell基类
///CollectionViewPagingLayout要求cell铺满collectionView 内容居中放置在子视图上进行transform
class GameLandscapeCarouselCell: UICollectionViewCell {
    
    ///封面下方为聚焦信息面板预留的高度
    static let infoPanelReserve: CGFloat = 132
    
    ///transform目标容器 必须是contentView的第一个子视图
    let cardView = UIView()
    ///复用现有的游戏封面组件（封面加载/圆角/平台侧条装饰）
    let coverView = GameCoverView()
    ///无游戏时的空白卡片
    private let emptyCardView: UIView = {
        let view = UIView()
        view.alpha = 0.7
        view.backgroundColor = R.Color.BackgroundSecondary
        view.clipsToBounds = true
        view.isHidden = true
        return view
    }()
    private let emptyContentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = R.Size.ContentSpaceExtraSmall
        stack.isHidden = true
        return stack
    }()
    private let emptyIconView: ASIconView = {
        ASIconView(.symbol(.plusCircle, colors: [R.Color.LabelSecondary]))
    }()
    private let emptyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = R.Font.Body()
        label.textColor = R.Color.LabelSecondary
        label.textAlignment = .center
        label.text = R.string.localizable.landscapeEmptyAddGame()
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    /// Snapshot 样式的内容标识
    fileprivate(set) var snapshotKey: String = ""

    /// Layout 会改 `cardView.transform`，FocusKit 的 lift 必须落在内部视图上，避免两套 transform 互抢。
    var focusContentView: UIView {
        emptyCardView.isHidden ? coverView : emptyCardView
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        cardView.enableFocusEffects = false
        coverView.enableFocusEffects = false
        emptyCardView.enableFocusEffects = false
        
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            //封面整体上移 底部留给聚焦信息面板
            make.centerY.equalToSuperview().offset(-Self.infoPanelReserve/2)
            make.size.equalTo(100)
        }
        
        cardView.addSubview(coverView)
        coverView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(100)
        }
        
        cardView.addSubview(emptyCardView)
        emptyCardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(100)
        }
        
        emptyCardView.addSubview(emptyContentStack)
        emptyContentStack.addArrangedSubview(emptyIconView)
        emptyContentStack.addArrangedSubview(emptyTitleLabel)
        emptyContentStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceSmall)
        }
        emptyIconView.snp.makeConstraints { make in
            make.size.equalTo(R.Size.IconSizeHuge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(game: Game, cardSize: CGSize) {
        snapshotKey = game.id
        emptyCardView.isHidden = true
        emptyContentStack.isHidden = true
        coverView.isHidden = false
        cardView.snp.updateConstraints { make in
            make.centerY.equalToSuperview().offset(-Self.infoPanelReserve/2)
            make.size.equalTo(cardSize.height)
        }
        coverView.setData(game: game, coverSize: cardSize, style: R.Style.GameCoverStyle)
        coverView.snp.updateConstraints { make in
            if cardSize.height >= cardSize.width {
                make.size.equalTo(cardSize)
            } else {
                let newWidth = cardSize.height
                make.size.equalTo(CGSize(width: newWidth,
                                         height: (newWidth*cardSize.height)/cardSize.width))
            }
        }
    }
    
    func setEmptyPlaceholder(cardSize: CGSize) {
        snapshotKey = "empty"
        coverView.isHidden = true
        emptyCardView.isHidden = false
        emptyContentStack.isHidden = false
        cardView.snp.updateConstraints { make in
            make.centerY.equalToSuperview().offset(-((R.Size.NavigationHeight + R.Size.ContentInsetTop)/2))
            make.size.equalTo(cardSize.height)
        }
        emptyCardView.snp.updateConstraints { make in
            if cardSize.height >= cardSize.width {
                make.size.equalTo(cardSize)
            } else {
                let newWidth = cardSize.height
                make.size.equalTo(CGSize(width: newWidth,
                                         height: (newWidth*cardSize.height)/cardSize.width))
            }
        }
        let style = R.Style.GameCoverStyle
        emptyCardView.layerCornerRadius = R.Style.GameCoverCornerRatio * style.maxCornerRadius(frameHeight: cardSize.height)
    }
}

//MARK: - Scale样式（默认）
class GameLandscapeScaleCell: GameLandscapeCarouselCell, ScaleTransformView {
    ///出厂默认配置
    static let defaultOptions = ScaleTransformViewOptions.layout(.linear)
    
    ///当前生效的配置 用户自定义后持久化于Settings extras
    static var options = defaultOptions
    
    var scaleOptions: ScaleTransformViewOptions { Self.options }
    var scalableView: UIView { cardView }
}

//MARK: - Stack样式
class GameLandscapeStackCell: GameLandscapeCarouselCell, StackTransformView {
    ///出厂默认配置
    static let defaultOptions = StackTransformViewOptions.layout(.perspective)
    
    ///当前生效的配置 用户自定义后持久化于Settings extras
    static var options = defaultOptions
    
    var stackOptions: StackTransformViewOptions { Self.options }
    //StackTransformView所需的cardView由基类同名属性直接满足
}

//MARK: - Snapshot样式
class GameLandscapeSnapshotCell: GameLandscapeCarouselCell, SnapshotTransformView {
    ///出厂默认配置
    static let defaultOptions = SnapshotTransformViewOptions.layout(.fade)
    
    ///当前生效的配置 用户自定义后持久化于Settings extras
    static var options = defaultOptions
    
    var snapshotOptions: SnapshotTransformViewOptions { Self.options }
    var targetView: UIView { cardView }
    ///基于游戏内容的标识 避免复用时快照错乱
    ///切片参数在快照生成时固化 因此附加版本号 配置变化时强制重建快照
    var snapshotIdentifier: String { "\(snapshotKey)_v\(LandscapeCarouselStyle.snapshotOptionsVersion)" }
}

//MARK: - 样式options配置

///配置项分组
struct LandscapeCarouselOptionSection {
    let title: String
    let items: [LandscapeCarouselOptionItem]
}

///轮播样式的可配置项 值通过Settings extras持久化 应用到对应Cell的static options实现实时预览
struct LandscapeCarouselOptionItem {
    ///配置项类型
    enum Kind {
        ///数值 picker选择 滚动实时预览
        case number(values: [Double], defaultValue: Double, decimals: Int, apply: (Double) -> Void)
        ///可空数值 "None"表示不设置
        case optionalNumber(values: [Double], defaultValue: Double?, decimals: Int, apply: (Double?) -> Void)
        ///开关
        case toggle(defaultValue: Bool, apply: (Bool) -> Void)
        ///枚举单选
        case selection(titles: [String], defaultIndex: Int, apply: (Int) -> Void)
    }
    
    ///可空数值持久化时表示nil的占位串
    static let noneValue = "none"
    
    ///持久化key
    let key: String
    let title: String
    let kind: Kind
    
    //MARK: 构造
    
    static func number(_ key: String, _ title: String,
                       from: Double, through: Double, by: Double,
                       defaultValue: Double, decimals: Int = 2,
                       apply: @escaping (Double) -> Void) -> Self {
        .init(key: key, title: title,
              kind: .number(values: makeValues(from: from, through: through, by: by, including: defaultValue),
                            defaultValue: normalize(defaultValue), decimals: decimals, apply: apply))
    }
    
    static func optionalNumber(_ key: String, _ title: String,
                               from: Double, through: Double, by: Double,
                               defaultValue: Double?, decimals: Int = 2,
                               apply: @escaping (Double?) -> Void) -> Self {
        .init(key: key, title: title,
              kind: .optionalNumber(values: makeValues(from: from, through: through, by: by, including: defaultValue),
                                    defaultValue: defaultValue.map { normalize($0) }, decimals: decimals, apply: apply))
    }
    
    static func toggle(_ key: String, _ title: String,
                       defaultValue: Bool,
                       apply: @escaping (Bool) -> Void) -> Self {
        .init(key: key, title: title, kind: .toggle(defaultValue: defaultValue, apply: apply))
    }
    
    static func selection(_ key: String, _ title: String,
                          titles: [String], defaultIndex: Int,
                          apply: @escaping (Int) -> Void) -> Self {
        .init(key: key, title: title, kind: .selection(titles: titles, defaultIndex: defaultIndex, apply: apply))
    }
    
    private static func normalize(_ value: Double) -> Double {
        (value * 10000).rounded() / 10000
    }
    
    ///由范围生成候选值 精度处理并保证默认值一定在候选值中
    private static func makeValues(from: Double, through: Double, by: Double, including defaultValue: Double?) -> [Double] {
        var values = Array(stride(from: from, through: through, by: by)).map { normalize($0) }
        if let defaultValue {
            let normalizedDefault = normalize(defaultValue)
            if !values.contains(where: { abs($0 - normalizedDefault) < 0.00001 }) {
                values.append(normalizedDefault)
                values.sort()
            }
        }
        return values
    }
    
    //MARK: 当前值
    
    var currentNumber: Double {
        guard case .number(_, let defaultValue, _, _) = kind else { return 0 }
        return Settings.defalut.getExtraDouble(key: key) ?? defaultValue
    }
    
    var currentOptionalNumber: Double? {
        guard case .optionalNumber(_, let defaultValue, _, _) = kind else { return nil }
        if let stored = Settings.defalut.getExtraString(key: key) {
            return stored == Self.noneValue ? nil : Double(stored)
        }
        return defaultValue
    }
    
    var currentBool: Bool {
        guard case .toggle(let defaultValue, _) = kind else { return false }
        return Settings.defalut.getExtraBool(key: key) ?? defaultValue
    }
    
    var currentSelectionIndex: Int {
        guard case .selection(_, let defaultIndex, _) = kind else { return 0 }
        return Settings.defalut.getExtraInt(key: key) ?? defaultIndex
    }
    
    ///配置项列表右侧展示的当前值
    var displayValue: String {
        switch kind {
        case .number(_, _, let decimals, _):
            return Self.format(currentNumber, decimals: decimals)
        case .optionalNumber(_, _, let decimals, _):
            if let value = currentOptionalNumber {
                return Self.format(value, decimals: decimals)
            }
            return "None"
        case .toggle:
            return currentBool ? "On" : "Off"
        case .selection(let titles, _, _):
            let index = currentSelectionIndex
            return titles.indices.contains(index) ? titles[index] : ""
        }
    }
    
    static func format(_ value: Double, decimals: Int) -> String {
        decimals == 0 ? "\(Int(value))" : String(format: "%.\(decimals)f", value)
    }
    
    //MARK: Progress（0-1）与number候选值互转
    
    ///当前number值对应的slider进度
    var numberProgress: Float {
        guard case .number(let values, _, _, _) = kind,
              let minValue = values.first, let maxValue = values.last, maxValue > minValue else { return 0 }
        let clamped = Swift.min(Swift.max(currentNumber, minValue), maxValue)
        return Float((clamped - minValue) / (maxValue - minValue))
    }
    
    ///将0-1进度映射到number候选值并吸附最近档位
    func numberValue(fromProgress progress: Float) -> Double? {
        guard case .number(let values, _, _, _) = kind,
              let minValue = values.first, let maxValue = values.last else { return nil }
        let clamped = Double(Swift.min(Swift.max(progress, 0), 1))
        let raw = minValue + clamped * (maxValue - minValue)
        return values.min(by: { abs($0 - raw) < abs($1 - raw) }) ?? raw
    }
    
    ///Progress展示文案：把0-1进度格式化为实际数值
    func numberDisplayFormatter(_ progress: Float) -> String {
        guard case .number(_, _, let decimals, _) = kind,
              let value = numberValue(fromProgress: progress) else { return "" }
        return Self.format(value, decimals: decimals)
    }
    
    //MARK: 更新（持久化并实时应用 与默认值一致时清除持久化记录）
    
    func update(number value: Double) {
        guard case .number(_, let defaultValue, _, let apply) = kind else { return }
        Settings.defalut.updateExtra(key: key, value: abs(value - defaultValue) < 0.00001 ? nil : value)
        apply(value)
    }
    
    func update(optionalNumber value: Double?) {
        guard case .optionalNumber(_, let defaultValue, _, let apply) = kind else { return }
        if value == defaultValue {
            Settings.defalut.updateExtra(key: key, value: nil)
        } else {
            Settings.defalut.updateExtra(key: key, value: value.map { String($0) } ?? Self.noneValue)
        }
        apply(value)
    }
    
    func update(toggle value: Bool) {
        guard case .toggle(let defaultValue, let apply) = kind else { return }
        Settings.defalut.updateExtra(key: key, value: value == defaultValue ? nil : value)
        apply(value)
    }
    
    func update(selection index: Int) {
        guard case .selection(_, let defaultIndex, let apply) = kind else { return }
        Settings.defalut.updateExtra(key: key, value: index == defaultIndex ? nil : index)
        apply(index)
    }
    
    ///启动时应用持久化的自定义值
    ///注意3D等含"Enabled"开关的分组依赖数组顺序：开关项在前先创建子结构 数值项在后依次覆盖
    func applyPersisted() {
        switch kind {
        case .number(_, _, _, let apply):
            if let value = Settings.defalut.getExtraDouble(key: key) {
                apply(value)
            }
        case .optionalNumber(_, _, _, let apply):
            if let stored = Settings.defalut.getExtraString(key: key) {
                apply(stored == Self.noneValue ? nil : Double(stored))
            }
        case .toggle(_, let apply):
            if let value = Settings.defalut.getExtraBool(key: key) {
                apply(value)
            }
        case .selection(_, _, let apply):
            if let index = Settings.defalut.getExtraInt(key: key) {
                apply(index)
            }
        }
    }
    
    ///仅清除持久化记录（不改写当前options 由activateCurrentLayout统一重建）
    func clearPersisted() {
        Settings.defalut.updateExtra(key: key, value: nil)
    }
    
    ///恢复默认值
    func reset() {
        clearPersisted()
        switch kind {
        case .number(_, let defaultValue, _, let apply):
            apply(defaultValue)
        case .optionalNumber(_, let defaultValue, _, let apply):
            apply(defaultValue)
        case .toggle(let defaultValue, let apply):
            apply(defaultValue)
        case .selection(_, let defaultIndex, let apply):
            apply(defaultIndex)
        }
    }
}


extension LandscapeCarouselStyle {
    ///Snapshot的切片在快照生成时固化 配置变化后提升版本号强制重建
    static var snapshotOptionsVersion = 0
    
    //MARK: 枚举选项映射
    
    static let curveTitles = ["Linear", "Ease In", "Ease Out"]
    
    static func curve(at index: Int) -> TransformCurve {
        switch index {
        case 1: return .easeIn
        case 2: return .easeOut
        default: return .linear
        }
    }
    
    static func curveIndex(_ curve: TransformCurve) -> Int {
        switch curve {
        case .easeIn: return 1
        case .easeOut: return 2
        case .linear: return 0
        }
    }
    
    static let blurStyleTitles = ["Extra Light", "Light", "Dark"]
    
    static func blurStyle(at index: Int) -> UIBlurEffect.Style {
        switch index {
        case 0: return .extraLight
        case 2: return .dark
        default: return .light
        }
    }
    
    static func blurStyleIndex(_ style: UIBlurEffect.Style) -> Int {
        switch style {
        case .extraLight: return 0
        case .dark: return 2
        default: return 1
        }
    }
    
    ///Rotation 3D开启时的兜底配置（Layout未提供时使用）
    static let defaultRotation3d = ScaleTransformViewOptions.Rotation3dOptions(
        angle: .pi / 3, minAngle: 0, maxAngle: .pi, x: 0, y: 1, z: 0, m34: -0.0001
    )
    
    ///Translation 3D开启时的兜底配置（Layout未提供时使用）
    static let defaultTranslation3d = ScaleTransformViewOptions.Translation3dOptions(
        translateRatios: (0.1, 0, 0),
        minTranslateRatios: (-0.05, 0, 0.86),
        maxTranslateRatios: (0.05, 0, -0.86)
    )
    
    ///当前选中Layout可供配置的options（默认值取自该Layout出厂配置 key按Layout隔离）
    var optionSections: [LandscapeCarouselOptionSection] {
        switch self {
        case .scale: return Self.scaleSections(layout: Self.currentScaleLayout)
        case .stack: return Self.stackSections(layout: Self.currentStackLayout)
        case .snapshot: return Self.snapshotSections(layout: Self.currentSnapshotLayout)
        }
    }
    
    //MARK: Scale配置
    
    private static func scaleSections(layout: ScaleTransformViewOptions.Layout) -> [LandscapeCarouselOptionSection] {
        let defaults = ScaleTransformViewOptions.layout(layout)
        let key: (String) -> String = { "landscapeCarousel_scale_\(layout.rawValue)_\($0)" }
        let rotationFallback = defaults.rotation3d ?? defaultRotation3d
        let translationFallback = defaults.translation3d ?? defaultTranslation3d
        
        let general: [LandscapeCarouselOptionItem] = [
            .number(key("minScale"), "Min Scale",
                    from: 0, through: 2, by: 0.02, defaultValue: defaults.minScale) {
                GameLandscapeScaleCell.options.minScale = $0
            },
            .number(key("maxScale"), "Max Scale",
                    from: 0, through: 2, by: 0.02, defaultValue: defaults.maxScale) {
                GameLandscapeScaleCell.options.maxScale = $0
            },
            .number(key("scaleRatio"), "Scale Ratio",
                    from: 0, through: 2, by: 0.02, defaultValue: defaults.scaleRatio) {
                GameLandscapeScaleCell.options.scaleRatio = $0
            },
            .number(key("translationX"), "Translation X",
                    from: -2, through: 2, by: 0.02, defaultValue: defaults.translationRatio.x) {
                GameLandscapeScaleCell.options.translationRatio.x = $0
            },
            .number(key("translationY"), "Translation Y",
                    from: -2, through: 2, by: 0.02, defaultValue: defaults.translationRatio.y) {
                GameLandscapeScaleCell.options.translationRatio.y = $0
            },
            .number(key("minTranslationX"), "Min Translation X",
                    from: -5, through: 5, by: 0.25, defaultValue: Double(defaults.minTranslationRatio?.x ?? -5)) {
                var point = GameLandscapeScaleCell.options.minTranslationRatio ?? .zero
                point.x = $0
                GameLandscapeScaleCell.options.minTranslationRatio = point
            },
            .number(key("minTranslationY"), "Min Translation Y",
                    from: -5, through: 5, by: 0.25, defaultValue: Double(defaults.minTranslationRatio?.y ?? -5)) {
                var point = GameLandscapeScaleCell.options.minTranslationRatio ?? .zero
                point.y = $0
                GameLandscapeScaleCell.options.minTranslationRatio = point
            },
            .number(key("maxTranslationX"), "Max Translation X",
                    from: -5, through: 5, by: 0.25, defaultValue: Double(defaults.maxTranslationRatio?.x ?? 5)) {
                var point = GameLandscapeScaleCell.options.maxTranslationRatio ?? .zero
                point.x = $0
                GameLandscapeScaleCell.options.maxTranslationRatio = point
            },
            .number(key("maxTranslationY"), "Max Translation Y",
                    from: -5, through: 5, by: 0.25, defaultValue: Double(defaults.maxTranslationRatio?.y ?? 5)) {
                var point = GameLandscapeScaleCell.options.maxTranslationRatio ?? .zero
                point.y = $0
                GameLandscapeScaleCell.options.maxTranslationRatio = point
            },
            .toggle(key("keepVSpacing"), "Keep Vertical Spacing Equal",
                    defaultValue: defaults.keepVerticalSpacingEqual) {
                GameLandscapeScaleCell.options.keepVerticalSpacingEqual = $0
            },
            .toggle(key("keepHSpacing"), "Keep Horizontal Spacing Equal",
                    defaultValue: defaults.keepHorizontalSpacingEqual) {
                GameLandscapeScaleCell.options.keepHorizontalSpacingEqual = $0
            },
            .selection(key("scaleCurve"), "Scale Curve",
                       titles: curveTitles, defaultIndex: curveIndex(defaults.scaleCurve)) {
                GameLandscapeScaleCell.options.scaleCurve = curve(at: $0)
            },
            .selection(key("translationCurve"), "Translation Curve",
                       titles: curveTitles, defaultIndex: curveIndex(defaults.translationCurve)) {
                GameLandscapeScaleCell.options.translationCurve = curve(at: $0)
            },
            .toggle(key("shadowEnabled"), "Shadow Enabled",
                    defaultValue: defaults.shadowEnabled) {
                GameLandscapeScaleCell.options.shadowEnabled = $0
            },
            .number(key("shadowOpacity"), "Shadow Opacity",
                    from: 0, through: 1, by: 0.05, defaultValue: Double(defaults.shadowOpacity)) {
                GameLandscapeScaleCell.options.shadowOpacity = Float($0)
            },
            .number(key("shadowOpacityMin"), "Shadow Opacity Min",
                    from: 0, through: 1, by: 0.05, defaultValue: Double(defaults.shadowOpacityMin)) {
                GameLandscapeScaleCell.options.shadowOpacityMin = Float($0)
            },
            .number(key("shadowOpacityMax"), "Shadow Opacity Max",
                    from: 0, through: 1, by: 0.05, defaultValue: Double(defaults.shadowOpacityMax)) {
                GameLandscapeScaleCell.options.shadowOpacityMax = Float($0)
            },
            .number(key("shadowRadiusMin"), "Shadow Radius Min",
                    from: 0, through: 15, by: 0.5, defaultValue: defaults.shadowRadiusMin, decimals: 1) {
                GameLandscapeScaleCell.options.shadowRadiusMin = $0
            },
            .number(key("shadowRadiusMax"), "Shadow Radius Max",
                    from: 0, through: 15, by: 0.5, defaultValue: defaults.shadowRadiusMax, decimals: 1) {
                GameLandscapeScaleCell.options.shadowRadiusMax = $0
            },
            .number(key("shadowOffsetMinX"), "Shadow Offset Min X",
                    from: -7, through: 7, by: 0.5, defaultValue: defaults.shadowOffsetMin.width, decimals: 1) {
                GameLandscapeScaleCell.options.shadowOffsetMin.width = $0
            },
            .number(key("shadowOffsetMinY"), "Shadow Offset Min Y",
                    from: -7, through: 7, by: 0.5, defaultValue: defaults.shadowOffsetMin.height, decimals: 1) {
                GameLandscapeScaleCell.options.shadowOffsetMin.height = $0
            },
            .number(key("shadowOffsetMaxX"), "Shadow Offset Max X",
                    from: -7, through: 7, by: 0.5, defaultValue: defaults.shadowOffsetMax.width, decimals: 1) {
                GameLandscapeScaleCell.options.shadowOffsetMax.width = $0
            },
            .number(key("shadowOffsetMaxY"), "Shadow Offset Max Y",
                    from: -7, through: 7, by: 0.5, defaultValue: defaults.shadowOffsetMax.height, decimals: 1) {
                GameLandscapeScaleCell.options.shadowOffsetMax.height = $0
            },
            .toggle(key("blurEnabled"), "Blur Effect Enabled",
                    defaultValue: defaults.blurEffectEnabled) {
                GameLandscapeScaleCell.options.blurEffectEnabled = $0
            },
            .number(key("blurRadiusRatio"), "Blur Effect Radius Ratio",
                    from: 0, through: 1, by: 0.05, defaultValue: defaults.blurEffectRadiusRatio) {
                GameLandscapeScaleCell.options.blurEffectRadiusRatio = $0
            },
            .selection(key("blurStyle"), "Blur Effect Style",
                       titles: blurStyleTitles, defaultIndex: blurStyleIndex(defaults.blurEffectStyle)) {
                GameLandscapeScaleCell.options.blurEffectStyle = blurStyle(at: $0)
            }
        ]
        
        //Enabled开关须放在首位 applyPersisted按顺序先创建子结构再覆盖数值
        let rotation3d: [LandscapeCarouselOptionItem] = [
            .toggle(key("rot3dEnabled"), "Enabled", defaultValue: defaults.rotation3d != nil) {
                GameLandscapeScaleCell.options.rotation3d = $0 ? rotationFallback : nil
            },
            .number(key("rot3dAngle"), "Angle",
                    from: -3.15, through: 3.15, by: 0.05, defaultValue: rotationFallback.angle) {
                GameLandscapeScaleCell.options.rotation3d?.angle = $0
            },
            .number(key("rot3dMinAngle"), "Min Angle",
                    from: -3.15, through: 3.15, by: 0.05, defaultValue: rotationFallback.minAngle) {
                GameLandscapeScaleCell.options.rotation3d?.minAngle = $0
            },
            .number(key("rot3dMaxAngle"), "Max Angle",
                    from: -3.15, through: 3.15, by: 0.05, defaultValue: rotationFallback.maxAngle) {
                GameLandscapeScaleCell.options.rotation3d?.maxAngle = $0
            },
            .number(key("rot3dX"), "Axis X",
                    from: -1, through: 1, by: 0.1, defaultValue: rotationFallback.x, decimals: 1) {
                GameLandscapeScaleCell.options.rotation3d?.x = $0
            },
            .number(key("rot3dY"), "Axis Y",
                    from: -1, through: 1, by: 0.1, defaultValue: rotationFallback.y, decimals: 1) {
                GameLandscapeScaleCell.options.rotation3d?.y = $0
            },
            .number(key("rot3dZ"), "Axis Z",
                    from: -1, through: 1, by: 0.1, defaultValue: rotationFallback.z, decimals: 1) {
                GameLandscapeScaleCell.options.rotation3d?.z = $0
            },
            .number(key("rot3dM34"), "m34 (x1000)",
                    from: -2, through: 2, by: 0.1, defaultValue: rotationFallback.m34 * 1000, decimals: 1) {
                GameLandscapeScaleCell.options.rotation3d?.m34 = $0 / 1000
            }
        ]
        
        let translation3d: [LandscapeCarouselOptionItem] = [
            .toggle(key("trans3dEnabled"), "Enabled", defaultValue: defaults.translation3d != nil) {
                GameLandscapeScaleCell.options.translation3d = $0 ? translationFallback : nil
            },
            .number(key("trans3dX"), "X Ratio",
                    from: -5, through: 5, by: 0.05, defaultValue: translationFallback.translateRatios.0) { value in
                if let current = GameLandscapeScaleCell.options.translation3d?.translateRatios {
                    GameLandscapeScaleCell.options.translation3d?.translateRatios = (value, current.1, current.2)
                }
            },
            .number(key("trans3dY"), "Y Ratio",
                    from: -5, through: 5, by: 0.05, defaultValue: translationFallback.translateRatios.1) { value in
                if let current = GameLandscapeScaleCell.options.translation3d?.translateRatios {
                    GameLandscapeScaleCell.options.translation3d?.translateRatios = (current.0, value, current.2)
                }
            },
            .number(key("trans3dZ"), "Z Ratio",
                    from: -5, through: 5, by: 0.05, defaultValue: translationFallback.translateRatios.2) { value in
                if let current = GameLandscapeScaleCell.options.translation3d?.translateRatios {
                    GameLandscapeScaleCell.options.translation3d?.translateRatios = (current.0, current.1, value)
                }
            },
            .number(key("trans3dMinX"), "X Min Ratio",
                    from: -10, through: 10, by: 0.1, defaultValue: translationFallback.minTranslateRatios.0) { value in
                if let current = GameLandscapeScaleCell.options.translation3d?.minTranslateRatios {
                    GameLandscapeScaleCell.options.translation3d?.minTranslateRatios = (value, current.1, current.2)
                }
            },
            .number(key("trans3dMinY"), "Y Min Ratio",
                    from: -10, through: 10, by: 0.1, defaultValue: translationFallback.minTranslateRatios.1) { value in
                if let current = GameLandscapeScaleCell.options.translation3d?.minTranslateRatios {
                    GameLandscapeScaleCell.options.translation3d?.minTranslateRatios = (current.0, value, current.2)
                }
            },
            .number(key("trans3dMinZ"), "Z Min Ratio",
                    from: -10, through: 10, by: 0.1, defaultValue: translationFallback.minTranslateRatios.2) { value in
                if let current = GameLandscapeScaleCell.options.translation3d?.minTranslateRatios {
                    GameLandscapeScaleCell.options.translation3d?.minTranslateRatios = (current.0, current.1, value)
                }
            },
            .number(key("trans3dMaxX"), "X Max Ratio",
                    from: -10, through: 10, by: 0.1, defaultValue: translationFallback.maxTranslateRatios.0) { value in
                if let current = GameLandscapeScaleCell.options.translation3d?.maxTranslateRatios {
                    GameLandscapeScaleCell.options.translation3d?.maxTranslateRatios = (value, current.1, current.2)
                }
            },
            .number(key("trans3dMaxY"), "Y Max Ratio",
                    from: -10, through: 10, by: 0.1, defaultValue: translationFallback.maxTranslateRatios.1) { value in
                if let current = GameLandscapeScaleCell.options.translation3d?.maxTranslateRatios {
                    GameLandscapeScaleCell.options.translation3d?.maxTranslateRatios = (current.0, value, current.2)
                }
            },
            .number(key("trans3dMaxZ"), "Z Max Ratio",
                    from: -10, through: 10, by: 0.1, defaultValue: translationFallback.maxTranslateRatios.2) { value in
                if let current = GameLandscapeScaleCell.options.translation3d?.maxTranslateRatios {
                    GameLandscapeScaleCell.options.translation3d?.maxTranslateRatios = (current.0, current.1, value)
                }
            }
        ]
        
        return [
            .init(title: "Scale Options", items: general),
            .init(title: "Rotation 3D", items: rotation3d),
            .init(title: "Translation 3D", items: translation3d)
        ]
    }
    
    //MARK: Stack配置
    
    private static func stackSections(layout: StackTransformViewOptions.Layout) -> [LandscapeCarouselOptionSection] {
        let defaults = StackTransformViewOptions.layout(layout)
        let key: (String) -> String = { "landscapeCarousel_stack_\(layout.rawValue)_\($0)" }
        
        let items: [LandscapeCarouselOptionItem] = [
            .number(key("scaleFactor"), "Scale Factor",
                    from: -1, through: 1, by: 0.02, defaultValue: defaults.scaleFactor) {
                GameLandscapeStackCell.options.scaleFactor = $0
            },
            .optionalNumber(key("minScale"), "Min Scale",
                            from: 0, through: 2, by: 0.05, defaultValue: defaults.minScale.map { Double($0) }) {
                GameLandscapeStackCell.options.minScale = $0.map { CGFloat($0) }
            },
            .optionalNumber(key("maxScale"), "Max Scale",
                            from: 0, through: 2, by: 0.05, defaultValue: defaults.maxScale.map { Double($0) }) {
                GameLandscapeStackCell.options.maxScale = $0.map { CGFloat($0) }
            },
            .number(key("maxStackSize"), "Max Stack Size",
                    from: 2, through: 10, by: 1, defaultValue: Double(defaults.maxStackSize), decimals: 0) {
                GameLandscapeStackCell.options.maxStackSize = Int($0)
            },
            .number(key("spacingFactor"), "Spacing Factor",
                    from: 0, through: 0.5, by: 0.01, defaultValue: defaults.spacingFactor) {
                GameLandscapeStackCell.options.spacingFactor = $0
            },
            .optionalNumber(key("maxSpacing"), "Max Spacing",
                            from: 0, through: 1, by: 0.05, defaultValue: defaults.maxSpacing.map { Double($0) }) {
                GameLandscapeStackCell.options.maxSpacing = $0.map { CGFloat($0) }
            },
            .number(key("alphaFactor"), "Alpha Factor",
                    from: 0, through: 1, by: 0.05, defaultValue: defaults.alphaFactor) {
                GameLandscapeStackCell.options.alphaFactor = $0
            },
            .number(key("bottomAlphaSpeed"), "Bottom Stack Alpha Speed",
                    from: 0, through: 10, by: 0.1, defaultValue: defaults.bottomStackAlphaSpeedFactor, decimals: 1) {
                GameLandscapeStackCell.options.bottomStackAlphaSpeedFactor = $0
            },
            .number(key("topAlphaSpeed"), "Top Stack Alpha Speed",
                    from: 0, through: 10, by: 0.1, defaultValue: defaults.topStackAlphaSpeedFactor, decimals: 1) {
                GameLandscapeStackCell.options.topStackAlphaSpeedFactor = $0
            },
            .number(key("perspectiveRatio"), "Perspective Ratio",
                    from: -1, through: 1, by: 0.05, defaultValue: defaults.perspectiveRatio) {
                GameLandscapeStackCell.options.perspectiveRatio = $0
            },
            .toggle(key("shadowEnabled"), "Shadow Enabled",
                    defaultValue: defaults.shadowEnabled) {
                GameLandscapeStackCell.options.shadowEnabled = $0
            },
            .number(key("shadowOpacity"), "Shadow Opacity",
                    from: 0, through: 1, by: 0.05, defaultValue: Double(defaults.shadowOpacity)) {
                GameLandscapeStackCell.options.shadowOpacity = Float($0)
            },
            .number(key("shadowOffsetX"), "Shadow Offset X",
                    from: -7, through: 7, by: 0.5, defaultValue: defaults.shadowOffset.width, decimals: 1) {
                GameLandscapeStackCell.options.shadowOffset.width = $0
            },
            .number(key("shadowOffsetY"), "Shadow Offset Y",
                    from: -7, through: 7, by: 0.5, defaultValue: defaults.shadowOffset.height, decimals: 1) {
                GameLandscapeStackCell.options.shadowOffset.height = $0
            },
            .number(key("shadowRadius"), "Shadow Radius",
                    from: 0, through: 10, by: 0.5, defaultValue: defaults.shadowRadius, decimals: 1) {
                GameLandscapeStackCell.options.shadowRadius = $0
            },
            .number(key("rotateAngle"), "Stack Rotate Angle",
                    from: -3.15, through: 3.15, by: 0.05, defaultValue: defaults.stackRotateAngel) {
                GameLandscapeStackCell.options.stackRotateAngel = $0
            },
            .number(key("popAngle"), "Pop Angle",
                    from: -3.15, through: 3.15, by: 0.05, defaultValue: defaults.popAngle) {
                GameLandscapeStackCell.options.popAngle = $0
            },
            .number(key("popOffsetW"), "Pop Offset W",
                    from: -2, through: 2, by: 0.05, defaultValue: defaults.popOffsetRatio.width) {
                GameLandscapeStackCell.options.popOffsetRatio.width = $0
            },
            .number(key("popOffsetH"), "Pop Offset H",
                    from: -2, through: 2, by: 0.05, defaultValue: defaults.popOffsetRatio.height) {
                GameLandscapeStackCell.options.popOffsetRatio.height = $0
            },
            .number(key("positionX"), "Stack Position X",
                    from: -1, through: 1, by: 0.05, defaultValue: defaults.stackPosition.x) {
                GameLandscapeStackCell.options.stackPosition.x = $0
            },
            .number(key("positionY"), "Stack Position Y",
                    from: -1, through: 1, by: 0.05, defaultValue: defaults.stackPosition.y) {
                GameLandscapeStackCell.options.stackPosition.y = $0
            },
            .toggle(key("reverse"), "Reverse",
                    defaultValue: defaults.reverse) {
                GameLandscapeStackCell.options.reverse = $0
            },
            .toggle(key("blurEnabled"), "Blur Effect Enabled",
                    defaultValue: defaults.blurEffectEnabled) {
                GameLandscapeStackCell.options.blurEffectEnabled = $0
            },
            .number(key("maxBlurRadius"), "Max Blur Radius",
                    from: 0, through: 1, by: 0.02, defaultValue: defaults.maxBlurEffectRadius) {
                GameLandscapeStackCell.options.maxBlurEffectRadius = $0
            },
            .selection(key("blurStyle"), "Blur Effect Style",
                       titles: blurStyleTitles, defaultIndex: blurStyleIndex(defaults.blurEffectStyle)) {
                GameLandscapeStackCell.options.blurEffectStyle = blurStyle(at: $0)
            }
        ]
        
        return [.init(title: "Stack Options", items: items)]
    }
    
    //MARK: Snapshot配置
    
    private static func snapshotSections(layout: SnapshotTransformViewOptions.Layout) -> [LandscapeCarouselOptionSection] {
        let defaults = SnapshotTransformViewOptions.layout(layout)
        let key: (String) -> String = { "landscapeCarousel_snapshot_\(layout.rawValue)_\($0)" }
        //PiecesValue无法读回具体数值 以下默认值取自各Layout源码中的典型标量
        let piecesDefaults = snapshotPiecesDefaults(for: layout)
        
        let items: [LandscapeCarouselOptionItem] = [
            .number(key("pieceWidthRatio"), "Piece Width Ratio",
                    from: 0.05, through: 1, by: 0.05, defaultValue: defaults.pieceSizeRatio.width) {
                GameLandscapeSnapshotCell.options.pieceSizeRatio.width = $0
            },
            .number(key("pieceHeightRatio"), "Piece Height Ratio",
                    from: 0.02, through: 0.5, by: 0.02, defaultValue: defaults.pieceSizeRatio.height) {
                GameLandscapeSnapshotCell.options.pieceSizeRatio.height = $0
            },
            .number(key("piecesCornerRadius"), "Pieces Corner Radius",
                    from: 0, through: 1.5, by: 0.05, defaultValue: piecesDefaults.cornerRadius) {
                GameLandscapeSnapshotCell.options.piecesCornerRadiusRatio = .static($0)
            },
            .number(key("piecesAlphaRatio"), "Pieces Alpha Ratio",
                    from: 0, through: 1, by: 0.05, defaultValue: piecesDefaults.alpha) {
                GameLandscapeSnapshotCell.options.piecesAlphaRatio = .rowBased($0)
            },
            .number(key("piecesTranslationY"), "Pieces Translation Y",
                    from: 0, through: 1, by: 0.05, defaultValue: piecesDefaults.translationY) {
                GameLandscapeSnapshotCell.options.piecesTranslationRatio = .rowBasedMirror(CGPoint(x: 0, y: $0))
            },
            .number(key("piecesScaleW"), "Pieces Scale W",
                    from: 0, through: 1, by: 0.05, defaultValue: piecesDefaults.scaleW) { value in
                let height = Settings.defalut.getExtraDouble(key: key("piecesScaleH")) ?? piecesDefaults.scaleH
                GameLandscapeSnapshotCell.options.piecesScaleRatio = .rowBasedMirror(CGSize(width: value, height: height))
            },
            .number(key("piecesScaleH"), "Pieces Scale H",
                    from: 0, through: 1, by: 0.05, defaultValue: piecesDefaults.scaleH) { value in
                let width = Settings.defalut.getExtraDouble(key: key("piecesScaleW")) ?? piecesDefaults.scaleW
                GameLandscapeSnapshotCell.options.piecesScaleRatio = .rowBasedMirror(CGSize(width: width, height: value))
            },
            .number(key("containerScaleRatio"), "Container Scale Ratio",
                    from: 0, through: 1, by: 0.05, defaultValue: defaults.containerScaleRatio) {
                GameLandscapeSnapshotCell.options.containerScaleRatio = $0
            },
            .number(key("containerTranslationX"), "Container Translation X",
                    from: 0, through: 3, by: 0.1, defaultValue: defaults.containerTranslationRatio.x, decimals: 1) {
                GameLandscapeSnapshotCell.options.containerTranslationRatio.x = $0
            },
            .number(key("containerTranslationY"), "Container Translation Y",
                    from: 0, through: 2, by: 0.1, defaultValue: defaults.containerTranslationRatio.y, decimals: 1) {
                GameLandscapeSnapshotCell.options.containerTranslationRatio.y = $0
            },
            .optionalNumber(key("containerMinTranslationX"), "Container Min Translation X",
                            from: 0, through: 2, by: 0.1,
                            defaultValue: defaults.containerMinTranslationRatio.map { Double($0.x) }, decimals: 1) { value in
                if let value {
                    var point = GameLandscapeSnapshotCell.options.containerMinTranslationRatio ?? .zero
                    point.x = value
                    GameLandscapeSnapshotCell.options.containerMinTranslationRatio = point
                } else {
                    GameLandscapeSnapshotCell.options.containerMinTranslationRatio = nil
                }
            },
            .optionalNumber(key("containerMinTranslationY"), "Container Min Translation Y",
                            from: 0, through: 2, by: 0.1,
                            defaultValue: defaults.containerMinTranslationRatio.map { Double($0.y) }, decimals: 1) { value in
                if let value {
                    var point = GameLandscapeSnapshotCell.options.containerMinTranslationRatio ?? .zero
                    point.y = value
                    GameLandscapeSnapshotCell.options.containerMinTranslationRatio = point
                } else {
                    GameLandscapeSnapshotCell.options.containerMinTranslationRatio = nil
                }
            },
            .optionalNumber(key("containerMaxTranslationX"), "Container Max Translation X",
                            from: 0, through: 2, by: 0.1,
                            defaultValue: defaults.containerMaxTranslationRatio.map { Double($0.x) }, decimals: 1) { value in
                if let value {
                    var point = GameLandscapeSnapshotCell.options.containerMaxTranslationRatio ?? .zero
                    point.x = value
                    GameLandscapeSnapshotCell.options.containerMaxTranslationRatio = point
                } else {
                    GameLandscapeSnapshotCell.options.containerMaxTranslationRatio = nil
                }
            },
            .optionalNumber(key("containerMaxTranslationY"), "Container Max Translation Y",
                            from: 0, through: 2, by: 0.1,
                            defaultValue: defaults.containerMaxTranslationRatio.map { Double($0.y) }, decimals: 1) { value in
                if let value {
                    var point = GameLandscapeSnapshotCell.options.containerMaxTranslationRatio ?? .zero
                    point.y = value
                    GameLandscapeSnapshotCell.options.containerMaxTranslationRatio = point
                } else {
                    GameLandscapeSnapshotCell.options.containerMaxTranslationRatio = nil
                }
            }
        ]
        
        return [.init(title: "Snapshot Options", items: items)]
    }
    
    ///Snapshot的PiecesValue无法读回 按Layout给出编辑用的标量默认值
    private static func snapshotPiecesDefaults(for layout: SnapshotTransformViewOptions.Layout) -> (cornerRadius: Double, alpha: Double, translationY: Double, scaleW: Double, scaleH: Double) {
        switch layout {
        case .grid: return (1, 0, 1.8, 0.8, 0.8)
        case .space: return (0.7, 0.2, 1, 0.5, 0.5)
        case .chess: return (0.5, 0.4, 1, 0.5, 0.5)
        case .tiles: return (0, 0.4, 0, 0, 0.1)
        case .lines: return (0, 0.4, 0, 0.6, 0.96)
        case .bars: return (1.2, 0.4, 0.1, 0.2, 0.6)
        case .puzzle: return (0, 0.2, 0.15, 0.1, 0.4)
        case .fade: return (0.1, 0.1, 0.1, 0.05, 0.1)
        }
    }
    
    //MARK: 持久化
    
    ///启动时按当前选中的Layout激活options并叠加持久化自定义
    static func applyPersistedOptions() {
        activateCurrentLayout()
    }
    
    ///应用当前Layout持久化的自定义options
    ///也用于3D等"Enabled"开关重新开启后 把持久化的子项数值重新覆盖到新建的子结构上
    func applyPersistedOptions() {
        optionSections.forEach { section in
            section.items.forEach { $0.applyPersisted() }
        }
    }
    
    ///恢复当前Layout的出厂配置 并清除该Layout在Settings extras中的持久化记录
    func resetOptions() {
        optionSections.forEach { section in
            section.items.forEach { $0.clearPersisted() }
        }
        Self.activateCurrentLayout()
    }
}
