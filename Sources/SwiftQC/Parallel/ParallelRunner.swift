//
//  ParallelRunner.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/16/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

// File: Sources/SwiftQC/Parallel/ParallelRunner.swift

import Gen
#if canImport(Testing)
import Testing // For Issue.record, Comment, SourceLocation
#endif
import Atomics

public protocol DefaultableResponse {
    static var defaultPlaceholderResponse: Self { get }
}

// MARK: - Top-Level Helper Actors

private actor Orchestrator<Model: ParallelModel> where
    Model.State: Sendable & Comparable,
    Model.CommandVar: Sendable,
    Model.ResponseVar: Sendable,
    Model.ReferenceType: Sendable
{
    private var modelStates: [Model.State]
    private var rng: Xoshiro
    private var commandLog: [(opId: Int, symbolic: Model.CommandVar, virtualThreadId: Int)] = []
    // modelReferenceMap is for orchestrator's internal simulation during planning.
    private var modelReferenceMap: [Var<Model.ReferenceType>: Model.ReferenceType] = [:]
    private let initialThreads: Int

    init(threads: Int, initialSeed: UInt64) {
        self.initialThreads = threads
        self.modelStates = Array(repeating: Model.initialState, count: threads)
        self.rng = Xoshiro(seed: initialSeed)
    }

    // Not currently used externally, but could be if direct model inspection was needed.
    // func getModelResolverForPlanning() -> @Sendable (Var<Model.ReferenceType>) -> Model.ReferenceType { ... }
    
    // func updateModelReferenceMap(newRefs: [Var<Model.ReferenceType>: Model.ReferenceType]) { ... }

    func planOperations(totalOps: Int) -> [(opId: Int, symbolic: Model.CommandVar, virtualThreadId: Int)] {
        var plannedOpsForSUT: [(opId: Int, symbolic: Model.CommandVar, virtualThreadId: Int)] = []
        self.commandLog = [] // Reset for this planning pass
        self.modelStates = Array(repeating: Model.initialState, count: initialThreads) // Reset model states
        self.modelReferenceMap = [:] // Reset model ref map

        var opIdCounter = 0
        var generationAttempts = 0
        let maxGenerationAttempts = totalOps * 3 

        while opIdCounter < totalOps && generationAttempts < maxGenerationAttempts {
            generationAttempts += 1
            let virtualThreadId = opIdCounter % modelStates.count
            let symbolicCmd = Model.generateParallelCommand(modelStates).run(using: &rng)
            let stateBefore = modelStates[virtualThreadId]
            
            let fakeRunResult = Model.runFake(symbolicCmd, inState: stateBefore)

            switch fakeRunResult {
            case .right((let nextModelState, _ /* let modelResponse */ )): // modelResponse from runFake is not used in P1 planning
                plannedOpsForSUT.append((opId: opIdCounter, symbolic: symbolicCmd, virtualThreadId: virtualThreadId))
                self.commandLog.append((opId: opIdCounter, symbolic: symbolicCmd, virtualThreadId: virtualThreadId))
                modelStates[virtualThreadId] = nextModelState
                opIdCounter += 1
            case .left:
                print("  Planning: Precondition failed for symbolic \(symbolicCmd) on vThread \(virtualThreadId). Retrying.")
                continue
            }
        }
        if opIdCounter < totalOps {
            print("Warning: Orchestrator only planned \(opIdCounter)/\(totalOps) operations.")
        }
        return plannedOpsForSUT
    }
    
    func getCommandLogForShrinking() -> [(opId: Int, symbolic: Model.CommandVar, virtualThreadId: Int)] {
        return commandLog
    }

    func getInitialModelStates() -> [Model.State] {
        return Array(repeating: Model.initialState, count: initialThreads)
    }
}

private actor SUTReferenceManager<Model: ParallelModel> where Model.ReferenceType: Sendable {
    private var refMap: [Var<Model.ReferenceType>: Model.ReferenceType] = [:]

    func getResolver() -> @Sendable (Var<Model.ReferenceType>) -> Model.ReferenceType {
        let capturedMap = self.refMap
        return { symbolicVar in
            guard let concreteRef = capturedMap[symbolicVar] else {
                fatalError("SUT Task Resolver: No concrete reference for symbolic Var \(symbolicVar.id). Available: \(capturedMap.keys.map(\.id))")
            }
            return concreteRef
        }
    }

    func store(newRefs: [Var<Model.ReferenceType>: Model.ReferenceType]) {
        refMap.merge(newRefs, uniquingKeysWith: { (current, _) in current })
    }
    
    func reset() {
        refMap = [:]
    }
}

// MARK: - Main Parallel Runner Function

