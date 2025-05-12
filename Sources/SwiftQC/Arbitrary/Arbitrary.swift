//
//  Arbitrary.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen // For Gen and global zip functions

// Assuming Shrinker protocol is defined and Sendable
// Assuming Gen type from swift-gen is Sendable or handled with @preconcurrency import where used by Gen itself

/// A type that can be randomly generated and shrunk.
/// Conforming types should be `Sendable` if they are to be used across concurrent contexts.
public protocol Arbitrary: Sendable { // Added Sendable
    /// The type of value generated and shrunk.
    /// If `Value` itself needs to be `Sendable` for specific `Arbitrary` conformances,
    /// that constraint should be added to the specific conforming type.
    associatedtype Value: Sendable
    
    /// A generator that produces random values of type `Value`.
    /// The `Gen<Value>` instance should be Sendable.
    static var gen: Gen<Value> { get }
    
    /// A shrinker that can produce simpler versions of `Value` instances.
    /// `any Shrinker<Value>` will be Sendable if the `Shrinker` protocol is Sendable.
    static var shrinker: any Shrinker<Value> { get }
}

// MARK: - Tuple Arbitrary Conformances

/// Arbitrary conformance for 2-element tuples.
public struct Tuple2<T1: Arbitrary, T2: Arbitrary>: Arbitrary, Sendable {
    public typealias Value = (T1.Value, T2.Value)
    public static var gen: Gen<Value> { zip(T1.gen, T2.gen) }
    public static var shrinker: any Shrinker<Value> {
        // Assumes PairShrinker init(_:_:) exists and takes any Shrinker<A>, any Shrinker<B>
        PairShrinker(T1.shrinker, T2.shrinker)
    }
}

/// Arbitrary conformance for 3-element tuples.
public struct Tuple3<T1: Arbitrary, T2: Arbitrary, T3: Arbitrary>: Arbitrary, Sendable {
    public typealias Value = (T1.Value, T2.Value, T3.Value)
    public static var gen: Gen<Value> { zip(T1.gen, T2.gen, T3.gen) }
    public static var shrinker: any Shrinker<Value> {
        TripleShrinker(T1.shrinker, T2.shrinker, T3.shrinker)
    }
}

/// Arbitrary conformance for 4-element tuples.
public struct Tuple4<T1: Arbitrary, T2: Arbitrary, T3: Arbitrary, T4: Arbitrary>: Arbitrary, Sendable {
    public typealias Value = (T1.Value, T2.Value, T3.Value, T4.Value)
    public static var gen: Gen<Value> { zip(T1.gen, T2.gen, T3.gen, T4.gen) }
    public static var shrinker: any Shrinker<Value> {
        QuadrupleShrinker(T1.shrinker, T2.shrinker, T3.shrinker, T4.shrinker)
    }
}

/// Arbitrary conformance for 5-element tuples.
public struct Tuple5<T1: Arbitrary, T2: Arbitrary, T3: Arbitrary, T4: Arbitrary, T5: Arbitrary>: Arbitrary, Sendable {
    public typealias Value = (T1.Value, T2.Value, T3.Value, T4.Value, T5.Value)
    public static var gen: Gen<Value> { zip(T1.gen, T2.gen, T3.gen, T4.gen, T5.gen) }
    public static var shrinker: any Shrinker<Value> {
        QuintupleShrinker(T1.shrinker, T2.shrinker, T3.shrinker, T4.shrinker, T5.shrinker)
    }
}
