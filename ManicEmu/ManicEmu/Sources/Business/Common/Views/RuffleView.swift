//
//  RuffleView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/12.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import WebKit

class RuffleView: BaseView {
    /// Called once `window.ruffleAPI` is ready.
    var didFinishedInit: (() -> Void)? = nil

    var romPath: String? = nil

    private(set) var isPaused: Bool = false
    private var didNotifyReady = false

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()
        let proxy = WeakScriptMessageHandler(target: self)
        contentController.add(proxy, name: "console")
        contentController.add(proxy, name: "ruffle")
        configuration.userContentController = contentController

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = false
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.isOpaque = false
        view.backgroundColor = .black

        let consoleHookJS = """
        (function () {
            function wrap(type) {
                const original = console[type];
                console[type] = function () {
                    window.webkit.messageHandlers.console.postMessage({
                        type: type,
                        message: Array.from(arguments).join(' ')
                    });
                    original.apply(console, arguments);
                };
            }
            ['log', 'warn', 'error', 'info', 'debug'].forEach(wrap);
        })();
        """
        let script = WKUserScript(
            source: consoleHookJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        view.configuration.userContentController.addUserScript(script)
        return view
    }()

    private lazy var localServer: LocalWebServer = {
        let server = LocalWebServer()
        try? server.start(serverType: .Ruffle)
        return server
    }()

    deinit {
        localServer.stop()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        if let url = localServer.getURL() {
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RuffleView {
    /// Restore SharedObject dump (if any), then stream the SWF from the local server.
    func openFile(filePath: String, savePath: String?) {
        romPath = filePath
        let startLoad: () -> Void = { [weak self] in
            self?.loadSWF(filePath: filePath)
        }
        if let savePath, FileManager.default.fileExists(atPath: savePath) {
            loadSave(path: savePath, completion: startLoad)
        } else {
            startLoad()
        }
    }

    private func loadSWF(filePath: String) {
        let fileName = filePath.lastPathComponent.escapeJSString()
        let fileId = localServer.registerFile(filePath: filePath)
        let romURL = localServer.fileURL(for: fileId)
        let script = """
        (function() {
            if (window.ruffleAPI && window.ruffleAPI.openFileByUrlAndName) {
                window.ruffleAPI.openFileByUrlAndName('\(romURL)', '\(fileName)');
            }
        })();
        null;
        """
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                Log.debug("Ruffle openFile failed: \(error)")
            }
        }
    }

    func reset() {
        webView.evaluateJavaScript("if (window.ruffleAPI) window.ruffleAPI.reset();")
    }

    /// Dump localStorage (Ruffle SharedObject) to `path`.
    func save(to path: String, completion: ((_ isSuccess: Bool) -> Void)? = nil) {
        let script = """
        (function() {
            if (window.ruffleAPI && window.ruffleAPI.getSaveData) {
                return window.ruffleAPI.getSaveData();
            }
            return null;
        })();
        """
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                Log.debug("Ruffle getSaveData failed: \(error)")
                completion?(false)
                return
            }
            guard let json = result as? String, !json.isEmpty else {
                completion?(false)
                return
            }
            do {
                let url = URL(fileURLWithPath: path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try json.writeWithCompletePath(to: url)
                completion?(true)
            } catch {
                Log.debug("Ruffle save write failed: \(error)")
                completion?(false)
            }
        }
    }

    func loadSave(path: String, completion: (() -> Void)? = nil) {
        guard FileManager.default.fileExists(atPath: path),
              let json = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else {
            completion?()
            return
        }
        let escaped = json.escapeJSString()
        let script = "if (window.ruffleAPI) window.ruffleAPI.loadSaveData('\(escaped)');"
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                Log.debug("Ruffle loadSaveData failed: \(error)")
            }
            completion?()
        }
    }

    func pressButton(_ key: FLASHKey, pressed: Bool) {
        let work = { [weak self] in
            guard let self else { return }
            let code = key.rawValue.escapeJSString()
            let eventKey = key.eventKey.escapeJSString()
            let script = "if (window.ruffleAPI) window.ruffleAPI.pressKey('\(code)', '\(eventKey)', \(pressed), \(key.keyCode));"
            self.webView.evaluateJavaScript(script)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    func setMute(_ mute: Bool) {
        webView.evaluateJavaScript("if (window.ruffleAPI) window.ruffleAPI.setMute(\(mute));")
    }

    func snapShot() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: webView.bounds)
        return renderer.image { _ in
            webView.drawHierarchy(in: webView.bounds, afterScreenUpdates: true)
        }
    }

    func fastForward(speed: Float) {
        let clamped = max(0.25, min(8.0, Double(speed)))
        webView.evaluateJavaScript("if (window.ruffleAPI) window.ruffleAPI.setSpeed(\(clamped));")
    }

    func pause() {
        webView.evaluateJavaScript("if (window.ruffleAPI) window.ruffleAPI.pause();")
        isPaused = true
    }

    private func notifyReady() {
        guard !didNotifyReady else { return }
        didNotifyReady = true
        didFinishedInit?()
    }

    func resume() {
        webView.evaluateJavaScript("if (window.ruffleAPI) window.ruffleAPI.resume();")
        isPaused = false
    }
}

extension RuffleView: WKScriptMessageHandler {
    func decodeUnicodeString(_ str: String) -> String {
        let quoted = "\"\(str)\""
        guard let data = quoted.data(using: .utf8),
              let result = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? String else {
            return str
        }
        return result
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "console", let body = message.body as? [String: String] {
            let type = body["type"] ?? ""
            let text = decodeUnicodeString(body["message"] ?? "")
            Log.debug("JS: type=\(type) message=\(text)")
            return
        }

        guard message.name == "ruffle",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            return
        }

        switch type {
        case "ready":
            notifyReady()
        case "loadFailed":
            Log.debug("Ruffle load failed: \(body["message"] ?? "")")
        default:
            break
        }
    }
}

extension RuffleView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkInitStatus()
    }

    func checkInitStatus() {
        webView.evaluateJavaScript("typeof window.ruffleAPI !== 'undefined'") { [weak self] result, _ in
            guard let self else { return }
            if let isAvailable = result as? Bool, isAvailable {
                self.notifyReady()
            } else {
                DispatchQueue.main.asyncAfter(delay: 1) {
                    self.checkInitStatus()
                }
            }
        }
    }
}

extension RuffleView: WKUIDelegate {}
