//
//  PSXSBIImportView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/4.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UniformTypeIdentifiers

class PSXSBIImportView: BaseView {
    
    private let datas: [String]
    
    private let game: Game
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation(title: R.string.localizable.sbiImport(),
                                                       titleIcon: .symbol(.lockRectangleStack)))
        view.didTapClose = { [weak self] in
            guard let self else { return }
            self.hide()
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: PSXSBIDescCollectionCell.self)
        view.register(cellWithClass: PSXSBICollectionCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        return view
    }()
    
    required init?(parameters: Any...) {
        guard let game = parameters.compactMap({ $0 as? Game }).first else { return nil }
        self.game = game
        if game.isRomExtsts {
            if game.romUrl.pathExtension.lowercased() == "m3u", let m3uContents = try? String(contentsOf: game.romUrl, encoding: .utf8) {
                //读取多碟文件
                self.datas = m3uContents.components(separatedBy: .newlines).filter { !$0.isEmpty }
            } else {
                self.datas = [game.romUrl.lastPathComponent]
            }
        } else {
            self.datas = []
        }
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
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: sectionIndex == 0 ? .estimated(100) : .absolute(PSXSBICollectionCell.CellHeight())), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: R.Size.ContentSpaceMedium,
                                                            bottom: 0,
                                                            trailing: R.Size.ContentSpaceMedium)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: R.Size.ContentSpaceSmall, trailing: 0)
            return section
        }
        return layout
    }
}

extension PSXSBIImportView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1 + datas.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: PSXSBIDescCollectionCell.self, for: indexPath)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: PSXSBICollectionCell.self, for: indexPath)
            let filePath = game.romUrl.path.deletingLastPathComponent.appendingPathComponent(datas[indexPath.section-1])
            cell.setData(filePath: filePath)
            cell.addFileButton.addTapGesture { [weak self] gesture in
                guard let self else { return }
                if let sbi = UTType(filenameExtension: "sbi") {
                    let supportedType = [sbi]
                    FilesImporter.shared.presentImportController(supportedTypes: supportedType, allowsMultipleSelection: false, manualHandle: { [weak self] urls in
                        guard let self else { return }
                        if let url = urls.first {
                            do {
                                let sbiFilePath = filePath.deletingPathExtension + ".sbi"
                                try FileManager.safeCopyItem(at: url, to: URL(fileURLWithPath: sbiFilePath), shouldReplace: true)
                                UIView.makeToast(message: R.string.localizable.biosImportSuccess(url.lastPathComponent))
                                self.collectionView.reloadData()
                            } catch {
                                UIView.makeToast(message: R.string.localizable.biosImportFailed())
                            }
                        }
                    }, in: self.hostingWindowScene)
                }
            }
            return cell
        }
    }
    
}

extension PSXSBIImportView: UICollectionViewDelegate {
    
}

extension PSXSBIImportView: ShowableView {
    static func show(game: Game) {
        Self.show(parameters: game)
    }
}
