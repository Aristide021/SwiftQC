//
//  UnicodeScalar+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen

public struct UnicodeScalarShrinker: Shrinker {
    public typealias Value = Unicode.Scalar

    // Construct simpleScalars safely, ensuring they are valid Unicode.Scalars
    private let simpleScalars: [Unicode.Scalar] = [
        "a", "A", "0", " ", "\n", "\t",
        "b", "c", "1", "2", ".", ",",
    ].compactMap { charString in Unicode.Scalar(charString) } // Use the failable String initializer

    public func shrink(_ value: Unicode.Scalar) -> [Unicode.Scalar] {
        var shrinks: [Unicode.Scalar] = []

        let nullScalar = Unicode.Scalar(0)!
        if value.value > 0 && value != nullScalar {
            shrinks.append(nullScalar)
        }

        for simple in simpleScalars {
            if simple.value < value.value && value != simple {
                shrinks.append(simple)
            }
        }

        if value.value > 1 {
            if let halvedScalar = Unicode.Scalar(value.value / 2),
               halvedScalar.value < value.value,
               !shrinks.contains(halvedScalar) {
                shrinks.append(halvedScalar)
            }
        }

        // Check specific common scalars independently
        if let spaceScalar = Unicode.Scalar(32), value.value > spaceScalar.value, value != spaceScalar {
            shrinks.append(spaceScalar)
        }
        if let aScalar = Unicode.Scalar(97), value.value > aScalar.value, value != aScalar {
            shrinks.append(aScalar)
        }
        if let zeroScalar = Unicode.Scalar(48), value.value > zeroScalar.value, value != zeroScalar {
            shrinks.append(zeroScalar)
        }

        // Deduplicate and sort by scalar value
        return Array(Set(shrinks.filter { $0.value < value.value })).sorted { $0.value < $1.value }
    }
}

extension Unicode.Scalar: Arbitrary {
    public typealias Value = Unicode.Scalar

    public static var gen: Gen<Unicode.Scalar> {
        let genPrintableASCII = Gen.uint32(in: 0x0020...0x007E).compactMap(Unicode.Scalar.init)
        let genLatin1Supplement = Gen.uint32(in: 0x00A0...0x00FF).compactMap(Unicode.Scalar.init)
        let genGeneralPunctuation = Gen.uint32(in: 0x2000...0x206F).compactMap(Unicode.Scalar.init)
        
        // Ensure you are using the correct method to combine generators
        return Gen.frequency([
            (1, genPrintableASCII),
            (1, genLatin1Supplement),
            (1, genGeneralPunctuation)
        ])
    }

    public static var shrinker: any Shrinker<Unicode.Scalar> { UnicodeScalarShrinker() }
}