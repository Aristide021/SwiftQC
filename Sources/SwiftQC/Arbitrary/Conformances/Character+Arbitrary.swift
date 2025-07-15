//
//  Character+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen
// import Foundation // For CharacterSet if you use it

public struct CharacterShrinker: Shrinker {
    public typealias Value = Character

    internal let simpleChars: [Character] = [
        "a", "A", "0", " ", "\n", "\t",
        "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "1", "2", "3", "4", "5", "6", "7", "8", "9",
        ".", ",", "!", "?", "-", "_", "(", ")", "[", "]", "{", "}", "/", "\\", ":", ";"
    ]

    public func shrink(_ value: Character) -> [Character] {
        var shrinks: [Character] = []

        if let index = simpleChars.firstIndex(of: value) {
            shrinks.append(contentsOf: simpleChars.prefix(upTo: index))
        } else {
            shrinks.append(contentsOf: simpleChars)
            if value.unicodeScalars.count == 1, let scalar = value.unicodeScalars.first {
                let scalarShrinker = UnicodeScalarShrinker()
                for shrunkScalar in scalarShrinker.shrink(scalar) {
                    let shrunkChar = Character(shrunkScalar)
                    if shrunkChar != value && !shrinks.contains(shrunkChar) {
                        shrinks.append(shrunkChar)
                    }
                }
            }
        }
        
        return Array(Set(shrinks.filter { $0 != value })).sorted(by: { c1, c2 in
            let idx1 = simpleChars.firstIndex(of: c1); let idx2 = simpleChars.firstIndex(of: c2)
            if let i1 = idx1, let i2 = idx2 { return i1 < i2 }
            if idx1 != nil { return true }; if idx2 != nil { return false }
            return String(c1) < String(c2)
        })
    }
}

extension Character: Arbitrary {
    public typealias Value = Character

    public static var gen: Gen<Character> {
        let punctuationChars: [Character] = [".", ",", "!", "?", "-", "'", "\"", "(", ")"]
        // Gen<Character>.whitespaceAndNewline does not exist; define whitespaceGen manually
        let whitespaceChars: [Character] = [" ", "\t", "\n", "\r"]
        let whitespaceGen = Gen.element(of: whitespaceChars).compactMap { $0 }

        return Gen.frequency(
            (50, Gen<Character>.letter),
            (20, Gen<Character>.number),
            (15, whitespaceGen), // Use the combined whitespace generator
            (15, Gen.element(of: punctuationChars).compactMap { $0 }) // Gen.element(of:) returns Gen<Element?>
                                                                     // so compactMap to Gen<Element> if array is non-empty
        )
    }

    public static var shrinker: any Shrinker<Character> { CharacterShrinker() }
}