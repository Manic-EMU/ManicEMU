//
//  LanServiceEditViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/27.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import IQKeyboardManagerSwift
import SMBClient
import WebDavKit

class LanServiceEditViewController: BaseViewController {
    
    struct EditItem {
        enum EditType {
            case title, url, user, password
        }
        let title: String
        let placeholderString: String
        let keyboardType: UIKeyboardType
        let requiredField: Bool
        let type: EditType
        let returnKeyType: UIReturnKeyType
    }
    
    private var navigationBlurView: NavigationBlurView = {
        let view = NavigationBlurView()
        view.makeBlur()
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: LanServiceEditCollectionViewCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.contentInset = UIEdgeInsets(top: Constants.Size.ContentSpaceMax + Constants.Size.ItemHeightMid, left: 0, bottom: Constants.Size.ContentInsetBottom, right: 0)
        return view
    }()
    
    private lazy var confirmButton: HowToButton = {
        let view = HowToButton(title: R.string.localizable.landServiceEditConnect(), enableGlass: true) { [weak self] in
            guard let self = self else { return }
            //点击连接处理
            self.collectionView.endEditing(true)
            UIView.makeLoading()
            func handleServiceDetail() {
                if self.service.detail == nil {
                    var deltaiString = ""
                    if let host = self.service.host {
                        deltaiString += host
                    }
                    if let port = self.service.port {
                        deltaiString += ":\(port)"
                    }
                    if let path = self.service.path {
                        deltaiString += "/\(path)"
                    }
                    self.service.detail = deltaiString
                }
            }
            if self.service.type == .samba {
                //验证smaba服务是否可以连接
                if let host = self.service.host {
                    let client = SMBClient(host: host, port: self.service.port ?? 445)
                    Task {
                        do {
                            try await client.login(username: self.service.user, password: self.service.password)
                            try await client.logoff()
                            handleServiceDetail()
                            ImportService.change { realm in
                                realm.add(self.service)
                            }
                            
                            await MainActor.run {
                                self.dismiss(animated: true) {
                                    self.successHandler?()
                                }
                                UIView.hideLoading()
                                UIView.makeToast(message: R.string.localizable.addLandServiceSuccess(self.service.title))
                            }
                        } catch {
                            await MainActor.run {
                                UIView.hideLoading()
                                UIView.makeToast(message: R.string.localizable.addLandServiceFailed(self.service.title))
                            }
                        }
                    }
                } else {
                    UIView.hideLoading()
                    UIView.makeToast(message: R.string.localizable.errorUnknown())
                }
            } else if self.service.type == .webdav {
                if let host = service.host, let scheme = service.scheme {
                    var credential: URLCredential? = nil
                    if let user = service.user, let password = service.password {
                        credential = URLCredential(user: user, password: password, persistence: .permanent)
                    }
                    let webDAV = WebDAV(baseURL: scheme + "://" + host, port: service.port ?? (scheme == "http" ? 80 : 443), username: service.user, password: service.password, path: service.path)
                    Task {
                        do {
                            let _ = try await webDAV.listFiles(atPath: "/")
                            handleServiceDetail()
                            ImportService.change { realm in
                                realm.add(self.service)
                            }
                            await MainActor.run {
                                self.dismiss(animated: true) {
                                    self.successHandler?()
                                }
                                UIView.hideLoading()
                                UIView.makeToast(message: R.string.localizable.addLandServiceSuccess(self.service.title))
                            }
                        } catch {
                            await MainActor.run {
                                //发生错误
                                UIView.hideLoading()
                                UIView.makeToast(message: R.string.localizable.addLandServiceFailed(self.service.title))
                            }
                        }
                    }
                } else {
                    UIView.hideLoading()
                    UIView.makeToast(message: R.string.localizable.errorUnknown())
                }
            } else if self.service.type == .romm {
                if let host = service.host, let scheme = service.scheme,
                   let client = RommClient(scheme: scheme, host: host, port: service.port,
                                           user: service.user, password: service.password) {
                    Task {
                        do {
                            let _ = try await client.platforms()
                            handleServiceDetail()
                            ImportService.change { realm in
                                realm.add(self.service)
                            }
                            await MainActor.run {
                                self.dismiss(animated: true) {
                                    self.successHandler?()
                                }
                                UIView.hideLoading()
                                UIView.makeToast(message: R.string.localizable.addLandServiceSuccess(self.service.title))
                            }
                        } catch {
                            await MainActor.run {
                                UIView.hideLoading()
                                UIView.makeToast(message: R.string.localizable.addLandServiceFailed(self.service.title))
                            }
                        }
                    }
                } else {
                    UIView.hideLoading()
                    UIView.makeToast(message: R.string.localizable.errorUnknown())
                }
            }
        }
        return view
    }()
    
    private var editItems: [EditItem] = []
    
    private var service: ImportService
    
    private var inputUrl: String? = nil
    
    var successHandler: (()->Void)? = nil
    
