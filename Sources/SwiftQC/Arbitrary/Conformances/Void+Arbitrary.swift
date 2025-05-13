//
//  Void+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen


// A generic shrinker that performs no shrinking.
// This is often useful for types that are considered atomic or already minimal.
// Ideally, this would be in a more general Shrinkers utility file.

// A wrapper for Void to conform to Arbitrary
struct VoidWrapper: Arbitrary {
    public typealias Value = Void

    public static var gen: Gen<Void> {
        return Gen.always(()) // Gen.always expects a value of the generator's output type.
    }

    public static var shrinker: any Shrinker<Void> {
        return NoShrink<Void>()
    }
}

// Also, provide conformance for the empty tuple `()` if `Void` isn't automatically
// treated the same by the type system in all generic contexts for Arbitrary.
// Swift treats `Void` and `()` as the same type. Conformance for `Void` should suffice.