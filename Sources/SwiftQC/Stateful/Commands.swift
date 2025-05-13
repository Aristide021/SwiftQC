//
//  Commands.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

/// Represents a single step in a command sequence execution.
public struct ExecutedCommand<Model: StateModel>: Sendable where
    Model.CommandVar: Sendable,
    Model.CommandConcrete: Sendable,
    Model.ResponseVar: Sendable,
    Model.ResponseConcrete: Sendable,
    Model.State: Sendable
{
    public let symbolicCommand: Model.CommandVar
    public let concreteCommand: Model.CommandConcrete
    public let modelResponse: Model.ResponseVar
    public let actualResponse: Model.ResponseConcrete
    public let stateBefore: Model.State
    public let stateAfter: Model.State

    // Public initializer is needed if this struct is in a different module
    // than where it's initialized, or if default memberwise is not sufficient.
    // Let's add one for explicitness.
    public init(
        symbolicCommand: Model.CommandVar,
        concreteCommand: Model.CommandConcrete,
        modelResponse: Model.ResponseVar,
        actualResponse: Model.ResponseConcrete,
        stateBefore: Model.State,
        stateAfter: Model.State
    ) {
        self.symbolicCommand = symbolicCommand
        self.concreteCommand = concreteCommand
        self.modelResponse = modelResponse
        self.actualResponse = actualResponse
        self.stateBefore = stateBefore
        self.stateAfter = stateAfter
    }
}

/// Represents a sequence of executed commands.
public struct CommandSequence<Model: StateModel>: Sendable where
    Model.CommandVar: Sendable, // These constraints are inherited by ExecutedCommand
    Model.CommandConcrete: Sendable,
    Model.ResponseVar: Sendable,
    Model.ResponseConcrete: Sendable,
    Model.State: Sendable
{
    public let initialState: Model.State
    public let steps: [ExecutedCommand<Model>]
    public let finalModelState: Model.State

    // Add a public initializer here too for the same reasons.
    public init(
        initialState: Model.State,
        steps: [ExecutedCommand<Model>],
        finalModelState: Model.State
    ) {
        self.initialState = initialState
        self.steps = steps
        self.finalModelState = finalModelState
    }
}