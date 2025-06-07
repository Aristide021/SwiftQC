//
//  PropertyRunner.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

// Conditional imports
#if canImport(Testing)
import Testing
typealias SwiftTestingComment = Testing.Comment
typealias SwiftTestingSourceLocation = Testing.SourceLocation
typealias SwiftTestingIssue = Testing.Issue
#endif

import Gen

public struct TestFailureError: Error, CustomStringConvertible, Sendable {
    public let message: String
    public var description: String { message }
    public init(message: String) { self.message = message }
}

// Helper function to handle shrink failure suppression
private func suppressShrinkFailures<T>(
    _ operation: () async throws -> T
) async -> (result: Result<T, Error>, hasSuppressedFailures: Bool) {
    #if canImport(Testing)
    // Use Swift Testing's suppression mechanism
    var capturedResult: Result<T, Error>!
    
    await withKnownIssue(isIntermittent: true) {
        do {
            let value = try await operation()
            capturedResult = .success(value)
        } catch {
            capturedResult = .failure(error)
        }
    }
    
    let hasSuppressedFailures = capturedResult != nil && capturedResult.isFailure
    return (capturedResult, hasSuppressedFailures)
    #else
    // CLI mode: silently capture failures without reporting
    do {
        let value = try await operation()
        return (.success(value), false)
    } catch {
        return (.failure(error), true)
    }
    #endif
}

// Extension for Result convenience
private extension Result {
    var isFailure: Bool {
        switch self {
        case .success: return false
        case .failure: return true
        }
    }
}

/// Runs a property-based test for a single `Arbitrary` input type.
///
/// SwiftQC's `forAll` function automatically:
/// 1. Generates random inputs of the specified `Input` type using its `Arbitrary` conformance.
/// 2. Runs the provided `property` closure with each input.
/// 3. If the property fails (throws an error), it attempts to shrink the failing input
///    to a minimal counterexample using the `Input` type's `shrinker`.
/// 4. Reports success or the minimal failure (integrating with Swift Testing when available).
///
/// - Parameters:
///   - description: A textual description of the property being tested.
///   - count: The number of successful test iterations to run. Defaults to 100.
///   - seed: An optional fixed seed for the random number generator. If `nil`, a random seed is used.
///           Providing a seed ensures reproducibility of test runs, especially failures.
///   - reporter: A `Reporter` instance to handle logging of test progress and results.
///               Defaults to `ConsoleReporter`.
///   - file: The file where the test is defined (automatically captured).
///   - line: The line where the test is defined (automatically captured).
///   - property: An async closure that takes a value of `Input.Value` and throws an error if the property fails.
///               The `Input.Value` must conform to `Sendable`.
///   - arbitraryType: The `Arbitrary` conforming type to use for generating inputs. Defaults to `Input.self`.
/// - Returns: A `TestResult` indicating whether the test succeeded or failed, including details
///            like the minimal counterexample and seed if falsified.
public func forAll<Input: Arbitrary>( // Arbitrary.Value is Sendable via protocol constraint
  _ description: String,
  count: Int = 100,
  seed: UInt64? = nil,
  reporter: Reporter = ConsoleReporter(),
  file: StaticString = #file,
  line: UInt = #line,
  _ property: @escaping (Input.Value) async throws -> Void,
  _ arbitraryType: Input.Type = Input.self
) async -> TestResult<Input.Value> {
    let effectiveSeed: UInt64
    if let providedSeed = seed {
        effectiveSeed = providedSeed
    } else {
        var localSystemRng = SystemRandomNumberGenerator()
        effectiveSeed = localSystemRng.next()
    }
    var xoshiroRng = Xoshiro(seed: effectiveSeed)

    for testIndex in 0..<count {
        let currentInput: Input.Value = Input.gen.run(using: &xoshiroRng)
        do {
            try await property(currentInput)
        } catch let error {
            reporter.reportFailure(description: description, input: currentInput, error: error, file: file, line: line)
            print("Property '\(description)' failed on attempt \(testIndex + 1) with input: \(currentInput) (Seed: \(effectiveSeed))")
            print("Error: \(error)")
            print("Starting shrinking...")

            let shrinkResult = await shrink(
                initialValue: currentInput,
                initialError: error,
                shrinker: Input.shrinker,
                property: property,
                description: description,
                seedForRun: effectiveSeed,
                reporter: reporter,
                file: file,
                line: line
            )
            return shrinkResult
        }
    }
    reporter.reportSuccess(description: description, iterations: count)
    return .succeeded(testsRun: count)
}

