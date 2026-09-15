//
//  SettingsItemCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import BetterSegmentedControl

class SettingsItemCollectionViewCell: UICollectionViewCell {
    private var iconView: IconView = {
        let view = IconView()
        view.layerCornerRadius = 6
        return view
    }()
    
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 3
        return view
    }()
    
    var chevronIconView: UIImageView = {
        let view = UIImageView(image: UIImage(symbol: .chevronRight, font: Constants.Font.caption(size: .l, weight: .bold), color: Constants.Color.BackgroundSecondary))
        view.isHidden = true
        view.contentMode = .center
        return view
    }()
    
    var switchButton: DisabledTapSwitch = {
        let view = DisabledTapSwitch()
        view.isHidden = true
        view.onTintColor = Constants.Color.Main
        view.tintColor = Constants.Color.BackgroundSecondary
        return view
    }()
    
    private var arrowDetailLabel: UILabel = {
        let view = UILabel()
        view.font = Constants.Font.caption()
        view.textColor = Constants.Color.LabelSecondary
        view.isHidden = true
        return view
    }()
    
    var didSegmentChange: ((_ index: Int)->Void)?
    private lazy var segmentView: BetterSegmentedControl = {
        let icons = [R.image.customMoonFill()!, R.image.customSunMaxFill()!, R.image.customMoonphaseFirstQuarter()!]
        let segments = IconSegment.segments(withIcons: icons,
                                            iconSize: .init(16),
                                            normalIconTintColor: Constants.Color.LabelSecondary,
                                            selectedIconTintColor: Constants.Color.LabelPrimary)
        let options: [BetterSegmentedControl.Option] = [
            .backgroundColor(Constants.Color.Background),
            .indicatorViewInset(5),
            .indicatorViewBackgroundColor(Constants.Color.AppearanceSegmentHighlight),
            .cornerRadius(20)
        ]
        let view = BetterSegmentedControl(frame: .zero,
                                          segments: segments,
                                          options: options)
        
        view.on(.valueChanged) { [weak self] sender, forEvent in
            guard let self = self, let index = (sender as? BetterSegmentedControl)?.index else { return }
            UIDevice.generateHaptic()
            self.didSegmentChange?(index)
        }
        view.isHidden = true
        return view
    }()
    
    private var mainColorChangeNotification: Any? = nil
    
    deinit {
        if let mainColorChangeNotification = mainColorChangeNotification {
            NotificationCenter.default.removeObserver(mainColorChangeNotification)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
        }
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            var offset = 46.0
            if #available(iOS 26.0, *) {
                offset = 63
            }
            make.trailing.equalToSuperview().offset(-offset-Constants.Size.ContentSpaceMid-Constants.Size.ContentSpaceMin)
        }
        
        addSubview(chevronIconView)
        chevronIconView.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
            make.size.equalTo(16)
        }
        
        addSubview(arrowDetailLabel)
        arrowDetailLabel.snp.makeConstraints { make in
            make.centerY.equalTo(chevronIconView)
            make.trailing.equalTo(chevronIconView.snp.leading).offset(-Constants.Size.ContentSpaceUltraTiny)
        }
        
        addSubview(switchButton)
        switchButton.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
            if #available(iOS 26.0, *) {
                make.size.equalTo(CGSize(width: 63, height: 28))
            } else {
                make.size.equalTo(CGSize(width: 51, height: 31))
            }
        }
        if #available(iOS 26.0, *) {} else {
            switchButton.transform = CGAffineTransformMakeScale(0.9, 0.9)
        }
        
        
        addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
            make.size.equalTo(CGSize(width: 105, height: 40))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(item: SettingItem) {
        iconView.image = item.icon
        iconView.backgroundColor = item.backgroundColor
        var matt = NSMutableAttributedString(string: item.title, attributes: [.font: Constants.Font.body(size: .l, weight: .semibold), .foregroundColor: Constants.Color.LabelPrimary])
        if let detail = item.detail {
            matt.append(NSAttributedString(string: "\n" + detail, attributes: [.font: Constants.Font.caption(size: .l), .foregroundColor: Constants.Color.LabelSecondary]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
            matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        } else if item.type == .iCloud {
            //特殊处理detail
            var detail = R.string.localizable.iCloudNotEnable()
            var color = Constants.Color.LabelSecondary
            if Settings.defalut.iCloudSyncEnable && PurchaseManager.isMember {
                if SyncManager.shared.syncState == .idle {
                    detail = R.string.localizable.iCloudSynced()
                    color = Constants.Color.Green
                } else if SyncManager.shared.syncState == .syncing {
                    detail = R.string.localizable.iCloudSyncing()
                    color = Constants.Color.Yellow
                }
            }
            matt.append(NSAttributedString(string: "\n" + "●", attributes: [.font: Constants.Font.caption(size: .s), .foregroundColor: color, .baselineOffset: 1]))
            matt.append(NSAttributedString(string: " " + detail, attributes: [.font: Constants.Font.caption(size: .l), .foregroundColor: color]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
            matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        } else if item.type == .jit {
            //特殊处理detail
            var detail = R.string.localizable.jitNotAllow()
            var color = Constants.Color.Red
            if LibretroCore.jitAvailable() {
                detail = R.string.localizable.jitAllow()
                color = Constants.Color.Green
            }
            matt.append(NSAttributedString(string: "\n" + "●", attributes: [.font: Constants.Font.caption(size: .s), .foregroundColor: color, .baselineOffset: 1]))
            matt.append(NSAttributedString(string: " " + detail, attributes: [.font: Constants.Font.caption(size: .l), .foregroundColor: color]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
            matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        titleLabel.attributedText = matt
        
        switch item.type {
        case .quickGame, .airPlay, .fullScreenWhenConnectController, .autoSaveState, .respectSilentMode, .rumble, .skinSound, .rommSyncOnLaunch, .rommSyncOnGameExit:
            switchButton.isHidden = false
            chevronIconView.isHidden = true
            enableInteractive = false
            delayInteractiveTouchEnd = false
            segmentView.isHidden = true
        case .appearance:
            switchButton.isHidden = true
            chevronIconView.isHidden = true
            enableInteractive = false
            delayInteractiveTouchEnd = false
            segmentView.isHidden = false
            segmentView.setIndex(Settings.appearance.rawValue, animated: false, shouldSendValueChangedEvent: false)
        default:
            switchButton.isHidden = true
            chevronIconView.isHidden = false
            enableInteractive = true
            delayInteractiveTouchEnd = true
            segmentView.isHidden = true
        }
        if let isOn = item.isOn {
            if !PurchaseManager.isMember && (item.type == .airPlay) {
                switchButton.isEnabled = false
                switchButton.setOn(false, animated: false)
            } else {
                switchButton.isEnabled = true
                switchButton.setOn(isOn, animated: false)
            }
        } else {
            switchButton.isEnabled = false
            switchButton.setOn(false, animated: false)
        }
        
        switch item.type {
        case .clearCache, .language:
            arrowDetailLabel.isHidden = false
        default:
            arrowDetailLabel.isHidden = true
        }
        arrowDetailLabel.text = item.arrowDetail
    }
    
}
