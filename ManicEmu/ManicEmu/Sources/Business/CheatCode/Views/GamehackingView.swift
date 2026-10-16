//
//  GamehackingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import WebKit

private enum GamehackingScript {
    static let handlerName = "gamehackingHandler"
    static let contentBlockerIdentifier = "GamehackingAdBlock"
    
    /// Reduce the CPU/GPU load on WebView.
    static let contentBlockerRules = """
    [
      {
        "trigger": {
          "url-filter": ".*",
          "if-domain": ["ezoic.net", "ezoic.com", "ezodn.com", "g.ezoic.net"]
        },
        "action": { "type": "block" }
      },
      {
        "trigger": {
          "url-filter": ".*",
          "if-domain": ["googletagmanager.com", "google-analytics.com", "googlesyndication.com", "doubleclick.net", "googleadservices.com"]
        },
        "action": { "type": "block" }
      },
      {
        "trigger": {
          "url-filter": ".*/detroitchicago/.*",
          "resource-type": ["script"]
        },
        "action": { "type": "block" }
      },
      {
        "trigger": {
          "url-filter": ".*/parsonsmaize/.*",
          "resource-type": ["script"]
        },
        "action": { "type": "block" }
      },
      {
        "trigger": {
          "url-filter": ".*/ezais/analytics.*"
        },
        "action": { "type": "block" }
      },
      {
        "trigger": {
          "url-filter": ".*/ezqlog.*"
        },
        "action": { "type": "block" }
      }
    ]
    """
    
    static let adBlockScript = """
    (function() {
        window.ezDisableAds = true;
        var style = document.createElement('style');
        style.textContent = '[id*="ezoic"], [class*="ezoic"], .ezoic-ad, iframe[src*="googlesyndication"], iframe[src*="doubleclick"] { display: none !important; visibility: hidden !important; height: 0 !important; max-height: 0 !important; overflow: hidden !important; pointer-events: none !important; }';
        (document.head || document.documentElement).appendChild(style);
    })();
    """
    
    static let hookScript = """
    (function() {
        if (window.__manicGamehackingHooked) return;
        window.__manicGamehackingHooked = true;
    
        function serializeExportForm() {
            var form = document.getElementById('exportCodes');
            if (!form) return null;
    
            var action = form.getAttribute('action') || '';
            if (action.indexOf('http') !== 0) {
                action = 'https://gamehacking.org' + action;
            }
    
            var fields = {};
            var elements = form.querySelectorAll('input, select, textarea');
            for (var i = 0; i < elements.length; i++) {
                var el = elements[i];
                if (!el.name || el.disabled) continue;
                if ((el.type === 'radio' || el.type === 'checkbox') && !el.checked) continue;
                var key = el.name;
                if (fields[key] !== undefined) {
                    if (!Array.isArray(fields[key])) {
                        fields[key] = [fields[key]];
                    }
                    fields[key].push(el.value);
                } else {
                    fields[key] = el.value;
                }
            }
            return { action: action, fields: fields };
        }
    
        function prepareExportFormForSafari() {
            if (typeof $ !== 'undefined') {
                $('#dlCodID').val($('.codID :checked').map(function() {
                    return $(this).val();
                }).get().join(','));
                $('#exportCodes input[name^="codMods"]').remove();
                $('input[name^="codMods"], select[name^="codMods"]').each(function() {
                    $('<input>').attr({
                        type: 'hidden',
                        name: $(this).attr('name'),
                        value: $(this).val()
                    }).appendTo('#exportCodes');
                });
                $('#dlDownload').val('true');
            }
            return serializeExportForm();
        }
    
        var originalPrepareExportForm = window.prepareExportForm;
        window.prepareExportForm = function(download) {
            if (download === 'true') {
                var data = prepareExportFormForSafari();
                if (data && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(handlerName)) {
                    window.webkit.messageHandlers.\(handlerName).postMessage({
                        type: 'download',
                        action: data.action,
                        fields: data.fields
                    });
                }
                return;
            }
            if (typeof originalPrepareExportForm === 'function') {
                originalPrepareExportForm(download);
            }
        };
    
        var exportForm = document.getElementById('exportCodes');
        if (exportForm) {
            exportForm.addEventListener('submit', function(event) {
                event.preventDefault();
                var data = prepareExportFormForSafari();
                if (data && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(handlerName)) {
                    window.webkit.messageHandlers.\(handlerName).postMessage({
                        type: 'download',
                        action: data.action,
                        fields: data.fields
                    });
                }
            }, true);
        }
    
        function reportSelectedCount() {
            if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.\(handlerName)) return;
            var count = document.querySelectorAll('input[type="checkbox"][name="codID[]"]:checked').length;
            window.webkit.messageHandlers.\(handlerName).postMessage({
                type: 'selectionChanged',
                count: count
            });
        }
    
        document.addEventListener('change', function(event) {
            var target = event.target;
            if (target && target.type === 'checkbox' && target.name === 'codID[]') {
                reportSelectedCount();
            }
        }, true);
    
        reportSelectedCount();
    })();
    """
    
