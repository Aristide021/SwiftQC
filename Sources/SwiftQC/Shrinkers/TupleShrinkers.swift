//
//  TupleShrinkers.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

// --- Shrinker for 2-Tuples (Pair) ---
public struct PairShrinker<A, B>: Shrinker {
    public typealias Value = (A, B)
    private let shrinkerA: any Shrinker<A>
    private let shrinkerB: any Shrinker<B>

    public init(_ sA: any Shrinker<A>, _ sB: any Shrinker<B>) {
        self.shrinkerA = sA
        self.shrinkerB = sB
    }
    // Alternative init with named parameters if preferred for clarity at call site:
    // public init(first sA: any Shrinker<A>, second sB: any Shrinker<B>) {
    //     self.shrinkerA = sA
    //     self.shrinkerB = sB
    // }

    public func shrink(_ value: (A, B)) -> [(A, B)] {
        var shrinks: [(A, B)] = []
        let (a, b) = value
        for sa in shrinkerA.shrink(a) { shrinks.append((sa, b)) }
        for sb in shrinkerB.shrink(b) { shrinks.append((a, sb)) }
        return shrinks
    }
}

// --- Shrinker for 3-Tuples (Triple) ---
public struct TripleShrinker<A, B, C>: Shrinker {
    public typealias Value = (A, B, C)
    private let sA: any Shrinker<A>
    private let sB: any Shrinker<B>
    private let sC: any Shrinker<C>

    public init(_ sA: any Shrinker<A>, _ sB: any Shrinker<B>, _ sC: any Shrinker<C>) {
        self.sA = sA; self.sB = sB; self.sC = sC
    }

    public func shrink(_ v: Value) -> [Value] {
        var s: [Value] = []
        let (a, b, c) = v
        sA.shrink(a).forEach { s.append(($0, b, c)) }
        sB.shrink(b).forEach { s.append((a, $0, c)) }
        sC.shrink(c).forEach { s.append((a, b, $0)) }
        return s
    }
}

// --- Shrinker for 4-Tuples (Quadruple) ---
public struct QuadrupleShrinker<A, B, C, D>: Shrinker {
    public typealias Value = (A, B, C, D)
    private let sA: any Shrinker<A>; private let sB: any Shrinker<B>
    private let sC: any Shrinker<C>; private let sD: any Shrinker<D>

    public init(_ sA: any Shrinker<A>, _ sB: any Shrinker<B>, _ sC: any Shrinker<C>, _ sD: any Shrinker<D>) {
        self.sA = sA; self.sB = sB; self.sC = sC; self.sD = sD
    }

    public func shrink(_ v: Value) -> [Value] {
        var s: [Value] = []
        let (a, b, c, d) = v
        sA.shrink(a).forEach { s.append(($0, b, c, d)) }
        sB.shrink(b).forEach { s.append((a, $0, c, d)) }
        sC.shrink(c).forEach { s.append((a, b, $0, d)) }
        sD.shrink(d).forEach { s.append((a, b, c, $0)) }
        return s
    }
}

// --- Shrinker for 5-Tuples (Quintuple) ---
public struct QuintupleShrinker<A, B, C, D, E>: Shrinker {
    public typealias Value = (A, B, C, D, E)
    private let sA: any Shrinker<A>; private let sB: any Shrinker<B>; private let sC: any Shrinker<C>
    private let sD: any Shrinker<D>; private let sE: any Shrinker<E>

    public init(_ sA: any Shrinker<A>, _ sB: any Shrinker<B>, _ sC: any Shrinker<C>, _ sD: any Shrinker<D>, _ sE: any Shrinker<E>) {
        self.sA = sA; self.sB = sB; self.sC = sC; self.sD = sD; self.sE = sE
    }

    public func shrink(_ v: Value) -> [Value] {
        var s: [Value] = []
        let (a, b, c, d, e) = v
        sA.shrink(a).forEach { s.append(($0, b, c, d, e)) }
        sB.shrink(b).forEach { s.append((a, $0, c, d, e)) }
        sC.shrink(c).forEach { s.append((a, b, $0, d, e)) }
        sD.shrink(d).forEach { s.append((a, b, c, $0, e)) }
        sE.shrink(e).forEach { s.append((a, b, c, d, $0)) }
        return s
    }
}

// To be added to Sources/SwiftQC/Shrinkers/BuiltinShrinkers.swift (Shrinkers enum) for convenience:
// Once we validate the logic for tuple shrinking is validated for these manual implementations, refactoring this to utilize swift-gen zip variants or automated code generation for tuple shrinkers is a future enhancement.