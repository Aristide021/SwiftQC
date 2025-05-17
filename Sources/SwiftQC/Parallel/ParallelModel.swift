import Gen

// IO struct should be public if used across modules, and A should be Sendable if IO instances are passed around.
public struct IO<A: Sendable> { // Made A Sendable here
    public let run: @Sendable () async throws -> A // run is async and Sendable
    public init(_ run: @escaping @Sendable () async throws -> A) { // init takes an async and Sendable closure
        self.run = run
    }
}

// MARK: - ParallelModel Protocol

/// A protocol that extends `StateModel` for testing concurrent systems.
///
/// `ParallelModel` allows generating commands that can be run in parallel across
/// multiple threads or tasks, and includes mechanisms for checking linearizability.
///
/// Conforming types must ensure their `State` (from `StateModel`) is `Comparable`
/// to support certain parallel testing algorithms (e.g., state comparison in histories).
public protocol ParallelModel: StateModel where State: Comparable {
    // Note: `CommandVar` and `ReferenceType` are inherited from `StateModel`.

    /// Generates a command that can be executed in parallel.
    /// This command might operate on or be chosen based on multiple current states
    /// if the parallel model involves several independent or semi-independent state machines.
    ///
    /// - Parameter states: An array of current states from parallel execution branches.
    /// - Returns: A generator for a symbolic command (`CommandVar`).
    static func generateParallelCommand(_ states: [State]) -> Gen<CommandVar>

    /// Optionally shrinks a parallel command.
    ///
    /// - Parameters:
    ///   - states: An array of current states from parallel execution branches.
    ///   - cmd: The symbolic command (`CommandVar`) to shrink.
    /// - Returns: An array of "smaller" symbolic commands.
    static func shrinkParallelCommand(_ states: [State], _ cmd: CommandVar) -> [CommandVar]

    /// Converts a `CommandMonad` (typically an asynchronous operation) into an `IO` action
    /// (typically a synchronous operation or one suited for specific concurrent executors).
    /// This is used by the parallel test runner to manage execution of commands.
    ///
    /// - Parameter action: The `CommandMonad` to convert.
    /// - Returns: An `IO` action.
    static func runCommandMonad<A: Sendable>(_ action: @escaping CommandMonad<A>) -> IO<A> // ADDED @escaping here
}

// Default implementation for shrinkParallelCommand to make it optional.
public extension ParallelModel {
    static func shrinkParallelCommand(_ states: [State], _ cmd: CommandVar) -> [CommandVar] {
        // Default behavior: try to use the sequential shrinker if available,
        // or return no shrinks if sequential shrinking isn't appropriate here.
        // For simplicity, we'll assume the first state is representative for sequential shrinking.
        if let firstState = states.first {
            return shrinkCommand(cmd, inState: firstState)
        } else {
            // If states is empty, perhaps return an empty array or handle as appropriate
            // For now, consistent with original potentially empty shrinkCommand from StateModel if firstState is nil
            return [] 
        }
    }
    
    // Default implementation for extractNewReferences if not overridden by conforming types
    static func extractNewReferences(responseVar: ResponseVar, responseConcrete: ResponseConcrete) -> [Var<ReferenceType>: ReferenceType] {
        return [:]
    }
}
