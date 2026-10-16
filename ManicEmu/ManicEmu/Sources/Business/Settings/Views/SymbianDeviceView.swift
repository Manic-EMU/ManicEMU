//
//  SymbianDeviceView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/19.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class SymbianDeviceView: BaseView {
    private class AppCell: UICollectionViewCell {
        private let iconView: UIImageView = {
            let view = UIImageView()
            view.contentMode = .scaleAspectFit
            view.layerCornerRadius = R.Size.CornerRadiusSmall
            view.backgroundColor = R.Color.BackgroundSecondary
            return view
        }()
        
        private let captionLabel: UILabel = {
            let view = UILabel()
            view.font = R.Font.Caption()
            view.textColor = R.Color.LabelPrimary
            view.textAlignment = .center
            view.lineBreakMode = .byTruncatingTail
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            enablePressEffect = true
            enableFocusEffects = false
            
            contentView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.height.equalTo(iconView.snp.width)
            }
            
            contentView.addSubview(captionLabel)
            captionLabel.snp.makeConstraints { make in
                make.top.equalTo(iconView.snp.bottom).offset(R.Size.ContentSpaceTiny)
                make.leading.trailing.bottom.equalToSuperview()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func setData(_ game: LibretroSymbianGame) {
            if let icon = game.icon, icon.size != .zero {
                iconView.image = icon
            } else {
                iconView.image = UIImage.placeHolder()
            }
            captionLabel.text = nonempty(game.shortCaption) ?? nonempty(game.longCaption)
        }
    }
    
    private let device: LibretroSymbianDevice
    private var games: [LibretroSymbianGame] = []
    
    private lazy var navigationView: ASNavigationView = {
        let title = nonempty(device.model) ?? nonempty(device.firmwareCode)
        let view = ASNavigationView(.defaultNavigation(title: title,
                                                       titleIcon: .symbol(.candybarphone)))
        view.didTapClose = { [weak self] in
            guard let self else { return }
            if self.showAsSheet {
                self.hide()
            }
        }
        return view
    }()
    
    private lazy var collectionView: BlankSlateCollectionView = {
        let view = BlankSlateCollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: AppCell.self)
        view.showsVerticalScrollIndicator = false
        view.alwaysBounceVertical = true
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        view.blankSlateView = BlankSlateEmptyView(title: R.string.localizable.noSystemApp())
        return view
    }()
    
    required init?(parameters: Any...) {
        guard let device = parameters.compactMap({ $0 as? LibretroSymbianDevice }).first else { return nil }
        self.device = device
        super.init(frame: .zero)
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        reloadGames()
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, env in
            let columns: CGFloat = 3
            let spacing = R.Size.ContentSpaceHuge
            let itemWidth = (env.container.contentSize.width - spacing * 2 - spacing * (columns - 1)) / columns
            let itemHeight = itemWidth + R.Size.ContentSpaceTiny + R.Font.Caption().lineHeight
            
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1 / columns),
                                                                                 heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                              heightDimension: .absolute(itemHeight)),
                                                           subitem: item,
                                                           count: Int(columns))
            group.interItemSpacing = .fixed(spacing)
            
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = NSDirectionalEdgeInsets(top: spacing,
                                                            leading: spacing,
                                                            bottom: spacing,
                                                            trailing: spacing)
            return section
        }
    }
    
    private func reloadGames() {
        UIView.makeLoading()
        let index = device.index
        DispatchQueue.global().async { [weak self] in
            let games = LibretroCore.getSymbianGames(forDeviceIndex: index, appKinds: .system) ?? []
            DispatchQueue.main.async {
                UIView.hideLoading()
                self?.games = games
                self?.collectionView.reloadData()
            }
        }
    }
    
    private func startSystemApp(_ symbianGame: LibretroSymbianGame) {
        let realm = Database.realm
        let game: Game
        if let g = realm.object(ofType: Game.self, forPrimaryKey: Game.SymbianHomePrimary) {
            game = g
        } else {
            game = Game()
            game.gameType = .symbian
            game.id = Game.SymbianHomePrimary
            game.name = Game.SymbianHomePrimary
            try? realm.write {
                realm.add(game)
            }
        }
        game.safeMode = true
        game.symbianSystemApp = SymbianSystemApp(uid: symbianGame.uidString, deviceIndex: device.index, os: SymbianOS.getOS(by: device))
        PlayViewController.startGame(game: game, in: hostingWindowScene)
    }
}

extension SymbianDeviceView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        games.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: AppCell.self, for: indexPath)
        cell.setData(games[indexPath.item])
        return cell
    }
}

extension SymbianDeviceView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        UIDevice.generateHaptic()
        startSystemApp(games[indexPath.item])
    }
}

extension SymbianDeviceView: ShowableView {
    static func show(device: LibretroSymbianDevice) {
        Self.show(parameters: device)
    }
    
    func preferredFocusView() -> UIView? {
        collectionView
    }
}

private func nonempty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
