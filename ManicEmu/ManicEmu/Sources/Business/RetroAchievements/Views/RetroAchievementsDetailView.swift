//
//  RetroAchievementsDetailView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later



class RetroAchievementsDetailView: BaseView {
    
    class RetroAchievementsDetailContentView: BaseView {
        init(achievement: CheevosAchievement, shareMode: Bool = false, didTapClose: @escaping (()->Void)) {
            super.init(frame: .zero)
            
            let coverImageView = UIImageView()
            coverImageView.contentMode = .scaleAspectFill
            addSubview(coverImageView)
            coverImageView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.size.equalTo(160)
                make.top.equalToSuperview()
            }
            coverImageView.kf.setImage(with: URL(string: achievement.unlocked ? achievement.unlockedBadgeUrl : achievement.activeBadgeUrl), placeholder: UIImage.placeHolder(preferenceSize: .init(160)))
            
            var iconSymbol: SFSymbol? = nil
            var iconAlert: String? = nil
            if achievement.isMissable &&  achievement.isProgression {
                iconSymbol = .starCircle
                iconAlert = R.string.localizable.achievementsWinAlert()
            } else if achievement.isMissable {
                iconSymbol = .exclamationmarkCircle
                iconAlert = R.string.localizable.achievementsMissableAlert()
            } else if achievement.isProgression {
                iconSymbol = .clockBadgeCheckmark
                iconAlert = R.string.localizable.achievementsProgressionAlert()
            }
            if let iconSymbol {
                let iconImageView = SymbolButton(image: UIImage(symbol: iconSymbol, color: .white))
                iconImageView.enablePressEffect = false
                iconImageView.enableRoundCorner = true
                iconImageView.backgroundColor = UIColor.black
                addSubview(iconImageView)
                iconImageView.snp.makeConstraints { make in
                    make.top.trailing.equalTo(coverImageView).inset(R.Size.ContentSpaceExtraSmall)
                    make.size.equalTo(20)
                }
                iconImageView.addTapGesture { gesture in
                    if let iconAlert {
                        UIView.makeAlert(detail: iconAlert)
                    }
                }
            }
            
            
            let titleLabel: UILabel = {
                let view = UILabel()
                view.numberOfLines = 0
                let matt = NSMutableAttributedString(string: achievement.title ?? "",
                                                     attributes: [
                                                        .font: R.Font.LargeTitle(emphasis: true),
                                                        .foregroundColor: shareMode ? R.Color.LabelPrimary.forceStyle(.dark) : R.Color.LabelPrimary
                                                     ])
                matt.append(NSAttributedString(string: "\n\(achievement._description ?? "")",
                                               attributes: [
                                                .font: R.Font.Body(),
                                                .foregroundColor: R.Color.LabelSecondary
                                               ]))
                let style = NSMutableParagraphStyle()
                style.lineSpacing = R.Size.ContentSpaceTiny/2
                style.alignment = .center
                view.attributedText = matt.applying(attributes: [.paragraphStyle: style])
                return view
            }()
            addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.leading.greaterThanOrEqualToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
                make.top.equalTo(coverImageView.snp.bottom).offset(R.Size.ContentSpaceHuge)
            }
            
            var enableProgressView: RetroAchievementsListCell.AchievementsProgressView? = nil
            if let measuredProgress = achievement.measuredProgress, !measuredProgress.isEmpty {
                let progressView = RetroAchievementsListCell.AchievementsProgressView()
                enableProgressView = progressView
                progressView.progress = achievement.measuredPercent
                addSubview(progressView)
                progressView.snp.makeConstraints { make in
                    make.leading.equalTo(titleLabel)
                    make.height.equalTo(2)
                    make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceMedium)
                }
                
                let progressLabel = UILabel()
                progressLabel.font = R.Font.Footnote()
                progressLabel.textColor = R.Color.Yellow
                progressLabel.text = measuredProgress
                addSubview(progressLabel)
                progressLabel.snp.makeConstraints { make in
                    make.leading.equalTo(progressView.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
                    make.centerY.equalTo(progressView)
                    make.trailing.equalTo(titleLabel)
                }
            }
            