private func shrink<ValueParameter: Sendable, ShrinkerType: Shrinker>(
    initialValue: ValueParameter,
    initialError: Error,
    shrinker: ShrinkerType,
    property: @escaping (ValueParameter) async throws -> Void,
    description: String,
    seedForRun: UInt64,
    reporter: Reporter,
    file: StaticString,
    line: UInt
) async -> TestResult<ValueParameter> where ShrinkerType.Value == ValueParameter {
    var currentBestFailure = initialValue
    var errorForCurrentBest: Error = initialError
    var shrinksDone = 0

    print("Shrinking '\(description)': initial failing value \(currentBestFailure) with error: \(errorForCurrentBest.localizedDescription)")
    var madeProgressInOuterLoop = true
    while madeProgressInOuterLoop {
        madeProgressInOuterLoop = false
        let candidates = shrinker.shrink(currentBestFailure)
        if candidates.isEmpty { break }
        for candidate in candidates {
            reporter.reportShrinkProgress(from: currentBestFailure, to: candidate)
            
            // Use our helper function to suppress intermediate failures
            let (result, _) = await suppressShrinkFailures {
                try await property(candidate)
            }
            
            if case .failure(let error) = result {
                errorForCurrentBest = error
                print("  Shrinking '\(description)': found smaller failing candidate \(candidate) with error: \(errorForCurrentBest.localizedDescription)")
                currentBestFailure = candidate
                shrinksDone += 1
                madeProgressInOuterLoop = true
                break
            }
        }
    }
    
    print("Shrinking '\(description)': finished. Minimal failing input: \(currentBestFailure)")
    let finalErrorOnMinimalCandidate: Error
    var minimalCandidateUnexpectedlyPassed = false
    
     do {
        try await property(currentBestFailure)
        finalErrorOnMinimalCandidate = errorForCurrentBest
        minimalCandidateUnexpectedlyPassed = true
     } catch let finalError {
         finalErrorOnMinimalCandidate = finalError
     }
    
    reporter.reportFinalCounterexample(description: description, input: currentBestFailure, error: finalErrorOnMinimalCandidate, file: file, line: line)
    
    // Record the final issue conditionally
    #if canImport(Testing)
    if minimalCandidateUnexpectedlyPassed {
        SwiftTestingIssue.record(errorForCurrentBest, SwiftTestingComment(rawValue: "Minimal candidate unexpectedly passed. Input: \(currentBestFailure). Seed: \(seedForRun)"), sourceLocation: SwiftTestingSourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 0))
    } else {
        var notes = [String]()
        if errorForCurrentBest.localizedDescription != finalErrorOnMinimalCandidate.localizedDescription && shrinksDone > 0 {
            notes.append("Note: Error on initial shrink differed: \(errorForCurrentBest.localizedDescription)")
        }
        let failureComment = "Minimal counterexample: \(currentBestFailure). Seed: \(seedForRun)." + (notes.isEmpty ? "" : "\n" + notes.joined(separator: "\n"))
        SwiftTestingIssue.record(finalErrorOnMinimalCandidate, SwiftTestingComment(rawValue: failureComment), sourceLocation: SwiftTestingSourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 0))
    }
    #else
    // In CLI mode, we just return the result - the error is already printed via reporter
    #endif
    
    return .falsified(value: currentBestFailure, error: finalErrorOnMinimalCandidate, shrinks: shrinksDone, seed: seedForRun)
}

/// Runs a property-based test for two `Arbitrary` input types.
///
/// This overload provides an ergonomic way to test properties involving two inputs.
/// It internally uses the base `forAll` with a `Tuple2<A, B>` arbitrary type.
///
/// - Parameters:
///   - description: A textual description of the property being tested.
///   - count: The number of successful test iterations to run. Defaults to 100.
///   - seed: An optional fixed seed for the random number generator for reproducibility.
///   - reporter: A `Reporter` instance. Defaults to `ConsoleReporter`.
///   - file: The file where the test is defined (automatically captured).
///   - line: The line where the test is defined (automatically captured).
///   - typeA: The first `Arbitrary` type. Defaults to `A.self`.
///   - typeB: The second `Arbitrary` type. Defaults to `B.self`.
///   - property: An async closure that takes values of `A.Value` and `B.Value` and throws an error if the property fails.
/// - Returns: A `TestResult` indicating success or failure for the tuple `(A.Value, B.Value)`.
public func forAll<A: Arbitrary, B: Arbitrary>(
    _ description: String,
    count: Int = 100,
    seed: UInt64? = nil,
    reporter: Reporter = ConsoleReporter(),
    file: StaticString = #file,
    line: UInt = #line,
    _ typeA: A.Type = A.self,
    _ typeB: B.Type = B.self,
    _ property: @escaping (A.Value, B.Value) async throws -> Void
) async -> TestResult<(A.Value, B.Value)> {
    let result: TestResult<Tuple2<A, B>.Value> = await forAll(
        description, count: count, seed: seed, reporter: reporter, file: file, line: line,
        { (generatedTuple: Tuple2<A, B>.Value) async throws in
            try await property(generatedTuple.0, generatedTuple.1)
        },
        Tuple2<A, B>.self
    )
    return result
}

