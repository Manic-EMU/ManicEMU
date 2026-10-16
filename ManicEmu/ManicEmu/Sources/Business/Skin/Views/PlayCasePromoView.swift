//
//  PlayCasePromoView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/14.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class PlayCasePromoView: BaseView {
    private var hideCompletion: (() -> Void)? = nil
    
    required init?(parameters: Any...) {
        super.init(frame: .zero)
        
        let showDontShow = parameters.compactMap({ $0 as? Bool }).first ?? true
        
        let containerView = UIView()
        let logoView = IconView()
        logoView.image = R.image.playcase_logo()
        containerView.addSubview(logoView)
        logoView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(30)
        }
        
        let detailLabel = UILabel()
        detailLabel.numberOfLines = 0
        let style = NSMutableParagraphStyle()
        style.lineSpacing = R.Size.ContentSpaceTiny
        style.alignment = .left
        detailLabel.attributedText = NSAttributedString(string: R.string.localizable.playCasePromo(), attributes: [.font: R.Font.Body2(), .foregroundColor: R.Color.LabelPrimary, .paragraphStyle: style])
        containerView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            make.top.equalTo(logoView.snp.bottom).offset(R.Size.ContentSpaceSmall)
        }
        
        let button: SymbolButton = {
            let view = SymbolButton(image: nil, title: R.string.localizable.learnPlayCase(), titleFont: R.Font.Body(emphasis: true), titleColor: R.Color.LabelPrimary.forceStyle(.dark), horizontalContian: true, titlePosition: .right)
            view.enableRoundCorner = true
            view.backgroundColor = R.Color.Red
            view.addTapGesture { [weak self] gesture in
                guard let self else { return }
                self.hide()
                UIApplication.shared.open(R.URLs.PlayCasePromo)
            }
            return view
        }()
        
        containerView.addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            make.height.equalTo(R.Size.ItemHeightMedium)
            make.top.equalTo(detailLabel.snp.bottom).offset(R.Size.ItemHeightSmall)
            if !showDontShow {
                make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.ContentSpaceSmall)
            }
        }
        
        if showDontShow {
            let dontshowAgain: UIButton = {
                let view = UIButton(type: .custom)
                let att = NSAttributedString(string: R.string.localizable.dontshowAgain(), attributes: [.font: R.Font.Body(), .foregroundColor: R.Color.LabelSecondary])
                view.onTap { [weak self] in
                    guard let self else { return }
                    UserDefaults.standard.set(true, forKey: R.DefaultKey.HasShowPlayCasePromo)
                    self.hide()
                }
                view.setAttributedTitle(att.underlined, for: .normal)
                return view
            }()
            
            containerView.addSubview(dontshowAgain)
            dontshowAgain.snp.makeConstraints { make in
                make.centerX.equalTo(button)
                make.top.equalTo(button.snp.bottom).offset(R.Size.ContentSpaceTiny)
                make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.ContentSpaceSmall)
            }
        }
        
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PlayCasePromoView: ShowableView {
    static func show(showDontShow: Bool = true, hideCompletion: (()->Void)? = nil) {
        if let view = Self.show(parameters: showDontShow) {
            view.hideCompletion = hideCompletion
        }
    }
    
    func didHide() {
        hideCompletion?()
    }
    
    var prefferdConstraintHeight: CGFloat? {
        return nil
    }
}
