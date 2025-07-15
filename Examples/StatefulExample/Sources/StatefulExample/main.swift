import SwiftQC
import Testing

// MARK: - Simple Counter Example

/// A simple counter that we want to test
actor Counter {
  private var value: Int = 0
  
  func increment() {
    value += 1
  }
  
  func decrement() {
    value -= 1
  }
  
  func add(_ amount: Int) {
    value += amount
  }
  
  func getValue() -> Int {
    return value
  }
  
  func reset() {
    value = 0
  }
}

/// Model representing the expected state of our counter
struct CounterModel: StateModel, Sendable {
  typealias System = Counter
  typealias State = Int
  
  let initialState: Int = 0
}

/// Commands for testing the counter
enum CounterCommand: Command, Sendable {
  case increment
  case decrement
  case add(Int)
  case reset
  
  typealias System = Counter
  typealias State = Int
  
  func precondition(state: Int) -> Bool {
    // All commands are always valid for our simple counter
    return true
  }
  
  func execute(system: Counter, state: Int) async throws -> Int {
    switch self {
    case .increment:
      await system.increment()
      return state + 1
    case .decrement:
      await system.decrement()
      return state - 1
    case .add(let amount):
      await system.add(amount)
      return state + amount
    case .reset:
      await system.reset()
      return 0
    }
  }
  
  func postcondition(state: Int, newState: Int, system: Counter) async throws -> Bool {
    let actualValue = await system.getValue()
    return actualValue == newState
  }
}

// Make CounterCommand Arbitrary for random generation
extension CounterCommand: Arbitrary {
  typealias Value = CounterCommand
  
  static var gen: Gen<CounterCommand> {
    frequency([
      (3, constant(.increment)),
      (3, constant(.decrement)),
      (2, Int.gen.map(CounterCommand.add)),
      (1, constant(.reset))
    ])
  }
  
  static var shrinker: any Shrinker<CounterCommand> {
    Shrinkers.create { command in
      switch command {
      case .increment, .decrement, .reset:
        return []
      case .add(let amount):
        return Int.shrinker.shrink(amount).map(CounterCommand.add)
      }
    }
  }
}

// MARK: - Stack Example (More Complex)

/// A simple stack implementation to test
actor Stack<Element: Sendable> {
  private var elements: [Element] = []
  
  func push(_ element: Element) {
    elements.append(element)
  }
  
  func pop() -> Element? {
    return elements.popLast()
  }
  
  func peek() -> Element? {
    return elements.last
  }
  
  func isEmpty() -> Bool {
    return elements.isEmpty
  }
  
  func count() -> Int {
    return elements.count
  }
  
  func clear() {
    elements.removeAll()
  }
}

/// Model for the stack
struct StackModel<Element: Sendable>: StateModel, Sendable {
  typealias System = Stack<Element>
  typealias State = [Element]
  
  let initialState: [Element] = []
}

/// Commands for testing the stack
enum StackCommand<Element: Sendable & Arbitrary>: Command, Sendable {
  case push(Element)
  case pop
  case clear
  
  typealias System = Stack<Element>
  typealias State = [Element]
  
  func precondition(state: [Element]) -> Bool {
    switch self {
    case .push:
      return true
    case .pop:
      return !state.isEmpty // Can only pop if stack is not empty
    case .clear:
      return true
    }
  }
  
  func execute(system: Stack<Element>, state: [Element]) async throws -> [Element] {
    switch self {
    case .push(let element):
      await system.push(element)
      return state + [element]
    case .pop:
      let popped = await system.pop()
      assert(popped == state.last, "Popped element should match model")
      return Array(state.dropLast())
    case .clear:
      await system.clear()
      return []
    }
  }
  
  func postcondition(state: [Element], newState: [Element], system: Stack<Element>) async throws -> Bool {
    let actualCount = await system.count()
    let actualIsEmpty = await system.isEmpty()
    let actualPeek = await system.peek()
    
    return actualCount == newState.count &&
           actualIsEmpty == newState.isEmpty &&
           actualPeek == newState.last
  }
}

// Make StackCommand Arbitrary for Int stacks
extension StackCommand: Arbitrary where Element == Int {
  typealias Value = StackCommand<Int>
  
  static var gen: Gen<StackCommand<Int>> {
    frequency([
      (4, Int.gen.map(StackCommand.push)),
      (2, constant(.pop)),
      (1, constant(.clear))
    ])
  }
  
  static var shrinker: any Shrinker<StackCommand<Int>> {
    Shrinkers.create { command in
      switch command {
      case .push(let element):
        return Int.shrinker.shrink(element).map(StackCommand.push)
      case .pop, .clear:
        return []
      }
    }
  }
}

// MARK: - Tests

@Test("Counter stateful testing")
func testCounterStateful() async {
  await stateful(
    "Counter maintains consistency through operations",
    model: CounterModel(),
    system: { Counter() },
    commands: CounterCommand.self,
    commandCount: 20
  )
}