            let seperatorColor = shareMode ? R.Color.Border.forceStyle(.dark) : R.Color.Border
            let seperator = SparkleSeperatorView(color: seperatorColor, lineColor: seperatorColor)
            addSubview(seperator)
            seperator.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(24)
                if let enableProgressView {
                    make.top.equalTo(enableProgressView.snp.bottom).offset(R.Size.ContentSpaceLarge)
                } else {
                    make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceLarge)
                }
            }
            
            let infoLabel: UILabel = {
                let view = UILabel()
                view.textAlignment = .center
                view.numberOfLines = 0
                let matt = NSMutableAttributedString(string: "\(achievement.points) points", attributes: [
                    .font: R.Font.Body(),
                    .foregroundColor: shareMode ? R.Color.LabelPrimary.forceStyle(.dark) : R.Color.LabelPrimary
                ])
                if achievement.unlocked, let unlockDate = achievement.unlockTime {
                    matt.append(NSAttributedString(string: "\n\(unlockDate.dateTimeString())", attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelSecondary]))
                }
                let style = NSMutableParagraphStyle()
                style.lineSpacing = R.Size.ContentSpaceTiny/2
                style.alignment = .center
                view.attributedText = matt.applying(attributes: [.paragraphStyle: style])
                return view
            }()
            addSubview(infoLabel)
            infoLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.leading.greaterThanOrEqualToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
                make.top.equalTo(seperator.snp.bottom).offset(R.Size.ContentSpaceLarge)
            }
            
            if shareMode {
                let brandImageView = UIImageView(image: R.image.app_title())
                brandImageView.contentMode = .scaleAspectFit
                addSubview(brandImageView)
                brandImageView.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    if let _ = enableProgressView {
                        make.top.equalTo(infoLabel.snp.bottom).offset(R.Size.ItemHeightMicro)
                    } else {
                        make.top.equalTo(infoLabel.snp.bottom).offset(R.Size.ItemHeightSmall)
                    }
                    
                    make.bottom.equalToSuperview()
                }
            } else {
                let roundContainer = RoundAndBorderView(roundCorner: .allCorners, borderColor: R.Color.Border, borderWidth: 2)
                if #available(iOS 26.0, tvOS 26.0, *) {
                    roundContainer.makeGlass()
                } else {
                    roundContainer.backgroundColor = R.Color.BackgroundSecondary
                    roundContainer.enablePressEffect = true
                }
                roundContainer.addTapGesture { gesture in
                    didTapClose()
                }
                addSubview(roundContainer)
                roundContainer.snp.makeConstraints { make in
                    make.height.equalTo(R.Size.ItemHeightMedium)
                    make.centerX.equalToSuperview()
                    make.top.equalTo(infoLabel.snp.bottom).offset(R.Size.ItemHeightMicro)
                    make.bottom.equalToSuperview()
                }
                let okLabel = UILabel()
                okLabel.text = R.string.localizable.gotIt()
                okLabel.font = R.Font.Headline(emphasis: true)
                okLabel.textColor = R.Color.LabelPrimary
                roundContainer.addSubview(okLabel)
                okLabel.snp.makeConstraints { make in
                    make.center.equalToSuperview()
                    make.leading.trailing.equalToSuperview().inset(40)
                }
            }
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private let containerView = UIView()
    
    private var shareContentView: UIView? = nil
    
    required init?(parameters: Any...) {
        guard let achievement = parameters.compactMap({ $0 as? CheevosAchievement }).first else {
            return nil
        }
        super.init(frame: .zero)
        
        let retroImageView = UIImageView(image: R.image.retro_bg())
        retroImageView.contentMode = .scaleAspectFill
        addSubview(retroImageView)
        retroImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.lessThanOrEqualToSuperview()
            make.trailing.greaterThanOrEqualToSuperview()
            make.centerX.equalToSuperview()
        }
        
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let detailView = RetroAchievementsDetailContentView(achievement: achievement) { [weak self] in
            guard let self else { return }
            if self.showAsSheet {
                self.hide()
            }
        }
        containerView.addSubview(detailView)
        detailView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }
        
        let shareButton = ASButtonView(.smallIconButton(icon: .symbolImage(R.image.shareRa_iconSymbols())).enableGlass(true))
        shareButton.didTapButton = { [weak self] in
            guard let self else { return }
            UIView.makeLoading()
            self.generateShareImage(achievement: achievement) { image in
                UIView.hideLoading()
                ShareManager.shareImage(image: image, in: self.hostingWindowScene)
                self.shareContentView?.removeFromSuperview()
                self.shareContentView = nil
            }
        }
        addSubview(shareButton)
        shareButton.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(R.Size.SheetGrabberTopInset + R.Size.ContentSpaceExtraSmall)
            if UIDevice.isPhoneDuo {
                make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
            } else {
                make.trailing.equalTo(safeAreaLayoutGuide).offset(-R.Size.ContentSpaceMedium)
            }
            
        }
        
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func generateShareImage(achievement: CheevosAchievement, completion: ((UIImage)->Void)? = nil) {
        let contentView = UIView()
        insertSubview(contentView, at: 0)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let shareImageView = UIView()
        shareImageView.overrideUserInterfaceStyle = .dark
        shareImageView.backgroundColor = R.Color.BackgroundPrimary
        contentView.addSubview(shareImageView)
        shareImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: R.Size.ApplicationWindowSize.minDimension,
                                     height: R.Size.ApplicationWindowSize.maxDimension))
        }
        
        let maskView = UIView()
        maskView.backgroundColor = R.Color.BackgroundPrimary
        contentView.addSubview(maskView)
        maskView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let backgroundImageView = UIImageView(image: R.image.launch_bg()?.rotated(by: Measurement(value: 180, unit: .degrees)))
        backgroundImageView.contentMode = .scaleAspectFill
        shareImageView.addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }
        
        let retroImageView = UIImageView(image: R.image.retro_bg())
        retroImageView.contentMode = .scaleAspectFill
        shareImageView.addSubview(retroImageView)
        retroImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.lessThanOrEqualToSuperview()
            make.trailing.greaterThanOrEqualToSuperview()
            make.centerX.equalToSuperview()
        }
        
        let detailView = RetroAchievementsDetailContentView(achievement: achievement, shareMode: true) { }
        shareImageView.addSubview(detailView)
        detailView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }
        
        self.shareContentView = contentView
        
        DispatchQueue.main.asyncAfter(delay: 0.5) {
            completion?(shareImageView.asImage())
        }
        
        return
    }
}

extension RetroAchievementsDetailView: ShowableView {
    static func show(achievement: CheevosAchievement) {
        Self.show(parameters: achievement)
    }
    
    func dataForShow(_ defaultData: ASSheet) -> ASSheet {
        var sheetData = defaultData
        sheetData.enableBackgroundDecoration = false
        sheetData.fullScreenForLandscape = true
        return sheetData
    }
}
