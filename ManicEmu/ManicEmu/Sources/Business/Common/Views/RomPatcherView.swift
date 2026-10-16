//
//  RomPatcherView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/1/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import WebKit

class RomPatcherView: BaseView {
    
    private static func resolvedThemeCSS() -> String {
        let traits = UITraitCollection(userInterfaceStyle: UIDevice.isDarkMode ? .dark : .light)
        func hex(_ color: UIColor) -> String {
            color.resolvedColor(with: traits).hexString
        }
        return """
        :root {
            --bg-primary: \(hex(R.Color.BackgroundPrimary));
            --bg-secondary: \(hex(R.Color.BackgroundSecondary));
            --bg-tertiary: \(hex(R.Color.BackgroundTertiary));
            --bg-quaternary: \(hex(R.Color.BackgroundQuaternary));
            --label1: \(hex(R.Color.LabelPrimary));
            --label2: \(hex(R.Color.LabelSecondary));
            --red: \(hex(R.Color.Red));
            --background1: var(--bg-primary);
            --background2: var(--bg-secondary);
            --interactive-bg: var(--bg-tertiary);
            --segment-bg: var(--bg-secondary);
            --segment-selected-bg: var(--bg-tertiary);
        }
        html, body, #column {
            background-color: var(--bg-primary) !important;
        }
        .tab {
            background-color: var(--bg-secondary) !important;
        }
        #bottom-action-bar {
            background-color: var(--bg-primary) !important;
        }
        """
    }
    
    private lazy var navigationView: ASNavigationView = {
        var navigation = ASListPage.Navigation.defaultNavigation(title: "RomPatcher",
                                                                 titleIcon: .image(R.image.rompatcher_logo()))
        let view = ASNavigationView(navigation)
        view.didTapClose = { [weak self] in
            guard let self = self else { return }
            self.hide()
        }
        return view
    }()
    
    private lazy var webView: WKWebView = {
        let view: WKWebView
        let js = """
        (function() {
            'use strict';
            var originalCreateObjectURL = URL.createObjectURL;
            var romFileName = '';
            var patchFileName = '';
            var originalFileName = '';
            var modifiedFileName = '';
            var patchFileExtension = 'ips';
            var mode = 'patch';
            var hooksReady = false;

            function bindOnce(element, eventName, handler) {
                if (!element || element.dataset.manicBound === '1') {
                    return;
                }
                element.dataset.manicBound = '1';
                element.addEventListener(eventName, handler);
            }

            function setupHooks() {
                if (hooksReady) {
                    return;
                }
                var romInput = document.getElementById('rom-patcher-input-file-rom');
                if (!romInput) {
                    return;
                }
                hooksReady = true;

                romInput.removeAttribute('accept');
                bindOnce(romInput, 'change', function(e) {
                    if (e.target.files && e.target.files[0]) {
                        romFileName = e.target.files[0].name;
                    }
                });

                var patchInput = document.getElementById('rom-patcher-input-file-patch');
                if (patchInput) {
                    patchInput.removeAttribute('accept');
                    bindOnce(patchInput, 'change', function(e) {
                        if (e.target.files && e.target.files[0]) {
                            patchFileName = e.target.files[0].name;
                        }
                    });
                }

                var originalInput = document.getElementById('patch-builder-input-file-original');
                if (originalInput) {
                    originalInput.removeAttribute('accept');
                    bindOnce(originalInput, 'change', function(e) {
                        if (e.target.files && e.target.files[0]) {
                            originalFileName = e.target.files[0].name;
                        }
                    });
                }

                var modifiedInput = document.getElementById('patch-builder-input-file-modified');
                if (modifiedInput) {
                    modifiedInput.removeAttribute('accept');
                    bindOnce(modifiedInput, 'change', function(e) {
                        if (e.target.files && e.target.files[0]) {
                            modifiedFileName = e.target.files[0].name;
                        }
                    });
                }

                var patchTypeSelect = document.getElementById('patch-builder-select-patch-type');
                if (patchTypeSelect) {
                    bindOnce(patchTypeSelect, 'change', function(e) {
                        patchFileExtension = e.target.value;
                    });
                }

                var switchContainer = document.getElementById('switch-create-button');
                if (switchContainer) {
                    bindOnce(switchContainer, 'click', function(e) {
                        var btn = e.target.closest('.mode-segment');
                        if (!btn) {
                            return;
                        }
                        mode = btn.dataset.mode;
                    });
                }
            }

            function generatePatchedFileName(romName, patchName) {
                if (!romName) {
                    return 'patched_rom.bin';
                }

                var nameWithoutExt = romName.replace(/\\.[^/.]+$/, '');
                var romExt = romName.split('.').pop() || 'bin';
                var patchInfo = '';
                if (patchName) {
                    var patchWithoutExt = patchName.replace(/\\.[^/.]+$/, '');
                    if (!nameWithoutExt.toLowerCase().includes(patchWithoutExt.toLowerCase())) {
                        patchInfo = '_' + patchWithoutExt;
                    }
                }

                return nameWithoutExt + patchInfo + '_patched.' + romExt;
            }

            URL.createObjectURL = function(blob) {
                var downloadFileName = generatePatchedFileName(romFileName, patchFileName);
                var reader = new FileReader();
                reader.onload = function(e) {
                    window.webkit.messageHandlers.downloadHandler.postMessage({
                        type: 'blob_download',
                        data: e.target.result,
                        size: blob.size,
                        mimeType: blob.type,
                        fileName: downloadFileName,
                        romFileName: romFileName,
                        patchFileName: patchFileName,
                        originalFileName: originalFileName,
                        modifiedFileName: modifiedFileName,
                        patchFileExtension: patchFileExtension,
                        mode: mode
                    });
                };
                reader.readAsDataURL(blob);
                return originalCreateObjectURL.call(this, blob);
            };

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', setupHooks);
            } else {
                setupHooks();
            }
        })();
        """
        
        
        let userContentController = WKUserContentController()
        let proxy = WeakScriptMessageHandler(target: self)
        let themeCSS = Self.resolvedThemeCSS()
        let themeScriptSource = """
        (function() {
            var style = document.createElement('style');
            style.id = 'manic-rompatcher-theme';
            style.textContent = `\(themeCSS)`;
            (document.head || document.documentElement).appendChild(style);
        })();
        """
        let themeScript = WKUserScript(source: themeScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(themeScript)
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(script)
        userContentController.add(proxy, name: "downloadHandler")
        
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        
        view = WKWebView(frame: CGRect.zero, configuration: config)
        view.navigationDelegate = self
        view.isOpaque = false
        view.backgroundColor = R.Color.BackgroundPrimary
        view.scrollView.backgroundColor = R.Color.BackgroundPrimary
        view.scrollView.contentInset = .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow))
        
