//
//  AddCheatCodeContentCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later



class AddCheatCodeContentCell: UICollectionViewCell {
    
    private var supportedCheatFormats: [CheatFormat]!
    private var currentCheatFormat: CheatFormat!
    var didChangeCheatFormat: ((CheatFormat)->Void)? = nil
    var didTextChange: ((String)->Void)? = nil
    
    private lazy var titleButton: ASButtonView = {
        let view = ASButtonView(.quickButton(icon: .symbol(.chevronUpChevronDown,
                                                           colors: [R.Color.LabelSecondary]),
                                             title: R.string.localizable.autoDetectCheatTypeName(),
                                             titleColor: R.Color.LabelSecondary,
                                             titlePosition: .left,
                                             background: .clear,
                                             sizeStyle: .fixHeight(R.Size.ButtonMedium,
                                                                   insets: .insets(top: R.Size.ContentSpaceSmall,
                                                                                   bottom: R.Size.ContentSpaceSmall))))
        view.didTapButton = { [weak self] in
            guard let self = self else { return }
            
            let cells = self.supportedCheatFormats.map({
                ASListPage.Cell.iconTitleDetailRadioCell(title: $0.name,
                                                         detail: $0.type == .autoDetect ? nil : "\(R.string.localizable.cheatCodeFormat()): \($0.format)",
                                                         isSelected: $0.type == self.currentCheatFormat.type)
            })
            
            ChevronSheetView.show(icon: .symbolImage(R.image.cheat_iconSymbols()),
                                  title: R.string.localizable.cheatCodeFormat(),
                                  cellOptions: cells, completion: { [weak self] index in
                guard let self, let index else { return }
                let cheatFormat = self.supportedCheatFormats[index]
                self.titleButton.setTitleString(cheatFormat.name)
                let placeholder = cheatFormat.type == .autoDetect ? cheatFormat.format : "\(R.string.localizable.cheatCodeFormat()): \(cheatFormat.format)"
                self.textViewPlaceHolderLabel.attributedText = NSAttributedString(string: placeholder,
                                                                                  attributes: [
                                                                                    .font: R.Font.Body(),
                                                                                    .foregroundColor: R.Color.LabelTertiary
                                                                                  ])
                self.currentCheatFormat = cheatFormat
                self.didChangeCheatFormat?(cheatFormat)
                
            })
        }
        return view
    }()
    
    private var textViewPlaceHolderLabel = UILabel()
    
    lazy var editTextView: UITextView = {
        let view = UITextView()
        view.backgroundColor = .clear
        view.textColor = R.Color.LabelPrimary
        view.font = R.Font.Body()
        view.returnKeyType = .default
        view.delegate = self
        view.isFocusable = true
        view.onFocusConfirm = { [weak self] in
            self?.editTextView.becomeFirstResponder()
            return true
        }
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(titleButton)
        titleButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceExtraSmall)
            make.top.equalToSuperview()
        }
        
        let textFieldContainer = RoundAndBorderView(roundCorner: .allCorners, radius: R.Size.CornerRadiusMedium)
        textFieldContainer.backgroundColor = R.Color.InputBox
        addSubview(textFieldContainer)
        textFieldContainer.snp.makeConstraints { make in
            make.top.equalTo(titleButton.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }
        
        textFieldContainer.addSubview(editTextView)
        editTextView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceSmall)
        }
        
        textFieldContainer.addSubview(textViewPlaceHolderLabel)
        textViewPlaceHolderLabel.snp.makeConstraints { make in
            make.top.equalTo(editTextView).offset(R.Size.ContentSpaceExtraSmall)
            make.leading.trailing.equalTo(editTextView).inset(R.Size.ContentSpaceTiny)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(supportedCheatFormats: [CheatFormat], currentCheatFormat: CheatFormat, cheatCode: String) {
        self.supportedCheatFormats = supportedCheatFormats
        self.currentCheatFormat = currentCheatFormat
        titleButton.setTitleString(currentCheatFormat.name)
        textViewPlaceHolderLabel.attributedText = NSAttributedString(string: currentCheatFormat.format, attributes: [.font: R.Font.Body(), .foregroundColor: R.Color.LabelTertiary])
        editTextView.text = cheatCode
        textViewPlaceHolderLabel.isHidden = !cheatCode.isEmpty
    }
}

extension AddCheatCodeContentCell: UITextViewDelegate {
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        textViewPlaceHolderLabel.isHidden = !textView.text.isEmpty
        return true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        textViewPlaceHolderLabel.isHidden = !textView.text.isEmpty
    }
    
    func textViewDidChange(_ textView: UITextView) {
        textViewPlaceHolderLabel.isHidden = !textView.text.isEmpty
        didTextChange?(textView.text)
    }
}
