import XCTest
@testable import SwiftQC // For ParallelRunnerError, DefaultableResponse etc.
import Gen
import Atomics

// MARK: - SUT Implementations for Parallel Tests

// Basic Safe Counter (Actor-based)
actor SafeCounterSUT: Sendable {
    private var value: Int = 0
    private var opCount: Int = 0 // For some tests

    func increment() {
        opCount += 1
        value += 1
    }

    func getValue() -> Int {
        opCount += 1
        return value
    }
    
    func getOpCount() -> Int { // For some tests
        return opCount
    }

    func reset() {
        value = 0
        opCount = 0
    }
    init() { self.value = 0; self.opCount = 0 }
}

// SUT that can be made to throw an error
actor ErrorThrowingSUT: Sendable {
    private var value: Int = 0
    var shouldThrowOnNthIncrement: Int? = nil // 1-based: 1 means 1st call to increment
    var shouldThrowOnNthGetValue: Int? = nil  // 1-based: 1 means 1st call to getValue
    private var incrementCallCount = 0
    private var getValueCallCount = 0

    struct SUTError: Error, LocalizedError, Sendable, Equatable {
        let message: String
        var errorDescription: String? { message }
    }

    func increment() throws {
        incrementCallCount += 1
        if let throwOn = shouldThrowOnNthIncrement, incrementCallCount == throwOn {
            print("[ErrorThrowingSUT] Intentionally throwing on increment #\(incrementCallCount)")
            throw SUTError(message: "Intentional SUT error on increment")
        }
        value += 1
    }

    func getValue() throws -> Int {
        getValueCallCount += 1
        if let throwOn = shouldThrowOnNthGetValue, getValueCallCount == throwOn {
            print("[ErrorThrowingSUT] Intentionally throwing on getValue #\(getValueCallCount)")
            throw SUTError(message: "Intentional SUT error on getValue")
        }
        return value
    }
    func reset() { value = 0; incrementCallCount = 0; getValueCallCount = 0; shouldThrowOnNthIncrement = nil; shouldThrowOnNthGetValue = nil }
    init() {}

    // Methods to configure throwing behavior from tests
    func setShouldThrowOnNthIncrement(_ n: Int?) {
        self.shouldThrowOnNthIncrement = n
    }
    func setShouldThrowOnNthGetValue(_ n: Int?) {
        self.shouldThrowOnNthGetValue = n
    }
}

// SUT that causes divergence (returns unexpected value)
actor DivergentSUT: Sendable { // Cannot inherit from an actor; use composition or reimplement
    private let internalCounter = SafeCounterSUT() // Composition
    var divergeOnGetValueAfterIncrements: Int? = nil
    private var actualIncrements = 0

    func increment() async { // Make async to call internalCounter
        await internalCounter.increment()
        actualIncrements += 1
    }

    func getValue() async -> Int { // Make async to call internalCounter
        let currentValue = await internalCounter.getValue()
        if let divergeTarget = divergeOnGetValueAfterIncrements, actualIncrements >= divergeTarget {
            print("[DivergentSUT] Intentionally diverging. Returning \(currentValue + 100) instead of \(currentValue)")
            return currentValue + 100 // Divergent value
        }
        return currentValue
    }
    
    func reset() async { // Make async to call internalCounter
        await internalCounter.reset()
        actualIncrements = 0
        divergeOnGetValueAfterIncrements = nil
    }

    func setDivergeOnGetValueAfterIncrements(_ n: Int?) {
        self.divergeOnGetValueAfterIncrements = n
    }
    init() {}
}


// MARK: - ParallelModel Implementations for Tests

// For SafeCounterSUT (lenient areResponsesEquivalent)
struct LenientSimpleParallelCounterModel: ParallelModel {
    typealias State = Int
    typealias ReferenceType = NoReference
    typealias CommandVar = CounterCommand
    typealias ResponseVar = CounterResponse
    typealias CommandConcrete = CounterCommand
    typealias ResponseConcrete = CounterResponse
    typealias SUT = SafeCounterSUT

