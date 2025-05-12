//
//  CGFloat+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen
#if canImport(CoreGraphics)
import CoreGraphics
#elseif canImport(Foundation) // On Linux, CGFloat might come from Foundation
import Foundation
#endif

#if canImport(CoreGraphics) || canImport(Foundation)

public struct CGFloatShrinker: Shrinker {
    public typealias Value = CGFloat

    public func shrink(_ value: CGFloat) -> [CGFloat] {
        // Similar to Double/Float shrinker, shrink towards 0.0, +/-1.0
        guard value.isFinite && value != 0.0 else { return [] }

        var shrunkValues: [CGFloat] = [0.0]

        let half = value / 2.0
        if half.isFinite && half != value && half != 0.0 {
            shrunkValues.append(half)
        }
        
        if abs(value) > 1.0 {
            let closerToZeroByOne = value > 0 ? value - 1.0 : value + 1.0
            if closerToZeroByOne.isFinite && closerToZeroByOne != 0.0 && closerToZeroByOne != half {
                shrunkValues.append(closerToZeroByOne)
            }
        }
        
        let simpleValues: [CGFloat] = [1.0, -1.0]
        for simple in simpleValues {
            if abs(simple) < abs(value) && value != simple && !shrunkValues.contains(simple) {
                shrunkValues.append(simple)
            }
        }
        
        // CGFloat is Hashable
        return Array(Set(shrunkValues)).sorted { abs($0) < abs($1) }
    }
}

extension CGFloat: Arbitrary {
    public typealias Value = CGFloat
    public static var gen: Gen<CGFloat> {
        // swift-gen's cgFloat typically generates in 0...1 by default, or takes a range.
        // Let's use a range similar to Float/Double for consistency.
        Gen.cgFloat(in: -100.0...100.0)
    }
    public static var shrinker: any Shrinker<CGFloat> { CGFloatShrinker() }
}

#endif