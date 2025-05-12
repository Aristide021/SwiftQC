//
//  Decimal+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen
import Foundation // For Decimal, NSDecimalNumber

public struct DecimalShrinker: Shrinker {
    public typealias Value = Decimal

    public func shrink(_ value: Decimal) -> [Decimal] {
        guard !value.isZero else { return [] }

        var shrinks: [Decimal] = []
        let one = Decimal(1)
        let minusOne = Decimal(-1)

        // 1. Shrink towards Decimal.zero
        shrinks.append(Decimal.zero)

        // 2. If not an integer, try to make it an integer by rounding towards zero
        if !value.isInteger {
            var roundedTowardsZero = value
            var original = value
            NSDecimalRound(&roundedTowardsZero, &original, 0, .down)
            if roundedTowardsZero != value && !shrinks.contains(roundedTowardsZero) {
                shrinks.append(roundedTowardsZero)
            }
        }
        
        // 3. For positive values, shrink towards 1 if > 1
        if !value.isSignMinus && value > one && !shrinks.contains(one) {
            shrinks.append(one)
        }
        // 4. For negative values, shrink towards -1 if < -1
        if value.isSignMinus && value < minusOne && !shrinks.contains(minusOne) {
            shrinks.append(minusOne)
        }

        // 5. Halve the magnitude
        let nsValue = NSDecimalNumber(decimal: value)
        let two = NSDecimalNumber(decimal: Decimal(2))
        // NSDecimalNumber.zero is a static var.
        if !nsValue.isEqual(to: NSDecimalNumber.zero) { // Check against NSDecimalNumber.zero
            let trueHalf = nsValue.dividing(by: two).decimalValue
            if trueHalf != value && !trueHalf.isZero && !shrinks.contains(trueHalf) {
                shrinks.append(trueHalf)
            }
        }
        
        // 6. For negative, also offer its absolute value
        if value.isSignMinus {
            let absValue = -value // Direct negation for Decimal works for absolute value
            if !shrinks.contains(absValue) {
                shrinks.append(absValue)
            }
        }
        
        return Array(Set(shrinks)).sorted { left, right -> Bool in
            // *** CORRECTED SORTING LOGIC ***
            // Get the double representation
            let leftDouble = NSDecimalNumber(decimal: left).doubleValue
            let rightDouble = NSDecimalNumber(decimal: right).doubleValue
            
            // Compare their absolute values
            return abs(leftDouble) < abs(rightDouble) // Use global abs() for Double
        }
    }
}

extension Decimal: Arbitrary {
    public typealias Value = Decimal

    public static var gen: Gen<Decimal> {
        let integralPartGen = Gen.int(in: -10000...10000)
        let fractionalDigitsCountGen = Gen.int(in: 0...4) 

        return zip(integralPartGen, fractionalDigitsCountGen).map { whole, fracCount -> Decimal in
            if fracCount == 0 {
                return Decimal(whole)
            }
            var fractionalString = ""
            var tempRng = Xoshiro() 
            for i in 0..<fracCount {
                let digit = Gen.int(in: (i == fracCount - 1 && fracCount == 1 && whole == 0) ? 1...9 : 0...9).run(using: &tempRng)
                fractionalString += String(digit)
            }
            
            let decimalString = "\(whole).\(fractionalString)"
            return Decimal(string: decimalString) ?? Decimal(whole) 
        }
    }

    public static var shrinker: any Shrinker<Decimal> { DecimalShrinker() }
}

internal extension Decimal {
    var isInteger: Bool {
        var rounded = self
        var original = self
        NSDecimalRound(&rounded, &original, 0, .plain)
        return rounded == self
    }
}