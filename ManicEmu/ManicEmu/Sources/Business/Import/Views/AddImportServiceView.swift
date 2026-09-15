//
//  AddImportServiceView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import CloudServiceKit
import RealmSwift

class AddImportServiceView: BaseView {
    
    private lazy var listPageView: ASListPageView = {
        var navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.addImportServiceHeaderTitle(),
                                                                 titleIcon: .symbol(.cloud))
        navigation.enableClose = false
        var sections = [ASListPage.Section]()
        sections.append(.init(cells: cloudServices.map({ ASListPage.Cell.iconTitleChevronCell(icon: .image($0.iconImage), title: $0.title) }),
                              header: .defaultHeader(title: R.string.localizable.importAddCloudServiceTitle()),
                              decoration: .init(style: .primary)))
        
        sections.append(.init(cells: LanServices.map({ ASListPage.Cell.iconTitleChevronCell(icon: .image($0.iconImage), title: $0.title) }),
                              header: .defaultHeader(title: R.string.localizable.importAddLanServiceTitle()),
                              decoration: .init(style: .primary)))
        
        let view = ASListPageView(.init(navigation: navigation,
                                        sections: sections,
                                        backgroundColor: .clear,
                                        pageInsets: .insets(top: R.Size.ContentInsetTop),
                                        enableSafeAreaLeftInsets: true,
                                        enableSafeAreaRightInsets: true))
        
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            if let indexPath = action.normalItemValue?.indexPath {
                if !PurchaseManager.isMember {
                    topViewController()?.present(PurchaseViewController(featuresType: .import), animated: true)
                    return
                }
                let service: ImportService
                if indexPath.section == 0 {
                    service = cloudServices[indexPath.row]
                    CloudDriveConnetor.shard.connect(service: service)
                } else if indexPath.section == 1 {
                    service = LanServices[indexPath.row]
                    LanServiceEditView.show(serviceType: service.type, successHandler: { [weak self] in
                        guard let self = self else { return }
                        self.requireToHideSideMenu?()
                    })
                }
            }
            
        }
        return view
    }()
    
    private var cloudServices: [ImportService] = {
        var services: [ImportService] = []
        services.append(ImportService.genService(type: .googledrive))
        services.append(ImportService.genService(type: .dropbox))
        services.append(ImportService.genService(type: .onedrive))
        services.append(ImportService.genService(type: .baiduyun))
        services.append(ImportService.genService(type: .aliyun))
        return services
    }()
    
    private var LanServices: [ImportService] = {
        var services: [ImportService] = []
        services.append(ImportService.genService(type: .webdav))
        services.append(ImportService.genService(type: .samba))
        services.append(ImportService.genService(type: .romm))
        return services
    }()
    
    var requireToHideSideMenu: (()->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


