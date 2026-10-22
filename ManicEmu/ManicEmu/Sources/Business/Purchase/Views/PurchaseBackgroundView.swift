//
//  PurchaseBackgroundView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/17.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Purchase backdrop: animated gradient with the cover image sized to this view's bounds.
class PurchaseBackgroundView: BaseView {

    private let imageLayer = CALayer()
    private let gradientView = AnimatedGradientView(notifiedUpadate: true, alphaComponent: 0.9)
    /// Last size the cover was rasterized for. Layout can run again without a size change.
    private var renderedSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientView.layer.insertSublayer(imageLayer, at: 0)
        addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard size != .zero else { return }
        guard bounds.width > 0, bounds.height > 0, bounds.size != renderedSize else { return }
        renderedSize = bounds.size
        imageLayer.frame = CGRect(origin: .zero, size: bounds.size)
        imageLayer.contents = R.image.game_cover_bg()?.scaled(toWidth: bounds.width)?.cropped(to: bounds).cgImage
        if UIDevice.isPhoneDuo {
            if UIDevice.isPhoneDuoCompactWidth {
                self.roundCorners([.topLeft, .topRight], radius: R.Size.CornerRadiusMedium)
            } else {
                self.roundCorners([.topLeft, .topRight], radius: 0)
            }
        }
    }
}
