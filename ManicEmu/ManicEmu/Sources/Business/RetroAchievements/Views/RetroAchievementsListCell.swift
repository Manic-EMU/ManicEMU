//
//  RetroAchievementsListCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import Kingfisher
import MarqueeLabel

class RetroAchievementsListCell: UICollectionViewCell {
    
    class AchievementsListView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
        
        class AchievementsListViewCell: UICollectionViewCell {
            private let imageView: UIImageView = {
                let view = UIImageView()
                view.contentMode = .scaleAspectFill
                return view
            }()
            
            private let missableImageView: SymbolButton = {
                let view = SymbolButton(image: UIImage(symbol: .exclamationmarkCircle, font: R.Font.Caption(), color: .white))
                view.enablePressEffect = false
                view.enableRoundCorner = true
                view.backgroundColor = .black
                view.isHidden = true
                return view
            }()
            
            private let progressionImageView: SymbolButton = {
                let view = SymbolButton(image: UIImage(symbol: .clockBadgeCheckmark, font: R.Font.Caption(), color: .white))
                view.enablePressEffect = false
                view.enableRoundCorner = true
                view.backgroundColor = .black
                view.isHidden = true
                return view
            }()
            
            private let winImageView: SymbolButton = {
                let view = SymbolButton(image: UIImage(symbol: .starCircle, font: R.Font.Caption(), color: .white))
                view.enablePressEffect = false
                view.enableRoundCorner = true
                view.backgroundColor = .black
                view.isHidden = true
                return view
            }()
            
            override init(frame: CGRect) {
                super.init(frame: frame)
                addSubview(imageView)
                imageView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                
                imageView.addSubview(missableImageView)
                missableImageView.snp.makeConstraints { make in
                    make.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceTiny)
                    make.size.equalTo(15)
                }
                
                imageView.addSubview(progressionImageView)
                progressionImageView.snp.makeConstraints { make in
                    make.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceTiny)
                    make.size.equalTo(15)
                }
                
