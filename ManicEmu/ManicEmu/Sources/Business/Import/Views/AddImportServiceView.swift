//
//  AddImportServiceView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import CloudServiceKit
import RealmSwift

class AddImportServiceView: BaseView {
    
    private var navigationBlurView: NavigationBlurView = {
        let view = NavigationBlurView()
        view.makeBlur(blurColor: UIColor(.dm, light: .white, dark: .black))
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: AddImportServiceCollectionViewCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: LowestHaderReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.contentInset = UIEdgeInsets(top: Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid, left: 0, bottom: Constants.Size.ContentInsetBottom, right: 0)
        return view
    }()
    
    private var cloudServices: [ImportService] = {
        var services: [ImportService] = []
        services.append(ImportService.genService(type: .googledrive))
        services.append(ImportService.genService(type: .dropbox))
        services.append(ImportService.genService(type: .onedrive))
        services.append(ImportService.genService(type: .baiduyun))
        services.append(ImportService.genService(type: .aliyun))
        return services
    }()
    
    private var LanServices: [ImportService] = {
        var services: [ImportService] = []
        services.append(ImportService.genService(type: .webdav))
        services.append(ImportService.genService(type: .samba))
        services.append(ImportService.genService(type: .romm))
        return services
    }()
    
    private var discoverServices: [ImportService] = {
        var services: [ImportService] = []
        return services
    }()
    
    var requireToHideSideMenu: (()->Void)? = nil
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        Log.debug("\(String(describing: Self.self)) init")
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(navigationBlurView)
        navigationBlurView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(self.safeAreaLayoutGuide)
            make.height.equalTo(Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid)
        }
        
        let cloudIcon = UIImageView(image: UIImage(symbol: .cloudFill))
        navigationBlurView.addSubview(cloudIcon)
        cloudIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview().offset(Constants.Size.ContentInsetTop/2)
        }
        let headerTitleLabel = UILabel()
        headerTitleLabel.text = R.string.localizable.addImportServiceHeaderTitle()
        headerTitleLabel.textColor = Constants.Color.LabelPrimary
        headerTitleLabel.font = Constants.Font.title(size: .s)
        navigationBlurView.addSubview(headerTitleLabel)
        headerTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(cloudIcon.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMax)
            make.centerY.equalTo(cloudIcon)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(Constants.Size.ItemHeightMax)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: Constants.Size.ContentSpaceMid,
                                                            bottom: 0,
                                                            trailing: Constants.Size.ContentSpaceMid)
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            
            //header布局
            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                            heightDimension: .absolute(44)),
                                                                         elementKind: UICollectionView.elementKindSectionHeader,
                                                                         alignment: .top)
            headerItem.pinToVisibleBounds = true
            section.boundarySupplementaryItems = [headerItem]
            
            section.decorationItems = [NSCollectionLayoutDecorationItem.background(elementKind: String(describing: AddServiceDecorationCollectionReusableView.self))]
            
            return section
        }
        layout.register(AddServiceDecorationCollectionReusableView.self, forDecorationViewOfKind: String(describing: AddServiceDecorationCollectionReusableView.self))
        return layout
    }
    
    class AddServiceDecorationCollectionReusableView: UICollectionReusableView {
        var backgroundView: UIView = {
            let view = UIView()
            view.layerCornerRadius = Constants.Size.CornerRadiusMax
            view.backgroundColor = Constants.Color.SideList
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(backgroundView)
            backgroundView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(Constants.Size.ItemHeightMin)
                make.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

extension AddImportServiceView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return discoverServices.count > 0 ? 3 : 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return cloudServices.count
        } else if section == 1 {
            return LanServices.count
        } else {
            return discoverServices.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let service: ImportService
        if indexPath.section == 0 {
            service = cloudServices[indexPath.row]
        } else if indexPath.section == 1 {
            service = LanServices[indexPath.row]
        } else {
            service = discoverServices[indexPath.row]
        }
        let cell = collectionView.dequeueReusableCell(withClass: AddImportServiceCollectionViewCell.self, for: indexPath)
        cell.setData(service: service)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: LowestHaderReusableView.self, for: indexPath)
        header.titleLabel.font = Constants.Font.body(size: .l, weight: .semibold)
        if indexPath.section == 0 {
            header.titleLabel.text = R.string.localizable.importAddCloudServiceTitle()
        } else if indexPath.section == 1 {
            header.titleLabel.text = R.string.localizable.importAddLanServiceTitle()
        } else {
            header.titleLabel.text = R.string.localizable.importAddDiscoverServiceTitle()
        }
        return header
    }
}

extension AddImportServiceView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if !PurchaseManager.isMember {
            topViewController()?.present(PurchaseViewController(featuresType: .import), animated: true)
            return
        }
        let service: ImportService
        if indexPath.section == 0 {
            service = cloudServices[indexPath.row]
            CloudDriveConnetor.shard.connect(service: service)
        } else if indexPath.section == 1 {
            service = LanServices[indexPath.row]
            let vc = LanServiceEditViewController(serviceType: service.type)
            vc.successHandler = { [weak self] in
                guard let self = self else { return }
                self.requireToHideSideMenu?()
            }
            topViewController()?.present(vc, animated: true)
        } else {
            service = discoverServices[indexPath.row]
        }
        
    }
}
