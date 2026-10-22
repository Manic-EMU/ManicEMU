//
//  LandscapeFilterView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class LandscapeFilterView: UIVisualEffectView {
    private lazy var defaultView: UIView = {
        let view = UIView()
        let logoView = ASIconView(.symbolImage(R.image.logo_iconSymbols(),
                                               colors: [R.Color.LabelPrimary.forceStyle(.dark)],
                                               cornerStyle: .radius(R.Size.IconSizeMedium.height/2)))
        logoView.backgroundColor = R.Color.Main
        view.addSubview(logoView)
        logoView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(R.Size.ContentSpaceExtraExtraSmall)
            make.centerY.equalToSuperview()
            make.size.equalTo(R.Size.IconSizeMedium)
        }
        
        let iconView = ASIconView(.symbolImage(R.image.app_title()))
        view.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalTo(logoView.snp.trailing).offset(R.Size.ContentSpaceExtraExtraSmall)
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceExtraExtraSmall)
            make.height.equalTo(10)
            make.centerY.equalToSuperview()
        }
        return view
    }()
    
    private lazy var filterView = ASIconView()
    
    init() {
        super.init(effect: nil)
        if #available(iOS 26.0, tvOS 26.0, *) {
            if effect == nil {
                let glassEffect = UIGlassEffect(style: .clear)
                glassEffect.tintColor = R.Color.BackgroundSecondary.withAlphaComponent(0.2)
                glassEffect.isInteractive = true
                effect = glassEffect
                
            }
        } else {
            backgroundColor = R.Color.BackgroundSecondary
            enablePressEffect = true
        }
        isFocusable = true
        resetDefault()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layerCornerRadius = height/2
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func prepareFilterView() {
        if defaultView.superview != nil {
            defaultView.removeFromSuperview()
        }
        
        if filterView.superview == nil {
            contentView.addSubview(filterView)
            filterView.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceSmall)
            }
        }
    }
    
    func setManufacturer(_ manufacturer: Manufacturer) {
        prepareFilterView()
        filterView.icon = .image(manufacturer.highlightImage)
    }
    
    func setGameType(_ gameType: GameType) {
        prepareFilterView()
        if let brandImage = gameType.brandImage {
            filterView.icon = .image(brandImage)
        } else  {
            filterView.icon = .image(gameType.manufacturer.highlightImage)
        }
    }
    
    func resetDefault() {
        if defaultView.superview == nil {
            contentView.addSubview(defaultView)
            defaultView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        if filterView.superview != nil {
            filterView.removeFromSuperview()
        }
    }
}
