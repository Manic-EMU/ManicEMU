//
//  DuoTabletopControlView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/10/20.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit

/// Bottom pane of iPhone Duo Tabletop. Frames match the `Dark` artboard (669×951), shifted into the pane that starts at y = 476.
@available(iOS 27.1, *)
class DuoTabletopControlView: BaseView {
    private enum Design {
        static let pane = CGSize(width: 669, height: 475.5)
        static let dpad = CGRect(x: 70, y: 150, width: 150, height: 150)
        static let buttonA = CGRect(x: 522, y: 163, width: 64, height: 64)
        static let buttonB = CGRect(x: 462, y: 223, width: 64, height: 64)
        static let select = CGRect(x: 319, y: 261, width: 30, height: 30)
    }
    
    private let backgroundView = UIImageView(image: UIImage(named: "TabletopMode_bg"))
    private let dpadView = TabletopDpadControl(imageName: "TabletopMode_dpad")
    private let aButton = TabletopKeyControl(imageName: "TabletopMode_a", key: .a)
    private let bButton = TabletopKeyControl(imageName: "TabletopMode_b", key: .b)
    private let selectButton = TabletopKeyControl(imageName: "TabletopMode_select", key: .select)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.Color.BackgroundPrimary
        backgroundView.contentMode = .scaleAspectFill
        backgroundView.clipsToBounds = true
        isMultipleTouchEnabled = true
        addSubview(backgroundView)
        addSubview(dpadView)
        addSubview(aButton)
        addSubview(bButton)
        addSubview(selectButton)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.frame = bounds
        guard Design.pane.width > 0 else { return }
        // One scale from the pane width. The window is half a point shorter than the artboard, and stretching Y would move the controls.
        let scale = bounds.width / Design.pane.width
        func place(_ view: UIView, _ design: CGRect) {
            view.frame = CGRect(x: design.minX * scale,
                                y: design.minY * scale,
                                width: design.width * scale,
                                height: design.height * scale)
        }
        place(dpadView, Design.dpad)
        place(aButton, Design.buttonA)
        place(bButton, Design.buttonB)
        place(selectButton, Design.select)
    }
}

/// Spring press used by skin buttons in `DynamicEffectView`.
@available(iOS 27.1, *)
private final class TabletopPressAnimator {
    private var animator: UIViewPropertyAnimator?
    private var generation = 0
    private var pressedAt = Date()
    
    func press(_ animations: @escaping () -> Void) {
        generation += 1
        pressedAt = Date()
        run(animations)
    }
    
    /// Matches `ButtonsDynamicEffectView.deactivateButtonEffect`: a tap shorter than 0.06s still shows the press.
    func release(_ animations: @escaping () -> Void) {
        generation += 1
        let token = generation
        let elapsed = Date().timeIntervalSince(pressedAt)
        let runRelease = { [weak self] in
            guard let self, token == self.generation else { return }
            self.run(animations)
        }
        if elapsed < 0.06 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: runRelease)
        } else {
            runRelease()
        }
    }
    
    private func run(_ animations: @escaping () -> Void) {
        animator?.stopAnimation(true)
        let timing = UISpringTimingParameters(dampingRatio: 1.0, initialVelocity: CGVector(dx: 0.2, dy: 0.2))
        let animator = UIViewPropertyAnimator(duration: 0.65, timingParameters: timing)
        animator.addAnimations(animations)
        animator.isInterruptible = true
        animator.startAnimation()
        self.animator = animator
    }
}

@available(iOS 27.1, *)
private final class TabletopKeyControl: UIView {
    private let key: FocusKey
    private let imageView = UIImageView()
    private let effect = TabletopPressAnimator()
    private var touchInputs: [UITouch: Bool] = [:]
    private var isDown = false
    
