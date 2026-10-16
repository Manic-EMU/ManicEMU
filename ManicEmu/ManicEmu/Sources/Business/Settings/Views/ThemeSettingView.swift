//
//  ThemeSettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/3.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import RealmSwift

class ThemeSettingView: BaseView {
    
    private enum SectionIndex: Int, CaseIterable {
        case desktopIcon, themeColor, coverStyle, gameList, platformOrder, manufacturerOrder
        var title: String {
            switch self {
            case .desktopIcon:
                R.string.localizable.themeDesktopIconTitle()
            case .themeColor:
                R.string.localizable.themeThemeColorTitle()
            case .coverStyle:
                R.string.localizable.themeCoverStyleTitle()
            case .gameList:
                R.string.localizable.gamesThemeTitle()
            case .platformOrder:
                R.string.localizable.themePlatformOrderTitle()
            case .manufacturerOrder:
                R.string.localizable.themeManufacturerOrderTitle()
            }
        }
    }
    
    private lazy var navigationView: ASNavigationView = {
        var navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.themeSettingTitle(),
                                                                 titleIcon: .symbolImage(R.image.themeRegular_iconSymbols()))
        navigation.enableClose = showClose
        let view = ASNavigationView(navigation)
        view.didTapClose = { [weak self] in
            guard let self else { return }
            if self.showAsSheet {
                self.hide()
            } else {
                self.didTapClose?()
            }
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: DesktopIconCollectionViewCell.self)
        view.register(cellWithClass: ThemeColorCollectionViewCell.self)
        view.register(cellWithClass: CoverStyleCollectionViewCell.self)
        view.register(cellWithClass: GameListStyleCollectionViewCell.self)
        view.register(cellWithClass: PlatformSortCollectionViewCell.self)
        view.register(cellWithClass: TitleSortCollectionCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withClass: TitleHaderCollectionReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.dragInteractionEnabled = true
        view.dragDelegate = self
        view.dropDelegate = self
        view.contentInset = .insets(top: R.Size.ContentSpaceSmall,
                                    bottom: UIDevice.isPad ? (R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceLarge) : R.Size.ContentInsetBottom(window: hostingWindow))
        return view
    }()
    
    private var platformOrder: [String] = {
        return Theme.defalut.platformOrder.map { $0 }
    }()
    
    private var manufacturerOrder: [String] = {
        return Theme.defalut.manufacturerOrder.map { $0.title }
    }()
    
    private var showClose: Bool
    
    ///点击关闭按钮回调
    var didTapClose: (()->Void)? = nil
    
