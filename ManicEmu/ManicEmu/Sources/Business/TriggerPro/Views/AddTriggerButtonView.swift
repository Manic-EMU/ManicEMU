//
//  AddTriggerButtonView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/10/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit
import RealmSwift
import BetterSegmentedControl
import IceCream

class AddTriggerButtonView: BaseView {
    
    private lazy var buttonStyleView: AddTriggerButtonStyleView = {
        let view = AddTriggerButtonStyleView(item: triggerItem)
        view.needToUpdateCellHeight = { [weak self] in
            guard let self else { return }
            self.listPageView.sections = self.getSections()
        }
        return view
    }()
    
    private lazy var mappingListView: AddTriggerMappingListView = {
        let view = AddTriggerMappingListView(triggerItem: triggerItem)
        view.didTapAddMapping = { [weak self] updateViews in
            guard let self else { return }
            TriggerProMappingListView.show(inputs: self.inputs,
                                           gameType: self.gameType) { [weak self] input in
                guard let self else { return }
                self.triggerItem.mappings.append(input)
                updateViews?()
            }
        }
        return view
    }()
    
    private lazy var actionView: AddTriggerActionView = {
        let view = AddTriggerActionView(triggerItem: triggerItem)
        view.didActionChange = { [weak self ] in
            guard let self else { return }
            DispatchQueue.main.asyncAfter(delay: 0.35) { [weak self ] in
                guard let self else { return }
                self.listPageView.sections = self.getSections()
            }
        }
        return view
    }()
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(.init(navigation: .defaultNavigation(title: "TriggerPro",
                                                                       titleIcon: .symbolImage(R.image.triggerpro_iconSymbols())),
                                        sections: getSections(),
                                        backgroundColor: .clear,
                                        listInsets: .insets(bottom: R.Size.ContentInsetBottom(window: hostingWindow)),
                                        pageInsets: .insets(top: R.Size.SheetGrabberTopInset)))
        
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            if let navigationValue = action.navigationValue {
                if navigationValue.isTapClose {
                    if self.triggerItem.mappings.count == 0 {
                        UIView.makeAlert(title: R.string.localizable.fatalErrorTitle(),
                                         detail: R.string.localizable.noMappingAlert(),
                                         confirmTitle: R.string.localizable.multiDiscContinueClose(),
                                         confirmAction: { [weak self] in
                            self?.hide()
                        })
                        return
                    }
                    self.hide()
                }
            }
        }
        return view
    }()
    
    private var triggerItem: TriggerItem
    private let gameType: GameType
    private let inputs: [String]
    var hideCompletion: (() -> Void)? = nil
    
    required init?(parameters: Any...) {
        guard let triggerItem = parameters.compactMap({ $0 as? TriggerItem }).first else { return nil }
        guard let gameType = parameters.compactMap({ $0 as? GameType }).first else { return nil }
        guard let inputs = parameters.compactMap({ $0 as? [String] }).first else { return nil }
        self.triggerItem = triggerItem
        self.gameType = gameType
        self.inputs = inputs
        super.init(frame: .zero)
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getSections() -> [ASListPage.Section] {
        var sections = [ASListPage.Section]()
        sections.append(.init(cells: [.custom(buttonStyleView)],
                              header: .defaultHeader(title: R.string.localizable.buttonStyle()),
                              itemLayout: .fixedHeight(triggerItem.style.cellHeight)))
        sections.append(.init(cells: [.custom(mappingListView)],
                              header: .defaultHeader(title: R.string.localizable.mapping()),
                              itemLayout: .fixedHeight(72)))
        sections.append(.init(cells: [.custom(actionView)],
                              header: .texts([
                                .init(attributes: .init(text: R.string.localizable.action(),
                                                        color: R.Color.LabelSecondary,
                                                        font: R.Font.Subheadline(emphasis: true))),
                                .init(attributes: .init(text: triggerItem.action.desc,
                                                        color: R.Color.LabelSecondary,
                                                        font: R.Font.Footnote(),
                                                        numberOfLines: 0),
                                      textIcons: [.init(icon: .symbolImage(R.image.infoFill_iconSymbols()),
                                                        iconSize: 14)])
                              ], pin: false),
                              itemLayout: .fixedHeight(216)))
        return sections
    }
}

extension AddTriggerButtonView: ShowableView {
    static func show(triggerItem: TriggerItem, gameType: GameType, inputs: [String], hideCompletion: (() -> Void)? = nil) {
        Self.show(parameters: triggerItem, gameType, inputs)?.hideCompletion = hideCompletion
    }
    
    func didHide() {
        hideCompletion?()
    }
}
