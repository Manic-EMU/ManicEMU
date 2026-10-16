//
//  PriceView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import StoreKit

class PriceView: BaseView {
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: PriceItemCollectionCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: PurchaseButtonReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(top: R.Size.ContentSpaceHuge,
                                    bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        return view
    }()
    
    private weak var purchaseButtonView: PurchaseButtonReusableView? = nil
    

    private var products = [Product]() {
        didSet {
            self.collectionView.reloadData()
        }
    }
    
    private var selectedProduct: Product? = nil
    
    var needToClosePurchaseView: (()->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        UIView.makeLoading()
        PurchaseManager.getProducts { [weak self] products in
            guard let self = self else { return }
            UIView.hideLoading()
            if products.isEmpty {
                UIView.makeAlert(detail: R.string.localizable.getProductsFailedTitle())
            } else {
                self.products = products
                //默认选中能购买的
                if PurchaseManager.isForeverMember || PurchaseManager.isAnnualMember || PurchaseManager.isMonthlyMember {
                    self.selectedProduct = products.first(where: {PurchaseProductType(rawValue: $0.id) == .forever })
                    if let row = products.firstIndex(where: {PurchaseProductType(rawValue: $0.id) == .forever }) {
                        self.collectionView.selectItem(at: IndexPath(row: row, section: 0), animated: false, scrollPosition: [])
                    }
                } else {
                    self.selectedProduct = products.first
                    self.collectionView.selectItem(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: [])
                }
            }
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
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
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(R.Size.ItemHeightExtraLarge)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: R.Size.ContentSpaceHuge, bottom: 0, trailing: R.Size.ContentSpaceHuge)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = R.Size.ContentSpaceMedium
            let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                            heightDimension: .absolute(129)),
                                                                         elementKind: UICollectionView.elementKindSectionFooter,
                                                                         alignment: .bottom)
            section.boundarySupplementaryItems.append(footerItem)
            
            return section
        }
        return layout
    }
}

extension PriceView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return products.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: PriceItemCollectionCell.self, for: indexPath)
        let product = products[indexPath.row]
        cell.setData(product: product, isSelected: selectedProduct?.id == product.id)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: PurchaseButtonReusableView.self, for: indexPath)
        if let selectedProduct = self.selectedProduct {
            let info = selectedProduct.purchaseDisplayInfo
            footer.setData(title: info.title, descripton: info.detail, enable: info.enable)
        }
        footer.buttonContainer.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            //购买内购
            if let product = self.selectedProduct {
                UIView.makeLoading()
                PurchaseManager.purchase(product: product) { [weak self] message in
                    UIView.hideLoading()
                    if let message = message {
                        UIView.makeAlert(detail: message, cancelTitle: R.string.localizable.confirmTitle())
                    } else {
                        //购买成功
                        self?.needToClosePurchaseView?()
                        CheersView.makePurchaseCheers(in: self?.hostingWindowScene)
                    }
                }
            }
        }
        purchaseButtonView = footer
        return footer
    }
}

extension PriceView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedProduct = products[indexPath.row]
        if let purchaseDisplayInfo = selectedProduct?.purchaseDisplayInfo {
            purchaseButtonView?.setData(title: purchaseDisplayInfo.title, descripton: purchaseDisplayInfo.detail, enable: purchaseDisplayInfo.enable)
        }
    }
}
