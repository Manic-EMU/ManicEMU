//
//  LanServiceEditView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/2.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import SMBClient
import WebDavKit

class LanServiceEditView: BaseView {
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
    
    private lazy var listPageView: ASListPageView = {
        let sections = editItems.map({
            var input = ASInput.large(placeholder: $0.placeholderString)
            input.keyboardType = $0.keyboardType
            input.returnKeyType = $0.returnKeyType
            return ASListPage.Section(cells: [.input(input)],
                                      header: .defaultHeader(title: $0.title),
                                      decoration: .init(style: .primary))
        })
        let view = ASListPageView(.init(navigation: .defaultNavigation(title: service.title, titleIcon: .image(service.iconImage)),
                                        sections: sections,
                                        bottom: getBottom(isValid: false),
                                        backgroundColor: .clear,
                                        pageInsets: .insets(top: R.Size.SheetGrabberTopInset)))
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            if let inputValue = action.inputValue {
                let index = inputValue.indexPath.section
                let item = self.editItems[index]
                
                switch inputValue.action {
                case .textChange(let text):
                    self.validateInput(item: item, string: text ?? "")
                    
                case .tapReturn(_):
                    let isLast = (index == editItems.count - 1)
                    let handleIndex = isLast ? index : index + 1
                    if let cell = self.listPageView.collectionView.cellForItem(at: IndexPath(row: 0, section: handleIndex)) as? ASListInputCollectionCell {
                        if isLast {
                            cell.resignFirstResponder()
                        } else {
                            cell.becomeFirstResponder()
                        }
                    }
                    
                default:
                    break
                }
            } else if action.isBottom {
                // Connect after the form validates.
                self.listPageView.collectionView.endEditing(true)
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
                    // Verify the SMB service is reachable.
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
                                    self.hide()
                                    self.successHandler?()
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
                                    self.hide()
                                    self.successHandler?()
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
                } else if self.service.type == .romm {
                    if let host = service.host, let scheme = service.scheme,
                       let client = RommClient(scheme: scheme,
                                               host: host,
                                               port: service.port,
                                               user: service.user,
                                               password: service.password,
                                               path: service.path) {
                        Task {
                            do {
                                _ = try await client.platforms()
                                handleServiceDetail()
                                ImportService.change { realm in
                                    realm.add(self.service)
                                }
                                await MainActor.run {
                                    self.hide()
                                    self.successHandler?()
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
            } else if let navigationValue = action.navigationValue, navigationValue.isTapClose {
                self.hide()
            }
        }
        
        return view
    }()
    
    private lazy var editItems: [EditItem] = [
        EditItem(title: R.string.localizable.landServiceEditServerName(),
                 placeholderString: R.string.localizable.landServiceEditServerNamePlaceholder(),
                 keyboardType: .default,
                 requiredField: false,
                 type: .title,
                 returnKeyType: .next),
        EditItem(title: R.string.localizable.landServiceEditHost(),
                 placeholderString: R.string.localizable.landServiceEditRequiredPlaceholder(),
                 keyboardType: .URL,
                 requiredField: true,
                 type: .url,
                 returnKeyType: .next),
        EditItem(title: R.string.localizable.landServiceEditUserName(),
                 placeholderString: R.string.localizable.landServiceEditOptionalPlaceholder(),
                 keyboardType: .default,
                 requiredField: false,
                 type: .user,
                 returnKeyType: .next),
        EditItem(title: R.string.localizable.landServiceEditPassword(),
                 placeholderString: service.type == .romm
                    ? R.string.localizable.rommPasswordOrApiKey()
                    : R.string.localizable.landServiceEditOptionalPlaceholder(),
                 keyboardType: .default,
                 requiredField: false,
                 type: .password,
                 returnKeyType: .done)
    ]
    private var service: ImportService
    private var inputUrl: String? = nil
    var successHandler: (()->Void)? = nil
    
    required init?(parameters: Any...) {
        guard let serviceType = parameters.compactMap({ $0 as? ImportServiceType }).first else { return nil }
        self.service = ImportService()
        self.service.type = serviceType
        if serviceType == .samba {
            service.port = 445
        }
        super.init(frame: .zero)
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
                                // Reject a non-smb scheme when one is provided.
                                isValid = false
                                break
                            }
                        } else if service.type == .webdav || service.type == .romm {
                            guard let scheme = components.scheme else {
                                // WebDAV and RomM require http or https.
                                isValid = false
                                break
                            }
                            if scheme.lowercased() != "http" && scheme.lowercased() != "https" {
                                isValid = false
                                break
                            }
                            if service.type == .romm, !Self.isLanIPv4Host(components.host) {
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
        listPageView.bottom = getBottom(isValid: isValid)
    }
    
    private func getBottom(isValid: Bool) -> ASButton {
        var button = ASButton.large(title: R.string.localizable.landServiceEditConnect(),
                                    titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                    titleAlignment: .center,
                                    background: R.Color.Main)
        var disableAttributes = button.allAttributes[.normal]!
        disableAttributes.background = R.Color.BackgroundSecondary
        disableAttributes.title?.attributes?.color = R.Color.LabelTertiary
        button.allAttributes[.disabled] = disableAttributes
        button.state = isValid ? .normal : .disabled
        return button
    }

    /// Temporary add-form gate: private IPv4 only. Hostnames and public IPs are rejected.
    private static func isLanIPv4Host(_ host: String) -> Bool {
        let folded = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if folded == "localhost" { return true }
        let parts = folded.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4,
              let b1 = UInt8(parts[0]), let b2 = UInt8(parts[1]),
              UInt8(parts[2]) != nil, UInt8(parts[3]) != nil else { return false }
        if b1 == 10 { return true }
        if b1 == 127 { return true }
        if b1 == 169 && b2 == 254 { return true }
        if b1 == 192 && b2 == 168 { return true }
        if b1 == 172 && (16...31).contains(b2) { return true }
        return false
    }
}

extension LanServiceEditView: ShowableView {
    static func show(serviceType: ImportServiceType, successHandler: (()->Void)? = nil) {
        Self.show(parameters: serviceType)?.successHandler = successHandler
    }
}
