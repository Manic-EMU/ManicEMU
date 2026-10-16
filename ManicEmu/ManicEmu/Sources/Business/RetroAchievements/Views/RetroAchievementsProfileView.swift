//
//  RetroAchievementsProfileView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift

class RetroAchievementsProfileView: BaseView {
    class DetailView: BaseView {
        var didLayoutChange: (() -> Bool)? = nil
        
        private static let avatarSize = 80.0
        
        class UnlockedView: BaseView {
            private let backgroundImageView: UIImageView = {
                let view = UIImageView(image: R.image.retro_unlock_bg())
                view.contentMode = .scaleToFill
                return view
            }()
            
            private let trophyImageView: UIImageView = {
                let view = UIImageView(image: R.image.retro_unlock_tryphy())
                return view
            }()
            
            let countLabel: UILabel = {
                let view = UILabel()
                view.font = R.Font.LargeTitle(emphasis: true)
                view.textColor = R.Color.Yellow
                return view
            }()
            
            override init(frame: CGRect) {
                super.init(frame: frame)
                
                layerCornerRadius = R.Size.CornerRadiusLarge
                
                addSubview(backgroundImageView)
                backgroundImageView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                
                addSubview(countLabel)
                countLabel.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.centerY.equalToSuperview().offset(22.5)
                }
                
                addSubview(trophyImageView)
                trophyImageView.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.bottom.equalTo(countLabel.snp.top).offset(-R.Size.ContentSpaceSmall)
                }
                
                let bottomLabel = UILabel()
                bottomLabel.attributedText = NSAttributedString(string: R.string.localizable.achievementsUnlock(), attributes: [.font: R.Font.Footnote(), .foregroundColor: UIColor.white])
                addSubview(bottomLabel)
                bottomLabel.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.top.equalTo(countLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
                }
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }
        
        var didTapLogout: (() -> Void)? = nil
        
        private let avatarImageView: UIImageView = {
            let view = UIImageView(image: UIImage.placeHolder(preferenceSize: .init(DetailView.avatarSize)))
            view.contentMode = .scaleAspectFill
            view.layerCornerRadius = R.Size.CornerRadiusMedium
            return view
        }()
        
        private let usernameLabel: UILabel = {
            let view = UILabel()
            view.text = "Manic EMU"
            view.font = R.Font.LargeTitle(emphasis: true)
            view.textColor = R.Color.LabelPrimary
            return view
        }()
        
        private let lastActivityIcon = ASIconView(.symbol(.starCircleFill, colors: [R.Color.LabelSecondary]))
        
        private let lastActivityLabel: UILabel = {
            let view = UILabel()
            view.textColor = R.Color.LabelSecondary
            view.font = R.Font.Footnote()
            return view
        }()
        
        private let memberSinceIcon = ASIconView(.symbol(.sparkles, colors: [R.Color.LabelSecondary]))
        
        private let memberSinceLabel: UILabel = {
            let view = UILabel()
            view.textColor = R.Color.LabelSecondary
            view.font = R.Font.Footnote()
            return view
        }()
        
