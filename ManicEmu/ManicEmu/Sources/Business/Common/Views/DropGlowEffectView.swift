//
//  DropGlowEffectView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/26.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import UIKit
import SwiftUI

class DropGlowEffectView: BaseView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        if #available(iOS 17.0, *) {
            let vc = UIHostingController(rootView: GlowEffect().edgesIgnoringSafeArea(.all))
            vc.view.backgroundColor = .clear
            addSubview(vc.view)
            vc.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            let vc = UIHostingController(rootView: GlowEffectLegacy().edgesIgnoringSafeArea(.all))
            vc.view.backgroundColor = .clear
            addSubview(vc.view)
            vc.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }   
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct GlowEffect: View {
    @State private var gradientStops: [Gradient.Stop] = GlowEffect.generateGradientStops()

    var body: some View {
        ZStack {
            EffectNoBlur(gradientStops: gradientStops, width: 6)
                .onAppear {
                    // Start a timer to update the gradient stops every second
                    Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { _ in
                        withAnimation(.easeInOut(duration: 1.0)) {
                            gradientStops = GlowEffect.generateGradientStops()
                        }
                    }
                }
            Effect(gradientStops: gradientStops, width: 9, blur: 4)
                .onAppear {
                    // Start a timer to update the gradient stops every second
                    Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { _ in
                        withAnimation(.easeInOut(duration: 1.2)) {
                            gradientStops = GlowEffect.generateGradientStops()
                        }
                    }
                }
            Effect(gradientStops: gradientStops, width: 11, blur: 12)
                .onAppear {
                    // Start a timer to update the gradient stops every second
                    Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                        withAnimation(.easeInOut(duration: 1.6)) {
                            gradientStops = GlowEffect.generateGradientStops()
                        }
                    }
                }
            Effect(gradientStops: gradientStops, width: 15, blur: 15)
                .onAppear {
                    // Start a timer to update the gradient stops every second
                    Timer.scheduledTimer(withTimeInterval: 1.9, repeats: true) { _ in
                        withAnimation(.easeInOut(duration: 2.0)) {
                            gradientStops = GlowEffect.generateGradientStops()
                        }
                    }
                }
        }
    }
    
    // Function to generate random gradient stops
    static func generateGradientStops() -> [Gradient.Stop] {
        [
            Gradient.Stop(color: SwiftUI.Color(hex: "EB7500"), location: Double.random(in: 0...1)),
            Gradient.Stop(color: SwiftUI.Color(hex: "F2416B"), location: Double.random(in: 0...1)),
            Gradient.Stop(color: SwiftUI.Color(hex: "BB64FF"), location: Double.random(in: 0...1)),
            Gradient.Stop(color: SwiftUI.Color(hex: "0096FF"), location: Double.random(in: 0...1)),
        ].sorted { $0.location < $1.location }
    }
}

struct GlowEffectLegacy: View {
    @State private var animatedGradient: AnimatedGradient = AnimatedGradient()

    var body: some View {
        ZStack {
            EffectNoBlur(gradientStops: animatedGradient.gradientStops, width: 6)
            Effect(gradientStops: animatedGradient.gradientStops, width: 9, blur: 4)
            Effect(gradientStops: animatedGradient.gradientStops, width: 11, blur: 12)
            Effect(gradientStops: animatedGradient.gradientStops, width: 15, blur: 15)
        }
        .onAppear {
            animatedGradient.startAnimation()
        }
    }
}

// 自定义动画管理
class AnimatedGradient: ObservableObject {
    @Published var gradientStops: [Gradient.Stop] = AnimatedGradient.generateGradientStops()

    func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.6)) {
                self.gradientStops = AnimatedGradient.generateGradientStops()
            }
        }
    }

    // 平滑过渡颜色和位置
    static func generateGradientStops() -> [Gradient.Stop] {
        let baseLocations: [Double] = [0.1, 0.25, 0.5, 0.75, 0.9]
        return [
            Gradient.Stop(color: SwiftUI.Color(hex: "EB7500").interpolated(to: .red), location: baseLocations[0] + Double.random(in: -0.02...0.08)),
            Gradient.Stop(color: SwiftUI.Color(hex: "F2416B").interpolated(to: .pink), location: baseLocations[1] + Double.random(in: -0.02...0.08)),
            Gradient.Stop(color: SwiftUI.Color(hex: "BB64FF").interpolated(to: .purple), location: baseLocations[2] + Double.random(in: -0.02...0.08)),
            Gradient.Stop(color: SwiftUI.Color(hex: "0096FF").interpolated(to: .blue), location: baseLocations[3] + Double.random(in: -0.02...0.08)),
            Gradient.Stop(color: SwiftUI.Color(hex: "BB64FF").interpolated(to: .purple), location: baseLocations[4] + Double.random(in: -0.02...0.08)),
        ].sorted { $0.location < $1.location }
    }
}

// 让颜色能够渐变
extension Color {
    func interpolated(to target: Color) -> Color {
        let from = UIColor(self)
        let to = UIColor(target)

        let r = (from.red + to.red) / 2
        let g = (from.green + to.green) / 2
        let b = (from.blue + to.blue) / 2

        return Color(red: r, green: g, blue: b)
    }
}

// 让 UIColor 支持 RGB 解析
extension UIColor {
    var red: CGFloat { return cgColor.components?[0] ?? 0 }
    var green: CGFloat { return cgColor.components?[1] ?? 0 }
    var blue: CGFloat { return cgColor.components?[2] ?? 0 }
}

struct Effect: View {
    var gradientStops: [Gradient.Stop]
    var width: CGFloat
    var blur: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UIWindow.applicationWindow?.screen.displayCornerRadius ?? 0)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: gradientStops),
                        center: .center
                    ),
                    lineWidth: width
                )
                .frame(
                    width: UIScreen.current.bounds.width,
                    height: UIScreen.current.bounds.height
                )
                .blur(radius: blur)
        }
    }
}

struct EffectNoBlur: View {
    var gradientStops: [Gradient.Stop]
    var width: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UIWindow.applicationWindow?.screen.displayCornerRadius ?? 0)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: gradientStops),
                        center: .center
                    ),
                    lineWidth: width
                )
                .frame(
                    width: UIScreen.current.bounds.width,
                    height: UIScreen.current.bounds.height
                )
        }
    }
}

extension SwiftUI.Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)
        
        let r = Double((hexNumber & 0xff0000) >> 16) / 255
        let g = Double((hexNumber & 0x00ff00) >> 8) / 255
        let b = Double(hexNumber & 0x0000ff) / 255
        
        self.init(red: r, green: g, blue: b)
    }
}
