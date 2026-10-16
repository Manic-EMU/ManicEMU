//
//  LimitedTextInputView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/6/27.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ProHUD

struct LimitedTextInputView {
    enum LimitedType {
        case integer(min: Int, max: Int)
        case decimal(min: Double, max: Double)
        case normal(maxTextSize: Int, emptyEnable: Bool = false)
    }
    
    static func show(icon: ASIcon? = nil,
                     title: String? = nil,
                     detail: String? = nil,
                     text: String? = nil,
                     placeholder: String? = nil,
                     cancelTitle: String? = R.string.localizable.cancelTitle(),
                     confirmTitle: String? = R.string.localizable.confirmTitle(),
                     limitedType: LimitedType,
                     keyboadType: UIKeyboardType = .default,
                     confirmAction: ((_ result: Any)->Void)? = nil,
                     cancelAction: (()->Void)? = nil) {
        
        Alert { alert in
            alert.config.cardCornerRadius = 0
            alert.contentMaskView.alpha = 0

            let containerView = RoundAndBorderView(roundCorner: .allCorners)
            containerView.backgroundColor = R.Color.BackgroundPrimary
            
            let backgroundView = ASSheetView.BackgroundView()
            containerView.addSubview(backgroundView)
            backgroundView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            //标题
            var navigation = ASListPage.Navigation.defaultNavigation(title: title,
                                                                     titleIcon: icon)
            navigation.enableClose = false
            let navigationView = ASNavigationView(navigation)
            containerView.addSubview(navigationView)
            navigationView.snp.makeConstraints { make in
                make.leading.top.trailing.equalToSuperview()
                make.height.equalTo(R.Size.NavigationHeight)
            }
            
            var detailView: ASLabelView? = nil
            if let detail {
                let labelView = ASLabelView(text: .smallText(detail, numberOfLines: 0))
                containerView.addSubview(labelView)
                labelView.snp.makeConstraints { make in
                    make.top.equalTo(navigationView.snp.bottom).offset(R.Size.ContentSpaceSmall)
                    make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
                }
                detailView = labelView
            }
            
            var input: ASInput = .large(text: text,
                                        placeholder: placeholder,
                                        icon: .symbolImage(R.image.renameRegular_iconSymbols()))
            switch limitedType {
            case .integer(_, _):
                input.keyboardType = .numberPad
            case .decimal(_, _):
                input.keyboardType = .decimalPad
            case .normal(_, _):
                break
            }
            if keyboadType != .default {
                input.keyboardType = keyboadType
            }
            let inputView = ASListInputView(input)
            containerView.addSubview(inputView)
            inputView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
                make.top.equalTo((detailView ?? navigationView).snp.bottom).offset(R.Size.ContentSpaceSmall)
                make.height.equalTo(R.Size.ItemHeightMedium)
            }
            // Touch: open the keyboard after the alert animates.
            // Controller/keyboard: wait for A on the already-focused field.
            DispatchQueue.main.asyncAfter(delay: 0.35) {
                guard !FocusSystem.shared.hasExternalInput else { return }
                inputView.becomeFirstResponder()
            }
            
            let line = UIView()
            line.backgroundColor = R.Color.Border
            containerView.addSubview(line)
            line.snp.makeConstraints { make in
                make.height.equalTo(1)
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
                make.top.equalTo(inputView.snp.bottom).offset(R.Size.ContentSpaceMedium)
            }
            
            func closeKeyboard(input: Any? = nil) {
                alert.pop()
                if let input {
                    confirmAction?(input)
                } else {
                    cancelAction?()
                }
            }
            
            //cancelButton
            let cancelButton = ASButtonView(.quickButton(title: cancelTitle,
                                                         titleColor: R.Color.LabelSecondary,
                                                         titleFont: R.Font.Headline(),
                                                         titleAlignment: .center,
                                                         background: .clear,
                                                         sizeStyle: .fixHeight(R.Size.ButtonExtraLarge)))
            cancelButton.didTapButton = {
                closeKeyboard()
            }
            
            //verticalLine
            let verticalLine = UIView()
            verticalLine.backgroundColor = R.Color.Border
            
            //confrim button
            let button = ASButtonView(.quickButton(title: confirmTitle,
                                                   titleColor: R.Color.Main,
                                                   titleFont: R.Font.Headline(emphasis: true),
                                                   titleAlignment: .center,
                                                   background: .clear,
                                                   sizeStyle: .fixHeight(R.Size.ButtonExtraLarge)))
            button.didTapButton = {
                if let text = inputView.text?.trimmed {
                    var emptyEnable = false
                    if case .normal(_, let e) = limitedType {
                        emptyEnable = e
                    }
                    
                    if text.isEmpty && !emptyEnable {
                        inputView.shake()
                        return
                    }
                    
                    switch limitedType {
                    case .integer(let min, let max):
                        if let int = Int(text), int >= min, int <= max {
                            closeKeyboard(input: int)
                        } else {
                            inputView.shake()
                        }
                    case .decimal(let min, let max):
                        if let double = Double(text), double >= min, double <= max {
                            closeKeyboard(input: double)
                        } else {
                            inputView.shake()
                        }
                    case .normal(let maxTextSize, _):
                        if text.count <= maxTextSize {
                            closeKeyboard(input: text)
                        } else {
                            inputView.shake()
                        }
                    }
                } else {
                    inputView.shake()
                }
            }

            containerView.addSubviews([cancelButton, verticalLine, button])
            
            cancelButton.snp.makeConstraints { make in
                make.top.equalTo(line.snp.bottom)
                make.leading.equalToSuperview()
                make.trailing.equalTo(verticalLine.snp.leading)
                make.bottom.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                make.height.equalTo(R.Size.ButtonExtraLarge)
            }
            
            button.snp.makeConstraints { make in
                make.trailing.equalToSuperview()
                make.top.equalTo(line.snp.bottom)
                make.leading.equalTo(verticalLine.snp.trailing)
                make.height.equalTo(cancelButton)
            }
            
            verticalLine.snp.makeConstraints { make in
                make.centerY.equalTo(button)
                make.size.equalTo(CGSize(width: R.Size.Border, height: R.Size.ItemHeightMicro))
                make.centerX.equalToSuperview()
            }
            
            alert.config.backgroundViewMask { mask in
                mask.backgroundColor = .black.withAlphaComponent(0.5)
            }
            
            alert.onTappedBackground { alert in
                if inputView.isFirstResponder {
                    inputView.resignFirstResponder()
                } else {
                    closeKeyboard()
                }
            }
            
            alert.onViewDidAppear { [weak inputView] alert in
                alert.pushOverlayFocusContext { context in
                    context.cancelHandler = {
                        if inputView?.isFirstResponder == true {
                            inputView?.resignFirstResponder()
                            return true
                        }
                        return false
                    }
                }
            }
            alert.onViewDidDisappear { alert in
                alert.popFocusContext()
            }
            
            alert.set(customView: containerView).snp.makeConstraints { make in
                var width = 0.0
                if UIDevice.isPad {
                    width = 375
                } else {
                    width = R.Size.SheetWindowMinSize.width
                    if proHUDLayoutStyle() == .portrait {
                        width -= R.Size.ContentSpaceHuge*2
                    }
                }
                make.width.equalTo(width)
                make.edges.equalToSuperview()
            }
        }
    }
}
