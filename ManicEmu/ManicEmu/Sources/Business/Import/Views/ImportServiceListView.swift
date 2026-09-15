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
    
    private var navigationBlurView: NavigationBlurView = {
        let view = NavigationBlurView()
        view.makeBlur()
        return view
    }()
    
    var addServiceButton: SymbolButton = {
        let view = SymbolButton(image: UIImage(symbol: .plus, font: Constants.Font.body(size: .m, weight: .bold)), enableGlass: true)
        view.enableRoundCorner = true
        return view
    }()
    
    private lazy var moreContextMenuButton: ContextMenuButton = {
        var actions: [UIMenuElement] = []
        actions.append((UIAction(title: R.string.localizable.importHowTo(), image: UIImage(symbol: .bookClosed)) { [weak self] _ in
            guard let self = self else { return }
            //how to import
            topViewController()?.present(WebViewController(url: Constants.URLs.GameImportGuide), animated: true)
        }))
        actions.append((UIAction(title: R.string.localizable.fetchGamesFromMeloNX(), image: UIImage(symbol: .gamecontroller)) { [weak self] _ in
            guard let self = self else { return }
            EmulatorInteractionKit.fetchGames(type: .meloNX)
        }))
        actions.append((UIAction(title: R.string.localizable.fetchGamesFromXeniOS(), image: UIImage(symbol: .gamecontroller)) { [weak self] _ in
            guard let self = self else { return }
            EmulatorInteractionKit.fetchGames(type: .xeniOS)
        }))
        let view = ContextMenuButton(image: nil, menu: UIMenu(children: actions))
        return view
    }()
    
    private lazy var moreButton: SymbolButton = {
        let view = SymbolButton(symbol: .ellipsis, enableGlass: true)
        view.enableRoundCorner = true
        view.addTapGesture { [weak self] gesture in
            self?.moreContextMenuButton.triggerTapGesture()
        }
        return view
    }()
    
    private var downloadManageButton: DownloadButton = {
        let view = DownloadButton()
        view.addTapGesture { gesture in
            topViewController()?.present(DownloadViewController(), animated: true)
        }
        return view
    }()
    
    private let backgroundGradientView: UIView = {
        let view = UIView()
        view.masksToBounds = true
        return view
    }()
    
    lazy var collectionView: UICollectionView = {
        let view = NoControllCollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: ImportFileCollectionViewCell.self)
        view.register(cellWithClass: ImportServiceListCollectionViewCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: ImportFooterCollectionReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        let top = Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid
        let bottom = Constants.Size.ContentInsetBottom + Constants.Size.HomeTabBarSize.height + Constants.Size.ContentSpaceMax
        view.contentInset = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
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
    
    private let gradientSize = CGSize(width: 495, height: 307)
    
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
        
        updateBackgroundGradientView()
        
        addSubview(backgroundGradientView)
        backgroundGradientView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid)
            make.width.equalToSuperview()
            make.height.equalTo(gradientSize.height)
        }
        
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
        
        let navigationContainer = UIView()
        navigationBlurView.addSubview(navigationContainer)
        navigationContainer.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        
        navigationContainer.addSubview(addServiceButton)
        addServiceButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
        }
        
        navigationContainer.addSubview(moreContextMenuButton)
        navigationContainer.addSubview(moreButton)
        moreButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
        }
        moreContextMenuButton.snp.makeConstraints { make in
            make.edges.equalTo(moreButton)
        }
        
        navigationContainer.addSubview(downloadManageButton)
        downloadManageButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
            make.trailing.equalTo(moreButton.snp.leading).offset(-Constants.Size.ContentSpaceMin)
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
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackgroundGradientView()
        }
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(sectionIndex == 0 ? 1 : 0.5),
                                                                                 heightDimension: .fractionalHeight(1)))
            
            let group: NSCollectionLayoutGroup = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension:  sectionIndex == 0 ? .absolute(164) : .absolute(154)), subitem: item, count: sectionIndex == 0 ? 1 : 2)
            
            group.interItemSpacing = .fixed(Constants.Size.ContentSpaceMid)//item间距
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            
            section.interGroupSpacing = Constants.Size.ContentSpaceMax
            
            section.contentInsets = NSDirectionalEdgeInsets(top: sectionIndex == 0 ? 0 : Constants.Size.ContentSpaceMax,
                                                            leading: Constants.Size.ContentSpaceHuge,
                                                            bottom: sectionIndex == 0 ? 0 : Constants.Size.ContentSpaceMax,
                                                            trailing: Constants.Size.ContentSpaceHuge)
            if sectionIndex == 1 {
                let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                heightDimension: .absolute(150)),
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
    
    private func updateBackgroundGradientView() {
        backgroundGradientView.subviews.forEach({ $0.removeFromSuperview() })
        //渐变背景
        let gradientView = UIView(frame: CGRect(origin: .zero, size: gradientSize))
        let ovalLayer = CAShapeLayer()
        ovalLayer.path = UIBezierPath(ovalIn: gradientView.frame).cgPath
        gradientView.layer.mask = ovalLayer
        
        gradientView.addGradient(colors: Constants.Color.Gradient,
                                 direction: UIView.GradientDirection(startPoint: CGPoint(x: 0, y: 0.5),
                                                                     endPoint: CGPoint(x: 1, y: 0.5)))
        let maskGradientView = UIView(frame: CGRect(origin: .zero, size: gradientSize))
        maskGradientView.addGradient(colors: [Constants.Color.Background.withAlphaComponent(0.92),
                                              Constants.Color.Background,
                                              Constants.Color.Background],
                                     locations: [0, 0.62, 1],
                                     direction: UIView.GradientDirection(startPoint: CGPoint(x: 0.5, y: 0),
                                                                         endPoint: CGPoint(x: 0.5, y: 1)))
        
        gradientView.addSubview(maskGradientView)
        maskGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        backgroundGradientView.addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(gradientSize)
        }
    }
}

