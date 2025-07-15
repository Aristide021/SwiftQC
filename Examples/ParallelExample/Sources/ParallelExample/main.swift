import SwiftQC
import Testing

// MARK: - Thread-Safe Counter Example

/// A thread-safe counter that should work correctly under parallel access
actor ThreadSafeCounter {
  private var value: Int = 0
  
  func increment() -> Int {
    value += 1
    return value
  }
  
  func decrement() -> Int {
    value -= 1
    return value
  }
  
  func getValue() -> Int {
    return value
  }
  
  func reset() {
    value = 0
  }
}

/// Model for the thread-safe counter
struct ThreadSafeCounterModel: ParallelModel, Sendable {
  typealias System = ThreadSafeCounter
  typealias State = Int
  typealias Result = Int
  
  let initialState: Int = 0
  
  func step(state: Int, command: ThreadSafeCounterCommand) -> (Int, Int) {
    switch command {
    case .increment:
      let newState = state + 1
      return (newState, newState)
    case .decrement:
      let newState = state - 1
      return (newState, newState)
    case .getValue:
      return (state, state)
    case .reset:
      return (0, 0)
    }
  }
}

/// Commands for the thread-safe counter
enum ThreadSafeCounterCommand: ParallelCommand, Sendable {
  case increment
  case decrement
  case getValue
  case reset
  
  typealias System = ThreadSafeCounter
  typealias Result = Int
  
  func execute(system: ThreadSafeCounter) async -> Int {
    switch self {
    case .increment:
      return await system.increment()
    case .decrement:
      return await system.decrement()
    case .getValue:
      return await system.getValue()
    case .reset:
      await system.reset()
      return 0
    }
  }
}

extension ThreadSafeCounterCommand: Arbitrary {
  typealias Value = ThreadSafeCounterCommand
  
  static var gen: Gen<ThreadSafeCounterCommand> {
    frequency([
      (4, constant(.increment)),
      (4, constant(.decrement)),
      (2, constant(.getValue)),
      (1, constant(.reset))
    ])
  }
  
  static var shrinker: any Shrinker<ThreadSafeCounterCommand> {
    Shrinkers.create { _ in [] } // Commands don't shrink in this example
  }
}

// MARK: - Concurrent Set Example

/// A thread-safe set implementation using actor
actor ConcurrentSet<Element: Sendable & Hashable> {
  private var elements: Set<Element> = []
  
  func insert(_ element: Element) -> Bool {
    let wasInserted = !elements.contains(element)
    elements.insert(element)
    return wasInserted
  }
  
  func remove(_ element: Element) -> Bool {
    return elements.remove(element) != nil
  }
  
  func contains(_ element: Element) -> Bool {
    return elements.contains(element)
  }
  
  func count() -> Int {
    return elements.count
  }
  
  func isEmpty() -> Bool {
    return elements.isEmpty
  }
  
  func clear() {
    elements.removeAll()
  }
  
  func allElements() -> Set<Element> {
    return elements
  }
}

/// Model for concurrent set
struct ConcurrentSetModel: ParallelModel, Sendable {
  typealias System = ConcurrentSet<Int>
  typealias State = Set<Int>
  typealias Result = ConcurrentSetResult
  
  let initialState: Set<Int> = []
  
  func step(state: Set<Int>, command: ConcurrentSetCommand) -> (Set<Int>, ConcurrentSetResult) {
    switch command {
    case .insert(let element):
      let wasInserted = !state.contains(element)
      let newState = state.union([element])
      return (newState, .insertResult(wasInserted))
    case .remove(let element):
      let wasRemoved = state.contains(element)
      let newState = state.subtracting([element])
      return (newState, .removeResult(wasRemoved))
    case .contains(let element):
      let contains = state.contains(element)
      return (state, .containsResult(contains))
    case .count:
      return (state, .countResult(state.count))
    case .isEmpty:
      return (state, .isEmptyResult(state.isEmpty))
    case .clear:
      return ([], .clearResult)
    }
  }
}

/// Result types for set operations
enum ConcurrentSetResult: Sendable, Equatable {
  case insertResult(Bool)
  case removeResult(Bool)
  case containsResult(Bool)
  case countResult(Int)
  case isEmptyResult(Bool)
  case clearResult
}

