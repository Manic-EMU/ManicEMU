//
//  SettingsAdventureCardView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/24.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import IceCream
import RealmSwift

class SettingsAdventureCardView: BaseView {
    
    private static let avatarSize = CGSize(100)
    private let titleLabel = ASLabelView(text: .init(attributes: .init(text: R.string.localizable.adventurerCard(),
                                                                       color: R.Color.LabelSecondary,
                                                                       font: R.Font.Subheadline(emphasis: true))))
    private let nicknameRow = AdventureInfoRowView()
    private let playDurationRow = AdventureInfoRowView()
    private let joinDateRow = AdventureInfoRowView()
    
    private lazy var avatarView: UIImageView = {
        let view = UIImageView(image: R.image.avatar())
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = R.Color.BackgroundPrimary
        view.layerCornerRadius = Self.avatarSize.width / 2
        view.layerBorderColor = R.Color.Border
        view.layerBorderWidth = R.Size.Border
        view.isUserInteractionEnabled = true
        view.enablePressEffect = true
        view.enableFocusEffects = false
        return view
    }()
    
    private var games: Results<Game>?
    private var gamesUpdateToken: NotificationToken?
    private var settingsUpdateToken: NotificationToken?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layerCornerRadius = R.Size.CornerRadiusLarge
        backgroundColor = R.Color.BackgroundSecondary
        setupViews()
        observeData()
        reloadAll()
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        avatarView.layerBorderColor = R.Color.Border
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        nicknameRow.enablePressEffect = true
        nicknameRow.addTapGesture { [weak self] _ in
            self?.editNickname()
        }
        avatarView.addTapGesture { [weak self] _ in
            self?.pickAvatar()
        }
        
