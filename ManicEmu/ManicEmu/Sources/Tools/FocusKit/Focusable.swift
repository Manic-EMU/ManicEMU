//
//  Focusable.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

// MARK: - Focusable 协议

/// 需要深度定制焦点行为的视图可实现此协议；全部方法都有默认实现。
/// 普通视图无需实现协议，直接设置 `view.isFocusable = true` 即可参与导航。
protocol Focusable: UIView {
    /// 当前是否可以获得焦点（默认：isFocusable 且可见）
    var canFocus: Bool { get }
    /// 获得焦点（默认：应用聚焦外观并开启抬起）
    func didFocus()
    /// 失去焦点（默认：恢复外观并关闭抬起）
    func didUnfocus()
    /// 确定键的默认行为（默认走点击模拟激活链），返回是否消费
    func performPrimaryAction() -> Bool
}

extension Focusable {
    var canFocus: Bool { fk_defaultCanFocus }
    func didFocus() { fk_defaultApplyFocus(true) }
    func didUnfocus() { fk_defaultApplyFocus(false) }
    func performPrimaryAction() -> Bool { fk_defaultPerformPrimaryAction() }
}

// MARK: - UIView 关联属性（零成本接入）

private var FocusableIsFocusableKey: UInt8 = 0
private var FocusableEnableFocusEffectsKey: UInt8 = 0
private var FocusableOnFocusChangeKey: UInt8 = 0
private var FocusableOnConfirmKey: UInt8 = 0
private var FocusableCommandsKey: UInt8 = 0
private var FocusableAppearanceInfoKey: UInt8 = 0

