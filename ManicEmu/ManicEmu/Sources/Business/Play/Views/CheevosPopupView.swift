//
//  CheevosPopupView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/9/10.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ProHUD
import Kingfisher

class CheevosPopupAchievementCell: UICollectionViewCell {
    private let containerView: RoundAndBorderView = {
        let view = RoundAndBorderView(roundCorner: .allCorners, radius: R.Size.CornerRadiusMedium, borderColor: R.Color.Border, borderWidth: 1)
        view.backgroundColor = R.Color.BackgroundSecondary
        return view
    }()
    
    private let infoContainerView = UIView()
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layerCornerRadius = 4
        return view
    }()
    
    private let titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 2
        return view
    }()
    
    private let progressView = RetroAchievementsListCell.AchievementsProgressView()
    
    private let progressLabel: UILabel = {
        let view = UILabel()
        view.font = R.Font.Caption()
        view.textColor = R.Color.Yellow
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(containerView)
        enablePressEffect = true
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.size.equalTo(50)
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
        }
        
        containerView.addSubview(infoContainerView)
        infoContainerView.snp.makeConstraints { make in
            make.centerY.equalTo(imageView)
            make.leading.equalTo(imageView.snp.trailing).offset(R.Size.ContentSpaceSmall)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
        }
        
        infoContainerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-18)
        }
        
        infoContainerView.addSubview(progressLabel)
        progressLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        infoContainerView.addSubview(progressView)
        progressView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalTo(progressLabel)
            make.trailing.equalTo(progressLabel.snp.leading).offset(-R.Size.ContentSpaceSmall)
            make.height.equalTo(2)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(achievement: CheevosAchievement) {
        imageView.kf.setImage(with: URL(string: achievement.unlockedBadgeUrl), placeholder: UIImage.placeHolder(preferenceSize: .init(40)))
        
        let matt = NSMutableAttributedString(string: achievement.title ?? "", attributes: [.font: R.Font.Body(), .foregroundColor: R.Color.LabelPrimary])
        matt.append(NSAttributedString(string: "\n\(achievement._description ?? "")", attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.LabelSecondary]))
        let style = NSMutableParagraphStyle()
        style.lineSpacing = R.Size.ContentSpaceTiny/2
        style.alignment = .left
        titleLabel.attributedText = matt.applying(attributes: [.paragraphStyle: style])
        
        if let measuredProgress = achievement.measuredProgress, !measuredProgress.isEmpty {
            progressView.progress = achievement.measuredPercent
            progressLabel.text = measuredProgress
            progressView.isHidden = false
            progressLabel.isHidden = false
            titleLabel.snp.updateConstraints { make in
                make.bottom.equalToSuperview().offset(-18)
            }
        } else {
            progressView.isHidden = true
            progressLabel.isHidden = true
            titleLabel.snp.updateConstraints { make in
                make.bottom.equalToSuperview().offset(0)
            }
        }
    }
}

class CheevosPopupLeaderboardCell: UICollectionViewCell {
    private let containerView: RoundAndBorderView = {
        let view = RoundAndBorderView(roundCorner: .allCorners, radius: R.Size.CornerRadiusMedium, borderColor: R.Color.Border, borderWidth: 1)
        view.backgroundColor = R.Color.BackgroundSecondary
        return view
    }()
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layerCornerRadius = 4
        return view
    }()
    
    private let titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 2
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.size.equalTo(40)
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
        }
        
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(imageView.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(leaderboard: CheevosLeaderboard) {
        if let badgeUrl = leaderboard.badgeUrl {
            imageView.kf.setImage(with: URL(string: badgeUrl), placeholder: UIImage.placeHolder(preferenceSize: .init(40)))
        } else {
            imageView.image = leaderboard.image
        }
        
        let matt = NSMutableAttributedString(string: leaderboard.title ?? "", attributes: [.font: R.Font.Body(), .foregroundColor: UIColor.white])
        matt.append(NSAttributedString(string: "\n\(leaderboard._description ?? "")", attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.LabelSecondary]))
        let style = NSMutableParagraphStyle()
        style.lineSpacing = R.Size.ContentSpaceTiny/2
        style.alignment = .left
        titleLabel.attributedText = matt.applying(attributes: [.paragraphStyle: style])
    }
}

enum CheevosPopupViewType {
    case leaderboard, progress, challenge
}

