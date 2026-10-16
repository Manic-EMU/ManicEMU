//
//  CitraAdvancedSettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/14.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UniformTypeIdentifiers

class CitraAdvancedSettingView: BaseView {
    enum SettingType {
        case none, `switch`, option, action
    }
    
    ///When the integer span doesn't exceed this value, use the picker to edit; otherwise, fall back to text input.
    private static let pickerIntegerSpanLimit = 400
    
    ///Each item in the list corresponds to a visible key in the INI file.
    private struct SettingItem {
        let section: String
        let key: String
        let type: SettingType
        let note: String?
    }
    
    private var currentConfig = try? INIFile(fileName: R.Path.CitraConfig)
    private let defaultConfig = try? INIFile(fileName: R.Path.CitraDefaultConfig)
    private var isModified = false
    private var items: [SettingItem] = []
    
    private var hideCompletion: (() -> Void)? = nil
    
    private lazy var listView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        super.init(frame: .zero)
        
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - Page building
    private func getListPage() -> ASListPage {
        var navigation = ASListPage.Navigation.defaultNavigation(title: GameType._3ds.coreConfigTitle,
                                                                 titleIcon: GameType._3ds.coreConfigIcon,
                                                                 tools: [.symbolImage(R.image.ellipsis_iconSymbols())])
        navigation.enableClose = true
        
        return ASListPage(navigation: navigation,
                          sections: buildSections(),
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
    }
    
    private func buildSections() -> [ASListPage.Section] {
        items = []
        guard let config = currentConfig, defaultConfig != nil else { return [] }
        
        var sections = [ASListPage.Section]()
        for (index, sectionName) in config.sectionList.enumerated() {
            if sectionName == "_DEFAULT_" {
                continue
            }
            
            guard let keys = config.keyList[sectionName] else { continue }
            var didAddSectionHeader = false
            for key in keys {
                let type = getType(key: key)
                guard type != .none else { continue }
                
                let item = SettingItem(section: sectionName,
                                       key: key,
                                       type: type,
                                       note: keyNote(section: sectionName, key: key))
                items.append(item)
                
                var section = ASListPage.Section(cells: [makeCell(for: item)])
                if !didAddSectionHeader {
                    if index == 1 {
                        section.header = .texts([
                            .init(attributes: .init(text: R.string.localizable.coreConfigsAlert(),
                                                    color: R.Color.LabelSecondary,
                                                    font: R.Font.Footnote(),
                                                    numberOfLines: 0)),
                            .init(attributes: .init(text: sectionName,
                                                    color: R.Color.LabelSecondary,
                                                    font: R.Font.Subheadline(emphasis: true)))
                          ], pin: false)
                    } else {
                        section.header = .defaultHeader(title: sectionName)
                    }
                    didAddSectionHeader = true
                }
                if let note = item.note, !note.isEmpty {
                    section.footer = .texts([.smallText(note, numberOfLines: 0)], pin: false)
                }
                sections.append(section)
            }
        }
        return sections
    }
    
    private func makeCell(for item: SettingItem) -> ASListPage.Cell {
        switch item.type {
        case .switch:
            return ASListPage.Cell.iconTitleDetailSwitchCell(title: item.key,
                                                             state: currentBool(for: item) ? .on : .off,
                                                             enablePressEffect: false)
        case .option:
            return .iconTitleDetailChevronCell(title: item.key,
                                               chevronTitle: currentOptionLabel(for: item))
        case .action:
            return .iconTitleDetailChevronCell(title: item.key,
                                               chevronTitle: currentString(for: item))
        case .none:
            return .iconTitleDetailChevronCell(title: item.key)
        }
    }
    
    private func reloadList() {
        listView.updatePage(getListPage())
    }
    
    private func keyNote(section: String, key: String) -> String? {
        currentConfig?.readKeyNote(section, key)?
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func currentBool(for item: SettingItem) -> Bool {
        if item.key == "use_cpu_jit", !LibretroCore.jitAvailable() {
            return false
        }
        let fallback = defaultConfig?.readBool(item.section, item.key, false) ?? false
        return currentConfig?.readBool(item.section, item.key, fallback) ?? fallback
    }
    
    private func currentInt(for item: SettingItem) -> Int {
        let fallback = defaultConfig?.readInt(item.section, item.key, 0) ?? 0
        return currentConfig?.readInt(item.section, item.key, fallback) ?? fallback
    }
    
    private func currentString(for item: SettingItem) -> String {
        let fallback = defaultConfig?.readString(item.section, item.key, "") ?? ""
        return currentConfig?.readString(item.section, item.key, fallback) ?? fallback
    }
    
    ///option The currently selected index region_value has Auto corresponding to -1, so after reading it, add 1.
    private func currentOptionIndex(for item: SettingItem) -> Int {
        var selected = currentInt(for: item)
        if item.key == "region_value" {
            selected += 1
        }
        return selected
    }
    
    private func currentOptionLabel(for item: SettingItem) -> String {
        let options = getOptions(key: item.key)
        let index = currentOptionIndex(for: item)
        if options.indices.contains(index) {
            return options[index]
        }
        return currentString(for: item)
    }
    
    //MARK: - Event handling
    private func handleAction(_ action: ASListPage.Action) {
        if let (indexPath, cellData, subActions) = action.normalItemValue {
            guard indexPath.section < items.count else { return }
            let item = items[indexPath.section]
            switch item.type {
            case .switch:
                guard let isOn = subActions?.extraValue as? Bool else { return }
                handleSwitch(item: item, isOn: isOn, cellData: cellData, indexPath: indexPath)
            case .option:
                showOptionSheet(for: item, indexPath: indexPath)
            case .action:
                showActionEditor(for: item, indexPath: indexPath)
            case .none:
                break
            }
        } else if let navigationValue = action.navigationValue {
            if navigationValue.isTapClose {
                hide()
            } else if navigationValue.tapToolsValue != nil {
                showMoreMenu()
            }
        }
    }
    
    private func handleSwitch(item: SettingItem,
                              isOn: Bool,
                              cellData: ASListPage.Cell,
                              indexPath: IndexPath) {
        if item.key == "use_cpu_jit", isOn, !LibretroCore.jitAvailable() {
            UIView.makeToast(message: R.string.localizable.jitNoSupportDesc())
            listView.updateCellData(cellData.updateNormalSwitch(state: .off), indexPath: indexPath)
            return
        }
        writeValue(item: item, value: isOn ? "1" : "0")
        listView.updateCellData(cellData.updateNormalSwitch(state: isOn ? .on : .off),
                                indexPath: indexPath,
                                reloadView: false)
    }
    
    private func showOptionSheet(for item: SettingItem, indexPath: IndexPath) {
        let options = getOptions(key: item.key)
        guard options.count > 0 else { return }
        let selectedIndex = currentOptionIndex(for: item)
        
        ChevronSheetView.show(icon: .symbol(.sliderHorizontal3),
                              title: item.key,
                              detail: item.note,
                              cellOptions: options.enumerated().map({ index, option in
                                .iconTitleDetailRadioCell(title: option,
                                                          isSelected: index == selectedIndex)
                              }),
                              groupTogether: true) { [weak self] index in
            guard let self, let index, options.indices.contains(index) else { return }
            let writeIndex = item.key == "region_value" ? index - 1 : index
            self.writeValue(item: item, value: String(writeIndex))
            self.listView.updateCellData(self.makeCell(for: item), indexPath: indexPath)
        }
    }
    
    private func showActionEditor(for item: SettingItem, indexPath: IndexPath) {
        let limitedType = getActionLimitedType(key: item.key)
        if let range = integerPickerRange(for: limitedType) {
            showIntegerPicker(for: item, range: range, indexPath: indexPath)
        } else {
            LimitedTextInputView.show(title: item.key,
                                      detail: item.note,
                                      text: currentString(for: item),
                                      limitedType: limitedType) { [weak self] result in
                guard let self else { return }
                var writeString: String? = nil
                if let int = result as? Int {
                    writeString = String(int)
                } else if let double = result as? Double {
                    writeString = String(double)
                } else if let string = result as? String {
                    writeString = string
                }
                guard let writeString else { return }
                self.writeValue(item: item, value: writeString)
                self.listView.updateCellData(self.makeCell(for: item), indexPath: indexPath)
            }
        }
    }
    
    private func showIntegerPicker(for item: SettingItem,
                                   range: ClosedRange<Int>,
                                   indexPath: IndexPath) {
        let values = Array(range)
        let datas = values.map({ String($0) })
        let selectedIndex = values.firstIndex(of: currentInt(for: item)) ?? 0
        var pickedIndex: Int? = nil
        
        ASSheetView.show(.init(style: .picker(title: item.key,
                                              detail: item.note,
                                              datas: datas,
                                              selectedIndex: selectedIndex)),
                         action: { action, _ in
            if let pickerValue = action.pickerValue {
                pickedIndex = pickerValue.index
            }
            return .none
        }, dismiss: { [weak self] in
            guard let self, let pickedIndex, datas.indices.contains(pickedIndex), pickedIndex != selectedIndex else { return }
            self.writeValue(item: item, value: datas[pickedIndex])
            self.listView.updateCellData(self.makeCell(for: item), indexPath: indexPath)
        })
    }
    
    //MARK: - More menu
    private func showMoreMenu() {
        ChevronSheetView.show(icon: .symbol(.sliderHorizontal3),
                              title: R.string.localizable.threeDSAdvanceSettingTitle(),
                              cellOptions: [
                                .iconTitleChevronCell(icon: .symbolImage(R.image.refresh_iconSymbols()),
                                                      title: R.string.localizable.controllerMappingReset()),
                                .iconTitleChevronCell(icon: .symbolImage(R.image.shareRa_iconSymbols()),
                                                      title: R.string.localizable.shareConfigButtonTitle()),
                                .iconTitleChevronCell(icon: .symbolImage(R.image.import_iconSymbols()),
                                                      title: R.string.localizable.importConfigButtonTitle())
                              ]) { [weak self] index in
            guard let self, let index else { return }
            if index == 0 {
                self.resetConfig()
            } else if index == 1 {
                self.shareConfig()
            } else if index == 2 {
                self.importConfig()
            }
        }
    }
    
    private func resetConfig() {
        isModified = false
        try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.CitraDefaultConfig),
                                      to: URL(fileURLWithPath: R.Path.CitraConfig),
                                      shouldReplace: true)
        currentConfig = try? INIFile(fileName: R.Path.CitraConfig)
        reloadList()
    }
    
