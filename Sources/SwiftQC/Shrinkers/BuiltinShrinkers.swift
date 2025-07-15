//
//  BuiltinShrinkers.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Foundation // For Float, Double, Decimal
#if canImport(CoreGraphics) // For CGFloat
import CoreGraphics
#endif
// No need to import other specific Arbitrary conformance files here

/// A collection of factory methods for built-in shrinkers.
public enum Shrinkers {
  /// Shrinks an `Int` toward zero using a halving strategy.
  public static var int: IntShrinker { IntShrinker() }

  /// Shrinks an `Int` toward the lower bound of a range.
  public static func range(_ bounds: ClosedRange<Int>) -> IntInRangeShrinker {
    IntInRangeShrinker(bounds: bounds)
  }

  /// Shrinks an array by removing elements or shrinking individual elements.
  public static func array<Element, ElementShrinkerType: Shrinker>(
    ofElementShrinker elementShrinker: ElementShrinkerType
  ) -> ArrayShrinker<Element, ElementShrinkerType> where ElementShrinkerType.Value == Element {
    ArrayShrinker(elementShrinker: elementShrinker)
  }

  /// Shrinks a `String` towards an empty string and simpler character sequences.
  public static var string: StringShrinker { StringShrinker() }

  /// Shrinks a `Double` towards zero and other simple values.
  public static var double: DoubleShrinker { DoubleShrinker() }

  /// Shrinks a `Float` towards zero and other simple values.
  public static var float: FloatShrinker { FloatShrinker() }

  // MARK: - Fixed-Width Integer Shrinker Accessors
  // These refer to the structs defined in FixedWidthInteger+Arbitrary.swift
  public static var int8: Int8Shrinker { Int8Shrinker() }
  public static var uint8: UInt8Shrinker { UInt8Shrinker() }
  public static var int16: Int16Shrinker { Int16Shrinker() }
  public static var uint16: UInt16Shrinker { UInt16Shrinker() }
  public static var int32: Int32Shrinker { Int32Shrinker() }
  public static var uint32: UInt32Shrinker { UInt32Shrinker() }
  public static var int64: Int64Shrinker { Int64Shrinker() }
  public static var uint64: UInt64Shrinker { UInt64Shrinker() }

  // MARK: - Other Numeric Shrinker Accessors
  #if canImport(CoreGraphics) || canImport(Foundation) // Match the condition in CGFloat+Arbitrary.swift
  /// Shrinks a `CGFloat` towards zero and other simple values.
  /// Refers to CGFloatShrinker defined in CGFloat+Arbitrary.swift
  public static var cgFloat: CGFloatShrinker { CGFloatShrinker() }
  #endif

  /// Shrinks a `Decimal` towards zero and other simple values.
  /// Refers to DecimalShrinker defined in Decimal+Arbitrary.swift
  public static var decimal: DecimalShrinker { DecimalShrinker() }
  
  // MARK: - Convenient Combinators
  
  /// Creates a shrinker that maps values through a transformation.
  public static func map<From, To>(
    from shrinker: any Shrinker<From>,
    transform: @escaping @Sendable (From) -> To,
    reverse: @escaping @Sendable (To) -> From
  ) -> MappedShrinker<From, To> {
    MappedShrinker(
      baseShrinker: shrinker,
      transform: transform,
      reverse: reverse
    )
  }
  
  /// Creates a shrinker for tuples of two values.
  public static func tuple<A, B>(
    _ first: any Shrinker<A>,
    _ second: any Shrinker<B>
  ) -> TupleShrinker<A, B> {
    TupleShrinker(first: first, second: second)
  }
  
  /// Creates a shrinker that doesn't shrink (returns empty array).
  public static func noShrink<T>() -> NoShrinkShrinker<T> {
    NoShrinkShrinker<T>()
  }
  
  /// Creates a shrinker by combining multiple shrinkers.
  @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
  public static func combine<T>(
    _ shrinkers: [any Shrinker<T>]
  ) -> CombinedShrinker<T> {
    CombinedShrinker(shrinkers: shrinkers)
  }
}

// MARK: - Definitions for Truly "Built-in" Generic Shrinkers

