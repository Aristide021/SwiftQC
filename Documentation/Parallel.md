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

SwiftQC provides a `parallel` runner function for executing parallel property tests:

```swift
public func parallel<Model: ParallelModel, SUT_Runner>(
    _ propertyName: String,
    threads: Int = 2,
    forks: Int = 10,
    seed: UInt64? = nil,
    reporter: Reporter = ConsoleReporter(),
    file: StaticString = #file,
    line: UInt = #line,
    modelType: Model.Type,
    sutFactory: @escaping @Sendable () async -> SUT_Runner,
    _ property: @escaping (ParallelExecutionResult<Model>) async throws -> Void
) async -> TestResult<ParallelExecutionResult<Model>>
```

This runner:
- Generates `forks` operations to be executed concurrently across up to `threads` tasks
- Executes commands against both the model and the system under test (SUT) 
- Tracks execution history and detects model-SUT divergences
- Provides basic shrinking by removing operations from failing sequences
- Reports results via the standard `TestResult` type

### Current Implementation Status

**✅ Currently Implemented:**
- Complete `ParallelModel` protocol definition
- Working `parallel()` runner with concurrent task execution via `TaskGroup`
- Model-SUT divergence detection and error propagation  
- Basic shrinking (removing entire operations from failing sequences)
- Reference management for commands that create/return references
- Comprehensive tests coverage

**🚧 Advanced Features (TBD):**
- **Individual command shrinking**: Using `Model.shrinkParallelCommand()` to simplify individual commands within failing sequences
- **Linearizability verification**: Sophisticated analysis of concurrent execution histories to verify linearizability properties
- **Rose-tree interleaving analysis**: Advanced concurrent history analysis for complex race condition detection

The current implementation is suitable for many parallel testing scenarios, particularly:
- Testing thread-safe data structures
- Detecting basic race conditions and divergences
- Verifying that concurrent operations don't violate system invariants

### Example Usage

```swift
import SwiftQC
import Testing

// Define your ParallelModel for a thread-safe counter
struct CounterParallelModel: ParallelModel {
    typealias State = Int
    typealias ReferenceType = NoReference
    typealias CommandVar = CounterCommand
    typealias ResponseVar = CounterResponse
    typealias CommandConcrete = CounterCommand  
    typealias ResponseConcrete = CounterResponse
    typealias SUT = ThreadSafeCounter

    static var initialState: State { 0 }
    
    static func generateCommand(_ state: State) -> Gen<CommandVar> {
        Gen.element(of: [.increment, .getValue])
    }
    
    static func generateParallelCommand(_ states: [State]) -> Gen<CommandVar> {
        generateCommand(states.first ?? initialState)
    }
    
    // ... implement other required methods
}

@Test 
func testThreadSafeCounter() async {
    let result = await parallel(
        "Thread-safe counter operations",
        threads: 3,
        forks: 50,
        modelType: CounterParallelModel.self,
        sutFactory: { ThreadSafeCounter() }
    ) { executionResult in
        // Verify no SUT errors occurred
        #expect(executionResult.overallError == nil)
        
        // Additional invariant checks on the execution history
        let increments = executionResult.events.filter { $0.symbolicCommand == .increment }.count
        let finalStates = executionResult.finalModelStates
        #expect(finalStates.allSatisfy { $0 >= 0 && $0 <= increments })
    }
    
    // The test will automatically shrink any failures to minimal failing sequences
}
```