    private func shareConfig() {
        saveIfNeeded()
        ShareManager.shareFile(fileUrl: URL(fileURLWithPath: R.Path.CitraConfig), in: hostingWindowScene)
    }
    
    private func importConfig() {
        FilesImporter.shared.presentImportController(supportedTypes: UTType.configTypes, allowsMultipleSelection: false, manualHandle: { [weak self] urls in
            guard let self, let url = urls.first else { return }
            do {
                try FileManager.safeCopyItem(at: url,
                                             to: URL(fileURLWithPath: R.Path.CitraConfig),
                                             shouldReplace: true)
                self.currentConfig = try INIFile(fileName: R.Path.CitraConfig)
                self.reloadList()
            } catch {
                UIView.makeToast(message: R.string.localizable.readConfigFileFailed())
            }
        }, in: hostingWindowScene)
    }
    
    //MARK: - Configuration read/write
    private func writeValue(item: SettingItem, value: String) {
        currentConfig?.writeString(item.section, item.key, value)
        isModified = true
    }
    
    private func saveIfNeeded() {
        if isModified {
            try? currentConfig?.writeFile()
            isModified = false
        }
    }
    
    ///Integers that are too large in range or have no upper bound are not suitable for picker.
    private func integerPickerRange(for limitedType: LimitedTextInputView.LimitedType) -> ClosedRange<Int>? {
        switch limitedType {
        case .integer(let min, let max):
            guard max != .max, max >= min, (max - min) <= Self.pickerIntegerSpanLimit else { return nil }
            return min...max
        default:
            return nil
        }
    }
    
