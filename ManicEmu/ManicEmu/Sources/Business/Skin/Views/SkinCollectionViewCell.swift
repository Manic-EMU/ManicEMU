//
//  SkinCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit


class SkinCollectionViewCell: UICollectionViewCell {
    
    class SubscriptView: BaseView {
        var titleLabel: UILabel = {
            let view = UILabel()
            view.textColor = R.Color.LabelPrimary
            view.font = R.Font.Caption(emphasis: true)
            view.layer.shadowColor = R.Color.BackgroundPrimary.cgColor
            view.layer.shadowOpacity = 0.5
            view.layer.shadowOffset = .init(width: 0, height: 2)
            view.layer.shadowRadius = 2
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = R.Color.BackgroundSecondary.withAlphaComponent(0.4)
            addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    var onPreview: (() -> Void)?
    var onPlaycaseTap: (() -> Void)?
    
    private var appliedSkinIdentifier: String?
    private var appliedTraits: ControllerSkin.Traits?
    private var appliedRenderGeneration: Int = -1
    
    var controllerView: ControllerView = {
        let view = ControllerView()
        view.backgroundColor = .black
        view.layerCornerRadius = R.Size.CornerRadiusMedium
        view.isUserInteractionEnabled = false
        view.overrideControllerSkinSize = .small
        return view
    }()
    
    //When editing
    private var checkView: ASCheckView = {
        let view = ASCheckView(.init(isSelected: false))
        view.isHidden = true
        return view
    }()
    
    //Show the current options in use
    private var radioView: ASRadioView = {
        let view = ASRadioView(.init(isSelected: true))
        view.isHidden = true
        return view
    }()
    
    private var subscriptView: SubscriptView = {
        let view = SubscriptView()
        view.isHidden = true
        return view
    }()
    
    private var playcaseButton: UIImageView = {
        let view = UIImageView(image: R.image.playcase_footnote())
        view.enablePressEffect = true
        view.isFocusable = false
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private var previewButton: SymbolButton = {
        let view = SymbolButton(image: R.image.customArrowDownLeftAndArrowUpRight()?.applySymbolConfig(),
                                title: R.string.localizable.skinPreviewTitle(),
                                titleFont: R.Font.Footnote(),
                                edgeInsets: UIEdgeInsets(top: R.Size.ContentSpaceExtraSmall,
                                                         left: R.Size.ContentSpaceSmall,
                                                         bottom: R.Size.ContentSpaceExtraSmall,
                                                         right: R.Size.ContentSpaceSmall),
                                titlePosition: .right,
                                enableGlass: true)
        view.isFocusable = false
        view.enableRoundCorner = true
        view.isHidden = true
        return view
    }()
    
    override var isSelected: Bool {
        willSet {
            self.checkView.isSelected = newValue
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        enablePressEffect = true
        enableFocusEffects = false
        
        layerCornerRadius = R.Size.CornerRadiusMedium
        backgroundColor = R.Color.BackgroundPrimary
        addSubview(controllerView)
        controllerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalToSuperview()
        }
        
        addSubview(checkView)
        checkView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
        }
        
        addSubview(radioView)
        radioView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
        }
        
        addSubview(subscriptView)
        subscriptView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightMicro)
        }
        
        addSubview(previewButton)
        previewButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        addSubview(playcaseButton)
        playcaseButton.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview()
        }
        
        previewButton.addTapGesture { [weak self] _ in
            self?.onPreview?()
        }
        playcaseButton.addTapGesture { [weak self] _ in
            self?.onPlaycaseTap?()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onPreview = nil
        onPlaycaseTap = nil
        onFocusConfirm = nil
    }
    
    func setData(controllerSkin: ControllerSkin?,
                 traits: ControllerSkin.Traits,
                 subscriptTitle: String? = nil,
                 isEditMode: Bool,
                 isUsing: Bool,
                 isEditable: Bool,
                 renderGeneration: Int = 0) {
        let needsSkinUpdate = appliedSkinIdentifier != controllerSkin?.identifier
            || appliedTraits != traits
            || appliedRenderGeneration != renderGeneration
        
        if needsSkinUpdate {
            let screenAspectRatio: CGFloat
            if traits.orientation == .portrait {
                screenAspectRatio = R.Size.ApplicationWindowSize.aspectRatio
            } else {
                screenAspectRatio = R.Size.ApplicationWindowSize.height/R.Size.ApplicationWindowSize.width
            }
            if let aspectRatio = controllerSkin?.aspectRatio(for: traits), abs(aspectRatio.aspectRatio - screenAspectRatio) > 0.1 {
                controllerView.snp.updateConstraints { make in
                    make.height.equalToSuperview().offset(-(height - (width/aspectRatio.aspectRatio)))
                }
            } else {
                controllerView.snp.updateConstraints { make in
                    make.height.equalToSuperview()
                }
            }
            controllerView.overrideControllerSkinTraits = traits
            controllerView.controllerSkin = controllerSkin
            appliedSkinIdentifier = controllerSkin?.identifier
            appliedTraits = traits
            appliedRenderGeneration = renderGeneration
        }
        
        if let subscriptTitle {
            subscriptView.isHidden = false
            subscriptView.titleLabel.text = R.string.localizable.designedFor(subscriptTitle)
        } else {
            subscriptView.isHidden = true
        }
        
        playcaseButton.isHidden = !(controllerSkin?.isPlayCase ?? false)
        
        checkView.isHidden = !isEditMode || !isEditable
        radioView.isHidden = isEditMode || !isUsing
        previewButton.isHidden = isEditMode
    }
}
