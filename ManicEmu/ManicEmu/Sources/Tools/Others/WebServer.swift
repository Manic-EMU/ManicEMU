//
//  WebServer.swift
//  ManicEmu
//
//  Created by Max on 2025/1/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import GCDWebUploader

class WebServer: NSObject {
    static let shard = WebServer()
    private weak var scene: UIWindowScene? = nil
    
    var ipAddress: String {
        if let webServer = webServer, let serverURL = webServer.serverURL, let host = serverURL.host, let port = serverURL.port {
             return "\(host):\(port)"
        }
        return ""
    }
    
    var isRunning: Bool {
        if let webServer = webServer {
            return webServer.isRunning
        }
        return false
    }
    
    private override init(){}
    private var webServer: GCDWebUploader?
    
    func start(in scene: UIWindowScene?) {
        guard webServer == nil else { return }
        self.scene = scene
        webServer = GCDWebUploader(uploadDirectory: R.Path.UploadWorkSpace)
        webServer?.allowedFileExtensions = FileType.allSupportFileExtension()
        webServer?.delegate = self
        if FileManager.default.fileExists(atPath: R.Path.UploadWorkSpace) {
            try? FileManager.default.removeItem(atPath: R.Path.UploadWorkSpace)
        }
        try? FileManager.default.createDirectory(atPath: R.Path.UploadWorkSpace, withIntermediateDirectories: true)
        webServer?.start(withPort: 6969, bonjourName: nil)
    }
    
    func stop() {
        if let webServer = webServer {
            if webServer.isRunning {
                DispatchQueue.global().async { [weak self] in
                    guard let self = self else { return }
                    self.webServer?.stop()
                    self.webServer = nil
                }
            }
        }
    }
}

extension WebServer: GCDWebUploaderDelegate {
    func webUploader(_ uploader: GCDWebUploader, didUploadFileAtPath path: String) {
        FilesImporter.importFiles(urls: [URL(fileURLWithPath: path)], in: scene)
    }
}