        private lazy var enableGlobalCardView: ASCardView = {
            let view = ASCardView()
            let globalAchievements = Settings.defalut.getExtraBool(key: ExtraKey.globalAchievements.rawValue) ?? false
            let switchState: ASSwitch.State = globalAchievements ? .on : .off
            view.setData(icon: .symbolImage(R.image.controller_iconSymbols(),
                                            colors: [R.Color.Indigo]),
                         iconBackgroundColor: R.Color.Indigo.withAlphaComponent(0.1),
                         iconInsets: .init(inset: R.Size.ContentSpaceExtraSmall),
                         title: R.string.localizable.enableGlobalAchievements(),
                         enableSwitch: true,
                         switchState: switchState, didSwitchChange: { [weak self] value in
                guard let self else { return }
                let realm = Database.realm
                let games = realm.objects(Game.self).where({ !$0.isDeleted })
                Settings.defalut.updateExtra(key: ExtraKey.globalAchievements.rawValue, value: value)
                if value {
                    //开启全局RetroAchievements
                    for game in games {
                        if let enableAchievements = game.getExtraBool(key: ExtraKey.enableAchievements.rawValue), !enableAchievements {
                            game.enableAchievements = true
                        }
                    }
                    self.enableGlobalHardcoreCardView.switchButton.isEnabled = true
                } else {
                    //关闭全局RetroAchievements
                    for game in games {
                        if let enableAchievements = game.getExtraBool(key: ExtraKey.enableAchievements.rawValue), enableAchievements {
                            game.enableAchievements = false
                        }
                        if let achievementsHardcore = game.getExtraBool(key: ExtraKey.achievementsHardcore.rawValue), achievementsHardcore {
                            game.enableHarcore = false
                        }
                    }
                    //硬核模式也一并关闭
                    Settings.defalut.updateExtra(key: ExtraKey.globalHardcore.rawValue, value: false)
                    self.enableGlobalHardcoreCardView.switchButton.isEnabled = false
                    self.enableGlobalHardcoreCardView.switchButton.on = false
                }
            })
            return view
        }()
        
        private lazy var enableGlobalHardcoreCardView: ASCardView = {
            let view = ASCardView()
            
            let globalAchievements = Settings.defalut.getExtraBool(key: ExtraKey.globalAchievements.rawValue) ?? false
            var switchState: ASSwitch.State = .disabled
            if globalAchievements {
                let globalHardcore = Settings.defalut.getExtraBool(key: ExtraKey.globalHardcore.rawValue) ?? false
                switchState = globalHardcore ? .on : .off
            }
            view.setData(icon: .symbolImage(R.image.hardcore_iconSymbols(),
                                            colors: [R.Color.Magenta]),
                         iconBackgroundColor: R.Color.Magenta.withAlphaComponent(0.1),
                         iconInsets: .init(inset: R.Size.ContentSpaceExtraSmall),
                         title: R.string.localizable.globalHardcoreMode(),
                         detail: R.string.localizable.hardcoreDesc(),
                         enableSwitch: true,
                         switchState: switchState, didSwitchChange: { [weak self] value in
                guard let self else { return }
                let realm = Database.realm
                let games = realm.objects(Game.self).where({ !$0.isDeleted })
                Settings.defalut.updateExtra(key: ExtraKey.globalHardcore.rawValue, value: value)
                if value {
                    //开启全局硬核
                    for game in games {
                        if let achievementsHardcore = game.getExtraBool(key: ExtraKey.achievementsHardcore.rawValue), !achievementsHardcore {
                            game.enableHarcore = true
                        }
                    }
                } else {
                    //关闭全局硬核
                    for game in games {
                        if let achievementsHardcore = game.getExtraBool(key: ExtraKey.achievementsHardcore.rawValue), achievementsHardcore {
                            game.enableHarcore = false
                        }
                    }
                }
            }, didSwitchDisableTap: {
                UIView.makeToast(message: R.string.localizable.globalHardcoreAlert())
            })
            
            return view
        }()
        
        private let unlockedView = UnlockedView()
        