    static let collectSelectedCheatsScript = """
    (function() {
        var cheats = [];
        var checkboxes = document.querySelectorAll('input[type="checkbox"][name="codID[]"]:checked');
        for (var i = 0; i < checkboxes.length; i++) {
            var checkbox = checkboxes[i];
            var row = checkbox.closest('tr');
            if (!row) continue;
    
            var label = row.querySelector('label[for="' + checkbox.id + '"]');
            var name = '';
            if (label) {
                var clone = label.cloneNode(true);
                var removable = clone.querySelectorAll('input, button');
                for (var j = 0; j < removable.length; j++) {
                    removable[j].remove();
                }
                name = clone.textContent.replace(/\\s+/g, ' ').trim();
            }
    
            var pre = row.querySelector('pre');
            var code = pre ? pre.textContent.trim() : '';
            if (name.length > 0 && code.length > 0) {
                cheats.push({ name: name, code: code });
            }
        }
        return cheats;
    })();
    """
}

class GamehackingView: BaseView {
    private static var cachedContentRuleList: WKContentRuleList?
    
    private let game: Game
    
    private var isOnGameDetailPage = false {
        didSet {
            saveButton.isHidden = !isOnGameDetailPage
            if !isOnGameDetailPage {
                updateSaveButtonTitle(selectedCount: 0)
            }
        }
    }
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation(tools: [
            .symbolImage(R.image.home_iconSymbols()),
            .symbol(.chevronLeft),
            .symbolImage(R.image.refresh_iconSymbols()),
            .symbol(.bookmark)
        ]))
        view.didTapClose = { [weak self] in
            guard let self else { return }
            self.hide()
        }
        view.didTapTools = { [weak self] index in
            guard let self else { return }
            if index == 0 {
                self.webView.loadURL(self.getUrl(useBookMark: false))
            } else if index == 1 {
                //go back
                self.webView.goBack()
            } else if index == 2 {
                //refresh
                self.webView.reload()
            } else if index == 3 {
                //book mark
                guard let urlString = self.webView.url?.string else { return }
                self.game.updateExtra(key: ExtraKey.gamehackingBookMark.rawValue, value: urlString)
                UIView.makeToast(message: R.string.localizable.addBookMarkSuccess())
            }
        }
        return view
    }()
    
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let dataStore = WKWebsiteDataStore.default()
        configuration.websiteDataStore = dataStore
        
        let contentController = WKUserContentController()
        let proxy = WeakScriptMessageHandler(target: self)
        contentController.add(proxy, name: GamehackingScript.handlerName)
        contentController.addUserScript(WKUserScript(
            source: GamehackingScript.adBlockScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        configuration.userContentController = contentController
        
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = false
        view.isOpaque = false
        view.backgroundColor = R.Color.BackgroundPrimary
        view.scrollView.contentInset = .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow) + R.Size.ButtonExtraLarge + R.Size.ContentSpaceLarge)
        
        return view
    }()
    
    private lazy var saveButton: ASButtonView = {
        let view = ASButtonView(.large(title: R.string.localizable.addSelectedCheatCodes(),
                                       titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                       titleAlignment: .center,
                                       background: R.Color.Main))
        view.enableFocusEffects = false
        view.isHidden = true
        view.didTapButton = { [weak self] in
            self?.collectSelectedCheatsAndSave()
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        guard let game = parameters.compactMap({ $0 as? Game }).first else { return nil }
        self.game = game
        super.init(frame: .zero)
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(webView)
        webView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }
        addSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            if UIDevice.isPad || (UIDevice.isPhone && proHUDLayoutStyle() == .landscape) {
                make.width.equalTo(R.Size.ButtonMaxWidth)
                make.centerX.equalToSuperview()
            } else {
                make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(R.Size.ContentSpaceHuge)
            }
            make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow))
            make.height.equalTo(R.Size.ButtonExtraLarge)
        }
        
        prepareContentBlockerAndLoadInitialPage()
    }
    
    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: GamehackingScript.handlerName)
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getUrl(useBookMark: Bool = true) -> URL {
        if useBookMark,
           let extra = game.getExtraString(key: ExtraKey.gamehackingBookMark.rawValue),
            let bookMark = URL(string: extra) {
            return bookMark
        }
        return R.URLs.GamehackingSearch(gameType: game.gameType, gameName: game.displayName) ?? R.URLs.Gamehacking
    }
    
    private static func isGameDetailPageURL(_ url: URL?) -> Bool {
        guard let url, url.host?.contains("gamehacking.org") == true else { return false }
        let path = url.path
        guard path.hasPrefix("/game/") else { return false }
        let gameID = path.dropFirst("/game/".count)
        guard !gameID.isEmpty, gameID.allSatisfy(\.isNumber) else { return false }
        return true
    }
    
    private func prepareContentBlockerAndLoadInitialPage() {
        UIView.makeLoading(timeout: 15)
        loadContentBlockerIfNeeded { [weak self] in
            guard let self else { return }
            self.webView.loadURL(self.getUrl())
        }
    }
    
    private var hasInstalledContentBlocker = false
    
    private func loadContentBlockerIfNeeded(completion: @escaping () -> Void) {
        if hasInstalledContentBlocker {
            completion()
            return
        }
        
        if let cachedContentRuleList = Self.cachedContentRuleList {
            webView.configuration.userContentController.add(cachedContentRuleList)
            hasInstalledContentBlocker = true
            completion()
            return
        }
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: GamehackingScript.contentBlockerIdentifier,
            encodedContentRuleList: GamehackingScript.contentBlockerRules
        ) { [weak self] list, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    Log.debug("GamehackingView content blocker compile failed: \(error)")
                }
                if let list, !self.hasInstalledContentBlocker {
                    Self.cachedContentRuleList = list
                    self.webView.configuration.userContentController.add(list)
                    self.hasInstalledContentBlocker = true
                }
                completion()
            }
        }
    }
    
    private func updateGameDetailPageState(for url: URL?) {
        isOnGameDetailPage = Self.isGameDetailPageURL(url)
    }
    
    private func injectGameDetailPageHookIfNeeded() {
        guard isOnGameDetailPage else { return }
        webView.evaluateJavaScript(GamehackingScript.hookScript)
    }
    
    private func collectSelectedCheatsAndSave() {
        guard isOnGameDetailPage else { return }
        guard let supportedCheatFormats = game.gameType.manicEmuCore?.supportedCheatFormats else { return }
        
        webView.evaluateJavaScript(GamehackingScript.collectSelectedCheatsScript) { [weak self] result, error in
            guard let self else { return }
            if let error {
                Log.debug("GamehackingView collect cheats failed: \(error)")
                UIView.makeToast(message: R.string.localizable.noCheatCodesSelection())
                return
            }
            
            guard let cheatDicts = result as? [[String: Any]] else {
                UIView.makeToast(message: R.string.localizable.noCheatCodesSelection())
                return
            }
            
            var gameCheats = [GameCheat]()
            for (index, dict) in cheatDicts.enumerated() {
                guard let name = dict["name"] as? String,
                      let code = dict["code"] as? String,
                      !name.isEmpty,
                      !code.isEmpty else { continue }
                let gameCheat = GameCheat()
                gameCheat.id += index
                gameCheat.name = name
                gameCheat.code = code
                gameCheats.append(gameCheat)
            }
            
            guard !gameCheats.isEmpty else {
                UIView.makeToast(message: R.string.localizable.noCheatCodesSelection())
                return
            }
            
            for gameCheat in gameCheats {
                if let result = AddCheatCodeView.checkCheat(cheatCode: gameCheat.code, supportedCheatFormats: Array(supportedCheatFormats)) {
                    gameCheat.code = result.formatString
                    gameCheat.type = result.cheatFormat.type.rawValue
                } else {
                    UIView.makeAlert(detail: R.string.localizable.notSupportCheatCodes() + ":\n\(gameCheat.name)\n\(gameCheat.code)",
                                     cancelTitle: R.string.localizable.confirmTitle())
                    return
                }
            }
            
            Game.change { _ in
                self.game.gameCheats.append(objectsIn: gameCheats)
            }
            
            self.hide()
        }
    }
    
    private func openDownloadInSafari(action: String, fields: [String: Any]) {
        if let url = webView.url {
            UIApplication.shared.open(url)
        }
    }
    
    private func updateSaveButtonTitle(selectedCount: Int) {
        var title = R.string.localizable.addSelectedCheatCodes()
        if selectedCount > 0 {
            title += " (\(selectedCount))"
        }
        saveButton.setTitleString(title)
    }
}