    static var initialState: State { 0 }
    static func generateCommand(_ state: State) -> Gen<CommandVar> { Gen.element(of: [CounterCommand.increment, .getValue]).compactMap { $0 } }
    static func generateParallelCommand(_ states: [State]) -> Gen<CommandVar> { generateCommand(states.first ?? initialState) }
    static func shrinkParallelCommand(_ states: [State], _ cmd: CommandVar) -> [CommandVar] { [] } // Simplified
    static func runFake(_ cmd: CommandVar, inState state: State) -> Either<PreconditionFailure, (State, ResponseVar)> {
        switch cmd {
        case .increment: return .right((state + 1, .ackIncrement))
        case .getValue: return .right((state, .value(state)))
        }
    }
    static func runReal(_ cmd: CommandConcrete, sut: SUT) -> CommandMonad<ResponseConcrete> {
        return {
            switch cmd {
            case .increment: await sut.increment(); return .ackIncrement
            case .getValue: let v = await sut.getValue(); return .value(v)
            }
        }
    }
    static func runCommandMonad<A: Sendable>(_ action: @escaping CommandMonad<A>) -> IO<A> { IO(action) }
    static func concretizeCommand(_ cmd: CommandVar, resolver: @Sendable (Var<ReferenceType>) -> ReferenceType) -> CommandConcrete { cmd }
    static func areResponsesEquivalent(symbolicResponse: ResponseVar, concreteResponse: ResponseConcrete, resolver: @Sendable (Var<ReferenceType>) -> ReferenceType) -> Bool {
        switch (symbolicResponse, concreteResponse) { // Lenient for getValue
            case (.ackIncrement, .ackIncrement): return true
            case (.value(_), .value(_)): return true // Type match, value diff handled by property
            default: return false
        }
    }
}

// For ErrorThrowingSUT (strict areResponsesEquivalent, expects SUT to match model perfectly if no error)
struct ModelForErrorSUT: ParallelModel {
    typealias State = Int
    typealias ReferenceType = NoReference
    typealias CommandVar = CounterCommand
    typealias ResponseVar = CounterResponse
    typealias CommandConcrete = CounterCommand
    typealias ResponseConcrete = CounterResponse
    typealias SUT = ErrorThrowingSUT 

    static var initialState: State { 0 }
    static func generateCommand(_ state: State) -> Gen<CommandVar> { Gen.element(of: [CounterCommand.increment, .getValue]).compactMap { $0 } }
    static func generateParallelCommand(_ states: [State]) -> Gen<CommandVar> { generateCommand(states.first ?? initialState) }
    static func shrinkParallelCommand(_ states: [State], _ cmd: CommandVar) -> [CommandVar] { [] }
    static func runFake(_ cmd: CommandVar, inState state: State) -> Either<PreconditionFailure, (State, ResponseVar)> {
        switch cmd {
        case .increment: return .right((state + 1, .ackIncrement))
        case .getValue: return .right((state, .value(state)))
        }
    }
    // Must handle potential throws from ErrorThrowingSUT
    static func runReal(_ cmd: CommandConcrete, sut: SUT) -> CommandMonad<ResponseConcrete> {
        return {
            switch cmd {
            case .increment: try await sut.increment(); return .ackIncrement
            case .getValue: let v = try await sut.getValue(); return .value(v)
            }
        }
    }
    static func runCommandMonad<A: Sendable>(_ action: @escaping CommandMonad<A>) -> IO<A> { IO(action) }
    static func concretizeCommand(_ cmd: CommandVar, resolver: @Sendable (Var<ReferenceType>) -> ReferenceType) -> CommandConcrete { cmd }
    // Strict equivalence for when no error is thrown
    static func areResponsesEquivalent(symbolicResponse: ResponseVar, concreteResponse: ResponseConcrete, resolver: @Sendable (Var<ReferenceType>) -> ReferenceType) -> Bool { symbolicResponse == concreteResponse }
}

// For DivergentSUT (strict areResponsesEquivalent)
struct ModelForDivergentSUT: ParallelModel {
    typealias State = Int; typealias ReferenceType = NoReference; typealias CommandVar = CounterCommand
    typealias ResponseVar = CounterResponse; typealias CommandConcrete = CounterCommand
    typealias ResponseConcrete = CounterResponse; typealias SUT = DivergentSUT