        private lazy var logoutButton: ASButtonView = {
            let view = ASButtonView(.extraExtraSmall(title: R.string.localizable.achievementsLogoutTitle(),
                                                     titleColor: R.Color.Red,
                                                     background: R.Color.BackgroundSecondary,
                                                     sizeStyle: .fixHeight(R.Size.ButtonExtraSmall)))
            view.didTapButton = { [weak self] in
                self?.didTapLogout?()
            }
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(avatarImageView)
            avatarImageView.snp.makeConstraints { make in
                make.size.equalTo(DetailView.avatarSize)
                make.leading.equalToSuperview()
                make.top.equalToSuperview()
            }
            
            addSubview(usernameLabel)
            usernameLabel.snp.makeConstraints { make in
                make.leading.equalTo(avatarImageView)
                make.top.equalTo(avatarImageView.snp.bottom).offset(R.Size.ContentSpaceSmall)
            }
            
            addSubview(logoutButton)
            logoutButton.snp.makeConstraints { make in
                make.height.equalTo(R.Size.ItemHeightMicro)
                make.trailing.equalToSuperview()
                make.centerY.equalTo(usernameLabel)
            }
            
            addSubview(lastActivityIcon)
            lastActivityIcon.snp.makeConstraints { make in
                make.size.equalTo(R.Size.IconSizeExtraSmall)
                make.leading.equalTo(avatarImageView)
                make.top.equalTo(usernameLabel.snp.bottom).offset(R.Size.ContentSpaceTiny)
            }
            
            addSubview(lastActivityLabel)
            lastActivityLabel.snp.makeConstraints { make in
                make.centerY.equalTo(lastActivityIcon)
                make.leading.equalTo(lastActivityIcon.snp.trailing).offset(R.Size.ContentSpaceTiny)
                make.trailing.equalToSuperview()
            }
            
            addSubview(memberSinceIcon)
            memberSinceIcon.snp.makeConstraints { make in
                make.size.equalTo(R.Size.IconSizeExtraSmall)
                make.leading.equalTo(avatarImageView)
                make.top.equalTo(lastActivityIcon.snp.bottom).offset(R.Size.ContentSpaceTiny)
            }
            
            addSubview(memberSinceLabel)
            memberSinceLabel.snp.makeConstraints { make in
                make.centerY.equalTo(memberSinceIcon)
                make.leading.equalTo(memberSinceIcon.snp.trailing).offset(R.Size.ContentSpaceTiny)
                make.trailing.equalToSuperview()
            }
            
            addSubviews([enableGlobalCardView, enableGlobalHardcoreCardView, unlockedView])
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            updateViewsConstraits()
        }
        
        func updateViewsConstraits() {
            if didLayoutChange?() ?? false {
                enableGlobalCardView.snp.remakeConstraints { make in
                    make.height.equalTo(R.Size.CardHeight)
                    make.leading.equalToSuperview()
                    make.top.equalTo(memberSinceIcon.snp.bottom).offset(R.Size.ContentSpaceSmall)
                }
                
                enableGlobalHardcoreCardView.snp.remakeConstraints { make in
                    make.height.equalTo(R.Size.CardHeight)
                    make.leading.equalTo(enableGlobalCardView.snp.trailing).offset(R.Size.ContentSpaceSmall)
                    make.top.equalTo(enableGlobalCardView)
                    make.width.equalTo(enableGlobalCardView)
                }
                
                unlockedView.snp.remakeConstraints { make in
                    make.height.equalTo(R.Size.CardHeight)
                    make.leading.equalTo(enableGlobalHardcoreCardView.snp.trailing).offset(R.Size.ContentSpaceSmall)
                    make.trailing.equalToSuperview()
                    make.top.equalTo(enableGlobalCardView)
                    make.width.equalToSuperview().dividedBy(2)
                }
            } else {
                enableGlobalCardView.snp.remakeConstraints { make in
                    make.height.equalTo(R.Size.CardHeight)
                    make.leading.equalToSuperview()
                    make.top.equalTo(memberSinceIcon.snp.bottom).offset(R.Size.ContentSpaceSmall)
                }
                
                enableGlobalHardcoreCardView.snp.remakeConstraints { make in
                    make.height.equalTo(R.Size.CardHeight)
                    make.leading.equalTo(enableGlobalCardView.snp.trailing).offset(R.Size.ContentSpaceMedium)
                    make.trailing.equalToSuperview()
                    make.top.equalTo(enableGlobalCardView)
                    make.width.equalTo(enableGlobalCardView)
                }
                
                unlockedView.snp.remakeConstraints { make in
                    make.height.equalTo(R.Size.CardHeight)
                    make.leading.equalTo(enableGlobalCardView)
                    make.trailing.equalTo(enableGlobalHardcoreCardView)
                    make.top.equalTo(enableGlobalCardView.snp.bottom).offset(R.Size.ContentSpaceMedium)
                }
            }
            
        }
        
