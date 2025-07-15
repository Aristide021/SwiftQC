//
//  StatefulTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import XCTest
@testable import SwiftQC // Use @testable to access internal types like stateful runner
import Gen             // For Gen if needed by models

// MARK: - Example StateModel: Counter (Copied and adapted from our discussion)

// --- The System Under Test (SUT) ---
// For testing, we need a way to reset the SUT's state between test runs or sequences.
// A class is suitable for this.
@MainActor
class RealCounterSUT { // REMOVED @unchecked Sendable, rely on @MainActor
    private var count: Int = 0
    // NSLock is not needed if all methods are @MainActor and calls are awaited from main actor context

    func increment() {
        count += 1
        print("[SUT:\(ObjectIdentifier(self))] Incremented. Count: \(count)")
    }

    func getValue() -> Int {
        print("[SUT:\(ObjectIdentifier(self))] GetValue. Returning: \(count)")
        return count
    }

    func reset() {
        count = 0
        print("[SUT:\(ObjectIdentifier(self))] Reset. Count: \(count)")
    }
    init() { print("[SUT:\(ObjectIdentifier(self))] Initialized. Count: \(count)") }
}

@MainActor
class BuggyRealCounterSUT: RealCounterSUT { // Inherits @MainActor
    private var callCount = 0
    
    override func getValue() -> Int {
        let realValue = super.getValue() // Call to super is sync within the same actor
        callCount += 1
        // Make it deterministic: fail every 3rd call when value > 2
        if realValue > 2 && callCount % 3 == 0 {
            print("[BUGGY SUT:\(ObjectIdentifier(self))] getValue returning INCORRECT value (\(realValue + 5)) instead of \(realValue)")
            return realValue + 5
        }
        return realValue
    }
}

// --- CounterModel Conformance ---
struct CounterModel: StateModel {
    typealias State = Int
    typealias ReferenceType = NoReference
    typealias CommandVar = CounterCommand
    typealias ResponseVar = CounterResponse
    typealias CommandConcrete = CounterCommand
    typealias ResponseConcrete = CounterResponse
    typealias SUT = RealCounterSUT

    static let initialState: State = 0

    // Ensure argument labels match the protocol: generateCommand(_ state: State)
    static func generateCommand(_ state: State) -> Gen<CommandVar> {
        return Gen.frequency(
            (7, Gen.always(.increment)),
            (3, Gen.always(.getValue))
        )
    }

    // Ensure labels match: shrinkCommand(_ cmd: CommandVar, inState state: State)
    static func shrinkCommand(_ cmd: CommandVar, inState state: State) -> [CommandVar] {
        return []
    }

    // Ensure labels match: runFake(_ cmd: CommandVar, inState state: State)
    static func runFake(_ cmd: CommandVar, inState state: State) -> Either<PreconditionFailure, (State, ResponseVar)> {
        print("[MODEL] Command: \(cmd), State Before: \(state)")
        switch cmd {
        case .increment:
            let newState = state + 1
            print("[MODEL] State After: \(newState), Response: .ackIncrement")
            return .right((newState, .ackIncrement))
        case .getValue:
            print("[MODEL] State After: \(state) (unchanged), Response: .value(\(state))")
            return .right((state, .value(state)))
        }
    }

    // Implement the new runReal
    static func runReal(_ cmd: CommandConcrete, sut: RealCounterSUT) -> CommandMonad<ResponseConcrete> {
        return {
            print("[SUT RUN:\(ObjectIdentifier(sut))] Command: \(cmd)")
            switch cmd {
            case .increment:
                await sut.increment()
                return .ackIncrement
            case .getValue:
                let val = await sut.getValue()
                return .value(val)
            }
        }
    }

    // Ensure labels match: concretizeCommand(_ symbolicCmd: CommandVar, resolver: ResolverType)
    static func concretizeCommand(_ symbolicCmd: CommandVar, resolver: @Sendable (Var<ReferenceType>) -> ReferenceType) -> CommandConcrete {
        return symbolicCmd
    }

    // Ensure labels match: areResponsesEquivalent(symbolicResponse: ResponseVar, concreteResponse: ResponseConcrete, resolver: ResolverType)
    static func areResponsesEquivalent(symbolicResponse: ResponseVar, concreteResponse: ResponseConcrete, resolver: @Sendable (Var<ReferenceType>) -> ReferenceType) -> Bool {
        let equivalent = symbolicResponse == concreteResponse
        if !equivalent {
            print("Response Mismatch: Model=\(symbolicResponse), SUT=\(concreteResponse)")
        }
        return equivalent
    }
    
    // Ensure monitoring matches protocol
    static func monitoring<PropValue: Sendable>(from: (oldState: State, newState: State), command: CommandConcrete, response: ResponseConcrete, property: Property<PropValue>) -> Property<PropValue> {
        return property
    }
}

// --- BuggyCounterModel Conformance ---
struct BuggyCounterModel: StateModel {
    typealias State = Int
    typealias ReferenceType = NoReference
    typealias CommandVar = CounterCommand
    typealias ResponseVar = CounterResponse
    typealias CommandConcrete = CounterCommand
    typealias ResponseConcrete = CounterResponse
    typealias SUT = BuggyRealCounterSUT

    static let initialState: State = 0

    static func generateCommand(_ state: State) -> Gen<CommandVar> {
        return CounterModel.generateCommand(state)
    }

