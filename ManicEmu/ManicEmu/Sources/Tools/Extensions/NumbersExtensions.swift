//
//  NumbersExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

protocol DecimalConvertible {
    var decimalValue: Decimal { get }
}

extension Double: DecimalConvertible {
    var decimalValue: Decimal { Decimal(self) }
}

extension Float: DecimalConvertible {
    var decimalValue: Decimal { Decimal(Double(self)) }
}

extension CGFloat: DecimalConvertible {
    var decimalValue: Decimal { Decimal(Double(self)) }
}

extension DecimalConvertible {
    
    /// 截断浮点数
    /// - Parameter scale: 精度 scale = 1 则把 0.1999999 -> 0.20000
    /// - Returns: Decimal结果
    func roundedDecimal(scale: Int = 1) -> Decimal {
        var decimal = decimalValue
        var result = Decimal()

        NSDecimalRound(
            &result,
            &decimal,
            scale,
            .plain // 四舍五入
        )
        return result
    }
    
    /// 截断浮点数
    /// - Parameters:
    ///   - scale: 精度 scale = 1 则把 0.1999999 -> 0.20000
    ///   - minFraction: 最小保留小数位 minFraction = 1 -> 0.2
    ///   - maxFraction: 最大保留小数位 minFraction = 2 -> 0.20
    /// - Returns: 字符串结果
    func roundedString(scale: Int = 1, minFraction: Int = 1, maxFraction: Int = 1) -> String {
        let result = roundedDecimal(scale: scale)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minFraction
        formatter.maximumFractionDigits = maxFraction
        formatter.decimalSeparator = "."

        return formatter.string(from: result as NSDecimalNumber) ?? ""
    }
    
    func roundedDouble(scale: Int = 1) -> Double {
        (roundedDecimal(scale: scale) as NSDecimalNumber).doubleValue
    }
    
    func roundedFloat(scale: Int = 1) -> Float {
        roundedDouble(scale: scale).float
    }
    
    func roundedCGFloat(scale: Int = 1) -> CGFloat {
        roundedDouble(scale: scale).cgFloat
    }
}

extension Decimal {
    var stringValue: String {
        (self as NSDecimalNumber).stringValue
    }
    
    func stringValue(minFraction: Int = 1, maxFraction: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minFraction
        formatter.maximumFractionDigits = maxFraction
        formatter.decimalSeparator = "."
        return formatter.string(from: self as NSDecimalNumber) ?? ""
    }
    
    var doubleValue: Double {
        (self as NSDecimalNumber).doubleValue
    }
    
    var cgFloat: CGFloat {
        doubleValue.cgFloat
    }
    
    var floatValue: Float {
        (self as NSDecimalNumber).floatValue
    }
}

extension BinaryFloatingPoint {
    func rounded1(rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Self {
        return rounded(numberOfDecimalPlaces: 1, rule: rule)
    }
}
