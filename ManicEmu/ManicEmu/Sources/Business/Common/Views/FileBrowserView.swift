//
//  FileBrowserView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/27.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import CloudServiceKit
import Tiercel

typealias FileBrowserPage = (page: any Hashable, items: [CloudItem])

class FileBrowserView: BaseView {
    enum BrowserType {
        case cloudDrive
        case local
    }
    
    private let browserType: BrowserType
    //cloud drive
    private var provider: CloudServiceProvider? = nil
    
    //local
    private var baseUrl: URL? = nil
    
    private var rootNavigationTitle: String? = nil
    
    private var pages = [FileBrowserPage]() {
        didSet {
            if self.isEditMode {
                self.isSelectedAll = false
            } else {
                self.updateContents()
                self.updateNavigation()
            }
        }
    }
    
    private var currentPage: FileBrowserPage? {
        pages.last
    }
    
    private var currentPageItems: [CloudItem] {
        currentPage?.items ?? []
    }

    private var isEditMode: Bool = false {
        didSet {
            if isEditMode {
                updateContents()
                updateNavigation()
            } else {
                isSelectedAll = false
            }
        }
    }
    private var isSelectedAll: Bool {
        get {
            if currentPageItems.count > 0 {
                return selectedItems.count == currentPageItems.filter({ !$0.isDirectory }).count
            }
            return false
        }
        set {
            if newValue {
                selectedItems = Set(currentPageItems.enumerated().filter({ !$1.isDirectory }).map({ $0.offset }))
            } else {
                selectedItems.removeAll()
            }
        }
    }
    private var selectedItems = Set<Int>() {
        didSet {
            updateContents()
            updateTool()
            updateNavigation()
        }
    }
    private var selectedPageItems: [CloudItem] {
        return currentPageItems.enumerated().filter({
            selectedItems.contains($0.offset)
        }).map({
            $0.element
        })
    }
    
