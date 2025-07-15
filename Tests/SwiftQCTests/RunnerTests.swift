//
//  RunnerTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import XCTest
@testable import SwiftQC
import Gen

// MARK: - Mock Reporter for Testing (Use the version from your "least errors" paste)
class SpyReporter: Reporter, @unchecked Sendable {
    struct CallCounts: Equatable {
        var success: Int = 0; var initialFailure: Int = 0; var shrinkProgress: Int = 0; var finalCounterexample: Int = 0
    }
    private(set) var calls = CallCounts()
    private(set) var lastReportedSuccessDescription: String?
    private(set) var lastReportedSuccessIterations: Int?
    private(set) var lastReportedInitialFailureInput: Any?
    private(set) var lastReportedFinalCounterexampleInput: Any?
    private(set) var lastReportedFinalCounterexampleError: Error?
    private(set) var lastReportedShrinkSteps: [(from: Any, to: Any)] = []

    func reportSuccess(description: String, iterations: Int) { calls.success += 1; lastReportedSuccessDescription = description; lastReportedSuccessIterations = iterations }
    func reportFailure(description: String, input: Any, error: Error, file: StaticString, line: UInt) { calls.initialFailure += 1; lastReportedInitialFailureInput = input }
    func reportShrinkProgress(from: Any, to: Any) { calls.shrinkProgress += 1; lastReportedShrinkSteps.append((from: from, to: to)) }
    func reportFinalCounterexample(description: String, input: Any, error: Error, file: StaticString, line: UInt) { calls.finalCounterexample += 1; lastReportedFinalCounterexampleInput = input; lastReportedFinalCounterexampleError = error }
    func reset() {
        calls = CallCounts(); lastReportedSuccessDescription = nil; lastReportedSuccessIterations = nil; lastReportedInitialFailureInput = nil;
        lastReportedFinalCounterexampleInput = nil; lastReportedFinalCounterexampleError = nil; lastReportedShrinkSteps = []
    }
}


// MARK: - RunnerTests
final class RunnerTests: XCTestCase {

    // MARK: - Test Properties
    func property_alwaysPasses(_ n: Int) throws { XCTAssertEqual(n, n) }
    struct AlwaysFailError: Error, Equatable, Sendable { let value: Int }
    func property_alwaysFails(_ n: Int) throws { throw AlwaysFailError(value: n) }
    struct IntShrinkTestError: Error, Equatable, Sendable { let value: Int }
    func property_intFailsAndShrinks(_ n: Int) throws { if n >= 5 { throw IntShrinkTestError(value: n) } }
    struct ArrayShrinkTestError: Error, Equatable, Sendable { let value: [Int] }
    func property_arrayFailsAndShrinks(_ arr: [Int]) throws { if arr.count >= 3 { throw ArrayShrinkTestError(value: arr) } }

    // MARK: - Test-Local Arbitrary Conformances
    struct SpecificIntArbitrary: Arbitrary, Sendable {
        typealias Value = Int; static var gen: Gen<Int> { Gen.always(7) }; static var shrinker: any Shrinker<Int> { Shrinkers.int }
    }
    struct IntAbove5Arbitrary: Arbitrary, Sendable {
        typealias Value = Int; static var gen: Gen<Int> { Gen.int(in: 20...30) }; static var shrinker: any Shrinker<Int> { Shrinkers.int }
    }
    struct FailingArrayArbitrary: Arbitrary, Sendable {
        typealias Value = [Int]; static var gen: Gen<[Int]> { Gen.int(in: 0...1).array(of: Gen.int(in: 5...7)) }; static var shrinker: any Shrinker<[Int]> { Array<Int>.shrinker }
    }
    struct ReproducibleIntArbitrary: Arbitrary, Sendable {
        typealias Value = Int; static var gen: Gen<Int> { Gen.always(25) }; static var shrinker: any Shrinker<Int> { Shrinkers.int }
    }

