//
//  StatefulRunner.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen
import Testing // For Issue.record if we use it for failures

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
    var rng = Xoshiro(seed: effectiveSeed)
    var lastFailure: TestResult<CommandSequence<Model>>? = nil

    print("Stateful Test: '\(propertyName)' starting. Seed: \(effectiveSeed)")

    sequenceLoop: for sequenceIndex in 0..<numberOfSequences {
        let sutInstance = await sutFactory()
        var currentModelState = Model.initialState
        var executedSteps: [ExecutedCommand<Model>] = []
        // Initialize the reference map for this sequence
        var referenceMap: [Var<Model.ReferenceType>: Model.ReferenceType] = [:]

        var commandLoopIterations = 0
        var preconditionFailuresInSequence = 0
        let maxPreconditionFailures = maxCommandsInSequence * 2

        commandLoop: for cmdIndex in 0..<maxCommandsInSequence {
            if preconditionFailuresInSequence > maxPreconditionFailures {
                print("  [\(sequenceIndex):\(cmdIndex)] Sequence \(sequenceIndex) aborted: Too many precondition failures.")
                break commandLoop
            }

            // Define the REAL resolver closure INSIDE the loop, capturing the current referenceMap
            let resolver: @Sendable (Var<Model.ReferenceType>) -> Model.ReferenceType = { [referenceMap] varSymbol in
                guard let concreteRef = referenceMap[varSymbol] else {
                    // This indicates an error: the model tried to resolve a Var that
                    // hasn't been mapped yet by a previous command in this sequence.
                    fatalError("Resolver Error: No concrete reference found for symbolic Var \(varSymbol.id). Map contains: \(referenceMap.keys.map { $0.id })")
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
                currentModelState = nextModelState
                // Use the REAL resolver now
                let concreteCommand = Model.concretizeCommand(symbolicCommand, resolver: resolver)

                var actualResponseValue: Model.ResponseConcrete? = nil
                var realRunError: Error? = nil

                do {
                    actualResponseValue = try await Model.runReal(concreteCommand, sut: sutInstance)()
                } catch {
                    realRunError = error
                }

                // We need the sequence state *before* adding the current step for reporting errors
                let currentSequenceForErrorReporting = CommandSequence(
                    initialState: Model.initialState,
                    steps: executedSteps, // Steps up to (but not including) the current one
                    finalModelState: stateBeforeCommand // State before the failed/diverged command
                )

                if let error = realRunError {
                    // let message = ... (optional detailed message)
                    reporter.reportFinalCounterexample(description: propertyName + " (SUT Error)", input: currentSequenceForErrorReporting, error: error, file: file, line: line)
                    lastFailure = .falsified(value: currentSequenceForErrorReporting, error: error, shrinks: 0, seed: effectiveSeed)
                    // Continue to the next sequence when an error occurs in runReal
                    continue sequenceLoop
                }

                guard let unwrappedActualResponse = actualResponseValue else {
                    let criticalError = TestFailureError(message: "Critical Runner Error: Actual response is nil but no error was thrown by runReal.")
                    reporter.reportFinalCounterexample(description: propertyName + " (Runner Critical Error)", input: currentSequenceForErrorReporting, error: criticalError, file: file, line: line)
                    lastFailure = .falsified(value: currentSequenceForErrorReporting, error: criticalError, shrinks: 0, seed: effectiveSeed)
                    // Continue to the next sequence on critical runner error
                    continue sequenceLoop
                }
                
                // Use the REAL resolver for checking equivalence
                if !Model.areResponsesEquivalent(symbolicResponse: modelResponse, concreteResponse: unwrappedActualResponse, resolver: resolver) {
                    let divergenceError = TestFailureError(message: "Property '\(propertyName)' FALSIFIED (Seq \(sequenceIndex), Cmd \(cmdIndex)): Model-SUT Response Divergence. Cmd: \(concreteCommand), Model: \(modelResponse), SUT: \(unwrappedActualResponse)")
                    // Need to include the current step in the reported sequence for divergence
                    let sequenceWithDivergence = CommandSequence(
                         initialState: Model.initialState,
                         steps: executedSteps + [ExecutedCommand(symbolicCommand: symbolicCommand, concreteCommand: concreteCommand, modelResponse: modelResponse, actualResponse: unwrappedActualResponse, stateBefore: stateBeforeCommand, stateAfter: currentModelState)],
                         finalModelState: currentModelState
                     )
                    reporter.reportFinalCounterexample(description: propertyName + " (Divergence)", input: sequenceWithDivergence, error: divergenceError, file: file, line: line)
                    lastFailure = .falsified(value: sequenceWithDivergence, error: divergenceError, shrinks: 0, seed: effectiveSeed)
                    // Continue to the next sequence on divergence
                    continue sequenceLoop
                }

                // ---- Success Path for this Command ----
                // Extract and store new references
                let newReferences = Model.extractNewReferences(responseVar: modelResponse, responseConcrete: unwrappedActualResponse)
                referenceMap.merge(newReferences) { (current, _) in current } // Keep existing value on conflict (shouldn't happen with unique Vars)
                
                // Add the successful step to the list for this sequence
                let successfulStep = ExecutedCommand<Model>(
                    symbolicCommand: symbolicCommand,
                    concreteCommand: concreteCommand,
                    modelResponse: modelResponse,
                    actualResponse: unwrappedActualResponse,
                    stateBefore: stateBeforeCommand,
                    stateAfter: currentModelState
                )
                executedSteps.append(successfulStep)
                commandLoopIterations += 1
            }
        }
        
        // --- Sequence Completed Successfully (or aborted) --- 
        // Logging for sequence completion status
        if commandLoopIterations > 0 && preconditionFailuresInSequence <= maxPreconditionFailures {
             print("  [\(sequenceIndex)] Sequence completed successfully with \(commandLoopIterations) commands.")
        } else if preconditionFailuresInSequence > maxPreconditionFailures {
            // Aborted message already printed in the loop
        } else { // commandLoopIterations == 0
             print("  [\(sequenceIndex)] Sequence completed with no commands executed (possibly all preconditions failed or maxCommandsInSequence was 0).")
        }
    } // End of sequenceLoop

    // --- All Sequences Completed --- 
    if let failure = lastFailure {
        // A failure was found and reported in one of the sequences
        return failure
    }

    // No failures encountered in any sequence
    print("Stateful Test '\(propertyName)' PASSED after \(numberOfSequences) sequences (max \(maxCommandsInSequence) commands each).")
    reporter.reportSuccess(description: propertyName, iterations: numberOfSequences)
    return .succeeded(testsRun: numberOfSequences)
}