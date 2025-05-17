//
//  ParallelCommands.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/16/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

// File: Sources/SwiftQC/Parallel/ParallelCommands.swift

import Foundation // For Error

// ParallelEvent represents a single operation's model and SUT execution details.
public struct ParallelEvent<Model: ParallelModel>: Sendable where
    Model.State: Sendable,
    Model.CommandVar: Sendable,
    Model.CommandConcrete: Sendable,
    Model.ResponseVar: Sendable,
    Model.ResponseConcrete: Sendable,
    Model.ReferenceType: Sendable
{
    public let opId: Int // A unique identifier for the operation in the sequence
    public let virtualThreadId: Int // The virtual thread this operation was primarily associated with for model state
    public let symbolicCommand: Model.CommandVar
    public let concreteCommand: Model.CommandConcrete
    public let modelResponse: Model.ResponseVar // From runFake on the virtualThreadId's model state
    public let actualResponse: Model.ResponseConcrete? // From runReal (SUT)
    public let modelStateBefore: Model.State // Model state of virtualThreadId before this command
    public let modelStateAfter: Model.State  // Model state of virtualThreadId after this command (from runFake)
    public let sutError: Error?              // Error thrown by runReal

    public init(
        opId: Int,
        virtualThreadId: Int,
        symbolicCommand: Model.CommandVar,
        concreteCommand: Model.CommandConcrete,
        modelResponse: Model.ResponseVar,
        actualResponse: Model.ResponseConcrete?,
        modelStateBefore: Model.State,
        modelStateAfter: Model.State,
        sutError: Error?
    ) {
        self.opId = opId
        self.virtualThreadId = virtualThreadId
        self.symbolicCommand = symbolicCommand
        self.concreteCommand = concreteCommand
        self.modelResponse = modelResponse
        self.actualResponse = actualResponse
        self.modelStateBefore = modelStateBefore
        self.modelStateAfter = modelStateAfter
        self.sutError = sutError
    }
}

// ParallelExecutionResult holds the entire outcome of one parallel test run.
// This is the value passed to the user's property check and is the subject of shrinking.
public struct ParallelExecutionResult<Model: ParallelModel>: Sendable where
    Model.State: Sendable,
    Model.CommandVar: Sendable,
    Model.CommandConcrete: Sendable,
    Model.ResponseVar: Sendable,
    Model.ResponseConcrete: Sendable,
    Model.ReferenceType: Sendable
{
    public let initialModelStates: [Model.State] // Initial state of each virtual model thread
    public let events: [ParallelEvent<Model>]    // The history of executed events (may be interleaved)
    public let finalModelStates: [Model.State]   // Final state of each virtual model thread after all model ops
    public internal(set) var overallError: Error? // Any SUT error, divergence, or property error

    public init(
        initialModelStates: [Model.State],
        events: [ParallelEvent<Model>],
        finalModelStates: [Model.State],
        overallError: Error?
    ) {
        self.initialModelStates = initialModelStates
        self.events = events
        self.finalModelStates = finalModelStates
        self.overallError = overallError
    }
}

// Custom error for failures within the parallel runner itself or non-SUT failures.
public struct ParallelRunnerError: Error, CustomStringConvertible, Sendable, Equatable {
    public let message: String
    public var description: String { message }

    public init(message: String) { // Add public initializer
        self.message = message
    }

    public static func == (lhs: ParallelRunnerError, rhs: ParallelRunnerError) -> Bool { // Add Equatable conformance
        return lhs.message == rhs.message
    }
}