    //MARK: - Type mapping
    private func getType(key: String) -> SettingType {
        switch key {
        case "use_cpu_jit",
            "disable_right_eye_render",
            "async_shader_compilation",
            "use_hw_shader",
            "shaders_accurate_mul",
            "use_shader_jit",
            "use_vsync_new",
            "use_disk_shader_cache",
            "use_frame_limit",
            "dump_textures",
            "custom_textures",
            "preload_textures",
            "async_custom_loading",
            "enable_audio_stretching",
            "use_virtual_sd",
            "is_new_3ds",
            "lle_applets",
            "plugin_loader",
            "allow_plugin_loader",
            "enable_realtime_audio":
            return .switch
        case "cpu_clock_percentage",
            "resolution_factor",
            "frame_limit",
            "bg_red",
            "bg_blue",
            "bg_green",
            "factor_3d",
            "pp_shader_name",
            "anaglyph_shader_name",
            "volume",
            "init_time",
            "init_ticks_override",
            "steps_per_hour":
            return .action
        case "spirv_shader_gen",
            "render_3d",
            "filter_mode",
            "output_type",
            "input_type",
            "region_value",
            "init_clock",
            "init_ticks_type",
            "camera_outer_right_flip",
            "camera_outer_left_flip",
            "camera_inner_flip",
            "texture_filter",
            "texture_sampling",
            "mono_render_option",
            "audio_emulation":
            return .option
        default: return .none
        }
    }
    
