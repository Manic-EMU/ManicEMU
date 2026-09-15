//
//  RommSettingsViewController.swift
//  ManicEmu
//
//  Created by Chris Habibi on 6/30/26.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class RommSettingsViewController: BaseViewController {
    private lazy var rommSettingsView: RommSettingsView = {
        let view = RommSettingsView(showClose: self.showClose)
        view.didTapClose = { [weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()

    let showClose: Bool

    init(showClose: Bool = true) {
        self.showClose = showClose
        super.init(nibName: nil, bundle: nil)
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(rommSettingsView)
        rommSettingsView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
