//
//  MultiDiscBuilderView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/5.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UniformTypeIdentifiers

class MultiDiscBuilderView: BaseView {
    protocol M3uItem {
        var url: URL { get set }
        var files: [URL] { get set }
    }
    
    struct DiscItem: M3uItem {
        var url: URL
        var files: [URL]
    }
    
    /// One playlist can only contain one disc-image type. `.cue`/`.gdi` keep companion tracks; others are one file per disc.
    private enum PlaylistFormat: Equatable {
        case undetermined
        case cue
        case gdi
        case standalone(String)
        
        static let standaloneExtensions = ["chd", "cdi", "iso", "rvz", "gcm", "gcz", "img", "d64"]
        static let cueSidecars = ["bin", "iso", "img"]
        static let gdiSidecars = ["bin", "raw", "iso"]
        
        var pickerExtensions: [String] {
            switch self {
            case .undetermined:
                return ["cue", "gdi", "bin", "raw"] + Self.standaloneExtensions
            case .cue:
                return ["cue"] + Self.cueSidecars
            case .gdi:
                return ["gdi"] + Self.gdiSidecars
            case .standalone(let ext):
                return [ext]
            }
        }
        
        var addButtonSuffix: String {
            switch self {
            case .undetermined:
                return "ROM"
            case .cue:
                return ".cue .bin"
            case .gdi:
                return ".gdi .bin .raw"
            case .standalone(let ext):
                return ".\(ext)"
            }
        }
        
        static func from(fileExtension ext: String) -> PlaylistFormat {
            switch ext {
            case "cue": return .cue
            case "gdi": return .gdi
            default: return .standalone(ext)
            }
        }
        
        static var supportedFormatList: String {
            ([".cue(.bin)", ".gdi(.bin .raw)"] + standaloneExtensions.map { ".\($0)" })
                .joined(separator: "   ")
        }
    }
    
