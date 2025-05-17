//
//  StatefulRunner.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen
import Testing // For Issue.record, Comment, SourceLocation

// Define a custom error type for sequence failures
struct StatefulTestSequenceFailure<Model: StateModel>: Error, Sendable where
    Model.State: Sendable,
    Model.CommandVar: Sendable,
    Model.ResponseVar: Sendable,
    Model.CommandConcrete: Sendable,
    Model.ResponseConcrete: Sendable
{
    let sequence: CommandSequence<Model>
    let underlyingError: Error // The SUT error or divergence error
    let message: String

    var localizedDescription: String {
        return "\(message) - Underlying: \(underlyingError.localizedDescription)"
    }
}

public func stateful<Model: StateModel, SUT_Runner>(
    _ propertyName: String,
    sutFactory: @Sendable () async -> SUT_Runner,
    maxCommandsInSequence: Int = 100,
    numberOfSequences: Int = 10,
    seed: UInt64? = nil,
    reporter: Reporter = ConsoleReporter(),
    file: StaticString = #file,
    line: UInt = #line
) async -> TestResult<CommandSequence<Model>> where
    Model.State: Sendable,
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
        var localRng = SystemRandomNumberGenerator()
        effectiveSeed = localRng.next()
    }
    
    // UPDATED COMMENT: Reflecting current robust RNG handling per sequence.
    // Each sequence run starts with a fresh RNG derived deterministically from the
    // effectiveSeed and the sequenceIndex. This ensures sequence generation is
    // independent and reproducible.
    print("Stateful Test: '\(propertyName)' starting. Seed: \(effectiveSeed)")

    // --- Outer loop for generating and testing multiple command sequences ---
    for sequenceIndex in 0..<numberOfSequences {
        // Create a new RNG for this sequence attempt to ensure independence
        var sequenceRng = Xoshiro(seed: effectiveSeed.addingReportingOverflow(UInt64(sequenceIndex)).partialValue)

        // --- Generate one full command sequence ---
        let generationResult: Result<CommandSequence<Model>, StatefulTestSequenceFailure<Model>> = await generateAndExecuteSequence(
            modelType: Model.self,
            sutFactory: sutFactory,
            maxCommands: maxCommandsInSequence,
            rng: &sequenceRng,
            propertyName: propertyName,
            sequenceIndexForLog: sequenceIndex
        )

        switch generationResult {
        case .success(let executedSequence):
            if executedSequence.steps.count > 0 {
                 print("  [\(sequenceIndex)] Sequence completed successfully with \(executedSequence.steps.count) commands.")
            } else if maxCommandsInSequence > 0 {
                 print("  [\(sequenceIndex)] Sequence completed with no commands executed (possibly all preconditions failed).")
            }
            // Model.monitoring could be called here
            
        case .failure(let sequenceFailure):
            reporter.reportFailure(
                description: propertyName,
                input: sequenceFailure.sequence,
                error: sequenceFailure.underlyingError,
                file: file,
                line: line
            )
            print("Property '\(propertyName)' failed in sequence \(sequenceIndex) (Seed: \(effectiveSeed))")
            print("Original Error: \(sequenceFailure.localizedDescription)")
            print("Original Failing Sequence (length \(sequenceFailure.sequence.steps.count)):")

            print("Starting shrinking of command sequence...")

            let shrinkResult = await shrinkStatefulSequence(
                initialFailingSequence: sequenceFailure.sequence,
                initialError: sequenceFailure.underlyingError,
                modelType: Model.self,
                sutFactory: sutFactory,
                propertyName: propertyName,
                originalSeed: effectiveSeed,
                reporter: reporter,
                file: file,
                line: line
            )
            return shrinkResult
        }
    } // End of sequenceLoop

    print("Stateful Test '\(propertyName)' PASSED after \(numberOfSequences) sequences (max \(maxCommandsInSequence) commands each).")
    reporter.reportSuccess(description: propertyName, iterations: numberOfSequences)
    return .succeeded(testsRun: numberOfSequences)
}


