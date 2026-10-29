//
//  ASSheet.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ASSheet {
    ///Conveniently construct a sheet pop-up.
    ///Except for the custom type, it will automatically handle the indentation issues at the top and bottom.
    enum Style {
        enum OptionsType {
            case simple, radio, check, chevron
        }
        
        case listPage(ASListPage)
        case options(icon: ASIcon,
                     title: String,
                     detail: ASText? = nil,
                     options: [[String]],
                     selectedIndexPath: IndexPath? = nil,
                     cancelEnable: Bool = true,
                     optionsType: OptionsType = .radio)
        case simpleList(icon: ASIcon? = nil,
                        title: String = "",
                        detail: ASText? = nil,
                        options: [[ASListPage.Cell]],
                        cancelEnable: Bool = true)
        case text(title: String? = nil,
                  detail: String,
                  detailAlignment: NSTextAlignment = .center,
                  buttonTitle: String? = nil,
                  buttonTitleColor: UIColor = R.Color.LabelSecondary,
                  destructiveButtonTitle: String? = nil,
                  destructiveButtonTitleColor: UIColor = R.Color.Main)
        case updation(title: String, detail: String)
        case step(title: String? = nil,
                  detail: String? = nil,
                  step: ASStep)
        case picker(title: String? = nil,
                    detail: String? = nil,
                    datas: [String],
                    selectedIndex: Int = 0)
        case custom(UIView, constraintMaker: (ConstraintMaker) -> Void)
    }
    
    enum Action {
        case listPage(ASListPage.Action)
        case text(tapIndex: Int)
        case update
        case step(ASStep)
        case picker(index: Int, value: String)
        case tapBackground
        
        var listPageValue: ASListPage.Action? {
            if case .listPage(let value) = self {
                return value
            }
            return nil
        }
        
        var textValue: Int? {
            if case .text(let value) = self {
                return value
            }
            return nil
        }
        
        var isUpdate: Bool {
            if case .update = self {
                return true
            }
            return false
        }
        
        var stepValue: ASStep? {
            if case .step(let value) = self {
                return value
            }
            return nil
        }
        
        var pickerValue: (index: Int, value: String)? {
            if case let .picker(index, value) = self {
                return (index, value)
            }
            return nil
        }
        
        var isTapBackground: Bool {
            if case .tapBackground = self {
                return true
            }
            return false
        }
    }
    
    var style: Style
    var enableGrabber: Bool = true
    var panGestureShouldBegin: ((UIPanGestureRecognizer) -> Bool)? = nil
    var enableTapBackgroundDismiss: Bool = true
    var enableBackgroundDecoration: Bool = true
    var enableStackDepthEffect: Bool = false
    var fullScreenForLandscape: Bool = false
    var overrideUserInterfaceStyle: UIUserInterfaceStyle? = nil
    
    static func moreSettingsSheet(icon: ASIcon = .symbolImage(R.image.ellipsis_iconSymbols()),
                                  title: String = R.string.localizable.moreSettingTitle(),
                                  detail: String? = nil,
                                  options: [[ASListPage.Cell]]) -> Self {
        var detailText: ASText? = nil
        if let detail {
            detailText = .smallText(detail, numberOfLines: 0)
        }
        return ASSheet(style: .simpleList(icon: icon,
                                          title: title,
                                          detail: detailText,
                                          options: options))
    }
}
