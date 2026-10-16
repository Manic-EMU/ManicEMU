//
//  PurchaseView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class PurchaseView: BaseView {
    
    ///点击关闭按钮回调
    var didTapClose: (()->Void)? = nil
    
    private lazy var navigationView: UIView = {
        let view = UIView()
        let closeButton = SymbolButton(image: UIImage(symbol: .xmark, font: R.Font.Footnote(emphasis: true), color: R.Color.LabelPrimary.forceStyle(.dark)), enableGlass: true)
        closeButton.backgroundColor = .white.withAlphaComponent(0.1)
        closeButton.enableRoundCorner = true
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.equalTo(R.Size.IconSizeLarge)
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceLarge)
        }
        closeButton.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.didTapClose?()
        }
        
        let restorePurchase = UILabel()
        restorePurchase.isUserInteractionEnabled = true
        restorePurchase.enablePressEffect = true
        restorePurchase.font = R.Font.Caption()
        restorePurchase.textColor = R.Color.LabelPrimary.forceStyle(.dark)
        restorePurchase.text = R.string.localizable.restorePurchaseButton()
        view.addSubview(restorePurchase)
        restorePurchase.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceLarge)
        }
        restorePurchase.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            //恢复购买
            UIView.makeLoading()
            PurchaseManager.restore { [weak self] isSuccess in
                guard let self = self else { return }
                UIView.hideLoading()
                if isSuccess {
                    UIView.makeToast(message: R.string.localizable.restoreSuccessDesc()) { [weak self] in
                        self?.didTapClose?()
                    }
                } else {
                    UIView.makeToast(message: R.string.localizable.restoreEndDesc())
                }
                
            }
        }
        
        if #available(iOS 16.0, *) {
            let redeemOfferCode = UILabel()
            redeemOfferCode.isUserInteractionEnabled = true
            redeemOfferCode.enablePressEffect = true
            redeemOfferCode.font = R.Font.Caption()
            redeemOfferCode.textColor = R.Color.LabelPrimary.forceStyle(.dark)
            redeemOfferCode.text = R.string.localizable.redeemOfferCode()
            view.addSubview(redeemOfferCode)
            redeemOfferCode.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.trailing.equalTo(restorePurchase.snp.leading).offset(-R.Size.ContentSpaceMedium)
            }
            redeemOfferCode.addTapGesture { [weak self] gesture in
                guard let self = self else { return }
                //兑换优惠码
                PurchaseManager.redeemOfferCode { [weak self] isCompleted, isMember in
                    guard let self else { return }
                    if isMember {
                        self.didTapClose?()
                        CheersView.makePurchaseCheers(in: self.hostingWindowScene)
                    } else if isCompleted {
                        Log.debug("兑换优惠成功")
                    } else {
                        Log.debug("兑换优惠失败")
                    }
                }
            }
        }
        
        return view
    }()
    
    private let imageLayer: CALayer = CALayer()
    private lazy var backgroundGradientView: AnimatedGradientView = {
        let view = AnimatedGradientView(notifiedUpadate: true, alphaComponent: 0.9)
        view.layer.insertSublayer(imageLayer, at: 0)
        return view
    }()
    
    private var featureView = FeaturesView()
    
    private lazy var priceView: PriceView = {
        let view = PriceView()
        view.needToClosePurchaseView = { [weak self] in
            self?.didTapClose?()
        }
        return view
    }()
    
    init(featuresType: FeaturesType?) {
        super.init(frame: .zero)
        addSubview(backgroundGradientView)
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightMedium)
        }
        
        addSubview(featureView)
        featureView.featuresType = featuresType
        addSubview(priceView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateViewsConstraits()
        imageLayer.contents = R.image.game_cover_bg()?.scaled(toWidth: backgroundGradientView.width)?.cropped(to: backgroundGradientView.bounds).cgImage
        imageLayer.frame = CGRect(origin: .zero, size: backgroundGradientView.size)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateViewsConstraits() {
        backgroundGradientView.snp.remakeConstraints { make in
            if UIDevice.isPhone, prefferedLayoutStyle == .landscape {
                make.top.equalToSuperview()
                make.leading.bottom.trailing.equalTo(featureView)
            } else {
                make.leading.top.trailing.equalToSuperview()
                make.bottom.equalTo(featureView.snp.bottom)
            }
        }
        
        featureView.snp.remakeConstraints { make in
            if UIDevice.isPhone, prefferedLayoutStyle == .landscape {
                make.top.equalToSuperview().offset(R.Size.NavigationHeight)
                make.leading.bottom.equalToSuperview()
                make.width.equalToSuperview().dividedBy(2)
            } else {
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(navigationView.snp.bottom)
            }
        }
        
        priceView.snp.remakeConstraints { make in
            if UIDevice.isPhone, prefferedLayoutStyle == .landscape {
                make.top.equalToSuperview().offset(R.Size.NavigationHeight)
                make.bottom.trailing.equalToSuperview()
                make.leading.equalTo(featureView.snp.trailing)
            } else {
                make.leading.bottom.trailing.equalToSuperview()
                make.top.equalTo(featureView.snp.bottom)
                make.height.equalTo(447)
            }
        }
    }
}
