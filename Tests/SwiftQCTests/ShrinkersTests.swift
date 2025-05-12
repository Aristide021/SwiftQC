//
//  ShrinkersTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import XCTest
@testable import SwiftQC // Use @testable to access internal types if needed
import Gen             // <--- IMPORT Gen HERE

// A helper struct for testing enum shrinking
internal struct NoShrink<T>: Shrinker {
    typealias Value = T
    func shrink(_ value: T) -> [T] { [] }
}

// Example Error type for testing ResultShrinker
internal enum TestError: Error, Equatable, CaseIterable {
    case e1, e2, e3
}


final class ShrinkersTests: XCTestCase {

    // MARK: - IntShrinker Tests

    func testIntShrinker_withZero_returnsEmpty() {
        let shrinker = Shrinkers.int
        XCTAssertTrue(shrinker.shrink(0).isEmpty, "Shrinking 0 should produce no values.")
    }

    func testIntShrinker_withPositiveNumber_shrinksTowardsZero() {
        let shrinker = Shrinkers.int
        let value = 10
        let shrunkValues = shrinker.shrink(value)

        XCTAssertFalse(shrunkValues.isEmpty, "Shrinking a non-minimal positive int should produce values.")
        XCTAssertTrue(shrunkValues.contains(0), "Should shrink towards 0.")
        XCTAssertTrue(shrunkValues.contains(value / 2), "Should try halving.")
        XCTAssertTrue(shrunkValues.contains(value - 1), "Should try decrementing magnitude.")
        XCTAssertTrue(shrunkValues.allSatisfy { abs($0) < abs(value) || $0 == 0 }, "All shrunk values should be closer to zero or zero.")
        XCTAssertFalse(shrunkValues.contains(value), "Shrunk values should not contain the original value.")
    }

    func testIntShrinker_withNegativeNumber_shrinksTowardsZero() {
        let shrinker = Shrinkers.int
        let value = -10
        let shrunkValues = shrinker.shrink(value)

        XCTAssertFalse(shrunkValues.isEmpty, "Shrinking a non-minimal negative int should produce values.")
        XCTAssertTrue(shrunkValues.contains(0), "Should shrink towards 0.")
        XCTAssertTrue(shrunkValues.contains(value / 2), "Should try halving.")
        XCTAssertTrue(shrunkValues.contains(value + 1), "Should try incrementing magnitude.")
        XCTAssertTrue(shrunkValues.allSatisfy { abs($0) < abs(value) || $0 == 0 }, "All shrunk values should be closer to zero or zero.")
        XCTAssertFalse(shrunkValues.contains(value), "Shrunk values should not contain the original value.")
    }

    func testIntShrinker_withOne_shrinksToZero() {
        let shrinker = Shrinkers.int
        let shrunkValues = shrinker.shrink(1)
        XCTAssertEqual(shrunkValues, [0], "Shrinking 1 should primarily produce [0].")
    }

    func testIntShrinker_withMinusOne_shrinksToZero() {
        let shrinker = Shrinkers.int
        let shrunkValues = shrinker.shrink(-1)
        XCTAssertEqual(shrunkValues, [0], "Shrinking -1 should primarily produce [0].")
    }

    // MARK: - StringShrinker Tests

    func testStringShrinker_withEmptyString_returnsEmpty() {
        let shrinker = Shrinkers.string
        XCTAssertTrue(shrinker.shrink("").isEmpty, "Shrinking an empty string should produce no values.")
    }

    func testStringShrinker_withNonEmptyString_producesSimplerStrings() {
        let shrinker = Shrinkers.string
        let value = "hello"
        let shrunkValues = shrinker.shrink(value)

        XCTAssertFalse(shrunkValues.isEmpty, "Shrinking a non-empty string should produce values.")
        XCTAssertTrue(shrunkValues.contains(""), "Should shrink towards an empty string.")
        XCTAssertTrue(shrunkValues.contains("hell"), "Should try removing a character.")
        XCTAssertTrue(shrunkValues.contains("he"), "Should try halving (approx).")
        XCTAssertTrue(shrunkValues.allSatisfy { $0.count < value.count || $0.isEmpty }, "All shrunk strings should be shorter or empty.")
        XCTAssertFalse(shrunkValues.contains(value), "Shrunk values should not contain the original value.")
    }

