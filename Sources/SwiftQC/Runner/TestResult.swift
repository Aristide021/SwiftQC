//
//  TestResult.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Foundation // For Error

/// Represents the result of running a property test.
public enum TestResult<Value> {
    /// The property passed successfully for all tested inputs.
    case succeeded(testsRun: Int)

    /// The property was falsified by a specific input.
    /// - Parameters:
    ///   - value: The minimal counterexample that falsified the property.
    ///   - error: The error that occurred when the property failed on the minimal counterexample.
    ///   - shrinks: The number of shrinking steps performed to find the minimal counterexample.
    ///   - seed: The seed used for the test run (if available), for reproducibility.
    case falsified(value: Value, error: Error, shrinks: Int, seed: UInt64?)
} 