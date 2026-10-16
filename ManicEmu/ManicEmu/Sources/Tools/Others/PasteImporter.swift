//
//  PasteImporter.swift
//  ManicEmu
//
//  Created by Max on 2025/1/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UniformTypeIdentifiers

struct PasteImporter {
    static func paste(supportedTypes: [UTType] = UTType.allInfoPlistTypes,
                      in scene: UIWindowScene?) {
        UIView.makeLoading()
        DispatchQueue.global().async {
            var errors: [ImportError] = []
            var urls: [URL] = []
            let pasteboard = UIPasteboard.general
            let items = pasteboard.items
            
            //系统可能会弹窗 导致一些UI问题，这里延迟500ms
            Thread.sleep(forTimeInterval: 0.5)
            
            for item in items {
                if let fileURLData = item["public.file-url"] as? Data,
                   let fileURLString = String(data: fileURLData, encoding: .utf8),
                   let fileURL = URL(string: fileURLString) {
                    let exten = fileURL.pathExtension
                    //判断文件格式是否支持
                    guard let _ = FileType(fileExtension: exten) else { continue }
                    let fileName = fileURL.lastPathComponent
                    do {
                        //将粘贴板的内容先复制到缓存目录中
                        let dstUrl = URL(fileURLWithPath: R.Path.PasteWorkSpace.appendingPathComponent(fileName))
                        try FileManager.safeCopyItem(at: fileURL, to: dstUrl, shouldReplace: true)
                        //复制成功
                        urls.append(dstUrl)
                    } catch {
                        //复制失败
                        errors.append(.badCopy(fileName: fileName))
                    }
                }
            }
            
            let handleDataGroup = DispatchGroup()
            if urls.count == 0 {
                //试试看粘贴板中有没有data数据
                let supportIdentifiers = UTType.allTypes.reduce("") { partialResult, type in
                    return partialResult + " " + type.identifier
                }
                let itemProviders = pasteboard.itemProviders
                for itemProvider in itemProviders {
                    var supportIdentifier: String? = nil
                    for itemProviderIdentifier in itemProvider.registeredTypeIdentifiers {
                        if supportIdentifiers.contains(itemProviderIdentifier, caseSensitive: false) {
                            supportIdentifier = itemProviderIdentifier
                            break
                        }
                    }
                    if let supportIdentifier = supportIdentifier {
                        //找到了支持的类型
                        if let utType = UTType(supportIdentifier),
                            let extens = utType.tags[.filenameExtension]?.first,
                            let suggestedName = itemProvider.suggestedName {
                            //获取到文件名
                            let fileName = suggestedName + "." + extens
                            //将粘贴板的内容先复制到缓存目录中
                            let dstUrl = URL(fileURLWithPath: R.Path.PasteWorkSpace.appendingPathComponent(fileName))
                            handleDataGroup.enter()
                            itemProvider.loadFileRepresentation(forTypeIdentifier: supportIdentifier) { url, error in
                                if let url = url {
                                    do {
                                        try FileManager.safeCopyItem(at: url, to: dstUrl, shouldReplace: true)
                                        //复制成功
                                        urls.append(dstUrl)
                                        handleDataGroup.leave()
                                    } catch {
                                        //复制失败
                                        errors.append(.badCopy(fileName: fileName))
                                        handleDataGroup.leave()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            handleDataGroup.notify(queue: .main) {
                if urls.count == 0 {
                    //如果文件url列表为空 则不操作
                    if errors.isEmpty {
                        errors.append(.pasteNoMatchContent)
                    }
                    UIView.hideLoading()
                    UIView.makeToast(message: String.errorMessage(from: errors))
                } else {
                    FilesImporter.importFiles(urls: urls, preErrors: errors, in: scene)
                }
            }
        }
    }
}
