//
//  ASIconView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/13.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import Kingfisher

class ASIconView: BaseView {
    
    /// Bitmap UIImageView reports image.size as intrinsic; that must never drive this view's layout.
    private final class FillingImageView: UIImageView {
        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
    }
    
    enum SizeStyle: Equatable {
        case auto
        case fixHeight(CGFloat)
        case fixSize(CGSize)
    }
    
    private let imageView = FillingImageView()
    private var defaultContentSize: CGSize = .zero
    
    var icon: ASIcon? = nil {
        didSet {
            applyIconContent()
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }
    
    /// Declared size policy. `.fixHeight` makes intrinsic width follow height × image aspect.
    var sizeStyle: SizeStyle = .auto {
        didSet {
            guard oldValue != sizeStyle else { return }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }
    
    var animated = false {
        didSet {
            applyAnimated()
        }
    }
    
    
    init(_ icon: ASIcon? = nil) {
        self.icon = icon
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        
        imageView.clipsToBounds = true
        
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        applyIconContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override var intrinsicContentSize: CGSize {
        computedIntrinsicContentSize()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        applyVectorSymbolConfigurationIfNeeded()
        applyCornerStyle()
        applyAnimated()
    }
    
    // MARK: - Intrinsic sizing
    
    var contentAspectRatio: CGFloat {
        guard defaultContentSize.height > .ulpOfOne else { return 1 }
        return defaultContentSize.width / defaultContentSize.height
    }
    
    private func computedIntrinsicContentSize() -> CGSize {
        guard defaultContentSize.width > .ulpOfOne, defaultContentSize.height > .ulpOfOne else {
            return .zero
        }
        
        switch sizeStyle {
        case .auto:
            return defaultContentSize
        case .fixHeight(let height):
            return CGSize(width: height * contentAspectRatio, height: height)
        case .fixSize(let size):
            return size
        }
    }
    
    // MARK: - Layout dimension resolution
    
    /// Laid-out size for symbol pointSize.
    private func resolvedLayoutDimension(_ attribute: NSLayoutConstraint.Attribute) -> CGFloat? {
        switch attribute {
        case .width where bounds.width > .ulpOfOne:
            return bounds.width
        case .height where bounds.height > .ulpOfOne:
            return bounds.height
        default:
            break
        }
        
        switch sizeStyle {
        case .fixHeight(let height) where attribute == .height:
            return height
        case .fixSize(let size) where attribute == .width:
            return size.width
        case .fixSize(let size) where attribute == .height:
            return size.height
        default:
            return nil
        }
    }
    
    // MARK: - Icon content
    
    private func applyIconContent() {
        imageView.contentMode = .scaleAspectFit
        
        guard let icon else {
            imageView.image = nil
            imageView.preferredSymbolConfiguration = nil
            imageView.tintColor = nil
            defaultContentSize = .zero
            return
        }
        
        switch icon {
        case .symbol(let symbol, let weight, let colors, _, _):
            let defaultImage = UIImage(systemSymbol: symbol)
            defaultContentSize = defaultImage.size
            imageView.image = defaultImage
            applySymbolAppearance(weight: weight, colors: colors)
            
        case .symbolImage(let symbolImage, let weight, let colors, _, _):
            let symbolImage = symbolImage ?? R.image.logo_iconSymbols() ?? UIImage(systemSymbol: .photo)
            defaultContentSize = symbolImage.size
            imageView.image = symbolImage
            applySymbolAppearance(weight: weight, colors: colors)
            
        case .image(let image, let color, _):
            let image = image ?? R.image.logo_iconSymbols() ?? UIImage(systemSymbol: .photo)
            imageView.preferredSymbolConfiguration = nil
            imageView.contentMode = .scaleAspectFill
            defaultContentSize = image.size
            if let color {
                imageView.tintColor = color
                imageView.image = image.withRenderingMode(.alwaysTemplate)
            } else {
                imageView.tintColor = nil
                imageView.image = image
            }
            
        case .imageUrl(let url, let processSize, _):
            imageView.preferredSymbolConfiguration = nil
            imageView.tintColor = nil
            imageView.contentMode = .scaleAspectFill
            defaultContentSize = processSize
            imageView.kf.setImage(with: url, options: [.processor(DownsamplingImageProcessor(size: processSize))])
        }
    }
    
    /// Palette must always be applied; otherwise SF Symbols fall back to the window tintColor.
    /// pointSize is optional and only attached when a layout dimension is known.
    private func applySymbolAppearance(weight: UIImage.SymbolWeight, colors: [UIColor], pointSize: CGFloat? = nil) {
        let palette = colors.isEmpty ? [R.Color.LabelPrimary] : colors
        imageView.tintColor = palette[0]
        imageView.preferredSymbolConfiguration = ASIcon.imageConfig(size: pointSize, weight: weight, colors: palette)
    }
    
    private func applyVectorSymbolConfigurationIfNeeded() {
        guard let icon else { return }
        
        let pointSize = resolvedSymbolPointSize()
        switch icon {
        case .symbol(let symbol, let weight, let colors, _, _):
            imageView.image = UIImage(systemSymbol: symbol)
            applySymbolAppearance(weight: weight, colors: colors, pointSize: pointSize)
            
        case .symbolImage(let symbolImage, let weight, let colors, _, _):
            imageView.image = symbolImage
            applySymbolAppearance(weight: weight, colors: colors, pointSize: pointSize)
            
        case .image, .imageUrl:
            break
        }
    }
    
    private func resolvedSymbolPointSize() -> CGFloat? {
        let width = resolvedLayoutDimension(.width)
        let height = resolvedLayoutDimension(.height)
        
        switch (width, height) {
        case let (width?, height?):
            return min(width, height)
        case let (width?, nil):
            let resolvedHeight = width / contentAspectRatio
            return min(width, resolvedHeight)
        case let (nil, height?):
            let resolvedWidth = height * contentAspectRatio
            return min(resolvedWidth, height)
        case (nil, nil):
            return nil
        }
    }
    
    private func applyCornerStyle() {
        guard let icon else { return }
        
        func setCornerStyle(_ cornerStyle: ASCornerStyle) {
            switch cornerStyle {
            case .circle:
                layerCornerRadius = height/2
            case .radius(let cGFloat):
                layerCornerRadius = cGFloat
            }
        }
        
        switch icon {
        case .symbol(_, _, _, let cornerStyle, _):
            setCornerStyle(cornerStyle)
        case .symbolImage(_, _, _, let cornerStyle, _):
            setCornerStyle(cornerStyle)
        case .image(_, _, let cornerStyle):
            setCornerStyle(cornerStyle)
        case .imageUrl(_, _, let cornerStyle):
            setCornerStyle(cornerStyle)
        }
    }
    
    private func applyAnimated() {
        func setAnimated(_ animated: Bool) {
            if animated {
                if #available(iOS 18.0, *) {
                    imageView.addSymbolEffect(.pulse, options: .repeat(.continuous))
                }
            } else {
                if #available(iOS 18.0, *) {
                    imageView.removeSymbolEffect(ofType: .pulse)
                }
            }
        }
        
        switch icon {
        case .symbol(_, _, _, _, let animated):
            setAnimated(animated)
            
        case .symbolImage(_, _, _, _, let animated):
            setAnimated(animated)
            
        default:
            setAnimated(false)
            
        }
        
    }
}
