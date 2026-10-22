//
//  ASWebView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import WebKit
import MessageUI

class ASWebView: BaseView {
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(getNavigation())
        view.didTapClose = { [weak self] in
            guard let self else { return }
            self.hide()
        }
        view.didTapTools = { [weak self] index in
            guard let self else { return }
            if index == 0 {
                //home
                self.webView.loadURL(self.url)
            } else if index == 1 {
                //go back
                self.webView.goBack()
            } else if index == 2 {
                self.webView.reload()
            } else if index == 3 {
                //search
                LimitedTextInputView.show(title: R.string.localizable.readyEditCoverSearch(),
                                          detail: nil,
                                          text: nil,
                                          limitedType: .normal(maxTextSize: 2083),
                                          keyboadType: .URL) { [weak self] result in
                    guard let self else { return }
                    if let result = result as? String {
                        if self.isValidURL(result) {
                            //是URL则直接访问
                            self.webView.loadURLString(result)
                        } else {
                            //非URL则使用搜索引擎进行搜索
                            var searchUrl = "https://www.google.com/search?q=\(result)"
                            if Locale.prefersCN {
                                searchUrl = "https://www.baidu.com/s?wd=\(result)"
                            }
                            self.webView.loadURLString(searchUrl)
                        }
                    }
                }
            } else if index == 4 {
                //download
                DownloadManageView.show()
            }
        }
        return view
    }()
    
    private lazy var webView: WKWebView = {
        let view: WKWebView
        view = WKWebView(frame: CGRect.zero)
        view.navigationDelegate = self
        view.uiDelegate = self
        view.isOpaque = false
        view.backgroundColor = R.Color.BackgroundPrimary
        view.scrollView.backgroundColor = R.Color.BackgroundPrimary
        view.scrollView.contentInset = .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        if UIDevice.isPhoneDuo {
            view.scrollView.insetsLayoutMarginsFromSafeArea = false
            view.scrollView.contentInsetAdjustmentBehavior = .never
        }
        return view
    }()
    
    private let url: URL
    private let showClose: Bool
    private var downloadingUrls = [String: String]()
    
    private var beginDownloadNotification: Any? = nil
    private var stopDownloadNotification: Any? = nil
    
    private var hideCompletion: (() -> Void)? = nil
    
    deinit {
        webView.navigationDelegate = nil
        
        if let beginDownloadNotification = beginDownloadNotification {
            NotificationCenter.default.removeObserver(beginDownloadNotification)
        }
        if let stopDownloadNotification = stopDownloadNotification {
            NotificationCenter.default.removeObserver(stopDownloadNotification)
        }
    }
    
    required init?(parameters: Any...) {
        var searchGame: Game? = nil
        if let url = parameters.compactMap({ $0 as? URL }).first {
            self.url = url
        } else if let game = parameters.compactMap({ $0 as? Game }).first {
            self.url = R.URLs.MobyGames
            searchGame = game
        } else {
            return nil
        }
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)
        
        addSubview(navigationView)
        updateNavigationViewConstraints()
        
        addSubview(webView)
        webView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }
        
        if let searchGame {
            UIView.makeLoading()
            MobyGamesKit.getGameInfoUrl(game: searchGame) { [weak self] url in
                UIView.hideLoading()
                guard let self else { return }
                self.webView.loadURL(url)
            }
        } else {
            webView.loadURL(url)
        }
        
        beginDownloadNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.BeginDownload, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            self.navigationView.navigation = getNavigation()
        }
        
        stopDownloadNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.StopDownload, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            self.navigationView.navigation = getNavigation()
        }
    }
    
    convenience init(url: URL = R.URLs.ManicHome, showClose: Bool = true) {
        self.init(parameters: url, showClose)!
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if UIDevice.isPhoneDuo {
            updateNavigationViewConstraints()
        }
    }
    
    private func updateNavigationViewConstraints() {
        navigationView.snp.remakeConstraints { make in
            if UIDevice.isPhoneDuoOuter && UIDevice.currentOrientation == .landscapeRight {
                if let cameraArea = DuoLayoutKit.sideStrip()?.cameraArea() {
                    make.leading.equalToSuperview().inset(cameraArea.width - R.Size.ContentSpaceMedium)
                    make.top.equalToSuperview().offset((cameraArea.height - R.Size.NavigationHeight)/2)
                } else {
                    make.leading.equalToSuperview().inset(R.Size.iPhoneDuoOuterCameraEdge + R.Size.iPhoneDuoOuterCameraSize.width - R.Size.ContentSpaceMedium)
                    make.top.equalToSuperview().offset(R.Size.iPhoneDuoOuterCameraEdge)
                }
                make.trailing.equalToSuperview()
            } else {
                if UIDevice.isPhoneDuo {
                    make.leading.trailing.equalToSuperview()
                } else {
                    make.leading.trailing.equalTo(safeAreaLayoutGuide)
                }
                make.top.equalToSuperview().offset(showAsSheet ? R.Size.SheetGrabberTopInset : R.Size.ContentSpaceLarge)
            }
            make.height.equalTo(R.Size.NavigationHeight)
        }
    }
    
    private func isValidURL(_ string: String) -> Bool {
        let types: NSTextCheckingResult.CheckingType = .link
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return false }
        
        let range = NSRange(location: 0, length: string.utf16.count)
        let matches = detector.matches(in: string, options: [], range: range)
        
        // 确保整个字符串是链接而不是只包含链接的一部分
        return matches.contains { $0.range.length == string.utf16.count }
    }
    
    private func getNavigation() -> ASListPage.Navigation {
        var navigation = ASListPage.Navigation.defaultNavigation(tools: [
            .symbolImage(R.image.home_iconSymbols()),
            .symbol(.chevronLeft),
            .symbolImage(R.image.refresh_iconSymbols()),
            .symbolImage(R.image.searchRegular_iconSymbols()),
            .symbolImage(R.image.cloudDownload_iconSymbols(), animated: DownloadManager.shared.hasDownloadTask)
        ])
        navigation.enableClose = showClose
        return navigation
    }
}

