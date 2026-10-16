//
//  SymbianFirmwareView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/19.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UniformTypeIdentifiers

class SymbianFirmwareView: BaseView {
    private static let importDirectory = URL(fileURLWithPath: R.Path.Temp.appendingPathComponent("SymbianFirmwareImport"))
    
    private var devices: [LibretroSymbianDevice] = []
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
            if devices.count > 0 {
                return selectedItems.count == devices.count
            }
            return false
        }
        set {
            if newValue {
                selectedItems = Set(devices.map({ deviceKey($0) }))
            } else {
                selectedItems.removeAll()
            }
        }
    }
    private var selectedItems = Set<String>() {
        didSet {
            updateContents()
            updateTool()
            updateNavigation()
        }
    }
    private var selectedDevices: [LibretroSymbianDevice] {
        devices.filter({ selectedItems.contains(deviceKey($0)) })
    }
    
    private var pendingRomURL: URL? = nil
    private var pendingRpkgURL: URL? = nil
    
    private var listPageView: ASListPageView? = nil
    
    required init?(parameters: Any...) {
        super.init(frame: .zero)
        devices = LibretroCore.getSymbianDevices() ?? []
        
        let listView = ASListPageView(getListPage())
        listView.didActionOccurred = { [weak self] action in
            guard let self else { return }
            self.handleAction(action)
        }
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        listPageView = listView
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if let navigationValue = action.navigationValue {
            if navigationValue.isTapClose {
                if showAsSheet {
                    hide()
                }
            } else if let _ = navigationValue.tapToolsValue {
                guard devices.count > 0 else { return }
                isEditMode = true
            } else if navigationValue.isTapEdit {
                isSelectedAll.toggle()
            } else if navigationValue.isTapCancel {
                isEditMode = false
            }
        } else if let toolValue = action.toolValue {
            if let _ = toolValue.tapOthersValue {
                uninstallSelectedDevices()
            }
        } else if let index = action.normalItemValue?.indexPath.section {
            guard devices.indices.contains(index) else { return }
            let device = devices[index]
            if isEditMode {
                let key = deviceKey(device)
                if selectedItems.contains(key) {
                    selectedItems.remove(key)
                } else {
                    selectedItems.insert(key)
                }
            } else {
                SymbianDeviceView.show(device: device)
            }
        } else if action.isBottom {
            showAddFirmwareSheet()
        } else if let index = action.longPressValue?.section {
            guard !isEditMode, devices.indices.contains(index) else { return }
            isEditMode = true
            selectedItems.insert(deviceKey(devices[index]))
        }
    }
    
    private func getSections() -> [ASListPage.Section] {
        devices.map { device in
            let title = nonempty(device.model) ?? nonempty(device.firmwareCode) ?? ""
            // Core omits `symbianPlatform` on some dumps; fall back to the epocver bucket title.
            let platform = nonempty(device.symbianPlatform) ?? SymbianOS.getOS(by: device).title
            let detail = [nonempty(device.manufacturer), nonempty(device.firmwareCode), platform]
                .compactMap({ $0 })
                .joined(separator: " · ")
            if isEditMode {
                return ASListPage.Section(cells: [
                    .iconTitleDetailRadioCell(title: title,
                                              detail: detail,
                                              isSelected: selectedItems.contains(deviceKey(device)))
                ])
            } else {
                return ASListPage.Section(cells: [
                    .iconTitleDetailChevronCell(title: title,
                                                detail: detail)
                ])
            }
        }
    }
    
    private func getToolView() -> ASListPage.Tool? {
        guard selectedItems.count > 0 else { return nil }
        return ASListPage.Tool.defaultTool(otherIcons: [
            .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red])
        ], hideMainIcon: true)
    }
    
    private func getBlankSlate() -> ASListPage.BlankSlate? {
        guard devices.count == 0 else { return nil }
        return .init(title: R.string.localizable.noFirmware(),
                     detail: R.string.localizable.symbianOSFirmwareDesc(),
                     layoutInsets: .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.ButtonExtraLarge))
    }
    
    private func getNavigation() -> ASListPage.Navigation {
        let tools: [ASIcon] = devices.count == 0 ? [] : [
            .symbolImage(R.image.selectedit_iconSymbols())
        ]
        return ASListPage.Navigation.defaultNavigation(title: R.string.localizable.symbianOSFirmware(),
                                                       titleIcon: .symbol(.candybarphone),
                                                       tools: tools,
                                                       edit: R.string.localizable.selectAll())
    }
    
    private func getListPage() -> ASListPage {
        return ASListPage(navigation: getNavigation(),
                          sections: getSections(),
                          bottom: .large(title: R.string.localizable.addFirmware(),
                                         titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                         titleAlignment: .center,
                                         background: R.Color.Main),
                          blankSlate: getBlankSlate(),
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset),
                          enableLongPress: true)
    }
    
    private func updateContents() {
        guard let listPageView else { return }
        listPageView.sections = getSections()
        listPageView.blankSlate = getBlankSlate()
    }
    
    private func updateTool() {
        guard let listPageView else { return }
        listPageView.tool = getToolView()
    }
    
    private func updateNavigation() {
        guard let listPageView else { return }
        var navigation = getNavigation()
        navigation.state = isEditMode ? .edit : .normal
        navigation.edit = isSelectedAll ? R.string.localizable.deSelectAll() : R.string.localizable.selectAll()
        listPageView.navigation = navigation
    }
    
    private func reloadDevices() {
        devices = LibretroCore.getSymbianDevices() ?? []
        let validKeys = Set(devices.map({ deviceKey($0) }))
        selectedItems = selectedItems.intersection(validKeys)
        if devices.count == 0, isEditMode {
            isEditMode = false
        } else {
            updateContents()
            updateTool()
            updateNavigation()
        }
    }
    
    private func uninstallSelectedDevices() {
        let codes = selectedDevices.compactMap({ nonempty($0.firmwareCode) })
        guard codes.count > 0 else { return }
        UIView.makeLoading()
        DispatchQueue.global().async { [weak self] in
            codes.forEach({
                LibretroCore.uninstallSymbianDevice(withFirmwareCode: $0)
            })
            DispatchQueue.main.async {
                UIView.hideLoading()
                self?.reloadDevices()
            }
        }
    }
    
    private func showAddFirmwareSheet() {
        cleanupImportFiles()
        ASSheetView.show(.init(style: .listPage(makeAddFirmwareListPage())),
                         action: { [weak self] action, updation in
            guard let self else { return .dismiss() }
            if action.listPageValue?.navigationValue?.isTapClose == true {
                self.cleanupImportFiles()
                return .dismiss()
            }
            if action.isTapBackground {
                self.cleanupImportFiles()
                return .none
            }
            if action.listPageValue?.isBottom == true {
                return self.handleInstallFirmware()
            }
            guard let indexPath = action.listPageValue?.normalItemValue?.indexPath else { return .none }
            if indexPath.section == 0 {
                self.presentFirmwareImport(fileExtension: "rom", updation: updation)
            } else {
                self.presentFirmwareImport(fileExtension: "rpkg", updation: updation)
            }
            return .none
        })
    }
    
    private func makeAddFirmwareListPage() -> ASListPage {
        let romCell = ASListPage.Cell.iconTitleChevronCell(icon: .symbolImage(R.image.folder_iconSymbols()),
                                                           title: R.string.localizable.addRomFirmware(),
                                                           chevronTitle: pendingRomURL?.lastPathComponent)
        let rpkgCell = ASListPage.Cell.iconTitleChevronCell(icon: .symbolImage(R.image.folder_iconSymbols()),
                                                            title: R.string.localizable.addRpkgFile(),
                                                            chevronTitle: pendingRpkgURL?.lastPathComponent)
        let sections: [ASListPage.Section] = [
            .init(cells: [romCell],
                  header: .texts([.smallText(R.string.localizable.symbianFirmwareFormatDesc(),
                                             numberOfLines: 0)], pin: false)),
            .init(cells: [rpkgCell])
        ]
        return ASListPage(navigation: .defaultNavigation(title: R.string.localizable.addFirmware(),
                                                         titleIcon: .symbol(.candybarphone)),
                          sections: sections,
                          bottom: .large(title: R.string.localizable.installFirmware(),
                                         titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                         titleAlignment: .center,
                                         background: R.Color.Main),
                          backgroundColor: .clear)
    }
    
    private func presentFirmwareImport(fileExtension: String,
                                       updation: ASSheetView.ASSheetViewUpdation?) {
        guard let utType = UTType(filenameExtension: fileExtension) else { return }
        FilesImporter.shared.presentImportController(supportedTypes: [utType],
                                                     allowsMultipleSelection: false,
                                                     manualHandle: { [weak self] urls in
            guard let self, let url = urls.first else { return }
            let previous = fileExtension == "rom" ? self.pendingRomURL : self.pendingRpkgURL
            guard let copied = self.copyImportFile(url, replacing: previous) else {
                UIView.makeToast(message: R.string.localizable.filesImporterErrorBadCopy(url.lastPathComponent))
                return
            }
            if fileExtension == "rom" {
                self.pendingRomURL = copied
            } else {
                self.pendingRpkgURL = copied
            }
            updation?(.listPage(self.makeAddFirmwareListPage()))
        }, in: hostingWindowScene)
    }
    
    private func handleInstallFirmware() -> ASSheetView.ActionResult {
        guard let romURL = pendingRomURL else {
            UIView.makeToast(message: R.string.localizable.symbianFirmwareNeedRom())
            return .none
        }
        // S60v2+ dumps cannot install without RPKG; keep the sheet open so the user can add it.
        if pendingRpkgURL == nil, LibretroCore.isSymbianRomNeedsRpkg(romURL.path) {
            UIView.makeToast(message: R.string.localizable.symbianFirmwareNeedRpkg())
            return .none
        }
        let romPath = romURL.path
        let rpkgPath = pendingRpkgURL?.path
        return .dismiss { [weak self] in
            self?.installFirmware(romPath: romPath, rpkgPath: rpkgPath)
        }
    }
    
    private func installFirmware(romPath: String, rpkgPath: String?) {
        UIView.makeLoading()
        LibretroCore.installSymbianROM(romPath, rpkgPath: rpkgPath) { [weak self] result, _ in
            UIView.hideLoading()
            switch result {
            case .OK:
                UIView.makeToast(message: R.string.localizable.symbianFirmwareInstallSuccess())
                self?.reloadDevices()
                
                //gen home menu
                let realm = Database.realm
                if realm.object(ofType: Game.self, forPrimaryKey: Game.SymbianHomePrimary) == nil {
                    let game = Game()
                    game.gameType = .symbian
                    game.id = Game.SymbianHomePrimary
                    game.name = Game.SymbianHomePrimary
                    try? realm.write {
                        realm.add(game)
                    }
                }
                
            case .alreadyExist:
                UIView.makeToast(message: R.string.localizable.symbianFirmwareAlreadyExist())
            default:
                UIView.makeToast(message: R.string.localizable.symbianFirmwareInstallFailed())
            }
            self?.cleanupImportFiles()
        }
    }
    
    private func copyImportFile(_ url: URL, replacing previous: URL?) -> URL? {
        let directory = Self.importDirectory
        let destination = directory.appendingPathComponent(url.lastPathComponent)
        if let previous, previous.path != destination.path {
            try? FileManager.default.removeItem(at: previous)
        }
        try? FileManager.safeCopyItem(at: url, to: destination, shouldReplace: true)
        guard FileManager.default.fileExists(atPath: destination.path) else { return nil }
        return destination
    }
    
    private func cleanupImportFiles() {
        try? FileManager.default.removeItem(at: Self.importDirectory)
        pendingRomURL = nil
        pendingRpkgURL = nil
    }
    
    private func deviceKey(_ device: LibretroSymbianDevice) -> String {
        nonempty(device.firmwareCode) ?? "index-\(device.index)"
    }
    
    private func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension SymbianFirmwareView: ShowableView {
    
}
