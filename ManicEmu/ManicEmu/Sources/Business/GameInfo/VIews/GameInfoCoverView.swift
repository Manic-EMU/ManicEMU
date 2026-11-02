//
//  GameInfoCoverView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import IceCream
import Kingfisher

class GameInfoCoverView: BaseView {
    var maskTopView: UIView = {
        let view = UIView()
        view.backgroundColor = R.Color.BackgroundPrimary
        view.alpha = 0
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private var backgroundGradientView: UIView = {
        let view = GradientView()
        view.setupGradient(colors: [.clear, R.Color.BackgroundPrimary], locations: [0.0, 1.0], direction: .topToBottom)
        return view
    }()
    
    private var coverContainerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = R.Size.CornerRadiusLarge
        view.makeShadow(ofColor: R.Color.BackgroundPrimary.forceStyle(.dark), radius: 30)
        return view
    }()
    
    private var coverImageView: GameCoverView = {
        let view = GameCoverView()
        return view
    }()
    
    private var game: Game
    private var bitbopOffer: BitBopKit.CoverOffer = .hidden
    private var CoverImageSize: CGSize = .init(UIDevice.isPhone ? 236.0 : 200.0)
    
    private lazy var bitbopButton: ASButtonView = {
        let view = ASButtonView(.iconOnlyWithSmallSize(icon: .symbolImage(R.image.bitbop_iconSymbols(),
                                                                           colors: [R.Color.LabelPrimary.forceStyle(.dark)]),
                                                       background: R.Color.Main))
        view.cornerStyle = .circle
        view.isHidden = true
        view.accessibilityLabel = R.string.localizable.listenWithBitBop()
        view.didTapButton = { [weak self] in
            guard let self, self.bitbopOffer.showsButton else { return }
            UIDevice.generateHaptic()
            // Re-check at tap time so a library alert is not shown after BitBop has been removed.
            let offer: BitBopKit.CoverOffer = BitBopKit.isBitBopInstalled ? self.bitbopOffer : .send(scansCartridge: false)
            BitBopKit.presentCoverOffer(offer, for: self.game, in: self.hostingWindowScene)
        }
        return view
    }()
    
    
    init(game: Game) {
        self.game = game
        super.init(frame: .zero)
        backgroundColor = R.Color.BackgroundPrimary
        
        addSubview(backgroundGradientView)
        backgroundGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
         
        if R.Style.GameCoverStyle == .style1 {
            let ratio = R.Size.GameCoverRatio(gameType: game.gameType)
            if ratio == 1.0 {
                //正方形
            } else if ratio < 1.0 {
                //竖大于横
                CoverImageSize = CGSize(width: CoverImageSize.height * ratio, height: CoverImageSize.height)
            } else {
                //横大于竖
                CoverImageSize = CGSize(width: CoverImageSize.width, height: CoverImageSize.width/ratio)
            }
        }
        
        addSubview(coverContainerView)
        updateCoverContainerViewConstraints()
        
        coverContainerView.addSubview(coverImageView)
        coverImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        coverImageView.setData(game: game,
                               coverSize: CoverImageSize,
                               style: R.Style.GameCoverStyle,
                               scalePlatform: false)
        coverImageView.imageView.setGameCover(game: game, size: CoverImageSize) { [weak self] image in
            self?.backgroundGradientView.backgroundColor = image.dominantBackground
        }
        coverImageView.layoutSubviews()
        
        addSubview(maskTopView)
        maskTopView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if game.gameType.supportBitBop {
            addSubview(bitbopButton)
            bitbopButton.snp.makeConstraints { make in
                make.top.equalTo(coverContainerView).offset(R.Size.ContentSpaceExtraSmall)
                make.trailing.equalTo(coverContainerView).offset(-R.Size.ContentSpaceExtraSmall)
            }
            refreshBitBopButton()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateImage(_ image: UIImage) {
        coverImageView.imageView.image = image
        backgroundGradientView.backgroundColor = image.dominantBackground
    }
    
    func updateRating() {
        coverImageView.updateRating(esrp: GameMetadata.getGameMetadata(game: game)?.ESRPRating)
    }
    
    /// The options list is transparent over the cover and sits above this view, so it steals taps on the lower half of the button.
    func bitbopButton(at point: CGPoint, with event: UIEvent?) -> UIView? {
        guard game.gameType.supportBitBop, !bitbopButton.isHidden, bitbopButton.alpha > 0.01 else { return nil }
        let local = bitbopButton.convert(point, from: self)
        guard bitbopButton.point(inside: local, with: event) else { return nil }
        return bitbopButton.hitTest(local, with: event)
    }
    
    /// Sits on the cover art so it stays clear of the navigation close button.
    private func refreshBitBopButton() {
        let gameType = game.gameType
        let romURL = game.romUrl
        let bitbopInstalled = BitBopKit.isBitBopInstalled
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let offer = BitBopKit.prepareCoverOffer(gameType: gameType, romURL: romURL, bitbopInstalled: bitbopInstalled)
            DispatchQueue.main.async {
                guard let self else { return }
                self.bitbopOffer = offer
                self.bitbopButton.isHidden = !offer.showsButton
            }
        }
    }
    
    private func updateCoverContainerViewConstraints() {
        coverContainerView.snp.remakeConstraints { make in
            make.size.equalTo(proHUDLayoutStyle() == .landscape ? CoverImageSize.applying(.init(scaleX: 0.8, y: 0.8)) : CoverImageSize)
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(proHUDLayoutStyle() == .landscape ? -R.Size.ItemHeightLarge : -R.Size.ItemHeightMicro)
        }
    }
}

extension GameInfoCoverView: ViewTransition {
    func viewAlongsideTransition() {
        if UIDevice.isPhone {
            updateCoverContainerViewConstraints()
        }
    }
}
