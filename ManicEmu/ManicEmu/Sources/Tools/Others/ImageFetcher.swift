//
//  ImageFetcher.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import HXPhotoPicker
import UniformTypeIdentifiers
import Kingfisher

struct ImageFetcher {
    enum Source {
        case capture
        case library
        case file
        case libretro(Game)
        case steamGridDB(Game, preferredAssetType: SteamGridDBContentsView.AssetType)
        case editImage(UIImage)
        case editImageUrl(URL)
        case delete
    }
    
    private static func defaultEditorConfiguration() -> EditorConfiguration {
        var editConfig = EditorConfiguration()
        editConfig.buttonType = .top
        //        editConfig.photo.defaultSelectedToolOption = .cropSize
        //        editConfig.cropSize.isFixedRatio = true
        //        editConfig.cropSize.aspectRatio = CGSize(width: 1, height: 1)
        //        editConfig.cropSize.aspectRatios.removeAll()
        editConfig.toolsView.toolOptions.removeFirst { $0.type == .chartlet }
        editConfig.finishButtonTitleNormalColor = R.Color.Main
        editConfig.text.tintColor = R.Color.Main
        editConfig.text.doneTitleColor = R.Color.Main
        return editConfig
    }
    
    static func capture(preferenceSize: CGSize? = .init(R.Size.GameCoverMaxSize),
                        isOpenEditor: Bool = true,
                        in scene: UIWindowScene?,
                        completion: @escaping (_ image: UIImage?)->Void) {
        //拍摄
        PermissionKit.requestCamera {
            var config = CameraConfiguration()
            if isOpenEditor {
                config.editor = defaultEditorConfiguration()
            } else {
                config.allowsEditing = false
            }
            let vc = Photo.capture(config, type: .photo, sender: topViewController(in: scene)) { result, _, _ in
                if case .image(let image) = result {
                    if let preferenceSize {
                        completion(image.scaled(toSize: preferenceSize))
                    } else {
                        completion(image)
                    }
                } else {
                    completion(nil)
                }
                
            }
            vc.sheetPresentationController?.preferredCornerRadius = R.Size.CornerRadiusLarge
        }
    }
    
    static func pick(preferenceSize: CGSize? = .init(R.Size.GameCoverMaxSize),
                     isOpenEditor: Bool = true,
                     in scene: UIWindowScene?,
                     completion: @escaping (_ image: UIImage?)->Void) {
        PermissionKit.requestPhoto {
            var config = PickerConfiguration.default
            config.navigationBackgroundColor = R.Color.BackgroundSecondary.forceStyle(.dark)
            config.maximumSelectedCount = 1
            config.selectMode = .single
            config.selectOptions = [.livePhoto, .photo]
            config.photoSelectionTapAction = isOpenEditor ? .openEditor : .quickSelect
            config.editor = defaultEditorConfiguration()
            let vc = Photo.picker(config, sender: topViewController(in: scene)) { result, _ in
                result.getImage(compressionScale: 1) { image in
                    if let image = image.first {
                        if let preferenceSize {
                            completion(image.scaled(toSize: preferenceSize))
                        } else {
                            completion(image)
                        }
                    } else {
                        completion(nil)
                    }
                    
                }
            }
            vc.sheetPresentationController?.preferredCornerRadius = R.Size.CornerRadiusLarge
        }
    }
    
    static func file(preferenceSize: CGSize? = .init(R.Size.GameCoverMaxSize),
                     isOpenEditor: Bool = true,
                     in scene: UIWindowScene?,
                     completion: @escaping (_ image: UIImage?)->Void) {
        ImageFileFetcher.shared.file(preferenceSize: preferenceSize, in: scene, completion: { image in
            if let image {
                if isOpenEditor {
                    edit(image: image,
                         preferenceSize: preferenceSize,
                         in: scene,
                         completion: completion)
                } else {
                    completion(image)
                }
            } else {
                completion(nil)
            }
        })
    }
    
    static func edit(image: UIImage,
                     preferenceSize: CGSize? = .init(R.Size.GameCoverMaxSize),
                     in scene: UIWindowScene?,
                     completion: @escaping (_ image: UIImage?)->Void) {
        var config = defaultEditorConfiguration()
        // 由我们在 dismiss 完成后再回调，避免调用方立刻关掉 presenting 的 SheetWindow，导致系统旋转卡住。
        config.isAutoBack = false
        config.shouldAutorotate = true
        config.supportedInterfaceOrientations = R.Config.DefaultOrientation
        
        let vc = Photo.edit(asset: .init(type: .image(image)),
                            config: config,
                            sender: topViewController(in: scene),
                            finished: { asset, editor in
            var result = image
            if let url = asset.result?.url, let newImage = try? UIImage(url: url) {
                result = newImage
            }
            editor.dismiss(animated: true) {
                restoreInterfaceOrientation()
                if let preferenceSize {
                    completion(result.scaled(toSize: preferenceSize))
                } else {
                    completion(result)
                }
            }
        }, cancelled: { editor in
            editor.dismiss(animated: true) {
                restoreInterfaceOrientation()
            }
        })
        vc.sheetPresentationController?.preferredCornerRadius = R.Size.CornerRadiusLarge
    }
    
    private static func restoreInterfaceOrientation() {
        AppDelegate.orientation = R.Config.DefaultOrientation
    }
    
