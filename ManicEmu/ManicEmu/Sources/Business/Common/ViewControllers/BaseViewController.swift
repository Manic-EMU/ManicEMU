//
//  BaseViewController.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/25.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class BaseViewController: UIViewController {
    fileprivate var orientationNotification: Any? = nil
    
    private var fullScreen: Bool = false
    
    /// present的时候 是否需要隐藏背景的阴影视图
    var hideDimmingViewWhenPresent: Bool {
        if PlayViewController.isGaming {
            return true
        }
        
        if let presentingViewController, String(describing: type(of: presentingViewController)) == "SheetTarget" {
            return true
        }
        
        return false
    }
    
    var enableBackgroundMask: Bool = true {
        didSet {
            backgroundMaskView?.isHidden = !enableBackgroundMask
        }
    }
    
    var backgroundMaskView: PageBackgroundMaskView? = nil
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        Log.verbose("⚠️ \(objectInfo(self)) init")
        initConfigs()
    }
    
    init(fullScreen: Bool) {
        super.init(nibName: nil, bundle: nil)
        Log.verbose("⚠️ \(objectInfo(self)) init")
        self.fullScreen = fullScreen
        initConfigs()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        Log.verbose("⚠️ \(objectInfo(self)) init")
        initConfigs()
    }
    
    func initConfigs() {
        if UIDevice.isPad {
            modalPresentationStyle = .formSheet
            preferredContentSize = R.Size.PreferredContentSize
        }
        if fullScreen {
            modalPresentationStyle = .overFullScreen
        } else if let sheetPresentationController {
            sheetPresentationController.preferredCornerRadius = R.Size.CornerRadiusLarge
        }
        
        setupScreenEdgePanGestures()
    }
    
    deinit {
        Log.verbose("✅ \(objectInfo(self)) deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let backgroundColor = R.Color.BackgroundPrimary
        view.backgroundColor = backgroundColor
        if let navigationBar = self.navigationController?.navigationBar {
            navigationBar.isTranslucent = false
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundColor
            appearance.shadowColor = .clear
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
        }
        
        if UIDevice.isPhone {
            let maskView = PageBackgroundMaskView()
            view.insertSubview(maskView, at: 0)
            maskView.snp.makeConstraints { make in
                make.leading.top.trailing.equalToSuperview()
                make.height.equalTo(R.Size.PageBackgroundMaskHeight)
            }
            maskView.isHidden = !enableBackgroundMask
            backgroundMaskView = maskView
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let presentingViewController = self.presentingViewController, hideDimmingViewWhenPresent {
            presentingViewController.view.superview?.subviews.forEach({ view in
                if String(describing: type(of: view)) == "UIDimmingView" {
                    view.isHidden = true
                }
            })
        }
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }
    
    override var presentingViewController: UIViewController? {
        if let vc = super.presentingViewController {
            return vc
        } else if let vc = self.navigationController?.presentingViewController {
            return vc
        }
        return nil
    }
    
    /// Presented pages own a FocusKit context. Home tabs are sibling roots activated by HomeViewController.
    /// Live emulation keeps FocusKit off; a paused game (GameOptions, etc.) can take a context.
    var shouldManageFocusContext: Bool {
        presentingViewController != nil && !PlayViewController.isEmulationActive
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldManageFocusContext {
            pushOverlayFocusContext()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if shouldManageFocusContext {
            popFocusContext()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        OrientationLockPin.resistPortraitTransitionIfNeeded(to: size)
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.setPreferredContentSize()
            self?.backgroundMaskView?.snp.updateConstraints { make in
                make.height.equalTo(R.Size.PageBackgroundMaskHeight)
            }
        })
    }
    
    override var prefersStatusBarHidden: Bool {
        if UIDevice.isPad {
            return UIDevice.isLandscape
        }
        return super.prefersStatusBarHidden
    }
    
    fileprivate func setPreferredContentSize() {
        if UIDevice.isPad {
            if let _ = self.presentingViewController { //如果自己是被present出来的话 就执行
                let size = R.Size.PreferredContentSize
                if self.preferredContentSize != size {
                    self.preferredContentSize = size
                }
            }
        }
    }
    
    fileprivate func setupScreenEdgePanGestures() {
        let delegate = (self as? UIGestureRecognizerDelegate) ?? nil
        view.addScreenEdgePanGesture(edges: .left, handler: { [weak self] gesture in
            if gesture.state == .began {
                guard let self = self else { return }
                self.handleScreenPanGesture(edges: .left, gesture: gesture)
            }
        }).delegate = delegate
        
        view.addScreenEdgePanGesture(edges: .right, handler: { [weak self] gesture in
            if gesture.state == .began {
                guard let self = self else { return }
                self.handleScreenPanGesture(edges: .right, gesture: gesture)
            }
        }).delegate = delegate
    }
    
    func handleScreenPanGesture(edges: UIRectEdge, gesture: UIScreenEdgePanGestureRecognizer) { }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.left, .right]
    }
    
    @available(iOS 26.0, *)
    override var prefersInterfaceOrientationLocked: Bool {
        OrientationLockPin.prefersLocked
    }
    
}