public func parallel<Model: ParallelModel, SUT_Runner>(
    _ propertyName: String,
    threads: Int = 2,
    forks: Int = 10,
    seed: UInt64? = nil,
    reporter: Reporter = ConsoleReporter(),
    file: StaticString = #file,
    line: UInt = #line,
    modelType: Model.Type,
    sutFactory: @escaping @Sendable () async -> SUT_Runner,
    _ property: @escaping (ParallelExecutionResult<Model>) async throws -> Void
) async -> TestResult<ParallelExecutionResult<Model>>
    where Model.State: Sendable & Comparable,
          Model.CommandVar: Sendable,
          Model.ResponseVar: Sendable,
          Model.CommandConcrete: Sendable,
          Model.ResponseConcrete: Sendable,
          Model.ReferenceType: Sendable,
          SUT_Runner: Sendable,
          Model.SUT == SUT_Runner
{
    let effectiveSeed: UInt64
    if let providedSeed = seed {
        effectiveSeed = providedSeed
    } else {
        var localRng = SystemRandomNumberGenerator() // Create a mutable instance
        effectiveSeed = localRng.next()             // Call next() on the mutable instance
    }

    print("Parallel Test: '\(propertyName)' starting. Seed: \(effectiveSeed), Target SUT Threads: \(threads), Target Operations: \(forks)")

    let orchestrator = Orchestrator<Model>(threads: threads, initialSeed: effectiveSeed)
    let sutRefManager = SUTReferenceManager<Model>()
    let factoryToPass: @Sendable () async -> SUT_Runner = sutFactory

    let initialCommandPlan = await orchestrator.planOperations(totalOps: forks)
    
    if initialCommandPlan.isEmpty && forks > 0 {
        print("Warning: Initial command plan is empty after planning \(forks) ops. All model preconditions might have failed.")
    }

    var executionResultAfterRunner = await executeParallelRunInternal(
        commandPlan: initialCommandPlan,
        modelType: Model.self,
        passedSutFactory: factoryToPass,
        sutRefManager: sutRefManager,
        orchestrator: orchestrator,
        threads: threads
    )

    let errorDetectedByRunner = executionResultAfterRunner.overallError // Capture the error from the runner
    var finalErrorToReport: Error? = errorDetectedByRunner // Initialize with runner's error

    if errorDetectedByRunner == nil { // Only run the property if no error was detected
        do {
            try await property(executionResultAfterRunner)
            print("[parallel func] Property block executed successfully.")
        } catch {
            print("Property '\(propertyName)' threw an error: \(error.localizedDescription)")
            finalErrorToReport = error // Update to the error from the property
            executionResultAfterRunner.overallError = error // Update the result struct
        }
    } else {
        print("[parallel func] Condition 'errorDetectedByRunner == nil' is FALSE. Skipping property block.")
    }

    if let actualFailureError = finalErrorToReport {
        // Report the failure and handle shrinking logic
        print("[parallel func] Returning .falsified with error: \(actualFailureError)")
        return .falsified(value: executionResultAfterRunner, error: actualFailureError, shrinks: 0, seed: effectiveSeed)
    } else {
        // No errors from runner or property.
        print("[parallel func] Returning .succeeded")
        reporter.reportSuccess(description: propertyName, iterations: forks)
        return .succeeded(testsRun: forks)
    }
}

// Helper for generating shrink candidates for parallel command plans
private func generateParallelShrinkCandidates<Model: ParallelModel>(
    for commandPlan: [(opId: Int, symbolic: Model.CommandVar, virtualThreadId: Int)],
    modelType: Model.Type
) -> [[(opId: Int, symbolic: Model.CommandVar, virtualThreadId: Int)]] {
    var candidates: [[(opId: Int, symbolic: Model.CommandVar, virtualThreadId: Int)]] = []
    guard !commandPlan.isEmpty else { return [] }

    candidates.append([]) // Always offer empty

    for i in commandPlan.indices {
        var shrunkPlan = commandPlan
        shrunkPlan.remove(at: i)
        if !shrunkPlan.isEmpty { // Avoid adding empty list twice
            candidates.append(shrunkPlan)
        }
    }
    // TODO: Add individual command shrinking using Model.shrinkParallelCommand here
    // This would require more context (model states at the point of each command in the plan)
    // For P1, removing operations is the primary strategy.

    // Sort by length and then by opId sequence to ensure deterministic order of candidates for testing
    return candidates.sorted {
        if $0.count != $1.count {
            return $0.count < $1.count
        }
        return ($0.map(\.opId).lexicographicallyPrecedes($1.map(\.opId)))
    }
}

