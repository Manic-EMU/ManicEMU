//
//  PSPNetworkingConfigOnlineView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class PSPNetworkingConfigOnlineView: BaseView {
    private lazy var ipAddressTitleTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = R.Color.LabelSecondary
        textField.font = R.Font.Footnote()
        textField.attributedPlaceholder = NSAttributedString(string: "socom.cc",
                                                             attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.LabelTertiary])
        textField.clearButtonMode = .never
        textField.returnKeyType = .done
        textField.textAlignment = .right
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
        }
        textField.onChange { [weak textField] text in
            
        }
        textField.didEndEditing { [weak self] in
            guard let self else { return }
            self.didConnectedHostChange?(self.ipAddressTitleTextField.text)
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
        titleLabel.text = R.string.localizable.serverAddress()
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
            make.centerY.equalToSuperview()
        }
        
        let chevronIconView = ASButtonView(.smallIconButton(icon: .symbol(.ellipsisCircle, colors: [R.Color.LabelPrimary]),
                                                            background: .clear,
                                                            insets: .init(inset: R.Size.ContentSpaceExtraExtraSmall)))
        chevronIconView.didTapButton = { [weak self] in
            guard let self else { return }
            var servers = ["socom.cc", "psp.gameplayer.club", "myneighborsushicat.com", R.string.localizable.custom()]
            ChevronSheetView.show(stringOptions: servers, completion: { [weak self] index in
                guard let self, let index else { return }
                if index == 3 {
                    self.ipAddressTitleTextField.becomeFirstResponder()
                } else {
                    let server = servers[index]
                    self.ipAddressTitleTextField.resignFirstResponder()
                    self.ipAddressTitleTextField.text = server
                    self.didConnectedHostChange?(server)
                }
                
            })
        }
        
        view.addSubview(chevronIconView)
        chevronIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(ipAddressTitleTextField.snp.trailing)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceExtraSmall)
        }
        
        return view
    }()
    
    var didConnectedHostChange: ((String?)->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(ipAddressInputView)
        ipAddressInputView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
    }
    
    func setData(config: PSPNetworkingConfig) {
        guard config.type == .online else { return }
        ipAddressTitleTextField.text = config.connectedHost
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
