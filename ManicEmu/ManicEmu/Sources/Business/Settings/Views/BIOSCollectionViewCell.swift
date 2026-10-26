//
//  BIOSCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/6/10.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import UniformTypeIdentifiers
import ZipArchive

class BIOSCollectionViewCell: UICollectionViewCell {
    
    class ItemView: BaseView {
        var titleLabel: UILabel = {
            let view = UILabel()
            view.font = R.Font.Body()
            view.textColor = R.Color.LabelPrimary
            return view
        }()
        
        var detailLabel: UILabel = {
            let view = UILabel()
            view.font = R.Font.Caption()
            view.textColor = R.Color.LabelSecondary
            view.numberOfLines = 0
            return view
        }()
        
        var optionButton: UIButton = {
            let view = UIButton(type: .custom)
            view.titleLabel?.font = R.Font.Caption()
            view.setTitle("(\(R.string.localizable.optionTitleOptional()))", for: .normal)
            view.setTitle("(\(R.string.localizable.optionTitleRequired()))", for: .selected)
            view.setTitleColor(R.Color.LabelSecondary, for: .normal)
            view.setTitleColor(R.Color.Red, for: .selected)
            return view
        }()
        
        var button: UIButton = {
            let view = UIButton(type: .custom)
            view.titleLabel?.font = R.Font.Body(emphasis: true)
            view.setTitle(R.string.localizable.tabbarTitleImport(), for: .normal)
            view.setTitle(R.string.localizable.biosImported(), for: .selected)
            view.setTitleColor(R.Color.Red, for: .normal)
            view.setTitleColor(R.Color.Green, for: .selected)
            return view
        }()
        
        init(enableButton: Bool = true, enableOptionButton: Bool = true) {
            super.init(frame: .zero)
            layerCornerRadius = R.Size.CornerRadiusMedium
            backgroundColor = R.Color.BackgroundTertiary
            
            let titleContainer = UIView()
            addSubview(titleContainer)
            titleContainer.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                if !enableButton {
                    make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
                }
            }
            
            titleContainer.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.leading.top.equalToSuperview()
                if !enableOptionButton {
                    make.trailing.equalToSuperview()
                }
            }
            