/// Shrinker for `Int` that moves values toward zero.
public struct IntShrinker: Shrinker { /* ... implementation ... */
  public typealias Value = Int
  public func shrink(_ value: Int) -> [Int] {
    guard value != 0 else { return [] }
    var shrunkValues: [Int] = [0]
    let half = value / 2
    if half != value && half != 0 { shrunkValues.append(half) }
    let nextTowardsZero = value > 0 ? value - 1 : value + 1
    if nextTowardsZero != 0 && nextTowardsZero != half && nextTowardsZero != value { shrunkValues.append(nextTowardsZero) }
    return Array(Set(shrunkValues)).sorted { abs($0) < abs($1) }
  }
}

/// Shrinker for `Int` that moves values toward a given lower bound.
public struct IntInRangeShrinker: Shrinker { /* ... implementation ... */
  public typealias Value = Int
  let bounds: ClosedRange<Int>
  public init(bounds: ClosedRange<Int>) { self.bounds = bounds }
  public func shrink(_ value: Int) -> [Int] {
    guard bounds.contains(value) && value != bounds.lowerBound else { return [] }
    var shrunkValues: [Int] = [bounds.lowerBound]
    let distance = value - bounds.lowerBound
    if distance > 1 {
        let halfDistanceShrunk = bounds.lowerBound + (distance / 2)
        if halfDistanceShrunk != value && halfDistanceShrunk != bounds.lowerBound { shrunkValues.append(halfDistanceShrunk) }
    }
    let decremented = value - 1
    if decremented >= bounds.lowerBound && decremented != bounds.lowerBound && !shrunkValues.contains(decremented) { shrunkValues.append(decremented) }
    return Array(Set(shrunkValues)).sorted()
  }
}

/// Shrinker for arrays that drops elements or shrinks individual elements.
public struct ArrayShrinker<Element, ElementShrinkerType: Shrinker>: Shrinker
  where ElementShrinkerType.Value == Element { /* ... implementation ... */
  public typealias Value = [Element]
  let elementShrinker: ElementShrinkerType
  public init(elementShrinker: ElementShrinkerType) { self.elementShrinker = elementShrinker }
  public func shrink(_ value: [Element]) -> [[Element]] {
    var shrunkArrays: [[Element]] = []
    if !value.isEmpty { shrunkArrays.append([]) }
    if value.count > 1 {
        let half = Array(value.prefix(value.count / 2))
        if half.count < value.count && !(half.isEmpty && shrunkArrays.first?.isEmpty == true) { shrunkArrays.append(half) }
    }
    if !value.isEmpty {
        var oneLess = value; oneLess.removeLast()
        if oneLess.count < value.count && !(oneLess.isEmpty && shrunkArrays.first?.isEmpty == true) { shrunkArrays.append(oneLess) }
    }
    if value.count > 1 {
        var oneLessFromFront = value; oneLessFromFront.removeFirst()
        if oneLessFromFront.count < value.count && !(oneLessFromFront.isEmpty && shrunkArrays.first?.isEmpty == true) { shrunkArrays.append(oneLessFromFront) }
    }
    for (i, element) in value.enumerated() {
        for shrunkElement in elementShrinker.shrink(element) {
            var newArray = value; newArray[i] = shrunkElement; shrunkArrays.append(newArray)
        }
    }
    return shrunkArrays.sorted { $0.count < $1.count }
  }
}

/// Shrinker for `String`.
public struct StringShrinker: Shrinker { /* ... implementation ... */
    public typealias Value = String
    public func shrink(_ value: String) -> [String] {
        guard !value.isEmpty else { return [] }
        var shrunkStrings: [String] = [""]
        let commonSimpleStrings = ["a", "A", "0", " ", "."]; for simple in commonSimpleStrings { if value != simple && simple.count < value.count { shrunkStrings.append(simple) } }
        if value.count > 1 {
            let halfIndex = value.index(value.startIndex, offsetBy: value.count / 2); let halfString = String(value[..<halfIndex])
            if halfString.count < value.count { shrunkStrings.append(halfString) }
        }
        if !value.isEmpty { var oneLess = value; oneLess.removeLast(); if oneLess.count < value.count { shrunkStrings.append(oneLess) } }
        return Array(Set(shrunkStrings)).sorted { if $0.count != $1.count { return $0.count < $1.count } ; return $0 < $1 }
    }
}

