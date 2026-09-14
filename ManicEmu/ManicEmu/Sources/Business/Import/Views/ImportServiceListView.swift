//
//  ImportServiceListView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import RealmSwift

class ImportServiceListView: BaseView {
    
    var didTapAddService: (() -> Void)? = nil
    
    private lazy var importNavigationView: ImportNavigationView = {
        let view = ImportNavigationView()
        view.addServiceButton.didTapButton = { [weak self] in
            guard let self = self else { return }
            self.didTapAddService?()
        }
        
        view.toolsView.didTapButton = { [weak self] index in
            guard let self = self else { return }
            if index == 0 {
                //download
                DownloadManageView.show()
            } else if index == 1 {
                //question
                ASWebView.show(url: R.URLs.GameImportGuide)
            } else if index == 2 {
                //More
                ChevronSheetView.show(sections: [
                    (header: R.string.localizable.addGameLink(),
                     cells: [.iconTitleChevronCell(icon: .symbolImage(R.image.link_iconSymbols()),
                                                   title: R.string.localizable.addGameLink())]),
                    (header: R.string.localizable.fetchGamesFromOtherEmulators(),
                     cells: [
                        .iconTitleChevronCell(title: R.string.localizable.fetchGamesFromMeloNX()),
                        .iconTitleChevronCell(title: R.string.localizable.fetchGamesFromXeniOS()),
                        .iconTitleChevronCell(title: R.string.localizable.fetchGamesFromDukeX()),
                        .iconTitleChevronCell(title: R.string.localizable.fetchGamesFromARMSX2())
                     ])
                ], completion: { indexPath in
                    guard let indexPath else { return }
                    if indexPath.section == 0 {
                        AddUrlGameView.show()
                        return
                    }
                    let types: [EmulatorInteractionKit.EmulatorType] = [.meloNX, .xeniOS, .dukeX, .armsx2]
                    if types.indices.contains(indexPath.row) {
                        EmulatorInteractionKit.fetchGames(type: types[indexPath.row])
                    }
                })
            }
        }
        
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: ImportMottoCollectionViewCell.self)
        view.register(cellWithClass: ImportFileCollectionViewCell.self)
        view.register(cellWithClass: ImportServiceListCollectionViewCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: ImportFooterCollectionReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.contentInset = getCollectionViewContentInset()
        view.isFocusable = true
        return view
    }()
    
    //文件单独一个section
    private let fileService = ImportService.genService(type: .files, detail: R.string.localizable.importServiceListFilesDetail())
    
