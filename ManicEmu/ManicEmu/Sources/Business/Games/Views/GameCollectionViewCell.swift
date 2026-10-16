//
//  GameCollectionViewCell.swift
//  ManicReader
//
//  Created by Max on 2025/1/2.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import MarqueeLabel


class GameCollectionViewCell: UICollectionViewCell {
    
    private var gameType: GameType? = nil
    private var lastFrame: CGRect? = nil
    private var indexPath: IndexPath = IndexPath(row: 0, section: 0)
    
    var imageView: GameCoverView = {
        let view = GameCoverView()
        return view
    }()
    
    private var titleLabel: MarqueeLabel = {
        let view = MarqueeLabel()
        view.textAlignment = .center
        return view
    }()
    
    private var selectImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.layerCornerRadius = R.Size.IconSizeMedium.height/2
        view.layer.shadowColor = R.Color.Shadow.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowRadius = 2
        return view
    }()
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            selectImageView.layer.shadowColor = R.Color.Shadow.cgColor
        }
    }
    
    private var selectedBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(.dm,
                                       light: R.Color.BackgroundPrimary.forceStyle(.dark),
                                       dark: R.Color.BackgroundPrimary.forceStyle(.light))
        view.layerCornerRadius = R.Size.CornerRadiusLarge
        return view
    }()
    
    override var isSelected: Bool {
        willSet {
            if newValue {
                self.selectImageView.image = UIImage(symbol: .checkmarkCircleFill,
                                                     size: R.Size.IconSizeMedium.height,
                                                     weight: .bold,
                                                     colors: [R.Color.LabelPrimary, R.Color.Main])
                self.selectedBackground.alpha = 1
            } else {
                self.selectImageView.image = UIImage(symbol: .circle,
                                                     size: R.Size.IconSizeMedium.height,
                                                     color: R.Color.LabelPrimary.forceStyle(.dark))
                self.selectedBackground.alpha = 0
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        enablePressEffect = true
        enableFocusEffects = false
        
        contentView.addSubview(selectedBackground)
        selectedBackground.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        selectedBackground.alpha = 0
        
        contentView.addSubview(imageView)
        
        imageView.addSubview(selectImageView)
        selectImageView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
            make.size.equalTo(R.Size.IconSizeMedium)
        }
        selectImageView.alpha = 0
        self.isSelected = false
        
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.GamesListSelectionEdge)
            make.bottom.equalToSuperview().offset(-R.Size.GamesListSelectionEdge).priority(.required)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(game: Game,
                 isSelect: Bool = false,
                 highlightString: String? = nil,
                 coverSize: CGSize,
                 showTitle: Bool = true,
                 indexPath: IndexPath) {
        self.indexPath = indexPath
        gameType = game.gameType
        titleLabel.isHidden = !showTitle
        titleLabel.attributedText = NSAttributedString(string: game.displayName, attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.LabelSecondary]).highlightString(highlightString)
        imageView.setData(game: game,
                          coverSize: coverSize,
                          style: R.Style.GameCoverStyle)
        imageView.frame = CGRect(origin: CGPoint(x: R.Size.GamesListSelectionEdge, y: R.Size.GamesListSelectionEdge), size: coverSize)
        updateViews(isSelect: isSelect)
    }
    
    func updateViews(isSelect: Bool) {
        self.selectImageView.alpha = isSelect ? 1 : 0
    }
}