        return view
    }()
    
    private lazy var localServer: LocalWebServer = {
        let server = LocalWebServer()
        try? server.start(serverType: .RomPatcher)
        return server
    }()
    
    deinit {
        webView.navigationDelegate = nil
        localServer.stop()
    }
    
    required init?(parameters: Any...) {
        super.init(frame: .zero)
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(webView)
        webView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationView.snp.bottom)
            make.bottom.equalToSuperview()
        }
        if let url = localServer.getURL() {
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension RomPatcherView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           let host = url.host,
           host != "127.0.0.1",
           host != "localhost" {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}

extension RomPatcherView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "downloadHandler" {
            if let messageDict = message.body as? [String: Any] {
                if let type = messageDict["type"] as? String {
                    switch type {
                    case "blob_download":
                        handleBlobDownload(messageDict)
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func handleBlobDownload(_ messageDict: [String: Any]) {
        guard let base64Data = messageDict["data"] as? String,
              let size = messageDict["size"] as? Int else {
            Log.debug("无效的blob下载数据")
            return
        }
        
        Log.debug("接收到blob下载，大小: \(size) bytes")
        
        // 移除data:前缀并解码base64
        guard let commaRange = base64Data.range(of: ","),
              let data = Data(base64Encoded: String(base64Data[commaRange.upperBound...])) else {
            Log.debug("base64数据解码失败")
            return
        }
        
        let mode = messageDict["mode"] as? String ?? "patch"
        if mode == "patch" {
            // 从JS获取生成的文件名
            let romFileName = messageDict["romFileName"] as? String ?? ""
            let patchFileName = messageDict["patchFileName"] as? String ?? ""
            // 保存文件
            saveDownloadedFile(data: data, fileName: romFileName.deletingPathExtension + " (\(patchFileName.deletingPathExtension))." + romFileName.pathExtension, isPatch: false)
        } else {
            // 从JS获取生成的文件名
            let patchFileExtension = messageDict["patchFileExtension"] as? String ?? "ips"
            var patchFileName = messageDict["modifiedFileName"] as? String ?? messageDict["originalFileName"] as? String ?? "\(Date.now.timeIntervalSince1970)"
            patchFileName = patchFileName.deletingPathExtension + ".\(patchFileExtension)"
            // 保存文件
            saveDownloadedFile(data: data, fileName: patchFileName, isPatch: true)
        }
        
        
    }
    
    private func saveDownloadedFile(data: Data, fileName: String, isPatch: Bool) {
        let fileUrl = URL(fileURLWithPath: R.Path.Cache.appendingPathComponent(fileName))
        
        
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            try? FileManager.default.removeItem(at: fileUrl)
        }
        
        do {
            try data.writeWithCompletePath(to: fileUrl)
            DispatchQueue.main.async {
                UIView.makeAlert(title: R.string.localizable.downloadCompletion(), detail: fileName, cancelTitle: R.string.localizable.gamesShareRom(), confirmTitle: isPatch ? nil : R.string.localizable.m3uFileImport(), cancelAction: {
                    //分享
                    ShareManager.shareFile(fileUrl: fileUrl, in: self.hostingWindowScene)
                }, confirmAction: {
                    //导入
                    FilesImporter.importFiles(urls: [fileUrl], in: self.hostingWindowScene)
                })
            }
        } catch {
            DispatchQueue.main.async {
                UIView.makeToast(message: "文件保存失败: \(error.localizedDescription)")
            }
            Log.debug("文件保存失败: \(error)")
        }
    }
}

extension RomPatcherView: ShowableView {
    
}
