//
//  GameSavePurchaseGuideView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/17.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class GameSavePurchaseGuideView: BaseView {
    init(hideSeperator: Bool) {
        super.init(frame: .zero)
        enablePressEffect = true
        
        addTapGesture { [weak self] gesture in
            guard let self else { return }
            topViewController(in: self.hostingWindowScene)?.present(PurchaseViewController(), animated: true)
        }
        
        let seperator = SparkleSeperatorView(color: R.Color.BackgroundTertiary)
        if !hideSeperator {
            addSubview(seperator)
            seperator.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceLarge)
                make.height.equalTo(16)
                make.top.equalToSuperview().offset(40)
            }
        }
        
        
        let containerView = UIView()
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            if hideSeperator {
                make.top.equalToSuperview().offset(R.Size.ContentSpaceLarge)
            } else {
                make.top.equalTo(seperator.snp.bottom).offset(40)
            }
            make.centerX.equalToSuperview()
        }

        let becomeLabel = UILabel()
        becomeLabel.textColor = R.Color.LabelPrimary
        becomeLabel.font = R.Font.Headline(emphasis: true)
        becomeLabel.text = R.string.localizable.gameSaveGuideBecomTitle()
        containerView.addSubview(becomeLabel)
        becomeLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        
        let appNameImage = UIImageView(image: R.image.app_title())
        containerView.addSubview(appNameImage)
        appNameImage.snp.makeConstraints { make in
            make.leading.equalTo(becomeLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.centerY.equalTo(becomeLabel)
        }
        
        let memberLabel = UILabel()
        memberLabel.textColor = R.Color.LabelPrimary
        memberLabel.font = R.Font.Headline(emphasis: true)
        memberLabel.text = R.string.localizable.gameSaveGuideMemberTitle()
        containerView.addSubview(memberLabel)
        memberLabel.snp.makeConstraints { make in
            make.leading.equalTo(appNameImage.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.trailing.equalToSuperview()
            make.centerY.equalTo(becomeLabel)
        }
        
        let detalLabel = UILabel()
        detalLabel.textAlignment = .center
        detalLabel.numberOfLines = 0
        detalLabel.textColor = R.Color.LabelSecondary
        detalLabel.font = R.Font.Caption()
        detalLabel.text = R.string.localizable.gameSaveGuideDesc()
        addSubview(detalLabel)
        detalLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            make.top.equalTo(containerView.snp.bottom).offset(R.Size.ContentSpaceTiny)
        }
        
        let button = SymbolButton(image: nil, title: R.string.localizable.goToUpgrade(), titleFont: R.Font.Caption(emphasis: true), titleColor: R.Color.LabelPrimary.forceStyle(.dark), titlePosition: .left, imageAndTitlePadding: 0)
        button.enableRoundCorner = true
        let buttonBackground = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 30)))
        buttonBackground.addGradient(colors: R.Color.Gradient, direction: .leftToRight)
        button.insertSubview(buttonBackground, at: 0)
        addSubview(button)
        button.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(detalLabel.snp.bottom).offset(R.Size.ContentSpaceMedium)
            make.size.equalTo(CGSize(width: 100, height: 30))
            make.bottom.equalToSuperview()
        }
        
       
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