class CheevosPopupView: BaseView {
    private lazy var navigationView: ASNavigationView = {
        let title: String
        switch type {
        case .leaderboard:
            title = R.string.localizable.leaderboard()
        case .progress:
            title = R.string.localizable.progress()
        case .challenge:
            title = R.string.localizable.challenge()
        }
        let view = ASNavigationView(.defaultNavigation(title: title, titleIcon: .symbolImage(R.image.retroachievements_iconSymbols(),
                                                                                             colors: [R.Color.Indigo, R.Color.Yellow])))
        view.didTapClose = { [weak self] in
            self?.hide()
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: CheevosPopupLeaderboardCell.self)
        view.register(cellWithClass: CheevosPopupAchievementCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.allowsSelection = true
        view.allowsMultipleSelection = false
        view.contentInset = .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        return view
    }()

    private var leaderBoards: [CheevosLeaderboard] = []
    
    private var achievements: [CheevosAchievement] = []
    
    
    private var hideCompletion: (()->Void)? = nil
    
    let type: CheevosPopupViewType
    
    required init?(parameters: Any...) {
        guard let type = parameters.compactMap({ $0 as? CheevosPopupViewType }).first else { return nil }
        self.type = type
        super.init(frame: .zero)
        
        let leaderBoards = parameters.compactMap({ $0 as? [CheevosLeaderboard] }).first
        let achievements = parameters.compactMap({ $0 as? [CheevosAchievement] }).first
        
        switch type {
        case .leaderboard:
            guard let leaderBoards, leaderBoards.count > 0 else { return }
        case .progress, .challenge:
            guard let achievements, achievements.count > 0 else { return }
        }
        
        if type == .leaderboard {
            self.leaderBoards = leaderBoards ?? []
        } else {
            self.achievements = achievements ?? []
        }

        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalTo(navigationView.snp.bottom)
            make.bottom.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout  { [weak self] sectionIndex, env in
            guard let self else { return nil }
            
            let height = self.type == .leaderboard ? 64 : R.Size.ItemHeightExtraLarge
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                              heightDimension: .absolute(height)),
                                                           subitem: item,
                                                           count: Int(1))
            
            group.interItemSpacing = NSCollectionLayoutSpacing.fixed(R.Size.ContentSpaceMedium)
            
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = R.Size.ContentSpaceMedium

            section.contentInsets = NSDirectionalEdgeInsets(top: R.Size.ContentSpaceMedium,
                                                            leading: R.Size.ContentSpaceMedium,
                                                            bottom: R.Size.ContentSpaceMedium,
                                                            trailing: R.Size.ContentSpaceMedium)
            
            return section
        }
        return layout
    }
}

extension CheevosPopupView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        type == .leaderboard ? leaderBoards.count : achievements.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if type == .leaderboard {
            let cell = collectionView.dequeueReusableCell(withClass: CheevosPopupLeaderboardCell.self, for: indexPath)
            cell.setData(leaderboard: leaderBoards[indexPath.row])
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: CheevosPopupAchievementCell.self, for: indexPath)
            cell.setData(achievement: achievements[indexPath.row])
            return cell
        }
    }
}

extension CheevosPopupView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard type == .challenge || type == .progress else { return }
        RetroAchievementsDetailView.show(achievement: achievements[indexPath.row])
    }
}

extension CheevosPopupView: ShowableView {
    
    static func show(type: CheevosPopupViewType,
                     leaderboards: [CheevosLeaderboard]? = nil,
                     achievements: [CheevosAchievement]? = nil,
                     hideCompletion: (()->Void)? = nil) {
        if let leaderboards {
            Self.show(parameters: type, leaderboards)?.hideCompletion = hideCompletion
        } else if let achievements {
            Self.show(parameters: type, achievements)?.hideCompletion = hideCompletion
        }
    }
    
    func didHide() {
        hideCompletion?()
    }
    
    var prefferdConstraintHeight: CGFloat? {
        switch type {
        case .leaderboard:
            var height = R.Size.SheetGrabberTopInset + R.Size.NavigationHeight
            height += CGFloat(leaderBoards.count) * 64
            height += CGFloat(leaderBoards.count + 1) * R.Size.ContentSpaceMedium
            height += R.Size.ContentInsetBottom(window: hostingWindow)
            return height
            
        case .progress, .challenge:
            var height = R.Size.SheetGrabberTopInset + R.Size.NavigationHeight
            height += CGFloat(achievements.count) * R.Size.ItemHeightExtraLarge
            height += CGFloat(achievements.count + 1) * R.Size.ContentSpaceMedium
            height += R.Size.ContentInsetBottom(window: hostingWindow)
            return height
        }
    }
}