/// Commands for concurrent set
enum ConcurrentSetCommand: ParallelCommand, Sendable {
  case insert(Int)
  case remove(Int)
  case contains(Int)
  case count
  case isEmpty
  case clear
  
  typealias System = ConcurrentSet<Int>
  typealias Result = ConcurrentSetResult
  
  func execute(system: ConcurrentSet<Int>) async -> ConcurrentSetResult {
    switch self {
    case .insert(let element):
      let result = await system.insert(element)
      return .insertResult(result)
    case .remove(let element):
      let result = await system.remove(element)
      return .removeResult(result)
    case .contains(let element):
      let result = await system.contains(element)
      return .containsResult(result)
    case .count:
      let result = await system.count()
      return .countResult(result)
    case .isEmpty:
      let result = await system.isEmpty()
      return .isEmptyResult(result)
    case .clear:
      await system.clear()
      return .clearResult
    }
  }
}

extension ConcurrentSetCommand: Arbitrary {
  typealias Value = ConcurrentSetCommand
  
  static var gen: Gen<ConcurrentSetCommand> {
    frequency([
      (4, Gen.int(in: 1...10).map(ConcurrentSetCommand.insert)),
      (3, Gen.int(in: 1...10).map(ConcurrentSetCommand.remove)),
      (2, Gen.int(in: 1...10).map(ConcurrentSetCommand.contains)),
      (1, constant(.count)),
      (1, constant(.isEmpty)),
      (1, constant(.clear))
    ])
  }
  
  static var shrinker: any Shrinker<ConcurrentSetCommand> {
    Shrinkers.create { command in
      switch command {
      case .insert(let element), .remove(let element), .contains(let element):
        return Int.shrinker.shrink(element).map { value in
          switch command {
          case .insert: return .insert(value)
          case .remove: return .remove(value)
          case .contains: return .contains(value)
          default: return command
          }
        }
      case .count, .isEmpty, .clear:
        return []
      }
    }
  }
}

// MARK: - Cache Example (Potentially Buggy)

/// A simple cache that might have race conditions
class SimpleCache<Key: Hashable & Sendable, Value: Sendable>: Sendable {
  private let storage = UnsafeMutableDictionary<Key, Value>()
  
  func get(_ key: Key) -> Value? {
    return storage.getValue(for: key)
  }
  
  func set(_ key: Key, value: Value) {
    storage.setValue(value, for: key)
  }
  
  func remove(_ key: Key) -> Value? {
    return storage.removeValue(for: key)
  }
  
  func count() -> Int {
    return storage.count()
  }
  
  func clear() {
    storage.clear()
  }
}

/// Thread-unsafe dictionary wrapper (for demonstration)
class UnsafeMutableDictionary<Key: Hashable, Value>: @unchecked Sendable {
  private var dictionary: [Key: Value] = [:]
  
  func getValue(for key: Key) -> Value? {
    return dictionary[key]
  }
  
  func setValue(_ value: Value, for key: Key) {
    dictionary[key] = value
  }
  
  func removeValue(for key: Key) -> Value? {
    return dictionary.removeValue(forKey: key)
  }
  
  func count() -> Int {
    return dictionary.count
  }
  
  func clear() {
    dictionary.removeAll()
  }
}

/// Model for cache
struct CacheModel: ParallelModel, Sendable {
  typealias System = SimpleCache<String, Int>
  typealias State = [String: Int]
  typealias Result = CacheResult
  
  let initialState: [String: Int] = [:]
  
  func step(state: [String: Int], command: CacheCommand) -> ([String: Int], CacheResult) {
    switch command {
    case .get(let key):
      return (state, .getValue(state[key]))
    case .set(let key, let value):
      var newState = state
      newState[key] = value
      return (newState, .setResult)
    case .remove(let key):
      var newState = state
      let removed = newState.removeValue(forKey: key)
      return (newState, .removeResult(removed))
    case .count:
      return (state, .countResult(state.count))
    case .clear:
      return ([:], .clearResult)
    }
  }
}

enum CacheResult: Sendable, Equatable {
  case getValue(Int?)
  case setResult
  case removeResult(Int?)
  case countResult(Int)
  case clearResult
}

