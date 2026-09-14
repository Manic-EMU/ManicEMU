//
//  AddCheatCodeView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ProHUD

class AddCheatCodeView: BaseView {

    private lazy var navigationView: ASNavigationView = {
        let title = editGameCheat == nil ? R.string.localizable.addCheatCodes() : R.string.localizable.editCheatCodes()
        let view = ASNavigationView(.defaultNavigation(title: title,
                                                       titleIcon: .symbolImage(R.image.cheat_iconSymbols()),
                                                       tools: [.symbolImage(R.image.faq_iconSymbols())]))
        view.didTapClose = { [weak self] in
            guard let self else { return }
            self.hide()
        }
        
        view.didTapTools = { _ in
            ASWebView.show(url: R.URLs.CheatCodesGuide)
        }
        
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: TitleInputCollectionViewCell.self)
        view.register(cellWithClass: AddCheatCodeContentCell.self)
        view.register(cellWithClass: ASListCustomCollectionCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(bottom: R.Size.ContentInsetBottom + R.Size.ButtonExtraLarge + R.Size.ContentSpaceMedium)
        return view
    }()
    
    private lazy var saveButtonContainerView: UIView = {
        let view = UIView()
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            if UIDevice.isPad || (UIDevice.isPhone && UIDevice.isLandscape) {
                make.width.equalTo(R.Size.ButtonMaxWidth)
                make.centerX.equalToSuperview()
            } else {
                make.leading.equalToSuperview().inset(R.Size.ContentSpaceHuge)
                make.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
                make.centerY.equalToSuperview()
            }
            make.height.equalTo(R.Size.ButtonExtraLarge)
        }
        return view
    }()
    
    private lazy var saveButton: ASButtonView = {
        var button = ASButton.large(title: R.string.localizable.saveTitle(),
                                    titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                    titleAlignment: .center,
                                    background: R.Color.Main)
        var disableAttributes = button.allAttributes[.normal]!
        disableAttributes.background = R.Color.BackgroundSecondary
        disableAttributes.title?.attributes?.color = R.Color.LabelTertiary
        button.allAttributes[.disabled] = disableAttributes
        
        let view = ASButtonView(button)
        view.enableFocusEffects = false
        view.didTapButton = { [weak self] in
            guard let self = self else { return }
            self.collectionView.endEditing(true)
            if let editGameCheat = self.editGameCheat,
               self.cheatCode == editGameCheat.code,
               self.cheatCodeName == editGameCheat.name,
               self.cheatCodeType == editGameCheat.type {
                //尝试编辑，但是没有任何改动
                self.hide()
                return
            }
            
            var isValid = false
            if CheatType(cheatCodeType) == .autoDetect {
                if self.game.gameType == .doom, !self.cheatCode.trimmed.isEmpty {
                    isValid = true
                    self.cheatCodeType = CheatType.doomCommands.rawValue
                } else {
                    //自动检测模式下需要帮用户做一下检查
                    if let result = Self.checkCheat(cheatCode: self.cheatCode, supportedCheatFormats: supportedCheatFormats) {
                        isValid = true
                        self.cheatCode = result.formatString
                        self.cheatCodeType = result.cheatFormat.type.rawValue
                    }
                }
            } else {
                //指定了作弊码类型 且已经通过校验
                isValid = true
            }
            if isValid {
                if let editGameCheat = self.editGameCheat {
                    //修改模式
                    Game.change { realm in
                        editGameCheat.name = self.cheatCodeName
                        editGameCheat.code = self.cheatCode
                        editGameCheat.type = self.cheatCodeType
                    }
                } else {
                    //新增模式
                    let gameCheat = GameCheat()
                    gameCheat.name = self.cheatCodeName
                    gameCheat.code = self.cheatCode
                    gameCheat.type = self.cheatCodeType
                    Game.change { realm in
                        self.game.gameCheats.append(gameCheat)
                    }
                }
                self.hide()
            } else {
                UIView.makeToast(message: R.string.localizable.cheatCodeFormatError())
            }
        }
        
        return view
    }()
    
    private var game: Game
    private let autoDetectCheatFormat = CheatFormat(name: R.string.localizable.autoDetectCheatTypeName(), format: R.string.localizable.autoDetectFormat(), type: .autoDetect)
    private lazy var supportedCheatFormats: [CheatFormat] = {
        var result = [CheatFormat]()
        result.append(autoDetectCheatFormat)
        if let supportedCheatFormats = game.gameType.manicEmuCore?.supportedCheatFormats {
            if game.isDolphinCore {
                // ARMax is uniquely hyphenated; Gecko vs decrypted AR share a layout so prefer Gecko on Wii.
                result.append(contentsOf: supportedCheatFormats.sorted { lhs, rhs in
                    func rank(_ format: CheatFormat) -> Int {
                        if format.type == .ARMax { return 0 }
                        if game.gameType == .wii {
                            return format.type == .Gecko ? 1 : 2
                        }
                        return format.type == .actionReplay ? 1 : 2
                    }
                    return rank(lhs) < rank(rhs)
                })
            } else {
                result.append(contentsOf: supportedCheatFormats)
            }
        }
        return result
    }()
    ///当前选中的作弊码格式
    private var currentCheatFormat: CheatFormat {
        didSet {
            self.cheatCodeType = self.currentCheatFormat.type.rawValue
        }
    }
    private var cheatCodeName: String = ""
    private var cheatCodeType: String = ""
    private var cheatCode: String = ""
    private var editGameCheat: GameCheat? ///如果不传入则是新增 传入则是编辑
    
    required init?(parameters: Any...) {
        guard let game = parameters.compactMap({ $0 as? Game }).first else { return nil }
        self.game = game
        self.editGameCheat = parameters.compactMap({ $0 as? GameCheat }).first
        self.currentCheatFormat = autoDetectCheatFormat
        super.init(frame: .zero)
        
        if let editGameCheat = editGameCheat {
            cheatCodeName = editGameCheat.name
            cheatCodeType = editGameCheat.type
            cheatCode = editGameCheat.code
            if let cheatFormat = supportedCheatFormats.first(where: { $0.type == CheatType(cheatCodeType) }) {
                currentCheatFormat = cheatFormat
            }
        } else {
            cheatCodeType = autoDetectCheatFormat.type.rawValue
        }
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalTo(navigationView.snp.bottom)
            make.bottom.equalToSuperview()
        }
        
        validateInput()
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
            let height: CGFloat
            if sectionIndex == 0 {
                height = TitleInputCollectionViewCell.CellHeight
            } else if sectionIndex == 1 {
                height = 154
            } else {
                height = R.Size.ButtonExtraLarge
            }
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                              heightDimension: .absolute(height)),
                                                           subitems: [item])
           
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: sectionIndex == 2 ? R.Size.ContentSpaceHuge : 0,
                                                            leading: R.Size.ContentSpaceMedium,
                                                            bottom: 0,
                                                            trailing: R.Size.ContentSpaceMedium)
            return section
        }
        return layout
    }
    
    private func validateInput() {
        var isValid = false
        if cheatCodeName.trimmed.isEmpty || cheatCodeType.trimmed.isEmpty || cheatCode.trimmed.isEmpty  {
            isValid = false
        } else {
            let cheatType = CheatType(rawValue: cheatCodeType)
            if cheatType == .autoDetect {
              isValid = true
            } else {
                if let result = Self.checkCheat(cheatCode: cheatCode, currentCheatFormat: currentCheatFormat) {
                    cheatCode = result.formatString
                    cheatCodeType = result.cheatFormat.type.rawValue
                    isValid = true
                }
            }
        }
        updateConfirmButton(enable: isValid)
    }
    
    /// Beetle raw RAM patch: `AAAA:VV` / `AAAAA:VV`, parts joined by + , ; . _ or space.
    private static func formattedBeetleRaw(code: String) -> String? {
        let separators = CharacterSet(charactersIn: "+,;._ \n\t")
        let parts = code.components(separatedBy: separators).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        var normalized = [String]()
        for part in parts {
            let pieces = part.split(separator: ":", omittingEmptySubsequences: false)
            guard pieces.count == 2 else { return nil }
            let address = String(pieces[0])
            let value = String(pieces[1])
            guard (1...5).contains(address.count),
                  value.count == 2,
                  address.allSatisfy({ $0.isHexDigit }),
                  value.allSatisfy({ $0.isHexDigit }) else {
                return nil
            }
            normalized.append("\(address.uppercased()):\(value.uppercased())")
        }
        return normalized.joined(separator: "+")
    }
    
    private static func formattedCWCheat(code: String) -> String {
        var index = 0
        let codes = code.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespacesAndNewlines)
        return codes.reduce("", {
            let newLine = (index%3 == 0)
            let willAddNewLine = (index == codes.count-1) ? false : ((index+1)%3 == 0)
            let s = $0 + (newLine ? "" : " ") + $1.trimmed + (willAddNewLine ? "\n" : "")
            index += 1
            return s
        })
    }
    
    private static func isCodeMatchingFormat(format: String, code: String) -> Bool {
        // 将 format 和 code 按空格分割成数组
        let formatComponents = format.components(separatedBy: " ")
        let codeComponents = code.components(separatedBy: " ")
        
        // 如果分割后的数组长度不一致，直接返回 false
        if formatComponents.count != codeComponents.count {
            return false
        }
        
        // 遍历 format 和 code 的每个部分，检查长度是否匹配
        for i in 0..<formatComponents.count {
            if formatComponents[i].count != codeComponents[i].count {
                return false
            }
            
            if formatComponents[i].hasPrefix("0x") {
                if !codeComponents[i].hasPrefix("0X") && !codeComponents[i].hasPrefix("0x") {
                    return false
                }
            }
        }
        
        if let firstformat = formatComponents.first, firstformat == "_L", let firstCode = codeComponents.first, firstCode != "_L" {
            return false
        }
        
        // 如果所有部分都匹配，返回 true
        return true
    }
    
    private func updateConfirmButton(enable: Bool) {
        saveButton.state = enable ? .normal : .disabled
    }
    
    static func checkCheat(cheatCode: String,
                           currentCheatFormat: CheatFormat? = nil,
                           supportedCheatFormats: [CheatFormat] = []) -> (formatString: String, cheatFormat: CheatFormat)? {
        if let currentCheatFormat {
            if currentCheatFormat.type == .doomCommands {
                if cheatCode.trimmed.isEmpty {
                    return nil
                }
                return (cheatCode, currentCheatFormat)
            }
            if currentCheatFormat.type == .beetleRaw {
                guard let formatString = formattedBeetleRaw(code: cheatCode) else { return nil }
                return (formatString, currentCheatFormat)
            }
            // Validate against the selected cheat format.
            let formatString: String
            if currentCheatFormat.type == .cwCheat {
                formatString = Self.formattedCWCheat(code: cheatCode)
            } else {
                formatString = cheatCode.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").components(separatedBy: .whitespacesAndNewlines).joined().formatted(with: currentCheatFormat)
            }
            
            for subString in formatString.lines() {
                if !Self.isCodeMatchingFormat(format: currentCheatFormat.format, code: subString) {
                    return nil
                }
            }

            return (formatString, currentCheatFormat)

        } else {
            // Auto-detect among the platform's formats.
            for cheatFormat in supportedCheatFormats.filter({ $0.type != .autoDetect }) {
                let formatString: String
                if cheatFormat.type == .beetleRaw {
                    guard let beetleRaw = formattedBeetleRaw(code: cheatCode) else { continue }
                    return (beetleRaw, cheatFormat)
                } else if cheatFormat.type == .cwCheat {
                    formatString = formattedCWCheat(code: cheatCode)
                } else {
                    formatString = cheatCode.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").components(separatedBy: .whitespacesAndNewlines).joined().formatted(with: cheatFormat)
                }
                
                var isMatchThisFormat = true
                for subString in formatString.lines() {
                    if !isCodeMatchingFormat(format: cheatFormat.format, code: subString) {
                        isMatchThisFormat = false
                        break
                    }
                }
                if isMatchThisFormat {
                    return (formatString, cheatFormat)
                }
            }
        }
        return nil
    }
    
    
}