    private var serviceUpdateToken: NotificationToken? = nil
    private var services: [ImportService] = {
        var services: [ImportService] = []
        //默认添加wifi、粘贴板、多碟助手、RomPatcher
        services.append(ImportService.genService(type: .wifi, detail: WebServer.shard.isRunning ? R.string.localizable.importServiceListWiFiOnDetail(WebServer.shard.ipAddress) : R.string.localizable.importServiceListWiFiOffDetail()))
        
        services.append(ImportService.genService(type: .paste, detail: R.string.localizable.importServiceListPasteDetail()))
        
        services.append(ImportService.genService(type: .multiDisc))
        
        services.append(ImportService.genService(type: .romPatcher))
        return services
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        //访问数据库
        let realm = Database.realm
        let objects = realm.objects(ImportService.self).where { !$0.isDeleted }
        serviceUpdateToken = objects.observe(keyPaths: [\ImportService.detail]) { [weak self] changes in
            guard let self = self else { return }
            if case .update(_, let deletions, let insertions, let modifications) = changes {
                Log.debug("更新服务列表")
                if !deletions.isEmpty || !insertions.isEmpty {
                    self.updateServices(objects: objects)
                }
                if !modifications.isEmpty {
                    self.collectionView.reloadData()
                }
            }
        }
        updateServices(objects: objects)
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(importNavigationView)
        importNavigationView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(R.Size.NavigationHeight)
            make.top.equalToSuperview().offset(UIDevice.isPhone && UIDevice.isLandscape ? 0 : R.Size.ContentInsetTop)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            
            let widthDimension: NSCollectionLayoutDimension
            if sectionIndex == 0 {
                widthDimension = .fractionalWidth(UIDevice.isLandscape ? 0.5 : 1)
            } else {
                widthDimension = .fractionalWidth(UIDevice.isLandscape ? 0.25 : 0.5)
            }
            
            let heightDimension: NSCollectionLayoutDimension
            if sectionIndex == 0 {
                heightDimension = .estimated(100)
            } else {
                heightDimension = .absolute(154)
            }
            
            //item
            let itemLayoutSize = NSCollectionLayoutSize(widthDimension: widthDimension,
                                                        heightDimension: heightDimension)
            let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
            
            //group
            let count: Int
            if sectionIndex == 0 {
                count = UIDevice.isLandscape ? 2 : 1
            } else {
                count = UIDevice.isLandscape ? 4 : 2
            }
            let groupLayoutSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                         heightDimension: heightDimension)
            let group: NSCollectionLayoutGroup = NSCollectionLayoutGroup.horizontal(layoutSize: groupLayoutSize,
                                                                                    subitem: item,
                                                                                    count: count)
            group.interItemSpacing = .fixed(R.Size.ContentSpaceMedium)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = sectionIndex == 0 ? R.Size.ContentSpaceSmall : R.Size.ContentSpaceMedium
            section.contentInsets = NSDirectionalEdgeInsets(top: sectionIndex == 0 ? 0 : R.Size.ContentSpaceMedium,
                                                            leading: R.Size.ContentSpaceHuge,
                                                            bottom: sectionIndex == 0 ? 0 : R.Size.ContentSpaceMedium,
                                                            trailing: R.Size.ContentSpaceHuge)
            
            
            if sectionIndex == 1 {
                let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                heightDimension: .estimated(150)),
                                                                             elementKind: UICollectionView.elementKindSectionFooter,
                                                                             alignment: .bottom)
                section.boundarySupplementaryItems.append(footerItem)
            }
            return section
            
        }
        return layout
    }
    
    private func updateServices(objects: Results<ImportService>) {
        services.removeSubrange(4...)
        services.append(contentsOf: objects.map({ $0 }))
        collectionView.reloadSections([1])
    }
    
    private func getCollectionViewContentInset() -> UIEdgeInsets {
        var top = R.Size.ContentInsetTop
        if UIDevice.isLandscape {
            top += (R.Size.NavigationHeight + R.Size.ContentSpaceLarge)
        }
        let bottom = R.Size.ContentInsetBottom + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceLarge
        return .insets(top: top, bottom: bottom)
    }
}

extension ImportServiceListView: ViewTransition {
    func viewWillTransition() {
        if let cell = collectionView.cellForItem(at: IndexPath(row: 0, section: 0)) as? ImportMottoCollectionViewCell {
            cell.updateViews()
        }
    }
    
    func viewAlongsideTransition() {
        if UIDevice.isPhone {
            importNavigationView.snp.updateConstraints { make in
                make.top.equalToSuperview().offset(UIDevice.isPhone && UIDevice.isLandscape ? 0 : R.Size.ContentInsetTop)
            }
        } else if UIDevice.isPad, UIDevice.isLandscape {
            collectionView.contentInset = getCollectionViewContentInset()
        }
    }
}