// MARK: - Internal Execution Helper
private func executeParallelRunInternal<Model: ParallelModel, SUT_Runner>(
    commandPlan: [(opId: Int, symbolic: Model.CommandVar, virtualThreadId: Int)],
    modelType: Model.Type,
    passedSutFactory: @Sendable () async -> SUT_Runner,
    sutRefManager: SUTReferenceManager<Model>,
    orchestrator: Orchestrator<Model>,
    threads: Int
) async -> ParallelExecutionResult<Model>
    where Model.State: Sendable & Comparable,
          Model.CommandVar: Sendable,
          Model.ResponseVar: Sendable,
          Model.CommandConcrete: Sendable,
          Model.ResponseConcrete: Sendable,
          Model.ReferenceType: Sendable,
          SUT_Runner: Sendable,
          Model.SUT == SUT_Runner
{
    let sut = await passedSutFactory()
    
    var eventHistory: [ParallelEvent<Model>] = []
    var overallErrorInternal: Error? = nil
    
    let initialModelStatesForRun = await orchestrator.getInitialModelStates()

    await withTaskGroup(of: ParallelEvent<Model>.self) { group in
        for plannedOp in commandPlan {
            let opId = plannedOp.opId
            let symbolicCmd = plannedOp.symbolic
            let virtualThreadIdForModel = plannedOp.virtualThreadId

            group.addTask {
                // FIX: taskLocalModelState and taskLocalModelRefMap changed to 'let'
                let taskLocalModelState = initialModelStatesForRun[virtualThreadIdForModel]
                let taskLocalModelRefMap: [Var<Model.ReferenceType>: Model.ReferenceType] = [:] 
                
                // This resolver is local to the task.
                // For P1, taskLocalModelRefMap is empty. If symbolicCmd contains model-generated Vars
                // that need resolving *before* runFake, this would fail unless they are globally known.
                // This path is mainly for the dummyConcreteCmd in the error case.
                let taskLocalModelResolver: @Sendable (Var<Model.ReferenceType>) -> Model.ReferenceType = { vSym in
                     guard let cRef = taskLocalModelRefMap[vSym] else { 
                        // This fatalError will trigger if symbolicCmd (in error case below) has unresolved Vars
                        fatalError("Task local model resolver fail for Var \(vSym.id). Task local map is empty.")
                     }
                     return cRef
                }

                let modelStateBeforeOp = taskLocalModelState
                let fakeRunResult = Model.runFake(symbolicCmd, inState: modelStateBeforeOp)
                
                let modelResponseOp: Model.ResponseVar
                let modelStateAfterOp: Model.State

                switch fakeRunResult {
                case .right((let nextState, let response)):
                    modelStateAfterOp = nextState
                    modelResponseOp = response
                case .left(let precondFailure):
                    let err = ParallelRunnerError(message: "Model Inconsistency: Planned op \(symbolicCmd) opId \(opId) failed model precondition during SUT phase. Error: \(precondFailure)")
                    let dummyConcreteCmd = Model.concretizeCommand(symbolicCmd, resolver: taskLocalModelResolver) 

                    let dummyModelResponse: Model.ResponseVar 
                    if let defaultResponseProvider = Model.self as? any DefaultableResponse.Type, // Changed DefaultableResponseType to DefaultableResponse
                       let defaultResponse = defaultResponseProvider.defaultPlaceholderResponse as? Model.ResponseVar { // Changed defaultResponse to defaultPlaceholderResponse
                        dummyModelResponse = defaultResponse
                    } else {
                         fatalError("Model.ResponseVar for opId \(opId) cannot be initialized for error event. Model type: \(Model.self) (for symbolic cmd: \(symbolicCmd)) does not conform to DefaultableResponseType or it's not providing the correct ResponseVar type.")
                    }
                    return ParallelEvent(opId: opId, virtualThreadId: virtualThreadIdForModel, symbolicCommand: symbolicCmd,
                                         concreteCommand: dummyConcreteCmd, modelResponse: dummyModelResponse,
                                         actualResponse: nil, modelStateBefore: modelStateBeforeOp,
                                         modelStateAfter: modelStateBeforeOp, sutError: err)
                }
                
                let sutOpResolver = await sutRefManager.getResolver()
                let concreteCommand = Model.concretizeCommand(symbolicCmd, resolver: sutOpResolver)

                var actualSutResponse: Model.ResponseConcrete? = nil
                var sutError: Error? = nil
                do {
                    let monad = Model.runReal(concreteCommand, sut: sut)
                    let ioAction = Model.runCommandMonad(monad)
                    actualSutResponse = try await ioAction.run()

                    if let resp = actualSutResponse {
                        let newSutRefs = Model.extractNewReferences(responseVar: modelResponseOp, responseConcrete: resp)
                        await sutRefManager.store(newRefs: newSutRefs)
                    }
                } catch {
                    sutError = error
                    // Added diagnostic logging for SUT errors
                    print("[PID:\(opId)] SUT Execution Error Caught: \(error)")
                }
                
                return ParallelEvent(
                    opId: opId, virtualThreadId: virtualThreadIdForModel, symbolicCommand: symbolicCmd,
                    concreteCommand: concreteCommand, modelResponse: modelResponseOp,
                    actualResponse: actualSutResponse, modelStateBefore: modelStateBeforeOp,
                    modelStateAfter: modelStateAfterOp,
                    sutError: sutError
                )
            }
        }
        
        var collectedEvents: [ParallelEvent<Model>] = []
        for await event in group {
            collectedEvents.append(event)
        }
        eventHistory = collectedEvents.sorted(by: { $0.opId < $1.opId })
    }

    var finalSimulatedModelStates = await orchestrator.getInitialModelStates() // Start from initial states

    for event in eventHistory {
        let shouldSkipModelUpdate = event.sutError != nil && 
                                   !((event.sutError as? ParallelRunnerError)?.message.contains("Model Inconsistency") ?? false)

        if !shouldSkipModelUpdate {
            let modelStateForThisCmdInFinalSim = finalSimulatedModelStates[event.virtualThreadId]
            if case .right((let nextState, let modelRespForFinalSim)) = Model.runFake(event.symbolicCommand, inState: modelStateForThisCmdInFinalSim) {
                finalSimulatedModelStates[event.virtualThreadId] = nextState // Mutate here
                // Handle references if needed
                if let actualResp = event.actualResponse {
                    let _ = Model.extractNewReferences(responseVar: modelRespForFinalSim, responseConcrete: actualResp) // Changed to _
                }
            }
        }
    }

    // --- Determine overallErrorInternal ---
    overallErrorInternal = nil // Reset before checking

    // Pass 1: Check for actual SUT runtime errors from events
    for event in eventHistory {
        if let sutErr = event.sutError {
            // Ignore "Model Inconsistency" as it's a runner-internal planning/simulation issue,
            // not a direct SUT operational failure we want to prioritize for this check.
            if let runnerErr = sutErr as? ParallelRunnerError, runnerErr.message.contains("Model Inconsistency") {
                continue // This isn't a primary SUT failure for this pass
            }
            // This is a direct SUT runtime error. This is the highest priority error.
            overallErrorInternal = sutErr
            print("[executeParallelRunInternal] Prioritized SUT Error: \(sutErr) from OpId \(event.opId)")
            break // Found the first critical SUT error
        }
    }

    // Pass 2: If no direct SUT runtime error, check for divergence or critical nil responses
    if overallErrorInternal == nil {
        for event in eventHistory where event.sutError == nil {
            // Only evaluate events that didn't have a SUT error reported (as that would have been caught above)
            if let actualResp = event.actualResponse {
                let sutResolverForEquivalence = await sutRefManager.getResolver()
                if !Model.areResponsesEquivalent(symbolicResponse: event.modelResponse, concreteResponse: actualResp, resolver: sutResolverForEquivalence) {
                    overallErrorInternal = ParallelRunnerError(message: "Parallel Divergence: OpId \(event.opId), Cmd \(event.concreteCommand), ModelResp \(event.modelResponse), SUTResp \(actualResp)")
                    print("[executeParallelRunInternal] Detected Divergence: \(overallErrorInternal!)")
                    break // Found the first divergence
                }
            } else { // No SUT error, but actualResponse is nil
                overallErrorInternal = ParallelRunnerError(message: "Parallel Critical: Nil SUT response without error for OpId \(event.opId), Cmd \(event.concreteCommand)")
                print("[executeParallelRunInternal] Detected Critical Nil Response: \(overallErrorInternal!)")
                break // Found the first critical nil response
            }
        }
    }
    
    // If overallErrorInternal is still a "Model Inconsistency" error, that's fine, it means no other SUT errors or divergences occurred.
    // If it's nil, it means no errors of any kind occurred.

    return ParallelExecutionResult<Model>(
        initialModelStates: await orchestrator.getInitialModelStates(),
        events: eventHistory,
        finalModelStates: finalSimulatedModelStates, // Now correctly reflects simulated final states
        overallError: overallErrorInternal
    )
}

fileprivate extension Array {
    func removingDuplicates<T: Hashable>(by keyForValue: (Element) throws -> T) rethrows -> [Element] {
        var seen = Set<T>()
        return try filter { seen.insert(try keyForValue($0)).inserted }
    }
}