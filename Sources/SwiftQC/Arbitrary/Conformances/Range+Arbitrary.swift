//
//  Range+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen
import Foundation // For Set (requires Hashable) and Strideable, abs()

// MARK: - Range<Bound> Arbitrary Conformance

public struct RangeShrinker<BoundGeneric>: Shrinker
    where BoundGeneric: Comparable & Sendable & Hashable & Strideable, BoundGeneric.Stride: SignedInteger {
    public typealias Value = Range<BoundGeneric>
    private let boundShrinker: any Shrinker<BoundGeneric>

    public init(boundShrinker: any Shrinker<BoundGeneric>) {
        self.boundShrinker = boundShrinker
    }

    public func shrink(_ value: Range<BoundGeneric>) -> [Range<BoundGeneric>] {
        var shrinks: [Range<BoundGeneric>] = []
        let (lower, upper) = (value.lowerBound, value.upperBound)

        // 1. Shrink individual bounds
        for shrunkLower in boundShrinker.shrink(lower) {
            if shrunkLower < upper {
                shrinks.append(shrunkLower..<upper)
            }
        }
        for shrunkUpper in boundShrinker.shrink(upper) {
            if lower < shrunkUpper {
                shrinks.append(lower..<shrunkUpper)
            }
        }
        
        // 2. Shrink both bounds if possible
        if let anUpShrunkLower = boundShrinker.shrink(lower).first(where: { $0 < upper }),
           let aDownShrunkUpper = boundShrinker.shrink(upper).first(where: { lower < $0 }) {
            if anUpShrunkLower < aDownShrunkUpper {
                 shrinks.append(anUpShrunkLower..<aDownShrunkUpper)
            }
        }

        // 3. Shift range by one step (if Strideable)
        let nextLower = lower.advanced(by: 1)
        if nextLower < upper {
            shrinks.append(nextLower..<upper)
        }
        let prevUpper = upper.advanced(by: -1)
        if lower < prevUpper {
            shrinks.append(lower..<prevUpper)
        }
        
        var uniqueShrinks = [Range<BoundGeneric>]()
        var seen = Set<Range<BoundGeneric>>()
        for shrinkCandidate in shrinks {
            if !seen.contains(shrinkCandidate) {
                uniqueShrinks.append(shrinkCandidate)
                seen.insert(shrinkCandidate)
            }
        }
        
        return uniqueShrinks.sorted { (r1: Range<BoundGeneric>, r2: Range<BoundGeneric>) -> Bool in
            let dist1 = r1.lowerBound.distance(to: r1.upperBound)
            let dist2 = r2.lowerBound.distance(to: r2.upperBound)
            // Basic abs for Stride. Assumes Stride can be compared with its zero.
            let zeroStride = r1.lowerBound.distance(to: r1.lowerBound) // Gets a 'zero' of the Stride type
            let absDist1 = dist1 < zeroStride ? (zeroStride - dist1) : dist1 // Simplified abs
            let absDist2 = dist2 < zeroStride ? (zeroStride - dist2) : dist2
            if absDist1 != absDist2 { return absDist1 < absDist2 } 
            if r1.lowerBound != r2.lowerBound { return r1.lowerBound < r2.lowerBound }
            return r1.upperBound < r2.upperBound
        }
    }
}

extension Range: Arbitrary 
    where Bound: Arbitrary, 
          Bound.Value: Comparable, 
          Bound.Value: Hashable, 
          Bound.Value: Strideable,
          Bound.Value.Stride: SignedInteger {
    public typealias Value = Range<Bound.Value>

    public static var gen: Gen<Range<Bound.Value>> {
        return zip(Bound.gen, Bound.gen).flatMap { b1, b2 -> Gen<Range<Bound.Value>?> in // FlatMap to Gen<Optional<Range>>
            var val1 = b1
            var val2 = b2
            
            if val1 == val2 { 
                // Attempt to make them different if Strideable allows meaningful advancement
                if let advancedVal2 = Optional(val2.advanced(by: 1)), advancedVal2 > val1 {
                    val2 = advancedVal2
                } else if let advancedVal1 = Optional(val1.advanced(by: -1)), advancedVal1 < val2 {
                    val1 = advancedVal1
                }
                // If still equal after trying to adjust, this attempt will yield nil
            }

            if val1 > val2 { swap(&val1, &val2) }
            
            if val1 == val2 { // Final check: if bounds are equal, this range is invalid for Range (lowerBound < upperBound)
                return Gen.always(nil as Range<Bound.Value>?) // Explicitly nil of the Optional type
            }

            return Gen.always(val1..<val2 as Range<Bound.Value>?) // Explicitly optional
        }.compactMap { $0 } // compactMap will unwrap Some and filter out None/nil
    }

    public static var shrinker: any Shrinker<Range<Bound.Value>> {
        RangeShrinker(boundShrinker: Bound.shrinker)
    }
}

