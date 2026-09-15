//
//  RommSettingsView.swift
//  ManicEmu
//
//  Created by Chris Habibi on 6/30/26.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class RommSettingsView: BaseView {

    private let items: [SettingItem.ItemType] = [.rommSyncOnLaunch, .rommSyncOnGameExit]

    private var navigationBlurView: NavigationBlurView = {
        let view = NavigationBlurView()
        view.makeBlur()
        return view
    }()

    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: SettingsItemCollectionViewCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.contentInset = UIEdgeInsets(top: Constants.Size.ItemHeightMid, left: 0, bottom: UIDevice.isPad ? (Constants.Size.ContentInsetBottom + Constants.Size.HomeTabBarSize.height + Constants.Size.ContentSpaceMax) : Constants.Size.ContentInsetBottom, right: 0)
        return view
    }()

    private lazy var closeButton: SymbolButton = {
        let view = SymbolButton(image: UIImage(symbol: .xmark, font: Constants.Font.body(weight: .bold)), enableGlass: true)
        view.enableRoundCorner = true
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.didTapClose?()
        }
        return view
    }()

    var didTapClose: (()->Void)? = nil

    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }

    init(showClose: Bool = true) {
        super.init(frame: .zero)
        Log.debug("\(String(describing: Self.self)) init")
        backgroundColor = Constants.Color.Background

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(navigationBlurView)
        navigationBlurView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(self.safeAreaLayoutGuide)
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }

        let icon = UIImageView(image: UIImage(symbol: .arrowTriangle2Circlepath, font: Constants.Font.body(weight: .bold)))
        icon.contentMode = .scaleAspectFit
        navigationBlurView.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
        }
        let headerTitleLabel = UILabel()
        headerTitleLabel.text = R.string.localizable.rommSyncTitle()
        headerTitleLabel.textColor = Constants.Color.LabelPrimary
        headerTitleLabel.font = Constants.Font.title(size: .s)
        navigationBlurView.addSubview(headerTitleLabel)
        headerTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.centerY.equalTo(icon)
        }

        if showClose {
            navigationBlurView.addSubview(closeButton)
            closeButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
                make.centerY.equalToSuperview()
                make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeItem(for type: SettingItem.ItemType) -> SettingItem {
        switch type {
        case .rommSyncOnLaunch:
            return SettingItem(type: .rommSyncOnLaunch, isOn: Settings.defalut.getExtraBool(key: ExtraKey.rommSyncOnLaunch.rawValue) ?? true)
        case .rommSyncOnGameExit:
            return SettingItem(type: .rommSyncOnGameExit, isOn: Settings.defalut.getExtraBool(key: ExtraKey.rommSyncOnGameExit.rawValue) ?? true)
        default:
            return SettingItem(type: type)
        }
    }

    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, env in
            guard let self else { return nil }
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(Constants.Size.ItemHeightMax)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                          leading: Constants.Size.ContentSpaceMid,
                                                          bottom: 0,
                                                          trailing: Constants.Size.ContentSpaceMid)
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: Constants.Size.ContentSpaceMax, trailing: 0)
            section.decorationItems = [NSCollectionLayoutDecorationItem.background(elementKind: String(describing: RommSettingsDecorationView.self))]
            return section
        }
        layout.register(RommSettingsDecorationView.self, forDecorationViewOfKind: String(describing: RommSettingsDecorationView.self))
        return layout
    }

    class RommSettingsDecorationView: UICollectionReusableView, DynamicShadow {
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
                make.top.bottom.equalToSuperview()
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
}

extension RommSettingsView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: SettingsItemCollectionViewCell.self, for: indexPath)
        let type = items[indexPath.row]
        cell.setData(item: makeItem(for: type))
        cell.switchButton.onDisableTap(handler: nil)
        if type == .rommSyncOnLaunch {
            cell.switchButton.onChange { value in
                Settings.defalut.updateExtra(key: ExtraKey.rommSyncOnLaunch.rawValue, value: value)
            }
        } else if type == .rommSyncOnGameExit {
            cell.switchButton.onChange { value in
                Settings.defalut.updateExtra(key: ExtraKey.rommSyncOnGameExit.rawValue, value: value)
            }
        } else {
            cell.switchButton.onChange { _ in }
        }
        return cell
    }
}

extension RommSettingsView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return false
    }
}
