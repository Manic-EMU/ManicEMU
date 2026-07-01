//
//  SettingsListView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import RealmSwift
import MessageUI

class SettingsListView: BaseView {
    
    private var navigationBlurView: NavigationBlurView = {
        let view = NavigationBlurView()
        view.makeBlur()
        return view
    }()
    
    lazy var collectionView: UICollectionView = {
        let view = NoControllCollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: SettingsItemCollectionViewCell.self)
        view.register(cellWithClass: MembershipCollectionViewCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: BackgroundColorHaderReusableView.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: SettingsListFooterCollectionReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.contentInset = UIEdgeInsets(top: Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid, left: 0, bottom: Constants.Size.ContentInsetBottom + Constants.Size.HomeTabBarSize.height + Constants.Size.ContentSpaceMax, right: 0)
        return view
    }()
    
    enum SectionIndex: Int, CaseIterable {
        case general = 1, advance, support, others
        var title: String {
            switch self {
            case .general:
                R.string.localizable.generalSettingTitle()
            case .advance:
                R.string.localizable.advanceSettingTitle()
            case .support:
                R.string.localizable.supportSettingTitle()
            case .others:
                R.string.localizable.othersSettingTitle()
            }
        }
    }
    
    private var settingsUpdateToken: NotificationToken? = nil
    private lazy var items: [SectionIndex: [SettingItem]] = {
        var datas = [SectionIndex: [SettingItem]]()
        //监听数据的变化
        settingsUpdateToken = Settings.defalut.observe(keyPaths: [\Settings.language,
                                                                   \Settings.quickGame,
                                                                   \Settings.autoSaveState,
                                                                   \Settings.airPlay,
                                                                   \Settings.fullScreenWhenConnectController,
                                                                   \Settings.respectSilentMode]) { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .change(let object, let properties):
                //更新数据源
                for property in properties {
                    if let newvalue = property.newValue {
                        for sectionIndex in SectionIndex.allCases {
                            var stopIter = false
                            if let itemArray = self.items[sectionIndex] {
                                for (itemIndex, item) in itemArray.enumerated() {
                                    if item.type.rawValue == property.name {
                                        stopIter = true
                                        var newItem = item
                                        if item.type == .language {
                                            if let language = property.newValue as? String {
                                                newItem.arrowDetail = Locale.getSystemLanguageDisplayName(preferredLanguage: language)
                                            }
                                        } else {
                                            if let isOn = property.newValue as? Bool {
                                                newItem.isOn = isOn
                                            }
                                        }
                                        self.items[sectionIndex]?[itemIndex] = newItem
                                        break
                                    }
                                }
                            }
                            if stopIter {
                                break
                            }
                        }
                    }
                    Log.debug("设置更新 Property '\(property.name)' changed from \(property.oldValue == nil ? "nil" : property.oldValue!) to '\(property.newValue!)'")
                }
            default:
                break
            }
        }
        for section in SectionIndex.allCases {
            if section == .general {
                datas[section] = [SettingItem(type: .appearance),
                                  SettingItem(type: .theme),
                                  SettingItem(type: .quickGame, isOn: Settings.defalut.quickGame),
                                  SettingItem(type: .autoSaveState, isOn: Settings.defalut.autoSaveState),
                                  SettingItem(type: .skin)]
            } else if section == .advance {
#if SIDE_LOAD
                datas[section] = [SettingItem(type: .airPlay, isOn: Settings.defalut.airPlay),
                                  SettingItem(type: .fullScreenWhenConnectController, isOn: Settings.defalut.fullScreenWhenConnectController),
                                  SettingItem(type: .bios),
                                  SettingItem(type: .respectSilentMode, isOn: Settings.defalut.respectSilentMode),
                                  SettingItem(type: .onlinePlay),
                                  SettingItem(type: .rumble, isOn: Settings.defalut.getExtraBool(key: ExtraKey.rumble.rawValue) ?? false),
                                  SettingItem(type: .skinSound, isOn: Settings.defalut.getExtraBool(key: ExtraKey.skinSoundEffects.rawValue) ?? true),
                                  SettingItem(type: .retro),
                                  SettingItem(type: .triggerPro),
                                  SettingItem(type: .jit),
                                  SettingItem(type: .shaders),
                                  SettingItem(type: .globalCoreSwitch),
                ]
#else
                datas[section] = [SettingItem(type: .airPlay, isOn: Settings.defalut.airPlay),
                                  SettingItem(type: .iCloud),
                                  SettingItem(type: .fullScreenWhenConnectController, isOn: Settings.defalut.fullScreenWhenConnectController),
                                  SettingItem(type: .bios),
                                  SettingItem(type: .respectSilentMode, isOn: Settings.defalut.respectSilentMode),
                                  SettingItem(type: .onlinePlay),
                                  SettingItem(type: .rumble, isOn: Settings.defalut.getExtraBool(key: ExtraKey.rumble.rawValue) ?? false),
                                  SettingItem(type: .skinSound, isOn: Settings.defalut.getExtraBool(key: ExtraKey.skinSoundEffects.rawValue) ?? true),
                                  SettingItem(type: .retro),
                                  SettingItem(type: .triggerPro),
                                  SettingItem(type: .jit),
                                  SettingItem(type: .shaders),
                                  SettingItem(type: .globalCoreSwitch),
                ]
#endif
                if RommSyncManager.shared.isConfigured() {
                    datas[section]?.append(SettingItem(type: .romm))
                }
            } else if section == .support {
                datas[section] = [SettingItem(type: .FAQ),
                                  SettingItem(type: .feedback),
                                  SettingItem(type: .qq),
                                  SettingItem(type: .discord)]
            } else if section == .others {
                datas[section] = [SettingItem(type: .about),
                                  SettingItem(type: .shareApp),
                                  SettingItem(type: .clearCache, arrowDetail: CacheManager.totleSize),
                                  SettingItem(type: .language, arrowDetail: Locale.getSystemLanguageDisplayName(preferredLanguage: Settings.defalut.language)),
                                  SettingItem(type: .userAgreement),
                                  SettingItem(type: .privacyPolicy),
                                  SettingItem(type: .featuredItems)]
            }
        }
        return datas
    }()
    
    private let MembershipViewHeight = 120.0
    
    #if SIDE_LOAD
    private static let FooterHeight = 538 + Constants.Size.ContentSpaceHuge + Constants.Size.ItemHeightMax
    #else
    private static let FooterHeight = 538.0
    #endif
    
    private var membershipNotification: Any? = nil
    private var iCloudDriveSyncChangeNotification: Any? = nil
    private var iCloudEnableChangeNotification: Any? = nil
    private var importServiceUpdateToken: NotificationToken? = nil

    var didTapDetail: ((UIViewController)->Void)? = nil

    deinit {
        importServiceUpdateToken?.invalidate()
        if let membershipNotification = membershipNotification {
            NotificationCenter.default.removeObserver(membershipNotification)
        }
        if let iCloudDriveSyncChangeNotification {
            NotificationCenter.default.removeObserver(iCloudDriveSyncChangeNotification)
        }
        if let iCloudEnableChangeNotification {
            NotificationCenter.default.removeObserver(iCloudEnableChangeNotification)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(navigationBlurView)
        navigationBlurView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(self.safeAreaLayoutGuide)
            if UIDevice.isPhone, UIDevice.isLandscape {
                make.height.equalTo(Constants.Size.ItemHeightMid)
            } else {
                make.height.equalTo(Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid)
            }
        }
        
        let headerTitleLabel = UILabel()
        headerTitleLabel.textAlignment = .center
        headerTitleLabel.text = R.string.localizable.tabbarTitleSettings()
        headerTitleLabel.textColor = Constants.Color.LabelPrimary
        headerTitleLabel.font = Constants.Font.title(size: .s, weight: .semibold)
        navigationBlurView.addSubview(headerTitleLabel)
        headerTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        
        membershipNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.MembershipChange, object: nil, queue: .main) { [weak self] notification in
            self?.collectionView.reloadData()
        }
        
        iCloudDriveSyncChangeNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.iCloudDriveSyncChange, object: nil, queue: .main) { [weak self] _ in
            self?.collectionView.reloadData()
        }
        
        iCloudEnableChangeNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.iCloudEnableChange, object: nil, queue: .main) { [weak self] _ in
            self?.collectionView.reloadData()
        }

        let serviceObjects = Database.realm.objects(ImportService.self).where { !$0.isDeleted }
        importServiceUpdateToken = serviceObjects.observe { [weak self] changes in
            guard let self else { return }
            if case .update(_, let deletions, let insertions, _) = changes,
               !deletions.isEmpty || !insertions.isEmpty {
                self.refreshRommSettingsRow()
            }
        }
    }

    private func refreshRommSettingsRow() {
        guard var advanceItems = items[.advance] else { return }
        let hasRow = advanceItems.contains { $0.type == .romm }
        let shouldHaveRow = RommSyncManager.shared.isConfigured()
        guard hasRow != shouldHaveRow else { return }
        if shouldHaveRow {
            advanceItems.append(SettingItem(type: .romm))
        } else {
            advanceItems.removeAll { $0.type == .romm }
        }
        items[.advance] = advanceItems
        collectionView.reloadSections([SectionIndex.advance.rawValue])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, env in
            guard let self = self else { return nil }
            
            let lastSectionIndex = SectionIndex.allCases.last!.rawValue
            
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(sectionIndex == 0 ? self.MembershipViewHeight : Constants.Size.ItemHeightMax)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: Constants.Size.ContentSpaceMid,
                                                            bottom: 0,
                                                            trailing: Constants.Size.ContentSpaceMid)
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: sectionIndex == 0 ? Constants.Size.ContentSpaceMin : 0, leading: 0, bottom: Constants.Size.ContentSpaceMid, trailing: 0)
            
            if sectionIndex > 0 {
                //header布局
                let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                heightDimension: .absolute(44)),
                                                                             elementKind: UICollectionView.elementKindSectionHeader,
                                                                             alignment: .top)
                headerItem.pinToVisibleBounds = true
                section.boundarySupplementaryItems = [headerItem]
                if sectionIndex == lastSectionIndex {
                    section.decorationItems = [NSCollectionLayoutDecorationItem.background(elementKind: String(describing: SettingsBottomDecorationCollectionReusableView.self))]
                } else {
                    section.decorationItems = [NSCollectionLayoutDecorationItem.background(elementKind: String(describing: SettingsDecorationCollectionReusableView.self))]
                }
            }
            
            if sectionIndex == lastSectionIndex {
                let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                heightDimension: .absolute(Self.FooterHeight)),
                                                                             elementKind: UICollectionView.elementKindSectionFooter,
                                                                             alignment: .bottom)
                section.boundarySupplementaryItems.append(footerItem)
            }
            
            return section
        }
        layout.register(SettingsDecorationCollectionReusableView.self, forDecorationViewOfKind: String(describing: SettingsDecorationCollectionReusableView.self))
        layout.register(SettingsBottomDecorationCollectionReusableView.self, forDecorationViewOfKind: String(describing: SettingsBottomDecorationCollectionReusableView.self))
        return layout
    }
    
    class SettingsDecorationCollectionReusableView: UICollectionReusableView, DynamicShadow {
        var backgroundView: UIView = {
            let view = UIView()
            view.layerCornerRadius = Constants.Size.CornerRadiusMax
            view.backgroundColor = Constants.Color.BackgroundPrimary
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            updateDynamicShadow(offset: CGSize(width: 0, height: 0), radius: 2.5)
            
            addSubview(backgroundView)
            backgroundView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(Constants.Size.ItemHeightMin)
                make.bottom.equalToSuperview().offset(-Constants.Size.ContentSpaceMin)
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                updateDynamicShadow(offset: CGSize(width: 0, height: 0), radius: 2.5)
            }
        }
    }
    
    class SettingsBottomDecorationCollectionReusableView: UICollectionReusableView, DynamicShadow {
        var backgroundView: UIView = {
            let view = UIView()
            view.layerCornerRadius = Constants.Size.CornerRadiusMax
            view.backgroundColor = Constants.Color.BackgroundPrimary
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            updateDynamicShadow(offset: CGSize(width: 0, height: 0), radius: 2.5)
            
            addSubview(backgroundView)
            backgroundView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(Constants.Size.ItemHeightMin)
                make.bottom.equalToSuperview().offset(-Constants.Size.ContentSpaceMin-SettingsListView.FooterHeight)
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                updateDynamicShadow(offset: CGSize(width: 0, height: 0), radius: 2.5)
            }
        }
    }
    
    func updateViews() {
        if UIDevice.isPhone {
            navigationBlurView.snp.updateConstraints { make in
                if UIDevice.isLandscape {
                    make.height.equalTo(Constants.Size.ItemHeightMid)
                } else {
                    make.height.equalTo(Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid)
                }
            }
            if UIDevice.isLandscape {
                collectionView.contentInset = UIEdgeInsets(top: Constants.Size.ItemHeightMid, left: 0, bottom: Constants.Size.ContentInsetBottom + Constants.Size.HomeTabBarSize.height + Constants.Size.ContentSpaceMax, right: 0)
            } else {
                collectionView.contentInset = UIEdgeInsets(top: Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid, left: 0, bottom: Constants.Size.ContentInsetBottom + Constants.Size.HomeTabBarSize.height + Constants.Size.ContentSpaceMax, right: 0)
            }
        }
    }
}