    init(serviceType: ImportServiceType, successHandler: (()->Void)? = nil) {
        service = ImportService()
        service.type = serviceType
        if serviceType == .samba {
            service.port = 445
        }
        super.init(nibName: nil, bundle: nil)
        //禁止下滑关闭控制器
        isModalInPresentation = true
        self.successHandler = successHandler
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDatas()
        
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        view.addSubview(navigationBlurView)
        navigationBlurView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        
        
        navigationBlurView.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
            make.height.equalTo(Constants.Size.ItemHeightUltraTiny)
            make.centerY.equalToSuperview()
        }
        updateConfirmButton(enable: false)
        
        let headerTitleLabel = UILabel()
        headerTitleLabel.text = service.title
        headerTitleLabel.textColor = Constants.Color.LabelPrimary
        headerTitleLabel.font = Constants.Font.title(size: .s)
        navigationBlurView.addSubview(headerTitleLabel)
        headerTitleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        addCloseButton(makeConstraints:  { make in
            make.centerY.equalTo(headerTitleLabel)
            make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //启用IQKeyboardManager
        IQKeyboardManager.shared.isEnabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //禁用IQKeyboardManager
        IQKeyboardManager.shared.isEnabled = false
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
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(84)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: Constants.Size.ContentSpaceMid,
                                                            bottom: 0,
                                                            trailing: Constants.Size.ContentSpaceMid)
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = Constants.Size.ContentSpaceHuge
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            
            return section
        }
        return layout
    }
    
    private func setupDatas() {
        let title = EditItem(title: R.string.localizable.landServiceEditServerName(),
                             placeholderString: R.string.localizable.landServiceEditServerNamePlaceholder(),
                             keyboardType: .default,
                             requiredField: false,
                             type: .title,
                             returnKeyType: .next)
        let url = EditItem(title: R.string.localizable.landServiceEditHost(),
                           placeholderString: R.string.localizable.landServiceEditRequiredPlaceholder(),
                           keyboardType: .URL,
                           requiredField: true,
                           type: .url,
                           returnKeyType: .next)
        let user = EditItem(title: R.string.localizable.landServiceEditUserName(),
                            placeholderString: R.string.localizable.landServiceEditOptionalPlaceholder(),
                            keyboardType: .default,
                            requiredField: false,
                            type: .user,
                            returnKeyType: .next)
        let password = EditItem(title: R.string.localizable.landServiceEditPassword(),
                                placeholderString: R.string.localizable.landServiceEditOptionalPlaceholder(),
                                keyboardType: .default,
                                requiredField: false,
                                type: .password,
                                returnKeyType: .done)
        editItems.append(contentsOf: [title, url, user, password])
    }
    
    private func updateConfirmButton(enable: Bool) {
        if enable {
            confirmButton.backgroundColor = Constants.Color.Main
            confirmButton.label.textColor = Constants.Color.LabelPrimary
            confirmButton.isUserInteractionEnabled = true
        } else {
            confirmButton.backgroundColor = Constants.Color.BackgroundSecondary
            confirmButton.label.textColor = Constants.Color.LabelSecondary
            confirmButton.isUserInteractionEnabled = false
        }
    }
    
    private func validateInput(item: EditItem, string: String) {
        switch item.type {
        case .title:
            service.detail = string
        case .url:
            inputUrl = string
        case .user:
            service.user = string
        case .password:
            service.password = string
        }
        var isValid = true
        for editItem in editItems {
            if editItem.requiredField {
                switch editItem.type {
                case .title:
                    if service.detail?.isEmpty ?? true {
                        isValid = false
                        break
                    }
                case .url:
                    if let components = inputUrl?.validateAndExtractURLComponents {
                        if service.type == .samba {
                            if let scheme = components.scheme, scheme.lowercased() != "smb" {
                                //如果填写了scheme，但不是smb就不行
                                isValid = false
                                break
                            }
                        } else if service.type == .webdav || service.type == .romm {
                            guard let scheme = components.scheme else {
                                //webdav的scheme必须存在
                                isValid = false
                                break
                            }
                            if scheme.lowercased() != "http" && scheme.lowercased() != "https" {
                                //webdav的scheme必须是http或https
                                isValid = false
                                break
                            }
                        }
                        service.scheme = components.scheme
                        service.host = components.host
                        service.port = components.port
                        service.path = components.path
                    } else {
                        isValid = false
                        break
                    }
                case .user:
                    if service.user?.isEmpty ?? true {
                        isValid = false
                        break
                    }
                case .password:
                    if service.password?.isEmpty ?? true {
                        isValid = false
                        break
                    }
                }
            }
        }
        updateConfirmButton(enable: isValid)
    }
}

extension LanServiceEditViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        editItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: LanServiceEditCollectionViewCell.self, for: indexPath)
        let item =  editItems[indexPath.row]
        cell.setData(item:item)
        cell.shouldGoNext = { [weak self] in
            guard let self = self else { return }
            if let cell = self.collectionView.cellForItem(at: IndexPath(row: indexPath.row + 1, section: indexPath.section)) as? LanServiceEditCollectionViewCell {
                cell.editTextField.becomeFirstResponder()
            }
        }
        cell.editTextField.onChange { [weak self] string in
            guard let self = self else { return }
            self.validateInput(item: item, string: string)
        }
        return cell
    }
}

extension LanServiceEditViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
}
