//
//  ThreeDSKeyboardView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
#if !SIMULATOR
import Citra
#endif
import ProHUD

struct ThreeDSKeyboardView {
#if !SIMULATOR
    static func showForCitra(config: CitraKeyboardConfig,
                             completion: ((_ buttonPressed: Int, _ text: String?) -> Void)? = nil) {
        let mapped = AzaharKeyboardConfig()
        mapped.buttonConfig = AzaharButtonConfig(rawValue: config.buttonConfig.rawValue) ?? .single
        mapped.acceptedInput = AzaharAcceptedInput(rawValue: config.acceptedInput.rawValue) ?? .anything
        mapped.multilineMode = config.multilineMode
        mapped.maxTextLength = Int(config.maxTextSize)
        mapped.maxDigits = Int(config.maxDigits)
        mapped.hintText = config.hintText
        mapped.buttonText = config.buttonText
        mapped.preventDigit = config.preventDigit
        mapped.preventAt = config.preventAt
        mapped.preventPercent = config.preventPercent
        mapped.preventBackslash = config.preventBackslash
        mapped.preventProfanity = config.preventProfanity
        mapped.enableCallback = config.enableCallback

        showForAzahar(config: mapped) { buttonType, text in
            let buttonPressed: Int
            switch buttonType {
            case .ok:
                switch config.buttonConfig {
                case .dual:
                    buttonPressed = 1
                case .triple:
                    buttonPressed = 2
                case .single, .none:
                    buttonPressed = 0
                @unknown default:
                    buttonPressed = 0
                }
            case .cancel:
                buttonPressed = 0
            case .forgot:
                buttonPressed = 1
            case .noButton:
                buttonPressed = 0
            @unknown default:
                buttonPressed = 0
            }
            // Always notify the core so Execute() cannot stay blocked.
            NotificationCenter.default.post(name: .init("closeKeyboard"), object: nil, userInfo: [
                "buttonPressed": buttonPressed,
                "keyboardText": text ?? ""
            ])
            completion?(buttonPressed, text)
        }
    }
#endif
    
    static func showForAzahar(config: AzaharKeyboardConfig,
                              tapAction: ((_ buttonType: AzaharButtonType, _ inputText: String?)->Void)? = nil) {
        
        Alert { alert in
            alert.config.cardCornerRadius = 0
            alert.contentMaskView.alpha = 0
            alert.config.backgroundViewMask { mask in
                mask.backgroundColor = .clear
            }
            
            let textfiledWidth = UIDevice.isPhone ? 300 : 380

            let containerView = RoundAndBorderView(roundCorner: .allCorners)
            containerView.backgroundColor = R.Color.BackgroundPrimary
            containerView.makeBlur()
            
            // 标题
            let titleLabel = UILabel()
            titleLabel.textAlignment = .center
            let textTitle: String
            if let hintText = config.hintText, !hintText.isEmpty {
                textTitle = hintText
            } else {
                textTitle = R.string.localizable.game3DSInputTitle()
            }
            titleLabel.text = textTitle
            titleLabel.font = R.Font.Headline(emphasis: true)
            titleLabel.textColor = R.Color.LabelPrimary
            containerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                make.leading.trailing.greaterThanOrEqualToSuperview().inset(R.Size.ContentSpaceMedium)
            }
            
            // 输入框容器高度根据是否多行模式调整
            let textFieldHeight = config.multilineMode ? R.Size.ItemHeightMedium * 3 : R.Size.ItemHeightMedium
            
            let textFieldContainer = RoundAndBorderView(roundCorner: .allCorners, radius: R.Size.CornerRadiusMedium, borderColor: R.Color.Border, borderWidth: 1)
            textFieldContainer.backgroundColor = R.Color.InputBox
            containerView.addSubview(textFieldContainer)
            textFieldContainer.snp.makeConstraints { make in
                make.height.equalTo(textFieldHeight)
                make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceMedium)
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                make.width.equalTo(textfiledWidth)
            }
            
            var inputText: () -> String? = { nil }
            var bindReturnToSubmit: ((@escaping () -> Void) -> Void)?
            
