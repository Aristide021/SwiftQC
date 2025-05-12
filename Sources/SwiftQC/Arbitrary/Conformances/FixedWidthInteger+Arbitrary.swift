//
//  FixedWidthInteger+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen

// MARK: - Signed Fixed-Width Integer Shrinkers

// Common shrink logic for signed fixed-width integers
fileprivate func shrinkSignedFixedWidthInteger<T: FixedWidthInteger & SignedInteger>(_ value: T) -> [T] where T: Arbitrary {
    guard value != 0 else { return [] }

    var shrunkValues: [T] = []
    shrunkValues.append(0) // Candidate 1: Shrink to 0 directly

    let half = value / 2 // Candidate 2: Halve the value
    if half != value && half != 0 { // Avoid adding 0 twice or original value
        shrunkValues.append(half)
    }
    
    // Candidate 3: Decrement/Increment magnitude (move closer to 0 by 1)
    let nextTowardsZero = value > 0 ? value - 1 : value + 1
    if nextTowardsZero != 0 && nextTowardsZero != half && nextTowardsZero != value {
        shrunkValues.append(nextTowardsZero)
    }
    
    // Basic de-duplication by converting to a Set first (T must be Hashable, which FixedWidthIntegers are)
    // Sort by absolute value (closer to 0 first)
    return Array(Set(shrunkValues)).sorted { T.Magnitude.init(abs($0)) < T.Magnitude.init(abs($1)) }
}

public struct Int8Shrinker: Shrinker {
    public typealias Value = Int8
    public func shrink(_ value: Int8) -> [Int8] { return shrinkSignedFixedWidthInteger(value) }
}

public struct Int16Shrinker: Shrinker {
    public typealias Value = Int16
    public func shrink(_ value: Int16) -> [Int16] { return shrinkSignedFixedWidthInteger(value) }
}

public struct Int32Shrinker: Shrinker {
    public typealias Value = Int32
    public func shrink(_ value: Int32) -> [Int32] { return shrinkSignedFixedWidthInteger(value) }
}

public struct Int64Shrinker: Shrinker {
    public typealias Value = Int64
    public func shrink(_ value: Int64) -> [Int64] { return shrinkSignedFixedWidthInteger(value) }
}

// MARK: - Unsigned Fixed-Width Integer Shrinkers

// Common shrink logic for unsigned fixed-width integers
fileprivate func shrinkUnsignedFixedWidthInteger<T: FixedWidthInteger & UnsignedInteger>(_ value: T) -> [T] where T: Arbitrary {
    guard value != 0 else { return [] }

    var shrunkValues: [T] = []
    shrunkValues.append(0) // Candidate 1: Shrink to 0 directly

    let half = value / 2 // Candidate 2: Halve the value
    if half != value && half != 0 {
        shrunkValues.append(half)
    }
    
    // Candidate 3: Decrement magnitude (move closer to 0 by 1)
    if value > 0 { // Always true unless value is 0, handled by guard
        let decremented = value - 1
        if decremented != 0 && decremented != half { // Avoid adding 0 or half if already present
             shrunkValues.append(decremented)
        }
    }
    
    return Array(Set(shrunkValues)).sorted() // Sort normally for unsigned (smaller values first)
}

public struct UInt8Shrinker: Shrinker {
    public typealias Value = UInt8
    public func shrink(_ value: UInt8) -> [UInt8] { return shrinkUnsignedFixedWidthInteger(value) }
}

public struct UInt16Shrinker: Shrinker {
    public typealias Value = UInt16
    public func shrink(_ value: UInt16) -> [UInt16] { return shrinkUnsignedFixedWidthInteger(value) }
}

public struct UInt32Shrinker: Shrinker {
    public typealias Value = UInt32
    public func shrink(_ value: UInt32) -> [UInt32] { return shrinkUnsignedFixedWidthInteger(value) }
}

public struct UInt64Shrinker: Shrinker {
    public typealias Value = UInt64
    public func shrink(_ value: UInt64) -> [UInt64] { return shrinkUnsignedFixedWidthInteger(value) }
}


// MARK: - Arbitrary Conformances

extension Int8: Arbitrary {
    public typealias Value = Int8
    public static var gen: Gen<Int8> { Gen.int8(in: .min ... .max) }
    public static var shrinker: any Shrinker<Int8> { Int8Shrinker() }
}

extension UInt8: Arbitrary {
    public typealias Value = UInt8
    public static var gen: Gen<UInt8> { Gen.uint8(in: .min ... .max) }
    public static var shrinker: any Shrinker<UInt8> { UInt8Shrinker() }
}

extension Int16: Arbitrary {
    public typealias Value = Int16
    public static var gen: Gen<Int16> { Gen.int16(in: .min ... .max) }
    public static var shrinker: any Shrinker<Int16> { Int16Shrinker() }
}

extension UInt16: Arbitrary {
    public typealias Value = UInt16
    public static var gen: Gen<UInt16> { Gen.uint16(in: .min ... .max) }
    public static var shrinker: any Shrinker<UInt16> { UInt16Shrinker() }
}

extension Int32: Arbitrary {
    public typealias Value = Int32
    public static var gen: Gen<Int32> { Gen.int32(in: .min ... .max) }
    public static var shrinker: any Shrinker<Int32> { Int32Shrinker() }
}

extension UInt32: Arbitrary {
    public typealias Value = UInt32
    public static var gen: Gen<UInt32> { Gen.uint32(in: .min ... .max) }
    public static var shrinker: any Shrinker<UInt32> { UInt32Shrinker() }
}

extension Int64: Arbitrary {
    public typealias Value = Int64
    public static var gen: Gen<Int64> { Gen.int64(in: .min ... .max) }
    public static var shrinker: any Shrinker<Int64> { Int64Shrinker() }
}

extension UInt64: Arbitrary {
    public typealias Value = UInt64
    public static var gen: Gen<UInt64> { Gen.uint64(in: .min ... .max) }
    public static var shrinker: any Shrinker<UInt64> { UInt64Shrinker() }
}