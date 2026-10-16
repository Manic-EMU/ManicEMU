//
//  AddTriggerButtonStyleView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/4.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import IceCream

class AddTriggerButtonStyleView: BaseView {
    
    class ButtonView: BaseView, UITextFieldDelegate {
        var style: TriggerItem.Style = .classic {
            didSet {
                triggerButton.style = style
                titleTextField.isUserInteractionEnabled = (style != .custom)
            }
        }
        var buttonSize: CGSize = TriggerItem.Style.classic.defaultSize {
            didSet {
                triggerButton.buttonSize = buttonSize
                triggerButton.snp.updateConstraints { make in
                    make.size.equalTo(buttonSize)
                }
            }
        }
        //0-1
        var buttonOpacity: CGFloat = 1 {
            didSet {
                triggerButton.buttonOpacity = buttonOpacity
            }
        }
        var buttonRadius: CGFloat = R.Size.CornerRadiusMedium {
            didSet {
                guard style == .custom else { return }
                triggerButton.buttonCornerRadius = buttonRadius
            }
        }
        var buttonText: String = "M" {
            didSet {
                guard style != .custom else { return }
                triggerButton.title = buttonText
            }
        }
        
        var image: UIImage? {
            didSet {
                guard style == .custom else { return }
                triggerButton.image = image
            }
        }
        
        var didButtonTextChange: ((String)->Void)? = nil
        var didImageChange: ((UIImage?)->Void)? = nil
        /// 输入法组字开始前的文本，用于上屏后从「旧内容 + 新输入」里取出本次输入
        private var textBeforeIME: String?
        
        private let triggerButton: TriggerButton = {
            let view = TriggerButton(style: .classic,
                                     title: "M",
                                     buttonSize: TriggerItem.Style.classic.defaultSize,
                                     buttonCornerRadius: 0,
                                     buttonOpacity: 1,
                                     isEditMode: true)
            return view
        }()
        
        private lazy var editButton: ASButtonView = {
            let view = ASButtonView(.smallIconButton(icon: .symbolImage(R.image.camera_iconSymbols(), colors: [R.Color.Main]),
                                                     background: R.Color.BackgroundQuaternary))
            view.didTapButton = { [weak self] in
                guard let self = self else { return }
                if self.style == .custom {
                    //上传照片
                    ImageFetcher.showCommonFetcher(sources: [.capture, .library, .file],
                                                   in: self.hostingWindowScene,
                                                   completion: { [weak self] image, _ in
                        if let image = image?.scaled(toSize: self?.buttonSize ?? TriggerItem.Style.custom.defaultSize) {
                            self?.triggerButton.image = image
                            self?.didImageChange?(image)
                        }
                    })
                } else {
                    self.titleTextField.becomeFirstResponder()
                }
            }
            return view
        }()
        
        private lazy var titleTextField: UITextField = {
            let textField = UITextField()
            textField.textAlignment = .center
            textField.textColor = .clear
            textField.font = style.getFont(buttonSize: buttonSize)
            textField.text = "M"
            textField.clearButtonMode = .never
            textField.returnKeyType = .done
            textField.delegate = self
            textField.onReturnKeyPress { [weak self, weak textField] in
                guard let self = self else { return }
                textField?.resignFirstResponder()
            }
            
            textField.onChange { [weak textField, weak self] _ in
                guard let self, let textField else { return }
                self.handleCommittedTextChange(textField)
            }
            return textField
        }()
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.selectAll(nil)
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // In pinyin/kana/Hangul and other character composition systems: ignore the marked content for now, and only apply restrictions when it's actually displayed on screen.
            if textField.markedTextRange != nil {
                return true
            }
            
            textBeforeIME = textField.text
            
            if string.isEmpty {
                return true
            }
            
            // When multiple graphemes are submitted at once (e.g., pasting, whole-word input, etc.): only the first extended grapheme cluster of the input is taken.
            if string.count > 1 {
                applySingleSymbol(firstGrapheme(of: string), to: textField)
                textBeforeIME = nil
                return false
            }
            
            // Let the single grapheme pass through first, to avoid interrupting the starting point of the input method's composition (at this time, markedTextRange is often still nil).
            return true
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            if textField.markedTextRange != nil {
                textField.unmarkText()
            }
            handleCommittedTextChange(textField)
        }
        
        /// When the composition is complete, collapse the text field to the first grapheme of this input, and update the button title accordingly.
        private func handleCommittedTextChange(_ textField: UITextField) {
            guard textField.markedTextRange == nil else { return }
            
            var text = textField.text ?? ""
            if text.count > 1 {
                if let before = textBeforeIME, !before.isEmpty, text.hasPrefix(before) {
                    let inserted = String(text.dropFirst(before.count))
                    text = firstGrapheme(of: inserted.isEmpty ? text : inserted)
                } else {
                    text = firstGrapheme(of: text)
                }
                textField.text = text
            }
            textBeforeIME = nil
            applyButtonTitle(from: text)
        }
        
