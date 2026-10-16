//
//  PretendoNetworkingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import RealmSwift

class PretendoNetworkingView: BaseView {
    
    private var pretendoConfig: PretendoNetworkingConfig = .getConfig()
    private var emulationDidQuitNotification: Any? = nil
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation(title: GameType._3ds.localizedShortName + " " + R.string.localizable.pretendo(),
                                                       titleIcon: .symbolImage(R.image.online_iconSymbols())))
        view.didTapClose = { [weak self] in
            guard let self = self else { return }
            self.hide()
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: ArticBaseCollectionCell.self)
        view.register(cellWithClass: NimbusCollectionCell.self)
        view.register(cellWithClass: PretendoHomeMenuCollectionCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: BackgroundColorHaderReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        return view
    }()
    
    deinit {
        if let emulationDidQuitNotification {
            NotificationCenter.default.removeObserver(emulationDidQuitNotification)
        }
    }
    
    required init?(parameters: Any...) {
        super.init(frame: .zero)
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        emulationDidQuitNotification = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "LibretroDidShutdownNotification"), object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            UIView.makeAlert(title: R.string.localizable.systemUpdateAsk(),
                             detail: R.string.localizable.systemUpdateDesc(),
                             cancelTitle: R.string.localizable.systemUpdateFailed(),
                             confirmTitle: R.string.localizable.systemUpdateSuccess(), confirmAction: { [weak self] in
                guard let self else { return }
                if let region = self.pretendoConfig.articBaseRegion,
                   self.generateArticBaseHomeMenu(region: region) {
                    self.pretendoConfig.articBaseDone = true
                    PretendoNetworkingConfig.updateConfig(self.pretendoConfig)
                    self.collectionView.reloadData()
                    UIView.makeToast(message: R.string.localizable.articBaseHomeMenuSuccess())
                } else {
                    UIView.makeToast(message: R.string.localizable.articBaseHomeMenuFailed())
                }
            })
        }
        
        // Trigger the iOS local network permission request
        BonjourKit.shared.startSearchService()
        DispatchQueue.main.asyncAfter(delay: 1) {
            BonjourKit.shared.stopSearchService()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .estimated(200)))

            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(200)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: R.Size.ContentSpaceMedium,
                                                            bottom: 0,
                                                            trailing: R.Size.ContentSpaceMedium)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: R.Size.ContentSpaceSmall, trailing: 0)
            
            //header布局
            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                            heightDimension: .absolute(44)),
                                                                         elementKind: UICollectionView.elementKindSectionHeader,
                                                                         alignment: .top)
            section.boundarySupplementaryItems = [headerItem]
            
            return section
        }
        return layout
    }
    
    private func generateArticBaseHomeMenu(region: String) -> Bool {
        let homeMenus = [
            "JPN": "00008202",
            "USA": "00008f02",
            "EUR": "00009802",
            "AUS": "00009802",
            "CHN": "0000a102",
            "KOR": "0000a902",
            "TWN": "0000b102"
        ]
        
        guard let regionDirectory = homeMenus[region] else {
            return false
        }
        
        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: R.Path.ThreeDSHomeMenuBase.appendingPathComponent(regionDirectory)), includingPropertiesForKeys: [.isDirectoryKey]) {
            for case let fileURL as URL in enumerator {
                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard !isDirectory else { continue }
                guard fileURL.pathExtension.lowercased() == "app" else { continue }
                let realm = Database.realm
                if let hash = FileHashUtil.truncatedHash(url: fileURL) {
                    if let game = realm.object(ofType: Game.self, forPrimaryKey: hash) {
                        if game.romUrl == fileURL {
                            return true
                        } else {
                            try? realm.write {
                                realm.delete(game)
                            }
                        }
                    }
                    let game = Game()
                    game.id = hash
                    game.name = fileURL.deletingPathExtension().lastPathComponent
                    game.fileExtension = fileURL.pathExtension
                    game.gameType = ._3ds
                    let identifier = R.Numbers.ThreeDSHomeMenuIdentifiers[R.Strings.ThreeDSHomeMenuRegions.firstIndex(where: { $0 == region }) ?? 0]
                    game.extras = [
                        ExtraKey.identifier.rawValue: identifier,
                        ExtraKey.regions.rawValue: region,
                        ExtraKey.isArticBaseHomeMenu.rawValue: true
                    ].jsonData()
                    game.aliasName = "Home Menu (\(region))"
                    game.importDate = Date()
                    game.defaultCore = 1
                    try? realm.write { realm.add(game) }
                    return true
                }
            }
        }
        return false
    }
}

extension PretendoNetworkingView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: ArticBaseCollectionCell.self, for: indexPath)
            cell.setData(config: pretendoConfig)
            cell.didIPAddressChange = { [weak self] ipAddress in
                guard let self else { return }
                self.pretendoConfig.articBaseIpAddress = ipAddress
                PretendoNetworkingConfig.updateConfig(self.pretendoConfig)
            }
            cell.didRegionChange = { [weak self] region in
                guard let self else { return }
                self.collectionView.endEditing(true)
                self.pretendoConfig.articBaseRegion = region
            }
            return cell
        } else if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withClass: NimbusCollectionCell.self, for: indexPath)
            cell.setData(config: pretendoConfig)
            cell.didTapButton = { [weak self] in
                guard let self else { return }
                self.collectionView.endEditing(true)
                try? FileManager.safeMergeDirectories(srcURL: URL(fileURLWithPath: R.Path.Nimbus3DSPath), dstURL: URL(fileURLWithPath: R.Path.ThreeDS.appendingPathComponent("sdmc/3ds")))
                LibretroCore.sharedInstance().installAzaharCIA(R.Path.NimbusCiaPath)
                UIView.makeToast(message: R.string.localizable.installNimbusSuccess())
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: PretendoHomeMenuCollectionCell.self, for: indexPath)
            cell.setData(config: pretendoConfig)
            cell.didTapButton = { [weak self] in
                guard let self else { return }
                self.collectionView.endEditing(true)
                
                func openHomeMenu() -> Bool {
                    let realm = Database.realm
                    if let game = realm.objects(Game.self).where({
                        $0.gameType == ._3ds
                    }).filter({
                        $0.isArticBaseHomeMenu
                    }).first {
                        game.handleTapAction(forceQuick: true, in: self.hostingWindowScene)
                        return true
                    } else {
                        return false
                    }
                }
                
                if !openHomeMenu() {
                    if let region = self.pretendoConfig.articBaseRegion,
                       self.generateArticBaseHomeMenu(region: region) {
                        if !openHomeMenu() {
                            UIView.makeToast(message: R.string.localizable.homeMenuNotFound())
                        }
                    } else {
                        UIView.makeToast(message: R.string.localizable.homeMenuNotFound())
                    }
                }
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorHaderReusableView.self, for: indexPath)
        if indexPath.section == 0 {
            header.titleLabel.text = R.string.localizable.articBaseSettings()
        } else if indexPath.section == 1 {
            header.titleLabel.text = R.string.localizable.pretendo()
        } else {
            header.titleLabel.text = R.string.localizable.consoleHomeTitle()
        }
        
        return header
    }
}

extension PretendoNetworkingView: UICollectionViewDelegate {

}

extension PretendoNetworkingView: ShowableView {
    
}