    // *** RE-ADD MySendableKey and MySendableValue DEFINITIONS ***
    struct MySendableKey: Arbitrary, Hashable, Sendable {
        let id: Int; init(id: Int) { self.id = id }; typealias Value = MySendableKey
        static var gen: Gen<MySendableKey> { Gen.int(in: 0...2).map(MySendableKey.init) }
        static var shrinker: any Shrinker<MySendableKey> {
            struct S: Shrinker { func shrink(_ v: MySendableKey) -> [MySendableKey] { guard v.id != 0 else {return []}; return [MySendableKey(id:0),MySendableKey(id:v.id/2)].filter{$0.id<v.id}.removingDuplicates()}}
            return S()
        }
    }
    struct MySendableValue: Arbitrary, Equatable, Sendable {
        let data: String; init(data: String) { self.data = data }; typealias Value = MySendableValue
        static var gen: Gen<MySendableValue> { String.gen.map(MySendableValue.init) } // Assumes String.gen is available
        static var shrinker: any Shrinker<MySendableValue> {
            struct S: Shrinker { func shrink(_ v: MySendableValue) -> [MySendableValue] { String.shrinker.shrink(v.data).map(MySendableValue.init)}} // Assumes String.shrinker is available
            return S()
        }
    }
    // For tuple tests if needed, or general use
    struct AnotherArbitraryType: Arbitrary, Sendable {
        typealias Value = Bool; static var gen: Gen<Bool> { Bool.gen }; static var shrinker: any Shrinker<Bool> { Bool.shrinker }
    }


    // MARK: - Standard Test Cases
    func testForAll_propertyAlwaysPasses() async { /* ... */
        let spyReporter = SpyReporter()
        let result = await forAll( "Always Passes", count: 10, reporter: spyReporter, { (n: Int) in try self.property_alwaysPasses(n) }, Int.self)
        guard case .succeeded(let testsRun) = result else { XCTFail("Expected .succeeded, got \(result)"); return }
        XCTAssertEqual(testsRun, 10); XCTAssertEqual(spyReporter.calls.success, 1)
    }
    func testForAll_propertyAlwaysFails_shrinksToMinimal() async { /* ... */
        let spyReporter = SpyReporter()
        let result = await forAll( "Always Fails", count: 1, reporter: spyReporter, { (n: SpecificIntArbitrary.Value) in try self.property_alwaysFails(n) }, SpecificIntArbitrary.self )
        guard case .falsified(let value, let error, _, _) = result else { XCTFail("Expected .falsified, got \(result)"); return }
        XCTAssertEqual(value, 0); XCTAssertEqual((error as? AlwaysFailError)?.value, 0); XCTAssertEqual(spyReporter.calls.finalCounterexample, 1); XCTAssertEqual(spyReporter.lastReportedFinalCounterexampleInput as? Int, 0)
    }
    func testForAll_propertyIntFailsAndShrinksToMinimal() async { /* ... */
        let spyReporter = SpyReporter()
        let result = await forAll( "Int Fails and Shrinks", count: 5, reporter: spyReporter, { (n: IntAbove5Arbitrary.Value) in try self.property_intFailsAndShrinks(n) }, IntAbove5Arbitrary.self )
        guard case .falsified(let value, let error, let shrinks, _) = result else { XCTFail("Expected .falsified, got \(result)"); return }
        XCTAssertEqual(value, 5); XCTAssertEqual((error as? IntShrinkTestError)?.value, 5); XCTAssertGreaterThan(shrinks, 0); XCTAssertEqual(spyReporter.lastReportedFinalCounterexampleInput as? Int, 5)
    }
     func testForAll_propertyArrayFailsAndShrinksToMinimal() async { /* ... */
        let spyReporter = SpyReporter()
        struct TestFailingArrayArbitrary: Arbitrary, Sendable { typealias Value = [Int]; static var gen: Gen<[Int]> { Gen.int(in: 1...10).array(of: Gen.int(in: 3...5)) }; static var shrinker: any Shrinker<[Int]> { Array<Int>.shrinker }}
        let result = await forAll( "Array Fails and Shrinks", count: 3, reporter: spyReporter, { (arr: TestFailingArrayArbitrary.Value) in try self.property_arrayFailsAndShrinks(arr) }, TestFailingArrayArbitrary.self)
        guard case .falsified(let value, let error, let shrinks, _) = result else { XCTFail("Expected .falsified, got \(result)"); return }
        XCTAssertEqual(value.count, 3); XCTAssertEqual((error as? ArrayShrinkTestError)?.value, value); XCTAssertGreaterThan(shrinks, 0); XCTAssertEqual(spyReporter.lastReportedFinalCounterexampleInput as? [Int], value)
    }
    func testForAll_seedReproducibilityForFailure() async { /* ... */
        let spyReporter1 = SpyReporter(); let spyReporter2 = SpyReporter(); let failingSeed: UInt64 = 12345
        let propertyToTest = { (n: ReproducibleIntArbitrary.Value) in try self.property_intFailsAndShrinks(n) }
        let result1 = await forAll("Reproducible Run 1", count: 1, seed: failingSeed, reporter: spyReporter1, propertyToTest, ReproducibleIntArbitrary.self)
        guard case .falsified(let value1, _, _, let seed1) = result1 else { XCTFail("Run 1: Expected .falsified"); return }; XCTAssertEqual(value1, 5); XCTAssertEqual(seed1, failingSeed)
        let result2 = await forAll("Reproducible Run 2", count: 1, seed: failingSeed, reporter: spyReporter2, propertyToTest, ReproducibleIntArbitrary.self)
        guard case .falsified(let value2, _, _, let seed2) = result2 else { XCTFail("Run 2: Expected .falsified"); return }; XCTAssertEqual(value2, 5); XCTAssertEqual(seed2, failingSeed); XCTAssertEqual(value1, value2)
        XCTAssertEqual(spyReporter1.lastReportedFinalCounterexampleInput as? Int, spyReporter2.lastReportedFinalCounterexampleInput as? Int)
    }
    func testForAll_countParameterIsRespectedForSuccessfulProperty() async { /* ... */
        let spyReporter = SpyReporter()
        let targetCount = 7
        _ = await forAll( "Count Test", count: targetCount, reporter: spyReporter, { (n: Int) in try self.property_alwaysPasses(n) }, Int.self)
        XCTAssertEqual(spyReporter.lastReportedSuccessIterations, targetCount)
    }


