//
//  UIViewExtensions.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2023/5/17.
//  Copyright © 2023 Aoshuang Lee. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import ObjectiveC
import VisualEffectView
import ProHUD
import NVActivityIndicatorView
import Schedule

extension UIView {
    @discardableResult
    func makeBlur(blurRadius: CGFloat = 12.5, blurColor: UIColor = R.Color.BackgroundPrimary, blurAlpha: CGFloat = 0.9, cornerRadius: CGFloat? = nil) -> VisualEffectView {
        removeBlur()
        backgroundColor = .clear
        let blur = VisualEffectView()
        insertSubview(blur, at: 0)
        blur.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        blur.blurRadius = blurRadius
        blur.colorTint = blurColor
        blur.colorTintAlpha = blurAlpha
        if let cornerRadius = cornerRadius {
            blur.layerCornerRadius = cornerRadius
        }
        return blur
    }
    
    func removeBlur() {
        if let blurView = subviews.first(where: { $0 is VisualEffectView }) as? VisualEffectView {
            blurView.removeFromSuperview()
        }
    }
    
    func setBlurVisble(_ visble: Bool) {
        if let blurView = subviews.first(where: { $0 is VisualEffectView }) as? VisualEffectView {
            blurView.isHidden = !visble
        }
    }
    
    func makeShadow(ofColor: UIColor = R.Color.Shadow, offset: CGSize = .zero, radius: CGFloat = 10, opacity: Float = 0.5) {
        layer.shadowColor = ofColor.cgColor
        layer.shadowOffset = offset
        layer.shadowRadius = radius
        layer.shadowOpacity = opacity
        layer.masksToBounds = false
    }
    
    func removeShadow() {
        layer.shadowColor = UIColor.clear.cgColor
    }
    
    /// 为视图添加 iOS 26 的 Liquid Glass 效果
    /// - Parameters:
    ///   - useContainerEffect: 是否使用容器效果（UIGlassContainerEffect），默认为 false 使用普通玻璃效果（UIGlassEffect）
    /// - Note: 此方法仅在 iOS 26.0 及以上版本可用
    @available(iOS 26.0, *)
    func makeGlass(useContainerEffect: Bool = false, tintColor: UIColor = R.Color.BackgroundSecondary) {
        // 移除已存在的 Liquid Glass 视图
        subviews.filter { $0 is UIVisualEffectView && $0.accessibilityIdentifier == "LiquidGlassEffectView" }.forEach {
            $0.removeFromSuperview()
        }
        
        // 创建 Glass Effect
        let glassEffect: UIVisualEffect
        if useContainerEffect {
            glassEffect = UIGlassContainerEffect()
        } else {
            let effect = UIGlassEffect(style: .clear)
            effect.tintColor = tintColor.withAlphaComponent(0.2)
            effect.isInteractive = true
            glassEffect = effect
        }
        
        // 创建 UIVisualEffectView 并应用玻璃效果
        let visualEffectView = UIVisualEffectView(effect: glassEffect)
        visualEffectView.accessibilityIdentifier = "LiquidGlassEffectView"
        visualEffectView.frame = bounds
        visualEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 继承当前视图的圆角设置
        if layer.cornerRadius > 0 {
            visualEffectView.layer.cornerRadius = layer.cornerRadius
            visualEffectView.clipsToBounds = true
        }
        
        // 将 UIVisualEffectView 添加到当前视图的底层
        insertSubview(visualEffectView, at: 0)
    }
    
    static func normalAnimate(enable: Bool = true, animations: @escaping ()->Void, completion: ((Bool)->Void)? = nil) {
        if enable {
            UIView.animate(withDuration: 0.35, animations: animations, completion: completion)
        } else {
            animations()
            completion?(true)
        }
    }
    
