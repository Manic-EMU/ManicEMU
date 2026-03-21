//
//  ResourcesKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SSZipArchive
import ZIPFoundation

struct ResourcesKit {
    static func loadResources(completion: ((Bool)->Void)? = nil) {
        //将bunle的加密文件解压到Library中
        let resourceUrl = Bundle.main.url(forResource: "System", withExtension: "core")!
        let bundledSystemCoreSize = ((try? FileManager.default.attributesOfItem(atPath: resourceUrl.path)[.size]) as? NSNumber)?.intValue ?? 0
        
        //新版本更新需要强制刷新资源
        var forceRefresh = false
        if let systemCoreVersion = UserDefaults.standard.string(forKey: Constants.DefaultKey.SystemCoreVersion) {
            let appVersion = Constants.Config.AppVersion
            let appVersionNumber = UInt64(appVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
            let systemCoreVersionNumber = UInt64(systemCoreVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
            if systemCoreVersionNumber < appVersionNumber {
                //需要刷新
                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Resource))
                forceRefresh = true
            } else {
                //检查一下build version是否更新
                let systemCoreBuildVersion = UserDefaults.standard.integer(forKey: Constants.DefaultKey.SystemCoreBuildVersion)
                let appBuildVersion = Int(Constants.Config.AppBuildVersion)!
                if appBuildVersion > systemCoreBuildVersion {
                    //build number增加，也需要进行资源刷新
                    try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Resource))
                    forceRefresh = true
                }
            }
        } else {
            //内容为空 则强制刷新
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Resource))
            forceRefresh = true
        }

        let previousBundledSystemCoreSize = UserDefaults.standard.integer(forKey: Constants.DefaultKey.SystemCoreBundleSize)
        if previousBundledSystemCoreSize != bundledSystemCoreSize {
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Resource))
            forceRefresh = true
        }
#if DEBUG
        forceRefresh = true
