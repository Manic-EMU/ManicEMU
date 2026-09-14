//
//  GamesCollectionReusableView.swift
//  ManicReader
//
//  Created by Max on 2025/1/3.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

import VisualEffectView

class GamesCollectionReusableView: UICollectionReusableView {
    private let titleContainer = UIView()
    private var titleLabel = UILabel()
    private let brandImageContainer = UIView()
    private var brandImageView = UIImageView()
    private var gamesCountButton = ASButtonView(.extraSmall(icon: .symbol(.chevronUp, colors: [R.Color.LabelSecondary]),
                                                            title: "",
                                                            titleColor: R.Color.LabelSecondary,
                                                            titlePosition: .left,
                                                            background: .clear,
                                                            sizeStyle: .fixHeight(16, insets: .zero)))
    
    var didTapPlatform: (()->Void)? = nil
    
    var didTapGameCount: (()->Void)? = nil
    
    private var highlightString: String? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        func genInfoIcon() -> ASButtonView {
            ASButtonView(.iconOnly(icon: .symbolImage(R.image.introduction_iconSymbols(),
                                                      colors: [R.Color.LabelSecondary]),
                                   iconSize: R.Size.ButtonSizeAccessory,
                                   background: R.Color.BackgroundTertiary,
                                   insets: .init(inset: R.Size.ContentSpaceTiny)))
        }
        
        
        titleContainer.isHidden = true
        addSubview(titleContainer)
        titleContainer.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
        }
        titleContainer.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        let titleIcon = genInfoIcon()
        titleContainer.addSubview(titleIcon)
        titleIcon.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.centerY.equalTo(titleLabel)
            make.trailing.equalToSuperview()
        }
        titleContainer.enablePressEffect = true
        titleContainer.enableFocusEffects = false
        titleContainer.addTapGesture { [weak self] gesture in
            guard let self else { return }
            self.didTapPlatform?()
        }
        
        
        brandImageContainer.isHidden = true
        addSubview(brandImageContainer)
        brandImageContainer.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
        }
        brandImageContainer.addSubview(brandImageView)
        brandImageView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        let brandImageIcon = genInfoIcon()
        brandImageContainer.addSubview(brandImageIcon)
        brandImageIcon.snp.makeConstraints { make in
            make.leading.equalTo(brandImageView.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.centerY.equalTo(brandImageView)
            make.trailing.equalToSuperview()
        }
        brandImageContainer.enablePressEffect = true
        brandImageContainer.enableFocusEffects = false
        brandImageContainer.addTapGesture { [weak self] gesture in
            guard let self else { return }
            self.didTapPlatform?()
        }
        
        gamesCountButton.enableFocusEffects = false
        addSubview(gamesCountButton)
        gamesCountButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.leading.greaterThanOrEqualTo(titleContainer.snp.trailing).offset(R.Size.ContentSpaceMedium)
        }
        gamesCountButton.didTapButton = { [weak self] in
            self?.didTapGameCount?()
        }
    }
    
    func setData(gameType: GameType, highlightString: String? = nil, gamesCount: Int = 0, isFolded: Bool = false, allowsFold: Bool = true) {
        if R.Style.GamesGroupTitleStyle == .brand && gameType != .unknown {
            titleContainer.isHidden = true
            brandImageContainer.isHidden = false
            brandImageView.image = gameType.brandImage
        } else {
            titleContainer.isHidden = false
            brandImageContainer.isHidden = true
            var title: String = ""
            if R.Style.GamesGroupTitleStyle == .abbr {
                title = gameType.localizedShortName
            } else if R.Style.GamesGroupTitleStyle == .fullName {
                title = gameType.localizedName
            } else {
                title = gameType.localizedShortName
            }
            titleLabel.attributedText = NSAttributedString(string: title, attributes: [.font: R.Font.LargeTitle(emphasis: true), .foregroundColor: R.Color.LabelPrimary]).highlightString(highlightString)
        }
        
        gamesCountButton.setTitleString("\(gamesCount) \(R.string.localizable.tabbarTitleGames())")
        gamesCountButton.isUserInteractionEnabled = allowsFold
        if !allowsFold || (UIDevice.isPhone && UIDevice.isLandscape) {
            gamesCountButton.setIcon(nil)
        } else {
            gamesCountButton.setIcon(.symbol(isFolded ? .chevronDown : .chevronUp, colors: [R.Color.LabelSecondary]))
        }
        self.highlightString = highlightString
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