// Helper function to generate and execute a single command sequence
private func generateAndExecuteSequence<Model: StateModel, SUT_Runner>(
    modelType: Model.Type,
    sutFactory: @Sendable () async -> SUT_Runner,
    maxCommands: Int,
    rng: inout Xoshiro,
    propertyName: String,
    sequenceIndexForLog: Int
) async -> Result<CommandSequence<Model>, StatefulTestSequenceFailure<Model>> where
    Model.State: Sendable,
    Model.CommandVar: Sendable,
    Model.ResponseVar: Sendable,
    Model.CommandConcrete: Sendable,
    Model.ResponseConcrete: Sendable,
    Model.ReferenceType: Sendable,
    SUT_Runner: Sendable,
    Model.SUT == SUT_Runner
{
    let sutInstance = await sutFactory()
    var currentModelState = Model.initialState
    var executedSteps: [ExecutedCommand<Model>] = []
    var referenceMap: [Var<Model.ReferenceType>: Model.ReferenceType] = [:]
    var preconditionFailuresInSequence = 0
    let maxPreconditionFailures = maxCommands == 0 ? 1 : maxCommands * 2 + 1

    if maxCommands == 0 {
        return .success(CommandSequence<Model>(
            initialState: Model.initialState,
            steps: [],
            finalModelState: currentModelState
        ))
    }
    
    commandLoop: for cmdIndex in 0..<maxCommands {
        if preconditionFailuresInSequence > maxPreconditionFailures {
            print("  [\(sequenceIndexForLog):\(cmdIndex)] Sequence \(sequenceIndexForLog) aborted for '\(propertyName)': Too many precondition failures.")
            return .success(CommandSequence<Model>(initialState: Model.initialState, steps: executedSteps, finalModelState: currentModelState))
        }

        let resolver: @Sendable (Var<Model.ReferenceType>) -> Model.ReferenceType = { [referenceMap] varSymbol in
            guard let concreteRef = referenceMap[varSymbol] else {
                fatalError("Resolver Error: No concrete reference for symbolic Var \(varSymbol.id). Map: \(referenceMap.keys.map { $0.id })")
            }
            return concreteRef
        }

        let symbolicCommand = Model.generateCommand(currentModelState).run(using: &rng)
        let stateBeforeCommand = currentModelState
        let fakeRunResult = Model.runFake(symbolicCommand, inState: currentModelState)

        switch fakeRunResult {
        case .left(_):
            preconditionFailuresInSequence += 1
            continue commandLoop
        
        case .right((let nextModelState, let modelResponse)):
            let concreteCommand = Model.concretizeCommand(symbolicCommand, resolver: resolver)
            var actualResponseValue: Model.ResponseConcrete? = nil
            var realRunError: Error? = nil

            do {
                actualResponseValue = try await Model.runReal(concreteCommand, sut: sutInstance)()
            } catch {
                realRunError = error
            }

            // MODIFIED: Construct ExecutedCommand directly with optional actualResponseValue.
            // The forced cast is no longer present.
            let executedCommandForStep = ExecutedCommand<Model>(
                symbolicCommand: symbolicCommand,
                concreteCommand: concreteCommand,
                modelResponse: modelResponse,
                actualResponse: actualResponseValue, // actualResponseValue is Model.ResponseConcrete?
                stateBefore: stateBeforeCommand,
                stateAfter: nextModelState
            )
            
            let currentPartialSequence = CommandSequence<Model>(
                initialState: Model.initialState,
                steps: executedSteps + [executedCommandForStep],
                finalModelState: nextModelState
            )

            if let error = realRunError {
                // actualResponse in executedCommandForStep will be nil here if runReal threw.
                return .failure(StatefulTestSequenceFailure(sequence: currentPartialSequence, underlyingError: error, message: "SUT error during command \(cmdIndex) ('\(concreteCommand)') in sequence \(sequenceIndexForLog) for '\(propertyName)'"))
            }

            guard let unwrappedActualResponse = actualResponseValue else {
                // This case means runReal completed without throwing but returned nil,
                // which is unexpected unless ResponseConcrete itself is an Optional type
                // that is *not* representing an error but a valid nil response.
                // If ResponseConcrete is non-optional, actualResponseValue being nil here is a problem.
                // If ResponseConcrete *is* Optional, this guard might be too strict if nil is a valid success response.
                // For now, assuming nil actualResponseValue without an error is a critical issue.
                let criticalError = TestFailureError(message: "Critical Runner Error: Actual SUT response is nil but no error was thrown by runReal.")
                // actualResponse in executedCommandForStep will be nil here.
                return .failure(StatefulTestSequenceFailure(sequence: currentPartialSequence, underlyingError: criticalError, message: "Runner critical error during command \(cmdIndex) for '\(propertyName)'"))
            }
            
            // At this point, unwrappedActualResponse is non-nil.
            // The executedCommandForStep already correctly has actualResponseValue (which is unwrappedActualResponse).
            // No need to create 'finalExecutedCommandForStep' just to update the response,
            // as executedCommandForStep already holds the correct optional value.
            // We use unwrappedActualResponse for areResponsesEquivalent and extractNewReferences.

            if !Model.areResponsesEquivalent(symbolicResponse: modelResponse, concreteResponse: unwrappedActualResponse, resolver: resolver) {
                let divergenceError = TestFailureError(message: "Model-SUT Response Divergence. Cmd: \(concreteCommand), ModelResp: \(modelResponse), SUTResp: \(unwrappedActualResponse)")
                // The sequenceWithDivergence should use the executedCommandForStep which now correctly
                // has the unwrappedActualResponse because we passed the check.
                // However, executedCommandForStep was built with actualResponseValue (which is unwrappedActualResponse here).
                // So, currentPartialSequence is already correct for this divergence.
                return .failure(StatefulTestSequenceFailure(sequence: currentPartialSequence, underlyingError: divergenceError, message: "Response divergence at command \(cmdIndex) for '\(propertyName)'"))
            }

            currentModelState = nextModelState
            let newReferences = Model.extractNewReferences(responseVar: modelResponse, responseConcrete: unwrappedActualResponse)
            referenceMap.merge(newReferences) { (current, _) in current }
            
            executedSteps.append(executedCommandForStep) // Add the successful step
        }
    } // End of commandLoop

    return .success(CommandSequence<Model>(
        initialState: Model.initialState,
        steps: executedSteps,
        finalModelState: currentModelState
    ))
}