    func testStringShrinker_singleCharacterString_shrinksToEmpty() {
        let shrinker = Shrinkers.string
        let shrunkValues = shrinker.shrink("a")
        XCTAssertTrue(shrunkValues.contains(""), "Shrinking 'a' should produce \"\".")
    }

    // MARK: - Array Shrinker Tests (Testing through a concrete element type)

    func testArrayShrinker_withEmptyArray_returnsEmpty() {
        let elementShrinker = Shrinkers.int
        let arrayShrinker = Shrinkers.array(ofElementShrinker: elementShrinker)
        XCTAssertTrue(arrayShrinker.shrink([]).isEmpty, "Shrinking an empty array should produce no values.")
    }

    func testArrayShrinker_withNonEmptyArray_reducesLengthOrShrinksElements() {
        let elementShrinker = Shrinkers.int
        let arrayShrinker = Shrinkers.array(ofElementShrinker: elementShrinker)
        let value = [10, 20, 5]
        let shrunkValues = arrayShrinker.shrink(value)

        XCTAssertFalse(shrunkValues.isEmpty, "Shrinking a non-empty array should produce values.")
        XCTAssertTrue(shrunkValues.contains([]), "Should be able to shrink to an empty array.")
        XCTAssertTrue(shrunkValues.contains(Array(value.prefix(value.count / 2))), "Should try halving.")
        XCTAssertTrue(shrunkValues.contains(Array(value.dropLast())), "Should try removing last element.")

        let firstElementShrinks = elementShrinker.shrink(value[0])
        var foundShrunkFirstElement = false
        for shrunkFirst in firstElementShrinks {
            if shrunkValues.contains([shrunkFirst, value[1], value[2]]) {
                foundShrunkFirstElement = true
                break
            }
        }
        XCTAssertTrue(foundShrunkFirstElement, "Should try shrinking individual elements (e.g., the first one).")
        XCTAssertFalse(shrunkValues.contains(value), "Shrunk values should not contain the original value.")
    }

    // MARK: - Optional Shrinker Tests

    func testOptionalShrinker_withNil_returnsEmpty() {
        // let wrappedShrinker = Shrinkers.int // <--- REMOVED (unused)
        let optionalShrinker = Optional<Int>.shrinker
        XCTAssertTrue(optionalShrinker.shrink(nil).isEmpty, "Shrinking nil should produce no values.")
    }

    func testOptionalShrinker_withSomeValue_shrinksToNilAndShrinksWrapped() {
        let optionalShrinker = Optional<Int>.shrinker
        let value: Int? = 10
        let shrunkValues = optionalShrinker.shrink(value)

        XCTAssertFalse(shrunkValues.isEmpty, "Shrinking .some(value) should produce values.")
        XCTAssertTrue(shrunkValues.contains(nil), "Should always offer nil as a shrink for .some(value).")

        let wrappedValueShrinks = Shrinkers.int.shrink(value!) // Use Shrinkers.int directly
        var foundShrunkWrapped = false
        for shrunkWrapped in wrappedValueShrinks {
            if shrunkValues.contains(Optional(shrunkWrapped)) {
                foundShrunkWrapped = true
                break
            }
        }
        XCTAssertTrue(foundShrunkWrapped, "Should offer shrunk versions of the wrapped value.")
        XCTAssertFalse(shrunkValues.contains(value), "Shrunk values should not contain the original value.")
    }

    // MARK: - Result Shrinker Tests

    // Using TestErrorShrinker defined below in TestError's Arbitrary conformance
    struct TestErrorShrinker: Shrinker {
        typealias Value = TestError
        func shrink(_ value: TestError) -> [TestError] {
            switch value {
            case .e3: return [.e2, .e1]
            case .e2: return [.e1]
            case .e1: return []
            }
        }
    }

    func testResultShrinker_withSuccess_shrinksSuccessValue() {
        // let successShrinker = Shrinkers.int // <--- REMOVED (unused)
        // let failureShrinker = TestErrorShrinker() // <--- REMOVED (unused)
        let resultShrinker = Result<Int, TestError>.shrinker

        let value: Result<Int, TestError> = .success(10)
        let shrunkValues = resultShrinker.shrink(value)

        XCTAssertFalse(shrunkValues.isEmpty, "Shrinking .success(value) should produce values if value is not minimal.")
        
        let successValueShrinks = Shrinkers.int.shrink(10) // Use Shrinkers.int directly
        var foundShrunkSuccess = false
        for shrunkS in successValueShrinks {
            if shrunkValues.contains(.success(shrunkS)) {
                foundShrunkSuccess = true
                break
            }
        }
        XCTAssertTrue(foundShrunkSuccess, "Should offer shrunk versions of the success value.")
        XCTAssertFalse(shrunkValues.contains { if case .failure = $0 { return true } else { return false } },
                       "Should not shrink .success to .failure.")
        XCTAssertFalse(shrunkValues.contains(value), "Shrunk values should not contain the original value.")
    }