// MARK: - ClosedRange<Bound> Arbitrary Conformance

public struct ClosedRangeShrinker<BoundGeneric>: Shrinker 
    where BoundGeneric: Comparable & Sendable & Hashable & Strideable, BoundGeneric.Stride: SignedInteger {
    public typealias Value = ClosedRange<BoundGeneric>
    private let boundShrinker: any Shrinker<BoundGeneric>

    public init(boundShrinker: any Shrinker<BoundGeneric>) {
        self.boundShrinker = boundShrinker
    }

    public func shrink(_ value: ClosedRange<BoundGeneric>) -> [ClosedRange<BoundGeneric>] {
        var shrinks: [ClosedRange<BoundGeneric>] = []
        let (lower, upper) = (value.lowerBound, value.upperBound)

        if lower == upper { 
            for shrunkBound in boundShrinker.shrink(lower) {
                shrinks.append(shrunkBound...shrunkBound)
            }
        } else {
            for shrunkLower in boundShrinker.shrink(lower) {
                if shrunkLower <= upper {
                    shrinks.append(shrunkLower...upper)
                }
            }
            for shrunkUpper in boundShrinker.shrink(upper) {
                if lower <= shrunkUpper {
                    shrinks.append(lower...shrunkUpper)
                }
            }
            
            if let anUpShrunkLower = boundShrinker.shrink(lower).first(where: { $0 <= upper }),
               let aDownShrunkUpper = boundShrinker.shrink(upper).first(where: { lower <= $0 }) {
                if anUpShrunkLower <= aDownShrunkUpper {
                     shrinks.append(anUpShrunkLower...aDownShrunkUpper)
                }
            }

            let nextLower = lower.advanced(by: 1)
            if nextLower <= upper { 
                shrinks.append(nextLower...upper)
            }
            let prevUpper = upper.advanced(by: -1)
            if lower <= prevUpper {
                shrinks.append(lower...prevUpper)
            }

            shrinks.append(lower...lower)
            if upper != lower { 
                 shrinks.append(upper...upper)
            }
        }
        
        var uniqueShrinks = [ClosedRange<BoundGeneric>]()
        var seen = Set<ClosedRange<BoundGeneric>>()
        for shrinkCandidate in shrinks {
            if !seen.contains(shrinkCandidate) {
                uniqueShrinks.append(shrinkCandidate)
                seen.insert(shrinkCandidate)
            }
        }

        return uniqueShrinks.sorted { (r1: ClosedRange<BoundGeneric>, r2: ClosedRange<BoundGeneric>) -> Bool in
            let dist1 = r1.lowerBound.distance(to: r1.upperBound)
            let dist2 = r2.lowerBound.distance(to: r2.upperBound)
            let zeroStride = r1.lowerBound.distance(to: r1.lowerBound)
            let absDist1 = dist1 < zeroStride ? (zeroStride - dist1) : dist1
            let absDist2 = dist2 < zeroStride ? (zeroStride - dist2) : dist2
            if absDist1 != absDist2 { return absDist1 < absDist2 }
            if r1.lowerBound != r2.lowerBound { return r1.lowerBound < r2.lowerBound }
            return r1.upperBound < r2.upperBound
        }
    }
}

extension ClosedRange: Arbitrary 
    where Bound: Arbitrary, 
          Bound.Value: Comparable, 
          Bound.Value: Hashable,
          Bound.Value: Strideable,
          Bound.Value.Stride: SignedInteger {
    public typealias Value = ClosedRange<Bound.Value>

    public static var gen: Gen<ClosedRange<Bound.Value>> {
        Gen.frequency(
            (90, zip(Bound.gen, Bound.gen).map { b1, b2 in
                return b1 <= b2 ? (b1...b2) : (b2...b1)
            }),
            (10, Bound.gen.map { b_val in b_val...b_val })
        )
    }

    public static var shrinker: any Shrinker<ClosedRange<Bound.Value>> {
        ClosedRangeShrinker(boundShrinker: Bound.shrinker)
    }
}