        func setData(profile: AchievementsProfile) {
            avatarImageView.kf.setImage(with: URL(string: profile.userPic), placeholder: UIImage.placeHolder(preferenceSize: .init(DetailView.avatarSize)))
            usernameLabel.text = profile.user
            lastActivityLabel.text = R.string.localizable.lastActivity(profile.lastActivityTimestamp)
            memberSinceLabel.text = R.string.localizable.memberSince(profile.memberSince)
            unlockedView.countLabel.text = "\(profile.achievementCount)"
        }
    }
    
    private lazy var detailView: DetailView = {
        let view = DetailView()
        view.didTapLogout = { [weak self] in
            self?.logoutSuccess?()
        }
        view.didLayoutChange = { [weak self] in
            guard let self else { return false }
            return self.prefferedLandscapeStyle
        }
        return view
    }()
    
    private lazy var listPageView: ASListPageView = {
        return ASListPageView(getListPage())
    }()
    
    private lazy var bottomLinkView: UIView = {
        let view = UIView()
        
        let bottomLabelContainer = UIView()
        view.addSubview(bottomLabelContainer)
        bottomLabelContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }
        
        let bottomLabel = UILabel()
        bottomLabel.attributedText = NSAttributedString(string: R.string.localizable.achievementsMoreDetail(),
                                                        attributes: [
                                                            .font : R.Font.Caption(),
                                                            .foregroundColor: R.Color.Indigo])
        bottomLabelContainer.addSubview(bottomLabel)
        bottomLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        
        let button = UIButton(type: .custom)
        button.setAttributedTitle(NSAttributedString(string: "RetroAchievements",
                                                     attributes: [
                                                        .font: R.Font.Footnote(),
                                                        .foregroundColor: R.Color.Indigo
                                                     ]).underlined, for: .normal)
        button.onTap { [weak self] in
            guard let self else { return }
            if !self.username.isEmpty {
                UIApplication.shared.open(R.URLs.RetroProfile(username: self.username))
            } else {
                UIApplication.shared.open(R.URLs.Retro)
            }
        }
        bottomLabelContainer.addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.equalTo(bottomLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        
        return view
    }()
    
    private let username: String
    
    private var retroProfile = AchievementsProfile()
    
    private var detailViewHeight: CGFloat {
        prefferedLandscapeStyle ? 327 : 496.7
    }
    
    var logoutSuccess: (()->Void)? = nil
    
    private var showAsSheet: Bool
    
    private var prefferedLandscapeStyle: Bool {
        if showAsSheet {
            return prefferedLayoutStyle == .landscape
        } else {
            return width > 600
        }
    }
    
    init(username: String, showAsSheet: Bool) {
        self.username = username
        self.showAsSheet = showAsSheet
        super.init(frame: .zero)
        backgroundColor = .clear
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        updateDatas()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(755)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            
            return section
        }
        return layout
    }
    
    private func getListPage() -> ASListPage {
        var sections = [ASListPage.Section]()
        //section 0 detail view
        sections.append(.init(cells: [.custom(detailView)],
                              decoration: .init(enable: false),
                              itemLayout: .fixedHeight(detailViewHeight)))
        
        //section 1 scores
        var cells = [ASListPage.Cell]()
        let hardCore: [ASListPage.Cell.Style] = [
            .icon(.symbolImage(R.image.hardcore_iconSymbols())),
            .title(.largeText(R.string.localizable.hardcoreTitle()),
                   subTitle: .largeText("\(retroProfile.totalHardcorePoints)",
                                        color: R.Color.Yellow),
                   subtitleFollows: true),
            .detail(.extraSmallText(R.string.localizable.hardcoreDesc()))
        ]
        cells.append(.normal(hardCore, enablePressEffect: false))
        
        let softCore: [ASListPage.Cell.Style] = [
            .icon(.symbolImage(R.image.softcore_iconSymbols())),
            .title(.largeText(R.string.localizable.softcoreTitle()),
                   subTitle: .largeText("\(retroProfile.totalSoftcorePoints)",
                                        color: R.Color.Yellow),
                   subtitleFollows: true),
            .detail(.extraSmallText(R.string.localizable.softcoreDesc()))
        ]
        cells.append(.normal(softCore, enablePressEffect: false))
        
        let rankSubtitle: ASText
        if retroProfile.totalRanked > 0 {
            rankSubtitle = .smallText("\(retroProfile.totalRanked)",
                                      color: R.Color.Yellow)
        } else {
            rankSubtitle = .smallText(R.string.localizable.rankRequire(),
                                      color: R.Color.Yellow)
        }
        let rank: [ASListPage.Cell.Style] = [
            .icon(.symbolImage(R.image.rank_iconSymbols())),
            .title(.largeText(R.string.localizable.rankTitle()),
                   subTitle: rankSubtitle,
                   subtitleFollows: true)
        ]
        cells.append(.normal(rank, enablePressEffect: false))
        sections.append(.init(cells: cells))
        
        //section 2
        sections.append(.init(cells: [.custom(bottomLinkView)],
                              decoration: .init(enable: false),
                              itemLayout: .fixedHeight(R.Size.IconSizeExtraSmall.height)))
        
        return ASListPage(sections: sections,
                          backgroundColor: .clear,
                          listInsets: .insets(top: R.Size.NavigationHeight - R.Size.ContentSpaceSmall,
                                              bottom: R.Size.ContentInsetBottom(window: hostingWindow) + (!showAsSheet ? R.Size.HomeTabBarSize.height + R.Size.ContentSpaceMedium : 0)))
    }
    
    private func updateDatas() {
        if let url = URL(string: "https://retroachievements.org/API/API_GetUserSummary.php?u=\(username)&y=\(R.Cipher.RetroAPI)&g=5&a=1") {
            UIView.makeLoading()
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    UIView.hideLoading()
                    if let data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       json["errors"] == nil {
                        self.retroProfile = self.decode(json: json)
                        self.detailView.setData(profile: self.retroProfile)
                        self.listPageView.updatePage(self.getListPage())
                    } else {
                        UIView.makeToast(message: R.string.localizable.achievementsDataLoadFail())
                    }
                }
            }.resume()
        }
    }
    
    private func decode(json: [String: Any]) -> AchievementsProfile {
        var userPic = ""
        if let pic = json["UserPic"] as? String {
            userPic = "https://media.retroachievements.org\(pic)"
        }
        var lastActivityTimestamp = ""
        if let recentlyPlayeds = json["RecentlyPlayed"] as? [[String: Any]],
           let first = recentlyPlayeds.first,
           let lastPlayedTime = first["LastPlayed"] as? String,
           let lastPlayedTimeFormated = lastPlayedTime.date(withFormat: "yyyy-MM-dd HH:mm:ss")?.timeAgo() {
            lastActivityTimestamp = lastPlayedTimeFormated
        }
        var memberSince = ""
        if let memberSinceString = json["MemberSince"] as? String,
           let dateString = memberSinceString.dateTime?.dateString() {
            memberSince = dateString
        }
        var achievementCount = 0
        if let awarded = json["Awarded"] as? [String: [String: Any]] {
            for value in awarded.values {
                if let numAchieved = value["NumAchieved"] as? Int {
                    achievementCount += numAchieved
                }
            }
        }
        let totalSoftcorePoints = (json["TotalSoftcorePoints"] as? Int) ?? 0
        let totalHardcorePoints = (json["TotalPoints"] as? Int) ?? 0
        let rank = (json["Rank"] as? Int) ?? 0
        
        return AchievementsProfile(userPic: userPic,
                                   user: username,
                                   lastActivityTimestamp: lastActivityTimestamp,
                                   memberSince: memberSince,
                                   achievementCount: achievementCount,
                                   totalSoftcorePoints: totalSoftcorePoints,
                                   totalHardcorePoints: totalHardcorePoints,
                                   totalRanked: rank)
    }
}

extension RetroAchievementsProfileView: ViewTransition {
    func viewWillTransition() {
        detailView.updateViewsConstraits()
        listPageView.updateSectionData(.init(cells: [.custom(detailView)],
                                             decoration: .init(enable: false),
                                             itemLayout: .fixedHeight(detailViewHeight)),
                                       section: 0)
    }
}
