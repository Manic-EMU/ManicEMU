//
//  RetroAchievementsLaunchView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/16.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class RetroAchievementsLaunchView: BaseView {
    
    enum LoginedAction {
        case jumpList(game: Game, didClose: (() -> Void)? = nil)
        case jumpProfile
    }
    
    private let backgroundImageView: UIImageView = {
        let view = UIImageView(image: R.image.retro_bg())
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    private let containerView = UIView()
    
    private lazy var loginView: RetroAchievementsLoginView = {
        let view = RetroAchievementsLoginView()
        view.loginSuccess = { [weak self] in
            guard let self else { return }
            if case let .jumpList(game, didClose) = self.loginedAction {
                if self.showAsSheet {
                    self.hide()
                }
                RetroAchievementListView.show(game: game, didClose: didClose)
            } else if case .jumpProfile = self.loginedAction {
                self.loginView.removeFromSuperview()
                self.achievementsUser = AchievementsUser.getUser()
                self.containerView.addSubview(self.profileView)
                self.profileView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                self.navigationView.navigation = self.navigation
            }
        }
        return view
    }()
    
    private lazy var profileView: RetroAchievementsProfileView = {
        
        let view = RetroAchievementsProfileView(username: self.achievementsUser?.username ?? "", showAsSheet: showClose)
        view.logoutSuccess = { [weak self] in
            guard let self else { return }
            UIView.makeAlert(detail: R.string.localizable.achievementsLogoutAlert(), confirmTitle: R.string.localizable.confirmTitle(), confirmAction: {
                CheevosBridge.logoutCheevos()
                Settings.defalut.updateExtra(key: ExtraKey.achievementsUser.rawValue, value: "")
                self.profileView.removeFromSuperview()
                self.achievementsUser = nil
                self.containerView.addSubview(self.loginView)
                self.loginView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                self.navigationView.navigation = self.navigation
            })
        }
        return view
    }()
    
    private var navigation: ASListPage.Navigation {
        if let _ = achievementsUser {
            return .defaultNavigation()
        } else {
            return .defaultNavigation(title: "RetroAchievements", titleIcon: .symbolImage(R.image.retroachievements_iconSymbols()))
        }
    }
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(navigation)
        view.didTapClose = { [weak self] in
            guard let self else { return }
            if self.showAsSheet {
                self.hide()
            }
        }
        return view
    }()
    
    private var achievementsUser = AchievementsUser.getUser()
    
    private let loginedAction: LoginedAction
    private let showClose: Bool
    
    required init?(parameters: Any...) {
        self.loginedAction = parameters.compactMap({ $0 as? LoginedAction }).first ?? .jumpProfile
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)
        
        //Prevent the background Image View from extending beyond the screen.
        self.masksToBounds = true
        
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.lessThanOrEqualToSuperview()
            make.trailing.greaterThanOrEqualToSuperview()
            make.centerX.equalToSuperview()
        }
        
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if let _ = achievementsUser {
            //已登录
            containerView.addSubview(profileView)
            profileView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            //未登录
            containerView.addSubview(loginView)
            loginView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        if showClose {
            addSubview(navigationView)
            navigationView.snp.makeConstraints { make in
                if showClose {
                    make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
                } else {
                    make.top.equalToSuperview().offset(R.Size.ContentInsetTop(window: hostingWindow))
                }
                make.leading.trailing.equalTo(safeAreaLayoutGuide)
                make.height.equalTo(R.Size.ItemHeightMedium)
            }
        }
    }
    
    convenience init(loginedAction: LoginedAction, showClose: Bool = true) {
        self.init(parameters: loginedAction, showClose)!
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RetroAchievementsLaunchView: ShowableView {
    
    static func show(loginedAction: LoginedAction) {
        if case let .jumpList(game, didClose) = loginedAction,
            let _ = AchievementsUser.getUser() {
            RetroAchievementListView.show(game: game, didClose: didClose)
        } else {
            Self.show(parameters: loginedAction)
        }
    }
    
    func dataForShow(_ defaultData: ASSheet) -> ASSheet {
        var sheetData = defaultData
        sheetData.enableBackgroundDecoration = false
        sheetData.fullScreenForLandscape = true
        return sheetData
    }
    
    func didHide() {
        if case .jumpList(_, let didClose) = loginedAction {
            didClose?()
        }
    }
}