extension AddCheatCodeView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: TitleInputCollectionViewCell.self, for: indexPath)
            cell.setData(title: R.string.localizable.nameTitle(),
                         text: cheatCodeName,
                         placeholder: R.string.localizable.cheatCodeNamePlaceHolder(),
                         returnKeyType: .next)
            cell.shouldGoNext = { [weak self] in
                guard let self = self else { return }
                if let cell = self.collectionView.cellForItem(at: IndexPath(row: 0, section: indexPath.section + 1)) as? AddCheatCodeContentCell {
                    cell.editTextView.becomeFirstResponder()
                }
            }
            cell.editTextField.didInputChange = { [weak self] string in
                guard let self, let string else { return }
                self.cheatCodeName = string
                self.validateInput()
            }
            
            return cell
        } else if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withClass: AddCheatCodeContentCell.self, for: indexPath)
            cell.didTextChange = { [weak self] string in
                guard let self = self else { return }
                self.cheatCode = string
                self.validateInput()
            }
            cell.setData(supportedCheatFormats: supportedCheatFormats, currentCheatFormat: currentCheatFormat, cheatCode: cheatCode)
            cell.didChangeCheatFormat = { [weak self] cheatFormat in
                self?.currentCheatFormat = cheatFormat
                self?.validateInput()
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: ASListCustomCollectionCell.self, for: indexPath)
            cell.setData(customView: saveButtonContainerView)
            return cell
        }
        
    }
}

extension AddCheatCodeView: UICollectionViewDelegate {
    
}

extension AddCheatCodeView: ShowableView {
    static func show(game: Game, editGameCheat: GameCheat? = nil) {
        if let editGameCheat {
            Self.show(parameters: game, editGameCheat)
        } else {
            Self.show(parameters: game)
        }
    }
}
