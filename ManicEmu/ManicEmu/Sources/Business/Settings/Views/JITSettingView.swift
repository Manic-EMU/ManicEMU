//
//  JITSettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import Device

class JITSettingView: BaseView {

#if SIDE_LOAD
    private enum Row {
        case status
        case activeDebugger
        case source
        case device
        case system
        case memory
        case txm
        case jitPath
        case method
        case autoEnableOnLaunch
        case enable
        case pairing
        case prepare
        case resetDDI
    }
#else
    private enum Row {
        case status
        case source
        case device
        case system
        case memory
        case installSideload
    }
#endif

    private let showClose: Bool

    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        return view
    }()

    required init?(parameters: Any...) {
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    convenience init(showClose: Bool = true) {
        self.init(parameters: showClose)!
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has been implemented")
    }

    private func reloadList() {
        listPageView.updatePage(getListPage())
    }

    private func visibleRows() -> [[Row]] {
#if SIDE_LOAD
        let info: [Row] = [.source, .device, .system, .memory, .txm, .jitPath]
        var actions: [Row] = []
        if StikJITManager.shared.showsMethodPicker {
            actions.append(.method)
        }
        if StikJITManager.shared.jitLaunchMode == .builtInDebugger {
            actions.append(.autoEnableOnLaunch)
        }
        actions.append(.enable)
        if StikJITManager.shared.jitLaunchMode == .builtInDebugger {
            actions += [.pairing, .prepare, .resetDDI]
        }
        return [[.status, .activeDebugger], info, actions]
#else
        return [[.status], [.source, .device, .system, .memory], [.installSideload]]
#endif
    }

    private func row(at indexPath: IndexPath) -> Row? {
        let rows = visibleRows()
        guard indexPath.section < rows.count, indexPath.row < rows[indexPath.section].count else {
            return nil
        }
        return rows[indexPath.section][indexPath.row]
    }

    private func handleAction(_ action: ASListPage.Action) {
        if let navigationValue = action.navigationValue {
            if navigationValue.isTapClose {
                hide()
            } else if let _ = navigationValue.tapToolsValue {
                let desc = EmulationCore.libretroCores.filter({ $0.supportJit }).reduce("", { result, core in
                    var gameTypesString: String = ""
                    if let gameTypes = core.gameTypes {
                        gameTypesString = "(\(gameTypes.reduce("", { $0 + ($0.isEmpty ? "" : " ") + $1.localizedShortName })))"
                    }
                    return result + (result.isEmpty ? "" : "   ") + core.name + gameTypesString
                })
                UIView.makeAlert(detail: R.string.localizable.jitSupportedDesc(desc), cancelTitle: R.string.localizable.gotIt())
            }
            return
        }
        guard let value = action.normalItemValue, let row = row(at: value.indexPath) else { return }
#if SIDE_LOAD
        switch row {
        case .method:
            showMethodPicker()
        case .autoEnableOnLaunch:
            guard let isOn = value.subActions?.extraValue as? Bool else { return }
            Settings.defalut.updateExtra(key: ExtraKey.autoEnableJITOnLaunch.rawValue, value: isOn)
            listPageView.updateCellData(value.cellData.updateNormalSwitch(state: isOn ? .on : .off),
                                        indexPath: value.indexPath,
                                        reloadView: false)
        case .enable:
            enableJITTapped()
        case .pairing:
            importPairingTapped()
        case .prepare:
            prepareTapped()
        case .resetDDI:
            resetDDITapped()
        default:
            break
        }
#else
        if row == .installSideload {
            if UIApplication.shared.canOpenURL(R.URLs.InstallSideload) {
                UIApplication.shared.open(R.URLs.InstallSideload)
            } else {
                UIApplication.shared.open(R.URLs.SideStore)
            }
        }
#endif
    }

    private func getListPage() -> ASListPage {
        var navigation = ASListPage.Navigation.defaultNavigation(
            title: "JIT",
            titleIcon: .symbolImage(R.image.jit_iconSymbols()),
            tools: [.symbolImage(R.image.faq_iconSymbols())])
        navigation.enableClose = showClose

        let jitEnable = LibretroCore.jitAvailable()
        let statusCell = ASListPage.Cell.normal([
            .icon(.symbol(.boltFill, colors: [R.Color.LabelPrimary.forceStyle(.dark)]), iconSize: R.Size.IconSizeLarge.height),
            .title(.largeText(jitEnable ? R.string.localizable.jitAllow() : R.string.localizable.jitNotAllow(),
                              color: jitEnable ? R.Color.Green : R.Color.Red))
        ], enablePressEffect: false)

        #if SIDE_LOAD
        let sourceDetail = "Sideload"
        #else
        let sourceDetail = "AppStore"
        #endif
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        let memoryText = FileType.humanReadableFileSize(memoryBytes, numeralSystem: 1000, decimalPlaces: 0) ?? "Unknown"

        var infoCells: [ASListPage.Cell] = [
            .iconTitleDetailCell(icon: .symbol(.appFill), title: R.string.localizable.installSource(), detail: sourceDetail, enablePressEffect: false),
            .iconTitleDetailCell(icon: .symbol(.iphone), title: R.string.localizable.device(), detail: Device.version().rawValue, enablePressEffect: false),
            .iconTitleDetailCell(icon: .symbol(.squareStack3dUpFill), title: R.string.localizable.system(), detail: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)", enablePressEffect: false),
            .iconTitleDetailCell(icon: .symbol(.memorychipFill), title: R.string.localizable.memory(), detail: memoryText, enablePressEffect: false)
        ]
#if SIDE_LOAD
        let txmDetail = ProcessInfo.processInfo.hasTXMSilicon
            ? R.string.localizable.jitTxmPresent()
            : R.string.localizable.jitTxmNotPresent()
        let pathDetail: String
        switch ProcessInfo.processInfo.jitMemoryPath {
        case .legacy:
            pathDetail = R.string.localizable.jitPathLegacy()
        case .ppl:
            pathDetail = R.string.localizable.jitPathPPL()
        case .txm:
            pathDetail = R.string.localizable.jitPathTXM()
        }
        infoCells.append(.iconTitleDetailCell(
            icon: .symbol(.cpu),
            title: R.string.localizable.jitTxmStatus(),
            detail: txmDetail,
            enablePressEffect: false))
        infoCells.append(.iconTitleDetailCell(
            icon: .symbol(.arrowLeftArrowRight),
            title: R.string.localizable.jitPath(),
            detail: pathDetail,
            enablePressEffect: false))
#endif
        let infoSection = ASListPage.Section(cells: infoCells)

        #if SIDE_LOAD
        let mode = StikJITManager.shared.jitLaunchMode
        let enableTitle = jitEnable ? R.string.localizable.reEnableJIT() : R.string.localizable.enableJIT()
        var actionCells: [ASListPage.Cell] = []
        if StikJITManager.shared.showsMethodPicker {
            actionCells.append(.iconTitleChevronCell(
                icon: .symbolImage(R.image.jit_methodSymbols()),
                title: R.string.localizable.jitMethod(),
                chevronTitle: StikJITManager.shared.title(for: mode)))
        }
        if mode == .builtInDebugger {
            let autoEnable = Settings.defalut.getExtraBool(key: ExtraKey.autoEnableJITOnLaunch.rawValue) ?? true
            actionCells.append(.iconTitleDetailSwitchCell(
                icon: .symbol(.power),
                title: R.string.localizable.jitAutoEnableOnLaunch(),
                detail: R.string.localizable.jitAutoEnableOnLaunchDesc(),
                state: autoEnable ? .on : .off,
                enablePressEffect: false))
        }
        actionCells.append(.iconTitleChevronCell(icon: .symbolImage(R.image.jit_typeSymbols()), title: enableTitle))
        if mode == .builtInDebugger {
            actionCells.append(.iconTitleChevronCell(
                icon: .symbol(.docFill),
                title: R.string.localizable.jitImportPairingFile(),
                chevronTitle: StikJITManager.shared.pairingFileDisplayName))
            actionCells.append(.iconTitleChevronCell(
                icon: .symbol(.hammerFill),
                title: R.string.localizable.jitPrepare(),
                chevronTitle: StikJITManager.shared.preparationStatus))
            actionCells.append(.iconTitleChevronCell(
                icon: .symbol(.trash),
                title: R.string.localizable.jitResetDDI()))
        }
        var statusSection = ASListPage.Section(cells: [
            statusCell,
            .iconTitleDetailCell(
                icon: .symbol(.dotRadiowavesLeftAndRight),
                title: R.string.localizable.jitActiveDebugger(),
                detail: StikJITHostCoordinator.shared.activeDebuggerDisplayName,
                enablePressEffect: false)
        ])
        statusSection.header = .texts([.smallText(R.string.localizable.jitDesc(), numberOfLines: 0)], pin: false)
        var actionSection = ASListPage.Section(cells: actionCells)
        if StikJITManager.shared.showsMethodPicker {
            actionSection.footer = .texts([.smallText(R.string.localizable.jitMethodBuiltInInfo(), numberOfLines: 0)], pin: false)
        }
        let sections = [
            statusSection,
            infoSection,
            actionSection
        ]
        #else
        var lastSection = ASListPage.Section(cells: [
            .iconTitleChevronCell(
                icon: .symbolImage(R.image.customArrowTriangleheadSwap() ?? UIImage()),
                title: R.string.localizable.installSideloadVersion())
        ])
        lastSection.footer = .texts([.smallText(R.string.localizable.jitDesc(), numberOfLines: 0)], pin: false)
        let sections = [
            ASListPage.Section(cells: [statusCell]),
            infoSection,
            lastSection
        ]
        #endif

        let listInsetBottom = (UIDevice.isPad && !showClose) ? R.Size.ContentInsetBottom + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceMedium : 0
        return ASListPage(
            navigation: navigation,
            sections: sections,
            backgroundColor: .clear,
            listInsets: .insets(bottom: listInsetBottom),
            pageInsets: .insets(top: showClose ? R.Size.SheetGrabberTopInset : R.Size.ContentInsetTop))
    }

#if SIDE_LOAD
    private func showMethodPicker() {
        let options = [
            R.string.localizable.jitMethodBuiltInDebugger(),
            R.string.localizable.jitMethodExternalDebugger()
        ]
        let selected = StikJITManager.shared.jitLaunchMode == .builtInDebugger ? 0 : 1
        OptionsSheetView.show(
            icon: .symbolImage(R.image.jit_iconSymbols()),
            title: R.string.localizable.jitMethod(),
            detail: StikJITManager.shared.info(for: StikJITManager.shared.jitLaunchMode),
            options: options,
            selectedIndex: selected
        ) { [weak self] index in
            guard let index else { return }
            let mode: JITLaunchMode = index == 0 ? .builtInDebugger : .externalDebugger
            if mode == .builtInDebugger {
                if StikJITManager.shared.isRunningInLiveContainer {
                    UIView.makeToast(message: R.string.localizable.jitLiveContainerUnavailable())
                    return
                }
                if !StikJITManager.shared.isBuiltInAvailable {
                    UIView.makeToast(message: R.string.localizable.jitRequiresiOS174())
                    return
                }
            }
            StikJITManager.shared.jitLaunchMode = mode
            self?.reloadList()
        }
    }

    private func enableJITTapped() {
        if StikJITManager.shared.jitLaunchMode == .externalDebugger {
            if !StikJITHostCoordinator.shared.openExternalDebugger() {
                UIView.makeToast(message: R.string.localizable.notInstall("StikDebug"))
            }
            return
        }
        UIView.makeLoading(timeout: R.Numbers.WebLoadingViewTimeout)
        StikJITHostCoordinator.shared.acquireNow { [weak self] ok, message in
            if ok {
                UIView.makeToast(message: R.string.localizable.enableJITSuccess() )
            } else {
                UIView.makeAlert(
                    title: R.string.localizable.enableJIT(),
                    detail: message ?? R.string.localizable.errorUnknown(),
                    detailAlignment: .center,
                    cancelTitle: R.string.localizable.gotIt())
            }
            DispatchQueue.main.asyncAfter(delay: 0.35, execute: {
                UIView.hideLoading()
            })
            self?.reloadList()
        }
    }

    private func importPairingTapped() {
        StikJITManager.shared.presentPairingFilePicker { [weak self] ok, error in
            if let error {
                UIView.makeToast(message: error)
            } else if ok, StikJITManager.shared.hasPairingFile, StikJITManager.shared.isBuiltInAvailable {
                StikJITManager.shared.jitLaunchMode = .builtInDebugger
            }
            self?.reloadList()
        }
    }

    private func prepareTapped() {
        UIView.makeLoadingToast(message: R.string.localizable.jitPrepare())
        StikJITHostCoordinator.shared.prepareDevice { stage in
            UIView.makeLoadingToast(message: stage)
        } completion: { [weak self] ok, error in
            if ok {
                UIView.makeToast(message: R.string.localizable.jitPrepareSuccess())
            } else {
                UIView.makeAlert(
                    title: R.string.localizable.jitPrepare(),
                    detail: error ?? R.string.localizable.errorUnknown(),
                    detailAlignment: .center,
                    cancelTitle: R.string.localizable.gotIt())
            }
            self?.reloadList()
            DispatchQueue.main.asyncAfter(delay: 0.35, execute: {
                UIView.hideLoadingToast(forceHide: true)
            })
        }
    }

    private func resetDDITapped() {
        UIView.makeLoading(timeout: R.Numbers.WebLoadingViewTimeout)
        StikJITHostCoordinator.shared.resetCachedDDI { [weak self] ok, error in
            if ok {
                UIView.makeToast(message: R.string.localizable.jitResetDDISuccess())
            } else {
                UIView.makeAlert(
                    title: R.string.localizable.jitPrepare(),
                    detail: error ?? R.string.localizable.errorUnknown(),
                    detailAlignment: .center,
                    cancelTitle: R.string.localizable.gotIt())
            }
            self?.reloadList()
            DispatchQueue.main.asyncAfter(delay: 0.35, execute: {
                UIView.hideLoading()
            })
        }
    }
#endif
}

extension JITSettingView: ShowableView {
}
