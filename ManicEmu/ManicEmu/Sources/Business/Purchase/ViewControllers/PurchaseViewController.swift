//
//  PurchaseViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class PurchaseViewController: BaseViewController {
    
    private lazy var purchaseView: PurchaseView = {
        let view = PurchaseView(featuresType: featuresType)
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    var featuresType: FeaturesType
    
    init(featuresType: FeaturesType = .advance) {
        self.featuresType = featuresType
        if UIDevice.isPhoneDuoOuter || UIDevice.isPhoneDuoSplitView {
            super.init(fullScreen: true)
        } else {
            super.init(nibName: nil, bundle: nil)
        }
        
        //禁止下滑关闭控制器
        isModalInPresentation = true
        
        
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(purchaseView)
        purchaseView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
