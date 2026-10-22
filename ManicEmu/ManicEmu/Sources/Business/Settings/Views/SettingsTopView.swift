//
//  SettingsTopView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/25.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class SettingsTopView: BaseView {
    let membershipView = SettingsMembershipView()
    let adventureCardView = SettingsAdventureCardView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([membershipView, adventureCardView])
        updateViewsConstraints()
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateViewsConstraints() {
        if (UIDevice.isPhone && !UIDevice.isPhoneDuoInnerFullScreen), preferredLayoutStyle == .landscape {
            membershipView.snp.remakeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
            }
            adventureCardView.snp.remakeConstraints { make in
                make.trailing.top.bottom.equalToSuperview()
                make.leading.equalTo(membershipView.snp.trailing).offset(R.Size.ContentSpaceMedium)
                make.width.equalTo(membershipView.snp.width)
            }
        } else {
            membershipView.snp.remakeConstraints { make in
                make.leading.top.trailing.equalToSuperview()
                make.height.equalTo(120)
            }
            adventureCardView.snp.remakeConstraints { make in
                make.leading.bottom.trailing.equalToSuperview()
                make.top.equalTo(membershipView.snp.bottom).offset(R.Size.ContentSpaceMedium)
            }
        }
    }
}
