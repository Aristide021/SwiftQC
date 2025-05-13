//
//  StateModel.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen

// MARK: - Helper Types for StateModel

public struct Var<ReferenceType: Sendable>: Hashable, Sendable { // Ensure ReferenceType is Sendable, make Var Sendable
    let id: Int
    public init(id: Int) { self.id = id }
}

public protocol Referenceable: Hashable, Sendable {} // Add Sendable

public struct PreconditionFailure: Error, Equatable, Sendable { // Make Sendable
    public var message: String?
    public init(message: String? = nil) { self.message = message }
}

public enum Either<Left: Sendable, Right: Sendable>: Sendable { // Add Sendable to Left, Right, and Either itself
    case left(Left)
    case right(Right)
}

// Add Equatable conformance back with Sendable constraints
extension Either: Equatable where Left: Equatable, Right: Equatable {}


// CommandMonad's result A will need to be Sendable if the monad is used across actor boundaries
// or if ResponseConcrete itself needs to be strictly Sendable.
// The closure itself should be @Sendable if it captures Sendable state or is passed across actors.
public typealias CommandMonad<A: Sendable> = @Sendable () async throws -> A


// MARK: - StateModel Protocol
// The protocol itself doesn't need to be Sendable, but its associated types will be constrained
// by the stateful runner.
public protocol StateModel {
    // Associated types - their Sendable conformance will be enforced by the stateful runner's generic constraints
    // e.g., Model.State: Sendable
    associatedtype State: Equatable // Add Sendable to concrete conforming types
    associatedtype ReferenceType: Referenceable // Referenceable is now Sendable

    associatedtype CommandVar // Add Sendable to concrete conforming types
    associatedtype ResponseVar // Add Sendable to concrete conforming types

    associatedtype CommandConcrete // Add Sendable to concrete conforming types
    associatedtype ResponseConcrete // Add Sendable to concrete conforming types

    associatedtype SUT // NEW: Associated type for the System Under Test

    static var initialState: State { get }

    static func generateCommand(_ state: State) -> Gen<CommandVar> // No external label for 'state'

    static func shrinkCommand(_ cmd: CommandVar, inState state: State) -> [CommandVar] // Original labels

    static func runFake(_ cmd: CommandVar, inState state: State) -> Either<PreconditionFailure, (State, ResponseVar)> // Original labels

    static func runReal(
        _ cmd: CommandConcrete,
        sut: SUT // Use the associated SUT type
    ) -> CommandMonad<ResponseConcrete>

    static func concretizeCommand(
        _ symbolicCmd: CommandVar,
        resolver: @Sendable (Var<ReferenceType>) -> ReferenceType
    ) -> CommandConcrete
    
    static func areResponsesEquivalent(
        symbolicResponse: ResponseVar,
        concreteResponse: ResponseConcrete,
        resolver: @Sendable (Var<ReferenceType>) -> ReferenceType
    ) -> Bool

    static func monitoring<PropValue: Sendable>( // Ensure PropValue is Sendable
        from: (oldState: State, newState: State),
        command: CommandConcrete,
        response: ResponseConcrete,
        property: Property<PropValue>
    ) -> Property<PropValue>

    // NEW: Extract symbol-to-concrete reference mappings from responses
    static func extractNewReferences(responseVar: ResponseVar, responseConcrete: ResponseConcrete) -> [Var<ReferenceType>: ReferenceType]
}

public extension StateModel {
    static func shrinkCommand(_ cmd: CommandVar, inState state: State) -> [CommandVar] { return [] } // Original labels

    // If Property<PropValue> is not Sendable, this default impl might cause issues
    // if a model tries to use it in a Sendable-constrained context.
    // For now, this is okay as long as Property is not assumed Sendable by the runner logic.
    static func monitoring<PropValue>(
        from: (oldState: State, newState: State),
        command: CommandConcrete,
        response: ResponseConcrete,
        property: Property<PropValue>
    ) -> Property<PropValue> {
        return property
    }

    // Default implementation for models that don't use references
    static func extractNewReferences(responseVar: ResponseVar, responseConcrete: ResponseConcrete) -> [Var<ReferenceType>: ReferenceType] {
        return [:]
    }
}