    private func getOptions(key: String) -> [String] {
        switch key {
        case  "spirv_shader_gen":
            return ["GLSL", "SPIR-V"]
        case "render_3d":
            return ["Off", "Side by Side", "Anaglyph", "Interlaced", "Reverse Interlaced", "Cardboard VR"]
        case "filter_mode":
            return ["Nearest", "Linear"]
        case "output_type":
            return ["Auto", "No audio output", "Cubeb", "OpenAL", "SDL"]
        case "input_type":
            return ["Auto", "No audio input", "Static noise", "Cubeb", "OpenAL"]
        case "region_value":
            return ["Auto", "Japan", "USA", "Europe", "Australia", "China", "Korea", "Taiwan"] //Special handling: Auto is -1
        case "init_clock":
            return ["System clock", "fixed time"]
        case "init_ticks_type":
            return ["Random", "Fixed"]
        case "camera_outer_right_flip", "camera_outer_left_flip", "camera_inner_flip":
            return ["None", "Horizontal", "Vertical", "Reverse"]
        case "texture_filter":
            return ["None", "Anime4K", "Bicubic", "ScaleForce", "xBRZ", "MMPX"]
        case "texture_sampling":
            return ["GameControlled", "NearestNeighbor", "Linear"]
        case "mono_render_option":
            return ["LeftEye", "RightEye"]
        case "audio_emulation":
            return ["HLE", "LLE", "LLEMultithreaded"]
        default:
            return []
        }
    }
    
    private func getActionLimitedType(key: String) -> LimitedTextInputView.LimitedType {
        switch key {
        case "cpu_clock_percentage":
            return .integer(min: 0, max: 400)
        case "resolution_factor":
            return .integer(min: 0, max: 10)
        case "frame_limit":
            return .integer(min: 1, max: 9999)
        case "bg_red":
            return .decimal(min: 0.0, max: 1.0)
        case "bg_blue":
            return .decimal(min: 0.0, max: 1.0)
        case "bg_green":
            return .decimal(min: 0.0, max: 1.0)
        case "factor_3d":
            return .integer(min: 0, max: 100)
        case "pp_shader_name":
            return .normal(maxTextSize: 256)
        case "anaglyph_shader_name":
            return .normal(maxTextSize: 256)
        case "volume":
            return .decimal(min: 0.0, max: 1.0)
        case "init_time":
            return .integer(min: 946681277, max: Int.max)
        case "init_ticks_override":
            return .integer(min: 0, max: Int.max)
        case "steps_per_hour":
            return .integer(min: 0, max: Int.max)
        default:
            return .normal(maxTextSize: 256)
        }
    }
}

extension CitraAdvancedSettingView: ShowableView {
    static func show(hideCompletion: @escaping () -> Void) {
        Self.show()?.hideCompletion = hideCompletion
        
    }
    func didHide() {
        saveIfNeeded()
        hideCompletion?()
    }
}