        private func applySingleSymbol(_ symbol: String, to textField: UITextField) {
            textField.text = symbol
            applyButtonTitle(from: symbol)
        }
        
        private func applyButtonTitle(from text: String) {
            let title = text.uppercased()
            triggerButton.title = title
            didButtonTextChange?(title)
        }
        
        /// Swift's `Character` is an extended grapheme cluster, which correctly handles emoji with skin tones, ZWJ sequences, flags, and more.
        private func firstGrapheme(of string: String) -> String {
            String(string.prefix(1))
        }
        
        override init(frame: CGRect) {
            super.init(frame: .zero)
            backgroundColor = R.Color.BackgroundTertiary
            layerCornerRadius = R.Size.CornerRadiusLarge
            
            addSubview(triggerButton)
            triggerButton.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(buttonSize)
            }
            
            addSubview(editButton)
            editButton.snp.makeConstraints { make in
                make.trailing.top.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
            }
            
            addSubview(titleTextField)
            titleTextField.snp.makeConstraints { make in
                make.edges.equalTo(triggerButton).inset(R.Size.ContentSpaceExtraSmall)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
    }
    
    class SliderView: BaseView {
        private var titleLabel: UILabel = {
            let label = UILabel()
            label.font = R.Font.Body()
            label.textColor = R.Color.LabelPrimary
            return label
        }()
        
        private var detailLabel: UILabel = {
            let label = UILabel()
            label.font = R.Font.Footnote()
            label.textColor = R.Color.LabelSecondary
            return label
        }()
        
        private var sliderView: UISlider = {
            let view = UISlider()
            view.minimumTrackTintColor = R.Color.Main
            view.maximumTrackTintColor = R.Color.BackgroundTertiary
            view.enableFocusAdjustment()
            view.enableFocusEffects = false
            return view
        }()
        
        var didValueChange: ((CGFloat)->Void)? = nil
        var didChangeEnd: ((CGFloat)->Void)? = nil
        private var numberOfDecimalPlaces: Int
        var valueSufix: String?
        var value: Float = 0 {
            didSet {
                detailLabel.text = (numberOfDecimalPlaces == -1 ? "\(Int(value))" : "\(value)") + (valueSufix ?? "")
                sliderView.value = value
            }
        }
        
        init(title: String, valueSufix: String?, minimumValue: Float, maximumValue: Float, numberOfDecimalPlaces: Int = 0) {
            self.numberOfDecimalPlaces = numberOfDecimalPlaces
            self.valueSufix = valueSufix
            super.init(frame: .zero)
            
            addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.leading.top.equalToSuperview()
            }
            
            addSubview(detailLabel)
            detailLabel.snp.makeConstraints { make in
                make.leading.equalTo(titleLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
                make.bottom.equalTo(titleLabel)
            }
            
            addSubview(sliderView)
            sliderView.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceTiny)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(28)
            }
            
            titleLabel.text = title
            detailLabel.text = (numberOfDecimalPlaces == -1 ? "\(Int(value))" : "\(value)") + (valueSufix ?? "")
            sliderView.minimumValue = minimumValue
            sliderView.maximumValue = maximumValue
            
