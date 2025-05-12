//
//  FloatingPoint+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen

extension Double: Arbitrary {
    public typealias Value = Double

    /// The default generator for `Double`.
    /// Generates values using `Gen.double(in:)`.
    /// By default, uses a range like -100...100, but consider adjusting if a different default is better.
    /// Users can always use `Gen.double(in: desiredRange)` directly with `forAll` for specific needs.
    public static var gen: Gen<Double> {
        // Using the static property from the imported Gen module.
        return Gen.double(in: -100...100) // Default range for Arbitrary conformance
    }

    /// The default shrinker for `Double`.
    /// Uses `Shrinkers.double`.
    public static var shrinker: any Shrinker<Double> {
        // Use the standard shrinker from BuiltinShrinkers.swift
        return Shrinkers.double
    }
}

extension Float: Arbitrary {
    public typealias Value = Float

    /// The default generator for `Float`.
    /// Generates values using `Gen.float(in:)`.
    /// By default, uses a range like -100...100, but consider adjusting if a different default is better.
    /// Users can always use `Gen.float(in: desiredRange)` directly with `forAll` for specific needs.
    public static var gen: Gen<Float> {
        // Using the static property from the imported Gen module.
        // Ensure range uses Float literals for clarity.
        return Gen.float(in: Float(-100)...Float(100)) // Default range for Arbitrary conformance
    }

    /// The default shrinker for `Float`.
    /// Uses `Shrinkers.float`.
    public static var shrinker: any Shrinker<Float> {
        // Use the standard shrinker from BuiltinShrinkers.swift
        return Shrinkers.float
    }
}

// Note: Consider adding Arbitrary conformance for other floating-point types
// like CGFloat if relevant to your target platforms and use cases,
// ensuring appropriate generators and shrinkers are available or created.