// --- Shrinking Function for Stateful Sequences ---
private func shrinkStatefulSequence<Model: StateModel, SUT_Runner>(
    initialFailingSequence: CommandSequence<Model>,
    initialError: Error,
    modelType: Model.Type,
    sutFactory: @Sendable () async -> SUT_Runner,
    propertyName: String,
    originalSeed: UInt64,
    reporter: Reporter,
    file: StaticString,
    line: UInt
) async -> TestResult<CommandSequence<Model>> where
    Model.State: Sendable,
    Model.CommandVar: Sendable,
    Model.ResponseVar: Sendable,
    Model.CommandConcrete: Sendable,
    Model.ResponseConcrete: Sendable,
    Model.ReferenceType: Sendable,
    SUT_Runner: Sendable,
    Model.SUT == SUT_Runner
{
    var currentBestFailureSequence = initialFailingSequence
    var errorForCurrentBest: Error = initialError
    var shrinksDone = 0

    print("Shrinking Stateful Sequence for '\(propertyName)': initial sequence length \(currentBestFailureSequence.steps.count), error: \(errorForCurrentBest.localizedDescription)")

    var madeProgressInOuterLoop = true
    while madeProgressInOuterLoop {
        madeProgressInOuterLoop = false
        
        let candidates = generateShrinkCandidates(
            for: currentBestFailureSequence,
            modelType: Model.self
        )

        if candidates.isEmpty {
            print("  No smaller command sequence candidates to try.")
            break
        }
        
        print("  Trying \(candidates.count) shrink candidates for sequence of length \(currentBestFailureSequence.steps.count)...")

        candidateLoop: for candidateSymbolicCommands in candidates {
            let candidateExecutionResult: Result<CommandSequence<Model>, StatefulTestSequenceFailure<Model>> = await executeCandidateSymbolicSequence(
                symbolicCommands: candidateSymbolicCommands,
                modelType: Model.self,
                sutFactory: sutFactory,
                propertyName: propertyName,
                sequenceIndexForLog: -1 // Indicates a shrink attempt
            )
            
            switch candidateExecutionResult {
            case .success(_):
                continue candidateLoop
            case .failure(let sequenceFailure):
                print("  Shrinking '\(propertyName)': found smaller failing sequence (length \(sequenceFailure.sequence.steps.count)) with error: \(sequenceFailure.underlyingError.localizedDescription)")
                
                currentBestFailureSequence = sequenceFailure.sequence
                errorForCurrentBest = sequenceFailure.underlyingError
                shrinksDone += 1
                madeProgressInOuterLoop = true
                break candidateLoop
            }
        }
    }

    print("Shrinking Stateful Sequence for '\(propertyName)': finished. Minimal failing sequence length: \(currentBestFailureSequence.steps.count)")
    
    reporter.reportFinalCounterexample(
        description: propertyName,
        input: currentBestFailureSequence,
        error: errorForCurrentBest,
        file: file,
        line: line
    )
    
    let failureComment = "Minimal failing command sequence for '\(propertyName)' (length \(currentBestFailureSequence.steps.count)). Seed: \(originalSeed)."
    Issue.record(errorForCurrentBest, Comment(rawValue: failureComment), sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 0))
    
    return .falsified(value: currentBestFailureSequence, error: errorForCurrentBest, shrinks: shrinksDone, seed: originalSeed)
}


