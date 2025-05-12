//
//  GeneratorsTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import XCTest
@testable import SwiftQC
import Gen

final class GeneratorsTests: XCTestCase {

    // MARK: - Basic Type Generators (Sanity Checks)

    func testIntGenerator_producesIntsWithinRange() {
        var rng = Xoshiro(seed: 0)
        let intGen = Gen.int(in: -5...5)
        var generatedValues: [Int] = []
        for _ in 0..<100 {
            generatedValues.append(intGen.run(using: &rng))
        }
        XCTAssertTrue(generatedValues.allSatisfy { (-5...5).contains($0) }, "All generated Ints should be within the specified range.")
        XCTAssertTrue(generatedValues.count == 100, "Should generate the expected number of values.")
    }

    func testBoolGenerator_producesBools() {
        var rng = Xoshiro(seed: 1)
        let boolGen = Gen.bool
        var trues = 0
        var falses = 0
        for _ in 0..<200 {
            if boolGen.run(using: &rng) {
                trues += 1
            } else {
                falses += 1
            }
        }
        XCTAssertTrue(trues > 0 && falses > 0, "Gen.bool should produce both true and false values over a number of runs.")
    }

    func testStringGenerator_producesStringsOfExpectedLengthAndChars() {
        var rng = Xoshiro(seed: 2)
        let charGen = Gen<Character>.letter
        let lengthGen = Gen.int(in: 3...10)
        let stringGen = charGen.string(of: lengthGen)

        var generatedStrings: [String] = []
        for _ in 0..<50 {
            generatedStrings.append(stringGen.run(using: &rng))
        }

        XCTAssertTrue(generatedStrings.allSatisfy { $0.count >= 3 && $0.count <= 10 }, "All generated strings should have lengths within the specified range.")
        XCTAssertTrue(generatedStrings.allSatisfy { s in s.allSatisfy { $0.isLetter } }, "All characters in generated strings should be letters.")
    }

    func testDoubleGenerator_producesDoublesWithinRange() {
        var rng = Xoshiro(seed: 3)
        let doubleGen = Gen.double(in: 0.0...1.0)
        var generatedValues: [Double] = []
        for _ in 0..<100 {
            generatedValues.append(doubleGen.run(using: &rng))
        }
        XCTAssertTrue(generatedValues.allSatisfy { $0 >= 0.0 && $0 <= 1.0 }, "All generated Doubles should be within the specified range.")
    }

    func testFloatGenerator_producesFloatsWithinRange() {
        var rng = Xoshiro(seed: 4)
        // Ensure the range provided to Gen.float is also clearly Float if type inference is tricky.
        // Using Float literals for the range itself is the most robust.
        let floatGen = Gen.float(in: Float(-1.0) ... Float(0.0))
        var generatedValues: [Float] = []
        for _ in 0..<100 {
            generatedValues.append(floatGen.run(using: &rng))
        }
        // Corrected assertion to use Float literals for comparison
        XCTAssertTrue(generatedValues.allSatisfy { $0 >= Float(-1.0) && $0 <= Float(0.0) }, "All generated Floats should be within the specified range.")
    }
    
    func testArrayGenerator_producesArraysWithCorrectElementsAndCount() {
        var rng = Xoshiro(seed: 5)
        let elementGen = Gen.int(in: 1...3)
        let countGen = Gen.int(in: 2...4)
        let arrayGen = elementGen.array(of: countGen)

        for _ in 0..<30 {
            let arr = arrayGen.run(using: &rng)
            XCTAssertTrue(arr.count >= 2 && arr.count <= 4, "Array count should be within specified range.")
            XCTAssertTrue(arr.allSatisfy { (1...3).contains($0) }, "All array elements should be within specified range.")
        }
    }

    func testOptionalGenerator_producesNilAndSome() {
        var rng = Xoshiro(seed: 6)
        let intGen = Gen.int(in: 0...100)
        let optionalIntGen = intGen.optional

        var nils = 0
        var somes = 0
        for _ in 0..<200 {
            if let val = optionalIntGen.run(using: &rng) {
                XCTAssertTrue((0...100).contains(val), "Generated Some(Int) was out of range.")
                somes += 1
            } else {
                nils += 1
            }
        }
        XCTAssertTrue(nils > 0, "Optional generator should produce nil values.")
        XCTAssertTrue(somes > 0, "Optional generator should produce non-nil values.")
    }

    // MARK: - Result Generator Tests
    enum GenTestError: Error, CaseIterable, Equatable, Arbitrary {
        case alpha, beta

        typealias Value = GenTestError
        static var gen: Gen<GenTestError> {
            guard !GenTestError.allCases.isEmpty else {
                fatalError("GenTestError.allCases cannot be empty.")
            }
            return Gen.element(of: GenTestError.allCases).compactMap { $0 }
        }
        static var shrinker: any Shrinker<GenTestError> { NoShrink() }
    }

    func testResultGenerator_producesSuccessAndFailure() {
        var rng = Xoshiro(seed: 7)
        let resultGen = Result<Int, GenTestError>.gen

        var successes = 0
        var failures = 0
        for _ in 0..<200 {
            switch resultGen.run(using: &rng) {
            case .success(let intVal):
                XCTAssertNotNil(intVal)
                successes += 1
            case .failure(let errVal):
                XCTAssertNotNil(errVal)
                failures += 1
            }
        }
        XCTAssertTrue(successes > 0, "Result generator should produce .success values.")
        XCTAssertTrue(failures > 0, "Result generator should produce .failure values.")
    }


