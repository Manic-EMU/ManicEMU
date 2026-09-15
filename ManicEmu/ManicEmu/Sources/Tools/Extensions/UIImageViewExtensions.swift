//
//  UIImageViewExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import Kingfisher

private var gameCoverRequestIDKey: UInt8 = 0

extension UIImageView {
    /// Drop stale async cache hits after the cell is reused for another game.
    private var gameCoverRequestID: String? {
        get { objc_getAssociatedObject(self, &gameCoverRequestIDKey) as? String }
        set { objc_setAssociatedObject(self, &gameCoverRequestIDKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }

    func setGameCover(game: Game, size: CGSize? = nil, completion: ((UIImage)->Void)? = nil) {
        self.kf.cancelDownloadTask()
        let requestID = game.id
        gameCoverRequestID = requestID

        if game.isNDSHomeMenuGame || game.is3DSHomeMenuGame || game.isDOSHomeMenuGame || game.isSymbianHomeMenu {
            self.contentMode = .scaleAspectFill
            self.image = HomeMenuImage(size: size ?? .init(300), gameType: game.gameType, isDSi: game.isDSiHomeMenuGame)
            completion?(UIImage.tryDataImageOrPlaceholder(tryData: image?.jpegData(compressionQuality: 0.7)))
            return
        }

        if R.Style.GameCoverForceSquare,
            let data = game.icon?.storedData() {
            applyLocalCover(data: data, size: size, requestID: requestID, completion: completion)
            return
        }

        if let onlineCoverUrl = game.onlineCoverUrl, let url = URL(string: onlineCoverUrl), game.gameCover == nil {
            self.contentMode = .scaleAspectFit
            self.kf.setImage(with: url, placeholder: UIImage.placeHolder(preferenceSize: size)) { [weak self] result in
                guard let self, self.gameCoverRequestID == requestID else { return }
                switch result {
                case .success(let successResult):
                    self.contentMode = .scaleAspectFill
                    completion?(successResult.image)
                case .failure(_):
                    self.contentMode = .scaleAspectFit
                    completion?(UIImage.placeHolder(preferenceSize: size))
                }
            }
            return
        }

        if let data = game.gameCover?.storedData() {
            applyLocalCover(data: data, size: size, requestID: requestID, completion: completion)
            return
        }

        self.contentMode = .scaleAspectFit
        self.image = UIImage.tryDataImageOrPlaceholder(tryData: nil, preferenceSize: size)
        completion?(UIImage.tryDataImageOrPlaceholder(tryData: nil))
    }

    private func applyLocalCover(data: Data, size: CGSize?, requestID: String, completion: ((UIImage)->Void)?) {
        self.contentMode = .scaleAspectFill
        let cache = KingfisherManager.shared.cache
        let cacheKey = data.md5String
        if let cached = cache.retrieveImageInMemoryCache(forKey: cacheKey) {
            self.image = cached
            completion?(UIImage.tryDataImageOrPlaceholder(tryData: data))
            return
        }
        // Don't keep the previous game's artwork while disk cache / decode is in flight.
        self.image = UIImage.placeHolder(preferenceSize: size)
        cache.retrieveImage(forKey: cacheKey, completionHandler: { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.gameCoverRequestID == requestID else { return }
                func storeCache() {
                    let image = UIImage.tryDataImageOrPlaceholder(tryData: data, preferenceSize: size)
                    cache.store(image, forKey: cacheKey, processorIdentifier: DefaultImageProcessor.default.identifier)
                    self.image = image
                    completion?(UIImage.tryDataImageOrPlaceholder(tryData: data))
                }
                switch result {
                case .success(let value):
                    if let image = value.image {
                        self.image = image
                        completion?(UIImage.tryDataImageOrPlaceholder(tryData: data))
                    } else {
                        storeCache()
                    }
                case .failure(_):
                    storeCache()
                }
            }
        })
    }
}