    static func showCommonFetcher(sources: [Source],
                                  in scene: UIWindowScene?,
                                  completion: ((UIImage?, Source) -> Void)? = nil ) {
        guard sources.count > 0 else { return }
        
        let cells = sources.map({
            switch $0 {
            case .capture:
                return ASListPage.Cell.iconTitleChevronCell(icon: .symbolImage(R.image.camera_iconSymbols()),
                                                            title: R.string.localizable.readyEditCoverTakePhoto())
            case .library:
                return ASListPage.Cell.iconTitleChevronCell(icon: .symbolImage(R.image.cover_iconSymbols()),
                                                            title: R.string.localizable.readyEditCoverAlbum())
            case .file:
                return ASListPage.Cell.iconTitleChevronCell(icon: .symbolImage(R.image.folder_iconSymbols()),
                                                            title: R.string.localizable.readyEditCoverFile())
            case .libretro:
                return ASListPage.Cell.iconTitleChevronCell(icon: .image(R.image.libretro_icon()),
                                                            title: R.string.localizable.searchFromLibretro())
            case .steamGridDB:
                return ASListPage.Cell.iconTitleChevronCell(icon: .image(R.image.steamGridDB_icon()),
                                                            title: R.string.localizable.searchFromSteamGridDB())
            case .editImage, .editImageUrl:
                return ASListPage.Cell.iconTitleChevronCell(icon: .symbolImage(R.image.edit_iconSymbols()),
                                                            title: R.string.localizable.editTitle())
            case .delete:
                return ASListPage.Cell.iconTitleChevronCell(icon: .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
                                                            title: R.string.localizable.removeTitle(),
                                                            titleColor: R.Color.Red)
            }
        })
        
        ChevronSheetView.show(icon: GameOption.cover.icon,
                              title: GameOption.cover.title,
                              cellOptions: cells,
                              completion: { index in
            guard let index else { return }
            switch sources[index] {
            case .capture:
                ImageFetcher.capture(in: scene, completion: {
                    completion?($0, .capture)
                })
            case .library:
                ImageFetcher.pick(in: scene, completion: {
                    completion?($0, .library)
                })
            case .file:
                ImageFetcher.file(in: scene, completion: {
                    completion?($0, .file)
                })
            case .libretro(let game):
                LibretroCoverSearchView.show(parameters: game)?.didSelectIamge = {
                    completion?($0, .libretro(game))
                }
            case .steamGridDB(let game, let preferredAssetType):
                
                func showSteamGridDBSearchView(apiKey: String) {
                    SteamGridDBSearchView.show(apiKey: apiKey,
                                               game: game,
                                               preferredAssetType: preferredAssetType,
                                               didSelectImage: {
                        completion?($0, .steamGridDB(game, preferredAssetType: preferredAssetType))
                    })
                }
                
                if let apiKey = Settings.defalut.SteamGridDBAPIKey {
                    showSteamGridDBSearchView(apiKey: apiKey)
                } else {
                    LimitedTextInputView.show(icon: .symbolImage(R.image.key_iconSymbols()),
                                              title: "API Key",
                                              detail: R.string.localizable.steamGridDBAPIKeyDesc() + "\n" + R.string.localizable.steamGridDBAPIKeyAlert(),
                                              limitedType: .normal(maxTextSize: 255), confirmAction: { key in
                        if let key = key as? String, !key.trimmed.isEmpty {
                            Settings.defalut.updateExtra(key: ExtraKey.steamGridDBAPIKey.rawValue, value: key)
                            showSteamGridDBSearchView(apiKey: key)
                        } else {
                            UIView.makeToast(message: R.string.localizable.steamGridDBAPIKeyAlert())
                        }
                    })
                }
            case .editImage(let image):
                ImageFetcher.edit(image: image, in: scene, completion: {
                    completion?($0, .editImage(image))
                })
            case .editImageUrl(let url):
                let s = scene
                KingfisherManager.shared.retrieveImage(with: url) { result in
                    switch result {
                    case .success(let imageResult):
                        Task { @MainActor in
                            ImageFetcher.edit(image: imageResult.image, in: s, completion: {
                                completion?($0, .editImageUrl(url))
                            })
                        }
                    case .failure(_):
                        Task { @MainActor in
                            UIView.makeToast(message: R.string.localizable.onlineCoverFetchFailed())
                        }
                    }
                }
            case .delete:
                completion?(nil, .delete)
            }
        })
    }
}

fileprivate class ImageFileFetcher: NSObject {
    static let shared = ImageFileFetcher()
    private var preferenceSize: CGSize? = nil
    private var completion: ((_ image: UIImage?)->Void)? = nil
    
    func file(preferenceSize: CGSize? = .init(R.Size.GameCoverMaxSize),
              in scene: UIWindowScene?,
              completion: @escaping (_ image: UIImage?)->Void) {
        self.preferenceSize = preferenceSize
        self.completion = completion
        let documentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.image], asCopy: true)
        documentPickerViewController.delegate = self
        documentPickerViewController.overrideUserInterfaceStyle = UIDevice.isDarkMode ? .dark : .light
        documentPickerViewController.allowsMultipleSelection = false
        topViewController(in: scene)?.present(documentPickerViewController, animated: true)
    }
}

extension ImageFileFetcher: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first, let image = try? UIImage(url: url) {
            if let preferenceSize {
                completion?(image.scaled(toSize: preferenceSize))
            } else {
                completion?(image)
            }
        } else {
            completion?(nil)
        }
        completion = nil
    }
}