    private var beginDownloadNotification: Any? = nil
    private var stopDownloadNotification: Any? = nil
    
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            self.handleAction(action)
        }
        return view
    }()
    
    deinit {
        if let beginDownloadNotification = beginDownloadNotification {
            NotificationCenter.default.removeObserver(beginDownloadNotification)
        }
        if let stopDownloadNotification = stopDownloadNotification {
            NotificationCenter.default.removeObserver(stopDownloadNotification)
        }
    }
    
    required init?(parameters: Any...) {
        if let provider = parameters.compactMap({ $0 as? CloudServiceProvider }).first {
            self.browserType = .cloudDrive
            self.provider = provider
        } else if let baseUrl = parameters.compactMap({ $0 as? URL }).first {
            self.browserType = .local
            self.baseUrl = baseUrl
        } else {
            return nil
        }
        super.init(frame: .zero)
        
        self.rootNavigationTitle = parameters.compactMap({ $0 as? String }).first
        
        switch browserType {
        case .cloudDrive:
            self.provider = parameters.compactMap({ $0 as? CloudServiceProvider }).first
            
        case .local:
            break
        }
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        beginDownloadNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.BeginDownload, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            self.updateNavigation()
        }
        
        stopDownloadNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.StopDownload, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            self.updateNavigation()
        }
        
        switch browserType {
        case .cloudDrive:
            guard let page = provider?.rootItem else { return }
            loadFiles(page: page)
            
        case .local:
            guard let baseUrl else { return }
            loadFiles(url: baseUrl)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func loadFiles(page: CloudItem) {
        guard let provider else { return }
        UIView.makeLoading()
        provider.contentsOfDirectory(page, completion: { [weak self] result in
            UIView.hideLoading()
            guard let self = self else { return }
            switch result {
            case .success(let items):
                self.pages.append((page, items))
                self.listPageView.collectionView.scrollToTop()
                
            case .failure(let error):
                Log.debug("applySnapshot error:\(error)")
                UIView.makeToast(message: error.localizedDescription)
            }
        })
    }
    
    private func loadFiles(url: URL) {
        if let contents = try? FileManager.default.contentsOfDirectory(at: url,
                                                                       includingPropertiesForKeys: [.isDirectoryKey]) {
            let items = contents.map({
                let isDirectory = (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return CloudItem(id: "",
                                 name: $0.lastPathComponent,
                                 path: $0.path,
                                 isDirectory: isDirectory)
            })
            pages.append((url, items))
        }
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if let navigationValue = action.navigationValue {
            //navigation action
            if navigationValue.isTapClose {
                //close
                if showAsSheet {
                    hide()
                }
            } else if let index =  navigationValue.tapToolsValue {
                if index == 0 {
                    //edit mode
                    isEditMode = true
                } else if index == 1 {
                    //download manager
                    DownloadManageView.show()
                }
            } else if navigationValue.isTapEdit {
                //selected/deselected all
                isSelectedAll.toggle()
            } else if navigationValue.isTapCancel {
                //leave edit mode
                isEditMode = false
            } else if navigationValue.isTapTitle {
                pages.removeLast()
            }
        } else if let _ = action.toolValue {
            //download
            switch browserType {
            case .cloudDrive:
                downloadFiles(items: selectedPageItems)
                
            case .local:
                break
            }
            
            
        } else if let index = action.normalItemValue?.indexPath.section {
            if isEditMode {
                if selectedItems.contains(index) {
                    //deselected save state
                    selectedItems.remove(index)
                } else {
                    //selected save state
                    selectedItems.insert(index)
                }
            } else {
                let item = currentPageItems[index]
                switch browserType {
                case .cloudDrive:
                    loadFiles(page: item)
                    
                case .local:
                    loadFiles(url: URL(fileURLWithPath: item.path))
                    
                }
            }
        } else if let index = action.longPressValue?.section {
            guard !isEditMode else { return }
            let item = currentPageItems[index]
            guard !item.isDirectory else { return }
            isEditMode = true
            selectedItems.insert(index)
        }
    }
    
    private func getListPage() -> ASListPage {
        let blankSlate = ASListPage.BlankSlate(title: R.string.localizable.noContentResult())
        return ASListPage(navigation: getNavigation(),
                          sections: getSections(),
                          blankSlate: blankSlate,
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset),
                          enableLongPress: true)
    }
    
    private func getNavigation() -> ASListPage.Navigation {
        let icon: ASIcon
        var title: String? = nil
        if pages.count > 1 {
            icon = .symbol(.chevronLeft)
            
            switch browserType {
            case .cloudDrive:
                if let page = currentPage?.page as? CloudItem {
                    title = page.path
                }
                
            case .local:
                if let page = currentPage?.page as? URL {
                    title = page.relativePath
                }
            }
        } else {
            icon = .symbolImage(R.image.folder_iconSymbols())
            
            title = rootNavigationTitle ?? "/"
        }
        
        var navigation = ASListPage.Navigation.defaultNavigation(title: title,
                                                                 titleLineBreakMode: .byTruncatingHead,
                                                                 titleIcon: icon,
                                                                 tools: [
                                                                    .symbolImage(R.image.selectedit_iconSymbols()),
                                                                    .symbolImage(R.image.cloudDownload_iconSymbols(), animated: DownloadManager.shared.hasDownloadTask)
                                                                 ])
        if pages.count > 1 {
            navigation.enableTitleInteractive = true
        }
        return navigation
    }
    
    private func getSections() -> [ASListPage.Section] {
        var cells = [ASListPage.Cell]()
        for (index, item) in currentPageItems.enumerated() {
            let dateString = "\(item.modificationDate?.dateTimeString(ofStyle: .short) ?? "")"
            let sizeString = FileType.humanReadableFileSize(item.size > 0 ? UInt64(item.size) : 0) ?? ""
            let detail = dateString + (!dateString.isEmpty && !sizeString.isEmpty ? "   " : "") + sizeString
            if isEditMode {
                if item.isDirectory {
                    cells.append(.iconTitleDetailCell(icon: .image(R.image.file_browser_folder()),
                                                      title: item.name,
                                                      detail: detail,
                                                      enablePressEffect: false))
                } else {
                    cells.append(.iconTitleDetailCheckCell(icon: .image(R.image.file_browser_document()),
                                                           title: item.name,
                                                           detail: detail,
                                                           isSelected: selectedItems.contains(index)))
                }
            } else {
                if item.isDirectory {
                    cells.append(.iconTitleDetailChevronCell(icon: .image(R.image.file_browser_folder()),
                                                             title: item.name,
                                                             detail: detail))
                } else {
                    cells.append(.iconTitleDetailCell(icon: .image(R.image.file_browser_document()),
                                                      title: item.name,
                                                      detail: detail,
                                                      enablePressEffect: false))
                }
            }
        }
        
        return cells.map({
            ASListPage.Section(cells: [$0])
        })
    }
    
    private func getToolView() -> ASListPage.Tool? {
        if selectedItems.count > 0 {
            return ASListPage.Tool.defaultTool(otherIcons: [
                .symbol(.arrowDownToLine)
            ], hideMainIcon: true)
        }
        return nil
    }
    
    private func updateNavigation() {
        var navigation = getNavigation()
        navigation.state = isEditMode ? .edit : .normal
        navigation.edit = isSelectedAll ? R.string.localizable.deSelectAll() : R.string.localizable.selectAll()
        listPageView.navigation = navigation
    }
    
    private func updateContents() {
        listPageView.sections = getSections()
    }
    
    private func updateTool() {
        listPageView.tool = getToolView()
    }
    
    private func downloadFiles(items: [CloudItem]) {
        guard !items.isEmpty else { return }
        
        if let provider = provider as? SMBServiceProvider {
            UIView.makeLoading()
            provider.download(paths: items.map({ $0.path })) { [weak self] urls, falures in
                guard let self = self else { return }
                UIView.hideLoading()
                self.isSelectedAll = false
                var error = [ImportError]()
                if !falures.isEmpty {
                    let errorsString = falures.reduce("") { ($0.isEmpty ? $0 : "\n") + $1 }
                    error.append(ImportError.downloadError(filenames: errorsString))
                }
                FilesImporter.importFiles(urls: urls, preErrors: error)
            }
            return
        }
        
        var downloadItems: [String: URL] = [:]
        var errors: [Error] = []
        var headers: [String: String]? = nil
        let group = DispatchGroup()
        for item in items {
            if DownloadManager.shared.sessionManager.succeededTasks.contains(where: { $0.fileName == item.name })  {
                // Skip files that are already in the download cache.
                errors.append(ImportError.downloadExist(fileName: item.name))
                continue
            } else {
                
                if let provider = provider as? BaiduPanServiceProvider {
                    headers = ["User-Agent": "pan.baidu.com"]
                    group.enter()
                    provider.downloadLink(of: item) { result in
                        switch result {
                        case .success(let success):
                            downloadItems[item.name] = success
                        case .failure(let failure):
                            errors.append(failure)
                        }
                        group.leave()
                    }
                } else if let provider = provider as? AliyunDriveServiceProvider {
                    group.enter()
                    provider.downloadLink(of: item) { result in
                        switch result {
                        case .success(let success):
                            downloadItems[item.name] = success
                        case .failure(let failure):
                            errors.append(failure)
                        }
                        group.leave()
                    }
                } else if let provider = provider as? GoogleDriveServiceProvider {
                    let request = provider.downloadableRequest(of: item)
                    if let url = request?.url {
                        downloadItems[item.name] = url
                    }
                    headers = request?.allHTTPHeaderFields
                } else if let provider = provider as? DropboxServiceProvider {
                    group.enter()
                    provider.getTemporaryLink(item: item) { result in
                        switch result {
                        case .success(let success):
                            downloadItems[item.name] = success
                        case .failure(let failure):
                            errors.append(failure)
                        }
                        group.leave()
                    }
                } else if let provider = provider as? OneDriveServiceProvider {
                    group.enter()
                    provider.downloadLink(of: item) { result in
                        switch result {
                        case .success(let success):
                            downloadItems[item.name] = success
                        case .failure(let failure):
                            errors.append(failure)
                        }
                        group.leave()
                    }
                } else if let provider = provider as? WebDavServiceProvider {
                    let request = provider.downloadableRequest(of: item)
                    if let url = request?.url {
                        downloadItems[item.name] = url
                    }
                    headers = request?.allHTTPHeaderFields
                } else if let provider = provider as? RommServiceProvider {
                    let request = provider.downloadableRequest(of: item)
                    if let url = request?.url {
                        downloadItems[item.name] = url
                        if let romId = Int(item.id.split(separator: "/").first.map(String.init) ?? "") {
                            Log.debug("[RomM] download queue file=\(item.name) romId=\(romId) serviceId=\(provider.serviceId) url=\(url.absoluteString)")
                            RommLibrary.shared.registerDownloadedRom(fileName: item.name,
                                                                    romId: romId,
                                                                    serviceId: provider.serviceId)
                        } else {
                            Log.debug("[RomM] download queue skipped: cannot parse romId from item.id=\(item.id)")
                        }
                    }
                    headers = request?.allHTTPHeaderFields
                }
            }
        }
        
        group.notify(queue: .main) {
            if errors.count > 0 {
                let errorsString = errors.reduce("") {
                    $0 + ($0.isEmpty ? "" : "\n") + $1.localizedDescription
                }
                UIView.makeToast(message: R.string.localizable.importDownloadError(errorsString))
            }
            if !downloadItems.isEmpty {
                var names: [String] = []
                var urls: [URL] = []
                downloadItems.forEach { key, value in
                    names.append(key)
                    urls.append(value)
                }
                DownloadManager.shared.downloads(urls: urls, fileNames: names, headers: headers)
                self.isSelectedAll = false
            }
        }
    }
}

extension FileBrowserView: ShowableView {
    static func show(provider: CloudServiceProvider, navigationTitle: String? = nil) {
        if let navigationTitle {
            Self.show(parameters: provider, navigationTitle)
        } else {
            Self.show(parameters: provider)
        }
    }
    
    static func show(url: URL) {
        guard url.isFileURL else { return }
        let homePath = R.Path.Document.deletingLastPathComponent
        Self.show(parameters: URL(fileURLWithPath: url.path.replacingOccurrences(of: homePath, with: ""),
                                  relativeTo: URL(fileURLWithPath: homePath)))
    }
}