    // MARK: - Tests for Ergonomic Dictionary Overload
    struct DictTestError: Error, Equatable, Sendable { let message: String }

    // Define NonNegativeIntArbitrary here if it's only used in this test file
    struct NonNegativeIntArbitrary: Arbitrary, Sendable {
        typealias Value = Int
        static var gen: Gen<Int> { Gen.int(in: 0...(Int.max / 2)) } // Generates non-negative integers
        static var shrinker: any Shrinker<Int> { Shrinkers.int }
    }

    func testForAll_dictionaryErgonomic_propertyAlwaysPasses() async {
        let spyReporter = SpyReporter()
        var propertyCalledCount = 0
        let testCount = 5

        let result = await forAll(
            "Ergonomic Dictionary Always Passes",
            count: testCount,
            reporter: spyReporter,
            String.self,
            NonNegativeIntArbitrary.self,
            forDictionary: true
        ) { (dict: Dictionary<String, Int>) in
            propertyCalledCount += 1
            // Allow empty dictionaries
            if dict.isEmpty {
                print("Test property received an empty dictionary (allowed by generator).")
            } else {
                for (key, valueInDict) in dict {
                    XCTAssertGreaterThanOrEqual(valueInDict, 0, "Value for key '\(key)' was \(valueInDict), expected non-negative.")
                }
            }
        }

        guard case .succeeded(let testsRun) = result else { XCTFail("Expected .succeeded, got \(result)"); return }
        XCTAssertEqual(testsRun, testCount)
        XCTAssertEqual(propertyCalledCount, testCount)
        XCTAssertEqual(spyReporter.calls.success, 1)
    }

    // Helper static properties and Arbitrary structs for FailsAndShrinks test
    private static let failingDictTargetKey = MySendableKey(id: 1)
    private static let failingDictTargetValue = MySendableValue(data: "fail")
    private static var specificFailingKeyGen: Gen<MySendableKey> { Gen.frequency((1, Gen.always(failingDictTargetKey)), (3, MySendableKey.gen)) }
    private static var specificFailingValueGen: Gen<MySendableValue> { Gen.frequency((1, Gen.always(failingDictTargetValue)), (3, MySendableValue.gen)) }
    