            if config.multilineMode {
                let textView = UITextView()
                textView.backgroundColor = .clear
                textView.tintColor = R.Color.Main
                textView.textColor = R.Color.LabelPrimary
                textView.font = R.Font.Footnote()
                textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
                textFieldContainer.addSubview(textView)
                textView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                textView.becomeFirstResponder()
                inputText = { textView.text }
                textView.isFocusable = true
                textView.onFocusConfirm = { [weak textView] in
                    textView?.becomeFirstResponder()
                    return true
                }
                
            } else {
                let textField = UITextField()
                
                if config.acceptedInput == .fixedLength, config.maxTextLength > 0 {
                    textField.placeholder = R.string.localizable.exactlyTextSizeAllowDesc("\(config.maxTextLength)")
                } else if config.maxTextLength > 0 {
                    textField.placeholder = R.string.localizable.maxTextSizeAllowDesc("\(config.maxTextLength)")
                }
                
                textField.tintColor = R.Color.Main
                textField.textColor = R.Color.LabelPrimary
                textField.font = R.Font.Footnote()
                textField.clearButtonMode = .whileEditing
                
                if config.preventDigit && config.maxDigits == 0 {
                    textField.keyboardType = .default
                }
                
                textFieldContainer.addSubview(textField)
                textField.snp.makeConstraints { make in
                    make.top.bottom.equalToSuperview()
                    make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
                }
                textField.becomeFirstResponder()
                inputText = { textField.text }
                bindReturnToSubmit = { submit in
                    textField.onReturnKeyPress {
                        submit()
                    }
                }
                textField.isFocusable = true
                textField.onFocusConfirm = { [weak textField] in
                    textField?.becomeFirstResponder()
                    return true
                }
            }
            
            let line = UIView()
            line.backgroundColor = R.Color.Border
            containerView.addSubview(line)
            line.snp.makeConstraints { make in
                make.height.equalTo(1)
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
                make.top.equalTo(textFieldContainer.snp.bottom).offset(R.Size.ContentSpaceMedium)
            }
            
            // 3DS SWKBD measures length in UTF-16 code units.
            func utf16Length(_ text: String) -> Int {
                text.utf16.count
            }

            func validateInput(_ text: String?) -> String? {
                guard let text = text else { return nil }
                let length = utf16Length(text)
                let isBlank = text.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }

                if config.acceptedInput == .notEmpty || config.acceptedInput == .notEmptyAndNotBlank {
                    if text.isEmpty {
                        return R.string.localizable.emptyInputNotAllowed()
                    }
                }

                if config.acceptedInput == .notBlank || config.acceptedInput == .notEmptyAndNotBlank {
                    if isBlank {
                        return R.string.localizable.blankInputNotAllowed()
                    }
                }

                if config.acceptedInput == .fixedLength {
                    if length != config.maxTextLength {
                        return R.string.localizable.exactlyTextSize("\(config.maxTextLength)")
                    }
                }

                if config.maxTextLength > 0, length > config.maxTextLength {
                    return R.string.localizable.maxTextSizeAllowDesc("\(config.maxTextLength)")
                }

                if config.preventAt, text.contains("@") {
                    return R.string.localizable.atSymbolNotAllowed()
                }

                if config.preventPercent, text.contains("%") {
                    return R.string.localizable.percentSymbolNotAllowed()
                }

                if config.preventBackslash, text.contains("\\") {
                    return R.string.localizable.backslashSymbolNotAllowed()
                }

                if config.preventDigit {
                    let digitCount = text.filter { $0.isNumber }.count
                    if digitCount > config.maxDigits {
                        return R.string.localizable.digitsMaximumAllowed("\(config.maxDigits)")
                    }
                }