    required init?(parameters: Any...) {
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            if showClose {
                make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            } else {
                make.top.equalToSuperview().offset(R.Size.ContentInsetTop(window: hostingWindow))
            }
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
    
    convenience init(showClose: Bool) {
        self.init(parameters: showClose)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            
            var itemHeight: CGFloat = 0
            if sectionIndex == SectionIndex.desktopIcon.rawValue {
                itemHeight = 130
            } else if sectionIndex == SectionIndex.themeColor.rawValue {
                itemHeight = 100
            } else if sectionIndex == SectionIndex.coverStyle.rawValue {
                itemHeight = 498
            }  else if sectionIndex == SectionIndex.gameList.rawValue {
                itemHeight = 633
            }  else if sectionIndex == SectionIndex.platformOrder.rawValue || sectionIndex == SectionIndex.manufacturerOrder.rawValue {
                itemHeight = 50
            }
            
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(itemHeight)), subitems: [item])
            if sectionIndex == SectionIndex.platformOrder.rawValue || sectionIndex == SectionIndex.manufacturerOrder.rawValue {
                group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                                leading: R.Size.ContentSpaceMedium * 2,
                                                                bottom: 0,
                                                                trailing: R.Size.ContentSpaceMedium * 2)
            } else {
                group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                                leading: R.Size.ContentSpaceMedium,
                                                                bottom: 0,
                                                                trailing: R.Size.ContentSpaceMedium)
            }
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            if sectionIndex == SectionIndex.platformOrder.rawValue || sectionIndex == SectionIndex.manufacturerOrder.rawValue {
                section.interGroupSpacing = R.Size.ContentSpaceLarge
                section.contentInsets = NSDirectionalEdgeInsets(top: R.Size.ContentSpaceLarge + R.Size.ContentSpaceHuge, leading: 0, bottom: R.Size.ContentSpaceLarge, trailing: 0)
            } else {
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: R.Size.ContentSpaceSmall, trailing: 0)
            }
            
            //header布局
            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                            heightDimension: .absolute(44)),
                                                                         elementKind: UICollectionView.elementKindSectionHeader,
                                                                         alignment: .top)
            section.boundarySupplementaryItems = [headerItem]
            
            if sectionIndex == SectionIndex.platformOrder.rawValue || sectionIndex == SectionIndex.manufacturerOrder.rawValue {
                section.decorationItems = [NSCollectionLayoutDecorationItem.background(elementKind: String(describing: PlatformOrderCollectionReusableView.self))]
            }
            
            
            return section
        }
        layout.register(PlatformOrderCollectionReusableView.self, forDecorationViewOfKind: String(describing: PlatformOrderCollectionReusableView.self))
        return layout
    }
    
    class PlatformOrderCollectionReusableView: UICollectionReusableView {
        var descLabel: UILabel = {
            let label = UILabel()
            label.font = R.Font.Caption()
            label.textColor = R.Color.LabelSecondary
            label.text = R.string.localizable.themePlatformOrderDetail()
            return label
        }()
        
        var backgroundView: UIView = {
            let view = UIView()
            view.layerCornerRadius = R.Size.CornerRadiusLarge
            view.backgroundColor = R.Color.BackgroundSecondary
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(descLabel)
            descLabel.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceLarge)
                make.top.equalToSuperview().offset(R.Size.ItemHeightSmall)
            }
            
            addSubview(backgroundView)
            backgroundView.snp.makeConstraints { make in
                make.top.equalTo(descLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
                make.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

extension ThemeSettingView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return SectionIndex.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let section = SectionIndex(rawValue: section) {
            if section == .platformOrder {
                return platformOrder.count
            } else if section == .manufacturerOrder {
                return manufacturerOrder.count
            }
        }
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let section = SectionIndex(rawValue: indexPath.section)!
        switch section {
        case .desktopIcon:
            let cell = collectionView.dequeueReusableCell(withClass: DesktopIconCollectionViewCell.self, for: indexPath)
            return cell
        case .themeColor:
            let cell = collectionView.dequeueReusableCell(withClass: ThemeColorCollectionViewCell.self, for: indexPath)
            return cell
        case .coverStyle:
            let cell = collectionView.dequeueReusableCell(withClass: CoverStyleCollectionViewCell.self, for: indexPath)
            return cell
        case .gameList:
            let cell = collectionView.dequeueReusableCell(withClass: GameListStyleCollectionViewCell.self, for: indexPath)
            return cell
        case .platformOrder:
            let platform = platformOrder[indexPath.row]
            let cell = collectionView.dequeueReusableCell(withClass: PlatformSortCollectionViewCell.self, for: indexPath)
            cell.setData(platform: platform)
            cell.didTapVisibleButton = { [weak self] in
                guard let self else { return }
                let settings = Settings.defalut
                let visible = settings.getPlatformVisible(platform: platform)
                settings.setPlatformVisible(platform: platform, visible: !visible)
                UIView.makeToast(message: !visible ? R.string.localizable.showPlatform(platform) : R.string.localizable.hidePlatform(platform))
                self.collectionView.reloadItems(at: [indexPath])
            }
            return cell
        case .manufacturerOrder:
            let manufacturer = manufacturerOrder[indexPath.row]
            let cell = collectionView.dequeueReusableCell(withClass: TitleSortCollectionCell.self, for: indexPath)
            cell.setData(title: manufacturer)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: TitleHaderCollectionReusableView.self, for: indexPath)
        let section = SectionIndex(rawValue: indexPath.section)!
        header.titleLabel.text = section.title
        return header
    }
}

extension ThemeSettingView: UICollectionViewDelegate {
    
}