    func testResultShrinker_withFailure_shrinksFailureValue() {
        // let successShrinker = Shrinkers.int // <--- REMOVED (unused)
        // let failureShrinker = TestErrorShrinker() // <--- REMOVED (unused)
        let resultShrinker = Result<Int, TestError>.shrinker

        let value: Result<Int, TestError> = .failure(.e3)
        let shrunkValues = resultShrinker.shrink(value)
        
        XCTAssertFalse(shrunkValues.isEmpty, "Shrinking .failure(error) should produce values if error is not minimal.")

        let failureValueShrinks = TestErrorShrinker().shrink(.e3) // Instantiate directly
        var foundShrunkFailure = false
        for shrunkF in failureValueShrinks {
            if shrunkValues.contains(.failure(shrunkF)) {
                foundShrunkFailure = true
                break
            }
        }
        XCTAssertTrue(foundShrunkFailure, "Should offer shrunk versions of the failure value.")
        XCTAssertFalse(shrunkValues.contains { if case .success = $0 { return true } else { return false } },
                       "Should not shrink .failure to .success.")
        XCTAssertFalse(shrunkValues.contains(value), "Shrunk values should not contain the original value.")
    }

    func testResultShrinker_withMinimalSuccess_returnsEmpty() {
        // let successShrinker = Shrinkers.int // <--- REMOVED (unused)
        let resultShrinker = Result<Int, TestError>.shrinker
        
        let value: Result<Int, TestError> = .success(0)
        XCTAssertTrue(Shrinkers.int.shrink(0).isEmpty, "Precondition: 0 should be minimal for IntShrinker.")
        XCTAssertTrue(resultShrinker.shrink(value).isEmpty, "Shrinking .success(minimalValue) should produce no values.")
    }

    func testResultShrinker_withMinimalFailure_returnsEmpty() {
        // let failureShrinker = TestErrorShrinker() // <--- REMOVED (unused)
        let resultShrinker = Result<Int, TestError>.shrinker

        let value: Result<Int, TestError> = .failure(.e1)
        XCTAssertTrue(TestErrorShrinker().shrink(.e1).isEmpty, "Precondition: .e1 should be minimal for TestErrorShrinker.")
        XCTAssertTrue(resultShrinker.shrink(value).isEmpty, "Shrinking .failure(minimalError) should produce no values.")
    }
}

extension TestError: Arbitrary {
    public typealias Value = TestError
    public static var gen: Gen<TestError> {
        // TestError.allCases is guaranteed non-empty.
        // Gen.element(of:) returns Gen<Element?>. We need Gen<TestError>.
        // We can flatMap to handle the optional, or if confident it won't be nil,
        // use compactMap and then provide a fallback or assert.
        // Given allCases is non-empty, we can be more direct.
        // Let's use `Gen.fromElements(of:)` if available or map and force unwrap (safely here).
        // A common PointFree approach is to ensure you have a non-empty array for Gen.element.
        // Since allCases is [TestError], and it's not empty:
        guard !TestError.allCases.isEmpty else {
            // This case should ideally not happen for a CaseIterable enum with cases.
            // Return a generator that always fails or produces a default if absolutely necessary,
            // but for testing, it's better to make this state unrepresentable.
            // For now, let's make it fatal if allCases is empty, as it's an invalid setup for this gen.
            fatalError("TestError.allCases cannot be empty for Gen.element generation.")
        }
        // If allCases is guaranteed non-empty, Gen.element(of:) should always produce a non-nil value.
        // We can use compactMap to unwrap the optional, and since we know it's never nil
        // in this specific case, it will always succeed.
        return Gen.element(of: TestError.allCases).compactMap { $0 }
    }
    public static var shrinker: any Shrinker<TestError> { ShrinkersTests.TestErrorShrinker() }
}