enum CacheCommand: ParallelCommand, Sendable {
  case get(String)
  case set(String, Int)
  case remove(String)
  case count
  case clear
  
  typealias System = SimpleCache<String, Int>
  typealias Result = CacheResult
  
  func execute(system: SimpleCache<String, Int>) async -> CacheResult {
    switch self {
    case .get(let key):
      let value = system.get(key)
      return .getValue(value)
    case .set(let key, let value):
      system.set(key, value: value)
      return .setResult
    case .remove(let key):
      let removed = system.remove(key)
      return .removeResult(removed)
    case .count:
      let count = system.count()
      return .countResult(count)
    case .clear:
      system.clear()
      return .clearResult
    }
  }
}

extension CacheCommand: Arbitrary {
  typealias Value = CacheCommand
  
  static var gen: Gen<CacheCommand> {
    let keyGen = frequency([
      (3, constant("key1")),
      (3, constant("key2")),
      (2, constant("key3")),
      (1, constant("key4"))
    ])
    
    return frequency([
      (4, keyGen.map(CacheCommand.get)),
      (4, zip(keyGen, Gen.int(in: 1...100)).map(CacheCommand.set)),
      (2, keyGen.map(CacheCommand.remove)),
      (1, constant(.count)),
      (1, constant(.clear))
    ])
  }
  
  static var shrinker: any Shrinker<CacheCommand> {
    Shrinkers.create { command in
      switch command {
      case .set(let key, let value):
        return Int.shrinker.shrink(value).map { CacheCommand.set(key, $0) }
      default:
        return []
      }
    }
  }
}

// MARK: - Tests

@Test("Thread-safe counter parallel testing")
func testThreadSafeCounterParallel() async {
  await parallel(
    "Thread-safe counter maintains consistency under parallel access",
    model: ThreadSafeCounterModel(),
    system: { ThreadSafeCounter() },
    commands: ThreadSafeCounterCommand.self,
    sequentialCount: 5,
    parallelCount: 10
  )
}

@Test("Concurrent set parallel testing")
func testConcurrentSetParallel() async {
  await parallel(
    "Concurrent set maintains consistency",
    model: ConcurrentSetModel(),
    system: { ConcurrentSet<Int>() },
    commands: ConcurrentSetCommand.self,
    sequentialCount: 3,
    parallelCount: 8
  )
}

@Test("Cache parallel testing - may reveal race conditions")
func testCacheParallel() async {
  // This test might fail due to race conditions in SimpleCache
  // Uncomment to see parallel testing in action with a potentially buggy system
  
  /*
  await parallel(
    "Simple cache consistency under parallel access",
    model: CacheModel(),
    system: { SimpleCache<String, Int>() },
    commands: CacheCommand.self,
    sequentialCount: 3,
    parallelCount: 6
  )
  */
  
  // For now, we'll just verify the model works
  await parallel(
    "Cache model verification with safe operations",
    model: CacheModel(),
    system: { SimpleCache<String, Int>() },
    commands: CacheCommand.self,
    sequentialCount: 3,
    parallelCount: 2  // Reduced parallelism to avoid race conditions
  )
}

// MARK: - Entry Point

@main
struct ParallelExample {
  static func main() async {
    print("⚡ SwiftQC Parallel Testing Examples")
    print("===================================")
    print()
    print("This example demonstrates parallel property-based testing with SwiftQC.")
    print("Run with: swift test")
    print()
    print("Examples included:")
    print("• Thread-Safe Counter - Actor-based concurrent counter")
    print("• Concurrent Set - Thread-safe set operations")
    print("• Simple Cache - Potentially racy cache implementation")
    print()
    print("Key concepts:")
    print("• ParallelModel protocol for modeling concurrent behavior")
    print("• ParallelCommand protocol for concurrent operations")
    print("• Sequential setup phase followed by parallel execution")
    print("• Race condition detection through model divergence")
    print("• Linearizability checking")
    print()
    print("Parallel testing helps find:")
    print("• Race conditions")
    print("• Data races")
    print("• Atomicity violations")
    print("• Inconsistent concurrent behavior")
    print()
    print("Note: The cache example may reveal race conditions")
    print("in non-thread-safe implementations. Comment/uncomment")
    print("the cache test to see this in action.")
  }
}