//
//  Int+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen

extension Int: Arbitrary {
    public typealias Value = Int

    /// The default generator for `Int`.
    ///
    /// This generator produces integers across the full range of `Int`
    /// (i.e., `Int.min...Int.max`). It relies on the underlying `Gen.int(in:)`
    /// from the `swift-gen` library.
    public static var gen: Gen<Int> { // This Gen is SwiftQC.Gen (i.e., PointFreeGen.Gen)
        // Access static members on the imported module's Gen type.
        // The module is named "Gen" and the type is also "Gen".
        return Gen.int(in: Int.min ... Int.max) // Corrected: Was PointFreeGen.Gen.int
    }

    /// The default shrinker for `Int`.
    ///
    /// This uses `Shrinkers.int`, which shrinks an integer towards zero by halving its value
    /// and decrementing/incrementing its magnitude.
    public static var shrinker: any Shrinker<Int> {
        return Shrinkers.int
    }
}
