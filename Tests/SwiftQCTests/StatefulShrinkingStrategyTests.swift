// Tests/SwiftQCTests/StatefulShrinkingStrategyTests.swift

import XCTest
@testable import SwiftQC // To access generateShrinkCandidates and other internal types if needed
import Gen             // If Gen is used by any helper models

// --- Mock/Dummy Types for Testing Shrinking Strategies ---


enum ShrinkTestCommand: String, Sendable, Hashable, CustomStringConvertible {
    case cmdA, cmdB, cmdC // cmdC can shrink
    case cmdX, cmdY, cmdZ // cmdZ can shrink
    case noShrinkCmd

    var description: String { self.rawValue }
}

struct DummySUT: Sendable {} // Dummy SUT, not strictly needed for command list shrinking

struct ShrinkTestModel: StateModel {
    typealias State = Int
    typealias ReferenceType = NoReference
    typealias CommandVar = ShrinkTestCommand
    typealias ResponseVar = Int // Dummy
    typealias CommandConcrete = ShrinkTestCommand
    typealias ResponseConcrete = Int
    typealias SUT = DummySUT

    static var initialState: State { 0 }

    // Not directly used by generateShrinkCandidates, but needed for model conformance
    static func generateCommand(_ state: State) -> Gen<CommandVar> { .always(.cmdA) }
    static func runFake(_ cmd: CommandVar, inState state: State) -> Either<PreconditionFailure, (State, ResponseVar)> { .right((state, 0)) }
    static func runReal(_ cmd: CommandConcrete, sut: SUT) -> CommandMonad<ResponseConcrete> { { 0 } }
    static func concretizeCommand(_ symbolicCmd: CommandVar, resolver: @Sendable (Var<NoReference>) -> NoReference) -> CommandConcrete { symbolicCmd }
    static func areResponsesEquivalent(symbolicResponse: ResponseVar, concreteResponse: ResponseConcrete, resolver: @Sendable (Var<NoReference>) -> NoReference) -> Bool { true }

    // This IS used by generateShrinkCandidates's "shrink individual command" strategy
    static func shrinkCommand(_ cmd: CommandVar, inState state: State) -> [CommandVar] {
        switch cmd {
        case .cmdC: return [.cmdA, .cmdB] // cmdC can shrink to cmdA or cmdB
        case .cmdZ: return [.cmdX, .cmdY]
        default: return [] // cmdA, cmdB, cmdX, cmdY, noShrinkCmd are minimal
        }
    }
}

// Helper to create a CommandSequence (steps part only contains symbolic commands for these tests)
// The `ExecutedCommand` details like responses, concrete commands are not relevant for testing
// the *generation of candidate symbolic command lists*.
func makeTestSequence(from commands: [ShrinkTestCommand]) -> CommandSequence<ShrinkTestModel> {
    var steps: [ExecutedCommand<ShrinkTestModel>] = []
    var currentState = ShrinkTestModel.initialState
    for cmd in commands {
        // Create dummy ExecutedCommand instances
        steps.append(ExecutedCommand(
            symbolicCommand: cmd,
            concreteCommand: cmd, // Dummy
            modelResponse: 0,     // Dummy
            actualResponse: 0,    // Dummy
            stateBefore: currentState,
            stateAfter: currentState + 1 // Dummy state transition
        ))
        currentState += 1
    }
    return CommandSequence<ShrinkTestModel>(
        initialState: ShrinkTestModel.initialState,
        steps: steps,
        finalModelState: currentState
    )
}


final class StatefulShrinkingStrategyTests: XCTestCase {

    // Helper to get just the symbolic command lists from candidates
    private func getSymbolicCommands(from candidates: [[ShrinkTestCommand]]) -> Set<[ShrinkTestCommand]> {
        return Set(candidates) // Assumes CommandVar is Hashable
    }
    
    // MARK: - Tests for `generateShrinkCandidates`

    func testGenerateShrinkCandidates_onEmptySequence_returnsEmpty() {
        let emptySequence = makeTestSequence(from: [])
        let candidates = generateShrinkCandidates(for: emptySequence, modelType: ShrinkTestModel.self)
        XCTAssertTrue(candidates.isEmpty, "Shrinking an empty sequence should produce no candidates.")
    }

    func testGenerateShrinkCandidates_removeOneStrategy() {
        let sequence = makeTestSequence(from: [.cmdA, .cmdB, .cmdC])
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        let symbolicCandidates = getSymbolicCommands(from: candidates)

        // Assertions for remove-one (other strategies like empty and shrink-individual also contribute)
        XCTAssertTrue(symbolicCandidates.contains([.cmdB, .cmdC]), "Should offer removing first element.")
        XCTAssertTrue(symbolicCandidates.contains([.cmdA, .cmdC]), "Should offer removing second element.")
        XCTAssertTrue(symbolicCandidates.contains([.cmdA, .cmdB]), "Should offer removing third element.")
    }