extension ThemeSettingView: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        if indexPath.section == SectionIndex.platformOrder.rawValue {
            let pf = platformOrder[indexPath.row]
            let itemProvider = NSItemProvider(object: pf as NSString)
            let dragItem = UIDragItem(itemProvider: itemProvider)
            dragItem.localObject = pf
            return [dragItem]
        } else if indexPath.section == SectionIndex.manufacturerOrder.rawValue {
            let mf = manufacturerOrder[indexPath.row]
            let itemProvider = NSItemProvider(object: mf as NSString)
            let dragItem = UIDragItem(itemProvider: itemProvider)
            dragItem.localObject = mf
            return [dragItem]
        }
        return []
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator) {
        
        if let sourceIndexPath = coordinator.items.first?.sourceIndexPath,
            let destinationIndexPath = coordinator.destinationIndexPath,
           sourceIndexPath.section == destinationIndexPath.section,
           (sourceIndexPath.section == SectionIndex.platformOrder.rawValue || sourceIndexPath.section == SectionIndex.manufacturerOrder.rawValue),
           (destinationIndexPath.section == SectionIndex.platformOrder.rawValue || destinationIndexPath.section == SectionIndex.manufacturerOrder.rawValue) {
            
            if destinationIndexPath.section == SectionIndex.platformOrder.rawValue {
                coordinator.items.forEach { dropItem in
                    guard let sourceIndexPath = dropItem.sourceIndexPath,
                          sourceIndexPath.section == SectionIndex.platformOrder.rawValue,
                          let console = dropItem.dragItem.localObject as? String else { return }
                    
                    collectionView.performBatchUpdates({
                        platformOrder.remove(at: sourceIndexPath.item)
                        platformOrder.insert(console, at: destinationIndexPath.item)
                        collectionView.deleteItems(at: [sourceIndexPath])
                        collectionView.insertItems(at: [destinationIndexPath])
                    }) { [weak self] isSuccess in
                        if isSuccess {
                            self?.updatePlatformOrder()
                        }
                    }
                    
                    coordinator.drop(dropItem.dragItem, toItemAt: destinationIndexPath)
                }
            } else if destinationIndexPath.section == SectionIndex.manufacturerOrder.rawValue {
                coordinator.items.forEach { dropItem in
                    guard let sourceIndexPath = dropItem.sourceIndexPath,
                          sourceIndexPath.section == SectionIndex.manufacturerOrder.rawValue,
                          let console = dropItem.dragItem.localObject as? String else { return }
                    
                    collectionView.performBatchUpdates({
                        manufacturerOrder.remove(at: sourceIndexPath.item)
                        manufacturerOrder.insert(console, at: destinationIndexPath.item)
                        collectionView.deleteItems(at: [sourceIndexPath])
                        collectionView.insertItems(at: [destinationIndexPath])
                    }) { [weak self] isSuccess in
                        if isSuccess {
                            self?.updateManufacturerOrder()
                        }
                    }
                    
                    coordinator.drop(dropItem.dragItem, toItemAt: destinationIndexPath)
                }
            }
            
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        canHandle session: UIDropSession) -> Bool {
        return session.localDragSession != nil
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if let dragItem = session.localDragSession?.items.first?.localObject as? String, let destinationIndexPath {
            if platformOrder.contains(where: { $0 == dragItem }), destinationIndexPath.section == SectionIndex.platformOrder.rawValue {
                return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            } else if manufacturerOrder.contains(where: { $0 == dragItem }), destinationIndexPath.section == SectionIndex.manufacturerOrder.rawValue {
                return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            }
        }
        return UICollectionViewDropProposal(operation: .forbidden)
        
    }
    
    private func updatePlatformOrder() {
        let theme = Theme.defalut
        guard theme.platformOrder.map({ $0 }) != platformOrder else { return }
        Theme.change { realm in
            theme.platformOrder.removeAll()
            theme.platformOrder.append(objectsIn: platformOrder)
        }
    }
    
    private func updateManufacturerOrder() {
        if Theme.defalut.manufacturerOrder.map({ $0.title }) != manufacturerOrder {
            Theme.defalut.updateManufacturerOrder(manufacturerOrder)
        }
    }
}

extension ThemeSettingView: ShowableView {
    
}