extension ImportServiceListView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 2 : services.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                let cell = collectionView.dequeueReusableCell(withClass: ImportMottoCollectionViewCell.self, for: indexPath)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withClass: ImportFileCollectionViewCell.self, for: indexPath)
                cell.setData(service: fileService)
                return cell
            }
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: ImportServiceListCollectionViewCell.self, for: indexPath)
            let service = services[indexPath.row]
            cell.setData(service: service)
            if service.type == .wifi {
                let enableSelectedEffect = WebServer.shard.isRunning ? true : false
                cell.enablePressEffect = enableSelectedEffect
                cell.didValueChange = { [weak service, weak self, weak cell] isOn in
                    let enableSelectedEffect = WebServer.shard.isRunning ? true : false
                    if isOn {
                        cell?.enablePressEffect = enableSelectedEffect
                        WebServer.shard.start()
                        service?.detail = R.string.localizable.importServiceListWiFiOnDetail(WebServer.shard.ipAddress)
                    } else {
                        cell?.enablePressEffect = enableSelectedEffect
                        WebServer.shard.stop()
                        service?.detail = R.string.localizable.importServiceListWiFiOffDetail()
                    }
                    DispatchQueue.main.asyncAfter(delay: 0.35) {
                        self?.collectionView.reloadItems(at: [indexPath])
                    }
                }
            } else {
                cell.enablePressEffect = true
                cell.didValueChange = nil
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: ImportFooterCollectionReusableView.self, for: indexPath)
        footer.channelButton.addTapGesture { gesture in
            if Locale.prefersCN {
                UIApplication.shared.open(R.URLs.JoinQQ)
            } else {
                UIApplication.shared.open(R.URLs.JoinDiscord)
            }
        }
        footer.channelButton.onFocusConfirm = {
            if Locale.prefersCN {
                UIApplication.shared.open(R.URLs.JoinQQ)
            } else {
                UIApplication.shared.open(R.URLs.JoinDiscord)
            }
            return true
        }
        return footer
    }
}

extension ImportServiceListView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0, indexPath.row == 1 {
            //files
            FilesImporter.shared.presentImportController()
            return
        }
        
        guard indexPath.section == 1 else { return }
        let service = services[indexPath.row]
        switch service.type {
        case .wifi:
            if WebServer.shard.isRunning {
                UIPasteboard.general.string = WebServer.shard.ipAddress
                UIView.makeToast(message: R.string.localizable.ipCopy())
            }
            
        case .paste:
            //读取粘贴板
            PasteImporter.paste()
            
        case .googledrive, .dropbox, .onedrive, .baiduyun, .aliyun:
            
            if !PurchaseManager.isMember {
                topViewController()?.present(PurchaseViewController(featuresType: .import), animated: true)
                return
            }
            
            //打开文件浏览器
            if let provider = service.cloudDriveProvider {
                UIView.makeLoading()
                CloudDriveConnetor.shard.renewToken(service: service, provider: provider) {
                    UIView.hideLoading()
                    FileBrowserView.show(provider: provider, navigationTitle: service.title)
                }
            }
            
        case .samba, .webdav:
            
            if !PurchaseManager.isMember {
                topViewController()?.present(PurchaseViewController(featuresType: .import), animated: true)
                return
            }
            
            if let provider = service.lanDriveProvider {
                FileBrowserView.show(provider: provider, navigationTitle: service.title)
            }
            
        case .multiDisc:
            //多碟助手
            MultiDiscBuilderView.show()
            
        case .romPatcher:
            //RomPatcher
            RomPatcherView.show()
        
        default:
            break
        }
    }
    
    //Long press to bring up an interactive menu (iOS 15 compatible)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuConfiguration(for: collectionView, at: indexPath)
    }
    
    //Long press to bring up an interactive menu (iOS 16+)
    @available(iOS 16.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first else { return nil }
        return contextMenuConfiguration(for: collectionView, at: indexPath)
    }
    
    //Unified context menu configuration logic
    private func contextMenuConfiguration(for collectionView: UICollectionView, at indexPath: IndexPath) -> UIContextMenuConfiguration? {
        guard indexPath.section == 1 else { return nil }
        let service = services[indexPath.row]
        guard service.type != .wifi && service.type != .paste && service.type != .multiDisc && service.type != .romPatcher else { return nil }
        
        ChevronSheetView.show(cellOptions: [.iconTitleChevronCell(icon: .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
                                                                  title: R.string.localizable.importServiceDelete(),
                                                                  titleColor: R.Color.Red)],
                              completion: { index in
            if let _ = index {
                ImportService.change { realm in
                    if Settings.defalut.iCloudSyncEnable {
                        service.isDeleted = true
                    } else {
                        realm.delete(service)
                    }
                }
            }
        })
        return nil
    }
}