extension UIView {
    /// 标记视图可被焦点导航系统识别。
    /// 对 `UICollectionView` 设置此值即代表其作为容器参与导航（进入层级）。
    var isFocusable: Bool {
        get { (objc_getAssociatedObject(self, &FocusableIsFocusableKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &FocusableIsFocusableKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 是否在聚焦时改 userInterfaceStyle / backgroundColor / layerCornerRadius。默认 true。
    /// 不影响抬起（`focusEffect`）。设为 false 时仍可聚焦，`onFocusChange` 仍会回调。
    var enableFocusEffects: Bool {
        get { (objc_getAssociatedObject(self, &FocusableEnableFocusEffectsKey) as? Bool) ?? true }
        set {
            let wasEnabled = enableFocusEffects
            objc_setAssociatedObject(self, &FocusableEnableFocusEffectsKey, newValue, .OBJC_ASSOCIATION_RETAIN)
            if wasEnabled && !newValue {
                fk_restoreFocusAppearance()
            }
        }
    }

    /// 焦点变化回调（在默认 focusEffect 处理之后调用），可用于自定义视觉
    var onFocusChange: ((_ focused: Bool) -> Void)? {
        get { objc_getAssociatedObject(self, &FocusableOnFocusChangeKey) as? (Bool) -> Void }
        set { objc_setAssociatedObject(self, &FocusableOnFocusChangeKey, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    /// 确定键（a）落在此视图时的自定义行为，优先于默认激活链。
    /// 带有 UITapGestureRecognizer 而非 UIControl 的视图建议设置此闭包。
    /// 返回 true 表示消费。
    var onFocusConfirm: (() -> Bool)? {
        get { objc_getAssociatedObject(self, &FocusableOnConfirmKey) as? () -> Bool }
        set { objc_setAssociatedObject(self, &FocusableOnConfirmKey, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    /// 焦点位于此视图时生效的命令（优先级最高）
    var focusCommands: [FocusCommand] {
        get { (objc_getAssociatedObject(self, &FocusableCommandsKey) as? [FocusCommand]) ?? [] }
        set { objc_setAssociatedObject(self, &FocusableCommandsKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

// MARK: - FocusKit 内部统一入口
// 引擎不关心视图是否实现了 Focusable，一律通过 fk_ 前缀方法访问。

extension UIView {
    /// 视图自身（不含祖先链）是否具备聚焦条件；祖先可见性由引擎遍历时保证
    var fk_defaultCanFocus: Bool {
        guard isFocusable else { return false }
        guard window != nil else { return false }
        var node: UIView? = self
        while let current = node {
            if current.isHidden || current.alpha <= 0.01 { return false }
            node = current.superview
        }
        guard bounds.width > 0.5, bounds.height > 0.5 else { return false }
        if let control = self as? UIControl, !control.isEnabled, onFocusConfirm == nil { return false }
        return true
    }

    var fk_canFocus: Bool {
        if let focusable = self as? Focusable {
            return focusable.canFocus
        }
        return fk_defaultCanFocus
    }

    func fk_applyFocus(_ focused: Bool) {
        if let focusable = self as? Focusable {
            focused ? focusable.didFocus() : focusable.didUnfocus()
        } else {
            fk_defaultApplyFocus(focused)
        }
    }

    private final class FocusAppearanceInfo {
        let userInterfaceStyle: UIUserInterfaceStyle
        let backgroundColor: UIColor?
        let layerCornerRadius: CGFloat

        init(userInterfaceStyle: UIUserInterfaceStyle, backgroundColor: UIColor?, layerCornerRadius: CGFloat) {
            self.userInterfaceStyle = userInterfaceStyle
            self.backgroundColor = backgroundColor
            self.layerCornerRadius = layerCornerRadius
        }
    }

    private var fk_focusAppearanceInfo: FocusAppearanceInfo? {
        get { objc_getAssociatedObject(self, &FocusableAppearanceInfoKey) as? FocusAppearanceInfo }
        set { objc_setAssociatedObject(self, &FocusableAppearanceInfoKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    fileprivate func fk_defaultApplyFocus(_ focused: Bool) {
        if focused {
            if enableFocusEffects {
                fk_applyFocusAppearance()
            }
        } else {
            fk_restoreFocusAppearance()
        }
        focusEffect = focused
        onFocusChange?(focused)
    }

    private func fk_applyFocusAppearance() {
        if fk_focusAppearanceInfo == nil {
            fk_focusAppearanceInfo = FocusAppearanceInfo(userInterfaceStyle: overrideUserInterfaceStyle,
                                                         backgroundColor: backgroundColor,
                                                         layerCornerRadius: layerCornerRadius)
        }
        overrideUserInterfaceStyle = UIDevice.isDarkMode ? .light : .dark
        backgroundColor = R.Color.BackgroundPrimary.forceStyle(UIDevice.isDarkMode ? .light : .dark)
        if layerCornerRadius == 0 {
            let w = bounds.width
            let h = bounds.height
            guard w > 0.5, h > 0.5 else { return }
            if h > 150 {
                layerCornerRadius = R.Size.CornerRadiusMedium
            } else {
                let shortest = min(w, h)
                let longest = max(w, h)
                let aspectRatio = longest / shortest
                if aspectRatio > 1.1 {
                    layerCornerRadius = shortest / 2.0
                } else if shortest / longest > 0.9 {
                    layerCornerRadius = h / 2.0
                } else {
                    layerCornerRadius = R.Size.AppleIconCornerRadius(height: h)
                }
            }
        }
    }

    private func fk_restoreFocusAppearance() {
        guard let info = fk_focusAppearanceInfo else { return }
        overrideUserInterfaceStyle = info.userInterfaceStyle
        backgroundColor = info.backgroundColor
        layerCornerRadius = info.layerCornerRadius
        fk_focusAppearanceInfo = nil
    }

    /// 确定键默认激活链：onFocusConfirm → performPrimaryAction 覆盖 → UIControl 点击模拟
    @discardableResult
    func fk_performPrimaryAction() -> Bool {
        if let onFocusConfirm, onFocusConfirm() {
            return true
        }
        if let focusable = self as? Focusable {
            return focusable.performPrimaryAction()
        }
        return fk_defaultPerformPrimaryAction()
    }

    fileprivate func fk_defaultPerformPrimaryAction() -> Bool {
        if let control = self as? UIControl {
            guard control.isEnabled else { return false }
            control.sendActions(for: .touchUpInside)
            return true
        }
        if fk_fireTapGestures() {
            return true
        }
        return false
    }

    /// Trigger enabled single-tap recognizers on this view (and one level of subviews for glass hosts).
    @discardableResult
    func fk_fireTapGestures() -> Bool {
        func fire(on view: UIView) -> Bool {
            var fired = false
            for gestureRecognizer in view.gestureRecognizers ?? [] {
                if let tap = gestureRecognizer as? UITapGestureRecognizer,
                   tap.isEnabled,
                   tap.numberOfTapsRequired <= 1 {
                    tap.state = .ended
                    fired = true
                }
            }
            return fired
        }
        if fire(on: self) { return true }
        for subview in subviews where fire(on: subview) {
            return true
        }
        return false
    }
}

extension UISlider {
    /// Make the slider focusable and consume left/right to nudge value.
    func enableFocusAdjustment(step: Float = 0.01) {
        isFocusable = true
        focusCommands = [
            FocusCommand(key: .left, title: R.string.localizable.focusHintAdjust(), action: { [weak self] in
                guard let self else { return }
                self.value = max(self.minimumValue, self.value - step)
                self.sendActions(for: [.valueChanged, .touchUpInside])
            }),
            FocusCommand(key: .right, title: R.string.localizable.focusHintAdjust(), action: { [weak self] in
                guard let self else { return }
                self.value = min(self.maximumValue, self.value + step)
                self.sendActions(for: [.valueChanged, .touchUpInside])
            })
        ]
    }
}
