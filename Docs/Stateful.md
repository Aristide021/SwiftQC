## Stateful Testing

SwiftQC provides a framework for stateful property-based testing, modeled after approaches like Quviq. This allows you to test systems that maintain state over time by generating sequences of commands and verifying that applying these commands to a real system yields results consistent with a simplified model (the "fake" model).

### The `StateModel` Protocol

The core of stateful testing is the `StateModel` protocol. You define a type that conforms to this protocol to model the behavior of the system under test.

```swift
public protocol StateModel {
    associatedtype State: Equatable
    associatedtype ReferenceType: Referenceable

    associatedtype CommandVar   // Command with symbolic references (Var<ReferenceType>)
    associatedtype ResponseVar  // Response with symbolic references (Var<ReferenceType>)

    associatedtype CommandConcrete // Command with concrete references (ReferenceType)
    associatedtype ResponseConcrete // Response with concrete references (ReferenceType)

    static var initialState: State { get }

    static func generateCommand(_ state: State) -> Gen<CommandVar>

    static func shrinkCommand(_ state: State, _ cmd: CommandVar) -> [CommandVar]

    static func runFake(
        _ cmd: CommandVar,
        _ state: State
    ) -> Either<PreconditionFailure, (State, ResponseVar)>

    static func runReal(
        _ cmd: CommandConcrete
    ) -> CommandMonad<ResponseConcrete>

    static func concretizeCommand(
        _ symbolicCmd: CommandVar,
        resolver: (Var<ReferenceType>) -> ReferenceType
    ) -> CommandConcrete
    
    static func areResponsesEquivalent(
        symbolicResponse: ResponseVar,
        concreteResponse: ResponseConcrete,
        resolver: (Var<ReferenceType>) -> ReferenceType
    ) -> Bool

    static func monitoring<PropValue>(
        from: (oldState: State, newState: State),
        command: CommandConcrete,
        response: ResponseConcrete,
        property: Property<PropValue>
    ) -> Property<PropValue>
}
```

Key components you need to provide:

-   `State`: The type representing your model's state.
-   `ReferenceType`: A type used for modeling references within your commands and responses.
-   `CommandVar` / `CommandConcrete`: Types for commands using symbolic (`Var<ReferenceType>`) and concrete (`ReferenceType`) references, respectively.
-   `ResponseVar` / `ResponseConcrete`: Types for responses using symbolic and concrete references.
-   `initialState`: The starting state of your model.
-   `generateCommand`: A generator for producing the next command given the current state.
-   `shrinkCommand`: (Optional) A function to shrink individual commands.
-   `runFake`: Executes a command on your *model* state and returns the new state and a symbolic response, or a precondition failure.
-   `runReal`: Executes a command on the *actual system under test* and returns a concrete response within a `CommandMonad` (typically an `async` closure).
-   `concretizeCommand`: Converts a symbolic command to a concrete one using a resolver for references.
-   `areResponsesEquivalent`: Compares a symbolic response from `runFake` with a concrete response from `runReal`, considering reference mapping.
-   `monitoring`: (Optional) Allows for tracking coverage or classification based on state transitions, commands, and responses.

### Running Stateful Tests

The documentation describes a `stateful` runner function:

```swift
public func stateful<T: StateModel>(
  _ propertyName: String,
  count: Int = 100,
  file: StaticString = #file, line: UInt = #line,
  _ property: @escaping (Commands<T>) async throws -> Void // Note: Commands<T> represents the generated command sequence
) async
```

**Note:** Based on the current codebase analysis, the implementation of the `stateful` runner and the underlying execution logic in `StatefulRunner.swift` appear to be incomplete or minimal. While the `StateModel` protocol is defined, the full stateful testing workflow driven by this runner might not be fully functional yet.

To use stateful testing when the runner is complete, you would typically define your `StateModel` and then call the `stateful` function, providing a property closure that executes the generated command sequence (represented by `Commands<T>`) against your system under test.