    func testGenerateShrinkCandidates_offersEmptySequence() {
        let sequence = makeTestSequence(from: [.cmdA, .cmdB])
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        let symbolicCandidates = getSymbolicCommands(from: candidates)
        XCTAssertTrue(symbolicCandidates.contains([]), "Should offer an empty sequence as a shrink candidate for non-empty sequences.")
    }
    
    func testGenerateShrinkCandidates_singleCommandSequence_offersEmptyAndShrunkCommand() {
        let sequence = makeTestSequence(from: [.cmdC]) // cmdC shrinks to cmdA, cmdB
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        let symbolicCandidates = getSymbolicCommands(from: candidates)

        XCTAssertTrue(symbolicCandidates.contains([]), "Shrinking single command should offer empty list.")
        XCTAssertTrue(symbolicCandidates.contains([.cmdA]), "Shrinking [.cmdC] should offer individual command shrink [.cmdA].")
        XCTAssertTrue(symbolicCandidates.contains([.cmdB]), "Shrinking [.cmdC] should offer individual command shrink [.cmdB].")
        XCTAssertEqual(symbolicCandidates.count, 3, "Should be 3 unique candidates: [], [cmdA], [cmdB]")
    }

    func testGenerateShrinkCandidates_shrinkIndividualCommandStrategy() {
        let sequence = makeTestSequence(from: [.cmdA, .cmdC, .noShrinkCmd]) // cmdC shrinks to cmdA or cmdB
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        let symbolicCandidates = getSymbolicCommands(from: candidates)

        // Candidates from shrinking cmdC at index 1
        XCTAssertTrue(symbolicCandidates.contains([.cmdA, .cmdA, .noShrinkCmd]), "Should offer sequence with cmdC shrunk to cmdA.")
        XCTAssertTrue(symbolicCandidates.contains([.cmdA, .cmdB, .noShrinkCmd]), "Should offer sequence with cmdC shrunk to cmdB.")

        // Ensure cmdA and noShrinkCmd (which don't shrink) don't produce individual command shrinks
        // by checking that no candidate sequence of length 3 was formed by ONLY changing cmdA or noShrinkCmd.
        let originalCmds = sequence.steps.map { $0.symbolicCommand }
        var foundUnexpectedShrink = false
        for candidate in symbolicCandidates where candidate.count == originalCmds.count {
            var diffCount = 0
            var modifiedOriginal = false
            for i in 0..<originalCmds.count {
                if originalCmds[i] != candidate[i] {
                    diffCount += 1
                    if i == 0 && originalCmds[i] == .cmdA { modifiedOriginal = true } // cmdA at index 0
                    if i == 2 && originalCmds[i] == .noShrinkCmd { modifiedOriginal = true } // noShrinkCmd at index 2
                }
            }
            if diffCount == 1 && modifiedOriginal { // Only one command changed, and it was one that shouldn't shrink
                foundUnexpectedShrink = true
                break
            }
        }
        XCTAssertFalse(foundUnexpectedShrink, "Minimal commands (.cmdA, .noShrinkCmd) should not produce individual shrink candidates that only change them.")
    }

    func testGenerateShrinkCandidates_combinesStrategiesAndSorts() {
        let sequence = makeTestSequence(from: [.cmdA, .cmdC]) // cmdC shrinks to cmdA, cmdB
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        
        let expectedSymbolicCandidates: Set<[ShrinkTestCommand]> = [
            [], [.cmdC], [.cmdA], [.cmdA, .cmdA], [.cmdA, .cmdB]
        ]
        XCTAssertEqual(Set(candidates), expectedSymbolicCandidates, "Combined strategies did not produce the expected set of unique candidates.")

        for i in 0..<(candidates.count - 1) {
            XCTAssertLessThanOrEqual(candidates[i].count, candidates[i+1].count, "Candidates should be sorted by length.")
        }
    }
    
    func testGenerateShrinkCandidates_noShrinkForMinimalCommands() {
        let sequence = makeTestSequence(from: [.cmdA, .cmdB]) // cmdA and cmdB don't shrink
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        let symbolicCandidates = getSymbolicCommands(from: candidates)
        
        let expectedSymbolicCandidates: Set<[ShrinkTestCommand]> = [
            [], [.cmdB], [.cmdA]
        ]
        XCTAssertEqual(symbolicCandidates, expectedSymbolicCandidates, "Should only offer structural shrinks if commands are minimal.")
    }

    // MARK: - Additional Tests for generateShrinkCandidates

