//
//  GameCoverView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/4.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import Kingfisher

class GameCoverView: BaseView {
    private var gameCoverChangeNotification: Any? = nil
    
    
    var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.backgroundColor = R.Color.CoverEmpty
        return view
    }()
    
    private var platformView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.backgroundColor = R.Color.CoverSide
        view.isHidden = true
        return view
    }()
    
    private var ratingView: ASIconView = {
        let view = ASIconView()
        return view
    }()
    
    private var style: CoverStyle = .style1
    private var autoCornerRadius: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.Color.CoverEmpty
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(platformView)
        
        addSubview(ratingView)
        
        gameCoverChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.GameCoverChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(delay: 0.35) {
                self.updateCornerRadius(self.layerCornerRadius)
            }
        }
    }
    
    deinit {
        if let gameCoverChangeNotification {
            NotificationCenter.default.removeObserver(gameCoverChangeNotification)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if autoCornerRadius {
            layerCornerRadius = R.Style.GameCoverCornerRatio * style.maxCornerRadius(frameHeight: height)
        }
        if style == .style3 {
            imageView.roundCorners([.topLeft, .topRight], radius: layerCornerRadius - 6)
        } else {
            imageView.roundCorners([], radius: 0)
        }
        ratingView.makeShadow(radius: 30, opacity: 1)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    ///设置游戏封面
    func setData(game: Game,
                 coverSize: CGSize,
                 style: CoverStyle,
                 scalePlatform: Bool = true) {
        if height > 0 {
            autoCornerRadius = false
            let gameCoverCornerRatio = R.Style.GameCoverCornerRatio
            let maxCornerRadius = style.maxCornerRadius(frameHeight: coverSize.height)
            let cornerRadius = gameCoverCornerRatio * maxCornerRadius
            updateCornerRadius(cornerRadius)
        } else {
            autoCornerRadius = true
        }
        imageView.setGameCover(game: game, size: coverSize)
        var gameTypeCategory = 0
        if game.supportChangeCategory {
            gameTypeCategory = game.getExtraInt(key: ExtraKey.gameTypeCategory.rawValue) ?? 0
        }
        updateStyle(style,
                    gameType: game.gameType,
                    scalePlatform: scalePlatform,
                    gameTypeCategory: gameTypeCategory)
        
        if !R.Style.GameHideRating {
            if let esrp = GameMetadata.getGameMetadata(game: game)?.ESRPRating {
                ratingView.isHidden = false
                ratingView.icon = esrp.icon
            } else {
                ratingView.isHidden = true
            }
            ratingView.snp.remakeConstraints { make in
                let width = min(coverSize.width/5.5, R.Size.ItemHeightMicro)
                let inset = max(width * 0.27, R.Size.ContentSpaceTiny)
                make.bottom.trailing.equalTo(imageView).inset(inset)
                make.size.equalTo(CGSize(width: width, height: width/0.6666))
            }
        } else {
            ratingView.isHidden = true
        }
    }
    
    ///主题圆角配置时使用
    func setData(gameType: GameType,
                 image: UIImage?,
                 style: CoverStyle,
                 cornerRadius: CGFloat,
                 scalePlatform: Bool = true) {
        autoCornerRadius = false
        layerCornerRadius = cornerRadius
        imageView.image = image
        imageView.contentMode = .center
        updateStyle(style,
                    gameType: gameType,
                    scalePlatform: scalePlatform)
        if R.Style.GameHideRating {
            ratingView.isHidden = true
        } else {
            ratingView.isHidden = false
            ratingView.icon = ESRP.E.icon
            ratingView.snp.remakeConstraints { make in
                make.bottom.trailing.equalTo(imageView).inset(R.Size.ContentSpaceExtraSmall)
                make.size.equalTo(CGSize(width: R.Size.ItemHeightMicro, height: R.Size.ItemHeightMicro/0.6666))
            }
        }
    }
    
    func updateStyle(_ style: CoverStyle,
                     gameType: GameType,
                     scalePlatform: Bool = true,
                     gameTypeCategory: Int = 0) {
        self.style = style
        platformView.image = Self.getPlatformImage(gameType: gameType, style: style, scalePlatform: scalePlatform, gameTypeCategory: gameTypeCategory)
        switch style {
        case .style1:
            imageView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
            platformView.isHidden = true
            backgroundColor = R.Color.CoverEmpty
        case .style2:
            imageView.snp.remakeConstraints { make in
                make.top.trailing.bottom.equalToSuperview()
                make.leading.equalTo(platformView.snp.trailing)
            }
            platformView.snp.remakeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                make.width.equalToSuperview().multipliedBy(0.1298)
            }
            platformView.isHidden = false
            backgroundColor = R.Color.CoverEmpty
        case .style3:
            imageView.snp.remakeConstraints { make in
                make.leading.top.trailing.equalToSuperview().inset(6)
                make.bottom.equalTo(platformView.snp.top)
            }
            platformView.snp.remakeConstraints { make in
                make.leading.bottom.trailing.equalToSuperview()
                make.height.equalToSuperview().multipliedBy(0.2077)
            }
            platformView.isHidden = false
            backgroundColor = R.Color.CoverSide
        }
    }
    
    func updateCornerRadius(_ radius: CGFloat) {
        layerCornerRadius = radius
        if style == .style3 {
            imageView.roundCorners([.topLeft, .topRight], radius: layerCornerRadius - 6)
        } else {
            imageView.roundCorners([], radius: 0)
        }
    }
    
    func updateRating(esrp: ESRP?) {
        if let esrp {
            ratingView.isHidden = false
            ratingView.icon = esrp.icon
        } else {
            ratingView.isHidden = true
        }
    }
    
    private static var platformImageCaches = [String: UIImage?]()
    static func getPlatformImage(gameType: GameType, style: CoverStyle, scalePlatform: Bool = true, gameTypeCategory: Int = 0) -> UIImage? {
        guard style != .style1 else { return nil }
        let key = gameType.rawValue + "_\(style.rawValue)" + (UIDevice.isPhone && !UIDevice.isLandscape && scalePlatform ? "_\(R.Style.GamesPerRow)" : "") + "_\(gameTypeCategory)"
        if let image = GameCoverView.platformImageCaches[key] {
            return image
        } else {
            var image: UIImage? = nil
            if gameType == ._3ds {
                image = style == .style2 ? R.image.sds_cover_v() : R.image.sds_cover_h()
            } else if gameType == .ds {
                image = style == .style2 ? R.image.ds_cover_v() : R.image.ds_cover_h()
            } else if gameType == .gba {
                image = style == .style2 ? R.image.gba_cover_v() : R.image.gba_cover_h()
            } else if gameType == .gbc {
                image = style == .style2 ? R.image.gbc_cover_v() : R.image.gbc_cover_h()
            } else if gameType == .gb {
                if gameTypeCategory == 0 {
                    image = style == .style2 ? R.image.gb_cover_v() : R.image.gb_cover_h()
                } else if gameTypeCategory == 1 {
                    image = style == .style2 ? R.image.chm_cover_v() : R.image.chm_cover_h()
                }
            } else if gameType == .nes {
                image = style == .style2 ? R.image.nes_cover_v() : R.image.nes_cover_h()
            } else if gameType == .fds {
                image = style == .style2 ? R.image.fds_cover_v() : R.image.fds_cover_h()
            } else if gameType == .snes {
                image = style == .style2 ? R.image.snes_cover_v() : R.image.snes_cover_h()
            } else if gameType == .psp {
                image = style == .style2 ? R.image.psp_cover_v() : R.image.psp_cover_h()
            } else if gameType == .md {
                if Locale.prefersUS {
                    image = style == .style2 ? R.image.md_cover_v_us() : R.image.md_cover_h_us()
                } else {
                    image = style == .style2 ? R.image.md_cover_v() : R.image.md_cover_h()
                }
            } else if gameType == .mcd {
                if Locale.prefersUS {
                    image = style == .style2 ? R.image.mcd_cover_v_us() : R.image.mcd_cover_h_us()
                } else {
                    image = style == .style2 ? R.image.mcd_cover_v() : R.image.mcd_cover_h()
                }
            } else if gameType == ._32x {
                if Locale.prefersUS {
                    image = style == .style2 ? R.image.s2x_cover_v_us() : R.image.s2x_cover_h_us()
                } else {
                    image = style == .style2 ? R.image.s2x_cover_v() : R.image.s2x_cover_h()
                }
            } else if gameType == .ss {
                image = style == .style2 ? R.image.ss_cover_v() : R.image.ss_cover_h()
            } else if gameType == .sg1000 {
                image = style == .style2 ? R.image.sg1000_cover_v() : R.image.sg1000_cover_h()
            } else if gameType == .gg {
                image = style == .style2 ? R.image.gg_cover_v() : R.image.gg_cover_h()
            } else if gameType == .ms {
                image = style == .style2 ? R.image.ms_cover_v() : R.image.ms_cover_h()
            } else if gameType == .n64 {
                image = style == .style2 ? R.image.n64_cover_v() : R.image.n64_cover_h()
            } else if gameType == .vb {
                image = style == .style2 ? R.image.vb_cover_v() : R.image.vb_cover_h()
            } else if gameType == .pm {
                image = style == .style2 ? R.image.pm_cover_v() : R.image.pm_cover_h()
            } else if gameType == .ps1 {
                image = style == .style2 ? R.image.ps1_cover_v() : R.image.ps1_cover_h()
            } else if gameType == .dc {
                image = style == .style2 ? R.image.dc_cover_v() : R.image.dc_cover_h()
            } else if gameType == .arcade {
                image = style == .style2 ? R.image.arcade_cover_v() : R.image.arcade_cover_h()
            } else if gameType == .ns {
                image = style == .style2 ? R.image.ns_cover_v() : R.image.ns_cover_h()
            } else if gameType == .a2600 {
                image = style == .style2 ? R.image.a2600_cover_v() : R.image.a2600_cover_h()
            } else if gameType == .a5200 {
                image = style == .style2 ? R.image.a5200_cover_v() : R.image.a5200_cover_h()
            } else if gameType == .a7800 {
                image = style == .style2 ? R.image.a7800_cover_v() : R.image.a7800_cover_h()
            } else if gameType == .jaguar {
                image = style == .style2 ? R.image.jaguar_cover_v() : R.image.jaguar_cover_h()
            } else if gameType == .lynx {
                image = style == .style2 ? R.image.lynx_cover_v() : R.image.lynx_cover_h()
            } else if gameType == .xbox360 {
                image = style == .style2 ? R.image.xbox360_cover_v() : R.image.xbox360_cover_h()
            } else if gameType == .j2me {
                image = style == .style2 ? R.image.j2me_cover_v() : R.image.j2me_cover_h()
            } else if gameType == .flash {
                image = style == .style2 ? R.image.flash_cover_v() : R.image.flash_cover_h()
            } else if gameType == .doom {
                image = style == .style2 ? R.image.doom_cover_v() : R.image.doom_cover_h()
            } else if gameType == .dos {
                if gameTypeCategory == 0 {
                    image = style == .style2 ? R.image.dos_cover_v() : R.image.dos_cover_h()
                } else if gameTypeCategory == 1 {
                    image = style == .style2 ? R.image.win95_cover_v() : R.image.win95_cover_h()
                } else if gameTypeCategory == 2 {
                    image = style == .style2 ? R.image.win98_cover_v() : R.image.win98_cover_h()
                }   
            } else if gameType == .xbox {
                image = style == .style2 ? R.image.xbox_cover_v() : R.image.xbox_cover_h()
            } else if gameType == .symbian {
                image = style == .style2 ? R.image.symbian_cover_v() : R.image.symbian_cover_h()
            } else if gameType == .ngc {
                image = style == .style2 ? R.image.ngc_cover_v() : R.image.ngc_cover_h()
            } else if gameType == .wii {
                image = style == .style2 ? R.image.wii_cover_v() : R.image.wii_cover_h()
            } else if gameType == .pce {
                if gameTypeCategory == 0 {
                    image = style == .style2 ? R.image.pce_cover_v() : R.image.pce_cover_h()
                } else if gameTypeCategory == 1 {
                    image = style == .style2 ? R.image.turbografx_16_cover_v() : R.image.turbografx_16_cover_h()
                } else if gameTypeCategory == 2 {
                    image = style == .style2 ? R.image.turbografx_cd_cover_v() : R.image.turbografx_cd_cover_h()
                } else if gameTypeCategory == 3 {
                    image = style == .style2 ? R.image.supergrafx_cover_v() : R.image.supergrafx_cover_h()
                }
            } else if gameType == .ngp {
                if gameTypeCategory == 0 {
                    image = style == .style2 ? R.image.ngp_cover_v() : R.image.ngp_cover_h()
                } else if gameTypeCategory == 1 {
                    image = style == .style2 ? R.image.ngp_color_cover_v() : R.image.ngp_color_cover_h()
                }
            } else if gameType == .wsc {
                if gameTypeCategory == 0 {
                    image = style == .style2 ? R.image.wsc_cover_v() : R.image.wsc_cover_h()
                } else if gameTypeCategory == 1 {
                    image = style == .style2 ? R.image.ws_cover_v() : R.image.ws_cover_h()
                }
            } else if gameType == .ws {
                image = style == .style2 ? R.image.ws_cover_v() : R.image.ws_cover_h()
            } else if gameType == .c64 {
                image = style == .style2 ? R.image.c64_cover_v() : R.image.c64_cover_h()
            } else if gameType == .amiga {
                image = style == .style2 ? R.image.amiga_cover_v() : R.image.amiga_cover_h()
            } else if gameType == .ps2 {
                image = style == .style2 ? R.image.ps2_cover_v() : R.image.ps2_cover_h()
            }
            if UIDevice.isPhone, !UIDevice.isLandscape, scalePlatform, R.Style.GamesPerRow != 2, let unwrapImage = image {
                image = unwrapImage.scaled(toWidth: unwrapImage.size.width * (1/(R.Style.GamesPerRow-1)))
            }
            GameCoverView.platformImageCaches[key] = image
            return image
        }
    }
    
}