// --- Helper for generating shrink candidates (Unaffected by ExecutedCommand.actualResponse change) ---
internal func generateShrinkCandidates<Model: StateModel>(
    for sequence: CommandSequence<Model>,
    modelType: Model.Type
) -> [[Model.CommandVar]] where Model.CommandVar: Sendable, Model.State: Sendable, Model.ReferenceType: Sendable {
    var candidates: [[Model.CommandVar]] = []
    let originalSymbolicCommands = sequence.steps.map { $0.symbolicCommand }

    guard !originalSymbolicCommands.isEmpty else { return [] }

    // Strategy 1: Remove commands
    if !originalSymbolicCommands.isEmpty {
        candidates.append([]) // Offer empty sequence
    }
    for i in originalSymbolicCommands.indices {
        var shrunkCmds = originalSymbolicCommands
        shrunkCmds.remove(at: i)
        if !shrunkCmds.isEmpty { // Avoid adding empty twice if original had 1 element
             candidates.append(shrunkCmds)
        }
    }
    
    // Strategy 2: Shrink individual commands
    for (idx, step) in sequence.steps.enumerated() {
        let symbolicCmd = step.symbolicCommand
        let stateBeforeThisCommand = step.stateBefore

        let shrunkenCmdVariations = Model.shrinkCommand(symbolicCmd, inState: stateBeforeThisCommand)
        
        for shrunkCmdVar in shrunkenCmdVariations {
            var newCmdList = originalSymbolicCommands
            newCmdList[idx] = shrunkCmdVar
            candidates.append(newCmdList)
        }
    }
    
    // Deduplicate and sort by length
    // Using a Set to deduplicate assuming Model.CommandVar is Hashable.
    // If not, more complex deduplication or allowing duplicates might be needed.
    // For simplicity, if CommandVar is not Hashable, duplicates might pass through.
    // This part can be enhanced if CommandVar is guaranteed Hashable.
    // For now, focusing on the sorting.
    return candidates.sorted { $0.count < $1.count }
}