extension GamehackingView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if navigationAction.targetFrame?.isMainFrame != false {
            updateGameDetailPageState(for: url)
        }
        
        if Self.isGameDetailPageURL(webView.url),
           url.path.contains("sub.exportCodes.php") {
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        UIView.makeLoading(timeout: R.Numbers.WebLoadingViewTimeout)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        UIView.hideLoading()
        injectGameDetailPageHookIfNeeded()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        Log.debug("GamehackingView didFail: \(error)")
        UIView.hideLoading()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        Log.debug("GamehackingView didFailProvisionalNavigation: \(error)")
        UIView.hideLoading()
    }
}

extension GamehackingView: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }
}

extension GamehackingView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == GamehackingScript.handlerName,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        
        switch type {
        case "download":
            guard isOnGameDetailPage,
                  let action = body["action"] as? String,
                  let fields = body["fields"] as? [String: Any] else { return }
            openDownloadInSafari(action: action, fields: fields)
        case "selectionChanged":
            let count = body["count"] as? Int ?? 0
            updateSaveButtonTitle(selectedCount: count)
        default:
            break
        }
    }
}

extension GamehackingView: ShowableView {
    static func show(game: Game) {
        Self.show(parameters: game)
    }
    
    func dataForShow(_ defaultData: ASSheet) -> ASSheet {
        var sheetData = defaultData
        sheetData.overrideUserInterfaceStyle = .dark
        return sheetData
    }
}