#endif
        
        if forceRefresh || !FileManager.default.fileExists(atPath: Constants.Path.Resource) {
            //将3DS的文件从Library移到Document 暴露给用户使用
            if FileManager.default.fileExists(atPath: Constants.Path.Library.appendingPathComponent("3DS")),
               !FileManager.default.fileExists(atPath: Constants.Path.ThreeDS) {
                try? FileManager.safeMoveItem(at: URL(fileURLWithPath: Constants.Path.Library.appendingPathComponent("3DS")), to: URL(fileURLWithPath: Constants.Path.ThreeDS))
            }
            //重新将Documents/Datas/3DS/sdmc 转移回 Documents/3DS/sdmc
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.ThreeDS.appendingPathComponent("sdmc_location.txt")))
            if !FileManager.default.fileExists(atPath: Constants.Path.ThreeDS.appendingPathComponent("sdmc")) {
                if FileManager.default.fileExists(atPath: Constants.Path.Data.appendingPathComponent("3DS/sdmc")) {
                    try? FileManager.safeMoveItem(at: URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent("3DS/sdmc")),
                                             to: URL(fileURLWithPath: Constants.Path.ThreeDS.appendingPathComponent("sdmc")),
                                             shouldReplace: true)
                    try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent("3DS")))
                } else {
                    try? FileManager.default.createDirectory(atPath: Constants.Path.ThreeDS.appendingPathComponent("sdmc"),
                                                        withIntermediateDirectories: true)
                }
            }
            
            Log.debug("开始解压资源:\(Date.now.timeIntervalSince1970ms)")
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: Constants.Path.Resource))
            SSZipArchive.unzipFile(atPath: resourceUrl.path, toDestination: Constants.Path.Resource, overwrite: true, password: nil, progressHandler: nil) { _, isSuccess, error in
                
                //处理复用皮肤
                let reuseCores = System.allCores.filter({ $0.gameType.reuseGameType() != $0.gameType })
                for reuse in reuseCores {
                    let templateStandardSkinPath = Constants.Path.Resource.appendingPathComponent("\(reuse.gameType.reuseGameType().localizedShortName).manicskin")
                    let newStandardSkinPath = Constants.Path.Resource.appendingPathComponent("\(reuse.name).manicskin")
                    do {
                        try FileManager.safeCopyItem(at: URL(fileURLWithPath: templateStandardSkinPath), to: URL(fileURLWithPath: newStandardSkinPath), shouldReplace: true)
                        let archive = try Archive(url: URL(fileURLWithPath: newStandardSkinPath), accessMode: .update)
                        if let oldInfoJson = archive["info.json"] {
                            try archive.remove(oldInfoJson)
                        }
                        try archive.addEntry(with: "info.json", fileURL: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("\(reuse.name).skininfo")))
                    } catch {
                        Log.debug("复用皮肤出错:\(error)")
                    }
                    
                    let templateFlexSkinPath = Constants.Path.Resource.appendingPathComponent("\(reuse.gameType.reuseGameType().localizedShortName)_FLEX.manicskin")
                    let newFlexSkinPath = Constants.Path.Resource.appendingPathComponent("\(reuse.name)_FLEX.manicskin")
                    do {
                        try FileManager.safeCopyItem(at: URL(fileURLWithPath: templateFlexSkinPath), to: URL(fileURLWithPath: newFlexSkinPath), shouldReplace: true)
                        let archive = try Archive(url: URL(fileURLWithPath: newFlexSkinPath), accessMode: .update)
                        if let oldInfoJson = archive["info.json"] {
                            try archive.remove(oldInfoJson)
                        }
                        try archive.addEntry(with: "info.json", fileURL: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("\(reuse.name)_FLEX.skininfo")))
                    } catch {
                        Log.debug("复用皮肤出错:\(error)")
                    }
                }
                
                Log.debug("资源解压结束:\(Date.now.timeIntervalSince1970ms)")
                completion?(isSuccess)
                if isSuccess {
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("aes_keys.txt")), to: URL(fileURLWithPath: Constants.Path.ThreeDSSystemData.appendingPathComponent("aes_keys.txt")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("seeddb.bin")), to: URL(fileURLWithPath: Constants.Path.ThreeDSSystemData.appendingPathComponent("seeddb.bin")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("shared_font.bin")), to: URL(fileURLWithPath: Constants.Path.ThreeDSSystemData.appendingPathComponent("shared_font.bin")), shouldReplace: true)
                    
                    //Libretro的资源复制到对应位置
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("Libretro/info")), to: URL(fileURLWithPath: Constants.Path.Libretro.appendingPathComponent("info")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("Libretro/autoconfig")), to: URL(fileURLWithPath: Constants.Path.Libretro.appendingPathComponent("autoconfig")), shouldReplace: true)
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("Libretro/shaders/default")), to: URL(fileURLWithPath: Constants.Path.ShaderDefault), shouldReplace: true)
                    try? FileManager.safeReplaceDirectory(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("Libretro/system")), to: URL(fileURLWithPath: Constants.Path.System))
                    try? FileManager.safeReplaceDirectory(at: URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent("Libretro/config")), to: URL(fileURLWithPath: Constants.Path.Libretro.appendingPathComponent("config")))
                    if !FileManager.default.fileExists(atPath: Constants.Path.AzaharConfig) {
                        try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.AzaharDefaultConfig), to: URL(fileURLWithPath: Constants.Path.AzaharConfig))
                    }
                    
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: Constants.Path.CitraDefaultConfig), to: URL(fileURLWithPath: Constants.Path.CitraConfig), shouldReplace: true)
                    
                    if let systemCoreVersion = UserDefaults.standard.string(forKey: Constants.DefaultKey.SystemCoreVersion) {
                        let systemCoreVersionNumber = UInt64(systemCoreVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
                        if systemCoreVersionNumber < 153 {
                            //适配PKSM 将存档位置进行调整
                            if let contents = try? FileManager.default.contentsOfDirectory(atPath: Constants.Path.Data) {
                                for content in contents {
                                    var newSaveUrl: URL? = nil
                                    if content.hasSuffix(".dsv") {
                                        //将dsv后缀改为srm
                                        newSaveUrl = URL(fileURLWithPath: Constants.Path.DSSavePath.appendingPathComponent("\(content.deletingPathExtension).srm"))
                                    } else if content.hasSuffix(".gba.sav") {
                                        //将.gba.sav 改成 .sav
                                        newSaveUrl = URL(fileURLWithPath: Constants.Path.GBASavePath.appendingPathComponent("\(content.replacingOccurrences(of: ".gba.sav", with: ".sav"))"))
                                    } else if content.hasSuffix(".gb.sav") {
                                        //将.gb.sav 改成 .sav
                                        //GB和GBC 都使用了.gb.sav的后缀格式，在这里需要将他们区分开
                                        let gameFileName = content.deletingPathExtension
                                        var isGBC = true
                                        if FileManager.default.fileExists(atPath: Constants.Path.Data.appendingPathComponent(gameFileName)), gameFileName.pathExtension.lowercased() == "gb" {
                                            isGBC = false
                                        }
                                        if isGBC {
                                            newSaveUrl = URL(fileURLWithPath: Constants.Path.GBCSavePath.appendingPathComponent("\(content.replacingOccurrences(of: ".gb.sav", with: ".sav"))"))
                                        } else {
                                            newSaveUrl = URL(fileURLWithPath: Constants.Path.GBSavePath.appendingPathComponent("\(content.replacingOccurrences(of: ".gb.sav", with: ".sav"))"))
                                        }
                                    }
                                    if let newSaveUrl {
                                        try? FileManager.safeMoveItem(at: URL(fileURLWithPath: Constants.Path.Data.appendingPathComponent(content)), to: newSaveUrl, shouldReplace: true)
                                    }
                                }
                            }
                        }
                        if systemCoreVersionNumber < 181 {
                            if let contents = try? FileManager.default.contentsOfDirectory(atPath: Constants.Path.Shaders) {
                                for content in contents {
                                    if content != "default" {
                                        try? FileManager.default.removeItem(atPath: Constants.Path.Shaders.appendingPathComponent(content))
                                    }
                                }
                            }
                        }
                        //升级1.8.3将DeSmuME核心的dsv存档全转转换为srm
                        if systemCoreVersionNumber < 183 {
                            if let contents = try? FileManager.default.contentsOfDirectory(atPath: Constants.Path.DSSavePath) {
                                for content in contents {
                                    if content.pathExtension.lowercased() == "dsv" {
                                        let contentUrl = URL(fileURLWithPath: Constants.Path.DSSavePath.appendingPathComponent(content))
                                        let newContentUrl = URL(fileURLWithPath: Constants.Path.DSSavePath.appendingPathComponent(content.deletingPathExtension + ".srm"))
                                        if FileManager.default.fileExists(atPath: newContentUrl.path) {
                                            continue
                                        } else {
                                            try? FileManager.safeMoveItem(at: contentUrl, to: newContentUrl)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Log.info("资源解压成功!")
                    UserDefaults.standard.set(Constants.Config.AppVersion, forKey: Constants.DefaultKey.SystemCoreVersion)
                    UserDefaults.standard.set(Constants.Config.AppBuildVersion, forKey: Constants.DefaultKey.SystemCoreBuildVersion)
                    UserDefaults.standard.set(bundledSystemCoreSize, forKey: Constants.DefaultKey.SystemCoreBundleSize)
                } else {
                    if let error = error {
                        Log.error("资源解压失败! error:\(error)")
                    } else {
                        Log.error("资源解压失败!")
                    }
                }
            }
        } else {
            completion?(true)
        }
    }
}