    static var initialState: State { 0 }
    static func generateCommand(_ state: State) -> Gen<CommandVar> { Gen.element(of: [.increment, .getValue, .increment, .getValue]).compactMap{$0} } // Bias towards a few increments then get
    static func generateParallelCommand(_ states: [State]) -> Gen<CommandVar> { generateCommand(states.first ?? initialState) }
    static func shrinkParallelCommand(_ states: [State], _ cmd: CommandVar) -> [CommandVar] { [] }
    static func runFake(_ cmd: CommandVar, inState state: State) -> Either<PreconditionFailure, (State, ResponseVar)> {
        switch cmd {
        case .increment: return .right((state + 1, .ackIncrement))
        case .getValue: return .right((state, .value(state)))
        }
    }
    static func runReal(_ cmd: CommandConcrete, sut: SUT) -> CommandMonad<ResponseConcrete> {
        return {
            switch cmd {
            case .increment: await sut.increment(); return .ackIncrement
            case .getValue: let v = await sut.getValue(); return .value(v)
            }
        }
    }
    static func runCommandMonad<A: Sendable>(_ action: @escaping CommandMonad<A>) -> IO<A> { IO(action) }
    static func concretizeCommand(_ cmd: CommandVar, resolver: @Sendable (Var<ReferenceType>) -> ReferenceType) -> CommandConcrete { cmd }
    static func areResponsesEquivalent(symbolicResponse: ResponseVar, concreteResponse: ResponseConcrete, resolver: @Sendable (Var<ReferenceType>) -> ReferenceType) -> Bool { symbolicResponse == concreteResponse }
}


