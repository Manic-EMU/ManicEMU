//
//  ColorPickerView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ChromaColorPicker

class ColorPickerView: BaseView {
    private var colorPickerSize: CGSize {
        if UIDevice.isPhone, preferredLayoutStyle == .landscape {
            return CGSize(150)
        }
        return CGSize(290)
    }
    private let colorPicker = ChromaColorPicker(frame: CGRect(origin: .zero, size: CGSize(290)))
    private let brightnessSlider = ChromaBrightnessSlider()
    private let colorView = ThemeColorCollectionViewCell.ColorView()
    private lazy var textField: UITextField = {
        let view = UITextField()
        view.textColor = R.Color.LabelPrimary
        view.font = R.Font.Body()
        view.clearButtonMode = .whileEditing
        view.attributedPlaceholder = NSAttributedString(string: R.Color.Main.hexString, attributes: [.font: R.Font.Body(), .foregroundColor: R.Color.LabelSecondary])
        view.isFocusable = true
        view.onFocusConfirm = { [weak self] in
            self?.textField.becomeFirstResponder()
            return true
        }
        return view
    }()
    private var addButton: ASButtonView = {
        let view = ASButtonView(.iconOnly(icon: .symbol(.plus),
                                          iconSize: CGSize(48),
                                          background: R.Color.BackgroundSecondary,
                                          insets: .init(inset: R.Size.ContentSpaceExtraSmall)))
        return view
    }()
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation())
        view.didTapClose = { [weak self] in
            guard let self else { return }
            self.hide()
        }
        return view
    }()
    
    private lazy var colorPickerContainerView: UIView = {
       let view = UIView()
        
        view.addSubview(colorPicker)
        colorPicker.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(colorPickerSize)
        }
        
        view.addSubview(brightnessSlider)
        brightnessSlider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(70)
            make.height.equalTo(28)
            make.top.equalTo(colorPicker.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        view.addSubview(colorView)
        colorView.snp.makeConstraints { make in
            make.size.equalTo(48)
            make.leading.equalTo(brightnessSlider)
            make.top.equalTo(brightnessSlider.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        let textFieldContainer = RoundAndBorderView(roundCorner: .allCorners, radius: R.Size.CornerRadiusMedium)
        textFieldContainer.backgroundColor = R.Color.InputBox
        view.addSubview(textFieldContainer)
        textFieldContainer.snp.makeConstraints { make in
            make.centerY.equalTo(colorView)
            make.leading.equalTo(colorView.snp.trailing).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(R.Size.ItemHeightSmall)
        }
        
        textFieldContainer.addSubview(textField)
        textField.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        
        view.addSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.centerY.equalTo(colorView)
            make.leading.equalTo(textFieldContainer.snp.trailing).offset(R.Size.ContentSpaceLarge)
            make.trailing.equalTo(brightnessSlider)
        }
        
        return view
    }()
    
    private lazy var saveButton: ASButtonView = {
        let view = ASButtonView(.large(title: R.string.localizable.saveTitle(),
                                       titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                       titleAlignment: .center,
                                       background: R.Color.Main))
        view.enableFocusEffects = false
        view.didTapButton = { [weak self] in
            guard let self else { return }
            if var themeColor = self.themeColor {
                //编辑
                themeColor.colors = self.colorPicker.handles.map({ $0.color.hexString })
                self.didSaveAction?(themeColor)
            } else {
                //新增
                let themeColor = ThemeColor(timestamp: Date.now.timeIntervalSince1970ms, colors: self.colorPicker.handles.map({ $0.color.hexString }), isSelect: false, system: false)
                self.didSaveAction?(themeColor)
            }
            self.hide()
        }
        return view
    }()
    
    //点击保存回调
    var didSaveAction: ((ThemeColor)->Void)? = nil
    
    private var themeColor: ThemeColor? = nil
    
    required init?(parameters: Any...) {
        super.init(frame: .zero)
        
        themeColor = parameters.compactMap({ $0 as? ThemeColor }).first
        
        colorPicker.delegate = self
        colorPicker.borderColor = R.Color.BackgroundSecondary
        
        
        brightnessSlider.handle.borderColor = R.Color.BackgroundSecondary
        brightnessSlider.borderColor = R.Color.BackgroundSecondary
        brightnessSlider.trackColor = R.Color.Main
        brightnessSlider.handle.borderWidth = 2.0
        
        
        //添加两个颜色
        if let colors = themeColor?.colors.compactMap({ UIColor(hexString: $0) }), colors.count > 0 {
            for (index, color) in colors.enumerated() {
                if index == 0 {
                    let homeHandle = colorPicker.addHandle(at: color)
                    homeHandle.accessoryView = UIImageView(image: .init(symbol: .house, font: R.Font.LargeTitle(emphasis: true), color: .white))
                } else {
                    colorPicker.addHandle(at: color)
                }
            }
        } else {
            let homeHandle = colorPicker.addHandle(at: R.Color.Main)
            homeHandle.accessoryView = UIImageView(image: .init(symbol: .house, font: R.Font.LargeTitle(emphasis: true), color: .white))
            colorPicker.addHandle(at: UIColor.random)
        }
        
        brightnessSlider.connect(to: colorPicker)
        
        colorView.selectView.isHidden = true
        colorView.animatedGradientView.setColors(colorPicker.handles.map({ $0.color }))

        
        textField.onReturnKeyPress { [weak self] in
            guard let self = self else { return }
            self.textField.resignFirstResponder()
            if let hex = self.textField.text, let color = UIColor(hexString: hex), let handle = self.colorPicker.currentHandle {
                handle.color = color
                self.colorPicker.setNeedsLayout()
                self.brightnessSlider.trackColor = color
                self.colorPickerHandleDidChangeEnd(self.colorPicker)
            }
        }
        
        addButton.didTapButton = { [weak self] in
            guard let self = self else { return }
            guard self.colorPicker.handles.count < R.Numbers.ThemeColorMaxCount else {
                UIView.makeToast(message: R.string.localizable.themeColorLimitToast())
                return
            }
            self.colorPicker.addHandle(at: UIColor.random)
            self.colorView.animatedGradientView.setColors(self.colorPicker.handles.map({ $0.color }))
        }
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(colorPickerContainerView)
        colorPickerContainerView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.ButtonExtraLarge + R.Size.ContentSpaceLarge)
        }
        
        addSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            if UIDevice.isPad || (UIDevice.isPhone && proHUDLayoutStyle() == .landscape) {
                make.width.equalTo(R.Size.ButtonMaxWidth)
                make.centerX.equalToSuperview()
            } else {
                make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(R.Size.ContentSpaceHuge)
            }
            make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow))
            make.height.equalTo(R.Size.ButtonExtraLarge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension ColorPickerView: ChromaColorPickerDelegate {
    func colorPickerHandleDidChange(_ colorPicker: ChromaColorPicker, handle: ChromaColorHandle, to color: UIColor) {
        textField.text = color.hexString
    }
    
    func colorPickerHandleDidChangeEnd(_ colorPicker: ChromaColorPicker) {
        colorView.animatedGradientView.setColors(colorPicker.handles.map({ $0.color }))
    }
    
}

extension ColorPickerView: ShowableView {
    static func show(themeColor: ThemeColor?, didSaveAction: ((ThemeColor)->Void)? = nil) {
        if let themeColor {
            Self.show(parameters: themeColor)?.didSaveAction = didSaveAction
        } else {
            Self.show()?.didSaveAction = didSaveAction
        }
    }
    
    var prefferdConstraintHeight: CGFloat? {
        if UIDevice.isPhone, proHUDLayoutStyle() == .portrait {
            return 582
        }
        return R.Size.SheetWindowMaxSize.height
    }
    
    func dataForShow(_ defaultData: ASSheet) -> ASSheet {
        var sheetData = defaultData
        sheetData.enableGrabber = false
        return sheetData
    }
}

extension ColorPickerView: ViewTransition {
    func viewAlongsideTransition() {
        if UIDevice.isPhone {
            colorPicker.snp.updateConstraints { make in
                make.size.equalTo(colorPickerSize)
            }
            
            saveButton.snp.updateConstraints { make in
                make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow))
            }
        }
        
    }
}
