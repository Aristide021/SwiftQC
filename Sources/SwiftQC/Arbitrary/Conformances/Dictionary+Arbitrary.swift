//
//  Dictionary+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen

// --- Helper Shrinker (can remain fileprivate) ---
// (Keep the DictionaryShrinker struct definition exactly as it was in the previous correct version)
fileprivate struct DictionaryShrinker<ShrinkerKey: Hashable & Sendable, ShrinkerValue: Sendable>: Shrinker {
    typealias Value = Dictionary<ShrinkerKey, ShrinkerValue>
    private let keyShrinker: any Shrinker<ShrinkerKey>
    private let valueShrinker: any Shrinker<ShrinkerValue>

    init(keyShrinker: any Shrinker<ShrinkerKey>, valueShrinker: any Shrinker<ShrinkerValue>) {
        self.keyShrinker = keyShrinker
        self.valueShrinker = valueShrinker
    }

    func shrink(_ dictionary: Dictionary<ShrinkerKey, ShrinkerValue>) -> [Dictionary<ShrinkerKey, ShrinkerValue>] {
        guard !dictionary.isEmpty else { return [] }
        var shrinks: [Dictionary<ShrinkerKey, ShrinkerValue>] = [[:]]
        if dictionary.count > 1 {
            let pairs = Array(dictionary)
            let halfPairsSlice = pairs.prefix(dictionary.count / 2)
            // Map to unlabeled tuples as required by some initializers
            let sequenceForInit = halfPairsSlice.map { ($0.key, $0.value) }
            let halfDict = Dictionary<ShrinkerKey, ShrinkerValue>(uniqueKeysWithValues: sequenceForInit)
            if halfDict.count < dictionary.count { shrinks.append(halfDict) }
        }
        if dictionary.count >= 1 {
            var oneLess = dictionary
            if let key = dictionary.keys.first { oneLess.removeValue(forKey: key); if oneLess.count < dictionary.count { shrinks.append(oneLess) } }
        }
        for (key, value) in dictionary {
            for shrunkValue in valueShrinker.shrink(value) {
                var newDict = dictionary; newDict[key] = shrunkValue; shrinks.append(newDict)
            }
        }
        return shrinks.sorted { $0.count < $1.count }
    }
}


// --- Wrapper Struct for Arbitrary Dictionary ---
// Define a struct that *provides* the Arbitrary conformance for a Dictionary.
// The generic parameters KeyArbitraryType and ValueArbitraryType are constrained to Arbitrary.
public struct ArbitraryDictionary<KeyArbitraryType: Arbitrary, ValueArbitraryType: Arbitrary>: Arbitrary
    where KeyArbitraryType.Value: Hashable // The Key's *associated type* must be Hashable
{
    // This struct doesn't store data; it's just a namespace for the conformance.

    // Define the Arbitrary protocol's associated type 'Value'.
    // This IS the Dictionary type constructed from the associated types of our generic parameters.
    public typealias Value = Dictionary<KeyArbitraryType.Value, ValueArbitraryType.Value>

    // gen must return Gen<Self.Value>
    public static var gen: Gen<Self.Value> {
        // Use the generic parameters KeyArbitraryType and ValueArbitraryType
        let pairGen = zip(KeyArbitraryType.gen, ValueArbitraryType.gen) // Produces Gen<(KeyArbitraryType.Value, ValueArbitraryType.Value)>
        let countGen = Gen.int(in: 0...50)
        let pairArrayGen = pairGen.array(of: countGen) // Produces Gen<[(KeyArbitraryType.Value, ValueArbitraryType.Value)]>

        // Map to Self.Value (Dictionary<KeyArbitraryType.Value, ValueArbitraryType.Value>)
        return pairArrayGen.map { pairs -> Self.Value in
             return Self.Value(pairs, uniquingKeysWith: { first, _ in first })
        }
    }

    // shrinker must return any Shrinker<Self.Value>
    public static var shrinker: any Shrinker<Self.Value> {
        // Instantiate the helper shrinker with the correct associated types
        return DictionaryShrinker<KeyArbitraryType.Value, ValueArbitraryType.Value>(
            keyShrinker: KeyArbitraryType.shrinker,   // Provides any Shrinker<KeyArbitraryType.Value>
            valueShrinker: ValueArbitraryType.shrinker // Provides any Shrinker<ValueArbitraryType.Value>
        )
    }
}