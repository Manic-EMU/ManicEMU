//
//  ASIcon.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

enum ASIcon {
    case symbol(SFSymbol,
                weight: UIImage.SymbolWeight = .regular,
                colors: [UIColor] = [R.Color.LabelPrimary],
                cornerStyle: ASCornerStyle = .radius(0),
                animated: Bool = false)
    
    case symbolImage(UIImage?,
                     weight: UIImage.SymbolWeight = .semibold,
                     colors: [UIColor] = [R.Color.LabelPrimary],
                     cornerStyle: ASCornerStyle = .radius(0),
                     animated: Bool = false)
    
    case image(UIImage?,
               color: UIColor? = nil,
               cornerStyle: ASCornerStyle = .radius(0))
    
    case imageUrl(URL,
                  processSize: CGSize = R.Size.IconSizeHuge,
                  cornerStyle: ASCornerStyle = .radius(0))
    
    ///Pass in a size to quickly generate an image.
    func image(size: CGFloat) -> UIImage {
        switch self {
        case .symbol(let symbol, let weight, let colors, _, _):
            let configs = Self.imageConfig(size: size, weight: weight, colors: colors)
            return UIImage(systemSymbol: symbol,
                           withConfiguration: configs)
            
        case .symbolImage(let symbolImage, weight: let weight, let colors, _, _):
            let symbolImage = symbolImage ?? R.image.logo_iconSymbols() ?? UIImage(systemSymbol: .photo)
            let configs = Self.imageConfig(size: size, weight: weight, colors: colors)
            let symbolImageWithConfigs = symbolImage.applyingSymbolConfiguration(configs)
            return symbolImageWithConfigs ?? symbolImage
            
        case .image(let image, let color, _):
            let image = image ?? R.image.logo_iconSymbols() ?? UIImage(systemSymbol: .photo)
            var scaledImage: UIImage? = nil
            let imageSize = image.size
            if imageSize.width > imageSize.height {
                scaledImage = image.scaled(toWidth: size)
            } else if imageSize.height > imageSize.width {
                scaledImage = image.scaled(toHeight: size)
            } else if imageSize.width != size {
                scaledImage = image.scaled(toWidth: size)
            } else {
                scaledImage = image
            }
            if let _ = color {
                scaledImage = scaledImage?.withRenderingMode(.alwaysTemplate)
                
            }
            return scaledImage ?? image
            
        case .imageUrl(_, _, _):
            return UIImage.placeHolder(preferenceSize: .init(size))
        }
    }
    
    static func imageConfig(size: CGFloat? = nil, weight: UIImage.SymbolWeight, colors: [UIColor]) -> UIImage.SymbolConfiguration {
        let palette = colors.isEmpty ? [R.Color.LabelPrimary] : colors
        let colorConfig = UIImage.SymbolConfiguration(paletteColors: palette)
        if let size, size > .ulpOfOne {
            return UIImage.SymbolConfiguration(pointSize: size, weight: weight).applying(colorConfig)
        }
        return UIImage.SymbolConfiguration(weight: weight).applying(colorConfig)
    }
    
    ///If no color is set inside the icon, the passed-in color will be used for updating.
    ///If the icon already has a color, it will return itself directly.
    ///If forceUpdate is set, it will be forced to update.
    func updateColorsIfNeed(colors: [UIColor], forceUpdate: Bool = false) -> Self {
        var tempIcon = self
        switch self {
        case .symbol(let symbol, let weight, let oldColors, let cornerStyle, let animated):
            tempIcon = Self.symbol(symbol,
                                   weight: weight,
                                   colors: (forceUpdate || oldColors.count == 0) ? colors : oldColors,
                                   cornerStyle: cornerStyle,
                                   animated: animated)
            
        case .symbolImage(let image, let weight, let oldColors, let cornerStyle, let animated):
            tempIcon = Self.symbolImage(image, weight: weight,
                                        colors: (forceUpdate || oldColors.count == 0) ? colors : oldColors,
                                        cornerStyle: cornerStyle,
                                        animated: animated)
            
        case .image(let image, let imageColor, let cornerStyle):
            tempIcon = .image(image,
                              color: (forceUpdate || imageColor == nil) ? colors.first : imageColor,
                              cornerStyle: cornerStyle)
            
        case .imageUrl:
            break
        }
        return tempIcon
    }
    
    func updateCornerStyle(_ cornerStyle: ASCornerStyle) -> Self {
        switch self {
        case .symbol(let sFSymbol, let weight, let colors, _, let animated):
            return .symbol(sFSymbol, weight: weight, colors: colors, cornerStyle: cornerStyle, animated: animated)
        case .symbolImage(let uIImage, let weight, let colors, _, let animated):
            return .symbolImage(uIImage, weight: weight, colors: colors, cornerStyle: cornerStyle, animated: animated)
        case .image(let uIImage, let color, _):
            return .image(uIImage, color: color, cornerStyle: cornerStyle)
        case .imageUrl(let uRL, let processSize, _):
            return .imageUrl(uRL, processSize: processSize, cornerStyle: cornerStyle)
        }
    }
}
