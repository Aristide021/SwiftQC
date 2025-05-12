//
//  Result+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen // For Gen and combinators
// Ensure Arbitrary and Shrinker protocols are accessible

// Define a specific shrinker for Result values.
// SuccessValue is the type for the success case, FailureValue is the type for the failure case.
fileprivate struct ResultShrinker<SuccessValue, FailureValue: Error>: Shrinker {
    typealias Value = Result<SuccessValue, FailureValue>

    private let successShrinker: any Shrinker<SuccessValue>
    private let failureShrinker: any Shrinker<FailureValue> // Shrinker for the Error type

    init(successShrinker: any Shrinker<SuccessValue>, failureShrinker: any Shrinker<FailureValue>) {
        self.successShrinker = successShrinker
        self.failureShrinker = failureShrinker
    }

    public func shrink(_ value: Result<SuccessValue, FailureValue>) -> [Result<SuccessValue, FailureValue>] {
        var shrinks: [Result<SuccessValue, FailureValue>] = []

        switch value {
        case .success(let successValue):
            for shrunkSuccess in successShrinker.shrink(successValue) {
                shrinks.append(.success(shrunkSuccess))
            }
        case .failure(let failureValue):
            // failureValue is already of type FailureValue which conforms to Error.
            for shrunkFailure in failureShrinker.shrink(failureValue) {
                shrinks.append(.failure(shrunkFailure))
            }
        }
        return shrinks
    }
}

// The extension must be on Result itself.
// The constraints are:
// 1. `Success` (the generic parameter of Result) must conform to `Arbitrary`.
// 2. `Failure` (the generic parameter of Result) must conform to `Arbitrary`.
// 3. Crucially, `Failure.Value` (the associated type from `Failure: Arbitrary`) must conform to `Error`.
extension Result: Arbitrary where Success: Arbitrary,
                                   Failure: Arbitrary,
                                   Failure.Value: Error { // Ensure the Arbitrary Value for Failure is an Error

    // The `Value` associated type for this Arbitrary conformance is indeed
    // Result<Success.Value, Failure.Value>.
    public typealias Value = Result<Success.Value, Failure.Value>

    public static var gen: Gen<Result<Success.Value, Failure.Value>> {
        // We generate either Success.Value or Failure.Value.
        // Failure.Value is now constrained to be an Error.
        return Gen.bool.flatMap { isSuccess -> Gen<Result<Success.Value, Failure.Value>> in
            if isSuccess {
                return Success.gen.map { .success($0) } // $0 is Success.Value
            } else {
                return Failure.gen.map { .failure($0) } // $0 is Failure.Value (which is an Error)
            }
        }
    }

    public static var shrinker: any Shrinker<Result<Success.Value, Failure.Value>> {
        // Success.shrinker provides `any Shrinker<Success.Value>`
        // Failure.shrinker provides `any Shrinker<Failure.Value>` (where Failure.Value is an Error)
        return ResultShrinker<Success.Value, Failure.Value>(
            successShrinker: Success.shrinker,
            failureShrinker: Failure.shrinker
        )
    }
}