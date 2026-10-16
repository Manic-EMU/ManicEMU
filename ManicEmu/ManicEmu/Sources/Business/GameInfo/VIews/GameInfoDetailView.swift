//
//  GameInfoDetailView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/8.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class GameInfoDetailView: BaseView {
    /// Display-only title. Avoid UITextField here: after PlayVC teardown, TextKit2
    /// UIFieldEditor layout can EXC_BAD_ACCESS when a new text field lays out.
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = game.displayName
        label.textColor = R.Color.LabelPrimary
        label.font = R.Font.Headline(emphasis: true)
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private lazy var editTitleButton: ASButtonView = {
        let view = ASButtonView(.iconOnly(icon: .symbolImage(R.image.renameRegular_iconSymbols()),
                                          iconSize: R.Size.IconSizeMedium,
                                          background: .clear))
        view.didTapButton = { [weak self] in
            guard let self = self else { return }
            self.beginRename()
        }
        return view
    }()
    
    private let subtitleIcon: UIImageView = {
        let view = UIImageView()
        view.image = .symbolImage(.starCircleFill).applySymbolConfig(color: R.Color.LabelSecondary)
        return view
    }()
    
    private let subtitleLabel: UILabel = {
        let view = UILabel()
        view.textColor = R.Color.LabelSecondary
        view.font = R.Font.Footnote()
        return view
    }()
    
    lazy var startGameButton: ASButtonView = {
        let view = ASButtonView(.extraLarge(icon: .symbol(.playFill, colors: [R.Color.LabelPrimary.forceStyle(.dark)]),
                                            title: R.string.localizable.play(),
                                            titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                            background: R.Color.Main,
                                            sizeStyle: .fixHeight(R.Size.ButtonLarge,
                                                                  insets: .init(horizontal: R.Size.ItemHeightMedium*2,
                                                                                vertical: R.Size.ContentSpaceSmall*2))))
        view.enableFocusEffects = false
        view.didTapButton = { [weak self] in
            guard let self = self else { return }
            self.game.handleTapAction(forceQuick: true, in: self.hostingWindowScene)
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.startGameTitle()
        view.accessibilityTraits = .button
        return view
    }()
    
    private lazy var safeModeButton: ASButtonView = {
        let view = ASButtonView(.quickButton(icon: .symbol(.arrowUpRight,
                                                           colors: [R.Color.Main]) ,
                                             title: R.string.localizable.safeMode(),
                                             titleColor: R.Color.Main,
                                             titleFont: R.Font.Footnote(emphasis: true),
                                             titlePosition: .left,
                                             background: .clear,
                                             sizeStyle: .fixHeight(R.Size.IconSizeExtraSmall.height)))
        view.didTapButton = { [weak self] in
            guard let self = self else { return }
            UIDevice.generateHaptic()
            UIView.makeAlert(title: R.string.localizable.safeMode(),
                             detail: R.string.localizable.safeModeDesc(),
                             confirmTitle: R.string.localizable.confirmTitle(),
                             confirmAction: { [weak self] in
                guard let self else { return }
                self.game.safeMode = true
                self.game.handleTapAction(forceQuick: true, in: self.hostingWindowScene)
            })
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = R.string.localizable.safeMode()
        view.accessibilityTraits = .button
        return view
    }()
    
    private let game: Game
    
    init(game: Game) {
        self.game = game
        super.init(frame: .zero)
        
        let titleContainer = UIView()
        addSubview(titleContainer)
        titleContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        titleContainer.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        titleContainer.addSubview(editTitleButton)
        editTitleButton.snp.makeConstraints { make in
            make.size.equalTo(R.Size.IconSizeMedium)
            make.top.trailing.bottom.equalToSuperview()
            make.leading.equalTo(titleLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
        }
        
        let subtitleContainer = UIView()
        addSubview(subtitleContainer)
        subtitleContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleContainer.snp.bottom).offset(R.Size.ContentSpaceTiny)
            make.width.lessThanOrEqualToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        subtitleContainer.addSubview(subtitleIcon)
        subtitleIcon.snp.makeConstraints { make in
            make.size.equalTo(R.Size.IconSizeSmall)
            make.leading.top.bottom.equalToSuperview()
        }
        subtitleContainer.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(subtitleIcon.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.trailing.equalToSuperview()
        }
        if let timeAgo = game.latestPlayDate?.timeAgo() {
            subtitleLabel.text = R.string.localizable.readyGameInfoSubTitle(timeAgo, Date.timeDuration(milliseconds: Int(game.totalPlayDuration)))
        } else {
            subtitleLabel.text = R.string.localizable.readyGameInfoNeverPlayed()
        }
        
        addSubview(startGameButton)
        startGameButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(subtitleContainer.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        addSubview(safeModeButton)
        safeModeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(startGameButton.snp.bottom).offset(R.Size.ContentSpaceExtraExtraSmall)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Present rename UI. Prefer a separate alert over inline UITextField (shared UIFieldEditor / TextKit2 crash after Play).
    func beginRename() {
        LimitedTextInputView.show(icon: .symbolImage(R.image.renameRegular_iconSymbols()),
                                  title: R.string.localizable.gamesRename(),
                                  text: game.displayName,
                                  limitedType: .normal(maxTextSize: R.Size.GameNameMaxCount),
                                  confirmAction: { [weak self] result in
            guard let self, let text = (result as? String)?.trimmed else { return }
            if text.isEmpty {
                UIView.makeToast(message: R.string.localizable.readyEditTitleFailed())
                return
            }
            if text != self.game.aliasName {
                Game.change { _ in
                    self.game.aliasName = text
                }
                self.titleLabel.text = text
            }
        })
    }
}
