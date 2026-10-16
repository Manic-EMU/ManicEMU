//
//  DownloadManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/26.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Tiercel
import ZipArchive

class DownloadManager {
    static let shared = DownloadManager()
    
    var hasDownloadTask: Bool {
        sessionManager.tasks.filter({ $0.status == .running }).count > 0
    }
    
    var didProgress: ((DownloadTask)->Void)? = nil
    var didSuccess: ((DownloadTask)->Void)? = nil
    var didFailure: ((DownloadTask)->Void)? = nil
    
    var sessionManager: SessionManager = {
        var config = SessionConfiguration()
        config.allowsCellularAccess = true
        let cache = Cache("DownloadManager", downloadPath: R.Path.DownloadWorkSpace)
        let manager = SessionManager(R.Config.AppIdentifier, configuration: config, cache: cache)
        let runningTasks = manager.tasks.filter({ $0.status == .running })
        if runningTasks.count > 0 {
            DispatchQueue.main.asyncAfter(delay: 0.35) {
                let fileNames = runningTasks.map({ $0.fileName }).reduce("") { $0 + ($0.isEmpty ? "" : "\n") + $1 }
                UIView.makeToast(message: R.string.localizable.importDownloadContinue(fileNames))
            }
        }
#if DEBUG
        manager.logger.option = .default
#endif
        manager.progress { manager in
            var text = ""
            text += "总任务：\(manager.succeededTasks.count)/\(manager.tasks.count)\n"
            text += "总速度：\(manager.speedString)\n"
            text += "剩余时间： \(manager.timeRemainingString)\n"
            let per = String(format: "%.2f", manager.progress.fractionCompleted)
            text += "总进度： \(per)\n"
            Log.debug("\(text)")
        }.failure { manager in
            let tasks = manager.tasks.filter { $0.status == .canceled || $0.status == .failed || $0.status == .removed }
            if tasks.count > 0 {
                let message = tasks.reduce("") { $0.isEmpty ? $1.fileName : $0 + "\n" + $1.fileName }
                UIView.makeToast(message: R.string.localizable.importDownloadError(message))
                //下载失败的直接移除
                tasks.forEach {
                    Log.debug("下载失败:\($0.fileName) 状态:\($0.status)")
                    manager.remove($0.url)
                }
            }
            if manager.tasks.filter({ $0.status == .running }).count == 0 {
                NotificationCenter.default.post(name: R.NotificationName.StopDownload, object: nil)
            }
        }.success { manager in
            Log.debug("下载完成")
            //全部下载完才统一导入
            UIView.makeToast(message: R.string.localizable.downloadCompletion())
            var succeededTasks = manager.succeededTasks
            
            let shaders = succeededTasks.filter({
                $0.filePath.lastPathComponent == R.Strings.SlangShader || $0.filePath.lastPathComponent == R.Strings.GLSLShader
            })
            if shaders.count > 0 {
                //处理RetroArch的shaders
                
                DispatchQueue.global().async {
                    for shader in shaders {
                        let desPath = shader.filePath.lastPathComponent == R.Strings.SlangShader ? R.Path.ShaderRetroArchSlang : R.Path.ShaderRetroArchGLSL
                        SSZipArchive.unzipFile(atPath: shader.filePath, toDestination: desPath, overwrite: true, password: nil, progressHandler: nil) { _, isSuccess, error in
                            DispatchQueue.main.async {
                                if isSuccess {
                                    NotificationCenter.default.post(name: R.NotificationName.RetroArchShadersDownloadSuccess, object: nil)
                                } else {
                                    UIView.makeToast(message: R.string.localizable.retroArchShaderUnzipFailed(shader.filePath.lastPathComponent))
                                }
                            }
                        }
                    }
                    shaders.forEach({ manager.remove($0.url) })
                }
                succeededTasks = succeededTasks.filter({
                    $0.filePath.lastPathComponent != R.Strings.SlangShader && $0.filePath.lastPathComponent != R.Strings.GLSLShader
                })
            }
            
            if succeededTasks.count > 0 {
                FilesImporter.importFiles(urls: succeededTasks.map({ URL(fileURLWithPath: $0.filePath) }), in: nil) {
                    succeededTasks.forEach { manager.remove($0.url) }
                }
            }
            
            NotificationCenter.default.post(name: R.NotificationName.StopDownload, object: nil)
        }
        return manager
    }()
    
    func downloads(urls: [URL], fileNames: [String], headers: [String: String]? = nil) {
        NotificationCenter.default.post(name: R.NotificationName.BeginDownload, object: nil)
        DispatchQueue.global().async {
            self.sessionManager.multiDownload(urls, headersArray: headers == nil ? nil : urls.map({ _ in headers! }), fileNames: fileNames)
//            for task in tasks {
//                task.progress { task in
//                    self.didProgress?(task)
//                }.success { task in
//                    self.didSuccess?(task)
//                }.failure { task in
//                    self.didFailure?(task)
//                }
//            }
        }
    }
}