extension SettingsListView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return items.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return items[SectionIndex(rawValue: section)!]!.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: MembershipCollectionViewCell.self, for: indexPath)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: SettingsItemCollectionViewCell.self, for: indexPath)
            let item = items[SectionIndex(rawValue: indexPath.section)!]![indexPath.row]
            cell.setData(item: item)
            cell.switchButton.onChange(handler: { _ in })
            cell.switchButton.onDisableTap(handler: nil)
            if item.type == .quickGame {
                cell.switchButton.onChange { value in
                    //快速游戏设置
                    Settings.change { _ in
                        Settings.defalut.quickGame = value
                    }
                }
            } else if item.type == .airPlay {
                cell.switchButton.onChange { value in
                    //airPlay设置
                    Settings.change { _ in
                        Settings.defalut.airPlay = value
                    }
                }
                cell.switchButton.onDisableTap {
                    topViewController()?.present(PurchaseViewController(featuresType: .airplay), animated: true)
                }
            } else if item.type == .fullScreenWhenConnectController {
                cell.switchButton.onChange { value in
                    //airPlay设置
                    Settings.change { _ in
                        Settings.defalut.fullScreenWhenConnectController = value
                    }
                }
            } else if item.type == .autoSaveState {
                cell.switchButton.onChange { value in
                    //airPlay设置
                    Settings.change { _ in
                        Settings.defalut.autoSaveState = value
                    }
                }
            } else if item.type == .respectSilentMode {
                cell.switchButton.onChange { value in
                    //快速游戏设置
                    Settings.change { _ in
                        Settings.defalut.respectSilentMode = value
                    }
                }
            } else if item.type == .rumble {
                cell.switchButton.onChange { value in
                    //设置震动触感
                    Settings.defalut.updateExtra(key: ExtraKey.rumble.rawValue, value: value)
                }
            } else if item.type == .appearance {
                cell.didSegmentChange = { [weak cell] index in
                    Settings.appearance = Settings.Appearance(rawValue: index) ?? .dark
                    cell?.setData(item: item)
                }
            } else if item.type == .skinSound {
                cell.switchButton.onChange { value in
                    //设置皮肤音效
                    Settings.defalut.updateExtra(key: ExtraKey.skinSoundEffects.rawValue, value: value)
                }
            }  else {
                cell.switchButton.onChange { value in }
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorHaderReusableView.self, for: indexPath)
            header.titleLabel.text = SectionIndex(rawValue: indexPath.section)?.title
            if UIDevice.isPad {
                header.makeBlur()
            }
            return header
        } else {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: SettingsListFooterCollectionReusableView.self, for: indexPath)
            return footer
        }
    }
}