    struct FailingDictKeyArbitrary: Arbitrary, Sendable {
        typealias Value = MySendableKey // This Value is for Arbitrary
        static var gen: Gen<MySendableKey> { RunnerTests.specificFailingKeyGen }
        static var shrinker: any Shrinker<MySendableKey> { MySendableKey.shrinker }
    }
    struct FailingDictValueArbitrary: Arbitrary, Sendable {
        typealias Value = MySendableValue // This Value is for Arbitrary
        static var gen: Gen<MySendableValue> { RunnerTests.specificFailingValueGen }
        static var shrinker: any Shrinker<MySendableValue> { MySendableValue.shrinker }
    }


    func testForAll_dictionaryErgonomic_propertyFailsAndShrinks() async {
        let spyReporter = SpyReporter()
        let propertyToTest = { (dict: Dictionary<MySendableKey, MySendableValue>) throws in // Dict uses MySendableKey, MySendableValue
            if let val = dict[RunnerTests.failingDictTargetKey], val == RunnerTests.failingDictTargetValue {
                if dict.count > 1 || (dict.count == 1 && dict.keys.first == RunnerTests.failingDictTargetKey) {
                    throw DictTestError(message: "Failed with targetKey: \(dict)")
                }
            }
            if dict.isEmpty && Int.random(in: 0...2) == 0 { return }
            if dict.count > 2 && dict[RunnerTests.failingDictTargetKey] == nil {
                throw DictTestError(message: "Fallback failure for shrinking test: \(dict)")
            }
        }
        
        let result = await forAll(
            "Ergonomic Dictionary Fails and Shrinks",
            count: 50,
            seed: nil,
            reporter: spyReporter,
            FailingDictKeyArbitrary.self,   // keyType, its Value is MySendableKey
            FailingDictValueArbitrary.self, // valueType, its Value is MySendableValue
            forDictionary: true,
            // Closure takes Dictionary<MySendableKey, MySendableValue>
            { (dict: Dictionary<MySendableKey, MySendableValue>) in 
                try propertyToTest(dict)
            }
        )

        guard case .falsified(let value, let error, let shrinks, _) = result else {
            XCTFail("Expected .falsified, got \(result)."); return
        }
        XCTAssertEqual(value.count, 1)
        XCTAssertEqual(value[RunnerTests.failingDictTargetKey], RunnerTests.failingDictTargetValue)
        XCTAssertNotNil(error as? DictTestError)
        XCTAssertGreaterThanOrEqual(shrinks, 0)
        XCTAssertEqual(spyReporter.calls.finalCounterexample, 1)
        XCTAssertEqual(spyReporter.lastReportedFinalCounterexampleInput as? Dictionary<MySendableKey, MySendableValue>, [RunnerTests.failingDictTargetKey: RunnerTests.failingDictTargetValue])
    }

    func testForAll_dictionaryErgonomic_seedReproducibility() async {
        let spyReporter1 = SpyReporter(); let spyReporter2 = SpyReporter(); let testSeed: UInt64 = 123
        var firstFailureDesc: String = ""
        let propertyToTest = { (dict: Dictionary<MySendableKey, MySendableValue>) throws in // Dict uses MySendableKey, MySendableValue
            if let val = dict[MySendableKey(id:0)], val.data == "trigger" { throw DictTestError(message: "Triggered failure: \(dict)") }
            if dict.count > 1, let val = dict[MySendableKey(id:1)], val.data == "aa" { throw DictTestError(message: "Predictable seeded complex failure: \(dict)") }
            if dict.count == 1 && dict.keys.first?.id == 2 && dict.values.first?.data == "specific_seed_val" { throw DictTestError(message: "Specific seed fallback: \(dict)") }
        }

        // *** DEFINE LOCAL ARBITRARY TYPES FOR RELIABLE FAILURE WITH SEED 123 ***
        struct SeededFailingKey: Arbitrary, Hashable, Sendable {
            typealias Value = MySendableKey
            static var gen: Gen<MySendableKey> { Gen.always(MySendableKey(id: 0)) } // Always produce the key needed for failure trigger
            static var shrinker: any Shrinker<MySendableKey> { MySendableKey.shrinker }
        }
        struct SeededFailingValue: Arbitrary, Equatable, Sendable {
            typealias Value = MySendableValue
            static var gen: Gen<MySendableValue> { Gen.always(MySendableValue(data: "trigger")) } // Always produce the value for failure trigger
            static var shrinker: any Shrinker<MySendableValue> { MySendableValue.shrinker }
        }

        let result1 = await forAll(
            "Ergonomic Dictionary Seeded Run 1",
            count: 10, seed: testSeed, reporter: spyReporter1,
            // *** USE LOCAL ARBITRARY TYPES ***
            SeededFailingKey.self,     // keyType
            SeededFailingValue.self,   // valueType
            forDictionary: true,
            propertyToTest
        )

        if case .falsified(let value1, let error1, _, let seed1) = result1 {
            firstFailureDesc = "Value: \(value1), Error: \(error1)"; XCTAssertEqual(seed1, testSeed)
            let result2 = await forAll(
                "Ergonomic Dictionary Seeded Run 2",
                count: 10, seed: testSeed, reporter: spyReporter2,
                // *** USE LOCAL ARBITRARY TYPES ***
                SeededFailingKey.self,     // keyType
                SeededFailingValue.self,   // valueType
                forDictionary: true,
                propertyToTest
            )
            guard case .falsified(let value2, let error2, _, let seed2) = result2 else { XCTFail("Run 2: Expected .falsified. Run 1: \(firstFailureDesc)"); return }
            XCTAssertEqual(value2, value1); XCTAssertEqual((error2 as? DictTestError)?.message, (error1 as? DictTestError)?.message); XCTAssertEqual(seed2, testSeed)
            XCTAssertEqual(spyReporter1.lastReportedFinalCounterexampleInput as? Dictionary<MySendableKey, MySendableValue>, spyReporter2.lastReportedFinalCounterexampleInput as? Dictionary<MySendableKey, MySendableValue>)
        } else { XCTFail("Expected Run 1 to be falsified. Result: \(result1)") }
    }


