//
//  ASSheetView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import ProHUD

class ASSheetView: BaseView {
    enum ActionResult {
        //After the sheet is hidden, the completion task will be executed
        case dismiss(completion: (() -> Void)? = nil)
        case none
        
        var dismissValue: (dismiss: Bool, completion: (() -> Void)?) {
            if case .dismiss(let completion) = self {
                return (true, completion)
            }
            return (false, nil)
        }
    }
    
    typealias ASSheetViewUpdation = ((ASSheet.Style) -> Void)
    typealias ASSheetViewAction = ((ASSheet.Action, ASSheetViewUpdation?) -> ActionResult)
    typealias ASSheetRefreshData = (contentView: UIView,
                                    sheetView: SheetProvider.Target,
                                    action: ASSheetViewAction?,
                                    sheetData: ASSheet)
    
    ///The bottom of the sheet defaults to always being in the safe area.
    ///When the sheet passed in is a list page, be careful not to add the safe area again.
    static func show(_ sheet: ASSheet,
                     identifier: String? = nil,
                     enableMultiInstance: Bool = false,
                     action: ASSheetViewAction? = nil,
                     showSuccess: ((SheetTarget) -> Void)? = nil,
                     dismiss: (()->Void)? = nil,
                     preferredFocusView: (() -> UIView?)? = nil) {
        Sheet { sheetView in
            
            if let identifier {
                if !enableMultiInstance {
                    Sheet.find(identifier: identifier).forEach({
                        $0.pop()
                    })
                }
                
                sheetView.identifier = identifier
            }
            
            var sheetData = sheet
            
            if let style = sheetData.overrideUserInterfaceStyle {
                sheetView.overrideUserInterfaceStyle = style
            }
            
            //Do not clip the parent container of the sheet.
            sheetView.contentView.layer.masksToBounds = false
            
            //Create a container view
            let containerView = UIView()
            
            var roundCorner: UIRectCorner {
                (UIDevice.isPad || getLayoutStyle() == .landscape || PlayViewController.menuInsets != nil || UIDevice.isPhoneDuoInnerFullScreen) ? .allCorners : [.topLeft, .topRight]
            }
            let contentView = RoundAndBorderView(roundCorner: roundCorner, borderWidth: 1.5)
            contentView.backgroundColor = R.Color.BackgroundPrimary
            containerView.addSubview(contentView)
            
            if sheetData.enableBackgroundDecoration {
                let backgroundView = BackgroundView()
                contentView.addSubview(backgroundView)
                backgroundView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
            }
            
            var heightReduction = 0.0
            
            var refreshData = (contentView, sheetView, action, sheetData)
            //Create the in-content view based on the initialization data.
            switch sheetData.style {
            case .listPage(let listPage):
                updateListPage(listPage,
                               refreshData: refreshData)
                
                
            case .options(let icon, let title, let detail, let options, let selectedIndexPath, let cancelEnable, let optionsType):
                sheetData.enableGrabber = cancelEnable
                sheetData.enableTapBackgroundDismiss = cancelEnable
                refreshData.3 = sheetData
                updateOptions(icon: icon,
                              title: title,
                              detail: detail,
                              options: options,
                              selectedIndexPath: selectedIndexPath,
                              cancelEnable: cancelEnable,
                              optionsType: optionsType,
                              refreshData: refreshData)
                
                
            case .simpleList(let icon, let title, let detail, let options, let cancelEnable):
                sheetData.enableGrabber = cancelEnable
                sheetData.enableTapBackgroundDismiss = cancelEnable
                refreshData.3 = sheetData
                updateSimpleList(icon: icon,
                                 title: title,
                                 detail: detail,
                                 options: options,
                                 cancelEnable: cancelEnable,
                                 refreshData: refreshData)
                
                
            case .text(let title,
                       let detail,
                       let detailAlignment,
                       let buttonTitle,
                       let destructiveButtonTitle):
                updateText(title: title,
                           detail: detail,
                           detailAlignment: detailAlignment,
                           buttonTitle: buttonTitle,
                           destructiveButtonTitle: destructiveButtonTitle,
                           refreshData: refreshData)
                
                
            case .updation(let title, let detail):
                heightReduction = 105
                sheetView.config.yOffsetWhenCardLayoutCenterY = heightReduction/2
                // Sheet 下拉 pan 默认 cancelsTouchesInView，会打断 UITextView 长按选区菜单；
                // 触摸落在文本视图上时禁止开始 pan。
                sheetData.panGestureShouldBegin = { gesture in
                    !Self.isTouchOnTextInputView(gesture)
                }
                updateUpdation(title: title,
                               detail: detail,
                               refreshData: refreshData)
                
            case .step(let title, let detail, let step):
                updateStep(title: title,
                           detail: detail,
                           step: step,
                           refreshData: refreshData)
                
            case .picker(let title, let detail, let datas, let selectedIndex):
                updatePicker(title: title,
                             detail: detail,
                             datas: datas,
                             selectedIndex: selectedIndex,
                             refreshData: refreshData)
                
            case .custom(let customView, let constraintMaker):
                updateCustom(customView: customView,
                             constraintMaker: constraintMaker,
                             refreshData: refreshData)
            }
            
            //Added a Grabber view, allowing you to pull down to hide the sheet.
            if sheetData.enableGrabber {
                let grabberView = UIView()
                grabberView.backgroundColor = R.Color.BackgroundQuaternary
                grabberView.layerCornerRadius = R.Size.ContentSpaceTiny/2
                containerView.addSubview(grabberView)
                grabberView.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.size.equalTo(CGSize(width: R.Size.ItemHeightLarge, height: R.Size.ContentSpaceTiny))
                    make.top.equalToSuperview().inset(R.Size.ContentSpaceTiny)
                }
            }
            sheetView.config.enableCustomViewPanGesture = sheetData.enableGrabber
            sheetView.config.panGestureShouldBegin = sheetData.enableGrabber ? sheetData.panGestureShouldBegin : nil
            
            
            //Other style configurations for the sheet
            func updateCardSize(config: SheetConfiguration) {
                if sheetData.fullScreenForLandscape, getLayoutStyle() == .landscape {
                    if UIDevice.isPhone && !UIDevice.isPhoneDuoInnerFullScreen {
                        config.cardMaxWidth = proHUDWindow()?.width
                        config.cardMaxHeight = proHUDWindow()?.height
                    } else {
                        config.cardMaxWidth = R.Size.SheetFullScreenForIpadLandscape.width
                        config.cardMaxHeight = R.Size.SheetFullScreenForIpadLandscape.height
                    }
                } else {
                    let windowMaxSize = R.Size.SheetWindowMaxSize
                    if let menuInsets = PlayViewController.menuInsets {
                        let prefferdWidth = min(windowMaxSize.width - menuInsets.left - menuInsets.right, windowMaxSize.width)
                        let prefferdHeight = min(windowMaxSize.height - menuInsets.top - menuInsets.bottom, windowMaxSize.height)
                        config.cardMaxWidth = prefferdWidth
                        config.cardMaxHeight = prefferdHeight
                        if menuInsets.bottom > 0 {
                            config.bottomEdgeInset = menuInsets.bottom
                        }
                    } else {
                        config.cardMaxWidth = windowMaxSize.width
                        config.cardMaxHeight = windowMaxSize.height
                    }
                }
            }
            updateCardSize(config: sheetView.config)
            sheetView.contentMaskView.alpha = 0
            sheetView.config.windowEdgeInset = 0
            sheetView.config.cardCornerRadius = 0
            sheetView.config.stackDepthEffect = sheetData.enableStackDepthEffect
            sheetView.config.backgroundViewMask { mask in
                if UIDevice.isDarkMode {
                    if SheetProvider.findAll().count == 0 {
                        mask.backgroundColor = .black.withAlphaComponent(0.5)
                    } else {
                        mask.backgroundColor = .clear
                    }
                } else {
                    mask.backgroundColor = .black.withAlphaComponent(0.5)
                }
            }
            
            var didNotifyCovering = false
            func isCoveringLandscapeBackground() -> Bool {
                sheetData.fullScreenForLandscape && UIDevice.isPhone && !UIDevice.isPhoneDuoInnerFullScreen && getLayoutStyle() == .landscape
            }
            func syncLandscapeBackgroundCovering() {
                let covering = isCoveringLandscapeBackground()
                guard covering != didNotifyCovering else { return }
                didNotifyCovering = covering
                NotificationCenter.default.post(name: R.NotificationName.LandscapeBackgroundFullscreenSheet, object: covering)
            }
            
            //dismiss callback
            sheetView.onViewDidAppear { sheet in
                sheet.pushOverlayFocusContext(configure: { context in
                    context.preferredFocusView = preferredFocusView
                })
                syncLandscapeBackgroundCovering()
            }
            sheetView.onViewDidDisappear { sheet in
                sheet.popFocusContext()
                dismiss?()
                if didNotifyCovering {
                    didNotifyCovering = false
                    NotificationCenter.default.post(name: R.NotificationName.LandscapeBackgroundFullscreenSheet, object: false)
                }
            }
            
            //tap background callback
            sheetView.onTappedBackground { s in
                if sheetData.enableTapBackgroundDismiss {
                    s.pop {
                        let _ = action?(ASSheet.Action.tapBackground, nil)
                    }
                } else {
                    let _ = action?(ASSheet.Action.tapBackground, nil)
                }
            }
            
            //Set view constraints
            func updateContentViewConstraints() {
                if sheetData.fullScreenForLandscape, getLayoutStyle() == .landscape {
                    contentView.snp.remakeConstraints { make in
                        make.edges.equalToSuperview()
                        if UIDevice.isPhone && !UIDevice.isPhoneDuoInnerFullScreen {
                            let windowHeight = (proHUDWindow()?.height) ?? R.Size.ApplicationWindowSize.height
                            make.height.equalTo(windowHeight)
                        } else {
                            make.height.equalTo(R.Size.SheetFullScreenForIpadLandscape.height)
                        }
                    }
                } else {
                    contentView.snp.remakeConstraints { make in
                        let windowMaxSize = R.Size.SheetWindowMaxSize
                        make.top.equalToSuperview()
                        make.leading.bottom.trailing.equalToSuperview()
                        if var height = calculateHeight(sheetData: sheetData) {
                            var maxHeight = windowMaxSize.height
                            maxHeight -= heightReduction
                            height = min(height, maxHeight)
                            height = max(height, R.Size.SheetWindowMinSize.height)
                            
                            if let _ = PlayViewController.menuInsets {
                                make.height.lessThanOrEqualTo(height)
                            } else {
                                make.height.equalTo(height)
                            }
                        } else {
                            make.height.lessThanOrEqualTo(windowMaxSize.height)
                            make.height.greaterThanOrEqualTo(R.Size.SheetWindowMinSize.height)
                        }
                    }
                }
            }
            updateContentViewConstraints()
            
            //Set how the sheet handles screen rotation.
            sheetView.config.viewWillTransitionUpdate = { [weak sheetView] _, reloadHUD in
                guard let sheetView, let cardMaxHeight = sheetView.config.cardMaxHeight else { return }
                let heightWillSet: CGFloat
                if sheetData.fullScreenForLandscape, getLayoutStyle() == .landscape {
                    if UIDevice.isPhone && !UIDevice.isPhoneDuoInnerFullScreen {
                        heightWillSet = (proHUDWindow()?.height) ?? R.Size.ApplicationWindowSize.height
                    } else {
                        heightWillSet = R.Size.SheetFullScreenForIpadLandscape.height
                    }
                } else {
                    heightWillSet = R.Size.SheetWindowMaxSize.height
                }
                let updateConstraintsFirst = cardMaxHeight >= heightWillSet
                if updateConstraintsFirst {
                    updateContentViewConstraints()
                }
                updateCardSize(config: sheetView.config)
                reloadHUD()
                if !updateConstraintsFirst {
                    updateContentViewConstraints()
                }
                contentView.roundCorner = roundCorner
                syncLandscapeBackgroundCovering()
            }
            
            //Submit custom view to Pro HUD
            sheetView.set(customView: containerView).snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            showSuccess?(sheetView)
        }
    }
    
    private static func getLayoutStyle() -> UIView.LayoutStyle {
        if let w = proHUDWindow(), w.size != .zero {
            if w.size.IsRelativelyWideRectangle {
                return .landscape
            } else {
                return .portrait
            }
        } else {
            return UIDevice.isLandscape ? .landscape : .portrait
        }
    }
    
    private static func calculateHeight(sheetData: ASSheet) -> CGFloat? {
        let containerWidth = R.Size.SheetWindowMaxSize.width
        
        switch sheetData.style {
        case .listPage(let listPage):
            return ASListPageView.calculateMinHeight(listPage: listPage,
                                                     containerWindow: proHUDWindow(),
                                                     containerWidth: containerWidth)
            
        case .options(let icon, let title, let detail, let options, let selectedIndexPath, let cancelEnable, let optionsType):
            return ASListPageView.calculateMinHeight(listPage: processInsets(for: .optionsList(icon: icon,
                                                                                               title: title,
                                                                                               detail: detail,
                                                                                               options: options,
                                                                                               selectedIndexPath: selectedIndexPath,
                                                                                               cancelEnable: cancelEnable,
                                                                                               optionsType: optionsType),
                                                                             enableGrabber: sheetData.enableGrabber),
                                                     containerWindow: proHUDWindow(),
                                                     containerWidth: containerWidth)
            
        case .simpleList(let icon, let title, let detail, let options, let cancelEnable):
            return ASListPageView.calculateMinHeight(listPage: processInsets(for: .simpleList(icon: icon,
                                                                                              title: title,
                                                                                              detail: detail,
                                                                                              options: options,
                                                                                              cancelEnable: cancelEnable),
                                                                             enableGrabber: sheetData.enableGrabber),
                                                     containerWindow: proHUDWindow(),
                                                     containerWidth: containerWidth)
            
        case .updation(_, let detail):
            var height = 0.0
            height += R.Size.NavigationHeight
            height += R.Size.ContentSpaceExtraSmall
            height += ASTextView.contentHeight(for: ASText.mediumText(detail, numberOfLines: 0),
                                               width: containerWidth - R.Size.ContentSpaceMedium*2)
            height += R.Size.ContentSpaceLarge
            height += R.Size.Border
            height += (R.Size.ButtonExtraLarge + R.Size.ContentSpaceHuge + R.Size.ContentSpaceLarge)
            return height
            
        case .custom(let view, _):
            if let customView = view as? ShowableView {
                return customView.prefferdConstraintHeight
            }
            return nil
            
        default:
            return nil
        }
    }
    
    private static func clearContentView(_ contentView: UIView) {
        contentView.subviews.filter({
            !($0.isKind(of: BackgroundView.self))
        }).forEach({
            $0.removeFromSuperview()
        })
    }
    
    private static func updateListPage(_ listPage: ASListPage,
                                       refreshData: ASSheetRefreshData) {
        let contentView = refreshData.contentView
        let sheetView = refreshData.sheetView
        let action = refreshData.action
        let enableGrabber = refreshData.sheetData.enableGrabber
        
        let listPageView = ASListPageView(processInsets(for: listPage,
                                                        enableGrabber: enableGrabber))
        contentView.addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let updation: ASSheetViewUpdation = { [weak listPageView] updateData in
            if case let .listPage(updateListPage) = updateData {
                listPageView?.updatePage(updateListPage)
            }
        }
        
        listPageView.didActionOccurred = { [weak sheetView] listPageAction in
            if let result = action?(.listPage(listPageAction), updation) {
                let dismissValue = result.dismissValue
                if dismissValue.dismiss {
                    sheetView?.pop {
                        dismissValue.completion?()
                    }
                }
            }
        }
    }
    
    private static func updateOptions(icon: ASIcon,
                                      title: String,
                                      detail: ASText? = nil,
                                      options: [[String]],
                                      selectedIndexPath: IndexPath? = nil,
                                      cancelEnable: Bool = true,
                                      optionsType: ASSheet.Style.OptionsType,
                                      refreshData: ASSheetRefreshData) {
        let contentView = refreshData.contentView
        let sheetView = refreshData.sheetView
        let action = refreshData.action
        let enableGrabber = refreshData.sheetData.enableGrabber
        
        let listPageView = ASListPageView(processInsets(for: .optionsList(icon: icon,
                                                                          title: title,
                                                                          detail: detail,
                                                                          options: options,
                                                                          selectedIndexPath: selectedIndexPath,
                                                                          cancelEnable: cancelEnable,
                                                                          optionsType: optionsType),
                                                        enableGrabber: enableGrabber))
        contentView.addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let updation: ASSheetViewUpdation = { [weak listPageView] updateData in
            if case let .options(icon, title, detail, options, selectedIndexPath, cancelEnable, optionsType) = updateData {
                listPageView?.updatePage(processInsets(for: .optionsList(icon: icon,
                                                                         title: title,
                                                                         detail: detail,
                                                                         options: options,
                                                                         selectedIndexPath: selectedIndexPath,
                                                                         cancelEnable: cancelEnable,
                                                                         optionsType: optionsType),
                                                       enableGrabber: enableGrabber))
            }
        }
        
        listPageView.didActionOccurred = { [weak sheetView] listPageAction in
            if let result = action?(.listPage(listPageAction), updation) {
                let dismissValue = result.dismissValue
                if dismissValue.dismiss {
                    sheetView?.pop {
                        dismissValue.completion?()
                    }
                }
            }
        }
    }
    
    private static func updateSimpleList(icon: ASIcon? = nil,
                                         title: String = "",
                                         detail: ASText? = nil,
                                         options: [[ASListPage.Cell]],
                                         cancelEnable: Bool = true,
                                         refreshData: ASSheetRefreshData) {
        let contentView = refreshData.contentView
        let sheetView = refreshData.sheetView
        let action = refreshData.action
        let enableGrabber = refreshData.sheetData.enableGrabber
        let listPageView = ASListPageView(processInsets(for: .simpleList(icon: icon,
                                                                         title: title,
                                                                         detail: detail,
                                                                         options: options,
                                                                         cancelEnable: cancelEnable),
                                                        enableGrabber: enableGrabber))
        
        contentView.addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let updation: ASSheetViewUpdation = { [weak listPageView] updateData in
            if case let .simpleList(icon, title, detail, options, cancelEnable) = updateData {
                listPageView?.updatePage(processInsets(for: .simpleList(icon: icon,
                                                                        title: title,
                                                                        detail: detail,
                                                                        options: options,
                                                                        cancelEnable: cancelEnable),
                                                       enableGrabber: enableGrabber))
            }
        }
        
        listPageView.didActionOccurred = { [weak sheetView] listPageAction in
            if let result = action?(.listPage(listPageAction), updation) {
                let dismissValue = result.dismissValue
                if dismissValue.dismiss {
                    sheetView?.pop {
                        dismissValue.completion?()
                    }
                }
            }
        }
    }
    
    private static func processInsets(for listPage: ASListPage, enableGrabber: Bool) -> ASListPage {
        var listPage = listPage
        if enableGrabber {
            listPage.pageInsets = .insets(top: listPage.pageInsets.top + R.Size.SheetGrabberTopInset)
        }
        return listPage
    }
    
    private static func updateText(title: String? = nil,
                                   detail: String,
                                   detailAlignment: NSTextAlignment = .center,
                                   buttonTitle: String? = nil,
                                   destructiveButtonTitle: String? = nil,
                                   refreshData: ASSheetRefreshData) {
        
        let contentView = refreshData.contentView
        let sheetView = refreshData.sheetView
        let action = refreshData.action
        let sheetData = refreshData.sheetData
        
        clearContentView(contentView)
        
        let textSheetView = TextSheetView(title: title,
                                          detail: detail,
                                          detailAlignment: detailAlignment,
                                          buttonTitle: buttonTitle,
                                          destructiveButtonTitle: destructiveButtonTitle,
                                          enableGrabber: refreshData.sheetData.enableGrabber)
        contentView.addSubview(textSheetView)
        textSheetView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let updation: ASSheetViewUpdation = { [weak contentView, weak sheetView] updateData in
            guard let contentView, let sheetView else { return }
            if case let .text(title, detail, detailAlignment, buttonTitle, destructiveButtonTitle) = updateData {
                updateText(title: title,
                           detail: detail,
                           detailAlignment: detailAlignment,
                           buttonTitle: buttonTitle,
                           destructiveButtonTitle: destructiveButtonTitle,
                           refreshData: (contentView, sheetView, action, sheetData))
            }
        }
        
        textSheetView.didTapButton = { [weak sheetView] index in
            if let result = action?(.text(tapIndex: index), updation) {
                let dismissValue = result.dismissValue
                if dismissValue.dismiss {
                    sheetView?.pop {
                        dismissValue.completion?()
                    }
                }
            }
        }
    }
    
    private static func updateUpdation(title: String,
                                       detail: String,
                                       refreshData: ASSheetRefreshData) {
        
        let contentView = refreshData.contentView
        let sheetView = refreshData.sheetView
        let action = refreshData.action
        let sheetData = refreshData.sheetData
        
        clearContentView(contentView)
        
        let updationSheetView = UpdationSheetView(title: title,
                                                  detail: detail,
                                                  enableGrabber: refreshData.sheetData.enableGrabber)
        contentView.addSubview(updationSheetView)
        updationSheetView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let iconView = ASIconView(.image(R.image.updation_ip()!))
        if let superView = contentView.superview {
            superView.subviews.first(where: { $0.isKind(of: ASIconView.self) })?.removeFromSuperview()
            superView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                make.bottom.equalTo(contentView.snp.top).offset(R.Size.ItemHeightMedium)
            }
        }
        
        let updation: ASSheetViewUpdation = { [weak contentView, weak sheetView] updateData in
            guard let contentView, let sheetView else { return }
            if case let .updation(title, detail) = updateData {
                updateUpdation(title: title,
                               detail: detail,
                               refreshData: (contentView, sheetView, action, sheetData))
            }
        }
        
        updationSheetView.didTapButton = { [weak sheetView] in
            if let result = action?(.update, updation) {
                let dismissValue = result.dismissValue
                if dismissValue.dismiss {
                    sheetView?.pop {
                        dismissValue.completion?()
                    }
                }
            }
        }
    }
    
    /// pan 手势起点是否落在 UITextView / UITextField 上（含其子视图）
    private static func isTouchOnTextInputView(_ gesture: UIPanGestureRecognizer) -> Bool {
        guard let host = gesture.view else { return false }
        let point = gesture.location(in: host)
        var view: UIView? = host.hitTest(point, with: nil)
        while let current = view {
            if current is UITextView || current is UITextField {
                return true
            }
            if current === host { break }
            view = current.superview
        }
        return false
    }
    
    private static func updateStep(title: String? = nil,
                                   detail: String? = nil,
                                   step: ASStep,
                                   refreshData: ASSheetRefreshData) {
        
        let contentView = refreshData.contentView
        let sheetView = refreshData.sheetView
        let action = refreshData.action
        let sheetData = refreshData.sheetData
        
        clearContentView(contentView)
        
        let stepSheetView = StepSheetView(title: title,
                                          detail: detail,
                                          step: step,
                                          enableGrabber: refreshData.sheetData.enableGrabber)
        contentView.addSubview(stepSheetView)
        stepSheetView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let updation: ASSheetViewUpdation = { [weak contentView, weak sheetView] updateData in
            guard let contentView, let sheetView else { return }
            if case let .step(title, detail, step) = updateData {
                updateStep(title: title,
                           detail: detail,
                           step: step,
                           refreshData: (contentView, sheetView, action, sheetData))
            }
        }
        
        stepSheetView.didStepChange = { [weak sheetView] value in
            if let result = action?(.step(value), updation) {
                let dismissValue = result.dismissValue
                if dismissValue.dismiss {
                    sheetView?.pop {
                        dismissValue.completion?()
                    }
                }
            }
        }
    }
    
    private static func updatePicker(title: String? = nil,
                                     detail: String? = nil,
                                     datas: [String],
                                     selectedIndex: Int,
                                     refreshData: ASSheetRefreshData) {
        
        let contentView = refreshData.contentView
        let sheetView = refreshData.sheetView
        let action = refreshData.action
        let sheetData = refreshData.sheetData
        
        clearContentView(contentView)
        
        let pickerSheetView = PickerSheetView(title:title,
                                              detail: detail,
                                              datas: datas,
                                              selectedIndex: selectedIndex,
                                              enableGrabber: refreshData.sheetData.enableGrabber)
        contentView.addSubview(pickerSheetView)
        pickerSheetView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        pickerSheetView.didTapClose = { [weak sheetView] in
            sheetView?.pop()
        }
        
        let updation: ASSheetViewUpdation = { [weak contentView, weak sheetView] updateData in
            guard let contentView, let sheetView else { return }
            if case let .picker(title, detail, datas, selectedIndex) = updateData {
                updatePicker(title: title,
                             detail: detail,
                             datas: datas,
                             selectedIndex: selectedIndex,
                             refreshData: (contentView, sheetView, action, sheetData))
            }
        }
        
        pickerSheetView.didPickerChange = { [weak sheetView] element, row in
            if let result = action?(.picker(index: row, value: element), updation) {
                let dismissValue = result.dismissValue
                if dismissValue.dismiss {
                    sheetView?.pop {
                        dismissValue.completion?()
                    }
                }
            }
        }
    }
    
    private static func updateCustom(customView: UIView,
                                     constraintMaker: (ConstraintMaker) -> Void,
                                     refreshData: ASSheetRefreshData) {
        let contentView = refreshData.contentView
        
        clearContentView(contentView)
        
        let containerView = UIView()
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(customView)
        customView.snp.makeConstraints(constraintMaker)
    }
}

