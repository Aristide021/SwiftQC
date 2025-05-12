import Gen

// MARK: - Helper Types for StateModel

public struct Var<ReferenceType>: Hashable {
    let id: Int
    public init(id: Int) { self.id = id }
}

public protocol Referenceable: Hashable {}

public struct PreconditionFailure: Error, Equatable {
    public var message: String?
    public init(message: String? = nil) { self.message = message }
}

public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}
extension Either: Equatable where Left: Equatable, Right: Equatable {}

// The Property type is defined in Sources/SwiftQC/Core/Property.swift
// public typealias Property = Any // Placeholder -- REMOVED

public typealias CommandMonad<A> = () async throws -> A

// MARK: - StateModel Protocol
public protocol StateModel {
    associatedtype State: Equatable
    associatedtype ReferenceType: Referenceable

    // Command and Response types are parameterized by the reference type (Var or Concrete)
    // Since associated types cannot be directly generic, we define specific versions.
    // Users will typically define a generic type like `MyCommand<Ref>` and then alias:
    // typealias CommandVar = MyCommand<Var<MyReference>>
    // typealias CommandConcrete = MyCommand<MyReference>
    associatedtype CommandVar
    associatedtype ResponseVar

    associatedtype CommandConcrete
    associatedtype ResponseConcrete

    static var initialState: State { get }

    static func generateCommand(_ state: State) -> Gen<CommandVar>

    static func shrinkCommand(_ state: State, _ cmd: CommandVar) -> [CommandVar]

    static func runFake(
        _ cmd: CommandVar,
        _ state: State
    ) -> Either<PreconditionFailure, (State, ResponseVar)>

    static func runReal(
        _ cmd: CommandConcrete // Takes the concrete command
    ) -> CommandMonad<ResponseConcrete> // Returns the concrete response

    // This function is crucial for bridging symbolic and concrete commands.
    // It's up to the StateModel implementer to define this transformation.
    static func concretizeCommand(
        _ symbolicCmd: CommandVar,
        resolver: (Var<ReferenceType>) -> ReferenceType
    ) -> CommandConcrete
    
    // This function is crucial for comparing symbolic and concrete responses.
    static func areResponsesEquivalent(
        symbolicResponse: ResponseVar,
        concreteResponse: ResponseConcrete,
        resolver: (Var<ReferenceType>) -> ReferenceType
    ) -> Bool


    static func monitoring<PropValue>(
        from: (oldState: State, newState: State), // State from runFake
        command: CommandConcrete, // Concrete command that was run
        response: ResponseConcrete, // Concrete response from runReal
        property: Property<PropValue>
    ) -> Property<PropValue>
}

public extension StateModel {
    static func shrinkCommand(_ state: State, _ cmd: CommandVar) -> [CommandVar] {
        return []
    }

    static func monitoring<PropValue>(
        from: (oldState: State, newState: State),
        command: CommandConcrete,
        response: ResponseConcrete,
        property: Property<PropValue>
    ) -> Property<PropValue> {
        return property
    }
}
