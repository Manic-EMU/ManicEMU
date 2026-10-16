//
//  PSPNetworkingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/7.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit

class PSPNetworkingView: BaseView {
    
    private var pspConfig: PSPNetworkingConfig = .getConfig()
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation(title: R.string.localizable.pspNetworking(),
                                                       titleIcon: .symbolImage(R.image.online_iconSymbols())))
        view.didTapClose = { [weak self] in
            guard let self = self else { return }
            if PSPNetworkingConfig.getConfig() != self.pspConfig {
                PSPNetworkingConfig.updateConfig(self.pspConfig)
            }
            self.hide()
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: PSPNetworkingSwitchCell.self)
        view.register(cellWithClass: PSPNetworkingConfigCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: BackgroundColorHaderReusableView.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: BackgroundColorDetailFooterReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        return view
    }()
    
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
        
        if pspConfig.enable, pspConfig.type == .local {
            updateBonjour()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, env in
            guard let self else { return nil }
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            let itemHeight: CGFloat
            if sectionIndex == 0 {
                itemHeight = R.Size.ItemHeightLarge
            } else {
                itemHeight = PSPNetworkingConfigCell.CellHeight(config: self.pspConfig)
            }

            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(itemHeight)), subitems: [item])
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
            
            if sectionIndex != 0 {
                let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                heightDimension: .estimated(44)),
                                                                             elementKind: UICollectionView.elementKindSectionFooter,
                                                                             alignment: .bottom)
                section.boundarySupplementaryItems.append(footerItem)
            }
            
            return section
        }
        return layout
    }
    
    private func updateBonjour() {
        if pspConfig.enable, pspConfig.type == .local {
            if pspConfig.asHost {
                BonjourKit.shared.stopSearchService()
                BonjourKit.shared.publishService(port: pspConfig.asHostPort, delay: 1)
                BonjourKit.shared.didSearchServiceList = nil
            } else {
                BonjourKit.shared.stopService()
                BonjourKit.shared.startSearchService()
                BonjourKit.shared.didSearchServiceList = { [weak self] list in
                    guard let self else { return }
                    self.pspConfig.hostList = list
                    self.collectionView.reloadData()
                }
            }
        } else {
            BonjourKit.shared.stopService()
            BonjourKit.shared.stopSearchService()
            BonjourKit.shared.didSearchServiceList = nil
        }
    }
}

extension PSPNetworkingView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return pspConfig.enable ? 2 : 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: PSPNetworkingSwitchCell.self, for: indexPath)
            cell.enableSwitchButton.setOn(pspConfig.enable, animated: true)
            cell.enableSwitchButton.onChange { [weak self] value in
                guard let self else { return }
                self.pspConfig.enable = value
                DispatchQueue.main.asyncAfter(delay: 0.35) {
                    self.updateBonjour()
                    self.collectionView.reloadData()
                }
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: PSPNetworkingConfigCell.self, for: indexPath)
            cell.didTypeChange = { [weak self] type in
                guard let self else { return }
                self.pspConfig.type = type
                self.collectionView.reloadData()
                self.updateBonjour()
            }
            cell.didAsHostChange = { [weak self] asHost in
                guard let self else { return }
                self.pspConfig.asHost = asHost
                self.collectionView.reloadData()
                self.updateBonjour()
            }
            cell.didConnectedHostChange = { [weak self] connectedHost in
                guard let self else { return }
                if let connectedHost, !connectedHost.isEmpty {
                    self.pspConfig.connectedHost = connectedHost
                }
            }
            cell.didConnectedIPChange = { [weak self] connectedIP in
                guard let self else { return }
                self.pspConfig.connectedLocalIP = connectedIP
            }
            cell.didPortChange = { [weak self] port in
                guard let self else { return }
                self.pspConfig.asHostPort = port
                self.updateBonjour()
            }
            cell.setData(config: pspConfig)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorHaderReusableView.self, for: indexPath)
            header.titleLabel.text = indexPath.section == 0 ? R.string.localizable.networking() : R.string.localizable.networkingConfiguration()
            return header
        } else {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: BackgroundColorDetailFooterReusableView.self, for: indexPath)
            footer.titleLabel.text = pspConfig.type == .local ? R.string.localizable.localNetworkingDesc() : R.string.localizable.onlineNetworkingDesc()
            return footer
        }
    }
}

extension PSPNetworkingView: UICollectionViewDelegate {
    
}

extension PSPNetworkingView: ShowableView {
    
}