    func testGenerateShrinkCandidates_longerSequence_allStrategies() {
        let sequence = makeTestSequence(from: [.cmdA, .cmdC, .cmdB, .cmdZ])
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        let symbolicCandidates = getSymbolicCommands(from: candidates)

        let expected: Set<[ShrinkTestCommand]> = [
            [], // Empty
            [.cmdC, .cmdB, .cmdZ], [.cmdA, .cmdB, .cmdZ], [.cmdA, .cmdC, .cmdZ], [.cmdA, .cmdC, .cmdB], // Remove one
            [.cmdA, .cmdA, .cmdB, .cmdZ], [.cmdA, .cmdB, .cmdB, .cmdZ], // Shrink C
            [.cmdA, .cmdC, .cmdB, .cmdX], [.cmdA, .cmdC, .cmdB, .cmdY]  // Shrink Z
        ]
        XCTAssertEqual(symbolicCandidates, expected, "Mismatch in expected candidates for longer sequence.")
    }

    func testGenerateShrinkCandidates_multipleShrinkableCommands() {
        let sequence = makeTestSequence(from: [.cmdC, .cmdZ])
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        let symbolicCandidates = getSymbolicCommands(from: candidates)

        let expected: Set<[ShrinkTestCommand]> = [
            [], [.cmdZ], [.cmdC],
            [.cmdA, .cmdZ], [.cmdB, .cmdZ],
            [.cmdC, .cmdX], [.cmdC, .cmdY]
        ]
        XCTAssertEqual(symbolicCandidates, expected)
    }

    func testGenerateShrinkCandidates_shrinkableAtStartAndEnd() {
        let sequence = makeTestSequence(from: [.cmdC, .cmdA, .cmdZ])
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        let symbolicCandidates = getSymbolicCommands(from: candidates)

        let expected: Set<[ShrinkTestCommand]> = [
            [], // Empty
            [.cmdA, .cmdZ], [.cmdC, .cmdZ], [.cmdC, .cmdA], // Remove one
            [.cmdA, .cmdA, .cmdZ], [.cmdB, .cmdA, .cmdZ], // Shrink C
            [.cmdC, .cmdA, .cmdX], [.cmdC, .cmdA, .cmdY]  // Shrink Z
        ]
        XCTAssertEqual(symbolicCandidates, expected)
    }

    func testGenerateShrinkCandidates_sequenceWithOnlyOneShrinkableCommand_longer() {
        let originalCmds: [ShrinkTestCommand] = [.cmdA, .cmdB, .cmdC, .cmdX, .cmdY]
        let sequence = makeTestSequence(from: originalCmds)
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        let symbolicCandidates = getSymbolicCommands(from: candidates)

        // Expected from remove-one (5 candidates) + empty (1 candidate)
        // + shrinking .cmdC (at index 2) to .cmdA and .cmdB (2 candidates)
        // Total = 5 + 1 + 2 = 8 unique candidates
        var expected = Set<[ShrinkTestCommand]>([[]])
        for i in 0..<originalCmds.count {
            var removed = originalCmds; removed.remove(at: i); expected.insert(removed)
        }
        expected.insert([.cmdA, .cmdB, .cmdA, .cmdX, .cmdY]) // .cmdC -> .cmdA
        expected.insert([.cmdA, .cmdB, .cmdB, .cmdX, .cmdY]) // .cmdC -> .cmdB
        
        XCTAssertEqual(symbolicCandidates, expected)
    }
    
    func testGenerateShrinkCandidates_outputSortingCheck_detailed() {
        let sequence = makeTestSequence(from: [.cmdC, .cmdA]) // .cmdC -> .cmdA, .cmdB
        let candidates = generateShrinkCandidates(for: sequence, modelType: ShrinkTestModel.self)
        
        // Expected (unsorted unique): [], [.cmdA], [.cmdC], [.cmdA, .cmdA], [.cmdB, .cmdA] (note: your previous expectation was [.cmdA,.cmdB])
        // Let's re-verify the shrink of .cmdC in [.cmdC, .cmdA]
        // Shrunk .cmdC (index 0) -> .cmdA or .cmdB
        //  -> [.cmdA, .cmdA]
        //  -> [.cmdB, .cmdA]

        let expectedSymbolicCandidates: Set<[ShrinkTestCommand]> = [
            [], [.cmdA], [.cmdC], [.cmdA, .cmdA], [.cmdB, .cmdA]
        ]
        XCTAssertEqual(Set(candidates), expectedSymbolicCandidates, "Combined strategies did not produce the expected set for sorting test.")

        if !candidates.isEmpty {
            XCTAssertEqual(candidates.first, [], "Empty sequence should be first if present and sorted by count.")
            var previousCount = candidates.first!.count
            for cand in candidates {
                XCTAssertLessThanOrEqual(previousCount, cand.count, "Candidates are not sorted by length.")
                previousCount = cand.count
            }
        }
    }

    // MARK: - Placeholders for New Strategies (Keep for future)
    // func testGenerateShrinkCandidates_halveStrategy() { /* ... */ }
    // func testGenerateShrinkCandidates_removeChunkStrategy() { /* ... */ }
}
