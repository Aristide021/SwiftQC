## Parallel Testing

SwiftQC extends its stateful testing capabilities to support **Parallel Testing** for concurrent systems. This involves generating groups of commands (forks) that can be executed concurrently and checking for properties like linearizability.

### The `ParallelModel` Protocol

To perform parallel testing, your state model should conform to the `ParallelModel` protocol, which extends the `StateModel` protocol:

```swift
public protocol ParallelModel: StateModel where State: Comparable {
    static func generateParallelCommand(_ states: [State]) -> Gen<CommandVar>
    static func shrinkParallelCommand(_ states: [State], _ cmd: CommandVar) -> [CommandVar]
    static func runCommandMonad<A>(_ action: CommandMonad<A>) -> IO<A>
}
```

In addition to the requirements of `StateModel`, `ParallelModel` adds:

-   `State: Comparable`: Your state type must be comparable, which is often required for algorithms used in checking properties of concurrent execution histories (like linearizability).
-   `generateParallelCommand(_ states: [State])`: Generates a command given an array of current states, useful when command generation depends on the state of multiple concurrent threads or processes.
-   `shrinkParallelCommand(_ states: [State], _ cmd: CommandVar) -> [CommandVar]`: (Optional) Provides a way to shrink commands in the context of parallel states.
-   `runCommandMonad<A>(_ action: CommandMonad<A>) -> IO<A>`: Converts the asynchronous `CommandMonad` into a synchronous `IO` type that can be managed by the parallel test runner for concurrent execution.

### Running Parallel Tests

The documentation describes a `parallel` runner function for executing parallel property tests:

```swift
public func parallel<T: ParallelModel>(
  _ description: String,
  threads: Int = 2,
  forks: Int = 10,
  file: StaticString = #file, line: UInt = #line,
  _ property: @escaping (ParallelCommands<T>) async throws -> Void // Note: ParallelCommands<T> represents the generated command forks
) async
```

This runner is intended to generate `forks` groups of commands, potentially executing them across `threads`, and then checking the specified `property`, which often involves verifying the concurrent execution history.

**Note:** Based on the current codebase analysis (`Sources/SwiftQC/Parallel/ParallelRunner.swift`), the implementation for the `parallel` runner function appears to be commented out or incomplete. While the `ParallelModel` protocol is defined, the full parallel testing workflow driven by this runner might not be fully functional yet.
