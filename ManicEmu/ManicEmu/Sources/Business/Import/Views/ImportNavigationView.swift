//
//  ImportNavigationView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/23.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ImportNavigationView: BaseView {
    private var appTitle: ASIconView = {
        let view = ASIconView(.image(R.image.app_title()!))
        return view
    }()
    
    var addServiceButton: ASButtonView = {
        let view = ASButtonView(.iconOnlyWithSmallSize(icon: .symbolImage(R.image.addRegular_iconSymbols())).enableGlass(true))
        return view
    }()
    
    lazy var toolsView: ASSymbolsButtonView = {
        let view = ASSymbolsButtonView(icons: getTools())
        view.containerInsets = .init(inset: R.Size.ContentSpaceTiny)
        return view
    }()
    
    private var beginDownloadNotification: Any? = nil
    private var stopDownloadNotification: Any? = nil
    
    deinit {
        if let beginDownloadNotification = beginDownloadNotification {
            NotificationCenter.default.removeObserver(beginDownloadNotification)
        }
        if let stopDownloadNotification = stopDownloadNotification {
            NotificationCenter.default.removeObserver(stopDownloadNotification)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubviews([addServiceButton, toolsView])
        
        addServiceButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceLarge)
            make.centerY.equalToSuperview()
        }
        
        if UIDevice.isPad {
            addServiceButton.isHidden = true
        }
        
        toolsView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceLarge)
            make.centerY.equalToSuperview()
            make.height.equalTo(R.Size.ButtonSmall)
        }
        
        beginDownloadNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.BeginDownload, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            self.updateToolsView()
        }
        
        stopDownloadNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.StopDownload, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            self.updateToolsView()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateToolsView() {
        toolsView.icons = getTools()
    }
    
    private func getTools() -> [ASIcon] {
        return [
            .symbolImage(R.image.cloudDownload_iconSymbols(), animated: DownloadManager.shared.hasDownloadTask),
            .symbolImage(R.image.faq_iconSymbols()),
            .symbolImage(R.image.ellipsis_iconSymbols())
        ]
    }
}