/// Runs a property-based test for three `Arbitrary` input types.
///
/// This overload provides an ergonomic way to test properties involving three inputs.
/// It internally uses the base `forAll` with a `Tuple3<A, B, C>` arbitrary type.
///
/// - Parameters: (Similar to the 2-parameter version, extending to C)
///   - description: Property description.
///   - count: Iteration count.
///   - seed: Optional seed.
///   - reporter: Reporter instance.
///   - file: Source file.
///   - line: Source line.
///   - typeA: The first `Arbitrary` type.
///   - typeB: The second `Arbitrary` type.
///   - typeC: The third `Arbitrary` type.
///   - property: An async closure taking `(A.Value, B.Value, C.Value)`.
/// - Returns: A `TestResult` for the tuple `(A.Value, B.Value, C.Value)`.
public func forAll<A: Arbitrary, B: Arbitrary, C: Arbitrary>(
    _ description: String,
    count: Int = 100,
    seed: UInt64? = nil,
    reporter: Reporter = ConsoleReporter(),
    file: StaticString = #file,
    line: UInt = #line,
    _ typeA: A.Type = A.self,
    _ typeB: B.Type = B.self,
    _ typeC: C.Type = C.self,
    _ property: @escaping (A.Value, B.Value, C.Value) async throws -> Void
) async -> TestResult<(A.Value, B.Value, C.Value)> {
    let result: TestResult<Tuple3<A, B, C>.Value> = await forAll(
        description, count: count, seed: seed, reporter: reporter, file: file, line: line,
        { (generatedTuple: Tuple3<A, B, C>.Value) async throws in
            try await property(generatedTuple.0, generatedTuple.1, generatedTuple.2)
        },
        Tuple3<A, B, C>.self
    )
    return result
}

/// Runs a property-based test for four `Arbitrary` input types.
///
/// This overload provides an ergonomic way to test properties involving four inputs.
/// It internally uses the base `forAll` with a `Tuple4<A, B, C, D>` arbitrary type.
///
/// - Parameters: (Similar to the 3-parameter version, extending to D)
///   - description: Property description.
///   - count: Iteration count.
///   - seed: Optional seed.
///   - reporter: Reporter instance.
///   - file: Source file.
///   - line: Source line.
///   - typeA: The first `Arbitrary` type.
///   - typeB: The second `Arbitrary` type.
///   - typeC: The third `Arbitrary` type.
///   - typeD: The fourth `Arbitrary` type.
///   - property: An async closure taking `(A.Value, B.Value, C.Value, D.Value)`.
/// - Returns: A `TestResult` for the tuple `(A.Value, B.Value, C.Value, D.Value)`.
public func forAll<A: Arbitrary, B: Arbitrary, C: Arbitrary, D: Arbitrary>(
    _ description: String,
    count: Int = 100,
    seed: UInt64? = nil,
    reporter: Reporter = ConsoleReporter(),
    file: StaticString = #file,
    line: UInt = #line,
    _ typeA: A.Type = A.self, _ typeB: B.Type = B.self, _ typeC: C.Type = C.self, _ typeD: D.Type = D.self,
    _ property: @escaping (A.Value, B.Value, C.Value, D.Value) async throws -> Void
) async -> TestResult<(A.Value, B.Value, C.Value, D.Value)> {
    let result: TestResult<Tuple4<A, B, C, D>.Value> = await forAll(
        description, count: count, seed: seed, reporter: reporter, file: file, line: line,
        { (tuple: Tuple4<A, B, C, D>.Value) throws in try await property(tuple.0, tuple.1, tuple.2, tuple.3) },
        Tuple4<A, B, C, D>.self
    )
    return result
}

