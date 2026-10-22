//
//  ArticBaseCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ArticBaseCollectionCell: UICollectionViewCell {
    
    private lazy var descTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isUserInteractionEnabled = true
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0

        let text = R.string.localizable.articBaseDesc("Artic Setup Tool")
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: R.Font.Footnote(),
                .foregroundColor: R.Color.LabelSecondary
            ]
        )

        if let range = text.range(of: "Artic Setup Tool") {
            let nsRange = NSRange(range, in: text)

            attr.addAttributes([
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: URL(string: "https://github.com/azahar-emu/ArticSetupTool")!
            ], range: nsRange)
        }

        let style = NSMutableParagraphStyle()
        style.lineSpacing = R.Size.ContentSpaceTiny
        attr.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attr.length))

        tv.attributedText = attr

        tv.linkTextAttributes = [
            .foregroundColor: R.Color.Main,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        return tv
    }()
    
    private lazy var ipAddressTitleTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = R.Color.LabelSecondary
        textField.font = R.Font.Footnote()
        textField.attributedPlaceholder = NSAttributedString(string: "192.168.0.1:5543",
                                                             attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.LabelTertiary])
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.textAlignment = .right
        textField.keyboardType = .numbersAndPunctuation
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
        }
        textField.onChange { [weak textField] text in
            
        }
        textField.didEndEditing { [weak self] in
            guard let self else { return }
            if let _ = self.ipAddressTitleTextField.text?.parseIPv4String() {
                self.button.titleLabel.textColor = R.Color.LabelPrimary
                self.button.backgroundColor = R.Color.Main
                self.button.isUserInteractionEnabled = true
                self.didIPAddressChange?(self.ipAddressTitleTextField.text!)
            } else {
                self.button.titleLabel.textColor = R.Color.LabelSecondary
                self.button.backgroundColor = R.Color.BackgroundTertiary
                self.button.isUserInteractionEnabled = false
                UIView.makeToast(message: R.string.localizable.badIpAddress())
            }
        }
        textField.isFocusable = true
        textField.onFocusConfirm = { [weak self] in
            self?.ipAddressTitleTextField.becomeFirstResponder()
            return true
        }
        return textField
    }()
    
    private lazy var ipAddressInputView: UIView = {
        let view = UIView()
        view.layerCornerRadius = R.Size.CornerRadiusMedium
        view.backgroundColor = R.Color.BackgroundTertiary
        
        let iconView = UIImageView()
        iconView.contentMode = .center
        iconView.layerCornerRadius = 6
        iconView.image = UIImage(symbol: .globe, font: R.Font.Footnote(emphasis: true), color: R.Color.LabelPrimary.forceStyle(.dark))
        iconView.backgroundColor = R.Color.Red
        view.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.size.equalTo(R.Size.IconSizeLarge)
            make.centerY.equalToSuperview()
        }
        
        let titleLabel = UILabel()
        titleLabel.text = R.string.localizable.ipAddress()
        titleLabel.textColor = R.Color.LabelPrimary
        titleLabel.font = R.Font.Body(emphasis: true)
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
        }
        
        view.addSubview(ipAddressTitleTextField)
        ipAddressTitleTextField.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(R.Size.ContentSpaceSmall)
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
        }
        
        return view
    }()
    
    private lazy var button: SymbolButton = {
        let view = SymbolButton(image: nil, title: R.string.localizable.startTransfer(), titleFont: R.Font.Body2(), titleColor: R.Color.LabelSecondary, titleAlignment: .right, horizontalContian: true)
        view.backgroundColor = R.Color.BackgroundTertiary
        view.isUserInteractionEnabled = false
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            if let ipAddress = self.ipAddressTitleTextField.text?.parseIPv4String() {
                UIView.makeAlert(title: R.string.localizable.headsUp(),
                                 detail: R.string.localizable.articBaseHeadsUp(),
                                 confirmTitle: R.string.localizable.confirmTitle(), confirmAction: {
                    let realm = Database.realm
                    let gameHash = R.Strings.AzaharArticBaseGameID
                    if let game = realm.object(ofType: Game.self, forPrimaryKey: gameHash) {
                        try? realm.write {
                            realm.delete(game)
                        }
                    }
                    
                    //Choose 3DS Region
                    ChevronSheetView.show(icon: .symbolImage(R.image.language_iconSymbols()),
                                          title: R.string.localizable.platformSelectionTitle(),
                                          detail: R.string.localizable.chooseRegion(),
                                          stringOptions: R.Strings.ThreeDSHomeMenuRegions,
                                          completion: { index in
                        if let index {
                            let region = R.Strings.ThreeDSHomeMenuRegions[index]
                            self.didRegionChange?(region)
                            let regionOptions = R.Strings.ThreeDSConsoleLanguage.filter({ $0 != "Automatic" })
                            var regionValue = regionOptions.first!
                            if let index = R.Strings.ThreeDSHomeMenuRegions.firstIndex(where: { $0 == region }), index < regionOptions.count {
                                regionValue = regionOptions[index]
                            }
                            LibretroCore.sharedInstance().updateConfig(EmulationCore.Azahar.name, configs: ["citra_region_value": regionValue], reload: false)
                            let game = Game()
                            game.id = gameHash
                            game.name = ipAddress.ip + ":" + "\(ipAddress.port)"
                            game.fileExtension = "articbase"
                            game.gameType = ._3ds
                            game.importDate = Date()
                            game.defaultCore = 1
                            try? realm.write { realm.add(game) }
                            game.handleTapAction(forceQuick: true, in: self.hostingWindowScene)
                        }
                    })
                })
            } else {
                UIView.makeToast(message: R.string.localizable.badIpAddress())
            }
        }
        return view
    }()
    
    var didIPAddressChange: ((_ ipAddress: String)->Void)? = nil
    var didRegionChange: ((_ region: String)->Void)? = nil
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        containerView.layerCornerRadius = R.Size.CornerRadiusLarge
        containerView.backgroundColor = R.Color.BackgroundSecondary
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(descTextView)
        descTextView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        
        containerView.addSubview(ipAddressInputView)
        ipAddressInputView.snp.makeConstraints { make in
            make.top.equalTo(descTextView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        containerView.addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(ipAddressInputView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(R.Size.ItemHeightMedium)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(config: PretendoNetworkingConfig) {
        ipAddressTitleTextField.text = config.articBaseIpAddress
        if let _ = config.articBaseIpAddress?.parseIPv4String() {
            button.titleLabel.textColor = R.Color.LabelPrimary
            button.backgroundColor = R.Color.Main
            button.isUserInteractionEnabled = true
        } else {
            button.titleLabel.textColor = R.Color.LabelSecondary
            button.backgroundColor = R.Color.BackgroundTertiary
            button.isUserInteractionEnabled = false
        }
    }
}