extension ImportServiceListView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : services.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: ImportFileCollectionViewCell.self, for: indexPath)
            cell.setData(service: fileService)
            cell.infoContainerView.addTapGesture { _ in
                //打开系统文件浏览器
                FilesImporter.shared.presentImportController()
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: ImportServiceListCollectionViewCell.self, for: indexPath)
            let service = services[indexPath.row]
            cell.setData(service: service)
            if service.type == .wifi {
                let enableSelectedEffect = WebServer.shard.isRunning ? true : false
                cell.enableInteractive = enableSelectedEffect
                cell.delayInteractiveTouchEnd = enableSelectedEffect
                cell.switchButton.onChange { [weak service, weak self, weak cell] isOn in
                    let enableSelectedEffect = WebServer.shard.isRunning ? true : false
                    if isOn {
                        cell?.enableInteractive = enableSelectedEffect
                        cell?.delayInteractiveTouchEnd = enableSelectedEffect
                        WebServer.shard.start()
                        service?.detail = R.string.localizable.importServiceListWiFiOnDetail(WebServer.shard.ipAddress)
                    } else {
                        cell?.enableInteractive = enableSelectedEffect
                        cell?.delayInteractiveTouchEnd = enableSelectedEffect
                        WebServer.shard.stop()
                        service?.detail = R.string.localizable.importServiceListWiFiOffDetail()
                    }
                    DispatchQueue.main.asyncAfter(delay: 0.35) {
                        self?.collectionView.reloadItems(at: [indexPath])
                    }
                }
            } else {
                cell.enableInteractive = true
                cell.delayInteractiveTouchEnd = true
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        //随机游戏footer
        let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: ImportFooterCollectionReusableView.self, for: indexPath)
        footer.channelButton.addTapGesture { gesture in
            if Locale.prefersCN {
                UIApplication.shared.open(Constants.URLs.JoinQQ)
            } else {
                UIApplication.shared.open(Constants.URLs.JoinDiscord)
            }
        }
        return footer
    }
}

extension ImportServiceListView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }
        let service = services[indexPath.row]
        switch service.type {
        case .files:
            break
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
                    topViewController(appController: true)?.present(BaseNavigationController(rootViewController: CloudDriveBrowserViewController(provider: provider, directory: provider.rootItem, navigationTitle: service.title)), animated: true)
                }
            }
        case .samba, .webdav, .romm:

            if !PurchaseManager.isMember {
                topViewController()?.present(PurchaseViewController(featuresType: .import), animated: true)
                return
            }
            
            if let provider = service.lanDriveProvider {
                topViewController()?.present(BaseNavigationController(rootViewController: CloudDriveBrowserViewController(provider: provider, directory: provider.rootItem, navigationTitle: service.title)), animated: true)
            }
        case .multiDisc:
            //多碟助手
            topViewController()?.present(MultiDiscBuilderViewController(), animated: true)
        case .romPatcher:
            //RomPatcher
            topViewController()?.present(RomPatcherViewController(), animated: true)
        }
    }
    
    //长按弹出可交互菜单 (iOS 15兼容)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuConfiguration(for: collectionView, at: indexPath)
    }
    
    //长按弹出可交互菜单 (iOS 16+)
    @available(iOS 16.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first else { return nil }
        return contextMenuConfiguration(for: collectionView, at: indexPath)
    }
    
    //统一的上下文菜单配置逻辑
    private func contextMenuConfiguration(for collectionView: UICollectionView, at indexPath: IndexPath) -> UIContextMenuConfiguration? {
        guard indexPath.section == 1 else { return nil }
        let service = services[indexPath.row]
        guard service.type != .wifi && service.type != .paste && service.type != .multiDisc && service.type != .romPatcher else { return nil }
        return UIContextMenuConfiguration(actionProvider:  { _ in
            UIMenu(children: [UIAction(title: R.string.localizable.importServiceDelete(), image: UIImage(systemSymbol: .trash), attributes: .destructive, handler: { _ in
                ImportService.change { realm in
                    if Settings.defalut.iCloudSyncEnable {
                        service.isDeleted = true
                    } else {
                        realm.delete(service)
                    }
                }
            })])
        })
    }
}