    // MARK: - Generator Combinator Tests

    func testMapGenerator() {
        var rng = Xoshiro(seed: 10)
        let intGen = Gen.int(in: 1...5)
        let stringGen = intGen.map { "Value: \($0)" }

        for _ in 0..<20 {
            let str = stringGen.run(using: &rng)
            XCTAssertTrue(str.hasPrefix("Value: "), "Mapped string should have the prefix.")
            let numPart = Int(str.dropFirst("Value: ".count))
            XCTAssertNotNil(numPart, "Numeric part of string should be convertible to Int.")
            if let num = numPart {
                XCTAssertTrue((1...5).contains(num), "Numeric part should be from original Int range.")
            }
        }
    }

    func testFlatMapGenerator() {
        var rng = Xoshiro(seed: 11)
        let countGen = Gen.int(in: 1...3)
        let arrayGenViaFlatMap = countGen.flatMap { count in
            Gen.int(in: 10...20).array(of: .always(count))
        }

        for _ in 0..<20 {
            let arr = arrayGenViaFlatMap.run(using: &rng)
            XCTAssertTrue(arr.count >= 1 && arr.count <= 3, "Array count from flatMap incorrect.")
            XCTAssertTrue(arr.allSatisfy { (10...20).contains($0) }, "Array elements from flatMap incorrect.")
        }
    }

    func testZipGenerator() {
        var rng = Xoshiro(seed: 12)
        let genA = Gen.int(in: 1...10)
        let genB = Gen.bool
        let zippedGen = zip(genA, genB)

        for _ in 0..<20 {
            let (num, flag) = zippedGen.run(using: &rng)
            XCTAssertTrue((1...10).contains(num), "Zipped Int out of range.")
            XCTAssertNotNil(flag, "Zipped Bool was nil (should not happen).")
        }
    }
    
    func testConstantGenerator() {
        var rng = Xoshiro(seed: 13)
        let always42 = Gen.always(42)
        for _ in 0..<10 {
            XCTAssertEqual(always42.run(using: &rng), 42)
        }
    }

    func testFrequencyGenerator() {
        var rng = Xoshiro(seed: 14)
        let freqGen = Gen.frequency(
            (9, Gen.always("A")),
            (1, Gen.always("B"))
        )
        var countA = 0
        var countB = 0
        let totalRuns = 1000
        for _ in 0..<totalRuns {
            if freqGen.run(using: &rng) == "A" {
                countA += 1
            } else {
                countB += 1
            }
        }
        XCTAssertGreaterThan(countA, 750, "Frequency generator should heavily favor 'A'.")
        XCTAssertLessThan(countB, 250, "Frequency generator should produce 'B' less often.")
        XCTAssertEqual(countA + countB, totalRuns)
    }


    // MARK: - Deterministic Seeding Tests

    func testGeneratorsAreDeterministicWithSameSeed() {
        var rng1_seed123 = Xoshiro(seed: 123)
        var rng2_seed123 = Xoshiro(seed: 123)
        var rng3_seed456 = Xoshiro(seed: 456)

        let intGen = Gen.int(in: 0...1000)
        let val1_int_rng1 = intGen.run(using: &rng1_seed123)
        let val2_int_rng1 = intGen.run(using: &rng1_seed123)

        let val1_int_rng2 = intGen.run(using: &rng2_seed123)
        let val2_int_rng2 = intGen.run(using: &rng2_seed123)

        let val1_int_rng3 = intGen.run(using: &rng3_seed456)

        XCTAssertEqual(val1_int_rng1, val1_int_rng2, "First Int from same seed should be identical.")
        XCTAssertEqual(val2_int_rng1, val2_int_rng2, "Second Int from same seed should be identical.")
        XCTAssertNotEqual(val1_int_rng1, val1_int_rng3, "Ints from different seeds should likely differ.")

        let stringGen = String.gen
        let val1_str_rng1 = stringGen.run(using: &rng1_seed123)
        let val1_str_rng2 = stringGen.run(using: &rng2_seed123)
        XCTAssertEqual(val1_str_rng1, val1_str_rng2, "String from same seed (after prior Int gen) should be identical.")

        var sRng1 = Xoshiro(seed: 789)
        var sRng2 = Xoshiro(seed: 789)

        let r1_bool = Bool.gen.run(using: &sRng1)
        let r1_int = Int.gen.run(using: &sRng1)
        let r1_str = String.gen.run(using: &sRng1)

        let r2_bool = Bool.gen.run(using: &sRng2)
        let r2_int = Int.gen.run(using: &sRng2)
        let r2_str = String.gen.run(using: &sRng2)

        XCTAssertEqual(r1_bool, r2_bool)
        XCTAssertEqual(r1_int, r2_int)
        XCTAssertEqual(r1_str, r2_str)
    }
}

// REMOVED NoShrink from here. It should be defined once,
// for example, in ShrinkersTests.swift or a shared TestHelpers.swift file.
// Assuming NoShrink is accessible because it's internal in the same test target.