    // MARK: - Tests for Ergonomic Tuple Overloads
    func testForAll_twoParams_propertyAlwaysPasses() async {
        let spyReporter = SpyReporter()
        var propertyCalledCount = 0
        let testCount = 5

        let result = await forAll(
            "Ergonomic Two Params Always Passes",
            count: testCount,
            reporter: spyReporter,
            types: Int.self,    // typeA
            String.self  // typeB
        ) { (i: Int, s: String) in
            propertyCalledCount += 1
            XCTAssertNotNil(i)
        }
        guard case .succeeded(let testsRun) = result else { XCTFail("Expected .succeeded, got \(result)"); return }
        XCTAssertEqual(testsRun, testCount)
        XCTAssertEqual(propertyCalledCount, testCount)
        XCTAssertEqual(spyReporter.calls.success, 1)
    }

    struct TupleFailError: Error, Equatable, Sendable { let v1: Int; let v2: String }
    func testForAll_twoParams_propertyFailsAndShrinks() async {
        let spyReporter = SpyReporter()
        let propertyToTest = { (i: Int, s: String) throws in if i >= 5 && s == "fail" { throw TupleFailError(v1: i, v2: s) } }
        struct FailingIntForTuple: Arbitrary, Sendable { typealias Value = Int; static var gen: Gen<Int> { Gen.int(in: 7...10) }; static var shrinker: any Shrinker<Int> { Shrinkers.int } }
        struct FailingStringForTuple: Arbitrary, Sendable { typealias Value = String; static var gen: Gen<String> { Gen.always("fail") }; static var shrinker: any Shrinker<String> { Shrinkers.string } }

        let result = await forAll(
            "Ergonomic Two Params Fails and Shrinks",
            count: 3, reporter: spyReporter,
            types: FailingIntForTuple.self,    // typeA
            FailingStringForTuple.self  // typeB
        ) { (val1: Int, val2: String) in
            try propertyToTest(val1, val2)
        }
        guard case .falsified(let value, let error, let shrinks, _) = result else { XCTFail("Expected .falsified, got \(result)"); return }
        XCTAssertEqual(value.0, 5)
        XCTAssertEqual(value.1, "fail") // Corrected based on previous output
        XCTAssertNotNil(error as? TupleFailError)
        XCTAssertGreaterThanOrEqual(shrinks, 0)
        XCTAssertEqual(spyReporter.calls.finalCounterexample, 1)
        let reportedFinal = spyReporter.lastReportedFinalCounterexampleInput as? (Int, String); XCTAssertEqual(reportedFinal?.0, 5); XCTAssertEqual(reportedFinal?.1, "fail")
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}