                return nil
            }
            
            // 关闭键盘函数
            func closeKeyboard(text: String?, buttonType: AzaharButtonType) {
                alert.pop()
                tapAction?(buttonType, text)
            }
            
            // 获取自定义按钮文本
            func getButtonText(at index: Int, defaultText: String) -> String {
                if let buttonTexts = config.buttonText, index < buttonTexts.count, !buttonTexts[index].isEmpty {
                    return buttonTexts[index]
                }
                return defaultText
            }
            
            // buttonText order: [0]=Cancel, [1]=Forgot, [2]=Ok
            func submitOk() {
                let text = inputText()
                if let errorMessage = validateInput(text) {
                    textFieldContainer.shake()
                    UIView.makeToast(message: errorMessage)
                    return
                }
                if config.acceptedInput == .anything || (text != nil && !(text?.isEmpty ?? true)) {
                    closeKeyboard(text: text, buttonType: .ok)
                } else {
                    textFieldContainer.shake()
                }
            }
            bindReturnToSubmit?(submitOk)

            let okButton = UILabel()
            okButton.isUserInteractionEnabled = true
            okButton.enablePressEffect = true
            okButton.text = getButtonText(at: 2, defaultText: R.string.localizable.confirmTitle())
            okButton.textAlignment = .center
            okButton.font = R.Font.Headline()
            okButton.textColor = R.Color.LabelPrimary
            okButton.addTapGesture { _ in
                submitOk()
            }
            
            let cancelButton = UILabel()
            cancelButton.isUserInteractionEnabled = true
            cancelButton.enablePressEffect = true
            cancelButton.text = getButtonText(at: 0, defaultText: R.string.localizable.cancelTitle())
            cancelButton.textAlignment = .center
            cancelButton.font = R.Font.Headline()
            cancelButton.textColor = R.Color.LabelSecondary
            cancelButton.addTapGesture { gesture in
                closeKeyboard(text: nil, buttonType: .cancel)
            }

            let forgetButton = UILabel()
            forgetButton.isUserInteractionEnabled = true
            forgetButton.enablePressEffect = true
            forgetButton.text = getButtonText(at: 1, defaultText: R.string.localizable.inputForget())
            forgetButton.textAlignment = .center
            forgetButton.font = R.Font.Headline()
            forgetButton.textColor = R.Color.LabelSecondary
            forgetButton.addTapGesture { gesture in
                closeKeyboard(text: nil, buttonType: .forgot)
            }
            
            if config.buttonConfig == .single || config.buttonConfig == .none {
                containerView.addSubview(okButton)
                okButton.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.top.equalTo(line.snp.bottom).offset(R.Size.ContentSpaceLarge)
                    make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                    make.bottom.equalToSuperview().inset(R.Size.ContentSpaceLarge)
                }
            } else if config.buttonConfig == .dual {
                containerView.addSubview(cancelButton)
                containerView.addSubview(okButton)

                let verticalLine = UIView()
                verticalLine.backgroundColor = R.Color.BackgroundTertiary
                containerView.addSubview(verticalLine)
                verticalLine.snp.makeConstraints { make in
                    make.size.equalTo(CGSize(width: 1, height: 26))
                    make.centerX.equalToSuperview()
                    make.centerY.equalTo(cancelButton)
                }

                cancelButton.snp.makeConstraints { make in
                    make.top.equalTo(line.snp.bottom).offset(R.Size.ContentSpaceLarge)
                    make.leading.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                    make.bottom.equalToSuperview().inset(R.Size.ContentSpaceLarge)
                    make.trailing.equalTo(verticalLine.snp.leading)
                }
                okButton.snp.makeConstraints { make in
                    make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                    make.leading.equalTo(verticalLine.snp.trailing)
                    make.centerY.equalTo(cancelButton)
                }

            } else {
                containerView.addSubview(cancelButton)
                containerView.addSubview(forgetButton)
                containerView.addSubview(okButton)

                forgetButton.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.top.equalTo(line.snp.bottom).offset(R.Size.ContentSpaceLarge)
                    make.width.equalToSuperview().dividedBy(3)
                    make.bottom.equalToSuperview().inset(R.Size.ContentSpaceLarge)
                }

                cancelButton.snp.makeConstraints { make in
                    make.leading.equalToSuperview()
                    make.trailing.equalTo(forgetButton.snp.leading)
                    make.centerY.equalTo(forgetButton)
                }

                okButton.snp.makeConstraints { make in
                    make.trailing.equalToSuperview()
                    make.leading.equalTo(forgetButton.snp.trailing)
                    make.centerY.equalTo(forgetButton)
                }
            }
            
            alert.set(customView: containerView).snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
}
