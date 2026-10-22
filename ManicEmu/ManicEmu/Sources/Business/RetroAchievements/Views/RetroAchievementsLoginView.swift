//
//  RetroAchievementsLoginView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class RetroLoginFooterReusableView: UICollectionReusableView {
    let button: SymbolButton = {
        let view = SymbolButton(image: nil, title: "", titleFont: R.Font.Body(emphasis: true), titleColor: R.Color.LabelPrimary.forceStyle(.dark), horizontalContian: true, titlePosition: .right)
        view.enableRoundCorner = true
        view.backgroundColor = R.Color.Red
        return view
    }()
    
    let register: UIButton = {
        let view = UIButton(type: .custom)
        let att = NSAttributedString(string: R.string.localizable.achievementsRegisterTitle(), attributes: [.font: R.Font.Body(), .foregroundColor: R.Color.LabelSecondary])
        view.isFocusable = true
        view.onTap {
            UIApplication.shared.open(R.URLs.RetroSignUp)
        }
        view.setAttributedTitle(att.underlined, for: .normal)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            make.height.equalTo(R.Size.ItemHeightMedium)
            make.top.equalToSuperview().offset(R.Size.ItemHeightSmall)
        }
        
        let labelContainer = UIView()
        addSubview(labelContainer)
        labelContainer.snp.makeConstraints { make in
            make.top.equalTo(button.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.centerX.equalToSuperview()
        }
        
        let notMemberLabel = UILabel()
        notMemberLabel.text = R.string.localizable.achievementsNotMember()
        notMemberLabel.font = R.Font.Body()
        notMemberLabel.textColor = R.Color.LabelSecondary
        
        labelContainer.addSubviews([notMemberLabel, register])
        register.snp.makeConstraints { make in
            make.leading.equalTo(notMemberLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.top.bottom.trailing.equalToSuperview()
        }
        notMemberLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalTo(register)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class RetroAchievementsLoginView: BaseView {
    private var editItems: [LanServiceEditView.EditItem] = []
    private var username: String? = nil
    private var password: String? = nil
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: TitleInputCollectionViewCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: RetroLoginFooterReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(top: 90,
                                    bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        if UIDevice.isPhoneDuo {
            view.contentInsetAdjustmentBehavior = .never
            view.insetsLayoutMarginsFromSafeArea = false
        }
        return view
    }()
    
    private weak var button: SymbolButton? = nil
    
    var loginSuccess: (()->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let user = LanServiceEditView.EditItem(title: R.string.localizable.landServiceEditUserName(),
                                               placeholderString: "",
                                               keyboardType: .default,
                                               requiredField: false,
                                               type: .user,
                                               returnKeyType: .next)
        let password = LanServiceEditView.EditItem(title: R.string.localizable.landServiceEditPassword(),
                                                   placeholderString: "",
                                                   keyboardType: .default,
                                                   requiredField: false,
                                                   type: .password,
                                                   returnKeyType: .done)
        editItems.append(contentsOf: [user, password])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.contentInsetsReference = UIDevice.isPhoneDuo ? .none : .safeArea
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(TitleInputCollectionViewCell.CellHeight)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                          leading: R.Size.ContentSpaceMedium,
                                                          bottom: 0,
                                                          trailing: R.Size.ContentSpaceMedium)
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = R.Size.ContentSpaceHuge
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            
            let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                            heightDimension: .absolute(130)),
                                                                         elementKind: UICollectionView.elementKindSectionFooter,
                                                                         alignment: .bottom)
            section.boundarySupplementaryItems.append(footerItem)
            
            return section
        }, configuration: configuration)
        return layout
    }
    
    private func updateButton() {
        guard let button else { return }
        if let username = self.username, !username.trimmed.isEmpty, let password = self.password, !password.isEmpty {
            button.backgroundColor = R.Color.Main
            button.titleLabel.textColor = R.Color.LabelPrimary.forceStyle(.dark)
            button.isUserInteractionEnabled = true
        } else {
            button.backgroundColor = R.Color.BackgroundTertiary
            button.titleLabel.textColor = R.Color.LabelSecondary
            button.isUserInteractionEnabled = false
        }
    }
}

extension RetroAchievementsLoginView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        editItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: TitleInputCollectionViewCell.self, for: indexPath)
        let item =  editItems[indexPath.row]
        var input = cell.editTextField.input
        input.isSecureTextEntry = item.type == .password
        cell.editTextField.input = input
        cell.setData(title: item.title,
                     placeholder: item.placeholderString,
                     keyboardType: item.keyboardType,
                     returnKeyType: item.returnKeyType)
        cell.shouldGoNext = { [weak self] in
            guard let self = self else { return }
            if let cell = self.collectionView.cellForItem(at: IndexPath(row: indexPath.row + 1, section: indexPath.section)) as? TitleInputCollectionViewCell {
                cell.editTextField.becomeFirstResponder()
            }
        }
        cell.editTextField.didInputChange = { [weak self] string in
            guard let self = self else { return }
            if item.type == .user {
                self.username = string
            } else if item.type == .password {
                self.password = string
            }
            self.updateButton()
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: RetroLoginFooterReusableView.self, for: indexPath)
        footer.button.titleLabel.text = R.string.localizable.achievementsLoginTitle()
        button = footer.button
        updateButton()
        footer.button.addTapGesture { [weak self] gesture in
            guard let self else { return }
            guard let username = self.username, !username.isEmpty, let password = self.password, !password.isEmpty else {
                return
            }
            UIView.makeLoading()
            CheevosBridge.loginCheevos(username, password: password) { [weak self] result, user in
                UIView.hideLoading()
                /**
                 const char* display_name; Daiuno
                 const char* username; Daiuno
                 const char* token; YNdH4yRapojs0moo
                 uint32_t score; 4
                 uint32_t score_softcore; 0
                 uint32_t num_unread_messages; 0
                 */
                if let _ = user {
                    self?.loginSuccess?()
                } else {
                    if result == LoginResult.invalid ||  result == LoginResult.expired {
                        UIView.makeToast(message: R.string.localizable.achievementsLoginFail())
                    } else if result == LoginResult.denied {
                        UIView.makeToast(message: R.string.localizable.achievementsLoginDenied())
                    } else if result == LoginResult.serverError {
                        UIView.makeToast(message: R.string.localizable.achievementsServerError())
                    } else if result == LoginResult.unknown {
                        UIView.makeToast(message: R.string.localizable.errorUnknown())
                    }
                }
            }
        }
        return footer
    }
}

extension RetroAchievementsLoginView: UICollectionViewDelegate {
    
}
