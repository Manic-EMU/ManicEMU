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
    enum SectionIndex: Int, CaseIterable {
        case top, general, advance, support, others, bottom
        var title: String {
            switch self {
            case .top, .bottom:
                ""
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
    
    private var listPageView: ASListPageView? = nil
    private let topView = SettingsTopView()
    private let bottomView = SettingsBottomView()
    
    private var membershipNotification: Any? = nil
    private var iCloudDriveSyncChangeNotification: Any? = nil
    private var iCloudEnableChangeNotification: Any? = nil
    
    var didTapDetailView: ((UIView)->Void)? = nil
    
    private var settingsUpdateToken: NotificationToken? = nil
    private lazy var items: [SectionIndex: [SettingItem]] = {
        var datas = [SectionIndex: [SettingItem]]()
        //Settings that update outside of the settings page will be monitored.
        settingsUpdateToken = Settings.defalut.observe(keyPaths: [\Settings.airPlay]) { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .change(let object, let properties):
                for property in properties {
                    if let itemType = SettingItem.ItemType(rawValue: property.name) {
                        self.reloadCell(for: .init(type: itemType))
                    }
                }
            default:
                break
            }
        }
        
        for section in SectionIndex.allCases {
            if section == .top || section == .bottom {
                datas[section] = []
                
            } else if section == .general {
                datas[section] = [.init(type: .appearance),
                                  .init(type: .theme),
                                  .init(type: .quickGame),
                                  .init(type: .autoSaveState),
                                  .init(type: .skin),
                                  .init(type: .coverScraping)]
                
            } else if section == .advance {
#if SIDE_LOAD
                datas[section] = [.init(type: .airPlay),
                                  .init(type: .fullScreenWhenConnectController),
                                  .init(type: .bios),
                                  .init(type: .respectSilentMode),
                                  .init(type: .onlinePlay),
                                  .init(type: .rumble),
                                  .init(type: .skinSound),
                                  .init(type: .retro),
                                  .init(type: .triggerPro),
                                  .init(type: .jit),
                                  .init(type: .shaders),
                                  .init(type: .globalCoreSwitch),
                ]
#else
                datas[section] = [.init(type: .airPlay),
                                  .init(type: .iCloud),
                                  .init(type: .fullScreenWhenConnectController),
                                  .init(type: .bios),
                                  .init(type: .respectSilentMode),
                                  .init(type: .onlinePlay),
                                  .init(type: .rumble),
                                  .init(type: .skinSound),
                                  .init(type: .retro),
                                  .init(type: .triggerPro),
                                  .init(type: .jit),
                                  .init(type: .shaders),
                                  .init(type: .globalCoreSwitch),
                ]
#endif
            } else if section == .support {
                datas[section] = [.init(type: .FAQ),
                                  .init(type: .feedback),
                                  .init(type: .qq),
                                  .init(type: .discord)]
                
            } else if section == .others {
                datas[section] = [.init(type: .about),
                                  .init(type: .shareApp),
                                  .init(type: .clearCache),
                                  .init(type: .language),
                                  .init(type: .userAgreement),
                                  .init(type: .privacyPolicy),
                                  .init(type: .featuredItems)]
                
            }
        }
        return datas
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        topView.membershipView.addTapGesture { [weak self] gesture in
            self?.showMemberShip()
        }
        
        let listView = ASListPageView(getListPage())
        listView.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        listPageView = listView
        
        membershipNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.MembershipChange, object: nil, queue: .main) { [weak self] notification in
            self?.reloadData()
        }
        
        iCloudDriveSyncChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.iCloudDriveSyncChange, object: nil, queue: .main) { [weak self] _ in
            self?.reloadCell(for: .init(type: .iCloud))
        }
        
        iCloudEnableChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.iCloudEnableChange, object: nil, queue: .main) { [weak self] _ in
            self?.reloadCell(for: .init(type: .iCloud))
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let membershipNotification {
            NotificationCenter.default.removeObserver(membershipNotification)
        }
        if let iCloudDriveSyncChangeNotification {
            NotificationCenter.default.removeObserver(iCloudDriveSyncChangeNotification)
        }
        if let iCloudEnableChangeNotification {
            NotificationCenter.default.removeObserver(iCloudEnableChangeNotification)
        }
    }
    
    private func getNavigation() -> ASListPage.Navigation? {
        if UIDevice.isPhone, UIDevice.isLandscape {
            return nil
        }
        var navigationText = ASText.extraLargeText(R.string.localizable.tabbarTitleSettings())
        navigationText.attributes?.alignment = .center
        let navigation = ASListPage.Navigation(title: navigationText,
                                               enableClose: false)
        return navigation
    }
    
    private func getListPage() -> ASListPage {
        var sections = [ASListPage.Section]()
        for sectionIndex in items.keys.sorted(by: { $0.rawValue < $1.rawValue } ) {
            let settingItems = items[sectionIndex]!
            switch sectionIndex {
            case .top:
                sections.append(ASListPage.Section(cells: [.custom(topView)],
                                                   decoration: .init(enable: false),
                                                   itemLayout: .fixedHeight((UIDevice.isPhone && UIDevice.isLandscape) ? 165 : 301)))
                
            case .general, .advance, .support, .others:
                var header: ASListPage.Supplementary? = nil
                if !sectionIndex.title.isEmpty {
                    header = .defaultHeader(title: sectionIndex.title)
                }
                let section = ASListPage.Section(cells: settingItems.map({ $0.cellData }), header: header)
                sections.append(section)
                
            case .bottom:
                var cellHeight = 479.0
#if SIDE_LOAD
                cellHeight += 76
#endif
                sections.append(ASListPage.Section(cells: [ASListPage.Cell.custom(bottomView)],
                                                   decoration: .init(enable: false),
                                                   itemLayout: .fixedHeight(cellHeight)))
                
            }
        }
        
        let listBottomInset = R.Size.ContentSpaceLarge + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceLarge
        let pageTopInset: CGFloat
        pageTopInset = UIDevice.isPhone && UIDevice.isLandscape ? 0 : R.Size.ContentInsetTop
        return ASListPage(navigation: getNavigation(),
                          sections: sections,
                          backgroundColor: .clear,
                          listInsets: .insets(bottom: listBottomInset),
                          pageInsets: .insets(top: pageTopInset),
                          enableSafeAreaBottomInsets: true)
    }
    
    private func showMemberShip(featuresType: FeaturesType = .advance) {
#if !SIDE_LOAD
        topViewController()?.present(PurchaseViewController(featuresType: featuresType), animated: true)
#endif
    }
    
    @discardableResult
    private func upateSwitchSettings(extraValue: Any?,
                                     cellData: ASListPage.Cell,
                                     indexPath: IndexPath,
                                     settingsUpdation: ((Bool) -> Void)? = nil) -> Bool? {
        if let value = extraValue as? Bool {
            Settings.change { _ in
                settingsUpdation?(value)
            }
            listPageView?.updateCellData(cellData.updateNormalSwitch(state: value ? .on : .off), indexPath: indexPath, reloadView: false)
            return value
        }
        return nil
    }
    
    private func reloadData() {
        listPageView?.updatePage(getListPage())
    }
    
    private func reloadCell(for item: SettingItem) {
        var section: SectionIndex? = nil
        var row: Int? = nil
        for (sectionIndex, items) in items {
            if let itemIndex = items.firstIndex(where: { $0.type == item.type }) {
                section = sectionIndex
                row = itemIndex
                break
            }
        }
        
        if let section, let row {
            listPageView?.updateCellData(item.cellData, indexPath: IndexPath(row: row, section: section.rawValue))
        }
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        switch action {
        case .normalItem(let indexPath, let cellData, let subActions):
            if let sectionIndex = SectionIndex(rawValue: indexPath.section) {
                switch sectionIndex {
                case .top:
                    break
                    
                case .general, .advance, .support, .others:
                    if let item = items[sectionIndex]?[indexPath.row] {
                        switch item.type {
                        case .retro:
                            if UIDevice.isPad {
                                didTapDetailView?(RetroAchievementsLaunchView(loginedAction: .jumpProfile, showClose: false))
                            } else {
                                RetroAchievementsLaunchView.show(loginedAction: .jumpProfile)
                            }
                            
                        case .onlinePlay:
                            if UIDevice.isPad {
                                didTapDetailView?(OnlinePlaySettingView(showClose: false))
                            } else {
                                OnlinePlaySettingView.show()
                            }
                            
                        case .bios:
                            if UIDevice.isPad {
                                didTapDetailView?(BIOSSelectionView(showClose: false))
                            } else {
                                BIOSSelectionView.show()
                            }
                            
                        case .theme:
                            if UIDevice.isPad {
                                didTapDetailView?(ThemeSettingView(showClose: false))
                            } else {
                                ThemeSettingView.show()
                            }
                            
                        case .FAQ:
                            if UIDevice.isPad {
                                didTapDetailView?(ASWebView(url: R.URLs.FAQ, showClose: false))
                            } else {
                                ASWebView.show(url: R.URLs.FAQ)
                            }
                            
                        case .feedback:
                            if MFMailComposeViewController.canSendMail() {
                                let mailController = MFMailComposeViewController()
                                mailController.setToRecipients([R.Strings.SupportEmail])
                                mailController.mailComposeDelegate = self
                                topViewController(appController: true)?.present(mailController, animated: true)
                            } else {
                                UIView.makeToast(message: R.string.localizable.noEmailSetting())
                            }
                            
                        case .shareApp:
                            ShareManager.shareApp(senderForIpad: UIDevice.isPad ? self : nil)
                            
                        case .qq:
                            UIApplication.shared.open(R.URLs.JoinQQ)
                            
                        case .discord:
                            UIApplication.shared.open(R.URLs.JoinDiscord)
                            
                        case .clearCache:
                            UIView.makeLoading()
                            CacheManager.clear { [weak self] in
                                self?.listPageView?.updateCellData(cellData.updateNormalChevron(title: nil), indexPath: indexPath)
                                UIView.hideLoading()
                            }
                            
                        case .language:
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                            
                        case .userAgreement:
                            if UIDevice.isPad {
                                didTapDetailView?(ASWebView(url: R.URLs.TermsOfUse, showClose: false))
                            } else {
                                ASWebView.show(url: R.URLs.TermsOfUse)
                            }
                            
                        case .privacyPolicy:
                            if UIDevice.isPad {
                                didTapDetailView?(ASWebView(url: R.URLs.PrivacyPolicy, showClose: false))
                            } else {
                                ASWebView.show(url: R.URLs.PrivacyPolicy)
                            }
                            
                        case .about:
                            if UIDevice.isPad {
                                didTapDetailView?(ASWebView(url: R.URLs.AboutUS, showClose: false))
                            } else {
                                ASWebView.show(url: R.URLs.AboutUS)
                            }
                            
                        case .triggerPro:
                            if UIDevice.isPad {
                                didTapDetailView?(TriggerProManageView(showClose: false))
                            } else {
                                TriggerProManageView.show()
                            }
                            
                        case .skin:
                            if UIDevice.isPad {
                                didTapDetailView?(SkinSettingsView(showClose: false))
                            } else {
                                SkinSettingsView.show()
                            }
                            
                        case .iCloud:
#if !SIDE_LOAD
                            if UIDevice.isPad {
                                didTapDetailView?(ICloudSettingView(showClose: false))
                            } else {
                                ICloudSettingView.show()
                            }
#endif
                            
                        case .jit:
                            if UIDevice.isPad {
                                didTapDetailView?(JITSettingView(showClose: false))
                            } else {
                                JITSettingView.show()
                            }
                            
                        case .shaders:
                            if UIDevice.isPad {
                                didTapDetailView?(ShaderListView(initType: .normal, showClose: false))
                            } else {
                                ShaderListView.show(initType: .normal)
                            }
                            
                        case .featuredItems:
                            UIApplication.shared.open(R.URLs.PlayCasePromo)
                            
                        case .globalCoreSwitch:
                            if UIDevice.isPad {
                                didTapDetailView?(GlobalCoreSwitchView(showClose: false))
                            } else {
                                GlobalCoreSwitchView.show()
                            }
                            
                        case .quickGame:
                            upateSwitchSettings(extraValue: subActions?.extraValue, cellData: cellData, indexPath: indexPath) {
                                Settings.defalut.quickGame = $0
                            }
                            
                        case .airPlay:
                            if let extraValue = subActions?.extraValue {
                                upateSwitchSettings(extraValue: extraValue, cellData: cellData, indexPath: indexPath) {
                                    Settings.defalut.airPlay = $0
                                }
                            } else {
                                showMemberShip(featuresType: .airplay)
                            }
                            
                        case .fullScreenWhenConnectController:
                            upateSwitchSettings(extraValue: subActions?.extraValue, cellData: cellData, indexPath: indexPath) {
                                Settings.defalut.fullScreenWhenConnectController = $0
                            }
                            
                        case .autoSaveState:
                            upateSwitchSettings(extraValue: subActions?.extraValue, cellData: cellData, indexPath: indexPath) {
                                Settings.defalut.autoSaveState = $0
                            }
                            
                        case .respectSilentMode:
                            upateSwitchSettings(extraValue: subActions?.extraValue, cellData: cellData, indexPath: indexPath) {
                                Settings.defalut.respectSilentMode = $0
                            }
                            
                        case .rumble:
                            let value = upateSwitchSettings(extraValue: subActions?.extraValue, cellData: cellData, indexPath: indexPath)
                            Settings.defalut.updateExtra(key: ExtraKey.rumble.rawValue, value: value)
                            
                        case .appearance:
                            if let index = subActions?.extraValue as? Int {
                                Settings.appearance = Settings.Appearance(rawValue: index) ?? .dark
                                listPageView?.updateCellData(cellData.updateNormalSegment(index: index), indexPath: indexPath)
                            }
                            
                        case .skinSound:
                            let value = upateSwitchSettings(extraValue: subActions?.extraValue, cellData: cellData, indexPath: indexPath)
                            Settings.defalut.updateExtra(key: ExtraKey.skinSoundEffects.rawValue, value: value)
                            
                        case .coverScraping:
                            if UIDevice.isPad {
                                didTapDetailView?(GameCoverScrapingView(showClose: false))
                            } else {
                                GameCoverScrapingView.show()
                            }
                            
                        default:
                            break
                        }
                    }
                    
                case .bottom:
                    break
                }
            }
        default:
            break
        }
    }
}

extension SettingsListView: ViewTransition {
    func viewAlongsideTransition() {
        if UIDevice.isPhone {
            topView.removeFromSuperview()
            topView.updateViewsConstraints()
            reloadData()
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