    init(imageName: String, key: FocusKey) {
        self.key = key
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        imageView.image = UIImage(named: imageName)
        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if isDown {
            FocusSystem.shared.keyUp(key)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchInputs[touch] = false
        }
        updateInputs(for: touches, ended: [])
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateInputs(for: touches, ended: [])
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateInputs(for: touches, ended: touches)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    /// Same diff as `ButtonsInputView`: update the held set, then keyDown new presses and keyUp releases.
    private func updateInputs(for touches: Set<UITouch>, ended: Set<UITouch>) {
        for touch in ended {
            touchInputs[touch] = nil
        }
        for touch in touches where touchInputs[touch] != nil {
            let point = touch.location(in: self)
            touchInputs[touch] = bounds.contains(point)
        }
        let down = touchInputs.values.contains(true)
        guard down != isDown else { return }
        isDown = down
        if down {
            FocusSystem.shared.keyDown(key)
            UIDevice.generateHaptic()
            effect.press { [weak self] in
                self?.imageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
        } else {
            FocusSystem.shared.keyUp(key)
            effect.release { [weak self] in
                self?.imageView.transform = .identity
            }
        }
    }
}

@available(iOS 27.1, *)
private final class TabletopDpadControl: UIView {
    private let imageView = UIImageView()
    private let effect = TabletopPressAnimator()
    private var touchDirections: [UITouch: Set<FocusKey>] = [:]
    private var activeDirections = Set<FocusKey>()
    
    init(imageName: String) {
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        imageView.image = UIImage(named: imageName)
        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        for key in activeDirections {
            FocusSystem.shared.keyUp(key)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchDirections[touch] = []
        }
        updateInputs(for: touches, ended: [])
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateInputs(for: touches, ended: [])
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateInputs(for: touches, ended: touches)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    /// Thirds of the d-pad, same split as `ButtonsInputView` for `.directional`.
    /// Corners belong to two directions; the center nub belongs to none.
    private func directions(at point: CGPoint) -> Set<FocusKey> {
        guard bounds.width > 0, bounds.height > 0, bounds.contains(point) else { return [] }
        let thirdWidth = bounds.width / 3
        let thirdHeight = bounds.height / 3
        let top = CGRect(x: 0, y: 0, width: bounds.width, height: thirdHeight)
        let bottom = CGRect(x: 0, y: bounds.height - thirdHeight, width: bounds.width, height: thirdHeight)
        let left = CGRect(x: 0, y: 0, width: thirdWidth, height: bounds.height)
        let right = CGRect(x: bounds.width - thirdWidth, y: 0, width: thirdWidth, height: bounds.height)
        var directions = Set<FocusKey>()
        if top.contains(point) { directions.insert(.up) }
        if bottom.contains(point) { directions.insert(.down) }
        if left.contains(point) { directions.insert(.left) }
        if right.contains(point) { directions.insert(.right) }
        return directions
    }
    
    private func updateInputs(for touches: Set<UITouch>, ended: Set<UITouch>) {
        for touch in ended {
            touchDirections[touch] = nil
        }
        for touch in touches where touchDirections[touch] != nil {
            touchDirections[touch] = directions(at: touch.location(in: self))
        }
        let now = touchDirections.values.reduce(into: Set<FocusKey>()) { $0.formUnion($1) }
        let activated = now.subtracting(activeDirections)
        let deactivated = activeDirections.subtracting(now)
        activeDirections = now
        for key in deactivated {
            FocusSystem.shared.keyUp(key)
        }
        if !activated.isEmpty {
            for key in activated {
                FocusSystem.shared.keyDown(key)
            }
            UIDevice.generateHaptic()
        }
        let transform = Self.tilt(for: now)
        if now.isEmpty {
            effect.release { [weak self] in
                self?.imageView.transform3D = CATransform3DIdentity
            }
        } else if !activated.isEmpty || !deactivated.isEmpty {
            effect.press { [weak self] in
                self?.imageView.transform3D = transform
            }
        }
    }
    
    /// Per-direction tilt from `DynamicEffectView.pressEffect`. Diagonals combine the two arms.
    private static func tilt(for directions: Set<FocusKey>) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 500.0
        if directions.contains(.up) {
            transform = CATransform3DScale(CATransform3DTranslate(CATransform3DRotate(transform, .pi / 10, 1, 0, 0), 0, -1.75, 0), 0.95, 1, 1)
        }
        if directions.contains(.down) {
            transform = CATransform3DScale(CATransform3DTranslate(CATransform3DRotate(transform, -.pi / 10, 1, 0, 0), 0, 1.75, 0), 0.95, 1, 1)
        }
        if directions.contains(.left) {
            transform = CATransform3DScale(CATransform3DTranslate(CATransform3DRotate(transform, -.pi / 10, 0, 1, 0), -1.75, 0, 0), 1, 0.95, 1)
        }
        if directions.contains(.right) {
            transform = CATransform3DScale(CATransform3DTranslate(CATransform3DRotate(transform, .pi / 10, 0, 1, 0), 1.75, 0, 0), 1, 0.95, 1)
        }
        return transform
    }
}