            sliderView.on(.touchUpInside) { [weak self] sender, forEvent in
                guard let self = self else { return }
                let value = self.sliderView.value.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .toNearestOrEven)
                self.didChangeEnd?(CGFloat(value))
            }
            
            sliderView.on(.touchUpOutside) { [weak self] sender, forEvent in
                guard let self = self else { return }
                let value = self.sliderView.value.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .toNearestOrEven)
                self.didChangeEnd?(CGFloat(value))
            }
            
            sliderView.on(.valueChanged) { [weak self] sender, forEvent in
                guard let self = self else { return }
                let value = self.sliderView.value.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .toNearestOrEven)
                self.didValueChange?(CGFloat(value))
                self.detailLabel.text = (numberOfDecimalPlaces == -1 ? "\(Int(value))" : "\(value)") + (self.valueSufix ?? "")
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private lazy var segmentView: ASSegmentView = {
        let view = ASSegmentView(.textSegment(titles: [
            R.string.localizable.classic(),
            R.string.localizable.flat(),
            R.string.localizable.custom()
        ], index: item.style.rawValue))
        return view
    }()
    
    private var triggerButtonView: ButtonView = {
        let view = ButtonView()
        return view
    }()
    
    private var sizeSliderView: SliderView = {
        let defaultStyle = TriggerItem.Style.classic
        let view = SliderView(title: R.string.localizable.size() + ":",
                              valueSufix: nil,
                              minimumValue: defaultStyle.sizeRange.min,
                              maximumValue: defaultStyle.sizeRange.max,
                              numberOfDecimalPlaces: 1)
        return view
    }()
    
    private var opacitySliderView: SliderView = {
        let defaultStyle = TriggerItem.Style.classic
        let view = SliderView(title: R.string.localizable.opacity() + ":",
                              valueSufix: "%",
                              minimumValue: 5,
                              maximumValue: 100)
        return view
    }()
    
    private var cornerRadiusSliderView: SliderView = {
        let view = SliderView(title: R.string.localizable.cornerRadius() + ":",
                              valueSufix: "%",
                              minimumValue: 0,
                              maximumValue: 100)
        view.isHidden = true
        return view
    }()
    
    private let item: TriggerItem
    
    var needToUpdateCellHeight: (()->Void)? = nil
    
    init(item: TriggerItem) {
        self.item = item
        super.init(frame: .zero)

        addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightSmall)
        }
        
        addSubview(triggerButtonView)
        triggerButtonView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(segmentView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(120)
        }
        
        addSubview(sizeSliderView)
        sizeSliderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            make.top.equalTo(triggerButtonView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(50)
        }
        
        addSubview(opacitySliderView)
        opacitySliderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            make.top.equalTo(sizeSliderView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(50)
        }
        
        addSubview(cornerRadiusSliderView)
        cornerRadiusSliderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            make.top.equalTo(opacitySliderView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(50)
        }
        
        //segmentView
        segmentView.didSelectIndex = { [weak self] index in
            guard let self else { return }
            if let style = TriggerItem.Style(rawValue: index) {
                guard self.item.style != style else { return }
                self.item.style = style
                self.item.buttonWidth = style.defaultSize.width
                self.item.buttonHeight = style.defaultSize.height
                self.item.buttonOpacity = 1
                self.item.buttonCornerRadiusRatio = 100
                self.triggerButtonView.style = style
                self.triggerButtonView.buttonSize = style.defaultSize
                self.triggerButtonView.buttonOpacity = 1
                self.triggerButtonView.buttonRadius = style.defaultSize.height/2
                self.sizeSliderView.value = Float(style.defaultSize.width)
                self.opacitySliderView.value = 100
                self.cornerRadiusSliderView.value = 100
                switch style {
                case .classic, .flat:
                    self.cornerRadiusSliderView.isHidden = true
                case .custom:
                    self.cornerRadiusSliderView.isHidden = false
                }
                self.needToUpdateCellHeight?()
            }
        }
        
        //ButtonView
        triggerButtonView.style = item.style
        triggerButtonView.buttonSize = item.buttonSize
        triggerButtonView.buttonOpacity = item.buttonOpacity
        if item.style == .custom {
            triggerButtonView.buttonRadius = item.buttonCornerRadius
            if let imageFilePath = item.customImage?.filePath {
                triggerButtonView.image = UIImage(contentsOfFile: imageFilePath.path)
            }
        } else {
            triggerButtonView.buttonRadius = 0
            triggerButtonView.buttonText = item.buttonText
        }
        triggerButtonView.didButtonTextChange = { title in
            item.buttonText = title
        }
        triggerButtonView.didImageChange = { image in
            if let image, let imageData = image.jpegData(compressionQuality: 0.7) {
                if let oldCustomImage = item.customImage {
                    if let _ = oldCustomImage.realm {
                        oldCustomImage.deleteAndClean(realm: Database.realm)
                    } else {
                        try? FileManager.safeRemoveItem(at: oldCustomImage.filePath)
                    }
                }
                item.customImage = CreamAsset.create(objectID: "\(PersistedKit.incrementID)", propName: "customImage", data: imageData)
            }
        }
        
        //sizeSliderView
        sizeSliderView.value = Float(item.buttonWidth)
        sizeSliderView.didValueChange = { [weak self] size in
            guard let self else { return }
            item.buttonWidth = Double(size).rounded(numberOfDecimalPlaces: 1, rule: .toNearestOrEven)
            item.buttonHeight = item.buttonWidth
            self.triggerButtonView.buttonSize = .init(CGFloat(size))
            if item.style == .custom {
                self.triggerButtonView.buttonRadius = item.buttonCornerRadius
            }
        }
        
        //opacitySliderView
        opacitySliderView.value = Float(item.buttonOpacity*100)
        opacitySliderView.didValueChange = { [weak self] opacity in
            guard let self else { return }
            let opacity = opacity/100
            item.buttonOpacity = Double(opacity).rounded(numberOfDecimalPlaces: 1, rule: .toNearestOrEven)
            self.triggerButtonView.buttonOpacity = opacity
        }
        
        //cornerRadiusSliderView
        if item.style == .custom {
            cornerRadiusSliderView.isHidden = false
            cornerRadiusSliderView.value = Float(item.buttonCornerRadiusRatio)
        } else {
            cornerRadiusSliderView.isHidden = true
        }
        cornerRadiusSliderView.didValueChange = { [weak self] cornerRadiusRatio in
            guard let self else { return }
            item.buttonCornerRadiusRatio = Double(cornerRadiusRatio).rounded(numberOfDecimalPlaces: 1, rule: .toNearestOrEven)
            self.triggerButtonView.buttonRadius = item.buttonCornerRadius
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
