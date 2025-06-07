//
//  Reporter.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Foundation // For basic types
#if canImport(XCTest)
import XCTest    // Import XCTest to use XCTFail
#endif

// Protocol definition remains the same
public protocol Reporter {
    func reportSuccess(description: String, iterations: Int)
    func reportFailure(description: String, input: Any, error: Error, file: StaticString, line: UInt)
    func reportShrinkProgress(from: Any, to: Any) // Likely a no-op for XCTestReporter
    func reportFinalCounterexample(description: String, input: Any, error: Error, file: StaticString, line: UInt)
}

// ConsoleReporter remains the same
public struct ConsoleReporter: Reporter {
    public init() {} // Add a public initializer
    
    public func reportSuccess(description: String, iterations: Int) {
        print("✅ Property '\(description)' succeeded after \(iterations) iterations.")
    }
    
    public func reportFailure(description: String, input: Any, error: Error, file: StaticString, line: UInt) {
        // This initial failure report might be noisy if shrinking occurs.
        // Consider if this specific call is still needed for ConsoleReporter,
        // or if only the final counterexample is the primary console output for failures.
        // For now, keeping it as it might be useful for immediate feedback before shrinking.
        print("⚠️ Property '\(description)' failed with input '\(input)' at \(file):\(line). Error: \(error). Shrinking...")
    }
    
    public func reportShrinkProgress(from: Any, to: Any) {
        // Optional: Print shrinking progress for console
        // print("   Shrinking: \(from) -> \(to)")
    }
    
    public func reportFinalCounterexample(description: String, input: Any, error: Error, file: StaticString, line: UInt) {
         print("🔥 Minimal counterexample for property '\(description)' found with input '\(input)' at \(file):\(line). Error: \(error)")
    }
}

// XCTest integration - MODIFIED
public struct XCTestReporter: Reporter {
    public init() {} // Add a public initializer

    public func reportSuccess(description: String, iterations: Int) {
        // XCTest doesn't typically log successes explicitly like this for each property run iteration.
        // This can remain a no-op.
        // Optional: Could log to console if a verbose XCTest mode was desired, but usually not.
        // print("XCTestReporter: Property '\(description)' succeeded after \(iterations) iterations.")
    }
    
    public func reportFailure(
        description: String,
        input: Any,
        error: Error,
        file: StaticString,
        line: UInt
    ) {
        // This method is called when an initial failure is found, before/during shrinking.
        // In the context of SwiftQC's PropertyRunner using Swift Testing's `withKnownIssue`
        // for suppression during shrinking, the final failure is the most important one
        // to report via XCTFail.
        //
        // If `forAll` directly calls this reporter *before* shrinking and without suppression,
        // then this XCTFail call would be active. However, the `PropertyRunner` currently
        // only prints to console upon initial failure and then the `shrink` function
        // records the *final* issue using `Issue.record`.
        //
        // For now, let's make this a no-op as the `PropertyRunner`'s `shrink` function
        // handles the authoritative `Issue.record` which integrates with Swift Testing.
        // If `forAll` was to *directly* use this reporter for the *very first* failure
        // before shrinking in a way that bypassed `Issue.record`, then this would be:
        // XCTFail("Property '\(description)' initially failed with input '\(input)' at \(file):\(line). Error: \(error)", file: file, line: line)
        //
        // Given the current PropertyRunner structure, the primary XCTest failure point
        // should be `reportFinalCounterexample` or the `Issue.record` in `shrink`.
        // If this reporter is meant to be used *instead of* `Issue.record` for XCTest,
        // the `forAll` and `shrink` logic would need to change to call this.
        //
        // Assuming `Issue.record` in `shrink` is the primary mechanism for Swift Testing,
        // and `XCTestReporter` is for pure XCTest environments *without* Swift Testing's `Issue` system,
        // then this method *would* be important.
        //
        // Let's assume for now that if `XCTestReporter` is used, we want it to report directly.
        // However, the `PropertyRunner` is hardcoded to use `Issue.record`.
        //
        // This highlights a point for future design: how does a selected Reporter interact
        // with the built-in `Issue.record`?
        // For now, if `XCTestReporter` is used, we'd expect `forAll` to call its methods.
        // The current `forAll` calls `print` and then `shrink`, which calls `Issue.record`.
        //
        // Simplification: For an `XCTestReporter` to be effective, `forAll` would need to be
        // adapted to use the reporter instance for all its reporting.
        // Let's modify it to call XCTFail, assuming it would be used in a context where
        // `Issue.record` might not be the (only) desired output.
        
        // This call might be redundant if `reportFinalCounterexample` is also called.
        // Usually, for property-based tests, only the *minimal* counterexample is the failure.
        // print("XCTestReporter: Property '\(description)' failed with input '\(input)'. Error: \(error). File: \(file), Line: \(line). Shrinking...")
    }
    
    public func reportShrinkProgress(from: Any, to: Any) {
        // No direct equivalent for visible reporting in XCTest, can be a no-op.
        // print("XCTestReporter: Shrink progress from \(from) to \(to)")
    }
    
    public func reportFinalCounterexample(
        description: String,
        input: Any,
        error: Error,
        file: StaticString,
        line: UInt
    ) {
        // This is the crucial point for XCTest. Report the minimal failing input.
        let message = """
        Property '\(description)' falsified.
        Minimal counterexample: \(input)
        Error: \(error)
        """
        #if canImport(XCTest)
        XCTFail(message, file: file, line: line)
        #else
        fatalError(message)
        #endif
    }
}

// Example of how `forAll` might need to be adapted to use this reporter:
// (This is conceptual and not part of Reporter.swift)
/*
public func forAll<Input: Arbitrary>(
  _ description: String,
  // ... other params ...
  reporter: Reporter = XCTestReporter(), // Default or injected
  _ property: @escaping (Input.Value) async throws -> Void,
) async -> TestResult<Input.Value> {
    // ...
    // On initial failure:
    //   reporter.reportFailure(description: description, input: currentInput, error: error, file: file, line: line)
    // ...
    // On final shrunk failure:
    //   Instead of Issue.record, or in addition to:
    //   reporter.reportFinalCounterexample(description: description, input: currentBestFailure, error: errorForCurrentBest, file: file, line: line)
    //   return .falsified(...)
    // ...
}*/