        let infoStack = UIStackView(arrangedSubviews: [nicknameRow, playDurationRow, joinDateRow])
        infoStack.axis = .vertical
        infoStack.distribution = .fillEqually
        infoStack.spacing = R.Size.ContentSpaceExtraSmall
        infoStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        infoStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let titleLabelContainer = UIView()
        titleLabelContainer.backgroundColor = R.Color.BackgroundTertiary
        titleLabelContainer.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
        }
        
        addSubviews([titleLabelContainer, infoStack, avatarView])
        
        titleLabelContainer.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightTiny)
        }
        
        avatarView.snp.makeConstraints { make in
            make.size.equalTo(Self.avatarSize)
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.centerY.equalTo(infoStack)
        }
        
        infoStack.snp.makeConstraints { make in
            make.top.equalTo(titleLabelContainer.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.bottom.equalToSuperview().inset(R.Size.ContentSpaceSmall)
            make.trailing.equalTo(avatarView.snp.leading).offset(-R.Size.ContentSpaceSmall)
        }
    }
    
    /// 监听游戏时长与设置中的头像 / extras 变化
    private func observeData() {
        let games = Database.realm.objects(Game.self).where { !$0.isDeleted }
        self.games = games
        gamesUpdateToken = games.observe(keyPaths: [\Game.totalPlayDuration]) { [weak self] changes in
            guard let self else { return }
            if case .update(_, let deletes, let insertions, let modifications) = changes,
               !deletes.isEmpty || !insertions.isEmpty || !modifications.isEmpty {
                self.reloadPlayDuration()
            }
        }
        
        settingsUpdateToken = Settings.defalut.observe(keyPaths: [\Settings.avatar, \Settings.extras]) { [weak self] change in
            guard let self else { return }
            if case .change = change {
                self.reloadAvatar()
                self.reloadNickname()
                self.reloadJoinDate()
            }
        }
    }
    
    // MARK: - Reload
    
    private func reloadAll() {
        reloadAvatar()
        reloadNickname()
        reloadPlayDuration()
        reloadJoinDate()
    }
    
    private func reloadAvatar() {
        if let data = Settings.defalut.avatar?.storedData(), let image = UIImage(data: data) {
            avatarView.image = image
        } else {
            avatarView.image = R.image.avatar()
        }
    }
    
    private func reloadNickname() {
        nicknameRow.setText("\(R.string.localizable.nickname()): \(Settings.nickname)")
    }
    
    private func reloadPlayDuration() {
        let total = (games ?? Database.realm.objects(Game.self).where { !$0.isDeleted })
            .reduce(0.0) { $0 + $1.totalPlayDuration }
        let totalString = total > 0 ? Date.timeDuration(milliseconds: Int(total)) : R.string.localizable.readyGameInfoNeverPlayed()
        playDurationRow.setText("\(R.string.localizable.gameTime()): \(totalString)")
    }
    
    private func reloadJoinDate() {
        joinDateRow.setText("\(R.string.localizable.joinTime()): \(resolvedJoinDate().dateString(ofStyle: .medium))")
    }
    
    // MARK: - Actions
    
    private func pickAvatar() {
        var sources: [ImageFetcher.Source] = [.capture, .library, .file]
        if let data = Settings.defalut.avatar?.storedData(), let image = UIImage(data: data) {
            sources.append(.editImage(image))
        }
        ImageFetcher.showCommonFetcher(sources: sources, in: hostingWindowScene) { [weak self] image, _ in
            guard let self, let image else { return }
            self.persistAvatar(image)
        }
    }
    
    private func persistAvatar(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        Settings.change { realm in
            Settings.defalut.avatar?.deleteAndClean(realm: realm)
            Settings.defalut.avatar = CreamAsset.create(objectID: Settings.defaultName, propName: "avatar", data: data)
        }
        reloadAvatar()
    }
    
    private func editNickname() {
        LimitedTextInputView.show(title: R.string.localizable.nickname(),
                                  text: Settings.nickname,
                                  placeholder: Settings.defaultNickname,
                                  limitedType: .normal(maxTextSize: 30)) { [weak self] result in
            guard let nickname = result as? String else { return }
            Settings.defalut.updateExtra(key: ExtraKey.nickname.rawValue, value: nickname)
            self?.reloadNickname()
        }
    }
    
    // MARK: - Data
    
    /// 优先读 extras；否则取沙盒创建时间与最早游戏导入时间中更早的一个并写入 extras
    private func resolvedJoinDate() -> Date {
        if let timestamp = Settings.defalut.getExtraDouble(key: ExtraKey.joinDate.rawValue) {
            return Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = Settings.defalut.getExtraInt(key: ExtraKey.joinDate.rawValue) {
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }
        
        var candidates = [Date]()
        if let attributes = try? FileManager.default.attributesOfItem(atPath: NSHomeDirectory()),
           let creationDate = attributes[.creationDate] as? Date {
            candidates.append(creationDate)
        }
        if let earliestImport = Database.realm.objects(Game.self).sorted(by: \Game.importDate).first?.importDate {
            candidates.append(earliestImport)
        }
        
        let joinDate = candidates.min() ?? Date()
        Settings.defalut.updateExtra(key: ExtraKey.joinDate.rawValue, value: joinDate.timeIntervalSince1970)
        return joinDate
    }
}

// MARK: - AdventureInfoRowView

private class AdventureInfoRowView: BaseView {
    
    private let gradientLayer = CAGradientLayer()
    private let accentView = UIView()
    private let labelView = ASLabelView(text: .smallText("", color: R.Color.LabelPrimary))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)
        updateGradientColors()
        
        accentView.backgroundColor = R.Color.Yellow
        
        addSubviews([accentView, labelView])
        accentView.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.width.equalTo(3)
        }
        labelView.snp.makeConstraints { make in
            make.leading.equalTo(accentView.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        layerCornerRadius = R.Size.CornerRadiusMicro
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        updateGradientColors()
    }
    
    func setText(_ text: String) {
        labelView.text = .smallText(text, color: R.Color.LabelPrimary)
    }
    
    private func updateGradientColors() {
        let start = R.Color.BackgroundTertiary.resolvedColor(with: traitCollection)
        gradientLayer.colors = [start.cgColor, start.withAlphaComponent(0).cgColor]
    }
}
