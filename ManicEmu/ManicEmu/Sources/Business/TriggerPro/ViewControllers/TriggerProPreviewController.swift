//
//  TriggerProPreviewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/10/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit

import AVFoundation
import RealmSwift

class TriggerProPreviewController: BaseViewController {
    
    private var skin: ControllerSkin {
        didSet {
            controlView.controllerSkin = skin
        }
    }
    private let defaultSkin: ControllerSkin
    private let traits: ControllerSkin.Traits
    private let trigger: Trigger ///不是真正的数据库对象
    private let isNewTrigger: Bool
    
    private lazy var supportSkins: [ControllerSkin] = {
        let realm = Database.realm
        let skins = realm.objects(Skin.self).where({ $0.gameType == self.skin.gameType })
        let controllerSkins = skins.compactMap({
            if let cs = ControllerSkin(fileURL: $0.fileURL), cs.supports(self.traits) {
                return cs
            }
            return nil
        })
        return Array(controllerSkins)
    }()
    
    private lazy var controlView: ControllerView = {
        let view = ControllerView()
        view.overrideControllerSkinTraits = traits
        view.controllerSkin = skin
        view.alpha = hideControls ? 0 : 1
        return view
    }()
    
    private var gameViewBackgroundView: UIImageView = {
        let view = UIImageView(image: R.image.triggerPro_bg())
        view.contentMode = .scaleAspectFill
        view.masksToBounds = true
        return view
    }()
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.init(tools: [.symbolImage(R.image.ellipsis_iconSymbols())]))
        view.didTapTools = { [weak self] _ in
            guard let self else { return }
            //more
            ChevronSheetView.show(stringOptions: [
                R.string.localizable.switchPreviewSkin(),
                R.string.localizable.hideControlsTitle()
            ], completion: { [weak self] index in
                guard let self, let index else { return }
                if index == 0 {
                    //switch preview skin
                    ChevronSheetView.show(icon: .symbolImage(R.image.skin_iconSymbols()),
                                          title: R.string.localizable.switchPreviewSkin(),
                                          stringOptions: self.supportSkins.map({ $0.name }),
                                          completion: { [weak self] skinIndex in
                        guard let self, let skinIndex else { return }
                        self.skin = self.supportSkins[skinIndex]
                        self.hideControls = false
                    })
                    
                } else if index == 1 {
                    //hide controls
                    self.hideControls = true
                }
            })
        }
        
        view.didTapClose = { [weak self] in
            self?.dismiss(animated: true)
            self?.storeTrigger()
        }
        return view
        
    }()
    
    private lazy var addButton: UIView = {
        let view = UIView()
        view.enablePressEffect = true
        view.enableFocusEffects = false
        let iconContainerView = RoundAndBorderView(roundCorner: .allCorners, radius: R.Size.CornerRadiusMedium)
        iconContainerView.backgroundColor = R.Color.BackgroundPrimary
        view.addSubview(iconContainerView)
        iconContainerView.snp.makeConstraints { make in
            make.size.equalTo(64)
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        
        let iconView = UIImageView(image: UIImage(symbol: .plusCircleFill, font: R.Font.Footnote(emphasis: true), colors: [R.Color.BackgroundPrimary, R.Color.LabelPrimary]))
        iconContainerView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(35)
        }
        
        let label = UILabel()
        label.font = R.Font.Body(emphasis: true)
        label.textColor = R.Color.LabelPrimary.forceStyle(.dark)
        label.text = R.string.localizable.addButton()
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalTo(iconContainerView.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            let item = TriggerItem()
            self.trigger.items.append(item)
            AddTriggerButtonView.show(triggerItem: item,
                                      gameType: self.trigger.gameType,
                                      inputs: self.getInputs(),
                                      hideCompletion: { [weak self] in
                guard let self else { return }
                self.triggerProView.reloadButtons()
            })
            self.triggerProView.reloadButtons()
        }
        
        return view
    }()
    
    private lazy var titleTextField: UITextField = {
        let view = UITextField()
        view.textColor = R.Color.LabelPrimary
        view.font = R.Font.Body()
        view.clearButtonMode = .always
        view.text = trigger.name ?? ""
        view.onReturnKeyPress { [weak self] in
            guard let self = self else { return }
            self.trigger.name = self.titleTextField.text
        }
        view.attributedPlaceholder = NSAttributedString(string: trigger.defaultName, attributes: [.font: R.Font.Body(), .foregroundColor: R.Color.LabelTertiary])
        view .returnKeyType = .done
        view.isFocusable = true
        view.onFocusConfirm = { [weak self] in
            self?.titleTextField.becomeFirstResponder()
            return true
        }
        return view
    }()
    
    private lazy var triggerProView: TriggerProView = {
        let view = TriggerProView(trigger: trigger, isEditMode: true)
        view.didTapButton = { [weak self] item in
            guard let self else { return }
            UIView.makeAlert(title: R.string.localizable.buttonInfo(),
                             detail: item.desc,
                             detailAlignment: .left,
                             cancelTitle: R.string.localizable.editTitle(),
                             confirmTitle: R.string.localizable.removeTitle(),
                             cancelAction: { [weak self] in
                guard let self else { return }
                //编辑
                AddTriggerButtonView.show(triggerItem: item, gameType: self.trigger.gameType, inputs: self.getInputs(), hideCompletion: { [weak self] in
                    guard let self else { return }
                    self.triggerProView.reloadButtons()
                })
            }, confirmAction: { [weak self] in
                guard let self else { return }
                if let index = self.trigger.items.firstIndex(of: item) {
                    self.trigger.items.remove(at: index)
                    self.triggerProView.reloadButtons()
                }
            })
        }
        return view
    }()

    private var hideControls: Bool {
        didSet {
            controlView.alpha = hideControls ? 0 : 1
        }
    }
    
    init(gameType: GameType,
         trigger: Trigger? = nil,
         preferredSkinID: String? = nil,
         hideControls: Bool = false,
         window: UIWindow) {
        let realm = Database.realm
        self.defaultSkin = ControllerSkin.standardControllerSkin(for: gameType)!
        if let preferredSkinID,
            let preferredSkin = realm.objects(Skin.self).where({ $0.id == preferredSkinID}).first,
            let preferredControllerSkin = ControllerSkin(fileURL: preferredSkin.fileURL) {
            self.skin = preferredControllerSkin
        } else {
            self.skin = self.defaultSkin
        }
        self.traits = ControllerSkin.Traits.defaults(for: UIWindow.applicationWindow ?? UIWindow(frame: .init(origin: .zero, size: R.Size.ApplicationWindowSize)))
        if let trigger {
            //将数据库实例转换为临时实例 为了更方便的修改 保存的时候统一修改数据库
            self.trigger = trigger.copyTrigger()
            self.isNewTrigger = false
        } else {
            self.trigger = Trigger()
            self.trigger.gameType = gameType
            self.isNewTrigger = true
        }
        self.hideControls = hideControls
        super.init(fullScreen: true)
        
        self.enableBackgroundMask = false
        
        view.addSubview(controlView)
        
        var needToRotate = false
        if traits.orientation == .portrait && window.size.IsRelativelyWideRectangle {
            needToRotate = true
        } else if traits.orientation == .landscape && !window.size.IsRelativelyWideRectangle {
            needToRotate = true
        }
        
        if needToRotate {
            controlView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                if let aspectRatio = skin.aspectRatio(for: traits) {
                    let frame = AVMakeRect(aspectRatio: aspectRatio, insideRect: CGRect(origin: .zero, size: R.Size.ApplicationWindowSize.swapSide))
                    make.size.equalTo(frame.size)
                }
            }
            controlView.transform = .init(rotationAngle: .pi/2)
        } else {
            controlView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                if let aspectRatio = skin.aspectRatio(for: traits) {
                    let frame = AVMakeRect(aspectRatio: aspectRatio, insideRect: CGRect(origin: .zero, size: R.Size.ApplicationWindowSize))
                    make.size.equalTo(frame.size)
                }
            }
        }
        
        view.addSubview(navigationView)
        updateNavigationViewConstraints()
        
        if let skinFrames = skin.getFrames(window: window) {
            controlView.addSubview(gameViewBackgroundView)
            gameViewBackgroundView.snp.makeConstraints { make in
                make.leading.equalTo(skinFrames.mainGameViewFrame.minX)
                make.top.equalTo(skinFrames.mainGameViewFrame.minY)
                make.size.equalTo(skinFrames.mainGameViewFrame.size)
            }
            
            view.addSubview(addButton)
            addButton.snp.makeConstraints { make in
                make.center.equalTo(gameViewBackgroundView)
            }
            
            let titleEditTextContainerView = UIView()
            titleEditTextContainerView.layerCornerRadius = R.Size.CornerRadiusMedium
            titleEditTextContainerView.backgroundColor = R.Color.BackgroundPrimary
            view.addSubview(titleEditTextContainerView)
            titleEditTextContainerView.snp.makeConstraints { make in
                make.top.equalTo(addButton.snp.bottom).offset(40)
                if UIDevice.isPhone {
                    make.leading.trailing.equalTo(gameViewBackgroundView).inset(R.Size.ContentSpaceMedium)
                } else {
                    make.width.equalTo(380)
                    make.centerX.equalTo(addButton)
                }
            }
            
            let titleEditLabel = UILabel()
            titleEditLabel.text = R.string.localizable.triggerProName()
            titleEditLabel.font = R.Font.Body(emphasis: true)
            titleEditLabel.textColor = R.Color.LabelPrimary
            titleEditTextContainerView.addSubview(titleEditLabel)
            titleEditLabel.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceLarge)
                make.top.equalToSuperview().inset(R.Size.ContentSpaceSmall)
            }
            
            let textFieldContainer = RoundAndBorderView(roundCorner: .allCorners, radius: R.Size.CornerRadiusMedium)
            textFieldContainer.backgroundColor = R.Color.InputBox
            titleEditTextContainerView.addSubview(textFieldContainer)
            textFieldContainer.snp.makeConstraints { make in
                make.top.equalTo(titleEditLabel.snp.bottom).offset(R.Size.ContentSpaceExtraSmall)
                make.leading.bottom.trailing.equalToSuperview().inset(R.Size.ContentSpaceSmall)
                make.height.equalTo(R.Size.ItemHeightExtraSmall)
            }
            
            textFieldContainer.addSubview(titleTextField)
            titleTextField.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
        }
        
        view.addSubview(triggerProView)
        triggerProView.snp.makeConstraints { make in
            make.edges.equalTo(controlView)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch UIDevice.currentOrientation {
        case .portrait:
            AppDelegate.orientation = .portrait
        case .portraitUpsideDown:
            AppDelegate.orientation = .portraitUpsideDown
        case .landscapeLeft:
            AppDelegate.orientation = .landscapeLeft
        case .landscapeRight:
            AppDelegate.orientation = .landscapeRight
        default: break
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppDelegate.orientation = R.Config.DefaultOrientation
    }
    
    override var prefersStatusBarHidden: Bool {
        if UIDevice.isPhoneDuo {
             return true
        }
        return super.prefersStatusBarHidden
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if UIDevice.isPhoneDuo {
            updateNavigationViewConstraints()
        }
    }
    
    private func updateNavigationViewConstraints() {
        navigationView.snp.remakeConstraints { make in
            if UIDevice.isPhoneDuoOuter && UIDevice.currentOrientation == .landscapeRight {
                if let cameraArea = DuoLayoutKit.sideStrip()?.cameraArea() {
                    make.leading.equalToSuperview().inset(cameraArea.width - R.Size.ContentSpaceMedium)
                    make.top.equalToSuperview().offset((cameraArea.height - R.Size.NavigationHeight)/2)
                } else {
                    make.leading.equalToSuperview().inset(R.Size.iPhoneDuoOuterCameraEdge + R.Size.iPhoneDuoOuterCameraSize.width - R.Size.ContentSpaceMedium)
                    make.top.equalToSuperview().offset(R.Size.iPhoneDuoOuterCameraEdge)
                }
                make.trailing.equalToSuperview()
            } else {
                if UIDevice.isPhoneDuo {
                    make.leading.equalToSuperview()
                    if UIDevice.isPhoneDuoOuter {
                        make.top.equalToSuperview().offset(21.5)
                        make.trailing.equalToSuperview().inset(64)
                    } else {
                        make.trailing.equalToSuperview()
                        make.top.equalToSuperview().offset(UIDevice.isPhoneDuoSplitView ? R.Size.ContentSpaceLarge : R.Size.ContentInsetTop(window: hostingWindow))
                    }
                } else {
                    make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
                    make.top.equalToSuperview().offset(R.Size.ContentInsetTop(window: hostingWindow))
                }
            }
            make.height.equalTo(R.Size.NavigationHeight)
        }
    }
    
    private func getInputs() -> [String] {
        if let inputs = defaultSkin.gameType.manicEmuCore?.allInputs {
            return inputs.compactMap({ ($0.stringValue == "flex" || $0.stringValue.contains("touchScreen")) ? nil : $0.stringValue })
        }
        return []
    }
    
    private func storeTrigger() {
        if isNewTrigger {
            //新增Trigger
            if trigger.items.count > 0 {
                Trigger.change { realm in
                    realm.add(trigger)
                }
            }
        } else {
            //更新已有Trigger
            let realm = Database.realm
            if let originTrigger = realm.objects(Trigger.self).where({ $0.id == trigger.id }).first {
                if originTrigger.isCompleteEqual(trigger: trigger) {
                    Log.debug("Trigger没有变更!!!")
                } else {
                    originTrigger.update(realm: realm, trigger: trigger)
                }
            }
        }
    }
}
