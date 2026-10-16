//
//  GameInfoNavigationView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/30.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class GameInfoNavigationView: BaseView {
    var gameCover: UIImageView = {
        let view = UIImageView()
        view.layerCornerRadius = R.Size.CornerRadiusTiny
        view.contentMode = .scaleAspectFill
        view.alpha = 0
        return view
    }()
    
    var closeButton: ASButtonView = {
        let button = ASButton.smallIconButton(icon: .symbolImage(R.image.close_iconSymbols()),
                                              background: proHUDLayoutStyle() == .landscape ? R.Color.BackgroundTertiary : R.Color.BackgroundSecondary).enableGlass(true)
        
        let view = ASButtonView(button)
        return view
    }()
    
    var toolsView: ASSymbolsButtonView = {
        let view = ASSymbolsButtonView(
            .symbolImage(R.image.info_iconSymbols()),
            .symbolImage(R.image.ellipsis_iconSymbols())
        )
        view.containerInsets = .init(inset: R.Size.ContentSpaceTiny)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubviews([closeButton, gameCover, toolsView])
        
        closeButton.snp.makeConstraints { make in
            make.trailing.equalTo(safeAreaLayoutGuide).inset(R.Size.ContentSpaceLarge)
            make.centerY.equalToSuperview()
        }
        
        gameCover.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(R.Size.ItemHeightLarge - R.Size.ContentSpaceSmall*2))
        }
        
        toolsView.snp.makeConstraints { make in
            make.leading.equalTo(safeAreaLayoutGuide).offset(R.Size.ContentSpaceLarge)
            make.centerY.equalToSuperview()
            make.height.equalTo(R.Size.ButtonSmall)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Iterate through all subviews and check whether the click is on a subview
        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if subview.bounds.contains(convertedPoint) {
                return super.hitTest(point, with: event)
            }
        }
        // Click not on any subview, return nil to let the click pass through.
        return nil
    }
}