extension ASWebView: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

extension ASWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.string.hasPrefix("mailto:") {
            if MFMailComposeViewController.canSendMail() {
                if url.string.hasSuffix("support@manicemu.site") {
                    //发送给Manic
                    let mailController = MFMailComposeViewController()
                    mailController.setToRecipients([R.Strings.SupportEmail])
                    mailController.mailComposeDelegate = self
                    topApplicationViewController()?.present(mailController, animated: true)
                } else {
                    let mailController = MFMailComposeViewController()
                    mailController.setToRecipients([url.string.replacingOccurrences(of: "mailto:", with: "")])
                    mailController.mailComposeDelegate = self
                    topApplicationViewController()?.present(mailController, animated: true)
                }
            } else {
                UIView.makeToast(message: R.string.localizable.noEmailSetting())
            }
            decisionHandler(.cancel)
            return
        }
        
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.canShowMIMEType {
            decisionHandler(.allow)
        } else {
            decisionHandler(.download)
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        UIView.makeLoading(timeout: R.Numbers.WebLoadingViewTimeout)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        UIView.hideLoading()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        Log.debug("WebView错误:\(error)")
        UIView.hideLoading()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        Log.debug("didFailProvisionalNavigation:\(error)")
        UIView.hideLoading()
    }
    
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
}

extension ASWebView: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
        if let downloadUrl = download.originalRequest?.url, !downloadUrl.string.lowercased().hasPrefix("blob") {
            UIView.makeToast(message: R.string.localizable.webViewDownloadBegin())
            DownloadManager.shared.downloads(urls: [downloadUrl], fileNames: [suggestedFilename])
        }
        completionHandler(nil)
    }
}

extension ASWebView: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: (any Error)?) {
        switch result {
        case .sent:
            UIView.makeToast(message: R.string.localizable.sendEmailSuccess())
            controller.dismiss(animated: true)
        case .failed:
            var errorMsg = ""
            if let error = error {
                errorMsg += "\n" + error.localizedDescription
            }
            UIView.makeToast(message: R.string.localizable.sendEmailFailed(errorMsg))
        default:
            controller.dismiss(animated: true)
        }
    
    }
}

extension ASWebView: ShowableView {
    
    static func show(url: URL,  showClose: Bool = true, hideCompletion: (() -> Void)? = nil) {
        Self.show(parameters: url, showClose)?.hideCompletion = hideCompletion
    }
    
    static func show(searchGame: Game) {
        Self.show(parameters: searchGame)
    }
    
    func dataForShow(_ defaultData: ASSheet) -> ASSheet {
        var sheetData = defaultData
        sheetData.fullScreenForLandscape = true
        return sheetData
    }
    
    func didHide() {
        hideCompletion?()
    }
    
}