@Test("Stack stateful testing")
func testStackStateful() async {
  await stateful(
    "Stack maintains LIFO property",
    model: StackModel<Int>(),
    system: { Stack<Int>() },
    commands: StackCommand<Int>.self,
    commandCount: 15
  )
}

// MARK: - Advanced Example: Bank Account

actor BankAccount {
  private var balance: Decimal
  private var isLocked: Bool = false
  
  init(initialBalance: Decimal = 0) {
    self.balance = initialBalance
  }
  
  func deposit(_ amount: Decimal) throws {
    guard !isLocked else { throw BankError.accountLocked }
    guard amount > 0 else { throw BankError.invalidAmount }
    balance += amount
  }
  
  func withdraw(_ amount: Decimal) throws {
    guard !isLocked else { throw BankError.accountLocked }
    guard amount > 0 else { throw BankError.invalidAmount }
    guard balance >= amount else { throw BankError.insufficientFunds }
    balance -= amount
  }
  
  func getBalance() -> Decimal {
    return balance
  }
  
  func lock() {
    isLocked = true
  }
  
  func unlock() {
    isLocked = false
  }
  
  func isAccountLocked() -> Bool {
    return isLocked
  }
}

enum BankError: Error, Sendable {
  case accountLocked
  case invalidAmount
  case insufficientFunds
}

struct BankAccountState: Sendable {
  let balance: Decimal
  let isLocked: Bool
  
  init(balance: Decimal = 0, isLocked: Bool = false) {
    self.balance = balance
    self.isLocked = isLocked
  }
}

struct BankAccountModel: StateModel, Sendable {
  typealias System = BankAccount
  typealias State = BankAccountState
  
  let initialState = BankAccountState()
}

enum BankAccountCommand: Command, Sendable {
  case deposit(Decimal)
  case withdraw(Decimal)
  case lock
  case unlock
  
  typealias System = BankAccount
  typealias State = BankAccountState
  
  func precondition(state: BankAccountState) -> Bool {
    switch self {
    case .deposit(let amount), .withdraw(let amount):
      return amount > 0 && !state.isLocked
    case .lock:
      return !state.isLocked
    case .unlock:
      return state.isLocked
    }
  }
  
  func execute(system: BankAccount, state: BankAccountState) async throws -> BankAccountState {
    switch self {
    case .deposit(let amount):
      try await system.deposit(amount)
      return BankAccountState(balance: state.balance + amount, isLocked: state.isLocked)
    case .withdraw(let amount):
      try await system.withdraw(amount)
      return BankAccountState(balance: state.balance - amount, isLocked: state.isLocked)
    case .lock:
      await system.lock()
      return BankAccountState(balance: state.balance, isLocked: true)
    case .unlock:
      await system.unlock()
      return BankAccountState(balance: state.balance, isLocked: false)
    }
  }
  
  func postcondition(state: BankAccountState, newState: BankAccountState, system: BankAccount) async throws -> Bool {
    let actualBalance = await system.getBalance()
    let actualLocked = await system.isAccountLocked()
    
    return actualBalance == newState.balance && actualLocked == newState.isLocked
  }
}

extension BankAccountCommand: Arbitrary {
  typealias Value = BankAccountCommand
  
  static var gen: Gen<BankAccountCommand> {
    frequency([
      (3, Decimal.gen.map(BankAccountCommand.deposit)),
      (3, Decimal.gen.map(BankAccountCommand.withdraw)),
      (1, constant(.lock)),
      (1, constant(.unlock))
    ])
  }
  
  static var shrinker: any Shrinker<BankAccountCommand> {
    Shrinkers.create { command in
      switch command {
      case .deposit(let amount), .withdraw(let amount):
        return Decimal.shrinker.shrink(amount).map { amount in
          switch command {
          case .deposit: return .deposit(amount)
          case .withdraw: return .withdraw(amount)
          default: return command
          }
        }
      case .lock, .unlock:
        return []
      }
    }
  }
}

@Test("Bank account stateful testing")
func testBankAccountStateful() async {
  await stateful(
    "Bank account maintains balance consistency and respects locking",
    model: BankAccountModel(),
    system: { BankAccount(initialBalance: 100) },
    commands: BankAccountCommand.self,
    commandCount: 25
  )
}

// MARK: - Entry Point

@main
struct StatefulExample {
  static func main() async {
    print("🏛️ SwiftQC Stateful Testing Examples")
    print("===================================")
    print()
    print("This example demonstrates stateful property-based testing with SwiftQC.")
    print("Run with: swift test")
    print()
    print("Examples included:")
    print("• Simple Counter - Basic increment/decrement operations")
    print("• Stack - LIFO data structure with push/pop operations")
    print("• Bank Account - Complex business logic with validation")
    print()
    print("Each example tests that the system under test (SUT)")
    print("maintains consistency with a model through sequences")
    print("of randomly generated commands.")
    print()
    print("Key concepts:")
    print("• StateModel protocol for modeling expected behavior")
    print("• Command protocol for operations on the system")
    print("• Preconditions to ensure valid commands")
    print("• Postconditions to verify state consistency")
    print("• Automatic shrinking of failing command sequences")
  }
}