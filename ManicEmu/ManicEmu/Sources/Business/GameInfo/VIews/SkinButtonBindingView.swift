//
//  SkinButtonBindingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/9/15.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class SkinButtonBindingView: BaseView {
    private let games: [Game]
    private var mapping: [FLASHSkinButton: FLASHKey]

    private lazy var listView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        return view
    }()

    required init?(parameters: Any...) {
        let games: [Game]
        if let list = parameters.first as? [Game], !list.isEmpty {
            games = list
        } else if let game = parameters.first as? Game {
            games = [game]
        } else {
            return nil
        }
        self.games = games
        self.mapping = FLASHSkinButton.mapping(from: games)
        super.init(frame: .zero)

        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func currentKey(for button: FLASHSkinButton) -> FLASHKey {
        mapping[button] ?? button.defaultKey
    }

    private func getListPage() -> ASListPage {
        var navigation = ASListPage.Navigation.defaultNavigation(
            title: GameOption.skinButtonBinding.title,
            titleIcon: GameOption.skinButtonBinding.icon,
            tools: [.symbolImage(R.image.refresh_iconSymbols())]
        )
        navigation.enableClose = true
        var sections = FLASHSkinButton.allCases.map { button in
            ASListPage.Section(cells: [
                .iconTitleDetailChevronCell(
                    icon: button.icon,
                    title: button.title,
                    chevronTitle: currentKey(for: button).title
                )
            ])
        }
        sections[0].header = .texts([.smallText(R.string.localizable.skinButtonBindingDesc())], pin: false)
        return ASListPage(
            navigation: navigation,
            sections: sections,
            backgroundColor: .clear,
            pageInsets: .insets(top: R.Size.SheetGrabberTopInset)
        )
    }

    private func handleAction(_ action: ASListPage.Action) {
        if let navigationValue = action.navigationValue {
            if navigationValue.tapToolsValue != nil {
                resetMapping()
                return
            }
            if navigationValue.isTapClose {
                hide()
                return
            }
        }

        guard let indexPath = action.normalItemValue?.indexPath else { return }
        let buttons = FLASHSkinButton.allCases
        guard indexPath.section < buttons.count else { return }
        showKeyPicker(for: buttons[indexPath.section])
    }

    private func resetMapping() {
        FLASHSkinButton.clear(from: games)
        mapping = FLASHSkinButton.defaultMapping
        PlayViewController.reloadRuffleKeyMapping(for: games)
        listView.updatePage(getListPage())
    }

    private func showKeyPicker(for button: FLASHSkinButton) {
        let keys = FLASHKey.allCases
        let selected = currentKey(for: button)
        OptionsSheetView.show(
            icon: button.icon,
            title: button.title,
            options: keys.map(\.title),
            selectedIndex: keys.firstIndex(of: selected),
            optionType: .radio,
            groupTogether: true
        ) { [weak self] index in
            guard let self, let index, keys.indices.contains(index) else { return }
            self.mapping[button] = keys[index]
            FLASHSkinButton.persist(self.mapping, to: self.games)
            PlayViewController.reloadRuffleKeyMapping(for: self.games)
            self.listView.updatePage(self.getListPage())
        }
    }
}

extension SkinButtonBindingView: ShowableView {
    static func show(games: [Game]) {
        Self.show(parameters: games)
    }
}