/// Runs a property-based test for five `Arbitrary` input types.
///
/// This overload provides an ergonomic way to test properties involving five inputs.
/// It internally uses the base `forAll` with a `Tuple5<A, B, C, D, E>` arbitrary type.
///
/// - Parameters: (Similar to the 4-parameter version, extending to E)
///   - description: Property description.
///   - count: Iteration count.
///   - seed: Optional seed.
///   - reporter: Reporter instance.
///   - file: Source file.
///   - line: Source line.
///   - typeA: The first `Arbitrary` type.
///   - typeB: The second `Arbitrary` type.
///   - typeC: The third `Arbitrary` type.
///   - typeD: The fourth `Arbitrary` type.
///   - typeE: The fifth `Arbitrary` type.
///   - property: An async closure taking `(A.Value, B.Value, C.Value, D.Value, E.Value)`.
/// - Returns: A `TestResult` for the tuple `(A.Value, B.Value, C.Value, D.Value, E.Value)`.
public func forAll<A: Arbitrary, B: Arbitrary, C: Arbitrary, D: Arbitrary, E: Arbitrary>(
    _ description: String,
    count: Int = 100,
    seed: UInt64? = nil,
    reporter: Reporter = ConsoleReporter(),
    file: StaticString = #file,
    line: UInt = #line,
    _ typeA: A.Type = A.self, _ typeB: B.Type = B.self, _ typeC: C.Type = C.self, _ typeD: D.Type = D.self, _ typeE: E.Type = E.self,
    _ property: @escaping (A.Value, B.Value, C.Value, D.Value, E.Value) async throws -> Void
) async -> TestResult<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
    let result: TestResult<Tuple5<A, B, C, D, E>.Value> = await forAll(
        description, count: count, seed: seed, reporter: reporter, file: file, line: line,
        { (tuple: Tuple5<A, B, C, D, E>.Value) throws in try await property(tuple.0, tuple.1, tuple.2, tuple.3, tuple.4) },
        Tuple5<A, B, C, D, E>.self
    )
    return result
}

// MARK: - Specialized Dictionary Overload

/// Runs a property-based test for `Dictionary` inputs where keys and values conform to `Arbitrary`.
///
/// This overload provides an ergonomic way to test properties involving dictionaries.
/// It requires the `Key` type's associated `Value` (`K_DictArbitrary.Value`) to be `Hashable`.
/// It internally uses the base `forAll` with an `ArbitraryDictionary<K_DictArbitrary, V_DictArbitrary>` wrapper type.
///
/// - Parameters:
///   - description: A textual description of the property being tested.
///   - count: The number of successful test iterations to run. Defaults to 100.
///   - seed: An optional fixed seed for the random number generator for reproducibility.
///   - reporter: A `Reporter` instance. Defaults to `ConsoleReporter`.
///   - file: The file where the test is defined (automatically captured).
///   - line: The line where the test is defined (automatically captured).
///   - keyType: The `Arbitrary` type for the dictionary keys. Defaults to `K_DictArbitrary.self`.
///   - valueType: The `Arbitrary` type for the dictionary values. Defaults to `V_DictArbitrary.self`.
///   - forDictionary: A dummy parameter to help the compiler distinguish this overload. Defaults to `true`.
///                    You should typically ignore this parameter.
///   - property: An async closure that takes a `Dictionary<K_DictArbitrary.Value, V_DictArbitrary.Value>`
///               and throws an error if the property fails.
/// - Returns: A `TestResult` indicating success or failure for the `Dictionary`.
/// - Note: Requires `K_DictArbitrary.Value: Hashable`.
public func forAll<K_DictArbitrary: Arbitrary, V_DictArbitrary: Arbitrary>(
    _ description: String,
    count: Int = 100,
    seed: UInt64? = nil,
    reporter: Reporter = ConsoleReporter(),
    file: StaticString = #file,
    line: UInt = #line,
    _ keyType: K_DictArbitrary.Type = K_DictArbitrary.self,
    _ valueType: V_DictArbitrary.Type = V_DictArbitrary.self,
    forDictionary: Bool = true, // Dummy parameter for disambiguation
    _ property: @escaping (Dictionary<K_DictArbitrary.Value, V_DictArbitrary.Value>) async throws -> Void
) async -> TestResult<Dictionary<K_DictArbitrary.Value, V_DictArbitrary.Value>> // Expected return type
    where K_DictArbitrary.Value: Hashable
{
    assert(forDictionary, "This overload is for dictionaries.")

    let dictionaryArbitraryProvider = ArbitraryDictionary<K_DictArbitrary, V_DictArbitrary>.self

    return await forAll(
        description,
        count: count,
        seed: seed,
        reporter: reporter,
        file: file,
        line: line,
        property,
        dictionaryArbitraryProvider
    )
}