// Helper to execute a candidate list of *symbolic* commands
private func executeCandidateSymbolicSequence<Model: StateModel, SUT_Runner>(
    symbolicCommands: [Model.CommandVar],
    modelType: Model.Type,
    sutFactory: @Sendable () async -> SUT_Runner,
    propertyName: String,
    sequenceIndexForLog: Int
) async -> Result<CommandSequence<Model>, StatefulTestSequenceFailure<Model>> where
    Model.State: Sendable,
    Model.CommandVar: Sendable,
    Model.ResponseVar: Sendable,
    Model.CommandConcrete: Sendable,
    Model.ResponseConcrete: Sendable,
    Model.ReferenceType: Sendable,
    SUT_Runner: Sendable,
    Model.SUT == SUT_Runner
{
    if symbolicCommands.isEmpty {
        return .success(CommandSequence<Model>(initialState: Model.initialState, steps: [], finalModelState: Model.initialState))
    }

    let sutInstance = await sutFactory()
    var currentModelState = Model.initialState
    var executedSteps: [ExecutedCommand<Model>] = []
    var referenceMap: [Var<Model.ReferenceType>: Model.ReferenceType] = [:]
    var preconditionFailuresInSequence = 0
    let maxPreconditionFailures = symbolicCommands.count + 1


    commandLoop: for (cmdIndex, symbolicCommand) in symbolicCommands.enumerated() {
        if preconditionFailuresInSequence > maxPreconditionFailures {
            let error = TestFailureError(message: "Shrink candidate path invalid for '\(propertyName)' due to too many precondition failures (\(preconditionFailuresInSequence)).")
            return .failure(StatefulTestSequenceFailure(sequence: CommandSequence<Model>(initialState: Model.initialState, steps: executedSteps, finalModelState: currentModelState), underlyingError: error, message: error.message))
        }

        let resolver: @Sendable (Var<Model.ReferenceType>) -> Model.ReferenceType = { [referenceMap] varSymbol in
            guard let concreteRef = referenceMap[varSymbol] else {
                fatalError("Resolver Error during shrink: No concrete reference for symbolic Var \(varSymbol.id). Map: \(referenceMap.keys.map { $0.id })")
            }
            return concreteRef
        }

        let stateBeforeCommand = currentModelState
        let fakeRunResult = Model.runFake(symbolicCommand, inState: currentModelState)

        switch fakeRunResult {
        case .left(let preconditionFailure):
            preconditionFailuresInSequence += 1
             return .failure(StatefulTestSequenceFailure(sequence: CommandSequence<Model>(initialState: Model.initialState, steps: executedSteps, finalModelState: currentModelState), underlyingError: preconditionFailure, message: "Precondition failed for command \(symbolicCommand) in shrink candidate for '\(propertyName)'."))
        
        case .right((let nextModelState, let modelResponse)):
            let concreteCommand = Model.concretizeCommand(symbolicCommand, resolver: resolver)
            var actualResponseValue: Model.ResponseConcrete? = nil
            var realRunError: Error? = nil

            do {
                actualResponseValue = try await Model.runReal(concreteCommand, sut: sutInstance)()
            } catch {
                realRunError = error
            }
            
            // MODIFIED: Construct ExecutedCommand directly with optional actualResponseValue.
            let executedCommandForStep = ExecutedCommand<Model>(
                symbolicCommand: symbolicCommand,
                concreteCommand: concreteCommand,
                modelResponse: modelResponse,
                actualResponse: actualResponseValue, // actualResponseValue is Model.ResponseConcrete?
                stateBefore: stateBeforeCommand,
                stateAfter: nextModelState
            )

            let currentPartialSequence = CommandSequence<Model>(
                initialState: Model.initialState,
                steps: executedSteps + [executedCommandForStep],
                finalModelState: nextModelState
            )

            if let error = realRunError {
                return .failure(StatefulTestSequenceFailure(sequence: currentPartialSequence, underlyingError: error, message: "SUT error during command \(cmdIndex) ('\(concreteCommand)') in sequence \(sequenceIndexForLog) for '\(propertyName)'"))
            }

            guard let unwrappedActualResponse = actualResponseValue else {
                let criticalError = TestFailureError(message: "Critical Runner Error (shrink): Actual SUT response is nil but no error thrown.")
                return .failure(StatefulTestSequenceFailure(sequence: currentPartialSequence, underlyingError: criticalError, message: "Runner critical error during command \(cmdIndex) for '\(propertyName)'"))
            }
            
            // As before, executedCommandForStep already has the correct actualResponse.
            if !Model.areResponsesEquivalent(symbolicResponse: modelResponse, concreteResponse: unwrappedActualResponse, resolver: resolver) {
                let divergenceError = TestFailureError(message: "Model-SUT Response Divergence. Cmd: \(concreteCommand), ModelResp: \(modelResponse), SUTResp: \(unwrappedActualResponse)")
                return .failure(StatefulTestSequenceFailure(sequence: currentPartialSequence, underlyingError: divergenceError, message: "Response divergence at command \(cmdIndex) for '\(propertyName)'"))
            }

            currentModelState = nextModelState
            let newReferences = Model.extractNewReferences(responseVar: modelResponse, responseConcrete: unwrappedActualResponse)
            referenceMap.merge(newReferences) { (current, _) in current }
            
            executedSteps.append(executedCommandForStep)
        }
    } // End of commandLoop

    return .success(CommandSequence<Model>(
        initialState: Model.initialState,
        steps: executedSteps,
        finalModelState: currentModelState
    ))
}