                imageView.addSubview(winImageView)
                winImageView.snp.makeConstraints { make in
                    make.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceTiny)
                    make.size.equalTo(15)
                }
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func setData(achievement: CheevosAchievement, isHardcoreList: Bool) {
                var url: String? = nil
                if isHardcoreList {
                    if achievement.hardcoreUnlocked {
                        url = achievement.unlockedBadgeUrl
                    } else {
                        url = achievement.activeBadgeUrl
                    }
                } else {
                    if achievement.softcoreUnlocked {
                        url = achievement.unlockedBadgeUrl
                    } else {
                        url = achievement.activeBadgeUrl
                    }
                }
                imageView.kf.setImage(with: URL(string: url), placeholder: UIImage.placeHolder(preferenceSize: .init(64)))
                if achievement.isMissable && achievement.isProgression {
                    winImageView.isHidden = false
                    missableImageView.isHidden = true
                    progressionImageView.isHidden = true
                } else {
                    if achievement.isMissable {
                        winImageView.isHidden = true
                        missableImageView.isHidden = false
                        progressionImageView.isHidden = true
                    } else if achievement.isProgression {
                        winImageView.isHidden = true
                        missableImageView.isHidden = true
                        progressionImageView.isHidden = false
                    } else {
                        winImageView.isHidden = true
                        missableImageView.isHidden = true
                        progressionImageView.isHidden = true
                    }
                }
            }
        }

        var datas: [CheevosAchievement] = [] {
            didSet {
                collectionView.reloadData()
            }
        }
        
        private var isHardcoreList = true
        
        var didTapAchievement: ((CheevosAchievement)->Void)? = nil
        
        private lazy var segmentView: ASSegmentView = {
            let view = ASSegmentView(.textSegment(titles: [
                R.string.localizable.hardcore(),
                R.string.localizable.softcore()
            ]))
            view.didSelectIndex = { [weak self] index in
                guard let self = self else { return }
                self.isHardcoreList = index == 0
                self.datas = self.datas.sorted(by: {
                    if self.isHardcoreList {
                        if $0.hardcoreUnlocked {
                            return true
                        } else if $1.hardcoreUnlocked {
                            return false
                        }
                        return false
                    } else {
                        if $0.softcoreUnlocked {
                            return true
                        } else if $1.softcoreUnlocked {
                            return false
                        }
                        return false
                    }
                })
            }
            return view
        }()
        
        private lazy var collectionView: UICollectionView = {
            let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
            view.backgroundColor = .clear
            view.contentInsetAdjustmentBehavior = .never
            view.register(cellWithClass: AchievementsListViewCell.self)
            view.showsVerticalScrollIndicator = false
            view.showsHorizontalScrollIndicator = false
            view.dataSource = self
            view.delegate = self
            view.isFocusable = true
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = R.Color.BackgroundSecondary
            layerCornerRadius = R.Size.CornerRadiusLarge
            
            addSubview(segmentView)
            segmentView.snp.makeConstraints { make in
                make.top.equalTo(R.Size.ContentSpaceMedium)
                make.height.equalTo(R.Size.ItemHeightExtraSmall)
                make.leading.equalTo(R.Size.ContentSpaceHuge)
                make.trailing.equalTo(-R.Size.ContentSpaceHuge)
            }
            
            addSubview(collectionView)
            collectionView.snp.makeConstraints { make in
                make.top.equalTo(segmentView.snp.bottom).offset(R.Size.ContentSpaceMedium)
                make.leading.bottom.trailing.equalToSuperview()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func createLayout() -> UICollectionViewLayout {
            let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, env in
                guard let self else { return nil }
                var column = 4.0
                if UIDevice.isPhone && self.prefferedLayoutStyle == .landscape {
                    column = 8.0
                } else if UIDevice.isPad && self.prefferedLayoutStyle == .landscape {
                    column = 6.0
                }
                let cellSize = (env.container.contentSize.width - R.Size.ContentSpaceHuge*2 - R.Size.ContentSpaceSmall*(column-1))/column
                
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(cellSize),
                                                                                     heightDimension: .absolute(cellSize)))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(cellSize)), subitem: item, count: Int(column))
                group.interItemSpacing = NSCollectionLayoutSpacing.fixed(R.Size.ContentSpaceSmall)
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = R.Size.ContentSpaceSmall
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 24, trailing: 24)
                return section
            }
            return layout
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { datas.count }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withClass: AchievementsListViewCell.self, for: indexPath)
            let achievement = datas[indexPath.row]
            cell.setData(achievement: achievement, isHardcoreList: isHardcoreList)
            cell.enablePressEffect = true
            cell.enableFocusEffects = false
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            didTapAchievement?(datas[indexPath.row])
        }
    }
    
    class AchievementsProgressView: BaseView {
        let indicatorView: UIView = {
            let view = UIView()
            view.backgroundColor = R.Color.Yellow
            view.layerCornerRadius = 1
            return view
        }()
        //0-100
        var progress: CGFloat = 0 {
            didSet {
                indicatorView.snp.remakeConstraints { make in
                    make.leading.top.bottom.equalToSuperview()
                    make.width.equalToSuperview().multipliedBy(progress/100)
                }
                UIView.springAnimate {
                    self.layoutIfNeeded()
                }
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = R.Color.BackgroundTertiary
            layerCornerRadius = 1
            addSubview(indicatorView)
            indicatorView.snp.makeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                make.width.equalTo(0)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
    }
    
    private let coverImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layerCornerRadius = R.Size.CornerRadiusMedium
        return view
    }()
    
    private let progressLabel: UILabel = {
        let view = UILabel()
        view.font = R.Font.Footnote()
        view.textColor = R.Color.Yellow
        return view
    }()
    
    private let progressView: AchievementsProgressView = {
        let view = AchievementsProgressView()
        return view
    }()
    
    private let titleLabel: UILabel = {
        let view = MarqueeLabel()
        view.textAlignment = .left
        view.font = R.Font.LargeTitle(emphasis: true)
        view.textColor = R.Color.LabelPrimary
        return view
    }()
    
    private let lastActivityIcon: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.image = .symbolImage(.starCircleFill).applySymbolConfig(color: R.Color.LabelSecondary)
        return view
    }()
    
    private let lastActivityLabel: UILabel = {
        let view = UILabel()
        view.textColor = R.Color.LabelSecondary
        view.font = R.Font.Footnote()
        return view
    }()
    
    let enableSwitchButton: DisabledTapSwitch = {
        let view = DisabledTapSwitch()
        view.onTintColor = R.Color.Main
        view.tintColor = R.Color.BackgroundTertiary
        return view
    }()
    
    let hardcoreSwitchButton: DisabledTapSwitch = {
        let view = DisabledTapSwitch()
        view.onTintColor = R.Color.Main
        view.tintColor = R.Color.BackgroundTertiary
        return view
    }()
    
    let alwaysShowProgressButton: DisabledTapSwitch = {
        let view = DisabledTapSwitch()
        view.onTintColor = R.Color.Main
        view.tintColor = R.Color.BackgroundTertiary
        return view
    }()
    
    private let achievementsCountLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        return view
    }()
    
    private let pointLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        return view
    }()
    
    private lazy var listView: AchievementsListView = {
        let view = AchievementsListView()
        view.didTapAchievement = { [weak self] achievement in
            guard let self else { return }
            // Prefer cached unlock progress when the live achievement has none.
            if achievement.measuredProgress == nil,
               let game = self.game,
               let achievementProgress = game.getAchievementProgress(id: achievement._id) {
                achievement.measuredPercent = achievementProgress.measuredPercent
                achievement.measuredProgress = achievementProgress.measuredProgress
            }
            RetroAchievementsDetailView.show(achievement: achievement)
        }
        return view
    }()
    
    private lazy var bottomButton: UIButton = {
        let view = UIButton(type: .custom)
        view.setAttributedTitle(NSAttributedString(string: "RetroAchievements", attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.Indigo]).underlined, for: .normal)
        view.isFocusable = true
        view.onTap { [weak self] in
            guard let self else { return }
            if let retroGame = self.retroGame {
                UIApplication.shared.open(R.URLs.RetroGame(gameId: retroGame._id))
            } else if let username = self.username {
                UIApplication.shared.open(R.URLs.RetroProfile(username: username))
            } else {
                UIApplication.shared.open(R.URLs.Retro)
            }
        }
        return view
    }()
    
    private var username: String? = nil
    
    private weak var game: Game? = nil
    private var retroGame: CheevosGame? = nil
    
    private lazy var subsetItemView: ASListItemView = {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbolImage(R.image.retroachievements_iconSymbols())))
        styles.append(.title(.largeText(R.string.localizable.achievementsSubset())))
        styles.append(.chevron(.init(title: R.string.localizable.achievementsBaseSet())))
        let view = ASListItemView()
        view.styles = styles
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(coverImageView)
        coverImageView.snp.makeConstraints { make in
            make.size.equalTo(80)
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceHuge)
            make.top.equalToSuperview()
        }
        
        let retroAchievementLabel = UILabel()
        retroAchievementLabel.attributedText = NSAttributedString(string: R.string.localizable.retroAchievements(), attributes: [.font: R.Font.Headline(emphasis: true), .foregroundColor: R.Color.LabelPrimary])
        addSubview(retroAchievementLabel)
        retroAchievementLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(R.Size.ContentSpaceSmall)
            make.top.equalTo(coverImageView).offset(R.Size.ContentSpaceSmall)
        }
        
        let completionProgressLabel = UILabel()
        completionProgressLabel.attributedText = NSAttributedString(string: R.string.localizable.completionProgress(), attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.LabelSecondary])
        addSubview(completionProgressLabel)
        completionProgressLabel.snp.makeConstraints { make in
            make.leading.equalTo(retroAchievementLabel)
            make.top.equalTo(retroAchievementLabel.snp.bottom).offset(R.Size.ContentSpaceTiny/2)
        }
        
        addSubview(progressLabel)
        progressLabel.snp.makeConstraints { make in
            make.centerY.equalTo(completionProgressLabel)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceHuge)
        }
        
        addSubview(progressView)
        progressView.snp.makeConstraints { make in
            make.height.equalTo(2)
            make.leading.equalTo(retroAchievementLabel)
            make.trailing.equalTo(progressLabel)
            make.top.equalTo(completionProgressLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
        }
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView)
            make.trailing.equalTo(progressLabel)
            make.top.equalTo(coverImageView.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        addSubview(lastActivityIcon)
        lastActivityIcon.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
        }
        
        addSubview(lastActivityLabel)
        lastActivityLabel.snp.makeConstraints { make in
            make.centerY.equalTo(lastActivityIcon)
            make.leading.equalTo(lastActivityIcon.snp.trailing).offset(6)
            make.trailing.equalTo(progressLabel)
        }
        
        let container = UIView()
        container.layerCornerRadius = R.Size.CornerRadiusLarge
        container.backgroundColor = R.Color.BackgroundSecondary
        addSubview(container)
        container.snp.makeConstraints { make in
            make.height.equalTo(R.Size.ItemHeightLarge * 3)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(lastActivityIcon.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        let enableContainer = UIView()
        container.addSubview(enableContainer)
        enableContainer.snp.makeConstraints { make in
            make.height.equalTo(R.Size.ItemHeightLarge)
            make.leading.top.trailing.equalToSuperview()
        }
        let enableIcon = UIImageView(image: .symbolImage(.gamecontrollerFill).applySymbolConfig(size: 19, color: R.Color.LabelPrimary))
        enableIcon.contentMode = .center
        enableContainer.addSubview(enableIcon)
        enableIcon.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
        }
        let enableLabel: UILabel = {
            let view = UILabel()
            view.numberOfLines = 2
            let matt = NSMutableAttributedString(string: R.string.localizable.enableAchievements(), attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.LabelPrimary])
            let style = NSMutableParagraphStyle()
            style.lineSpacing = R.Size.ContentSpaceTiny/2
            view.attributedText = matt.applying(attributes: [.paragraphStyle: style])
            return view
        }()
        enableContainer.addSubview(enableLabel)
        enableLabel.snp.makeConstraints { make in
            make.centerY.equalTo(enableIcon)
            make.leading.equalTo(enableIcon.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
        }
        enableContainer.addSubview(enableSwitchButton)
        enableSwitchButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
            make.leading.equalTo(enableLabel.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            if #available(iOS 26.0, tvOS 26.0, *) {
                make.size.equalTo(CGSize(width: 63, height: 28))
            } else {
                make.size.equalTo(CGSize(width: 51, height: 31))
            }
        }
        if #available(iOS 26.0, tvOS 26.0, *) {} else {
            enableSwitchButton.transform = CGAffineTransformMakeScale(0.9, 0.9)
        }
        
        let hardcoreContainer = UIView()
        container.addSubview(hardcoreContainer)
        hardcoreContainer.snp.makeConstraints { make in
            make.height.equalTo(R.Size.ItemHeightLarge)
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(enableContainer.snp.bottom)
        }
        let hardcoreIcon = UIImageView(image: .symbolImage(.flameFill).applySymbolConfig(size: 19, color: R.Color.LabelPrimary))
        hardcoreIcon.contentMode = .center
        hardcoreContainer.addSubview(hardcoreIcon)
        hardcoreIcon.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
        }
        let hardcoreScoreLabel: UILabel = {
            let view = UILabel()
            view.numberOfLines = 2
            let matt = NSMutableAttributedString(string: R.string.localizable.hardcoreMode(), attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.LabelPrimary])
            matt.append(NSAttributedString(string: "\n" + R.string.localizable.hardcoreDesc(), attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelSecondary]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = R.Size.ContentSpaceTiny/2
            view.attributedText = matt.applying(attributes: [.paragraphStyle: style])
            return view
        }()
        hardcoreContainer.addSubview(hardcoreScoreLabel)
        hardcoreScoreLabel.snp.makeConstraints { make in
            make.centerY.equalTo(hardcoreIcon)
            make.leading.equalTo(hardcoreIcon.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
        }
        hardcoreContainer.addSubview(hardcoreSwitchButton)
        hardcoreSwitchButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
            make.leading.equalTo(hardcoreScoreLabel.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            if #available(iOS 26.0, tvOS 26.0, *) {
                make.size.equalTo(CGSize(width: 63, height: 28))
            } else {
                make.size.equalTo(CGSize(width: 51, height: 31))
            }
        }
        if #available(iOS 26.0, tvOS 26.0, *) {} else {
            hardcoreSwitchButton.transform = CGAffineTransformMakeScale(0.9, 0.9)
        }
        
        let alwaysShowProgressContainer = UIView()
        container.addSubview(alwaysShowProgressContainer)
        alwaysShowProgressContainer.snp.makeConstraints { make in
            make.height.equalTo(R.Size.ItemHeightLarge)
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(hardcoreContainer.snp.bottom)
        }
        let alwaysShowProgressIcon = UIImageView(image: .symbolImage(.squareTextSquareFill).applySymbolConfig(size: 19, color: R.Color.LabelPrimary))
        alwaysShowProgressIcon.contentMode = .center
        alwaysShowProgressContainer.addSubview(alwaysShowProgressIcon)
        alwaysShowProgressIcon.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
        }
        let alwaysShowProgressLabel: UILabel = {
            let view = UILabel()
            view.numberOfLines = 2
            let matt = NSMutableAttributedString(string: R.string.localizable.alwaysShowProgress(), attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.LabelPrimary])
            matt.append(NSAttributedString(string: "\n" + R.string.localizable.alwaysShowProgressDesc(), attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelSecondary]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = R.Size.ContentSpaceTiny/2
            view.attributedText = matt.applying(attributes: [.paragraphStyle: style])
            return view
        }()
        alwaysShowProgressContainer.addSubview(alwaysShowProgressLabel)
        alwaysShowProgressLabel.snp.makeConstraints { make in
            make.centerY.equalTo(alwaysShowProgressIcon)
            make.leading.equalTo(alwaysShowProgressIcon.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
        }
        alwaysShowProgressContainer.addSubview(alwaysShowProgressButton)
        alwaysShowProgressButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
            make.leading.equalTo(alwaysShowProgressLabel.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            if #available(iOS 26.0, tvOS 26.0, *) {
                make.size.equalTo(CGSize(width: 63, height: 28))
            } else {
                make.size.equalTo(CGSize(width: 51, height: 31))
            }
        }
        if #available(iOS 26.0, tvOS 26.0, *) {} else {
            alwaysShowProgressButton.transform = CGAffineTransformMakeScale(0.9, 0.9)
        }
        
        
        let achievementInfoContainer = UIView()
        achievementInfoContainer.layerCornerRadius = R.Size.CornerRadiusLarge
        achievementInfoContainer.backgroundColor = R.Color.BackgroundSecondary
        addSubview(achievementInfoContainer)
        achievementInfoContainer.snp.makeConstraints { make in
            make.height.equalTo(R.Size.ItemHeightLarge*2)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(alwaysShowProgressContainer.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        let achievementCountIcon = SymbolButton(image: R.image.customTrophyFill()?.applySymbolConfig())
        achievementCountIcon.enablePressEffect = false
        achievementInfoContainer.addSubview(achievementCountIcon)
        achievementCountIcon.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.top.equalTo(18)
        }
        achievementInfoContainer.addSubview(achievementsCountLabel)
        achievementsCountLabel.snp.makeConstraints { make in
            make.centerY.equalTo(achievementCountIcon)
            make.leading.equalTo(achievementCountIcon.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.trailing.equalToSuperview()
        }
        let pointIcon = SymbolButton(image: R.image.customFlagPatternCheckered()?.applySymbolConfig())
        pointIcon.enablePressEffect = false
        achievementInfoContainer.addSubview(pointIcon)
        pointIcon.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.top.equalTo(achievementCountIcon.snp.bottom).offset(36)
        }
        achievementInfoContainer.addSubview(pointLabel)
        pointLabel.snp.makeConstraints { make in
            make.centerY.equalTo(pointIcon)
            make.leading.equalTo(pointIcon.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.trailing.equalToSuperview()
        }
        
        let subsetContainer = UIView()
        subsetContainer.enablePressEffect = true
        subsetContainer.isFocusable = true
        subsetContainer.layerCornerRadius = R.Size.CornerRadiusLarge
        subsetContainer.addTapGesture { [weak self] _ in
            self?.handleSubsetTap()
        }
        subsetContainer.onFocusConfirm = { [weak self] in
            self?.handleSubsetTap()
            return true
        }
        subsetContainer.backgroundColor = R.Color.BackgroundSecondary
        addSubview(subsetContainer)
        subsetContainer.snp.makeConstraints { make in
            make.height.equalTo(R.Size.ItemHeightLarge)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(achievementInfoContainer.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        subsetContainer.addSubview(subsetItemView)
        subsetItemView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.bottom.equalToSuperview()
        }
        
        let achievementListLabel = UILabel()
        achievementListLabel.attributedText = NSAttributedString(string: R.string.localizable.achievementsList(), attributes: [.font: R.Font.Footnote(emphasis: true), .foregroundColor: R.Color.LabelSecondary])
        addSubview(achievementListLabel)
        achievementListLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView)
            make.top.equalTo(subsetContainer.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(achievementListLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.height.equalTo(16+(24*2)+50+(64*4)+(16*3))
        }
        
        let bottomLabelContainer = UIView()
        addSubview(bottomLabelContainer)
        bottomLabelContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(listView.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        let bottomLabel = UILabel()
        bottomLabel.attributedText = NSAttributedString(string: R.string.localizable.achievementsMoreDetail(), attributes: [.font : R.Font.Caption(), .foregroundColor: R.Color.Indigo])
        bottomLabelContainer.addSubview(bottomLabel)
        bottomLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        bottomLabelContainer.addSubview(bottomButton)
        bottomButton.snp.makeConstraints { make in
            make.leading.equalTo(bottomLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.top.bottom.trailing.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setDatas(game: Game, retroGame: CheevosGame?) {
        guard let retroGame else { return }
        self.game = game
        self.retroGame = retroGame
        coverImageView.kf.setImage(with: URL(string: retroGame.badgeUrl), placeholder: UIImage.placeHolder(preferenceSize: .init(80)))
        
        applySelectedSubset()
        
        titleLabel.text = retroGame.title ?? game.displayName
        
        if let timeAgo = game.latestPlayDate?.timeAgo() {
            lastActivityLabel.text = R.string.localizable.readyGameInfoSubTitle(timeAgo, Date.timeDuration(milliseconds: Int(game.totalPlayDuration)))
        } else {
            lastActivityLabel.text = R.string.localizable.readyGameInfoNeverPlayed()
        }
        
        enableSwitchButton.setOn(game.enableAchievements, animated: false)
        
        if retroGame.notSupportHardcore {
            hardcoreSwitchButton.isEnabled = false
            hardcoreSwitchButton.setOn(false, animated: false)
            hardcoreSwitchButton.onDisableTap {
                UIView.makeAlert(detail: R.string.localizable.notSupportHardcore(), cancelTitle: R.string.localizable.gotIt())
            }
        } else {
            hardcoreSwitchButton.isEnabled = true
            hardcoreSwitchButton.setOn(game.enableHarcore, animated: false)
            hardcoreSwitchButton.onDisableTap {}
        }
        
        alwaysShowProgressButton.setOn(game.getExtraBool(key: ExtraKey.alwaysShowProgress.rawValue) ?? false, animated: false)
    }
    
    private func currentSubsets() -> [CheevosSubset] {
        retroGame?.subsets ?? []
    }
    
    private func resolvedSubset() -> CheevosSubset? {
        let subsets = currentSubsets()
        if let savedId = game?.getExtraInt(key: ExtraKey.cheevosSubsetId.rawValue),
           let match = subsets.first(where: { $0._id == savedId }) {
            return match
        }
        return subsets.first(where: { $0.isCore }) ?? subsets.first
    }
    
    private func subsetDisplayTitle(_ subset: CheevosSubset?) -> String {
        if let title = subset?.title, !title.isEmpty {
            return title
        }
        return R.string.localizable.achievementsBaseSet()
    }
    
    private func updateSubsetChevronTitle(_ title: String) {
        var styles = subsetItemView.styles
        styles.removeAll(where: {
            if case .chevron = $0 {
                return true
            }
            return false
        })
        styles.append(.chevron(.init(title: title)))
        subsetItemView.styles = styles
    }
    
    private func handleSubsetTap() {
        let subsets = currentSubsets()
        guard subsets.count > 1 else {
            UIView.makeAlert(title: R.string.localizable.focusShortcutsTips(),
                             detail: R.string.localizable.achievementsMultiSetsDesc() + "\n\n" + R.string.localizable.achievementsNoSubset(),
                             cancelTitle: R.string.localizable.cancelTitle(),
                             confirmTitle: R.string.localizable.goToSettings(),
                             confirmAction: { [weak self] in
                guard let self else { return }
                if let retroGame = self.retroGame {
                    UIApplication.shared.open(R.URLs.RetroGame(gameId: retroGame._id))
                } else {
                    UIApplication.shared.open(R.URLs.Retro)
                }
            })
            return
        }
        
        let options = subsets.map({
            let icon: ASIcon
            if let urlString = $0.badgeUrl,
                let url = URL(string: urlString) {
                icon = .imageUrl(url, processSize: CGSize(R.Size.ItemHeightTiny),
                                 cornerStyle: .radius(R.Size.CornerRadiusMicro))
            } else {
                icon = .symbolImage(R.image.retroachievements_iconSymbols())
            }
            return ASListPage.Cell.iconTitleChevronCell(icon: icon,
                                                        iconSize: R.Size.ItemHeightTiny,
                                                        title: subsetDisplayTitle($0))
        })
        
        ChevronSheetView.show(icon: .symbolImage(R.image.retroachievements_iconSymbols()),
                              title: R.string.localizable.achievementsSelectSubset(),
                              detail: R.string.localizable.achievementsMultiSetsDesc() + "\n\n" + R.string.localizable.achievementsMultiSetsGuide(),
                              cellOptions: options,
                              completion: { [weak self] index in
            guard let self, let index, index < subsets.count else { return }
            let subset = subsets[index]
            self.game?.updateExtra(key: ExtraKey.cheevosSubsetId.rawValue, value: subset._id)
            self.applySelectedSubset()
        })
    }
    
    private func applySelectedSubset() {
        guard let retroGame else { return }
        let subset = resolvedSubset()
        updateSubsetChevronTitle(subsetDisplayTitle(subset))
        
        let source: [CheevosAchievement]
        if let subset {
            source = (retroGame.achievements ?? []).filter { $0.subsetId == subset._id }
        } else {
            source = retroGame.achievements ?? []
        }
        
        var achievementCount = 0
        var hardcoreUnlockCount = 0
        var softcoreUnlockCount = 0
        var totalPoints = 0
        var hardcorePoints = 0
        var softcorePoints = 0
        var unlockAchievementCount = 0
        var validAchievements = [CheevosAchievement]()
        for a in source {
            if let badgeName = a.badgeName, badgeName == "00000" {
                continue
            }
            validAchievements.append(a)
            achievementCount += 1
            if a.unlocked {
                unlockAchievementCount += 1
            }
            if a.hardcoreUnlocked {
                hardcoreUnlockCount += 1
                hardcorePoints += a.points
            }
            if a.softcoreUnlocked {
                softcoreUnlockCount += 1
                softcorePoints += a.points
            }
            totalPoints += a.points
        }
        let percentage = achievementCount == 0 ? 0.0 : (Double(unlockAchievementCount) / Double(achievementCount) * 100)
        progressLabel.text = String(format: "%.1f%%", percentage)
        progressView.progress = percentage
        listView.datas = validAchievements.sorted(by: {
            if $0.hardcoreUnlocked {
                return true
            } else if $1.hardcoreUnlocked {
                return false
            }
            return false
        })
        
        achievementsCountLabel.attributedText = {
            let matt = NSMutableAttributedString(string: R.string.localizable.totalAchievements(achievementCount), attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.LabelPrimary])
            matt.append(NSAttributedString(string: "\n" + R.string.localizable.hardcore() + ": ", attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelSecondary]))
            matt.append(NSAttributedString(string: "\(hardcoreUnlockCount)    ", attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.Yellow]))
            matt.append(NSAttributedString(string: R.string.localizable.softcore() + ": ", attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelSecondary]))
            matt.append(NSAttributedString(string: "\(softcoreUnlockCount)", attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.Yellow]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = R.Size.ContentSpaceTiny / 2
            return matt.applying(attributes: [.paragraphStyle: style])
        }()
        pointLabel.attributedText = {
            let matt = NSMutableAttributedString(string: R.string.localizable.totalPoints(totalPoints), attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.LabelPrimary])
            matt.append(NSAttributedString(string: "\n" + R.string.localizable.hardcore() + ": ", attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelSecondary]))
            matt.append(NSAttributedString(string: "\(hardcorePoints)    ", attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.Yellow]))
            matt.append(NSAttributedString(string: R.string.localizable.softcore() + ": ", attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelSecondary]))
            matt.append(NSAttributedString(string: "\(softcorePoints)", attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.Yellow]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = R.Size.ContentSpaceTiny / 2
            return matt.applying(attributes: [.paragraphStyle: style])
        }()
    }
}
