//
//  GamesListBlankSlateView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/11.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Device

class GamesListBlankSlateView: BaseView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let containerView = UIView()
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        //The divider and stars in the middle
        let seperator = SparkleSeperatorView()
        containerView.addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.leading.trailing.equalTo(containerView).inset(R.Size.ContentSpaceLarge)
            make.height.equalTo(16)
            make.centerY.equalToSuperview().offset(-R.Size.ContentSpaceExtraSmall)
        }
        
        //Guide to importing the game
        let guideContainer = UIView()
        containerView.addSubview(guideContainer)
        guideContainer.snp.makeConstraints { make in
            make.bottom.equalTo(seperator.snp.top).offset(-40)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(R.Size.ContentSpaceLarge)
            make.trailing.lessThanOrEqualToSuperview().offset(-R.Size.ContentSpaceLarge)
        }
        let guideLabelLeft = UILabel()
        guideLabelLeft.textColor = R.Color.LabelSecondary
        guideLabelLeft.font = R.Font.Body2()
        guideLabelLeft.text = R.string.localizable.gamesListEmptyGuideLeft()
        guideContainer.addSubview(guideLabelLeft)
        guideLabelLeft.adjustsFontSizeToFitWidth = true
        guideLabelLeft.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        let guideImageView = ASIconView(.symbolImage(R.image.import_iconSymbols()))
        guideContainer.addSubview(guideImageView)
        guideImageView.snp.makeConstraints { make in
            make.leading.equalTo(guideLabelLeft.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.top.bottom.equalToSuperview()
            make.size.equalTo(R.Size.ButtonExtraExtraSmall)
        }
        let guideLabelRight = UILabel()
        guideLabelRight.textColor = R.Color.LabelSecondary
        guideLabelRight.font = R.Font.Body2()
        guideLabelRight.text = R.string.localizable.gamesListEmptyGuideRight()
        guideContainer.addSubview(guideLabelRight)
        guideLabelRight.adjustsFontSizeToFitWidth = true
        guideLabelRight.snp.makeConstraints { make in
            make.leading.equalTo(guideImageView.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.trailing.centerY.equalToSuperview()
        }
        
        //Welcome Banner
        let welcomeContainer = UIView()
        containerView.addSubview(welcomeContainer)
        welcomeContainer.snp.makeConstraints { make in
            make.bottom.equalTo(guideContainer.snp.top).offset(-R.Size.ContentSpaceExtraSmall)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(R.Size.ContentSpaceLarge)
            make.trailing.lessThanOrEqualToSuperview().offset(-R.Size.ContentSpaceLarge)
        }
        let welcomeLabelLeft = UILabel()
        welcomeLabelLeft.textColor = R.Color.LabelPrimary
        welcomeLabelLeft.font = R.Font.Headline(emphasis: true)
        welcomeLabelLeft.text = R.string.localizable.gamesListEmptyWelcomeLeft()
        welcomeContainer.addSubview(welcomeLabelLeft)
        welcomeLabelLeft.adjustsFontSizeToFitWidth = true
        welcomeLabelLeft.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        
        let appNameImage = UIImageView(image: R.image.app_title())
        welcomeContainer.addSubview(appNameImage)
        appNameImage.snp.makeConstraints { make in
            make.leading.equalTo(welcomeLabelLeft.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.centerY.equalToSuperview()
        }
        let welcomeLabelRight = UILabel()
        welcomeLabelRight.textColor = R.Color.LabelPrimary
        welcomeLabelRight.font = R.Font.Headline(emphasis: true)
        welcomeLabelRight.text = R.string.localizable.gamesListEmptyWelcomeRight()
        welcomeContainer.addSubview(welcomeLabelRight)
        welcomeLabelRight.adjustsFontSizeToFitWidth = true
        welcomeLabelRight.snp.makeConstraints { make in
            make.leading.equalTo(appNameImage.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.trailing.centerY.equalToSuperview()
        }
        
        //加入社区
        let channelLinkContainerView = UIView()
        channelLinkContainerView.backgroundColor = R.Color.BackgroundSecondary
        channelLinkContainerView.layerCornerRadius = R.Size.ButtonExtraSmall/2
        addSubview(channelLinkContainerView)
        channelLinkContainerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(R.Size.ButtonExtraSmall)
            make.top.equalTo(seperator.snp.bottom).offset(40)
            make.leading.greaterThanOrEqualToSuperview().offset(R.Size.ContentSpaceLarge)
            make.trailing.lessThanOrEqualToSuperview().offset(-R.Size.ContentSpaceLarge)
        }
        let channelLinkLabel = UILabel()
        let channelName = Locale.prefersCN ? R.string.localizable.qqChannelName() : "Discord"
        let matt = NSMutableAttributedString(string: R.string.localizable.importChannelTips(" \(channelName) "), attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.LabelSecondary])
        channelLinkLabel.attributedText = matt.applying(attributes: [.foregroundColor: R.Color.Purple], toOccurrencesOf: channelName)
        channelLinkLabel.textAlignment = .center
        channelLinkLabel.adjustsFontSizeToFitWidth = true
        channelLinkContainerView.addSubview(channelLinkLabel)
        channelLinkLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
        }
        let channelLinkButton = UIButton()
        channelLinkContainerView.addSubview(channelLinkButton)
        channelLinkButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        channelLinkButton.isFocusable = true
        channelLinkButton.onTap {
            if Locale.prefersCN {
                UIApplication.shared.open(R.URLs.JoinQQ)
            } else {
                UIApplication.shared.open(R.URLs.JoinDiscord)
            }
        }
        
        //warnning
        let warnningContainer = UIView()
        warnningContainer.backgroundColor = R.Color.BackgroundSecondary
        warnningContainer.layerCornerRadius = R.Size.ButtonExtraSmall/2
        containerView.addSubview(warnningContainer)
        warnningContainer.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-(R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.ItemHeightLarge + ((Device.size().rawValue < Size.screen5_8Inch.rawValue || UIDevice.isPad) ? R.Size.ContentSpaceHuge : R.Size.ContentSpaceSmall)))
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(R.Size.ContentSpaceLarge)
            make.trailing.lessThanOrEqualToSuperview().offset(-R.Size.ContentSpaceLarge)
            make.height.equalTo(R.Size.ButtonExtraSmall)
        }
        let warnningIcon = ASIconView(.symbolImage(R.image.infoFill_iconSymbols(),
                                                   colors: [R.Color.Yellow]))
        warnningContainer.addSubview(warnningIcon)
        warnningIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall)
            make.centerY.equalToSuperview()
            make.size.equalTo(R.Size.ButtonExtraExtraSmall)
        }
        let warnningLabel = UILabel()
        warnningLabel.font = R.Font.Footnote()
        warnningLabel.textColor = R.Color.Yellow
        warnningLabel.text = R.string.localizable.gamesListEmptyWarnning()
        warnningLabel.adjustsFontSizeToFitWidth = true
        warnningContainer.addSubview(warnningLabel)
        warnningLabel.snp.makeConstraints { make in
            make.centerY.equalTo(warnningIcon)
            make.leading.equalTo(warnningIcon.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceSmall)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