/// Shrinker for `Double`
public struct DoubleShrinker: Shrinker { /* ... implementation ... */
    public typealias Value = Double
    public func shrink(_ value: Double) -> [Double] {
        guard value.isFinite && value != 0.0 else { return [] }
        var shrunkValues: [Double] = [0.0]
        let half = value / 2.0; if half.isFinite && half != value && half != 0.0 { shrunkValues.append(half) }
        if abs(value) > 1.0 { let closer = value > 0 ? value - 1.0 : value + 1.0; if closer.isFinite && closer != 0.0 && closer != half { shrunkValues.append(closer) } }
        let simple: [Double] = [1.0, -1.0]; for s in simple { if abs(s) < abs(value) && value != s && !shrunkValues.contains(s) { shrunkValues.append(s) } }
        return Array(Set(shrunkValues)).sorted { abs($0) < abs($1) }
    }
}

/// Shrinker for `Float`
public struct FloatShrinker: Shrinker { /* ... implementation ... */
    public typealias Value = Float
    public func shrink(_ value: Float) -> [Float] {
        guard value.isFinite && value != 0.0 else { return [] }
        var shrunkValues: [Float] = [0.0]
        let half = value / 2.0; if half.isFinite && half != value && half != 0.0 { shrunkValues.append(half) }
        if abs(value) > 1.0 { let closer = value > 0 ? value - 1.0 : value + 1.0; if closer.isFinite && closer != 0.0 && closer != half { shrunkValues.append(closer) } }
        let simple: [Float] = [1.0, -1.0]; for s in simple { if abs(s) < abs(value) && value != s && !shrunkValues.contains(s) { shrunkValues.append(s) } }
        return Array(Set(shrunkValues)).sorted { abs($0) < abs($1) }
    }
}

// MARK: - Combinator Shrinker Implementations

/// A shrinker that maps values through a transformation.
public struct MappedShrinker<From, To>: Shrinker {
    public typealias Value = To
    
    private let baseShrinker: any Shrinker<From>
    private let transform: @Sendable (From) -> To
    private let reverse: @Sendable (To) -> From
    
    public init(
        baseShrinker: any Shrinker<From>,
        transform: @escaping @Sendable (From) -> To,
        reverse: @escaping @Sendable (To) -> From
    ) {
        self.baseShrinker = baseShrinker
        self.transform = transform
        self.reverse = reverse
    }
    
    public func shrink(_ value: To) -> [To] {
        let originalValue = reverse(value)
        return baseShrinker.shrink(originalValue).map(transform)
    }
}

/// A shrinker for tuples of two values.
public struct TupleShrinker<A, B>: Shrinker {
    public typealias Value = (A, B)
    
    private let firstShrinker: any Shrinker<A>
    private let secondShrinker: any Shrinker<B>
    
    public init(first: any Shrinker<A>, second: any Shrinker<B>) {
        self.firstShrinker = first
        self.secondShrinker = second
    }
    
    public func shrink(_ value: (A, B)) -> [(A, B)] {
        var results: [(A, B)] = []
        
        // Shrink first component
        for shrunkFirst in firstShrinker.shrink(value.0) {
            results.append((shrunkFirst, value.1))
        }
        
        // Shrink second component
        for shrunkSecond in secondShrinker.shrink(value.1) {
            results.append((value.0, shrunkSecond))
        }
        
        // Shrink both components
        for shrunkFirst in firstShrinker.shrink(value.0) {
            for shrunkSecond in secondShrinker.shrink(value.1) {
                results.append((shrunkFirst, shrunkSecond))
            }
        }
        
        return results
    }
}

/// A shrinker that doesn't shrink anything.
public struct NoShrinkShrinker<T>: Shrinker {
    public typealias Value = T
    
    public init() {}
    
    public func shrink(_ value: T) -> [T] {
        return []
    }
}

/// A shrinker that combines multiple shrinkers.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public struct CombinedShrinker<T>: Shrinker {
    public typealias Value = T
    
    private let shrinkers: [any Shrinker<T>]
    
    public init(shrinkers: [any Shrinker<T>]) {
        self.shrinkers = shrinkers
    }
    
    public func shrink(_ value: T) -> [T] {
        var results: [T] = []
        for shrinker in shrinkers {
            results.append(contentsOf: shrinker.shrink(value))
        }
        return results
    }
}