extension SettingsListView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
#if !SIDE_LOAD
            topViewController()?.present(PurchaseViewController(), animated: true)
#endif
        } else {
            let item = items[SectionIndex(rawValue: indexPath.section)!]![indexPath.row]
            switch item.type {
            case .retro:
                let vc = RetroAchievementsViewController()
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
                
            case .onlinePlay:
                let vc = OnlinePlaySettingViewController(showClose: UIDevice.isPad ? false : true)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }

            case .romm:
                let vc = RommSettingsViewController(showClose: UIDevice.isPad ? false : true)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }

            case .bios:
                let vc = BIOSSelectionViewController(showClose: UIDevice.isPad ? false : true)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
                
            case .theme:
                let vc = ThemeViewController()
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
                
            case .FAQ:
                let vc = WebViewController(url: Constants.URLs.FAQ, showClose: UIDevice.isPhone)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
            case .feedback:
                if MFMailComposeViewController.canSendMail() {
                    let mailController = MFMailComposeViewController()
                    mailController.setToRecipients([Constants.Strings.SupportEmail])
                    mailController.mailComposeDelegate = self
                    topViewController(appController: true)?.present(mailController, animated: true)
                } else {
                    UIView.makeToast(message: R.string.localizable.noEmailSetting())
                }
            case .shareApp:
                ShareManager.shareApp(senderForIpad: UIDevice.isPad ? (collectionView.cellForItem(at: indexPath) ?? collectionView) : nil)
            case .qq:
                UIApplication.shared.open(Constants.URLs.JoinQQ)
            case .discord:
                UIApplication.shared.open(Constants.URLs.JoinDiscord)
            case .clearCache:
                UIView.makeLoading()
                CacheManager.clear { [weak self] in
                    guard let self = self else { return }
                    if let section = SectionIndex(rawValue: indexPath.section), let items = self.items[section], indexPath.row < items.count {
                        self.items[section]?[indexPath.row].arrowDetail = nil
                        self.collectionView.reloadData()
                    }
                    UIView.hideLoading()
                }
            case .language:
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            case .userAgreement:
                let vc = WebViewController(url: Constants.URLs.TermsOfUse, showClose: UIDevice.isPhone)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
                
            case .privacyPolicy:
                let vc = WebViewController(url: Constants.URLs.PrivacyPolicy, showClose: UIDevice.isPhone)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
            case .about:
                let vc = WebViewController(url: Constants.URLs.AboutUS, showClose: UIDevice.isPhone)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
            case .triggerPro:
                let vc = TriggerProListViewController(showClose: UIDevice.isPhone)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
            case .skin:
                let vc = SkinSettingsViewController(showClose: UIDevice.isPad ? false : true)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
            case .iCloud:
                let vc = ICloudSettingViewController(showClose: UIDevice.isPad ? false : true)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
            case .jit:
                let vc = JITSettingViewController(showClose: UIDevice.isPad ? false : true)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
            case .shaders:
                let vc = ShadersListViewController(showClose: UIDevice.isPad ? false : true, initType: .normal)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
            case .featuredItems:
                UIApplication.shared.open(Constants.URLs.PlayCasePromo)
            case .globalCoreSwitch:
                let vc = GlobalCoreSwitchViewController(showClose: UIDevice.isPad ? false : true)
                if UIDevice.isPad {
                    didTapDetail?(vc)
                } else {
                    topViewController()?.present(vc, animated: true)
                }
            default:
                break
            }
        }
    }
}

extension SettingsListView: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: (any Error)?) {
        switch result {
        case .sent:
            UIView.makeToast(message: R.string.localizable.sendEmailSuccess())
            controller.dismiss(animated: true)
        case .failed:
            var errorMsg = ""
            if let error = error {
                errorMsg += "\n" + error.localizedDescription
            }
            UIView.makeToast(message: R.string.localizable.sendEmailFailed(errorMsg))
        default:
            controller.dismiss(animated: true)
        }
    
    }
}
