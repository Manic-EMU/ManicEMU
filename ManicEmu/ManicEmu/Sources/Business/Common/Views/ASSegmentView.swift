//
//  ASSegmentView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/14.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASSegmentView: BaseView {
    
    private let indicatorView = UIView()
    private let containerView = UIStackView()
    private var itemButtons = [ASButtonView]()
    private var isUpdating = false
    
    var segment: ASSegment {
        didSet {
            guard !isUpdating else { return }
            updateFromSegment(oldValue: oldValue)
        }
    }
    
    var index: Int {
        get { segment.index }
        set {
            segment.index = newValue
        }
    }
    
    var didSelectIndex: ((Int) -> Void)? = nil
    
    init(_ segment: ASSegment) {
        self.segment = segment
        super.init(frame: .zero)
        
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        
        clipsToBounds = true
        applySegmentAppearance()
        
        indicatorView.masksToBounds = true
        addSubview(indicatorView)
        
        containerView.axis = .horizontal
        containerView.alignment = .fill
        containerView.distribution = .fillEqually
        containerView.spacing = segment.itemSpacing
        addSubview(containerView)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(segment.contentInsets)
        }
        
        rebuildItems()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        let insets = segment.contentInsets
        guard !itemButtons.isEmpty else {
            return CGSize(width: insets.left + insets.right, height: insets.top + insets.bottom)
        }
        
        var totalWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        for button in itemButtons {
            let size = button.systemLayoutSizeFitting(
                CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric),
                withHorizontalFittingPriority: .fittingSizeLevel,
                verticalFittingPriority: .fittingSizeLevel
            )
            totalWidth += size.width
            maxHeight = max(maxHeight, size.height)
        }
        
        return CGSize(
            width: totalWidth + insets.left + insets.right,
            height: maxHeight + insets.top + insets.bottom
        )
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateViewCornerRadius()
        moveIndicator(to: currentIndex, animated: false)
    }
    
    private var currentIndex: Int {
        guard !itemButtons.isEmpty else { return 0 }
        return min(max(segment.index, 0), itemButtons.count - 1)
    }
    
    private func applySegmentAppearance() {
        backgroundColor = segment.background
        indicatorView.backgroundColor = segment.indicatorBackground
        updateViewCornerRadius()
        updateIndicatorCornerRadius()
    }
    
    private func rebuildItems() {
        containerView.removeAllArrangedSubviews()
        itemButtons.removeAll()
        
        for (index, button) in segment.items.enumerated() {
            let itemView = ASButtonView(button)
            itemView.setContentHuggingPriority(.required, for: .horizontal)
            itemView.setContentCompressionResistancePriority(.required, for: .horizontal)
            itemView.setContentHuggingPriority(.required, for: .vertical)
            itemView.setContentCompressionResistancePriority(.required, for: .vertical)
            
            let itemIndex = index
            itemView.didTapButton = { [weak self] in
                UIDevice.generateHaptic()
                self?.handleItemTap(at: itemIndex)
            }
            
            itemButtons.append(itemView)
            containerView.addArrangedSubview(itemView)
        }
        
        clampIndexIfNeeded()
        indicatorView.isHidden = itemButtons.isEmpty
        
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
    
    private func clampIndexIfNeeded() {
        guard !itemButtons.isEmpty else { return }
        let clamped = currentIndex
        guard segment.index != clamped else { return }
        isUpdating = true
        segment.index = clamped
        isUpdating = false
    }
    
    private func updateFromSegment(oldValue: ASSegment) {
        applySegmentAppearance()
        
        containerView.spacing = segment.itemSpacing
        
        containerView.snp.updateConstraints { make in
            make.edges.equalToSuperview().inset(segment.contentInsets)
        }
        
        if oldValue.items.count != segment.items.count {
            rebuildItems()
            return
        }
        
        clampIndexIfNeeded()
        
        if oldValue.index != segment.index {
            moveIndicator(to: currentIndex, animated: true)
        }
        
        invalidateIntrinsicContentSize()
    }
    
    private func handleItemTap(at index: Int) {
        guard index != segment.index, index < itemButtons.count else { return }
        
        isUpdating = true
        segment.index = index
        isUpdating = false
        
        moveIndicator(to: index, animated: true)
        didSelectIndex?(index)
    }
    
    private func moveIndicator(to index: Int, animated: Bool) {
        guard index >= 0, index < itemButtons.count else {
            indicatorView.isHidden = true
            return
        }
        
        for (itemIndex, itemButton) in itemButtons.enumerated() {
            if itemIndex == index {
                if itemButton.state != .highlight {
                    itemButton.state = .highlight
                }
            } else if itemButton.state != .normal {
                itemButton.state = .normal
            }
        }
        
        indicatorView.isHidden = false
        
        let itemView = itemButtons[index]
        
        let apply = { [weak self] in
            guard let self else { return }
            self.indicatorView.snp.remakeConstraints { make in
                make.leading.trailing.equalTo(itemView)
                make.top.equalToSuperview().inset(self.segment.contentInsets.top)
                make.bottom.equalToSuperview().inset(self.segment.contentInsets.bottom)
            }
            self.updateIndicatorCornerRadius()
        }
        
        if animated {
            apply()
            UIView.springAnimate {
                self.layoutIfNeeded()
            }
        } else {
            apply()
        }
    }
    
    private func updateViewCornerRadius() {
        switch segment.corner {
        case .circle:
            layer.cornerRadius = bounds.height / 2
        case .radius(let cornerRadius):
            layer.cornerRadius = cornerRadius
        }
    }
    
    private func updateIndicatorCornerRadius() {
        switch segment.indicatorCorner {
        case .circle:
            indicatorView.layer.cornerRadius = indicatorView.bounds.height / 2
        case .radius(let cornerRadius):
            indicatorView.layer.cornerRadius = cornerRadius
        }
    }
    
    func setIndex(_ index: Int, callback: Bool) {
        guard segment.items.count > index else { return }
        self.index = index
        if callback {
            didSelectIndex?(index)
        }
    }
}