    static func springAnimate(enable: Bool = true, options: AnimationOptions = [], animations: @escaping ()->Void, completion: ((Bool)->Void)? = nil) {
        if enable {
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: options,  animations: animations, completion: completion)
        } else {
            animations()
            completion?(true)
        }
    }
    
    static func makeToast(message: String, isRemovable: Bool = true, identifier: String? = nil, duration: TimeInterval = 3, hideCompletion: (()->Void)? = nil) {
        func setupToast(toast: ToastTarget, resue: Bool = false) {
            toast.onViewDidDisappear { _ in
                hideCompletion?()
            }
            let maxWidth = R.Size.WindowWidth - 2*R.Size.ContentSpaceLarge
            let insets = UIEdgeInsets(horizontal: R.Size.ContentSpaceHuge*2, vertical: 14*2)
            toast.config.cardEdgeInsets = insets
            let font = R.Font.Headline(emphasis: true)
            toast.config.customTextLabel { label in
                label.textColor = R.Color.LabelPrimary
                label.font = font
                label.textAlignment = .natural
                label.lineBreakMode = .byWordWrapping
            }
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .natural
            paragraphStyle.lineBreakMode = .byWordWrapping
            let textSize = NSAttributedString(string: message, attributes: [.font: font, .paragraphStyle: paragraphStyle]).size()
            let textMaxWidth = textSize.width.ceil
            let cornerRadius = (insets.top + textSize.height + insets.bottom)/2
            toast.config.cardCornerRadius = cornerRadius > 24 ? R.Size.CornerRadiusLarge : cornerRadius
            if insets.left + textMaxWidth + insets.right < maxWidth {
                toast.config.cardMaxWidth = insets.left + textMaxWidth + insets.right
            } else {
                toast.config.cardMaxWidth = maxWidth
            }
            toast.contentView.layerBorderColor = R.Color.Border
            toast.contentView.layerBorderWidth = 1
            toast.config.dynamicBackgroundColor = R.Color.BackgroundSecondary.withAlphaComponent(0.95)
        }
        
        if !isRemovable, let identifier = identifier {
            if let toast = ToastManager.find(identifier: identifier).first {
                toast.bodyLabel.text = message
            } else {
                //常驻的toast
                Toast(.message(message).duration(.infinity).identifier(identifier)) { toast in
                    toast.isRemovable = false
                    setupToast(toast: toast)
                }
            }
        } else if let identifier = identifier {
            //只有一个Toast 3秒消失
            Toast(.message(message).duration(duration).identifier(identifier)) { toast in
                setupToast(toast: toast)
            }
            
        } else {
            //停留3秒就消失
            Toast(.message(message).duration(duration)) { toast in
                setupToast(toast: toast)
            }
        }
    }
    
    /// 立即移除toast
    /// - Parameter identifier: toast的标识 如果不传入 则隐藏全部
    static func hideToast(identifier: String) {
        ToastManager.find(identifier: identifier).forEach { $0.pop() }
    }
    
    private static var LoadingToastRepeater: Schedule.Task? = nil
    private static var LoadingToastIdentifier = "LoadingToastIdentifier"
    static func makeLoadingToast(message: String) {
        var dot = "..."
        let task = Plan.every(1.seconds).do(queue: .main) {
            UIView.makeToast(message: message + dot,
                             isRemovable: false,
                             identifier: LoadingToastIdentifier)
            dot += "."
            if dot.count > 3 {
                dot = "."
            }
        }
        TaskCenter.default.addTag(LoadingToastIdentifier, to: task)
        LoadingToastRepeater = task
    }
    
    static func hideLoadingToast() {
        UIView.hideToast(identifier: LoadingToastIdentifier)
        LoadingToastRepeater?.cancel()
        TaskCenter.default.resume(byTag: LoadingToastIdentifier)
        LoadingToastRepeater = nil
    }
    
    private static let LoadingIdentifier = "LoadingIdentifier"
    private static var startLoadingTime: Date? = nil
    static func makeLoading(timeout: Double = .infinity) {
        if let _ = AlertManager.find(identifier: LoadingIdentifier).last {
            return
        }
        Alert(.identifier(LoadingIdentifier).duration(timeout)) { alert in
            let size = 100.0
            alert.config.cardMaxWidth = size
            alert.config.cardMinWidth = size
            alert.config.cardMaxHeight = size
            alert.config.cardMinHeight = size
            alert.contentView.layerBorderColor = UIDevice.isDarkMode ? R.Color.Border.forceStyle(.dark) : R.Color.Border.forceStyle(.light)
            alert.contentView.layerBorderWidth = 1
            alert.config.cardCornerRadius = R.Size.CornerRadiusMedium
            alert.config.contentViewMask { mask in }
            let blur = VisualEffectView()
            blur.blurRadius = 12.5
            blur.colorTint = UIDevice.isDarkMode ? R.Color.BackgroundSecondary.forceStyle(.dark) : R.Color.BackgroundSecondary.forceStyle(.light)
            blur.colorTintAlpha = 0.925
            alert.contentMaskView = blur
            alert.config.backgroundViewMask { mask in
                mask.backgroundColor = .black.withAlphaComponent(0.2)
            }
            let pacman = UIView()
            let activity = NVActivityIndicatorView(frame: .zero, type: .pacman, color: UIDevice.isDarkMode ? R.Color.LabelPrimary.forceStyle(.dark) : R.Color.LabelPrimary.forceStyle(.light), padding: nil)
            pacman.addSubview(activity)
            activity.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.centerX.equalToSuperview().offset(R.Size.ContentSpaceExtraSmall)
                make.size.equalTo(CGSize(width: 50, height: 50))
            }
            alert.add(subview: pacman).snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            activity.startAnimating()
            startLoadingTime = Date()
        }
    }
    
    static func hideLoading(completion: (()->Void)? = nil) {
        if let alert = AlertManager.find(identifier: LoadingIdentifier).last {
            if let startLoadingTime = startLoadingTime {
                let duration = Date().timeIntervalSince1970ms - startLoadingTime.timeIntervalSince1970ms
                if duration > 800 {
                    alert.pop {
                        completion?()
                    }
                } else {
                    DispatchQueue.main.asyncAfter(delay: (800-duration)/800) {
                        alert.pop {
                            completion?()
                        }
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(delay: 0.8) {
                    alert.pop {
                        completion?()
                    }
                }
            }
        } else {
            completion?()
        }
        startLoadingTime = nil
    }
    
    enum AlertHideType {
        case cancel, confirm, other
    }
    
    private static var SheetIdentifiers = [String]()
    static func makeAlert(identifier: String? = nil,
                          title: String? = nil,
                          detail: String,
                          detailAlignment: NSTextAlignment = .center,
                          cancelTitle: String = R.string.localizable.cancelTitle(),
                          confirmTitle: String? = nil,
                          confirmAutoHide: Bool = true,
                          enableForceHide: Bool = true,
                          cancelAction: (()->Void)? = nil,
                          confirmAction: (()->Void)? = nil,
                          hideAction: ((AlertHideType)->Void)? = nil,
                          tapBackgroundAction: (()->Void)? = nil) {
        if let identifier {
            SheetIdentifiers.append(identifier)
        }
        let sheet = ASSheet(style: .text(title: title,
                                         detail: detail,
                                         detailAlignment: detailAlignment,
                                         buttonTitle: cancelTitle,
                                         destructiveButtonTitle: confirmTitle),
                            enableGrabber: enableForceHide,
                            enableTapBackgroundDismiss: enableForceHide)
        let enableMultiInstance = identifier == nil
        var hideType: AlertHideType = .other
        ASSheetView.show(sheet,
                         identifier: identifier,
                         enableMultiInstance: enableMultiInstance,
                         action: { action, _ in
            if let index = action.textValue {
                if index == 0 {
                    //cancel
                    hideType = .cancel
                    return .dismiss {
                        cancelAction?()
                    }
                } else if index == 1 {
                    //destructiveButtonTitle
                    if confirmAutoHide {
                        hideType = .confirm
                        return .dismiss {
                            confirmAction?()
                        }
                    } else {
                        confirmAction?()
                        return .none
                    }
                }
            } else if action.isTapBackground {
                tapBackgroundAction?()
                return .none
            }
            return .dismiss()
        }, dismiss: {
            hideAction?(hideType)
            if let identifier {
                SheetIdentifiers.removeFirst { $0 == identifier }
            }
        })
    }
    
    ///只能隐藏由makeAlert展示的
    static func hideAlert(completion: (() -> Void)? = nil) {
        var removes: [String] = []
        for identifier in SheetIdentifiers.reversed() {
            if let sheet = SheetProvider.find(identifier: identifier).first {
                SheetIdentifiers.removeLast()
                sheet.pop {
                    completion?()
                }
                break
            } else {
                removes.append(identifier)
            }
        }
        SheetIdentifiers.removeAll { removes.contains($0) }
    }
    
    ///能隐藏所有Alert
    static func hideAllAlert(completion: (() -> Void)? = nil) {
        let group = DispatchGroup()
        SheetProvider.findAll().forEach({
            group.enter()
            $0.pop {
                group.leave()
            }
        })
        SheetIdentifiers.removeAll()
        group.notify(queue: .main) {
            completion?()
        }
    }
    
    func asImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = isOpaque
        
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        return renderer.image { _ in
            drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
    }
    
    var windowSafeArea: UIEdgeInsets {
        window?.safeAreaInsets ?? .zero
    }
}
