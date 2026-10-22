//
//  ImportMottoCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/23.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ImportMottoCollectionViewCell: UICollectionViewCell {
    
    private let imageView = ASIconView(.image(R.image.import_ip()!))
    private let labelView = {
        var text = ASText.mediumText(R.string.localizable.importTopHintTitle(),
                                     color: R.Color.LabelSecondary,
                                     numberOfLines: 0)
        text.attributes?.alignment = .center
        return ASLabelView(text: text)
    }()
    private let backgroundGradientView = GradientView()
    
    private let keepCellHeightView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.zPosition = .greatestFiniteMagnitude
        
        keepCellHeightView.layerCornerRadius = R.Size.CornerRadiusMedium
        
        addSubviews([keepCellHeightView, backgroundGradientView, imageView, labelView])
        
        let bg = R.Color.BackgroundPrimary
        let bgDark = R.Color.BackgroundPrimary.forceStyle(.dark)
        let bgLight = R.Color.BackgroundPrimary.forceStyle(.light)
        let top = UIColor(.dm,
                          light: bgLight.blended(with: .black, fraction: 0.1),
                          dark: bgDark.blended(with: .white, fraction: 0.1))
        backgroundGradientView.setupGradient(
            colors: [top, bg, bg],
            locations: [0.0, 0.6, 1],
            direction: .topToBottom
        )
        backgroundGradientView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightSmall)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var hasInit = false
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !hasInit else { return }
        updateViews(isLandscape: preferredLayoutStyle == .landscape)
        hasInit = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let ovalLayer = CAShapeLayer()
        ovalLayer.path = UIBezierPath(ovalIn: CGRect(origin: .zero,
                                                     size: CGSize(width: backgroundGradientView.width,
                                                                  height: backgroundGradientView.height*2))).cgPath
        backgroundGradientView.layer.mask = ovalLayer
        
        if UIDevice.isPhone, preferredLayoutStyle == .landscape {
            keepCellHeightView.backgroundColor = R.Color.BackgroundSecondary
            backgroundGradientView.isHidden = true
        } else {
            keepCellHeightView.backgroundColor = .clear
            backgroundGradientView.isHidden = false
        }
    }
    
    func updateViews(isLandscape: Bool) {
        if isLandscape {
            imageView.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(R.Size.ContentSpaceSmall)
                make.bottom.equalToSuperview().offset(R.Size.ContentSpaceHuge)
            }
            
            labelView.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall)
                make.trailing.equalTo(imageView.snp.leading)
                make.centerY.equalToSuperview()
            }
            
            keepCellHeightView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                make.height.equalTo(100).priority(.high)
            }
        } else {
            imageView.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(R.Size.ContentSpaceExtraExtraSmall)
                make.centerX.equalToSuperview()
            }
            
            labelView.snp.remakeConstraints { make in
                make.top.equalTo(imageView.snp.bottom)
                make.centerX.equalToSuperview()
                make.leading.trailing.greaterThanOrEqualToSuperview().inset(R.Size.ContentSpaceSmall)
                make.bottom.greaterThanOrEqualToSuperview().inset(R.Size.ContentSpaceSmall)
            }
            
            keepCellHeightView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
                make.height.equalTo(220).priority(.high)
            }
        }
    }
}
