//
//  CheersView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ConfettiSwiftUI
import SwiftUI



struct CheersView: View {
    
    static func makePurchaseCheers(in scene: UIWindowScene?) {
        if let window = UIWindow.topWindow(in: scene) {
            let vc = UIHostingController(rootView: CheersView().edgesIgnoringSafeArea(.all))
            if let cheersView = vc.view {
                
                let container = UIView()
                container.backgroundColor = .clear
                window.addSubview(container)
                container.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                
                let memberView = SettingsMembershipView(frame: CGRect(origin: .zero, size: CGSize(width: 300, height: 150)))
                container.addSubview(memberView)
                memberView.snp.makeConstraints { make in
                    make.center.equalToSuperview()
                    make.size.equalTo(CGSize(width: 300, height: 150))
                }
                
                memberView.alpha = 0
                UIView.normalAnimate {
                    memberView.alpha = 1
                    container.backgroundColor = .black.withAlphaComponent(0.75)
                }
                
                cheersView.isUserInteractionEnabled = false
                cheersView.backgroundColor = .clear
                container.addSubview(cheersView)
                cheersView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                
                DispatchQueue.main.asyncAfter(delay: 2) { [weak container] in
                    guard let container else { return }
                    container.addTapGesture { [weak container] gesture in
                        UIView.normalAnimate(animations: {
                            memberView.alpha = 0
                            container?.backgroundColor = .clear
                        }) { _ in
                            container?.removeFromSuperview()
                        }
                    }
                }
            }
        }
    }
    
    static func makeNormalCheers(userTopWindow: Bool = false) {
        let window = userTopWindow ? (ApplicationSceneDelegate.applicationScene?.windows.last(where: {
            $0.isHidden == false &&
            $0.rootViewController != nil &&
            (String(describing: type(of: $0)) == "SheetWindow" || String(describing: type(of: $0)) == "AlertWindow" || $0.windowLevel == .normal)
        })) : UIWindow.applicationWindow
        
        if let window {
            let vc = UIHostingController(rootView: CheersView().edgesIgnoringSafeArea(.all))
            if let cheersView = vc.view {
                
                let container = UIView()
                container.backgroundColor = .clear
                window.addSubview(container)
                container.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                
                cheersView.isUserInteractionEnabled = false
                cheersView.backgroundColor = .clear
                container.addSubview(cheersView)
                cheersView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                
                DispatchQueue.main.asyncAfter(delay: 4) {
                    UIView.normalAnimate(animations: {
                        container.backgroundColor = .clear
                    }) { _ in
                        container.removeFromSuperview()
                    }
                }
            }
        }
    }
    
    
    @State private var trigger: Int = 0
    
    var body: some View {
        Button(" "){}
            .confettiCannon(trigger: $trigger, num: 100, confettiSize: 22.5, rainHeight: R.Size.ApplicationWindowSize.height, openingAngle: Angle(degrees: 0), closingAngle: Angle(degrees: 180), radius: customRadius)
            .onAppear {
                trigger += 1
            }
    }
    
    private var customRadius: CGFloat {
        var radius = R.Size.ApplicationWindowSize.width/(UIDevice.isPad ? 2 : 1)
        if UIDevice.isPhone, R.Size.ApplicationWindowSize.IsRelativelyWideRectangle {
            radius = radius/2
        }
        return radius
    }
}