    private var datas: [M3uItem] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
    private var playlistFormat: PlaylistFormat {
        guard let ext = datas.first?.url.pathExtension.lowercased(), !ext.isEmpty else {
            return .undetermined
        }
        return PlaylistFormat.from(fileExtension: ext)
    }
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation(title: R.string.localizable.multiDiscBuilder(),
                                                       titleIcon: .symbolImage(R.image.disc_iconSymbols()),
                                                       tools: [.symbolImage(R.image.faq_iconSymbols()),
                                                               .symbolImage(R.image.ellipsis_iconSymbols())]))
        view.didTapClose = { [weak self] in
            guard let self else { return }
            guard self.datas.count > 0, !self.hasAddToLibrary else {
                self.hide()
                return
            }
            UIView.makeAlert(detail: R.string.localizable.multiDiscCloseAlert(),
                             cancelTitle: R.string.localizable.m3uFileImport(),
                             confirmTitle: R.string.localizable.multiDiscContinueClose(),
                             cancelAction: { [weak self] in
                guard let self else { return }
                self.importGame()
                self.hide()
            }, confirmAction: { [weak self] in
                guard let self else { return }
                self.hide()
            })
        }
        
        view.didTapTools = { [weak self] index in
            guard let self else { return }
            if index == 0 {
                UIView.makeAlert(detail: R.string.localizable.multiDiscSupportedFormats(PlaylistFormat.supportedFormatList),
                                 cancelTitle: R.string.localizable.gotIt())
                return
            }
            ChevronSheetView.show(stringOptions: [R.string.localizable.m3uFileShare()], completion: { [weak self] index in
                guard let self else { return }
                if let index {
                    if let url = self.generateM3uFile() {
                        ShareManager.shareFile(fileUrl: url)
                    } else {
                        UIView.makeToast(message: R.string.localizable.generateM3uFailed())
                    }
                }
            })
            
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: MultiDiscDescCollectionCell.self)
        view.register(cellWithClass: MultiDiscItemCollectionCell.self)
        view.register(cellWithClass: MultiDiscAddCollectionCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.dragInteractionEnabled = true
        view.dragDelegate = self
        view.dropDelegate = self
        let bottom = (UIDevice.isPad ? (R.Size.ContentInsetBottom + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceLarge) : R.Size.ContentInsetBottom) + R.Size.ItemHeightMedium + R.Size.ContentSpaceMedium
        view.contentInset = .insets(top: R.Size.ContentSpaceSmall,
                                    bottom: bottom)
        return view
    }()
    
    private lazy var addToLibraryButton: ASButtonView = {
        let view = ASButtonView(.large(title: R.string.localizable.m3uFileImport(),
                                       titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                       titleAlignment: .center,
                                       background: R.Color.Main))
        view.didTapButton = { [weak self] in
            guard let self else { return }
            self.importGame()
        }
        view.enableFocusEffects = false
        return view
    }()
    
    private var addItemText = R.string.localizable.multiDiscAddFile("ROM")
    
    private var hasAddToLibrary = false;
    
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
            make.leading.bottom.trailing.equalToSuperview()
        }
        
        addSubview(addToLibraryButton)
        addToLibraryButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            make.height.equalTo(R.Size.ItemHeightMedium)
            make.bottom.equalToSuperview().offset(-R.Size.ContentInsetBottom-R.Size.ContentSpaceMedium)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private func generateM3uFile() -> URL? {
        guard self.datas.count > 0 else {
            return nil
        }
        
        let m3uContent = self.datas.reduce("") { partialResult, item in
            if partialResult.isEmpty {
                return partialResult + item.url.lastPathComponent
            } else {
                return partialResult + "\n" + item.url.lastPathComponent
            }
        }
        let name = self.datas.first!.url.lastPathComponent.deletingPathExtension + ".m3u"
        let m3uUrl = URL(fileURLWithPath: R.Path.Temp.appendingPathComponent(name))
        try? FileManager.safeRemoveItem(at: m3uUrl)
        try? m3uContent.writeWithCompletePath(to: m3uUrl)
        return m3uUrl
    }
    
    private func importGame() {
        guard datas.count > 0 else {
            UIView.makeToast(message: R.string.localizable.generateM3uFailed())
            return
        }
        if let m3uUrl = generateM3uFile() {
            var urls: [URL] = [m3uUrl]
            for item in datas {
                urls.append(item.url)
                for subItem in item.files {
                    urls.append(subItem)
                }
            }
            FilesImporter.importFiles(urls: urls)
            hasAddToLibrary = true
        } else {
            UIView.makeToast(message: R.string.localizable.generateM3uFailed())
        }
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, env in
            guard let self else { return nil }
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            //group布局
            let height: NSCollectionLayoutDimension
            if sectionIndex == 0 {
                height = .estimated(100)
            } else if sectionIndex == self.datas.count + 1 {
                height = .estimated(R.Size.ItemHeightLarge)
            } else {
                height = .absolute(MultiDiscItemCollectionCell.CellHeight(itemCount: self.datas[sectionIndex-1].files.count))
            }
            
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: height), subitems: [item])
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
    
    private func contentTypes(for extensions: [String]) -> [UTType] {
        var seen = Set<String>()
        var types: [UTType] = []
        for ext in extensions {
            guard seen.insert(ext).inserted else { continue }
            guard let type = UTType(filenameExtension: ext) ?? UTType(filenameExtension: ext, conformingTo: .data) else { continue }
            types.append(type)
        }
        return types
    }
    
    private func copyToTemp(_ url: URL) -> URL {
        let dest = URL(fileURLWithPath: R.Path.Temp.appendingPathComponent(url.lastPathComponent))
        try? FileManager.safeCopyItem(at: url, to: dest, shouldReplace: true)
        return dest
    }
    
    private func appendDiscItems(_ items: [DiscItem]) {
        guard !items.isEmpty else { return }
        let format: PlaylistFormat
        if let ext = items.first?.url.pathExtension.lowercased(), !ext.isEmpty {
            format = PlaylistFormat.from(fileExtension: ext)
        } else {
            format = .undetermined
        }
        addItemText = R.string.localizable.multiDiscAddFile(format.addButtonSuffix)
        var next = datas
        for item in items {
            next.append(item)
        }
        datas = next
    }
}

extension MultiDiscBuilderView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1 + datas.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: MultiDiscDescCollectionCell.self, for: indexPath)
            return cell
        } else if indexPath.section == datas.count + 1 {
            let cell = collectionView.dequeueReusableCell(withClass: MultiDiscAddCollectionCell.self, for: indexPath)
            cell.titleLabel.text = addItemText
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: MultiDiscItemCollectionCell.self, for: indexPath)
            cell.setData(index: indexPath.section, item: datas[indexPath.section-1])
            cell.deleteIcon.addTapGesture { [weak self] gesture in
                guard let self else { return }
                if self.datas.count == 1 {
                    self.addItemText = R.string.localizable.multiDiscAddFile("ROM")
                }
                self.datas.remove(at: indexPath.section-1)
            }
            return cell
        }
    }
    
}

