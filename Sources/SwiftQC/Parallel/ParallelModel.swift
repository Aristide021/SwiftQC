import Gen // For Gen
// StateModel and its helpers are in Sources/SwiftQC/Stateful/StateModel.swift

// MARK: - Helper Type for ParallelModel

/// A simple wrapper for synchronous operations, used by `ParallelModel`
/// to convert `CommandMonad` instances for thread-spawning.
public struct IO<A> {
    public let run: () throws -> A
    public init(_ run: @escaping () throws -> A) {
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
    static func runCommandMonad<A>(_ action: CommandMonad<A>) -> IO<A>
}

// Default implementation for shrinkParallelCommand to make it optional.
public extension ParallelModel {
    static func shrinkParallelCommand(_ states: [State], _ cmd: CommandVar) -> [CommandVar] {
        // Default behavior: try to use the sequential shrinker if available,
        // or return no shrinks if sequential shrinking isn't appropriate here.
        // For simplicity, we'll assume the first state is representative for sequential shrinking.
        if let firstState = states.first {
            return shrinkCommand(firstState, cmd) // Calls StateModel's shrinkCommand
        }
        return []
    }
}
