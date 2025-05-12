//
//  String+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen // Import the PointFree Gen module
import Foundation // For Character, String

extension String: Arbitrary {
    public typealias Value = String

    /// This generator produces random strings of characters, typically between 0 and 100 characters long.
    /// It uses alphanumeric characters by default.
    public static var gen: Gen<String> {
        // 1. Define the generator for the characters you want in the string.
        //    To get alphanumeric characters, we can use Gen.frequency to combine
        //    letter and digit generators.
        let alphanumericCharacterGenerator: Gen<Character> = Gen.frequency(
            (26, Gen<Character>.letter), // Assuming ~26 letters for weighting
            (10, Gen<Character>.number)   // Assuming 10 numbers for weighting
        )
        // Adjust weights as desired. For example, (52, Gen<Character>.letter) if you want
        // to account for uppercase and lowercase, though .letter usually covers both.
        // Alternatively, a more direct way if .letter includes both cases:
        // let alphanumericCharacterGenerator: Gen<Character> = Gen.one(of: [
        //     Gen<Character>.letter,
        //     Gen<Character>.digit
        // ])
        // For simplicity and common use, Gen.frequency is often preferred for weighted choices.

        // 2. Define the generator for the length of the string.
        let lengthGenerator: Gen<Int> = Gen.int(in: 0...100)

        // 3. Use the instance method `string(of:)` on the character generator.
        return alphanumericCharacterGenerator.string(of: lengthGenerator)
    }

    /// This uses the built-in string shrinker from `Shrinkers.string`.
    public static var shrinker: any Shrinker<String> {
        return Shrinkers.string
    }
}