extension MultiDiscBuilderView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return indexPath.section == datas.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == datas.count + 1 {
            let supportedTypes = contentTypes(for: playlistFormat.pickerExtensions)
            guard !supportedTypes.isEmpty else { return }
            FilesImporter.shared.presentImportController(supportedTypes: supportedTypes) { [weak self] urls in
                guard let self else { return }
                let urls = urls.sorted(by: { $0.path < $1.path })
                let selectedExts = Set(urls.map { $0.pathExtension.lowercased() }.filter { !$0.isEmpty })
                let hasCue = selectedExts.contains("cue")
                let hasGdi = selectedExts.contains("gdi")
                let standaloneHits = PlaylistFormat.standaloneExtensions.filter { selectedExts.contains($0) }
                
                let ingestCompanion: Bool
                switch self.playlistFormat {
                case .cue, .gdi:
                    ingestCompanion = true
                case .standalone:
                    ingestCompanion = false
                case .undetermined:
                    if hasCue && hasGdi {
                        UIView.makeToast(message: R.string.localizable.multiDiscImportErrorConflict())
                        return
                    }
                    let sidecars = Set(hasCue ? PlaylistFormat.cueSidecars : (hasGdi ? PlaylistFormat.gdiSidecars : []))
                    let foreignStandalone = standaloneHits.filter { !sidecars.contains($0) }
                    if (hasCue || hasGdi) && !foreignStandalone.isEmpty {
                        UIView.makeToast(message: R.string.localizable.multiDiscImportErrorConflict())
                        return
                    }
                    if !hasCue && !hasGdi && standaloneHits.count > 1 {
                        UIView.makeToast(message: R.string.localizable.multiDiscImportErrorConflict())
                        return
                    }
                    ingestCompanion = hasCue || hasGdi
                }
                
                let standaloneExt: String?
                if case .standalone(let ext) = self.playlistFormat {
                    standaloneExt = ext
                } else {
                    standaloneExt = standaloneHits.first
                }
                
                if ingestCompanion {
                    let (_, errors, companionItems) = FilesImporter.handleMultiFiles(urls: urls)
                    if errors.count > 0 {
                        UIView.makeAlert(detail: errors.reduce("", { $0 + $1.localizedDescription + "\n"}))
                    }
                    let discs = companionItems.map { item in
                        DiscItem(url: self.copyToTemp(item.url), files: item.files.map { self.copyToTemp($0) })
                    }
                    if discs.isEmpty {
                        if errors.isEmpty {
                            UIView.makeToast(message: R.string.localizable.multiDiscImportErrorMissing())
                        }
                        return
                    }
                    self.appendDiscItems(discs)
                } else if let ext = standaloneExt {
                    let discs = urls.compactMap { url -> DiscItem? in
                        guard url.pathExtension.lowercased() == ext else { return nil }
                        return DiscItem(url: self.copyToTemp(url), files: [])
                    }
                    self.appendDiscItems(discs)
                } else {
                    UIView.makeToast(message: R.string.localizable.multiDiscImportErrorMissing())
                }
            }
        }
    }
}

extension MultiDiscBuilderView: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    func enableDragAndDrop(indexPath: IndexPath) -> Bool {
        return indexPath.section > 0 && indexPath.section < datas.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard enableDragAndDrop(indexPath: indexPath) else { return [] }
        let item = datas[indexPath.section-1]
        let itemProvider = NSItemProvider(object: item.url.path as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              enableDragAndDrop(indexPath: destinationIndexPath) else { return }
        
        coordinator.items.forEach { dropItem in
            guard let sourceIndexPath = dropItem.sourceIndexPath,
                  enableDragAndDrop(indexPath: sourceIndexPath) else { return }
            
            datas.swapAt(sourceIndexPath.section-1, destinationIndexPath.section-1)
            collectionView.reloadSections([sourceIndexPath.section, destinationIndexPath.section])
            coordinator.drop(dropItem.dragItem, toItemAt: destinationIndexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        canHandle session: UIDropSession) -> Bool {
        return session.localDragSession != nil
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        guard let indexPath = destinationIndexPath, indexPath.section > 0 else {
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
    
}

extension MultiDiscBuilderView: ShowableView {
    
}