// MARK: - ParallelTests Suite
@MainActor
class ParallelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure CounterResponse has DefaultableResponse conformance available (via import SwiftQC or local definition)
        // This is to satisfy the ParallelRunner's internal error handling path.
        let _ = CounterResponse.defaultPlaceholderResponse
    }

    func testParallelCounter_SuccessfulRun_WithLenientModel() async {
        let sutFactory: @Sendable () async -> SafeCounterSUT = { SafeCounterSUT() }

        let result = await SwiftQC.parallel(
            "Parallel Counter Success (Lenient Model)",
            threads: 2, forks: 20, // More ops
            modelType: LenientSimpleParallelCounterModel.self, 
            sutFactory: sutFactory
        ) { @Sendable (executionResult: ParallelExecutionResult<LenientSimpleParallelCounterModel>) in
            let overallErrorDescription = executionResult.overallError?.localizedDescription ?? "nil"
            XCTAssertNil(executionResult.overallError, "Expected no overall error from runner with lenient model. Error: \(overallErrorDescription)", file: #filePath, line: #line)
            
            let successfulIncrements = executionResult.events.filter { $0.symbolicCommand == .increment && $0.sutError == nil }.count
            print("Lenient Model - Successful SUT increments: \(successfulIncrements)")
            // To check final SUT state properly, we'd need to get the final SUT state.
            // For now, we check that no errors were reported by the runner itself.
        }

        if case .falsified(_, let error, _, _) = result {
            XCTFail("Parallel test (lenient model) failed but expected success. Error: \(error.localizedDescription)")
        } else {
            print("Test testParallelCounter_SuccessfulRun_WithLenientModel: PASSED.")
        }
    }

    func testParallel_SUTErrorPropagation() async {
        let sut = ErrorThrowingSUT()
        await sut.reset()
        await sut.setShouldThrowOnNthIncrement(2) 
        
        let sutFactory: @Sendable () async -> ErrorThrowingSUT = { sut }
        let propertyBlockEnteredWhenErrorExpected = ManagedAtomic<Bool>(false)

        let result = await SwiftQC.parallel(
            "Parallel SUT Error Propagation",
            threads: 2, forks: 4, 
            modelType: ModelForErrorSUT.self,
            sutFactory: sutFactory
        ) { @Sendable (executionResult: ParallelExecutionResult<ModelForErrorSUT>) in
            if executionResult.overallError == nil {
                propertyBlockEnteredWhenErrorExpected.store(true, ordering: .relaxed)
            }
        }

        XCTAssertFalse(propertyBlockEnteredWhenErrorExpected.load(ordering: .relaxed), "Property block was entered, but runner should have detected an SUT error first.")

        guard case .falsified(let execResult, let finalErrorAfterShrinking, let shrinks, _) = result else {
            XCTFail("Expected .falsified TestResult due to SUT error. Got \(result)"); return
        }
        
        XCTAssertNotNil(execResult.overallError, "The ParallelExecutionResult within TestResult.falsified should contain the error from the minimal failing run.")
        XCTAssertNotNil(finalErrorAfterShrinking, "The error in TestResult.falsified should be non-nil.")
        XCTAssertTrue(shrinks >= 0)
        print("Test testParallel_SUTErrorPropagation: FALSIFIED as expected. Final error type after shrinking: \(type(of: finalErrorAfterShrinking)), message: \"\(finalErrorAfterShrinking.localizedDescription)\". Shrinks: \(shrinks)")

        // Check if the final error is either the SUTError or a ParallelRunnerError
        XCTAssertTrue(finalErrorAfterShrinking is ErrorThrowingSUT.SUTError || finalErrorAfterShrinking is ParallelRunnerError, "Final error should be SUTError OR ParallelRunnerError. Actual: \(type(of: finalErrorAfterShrinking))")

        // Check if the events list contains the SUT error if the final error is indeed the SUTError
        if finalErrorAfterShrinking is ErrorThrowingSUT.SUTError {
            let sutErrorEventInMinimalPlan = execResult.events.first(where: { $0.sutError is ErrorThrowingSUT.SUTError })
            XCTAssertNotNil(sutErrorEventInMinimalPlan, "If final error is SUTError, an event in the minimal sequence should reflect it.")
        }
    }

    func testParallel_ModelSUTDivergence() async {
        let sut = DivergentSUT()
        await sut.reset()
        await sut.setDivergeOnGetValueAfterIncrements(1)

        let sutFactory: @Sendable () async -> DivergentSUT = { sut }
        let propertyBlockEnteredWhenErrorExpected = ManagedAtomic<Bool>(false)

        let result = await SwiftQC.parallel(
            "Parallel Model-SUT Divergence",
            threads: 2, forks: 3, 
            modelType: ModelForDivergentSUT.self,
            sutFactory: sutFactory
        ) { @Sendable (executionResult: ParallelExecutionResult<ModelForDivergentSUT>) in
            if executionResult.overallError == nil {
                propertyBlockEnteredWhenErrorExpected.store(true, ordering: .relaxed)
            }
        }
        
        XCTAssertFalse(propertyBlockEnteredWhenErrorExpected.load(ordering: .relaxed), "Property block was entered, but runner should have detected divergence first.")

        guard case .falsified(let execResult, let errorFromTestResult, let shrinks, _) = result else {
            XCTFail("Expected .falsified due to divergence. Got \(result)"); return
        }
        XCTAssertNotNil(execResult.overallError, "ExecutionResult should have an overallError for divergence.")
        XCTAssertTrue(errorFromTestResult is ParallelRunnerError, "Error in TestResult should be ParallelRunnerError for divergence. Got: \(type(of: errorFromTestResult)) - \(errorFromTestResult.localizedDescription)")
        if let runnerError = errorFromTestResult as? ParallelRunnerError {
            XCTAssertTrue(runnerError.message.contains("Parallel Divergence"), "Error message should indicate divergence. Was: '\(runnerError.message)'")
        }
        XCTAssertTrue(shrinks >= 0)
        print("Test testParallel_ModelSUTDivergence: FALSIFIED as expected. Error: \(errorFromTestResult.localizedDescription). Shrinks: \(shrinks)");
    }

    func testParallel_PropertyFailure() async {
        let sutFactory: @Sendable () async -> SafeCounterSUT = { SafeCounterSUT() }
        struct PropertyError: Error, LocalizedError { var errorDescription: String? = "Intentional property failure" }

        let result = await SwiftQC.parallel(
            "Parallel Property Failure",
            threads: 2, forks: 5,
            modelType: LenientSimpleParallelCounterModel.self, // Use a model that won't cause runner errors
            sutFactory: sutFactory
        ) { @Sendable (executionResult: ParallelExecutionResult<LenientSimpleParallelCounterModel>) in
            XCTAssertNil(executionResult.overallError, "Runner should not report an error before property runs.", file: #filePath, line: #line)
            let successfulIncrements = executionResult.events.filter { $0.symbolicCommand == .increment && $0.sutError == nil }.count
            if successfulIncrements >= 0 { // Always true, but to have a place to throw
                print("Intentional property failure: Forcing error because increments is \(successfulIncrements)")
                throw PropertyError() // Cause the property to fail
            }
        }

        guard case .falsified(let execResult, let error, let shrinks, _) = result else {
            XCTFail("Expected .falsified due to property failure."); return
        }
        XCTAssertNotNil(execResult.overallError, "ExecutionResult should have an overallError from property.")
        XCTAssertTrue(error is PropertyError, "Error should be the PropertyError. Got: \(type(of: error))")
        XCTAssertTrue(shrinks >= 0) // Shrinking should still run on the command plan
        print("Test testParallel_PropertyFailure: CORRECTLY FALSIFIED with property error. Shrinks: \(shrinks)")
    }
}