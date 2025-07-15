# Parallel Testing Example

This example demonstrates parallel property-based testing with SwiftQC, showing how to test concurrent systems for race conditions and consistency under parallel access.

## What You'll Learn

- How to model concurrent systems with the `ParallelModel` protocol
- Creating commands for parallel execution with the `ParallelCommand` protocol
- Testing thread-safe data structures and concurrent algorithms
- Detecting race conditions and atomicity violations
- Understanding linearizability in concurrent systems

## Running the Example

```bash
cd Examples/ParallelExample
swift run  # Shows example descriptions
swift test # Runs all parallel tests
```

## Examples Included

### 1. Thread-Safe Counter (Actor-based)
Tests an actor-based counter that should be thread-safe by design.

```swift
actor ThreadSafeCounter {
  private var value: Int = 0
  
  func increment() -> Int {
    value += 1
    return value
  }
}

await parallel(
  "Thread-safe counter maintains consistency",
  model: ThreadSafeCounterModel(),
  system: { ThreadSafeCounter() },
  commands: ThreadSafeCounterCommand.self,
  sequentialCount: 5,
  parallelCount: 10
)
```

### 2. Concurrent Set
Tests a thread-safe set implementation using Swift actors.

```swift
actor ConcurrentSet<Element> {
  private var elements: Set<Element> = []
  
  func insert(_ element: Element) -> Bool {
    let wasInserted = !elements.contains(element)
    elements.insert(element)
    return wasInserted
  }
}
```

### 3. Simple Cache (Potentially Buggy)
Demonstrates testing a cache implementation that may have race conditions.

```swift
class SimpleCache<Key, Value>: @unchecked Sendable {
  private var dictionary: [Key: Value] = [:]
  // This implementation is NOT thread-safe!
}
```

## Key Concepts

### ParallelModel Protocol
Models the expected behavior of concurrent operations:

```swift
struct ThreadSafeCounterModel: ParallelModel {
  typealias System = ThreadSafeCounter
  typealias State = Int
  typealias Result = Int
  
  let initialState: Int = 0
  
  func step(state: Int, command: ThreadSafeCounterCommand) -> (Int, Int) {
    // Returns (newState, expectedResult)
  }
}
```

### ParallelCommand Protocol
Defines operations that can be executed concurrently:

```swift
enum ThreadSafeCounterCommand: ParallelCommand {
  case increment
  case decrement
  case getValue
  
  func execute(system: ThreadSafeCounter) async -> Int {
    // Execute the command and return the result
  }
}
```

### Testing Phases

1. **Sequential Setup**: Executes a sequence of commands to establish initial state
2. **Parallel Execution**: Runs commands concurrently from multiple threads/tasks
3. **Linearizability Check**: Verifies that parallel results are consistent with some sequential ordering

## What Gets Tested

1. **Atomicity**: Operations complete without interference
2. **Consistency**: System state remains valid under concurrent access
3. **Linearizability**: Concurrent executions appear to occur in some sequential order
4. **Race Condition Detection**: Identifies when parallel access produces inconsistent results

## Expected Behavior

### Thread-Safe Examples (Should Pass)
- **Actor-based Counter**: Passes because Swift actors provide thread safety
- **Concurrent Set**: Passes because it uses actor isolation

### Potentially Buggy Examples (May Fail)
- **Simple Cache**: May fail due to race conditions in the non-thread-safe dictionary

## Understanding Failures

When a parallel test fails, it indicates:

1. **Race Condition**: Multiple threads interfered with each other
2. **Atomicity Violation**: An operation was interrupted mid-execution
3. **Inconsistent State**: The system reached a state impossible under sequential execution

SwiftQC will provide:
- The sequential prefix that set up the failing state
- The parallel commands that exposed the race condition
- The actual vs. expected results showing the inconsistency

## Real-World Applications

Use parallel testing for:
- Thread-safe data structures
- Concurrent algorithms
- Database operations
- Cache implementations
- Actor-based systems
- Lock-free data structures

This helps ensure your concurrent code behaves correctly under real-world parallel access patterns.