extension ASSheetView {
    class BackgroundView: UIImageView {
        init() {
            super.init(frame: .zero)
            backgroundColor = .clear
            contentMode = .scaleToFill
            updateImage()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func updateImage() {
            let darkTraitCollection: UITraitCollection = .init(userInterfaceStyle: .dark)
            let darkImage = R.image.sheet_bg(compatibleWith: darkTraitCollection)?.resizableImage(withCapInsets: .insets(top: R.Size.NavigationHeight),
                                                                                      resizingMode: .stretch)
            
            let lightTraitCollection: UITraitCollection = .init(userInterfaceStyle: .light)
            let lightImage = R.image.sheet_bg(compatibleWith: lightTraitCollection)?.resizableImage(withCapInsets: .insets(top: R.Size.NavigationHeight),
                                                                                      resizingMode: .stretch)
            if let darkImage, let lightImage {
                image = UIImage(.dm,
                                light: lightImage,
                                dark: darkImage)
            }
        }
    }
    
    class AutoBottomSafeAreaView: BaseView, ViewTransition {
        var bottomView: UIView? = nil
        
        func viewAlongsideTransition() {
            bottomView?.snp.updateConstraints { make in
                make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow))
            }
        }
    }
    
    class TextSheetView: AutoBottomSafeAreaView {
        
        var didTapButton: ((Int) -> Void)? = nil
        
        init(title: String? = nil,
             detail: String,
             detailAlignment: NSTextAlignment = .center,
             buttonTitle: String? = nil,
             destructiveButtonTitle: String? = nil,
             enableGrabber: Bool) {
            super.init(frame: .zero)
            
            var titleContainerView: UIView? = nil
            if let title {
                let view = UIView()
                addSubview(view)
                view.snp.makeConstraints { make in
                    make.top.equalToSuperview().offset(enableGrabber ? R.Size.SheetGrabberTopInset : 0)
                    make.leading.trailing.equalToSuperview()
                    make.height.equalTo(R.Size.NavigationHeight)
                }
                titleContainerView = view
                
                var text = ASText.extraLargeText(title)
                text.attributes?.alignment = .center
                let titleLabel = ASLabelView(text: text)
                view.addSubview(titleLabel)
                titleLabel.snp.makeConstraints { make in
                    make.center.equalToSuperview()
                }
            }
            
            
            var text = ASText.mediumText(detail, numberOfLines: 0)
            text.attributes?.alignment = detailAlignment
            let detailLabel = ASLabelView(text: text)
            addSubview(detailLabel)
            detailLabel.snp.makeConstraints { make in
                if let titleContainerView {
                    make.top.equalTo(titleContainerView.snp.bottom).offset(R.Size.ContentSpaceExtraSmall)
                } else {
                    make.top.equalToSuperview().offset(R.Size.ContentSpaceLarge + (enableGrabber ? R.Size.SheetGrabberTopInset : 0))
                }
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
            
            let horizontalLine = UIView()
            horizontalLine.backgroundColor = R.Color.Border
            addSubview(horizontalLine)
            horizontalLine.snp.makeConstraints { make in
                make.top.equalTo(detailLabel.snp.bottom).offset(R.Size.ContentSpaceLarge)
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
                make.height.equalTo(R.Size.Border)
            }
            
            let verticalLine = UIView()
            verticalLine.backgroundColor = R.Color.Border
            
            let button = ASButtonView(.quickButton(title: buttonTitle,
                                                   titleColor: R.Color.LabelSecondary,
                                                   titleFont: R.Font.Headline(),
                                                   titleAlignment: .center,
                                                   background: .clear,
                                                   sizeStyle: .fixHeight(R.Size.ButtonExtraLarge)))
            button.didTapButton = { [weak self] in
                self?.didTapButton?(0)
            }
            addSubview(button)
            
            var destructiveButton: ASButtonView? = nil
            if let destructiveButtonTitle {
                let view = ASButtonView(.quickButton(title: destructiveButtonTitle,
                                                                  titleColor: R.Color.Main,
                                                                  titleFont: R.Font.Headline(emphasis: true),
                                                                  titleAlignment: .center,
                                                                  background: .clear,
                                                                  sizeStyle: .fixHeight(R.Size.ButtonExtraLarge)))
                view.didTapButton = { [weak self] in
                    self?.didTapButton?(1)
                }
                addSubviews([view, verticalLine])
                destructiveButton = view
            }
            
            button.snp.makeConstraints { make in
                make.top.equalTo(horizontalLine.snp.bottom)
                if destructiveButtonTitle == nil {
                    make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
                } else {
                    make.leading.equalToSuperview()
                    make.trailing.equalTo(verticalLine.snp.leading)
                }
                make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow))
                make.height.equalTo(R.Size.ButtonExtraLarge)
            }
            
            if let destructiveButton {
                destructiveButton.snp.makeConstraints { make in
                    make.trailing.equalToSuperview()
                    make.top.equalTo(horizontalLine.snp.bottom)
                    make.leading.equalTo(verticalLine.snp.trailing)
                    make.height.equalTo(button)
                }
                
                verticalLine.snp.makeConstraints { make in
                    make.centerY.equalTo(button)
                    make.size.equalTo(CGSize(width: R.Size.Border, height: R.Size.ItemHeightMicro))
                    make.centerX.equalToSuperview()
                }
            }

            bottomView = button
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class UpdationSheetView: BaseView {
        
        var didTapButton: (() -> Void)? = nil
        
        init(title: String,
             detail: String,
             enableGrabber: Bool) {
            super.init(frame: .zero)
            
            let titleContainerView = UIView()
            addSubview(titleContainerView)
            titleContainerView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(enableGrabber ? R.Size.SheetGrabberTopInset : 0)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(R.Size.NavigationHeight)
            }
            let titleLabel = ASLabelView(text: .extraLargeText(title))
            titleContainerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            }
            
            let detailLabel = ASTextView(text: ASText.mediumText(detail, numberOfLines: 0))
            addSubview(detailLabel)
            detailLabel.snp.makeConstraints { make in
                make.top.equalTo(titleContainerView.snp.bottom).offset(R.Size.ContentSpaceExtraSmall)
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
            
            let horizontalLine = UIView()
            horizontalLine.backgroundColor = R.Color.Border
            addSubview(horizontalLine)
            horizontalLine.snp.makeConstraints { make in
                make.top.equalTo(detailLabel.snp.bottom).offset(R.Size.ContentSpaceLarge)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(R.Size.Border)
            }
            
            let button = ASButtonView(.quickButton(title: R.string.localizable.gotIt(),
                                                   titleColor: R.Color.Main,
                                                   titleFont: R.Font.Headline(emphasis: true),
                                                   titleAlignment: .center,
                                                   background: .clear,
                                                   sizeStyle: .fixHeight(R.Size.ButtonExtraLarge)))
            
            addSubview(button)
            button.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(horizontalLine.snp.bottom)
                make.height.equalTo(R.Size.ButtonExtraLarge)
                make.bottom.equalToSuperview().inset(R.Size.ContentSpaceLarge)
            }
            
            button.didTapButton = { [weak self] in
                self?.didTapButton?()
            }
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class StepSheetView: AutoBottomSafeAreaView {
        
        var didStepChange: ((ASStep)->Void)? = nil
        
        init(title: String? = nil,
             detail: String? = nil,
             step: ASStep,
             enableGrabber: Bool) {
            super.init(frame: .zero)
            
            var titleContainerView: UIView? = nil
            if let title {
                let view = UIView()
                addSubview(view)
                view.snp.makeConstraints { make in
                    make.top.equalToSuperview().offset(enableGrabber ? R.Size.SheetGrabberTopInset : 0)
                    make.leading.trailing.equalToSuperview()
                    make.height.equalTo(R.Size.NavigationHeight)
                }
                var text = ASText.extraLargeText(title)
                text.attributes?.alignment = .center
                let titleLabel = ASLabelView(text: text)
                view.addSubview(titleLabel)
                titleLabel.snp.makeConstraints { make in
                    make.center.equalToSuperview()
                }
                titleContainerView = view
            }
            
            var detailLabel: ASLabelView? = nil
            if let detail {
                var text = ASText.smallText(detail,
                                            color: R.Color.LabelSecondary,
                                            numberOfLines: 0)
                text.attributes?.alignment = .center
                let label = ASLabelView(text: text)
                addSubview(label)
                label.snp.makeConstraints { make in
                    if let titleContainerView {
                        make.top.equalTo(titleContainerView.snp.bottom).offset(R.Size.ContentSpaceExtraSmall)
                    } else {
                        make.top.equalToSuperview().offset(R.Size.ContentSpaceExtraSmall + R.Size.ItemHeightMedium)
                    }
                    make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                }
                detailLabel = label
            }
            
            var tempStep = step
            tempStep.spacing = R.Size.ContentSpaceHuge
            tempStep.fixedWidth = true
            tempStep.titles = tempStep.titles.map({
                var temp = $0
                temp.attributes?.font = R.Font.Body2()
                return temp
            })
            let sizeStyle = ASButton.Size.fixSize(CGSize(width: 64, height: R.Size.ButtonSmall))
            var tempDecreaseButton = tempStep.decrease
            tempDecreaseButton.sizeStyle = sizeStyle
            tempStep.decrease = tempDecreaseButton
            var tempIncreaseButton = tempStep.increase
            tempIncreaseButton.sizeStyle = sizeStyle
            tempStep.increase = tempIncreaseButton
            
            let stepView = ASStepView(tempStep)
            addSubview(stepView)
            stepView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow))
                make.height.equalTo(R.Size.ButtonSmall)
                if let detailLabel {
                    make.top.equalTo(detailLabel.snp.bottom).offset(R.Size.ContentSpaceLarge)
                } else if let titleContainerView {
                    make.top.equalTo(titleContainerView.snp.bottom).offset(R.Size.ContentSpaceLarge)
                } else {
                    make.top.equalToSuperview().offset(R.Size.ContentSpaceHuge)
                }
            }
            
            stepView.didStepChange = { [weak self] value in
                self?.didStepChange?(value)
                
            }
            
            bottomView = stepView
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class PickerSheetView: AutoBottomSafeAreaView {
        
        var didPickerChange: ((String, Int) -> Void)? = nil
        var didTapClose: (() -> Void)? = nil
        
        init(title: String? = nil,
             detail: String? = nil,
             datas: [String],
             selectedIndex: Int,
             enableGrabber: Bool) {
            super.init(frame: .zero)
            
            var titleContainerView: UIView? = nil
            if let title {
                let navigationView = ASNavigationView(.defaultNavigation(title: title))
                navigationView.didTapClose = { [weak self] in
                    self?.didTapClose?()
                }
                addSubview(navigationView)
                navigationView.snp.makeConstraints { make in
                    make.top.equalToSuperview().offset(enableGrabber ? R.Size.SheetGrabberTopInset : 0)
                    make.leading.trailing.equalToSuperview()
                    make.height.equalTo(R.Size.ItemHeightMedium)
                }
                titleContainerView = navigationView
            }
            
            var detailLabel: ASLabelView? = nil
            if let detail {
                var text = ASText.mediumText(detail, numberOfLines: 0)
                text.attributes?.alignment = .center
                let label = ASLabelView(text: text)
                addSubview(label)
                label.snp.makeConstraints { make in
                    if let titleContainerView {
                        make.top.equalTo(titleContainerView.snp.bottom).offset(R.Size.ContentSpaceExtraSmall)
                    } else {
                        make.top.equalToSuperview().offset(R.Size.ContentSpaceExtraSmall + R.Size.ItemHeightMedium)
                    }
                    make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                }
                detailLabel = label
            }
            
            
            let pickerView = UIPickerView()
            addSubview(pickerView)
            pickerView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
                if let detailLabel {
                    make.top.equalTo(detailLabel.snp.bottom).offset(R.Size.ContentSpaceExtraSmall)
                } else if let titleContainerView {
                    make.top.equalTo(titleContainerView.snp.bottom).offset(R.Size.ContentSpaceExtraSmall)
                } else {
                    make.top.equalToSuperview().offset(R.Size.ItemHeightMedium)
                }
                make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom(window: hostingWindow))
                make.height.equalTo(300).priority(.high)
            }
            pickerView.addComponents([datas]) { [weak self] element, component, row in
                self?.didPickerChange?(element, row)
            }
            pickerView.isFocusable = true
            pickerView.focusCommands = [
                FocusCommand(key: .up, title: R.string.localizable.focusHintAdjust(), action: { [weak pickerView, weak self] in
                    guard let pickerView else { return }
                    let row = pickerView.selectedRow(inComponent: 0)
                    guard row > 0 else { return }
                    pickerView.selectRow(row - 1, inComponent: 0, animated: true)
                    self?.didPickerChange?(datas[row - 1], row - 1)
                }),
                FocusCommand(key: .down, title: R.string.localizable.focusHintAdjust(), action: { [weak pickerView, weak self] in
                    guard let pickerView else { return }
                    let row = pickerView.selectedRow(inComponent: 0)
                    guard row < datas.count - 1 else { return }
                    pickerView.selectRow(row + 1, inComponent: 0, animated: true)
                    self?.didPickerChange?(datas[row + 1], row + 1)
                })
            ]
            
            if selectedIndex > 0 {
                DispatchQueue.main.asyncAfter(delay: 0.35, execute: { [weak pickerView] in
                    pickerView?.selectRow(selectedIndex, inComponent: 0, animated: true)
                })
            }
            
            bottomView = pickerView
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