            if enableOptionButton {
                titleContainer.addSubview(optionButton)
                optionButton.snp.makeConstraints { make in
                    make.trailing.lessThanOrEqualToSuperview()
                    make.centerY.equalTo(titleLabel)
                    make.leading.equalTo(titleLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
                }
            }
            
            titleContainer.addSubview(detailLabel)
            detailLabel.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceTiny)
                make.leading.bottom.equalToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
            }
            
            button.isFocusable = true
            optionButton.isFocusable = true
            if enableButton {
                addSubview(button)
                titleContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                titleContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                button.setContentHuggingPriority(.required, for: .horizontal)
                button.setContentCompressionResistancePriority(.required, for: .horizontal)
                button.snp.makeConstraints { make in
                    make.centerY.equalToSuperview()
                    make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
                    make.leading.equalTo(titleContainer.snp.trailing).offset(R.Size.ContentSpaceSmall)
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
    }
    
    private func getBiosItems(gameType: GameType, completion: (([BIOSItem])->Void)? = nil) {
        DispatchQueue.global().async {
            var biosItems = [BIOSItem]()
            if gameType == .mcd {
                biosItems = R.BIOS.MegaCDBios
            } else if gameType == .ss {
                biosItems = R.BIOS.SaturnBios
            } else if gameType == .ds {
                biosItems = R.BIOS.DSBios
            } else if gameType == .ps1 {
                biosItems = R.BIOS.PS1Bios
            } else if gameType == .dc {
                biosItems = R.BIOS.DCBios
            }  else if gameType == .gb {
                biosItems = R.BIOS.GBBios
            }  else if gameType == .gbc {
                biosItems = R.BIOS.GBCBios
            }  else if gameType == .gba {
                biosItems = R.BIOS.GBABios
            }  else if gameType == .fds {
                biosItems = R.BIOS.FDSBios
            }  else if gameType == .pm {
                biosItems = R.BIOS.PMBios
            } else if gameType == ._3ds {
                biosItems = R.BIOS.ThreeDSBios
            } else if gameType == .arcade {
                biosItems = R.BIOS.ArcadeDSBios
            } else if gameType == .a5200 {
                biosItems = R.BIOS.A5200Bios
            } else if gameType == .a7800 {
                biosItems = R.BIOS.A7800Bios
            } else if gameType == .lynx {
                biosItems = R.BIOS.LynxBios
            } else if gameType == .pce {
                biosItems = R.BIOS.PCEBios
            } else if gameType == .c64 {
                biosItems = R.BIOS.C64Bios
            } else if gameType == .amiga {
                biosItems = R.BIOS.AmigaBios
            } else if gameType == .wii {
                biosItems = R.BIOS.WiiBios
            } else if gameType == .ngc {
                biosItems = gameType.biosItems
            }
            let fileManager = FileManager.default
            for (index, bios) in biosItems.enumerated() {
                var biosInLib = R.Path.System.appendingPathComponent(bios.fileName)
                if gameType == .dc {
                    biosInLib = R.Path.Flycast.appendingPathComponent("dc/\(bios.fileName)")
                } else if gameType == .c64 {
                    biosInLib = R.Path.System.appendingPathComponent("vice/\(bios.fileName)")
                }
                let isBiosExists: Bool
                if gameType == .arcade {
                    isBiosExists = R.BIOS.MAMEBiosMap.keys.allSatisfy({ FileManager.default.fileExists(atPath: R.Path.Data.appendingPathComponent($0)) })
                } else {
                    isBiosExists = fileManager.fileExists(atPath: biosInLib)
                }
                if isBiosExists {
                    biosItems[index].imported = true
                } else {
                    let biosInDoc = R.Path.BIOS.appendingPathComponent(bios.fileName)
                    if fileManager.fileExists(atPath: biosInDoc) {
                        try? FileManager.safeCopyItem(at: URL(fileURLWithPath: biosInDoc), to: URL(fileURLWithPath: biosInLib))
                        biosItems[index].imported = true
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion?(biosItems)
            }
        }
    }
    
    private let itemViews: [ItemView] = {
        var views = [ItemView]()
        (0...7).forEach { _ in
            let v = ItemView()
            v.isHidden = true
            views.append(v)
        }
        return views
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layerCornerRadius = R.Size.CornerRadiusLarge
        backgroundColor = R.Color.BackgroundSecondary
        
        addSubviews(itemViews)
        for (index, view) in itemViews.enumerated() {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                make.height.equalTo(R.Size.ItemHeightLarge)
                if index == 0 {
                    make.top.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                } else {
                    make.top.equalTo(itemViews[index-1].snp.bottom).offset(R.Size.ContentSpaceMedium)
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(gameType: GameType, importSuccess: (()->Void)? = nil) {
        getBiosItems(gameType: gameType) { [weak self] biosItems in
            guard let self else { return }
            for (index, itemView) in self.itemViews.enumerated() {
                if index < biosItems.count {
                    let b = biosItems[index]
                    itemView.titleLabel.text = b.fileName
                    itemView.detailLabel.text = b.desc
                    itemView.optionButton.isSelected = b.required
                    itemView.button.isSelected = b.imported
                    itemView.isHidden = false
                    itemView.button.onTap {
                        func importFromFiles() {
                            FilesImporter.shared.presentImportController(supportedTypes: UTType.binTypes, allowsMultipleSelection: true, manualHandle: {  urls in
                                UIView.makeLoading()
                                DispatchQueue.global().async {
                                    var matchs = [(url: URL, fileName: String)]()
                                    var mameMatchs = [(url: URL, fileName: String)]()
                                    for url in urls {
                                        biosItems.forEach({ bios in
                                            if url.lastPathComponent.lowercased() == bios.fileName.lowercased() {
                                                matchs.append((url, bios.fileName))
                                            } else if bios.fileName == R.Strings.MAMEBiosTitle,
                                                      let _ = R.BIOS.MAMEBiosMap[url.lastPathComponent.lowercased()] {
                                                //MAME Bios特殊匹配
                                                mameMatchs.append((url, url.lastPathComponent.lowercased()))
                                            }
                                        })
                                    }
                                    
                                    var import3DSNandSuccess = true
                                    if matchs.count > 0 {
                                        for match in matchs {
                                            if match.fileName.lowercased() == "nand.zip" {
                                                import3DSNandSuccess = self.import3DSNand(url: match.url)
                                            } else {
                                                try? FileManager.safeCopyItem(at: match.url, to: URL(fileURLWithPath: R.Path.BIOS.appendingPathComponent(match.fileName)), shouldReplace: true)
                                                var matchFilePath = R.Path.System.appendingPathComponent(match.fileName)
                                                if gameType == .dc {
                                                    matchFilePath = R.Path.Flycast.appendingPathComponent("dc/\(match.fileName)")
                                                } else if gameType == .c64 {
                                                    try? FileManager.default.createDirectory(atPath: R.Path.System.appendingPathComponent("vice"), withIntermediateDirectories: true)
                                                    matchFilePath = R.Path.System.appendingPathComponent("vice/\(match.fileName)")
                                                }
                                                try? FileManager.safeCopyItem(at: match.url, to: URL(fileURLWithPath: matchFilePath), shouldReplace: true)
                                            }
                                        }
                                        if !import3DSNandSuccess {
                                            matchs.removeAll(where: { $0.fileName.lowercased() == "nand.zip" })
                                        }
                                    }
                                    
                                    if mameMatchs.count > 0 {
                                        for match in mameMatchs {
                                            try? FileManager.safeCopyItem(at: match.url, to: URL(fileURLWithPath: R.Path.Data.appendingPathComponent(match.fileName)), shouldReplace: true)
                                        }
                                    }
                                    DispatchQueue.main.async {
                                        UIView.hideLoading()
                                        if matchs.count > 0 || mameMatchs.count > 0 {
                                            UIView.makeToast(message: R.string.localizable.biosImportSuccess((matchs+mameMatchs).reduce("") { $0 + $1.fileName + "\n" }))
                                            importSuccess?()
                                        } else {
                                            UIView.makeToast(message: R.string.localizable.biosImportFailed())
                                        }
                                        
                                        if !import3DSNandSuccess {
                                            UIView.makeToast(message: R.string.localizable.threeDSNandImportFailed())
                                        }
                                    }
                                }
                            }, in: self.hostingWindowScene)
                        }
                        
                        if gameType == ._3ds {
                            UIView.makeAlert(title: R.string.localizable.headsUp(),
                                             detail: R.string.localizable.nandImportHeadsUp(),
                                             cancelTitle: R.string.localizable.contineFilesImport(),
                                             confirmTitle: R.string.localizable.openPage(R.string.localizable.articBaseSettings()),
                                             cancelAction: {
                                UIView.makeToast(message: R.string.localizable.threeDSNandImportToast())
                                importFromFiles()
                            }, confirmAction: {
                                DispatchQueue.main.asyncAfter(delay: 0.35) {
                                    PretendoNetworkingView.show()
                                }
                            })
                        } else {
                            importFromFiles()
                        }
                    }
                } else {
                    itemView.isHidden = true
                }
            }
        }
    }
    
    private func import3DSNand(url: URL) -> Bool {
        //先检查zip里面有没有支持的文件类型
        if SSZipArchive.isFilePasswordProtected(atPath: url.path) {
            return false
        } else {
            let unZipPath = R.Path.Cache.appendingPathComponent("nand")
            if FileManager.default.fileExists(atPath: unZipPath) {
                try? FileManager.default.removeItem(atPath: unZipPath)
            }
            let unzipSuccess = SSZipArchive.unzipFile(atPath: url.path, toDestination: unZipPath)
            guard unzipSuccess else { return false }
            
            var tempNandPath = unZipPath
            if FileManager.default.fileExists(atPath: unZipPath.appendingPathComponent("nand")) {
                tempNandPath = unZipPath.appendingPathComponent("nand")
            }
            
            let nandPath = R.Path.ThreeDS.appendingPathComponent("nand")
            try? FileManager.safeReplaceDirectory(at: URL(fileURLWithPath: tempNandPath), to: URL(fileURLWithPath: nandPath))
            
            try? FileManager.default.removeItem(atPath: unZipPath)
            
            import3DSHomeMenu(at: nandPath)
   
            return true
        }
    }
    
    private func import3DSHomeMenu(at path: String) {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return }
        
        if path.pathExtension.lowercased() == "app", let tid = pathToTid(path),
           R.Numbers.ThreeDSHomeMenuIdentifiers.contains(where: { $0 == tid }) {
            // Leave the .app in NAND. Importing it as a ROM copies onto the same path and deletes it.
            ThreeDS.registerInstalledHomeMenu(at: URL(fileURLWithPath: path), identifier: tid)
        }
        
        if isDirectory.boolValue {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                for item in contents {
                    let fullPath = (path as NSString).appendingPathComponent(item)
                    import3DSHomeMenu(at: fullPath)
                }
            } catch {
                Log.debug("Failed to read NAND directory \(path): \(error)")
            }
        }
    }
    
    // UInt64 -> String
    private func tidToPath(_ tid: UInt64) -> String {
        let high = UInt32(tid >> 32)
        let low = UInt32(tid & 0xFFFFFFFF)
        return String(format: "%08x/%08x", high, low)
    }

    // String -> UInt64
    private func pathToTid(_ path: String) -> UInt64? {
        guard let beginRange = path.range(of: "/title/") else { return nil }
        guard let endRange = path.range(of: "/content/") else { return nil }
        guard beginRange.upperBound < endRange.lowerBound else { return nil }
        
        let path = String(path[beginRange.upperBound..<endRange.lowerBound])
        
        let parts = path.split(separator: "/")
        guard parts.count == 2,
              let high = UInt32(parts[0], radix: 16),
              let low = UInt32(parts[1], radix: 16) else {
            return nil
        }
        return (UInt64(high) << 32) | UInt64(low)
    }
    
    
    static func CellHeight(gameType: GameType) -> Double {
        var itemCount = 0
        if gameType == .mcd {
            itemCount = R.BIOS.MegaCDBios.count
        } else if gameType == .ss {
            itemCount = R.BIOS.SaturnBios.count
        } else if gameType == .ds {
            itemCount = R.BIOS.DSBios.count
        } else if gameType == .ps1 {
            itemCount = R.BIOS.PS1Bios.count
        } else if gameType == .dc {
            itemCount = R.BIOS.DCBios.count
        }  else if gameType == .gb {
            itemCount = R.BIOS.GBBios.count
        }  else if gameType == .gbc {
            itemCount = R.BIOS.GBCBios.count
        }  else if gameType == .gba {
            itemCount = R.BIOS.GBABios.count
        }  else if gameType == .fds {
            itemCount = R.BIOS.FDSBios.count
        }  else if gameType == .pm {
            itemCount = R.BIOS.PMBios.count
        } else if gameType == ._3ds {
            itemCount = R.BIOS.ThreeDSBios.count
        } else if gameType == .arcade {
            itemCount = R.BIOS.ArcadeDSBios.count
        } else if gameType == .a5200 {
            itemCount = R.BIOS.A5200Bios.count
        } else if gameType == .a7800 {
            itemCount = R.BIOS.A7800Bios.count
        } else if gameType == .lynx {
            itemCount = R.BIOS.LynxBios.count
        } else if gameType == .pce {
            itemCount = R.BIOS.PCEBios.count
        } else if gameType == .c64 {
            itemCount = R.BIOS.C64Bios.count
        } else if gameType == .amiga {
            itemCount = R.BIOS.AmigaBios.count
        }
        return (Double(itemCount) * R.Size.ItemHeightLarge) + (Double(itemCount + 1) * R.Size.ContentSpaceMedium)
    }
}