    // Implement with correct labels matching the protocol
    static func shrinkCommand(_ cmd: CommandVar, inState state: State) -> [CommandVar] {
        return CounterModel.shrinkCommand(cmd, inState: state)
    }

    static func runFake(_ cmd: CommandVar, inState state: State) -> Either<PreconditionFailure, (State, ResponseVar)> {
        return CounterModel.runFake(cmd, inState: state)
    }

    static func concretizeCommand(_ symbolicCmd: CommandVar, resolver: @Sendable (Var<NoReference>) -> NoReference) -> CommandConcrete {
        return CounterModel.concretizeCommand(symbolicCmd, resolver: resolver)
    }

    static func areResponsesEquivalent(symbolicResponse: ResponseVar, concreteResponse: ResponseConcrete, resolver: @Sendable (Var<NoReference>) -> NoReference) -> Bool {
        return CounterModel.areResponsesEquivalent(symbolicResponse: symbolicResponse, concreteResponse: concreteResponse, resolver: resolver)
    }

    static func monitoring<PropValue: Sendable>(from: (oldState: State, newState: State), command: CommandConcrete, response: ResponseConcrete, property: Property<PropValue>) -> Property<PropValue> {
        return CounterModel.monitoring(from: from, command: command, response: response, property: property)
    }

    static func runReal(_ cmd: CommandConcrete, sut: BuggyRealCounterSUT) -> CommandMonad<ResponseConcrete> {
        return {
            print("[BUGGY SUT RUN:\(ObjectIdentifier(sut))] Command: \(cmd)")
            switch cmd {
            case .increment:
                await sut.increment()
                return .ackIncrement
            case .getValue:
                let val = await sut.getValue()
                return .value(val)
            }
        }
    }
}

// MARK: - Stateful Test Cases
@MainActor // Run tests on main actor to simplify SUT access if not fully Sendable
class StatefulTests: XCTestCase {

    // We need to adapt the runner or how runReal is called to handle the SUT.
    // Option 1: Runner manages SUT (more complex for runner).
    // Option 2: StateModel's runReal uses a shared/static SUT (bad for isolation, but simpler for first test).
    // Option 3: The `stateful` function itself takes an SUT factory.

    // For the very first test, let's use a slightly modified `stateful` call
    // or acknowledge that `runReal` in the model might need to access a test-scoped SUT.
    // The provided `stateful` runner doesn't have a direct way to pass SUT context to `Model.runReal`.

    // Let's assume for this first test that `Model.runReal` will be adapted slightly
    // or we use a shared instance for the SUT within the test method scope.
    // We will need to modify the stateful runner to accommodate this.

    // --- Test with a well-behaved counter ---
    func testCounterModel_BehavesCorrectly() async {
        print("\n--- Starting testCounterModel_BehavesCorrectly ---")
        
        let result: TestResult<CommandSequence<CounterModel>> = await SwiftQC.stateful(
            "Counter Model Correct Behavior",
            sutFactory: { await RealCounterSUT() }, // MODIFIED: Added await back
            maxCommandsInSequence: 30,
            numberOfSequences: 10
        )

        switch result {
        case .succeeded(let testsRun):
            XCTAssertGreaterThanOrEqual(testsRun, 0)
            print("Counter Model Correct Behavior: PASSED \(testsRun) sequences.")
        case .falsified(let sequence, let error, _, let seed):
            var failureLog = "Counter stateful test failed. Seed: \(seed ?? 0).\nError: \(error)\nSequence:\n"
            for step in sequence.steps {
                failureLog += "  Cmd: \(step.symbolicCommand), ModelResp: \(String(describing: step.modelResponse)), SUTResp: \(String(describing: step.actualResponse)), ModelAfter: \(step.stateAfter)\n"
            }
            XCTFail(failureLog)
        }
        print("--- Finished testCounterModel_BehavesCorrectly ---\n")
    }

    // --- Test with a deliberately buggy counter SUT ---
    func testBuggyCounterModel_DetectsDivergence() async {
        print("\n--- Starting testBuggyCounterModel_DetectsDivergence ---")
        
        let result: TestResult<CommandSequence<BuggyCounterModel>> = await SwiftQC.stateful(
            "Buggy Counter Model Divergence Test",
            sutFactory: { await BuggyRealCounterSUT() }, // MODIFIED: Added await back
            maxCommandsInSequence: 50,
            numberOfSequences: 20
        )

        switch result {
        case .succeeded(_):
            XCTFail("Buggy counter model test should have failed, but it succeeded.")
        case .falsified(let sequence, let error, _, let seed):
            print("Buggy Counter Model Divergence Test: CORRECTLY FALSIFIED. Seed: \(seed ?? 0)")
            XCTAssertTrue(error is TestFailureError, "Expected a TestFailureError for divergence. Got: \(type(of: error))")
            if let testError = error as? TestFailureError {
                XCTAssertTrue(testError.message.contains("Divergence"), "Error message should indicate divergence.")
            }
            var failureLog = "Buggy Counter Falsified. Seed: \(seed ?? 0).\nError: \(error)\nSequence:\n"
            for step in sequence.steps {
                failureLog += "  Cmd: \(step.symbolicCommand), ModelResp: \(String(describing: step.modelResponse)), SUTResp: \(String(describing: step.actualResponse)), ModelAfter: \(step.stateAfter)\n"
            }
            print(failureLog)
        }
        print("--- Finished testBuggyCounterModel_DetectsDivergence ---\n")
    }
}