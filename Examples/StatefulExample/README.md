# Stateful Testing Example

This example demonstrates stateful property-based testing with SwiftQC, showing how to test systems that maintain state through sequences of operations.

## What You'll Learn

- How to model stateful systems with the `StateModel` protocol
- Creating commands that modify system state with the `Command` protocol
- Using preconditions and postconditions to ensure valid test sequences
- Testing complex business logic with stateful properties
- Understanding command sequence shrinking

## Running the Example

```bash
cd Examples/StatefulExample
swift run  # Shows example descriptions
swift test # Runs all stateful tests
```

## Examples Included

### 1. Simple Counter
A basic counter with increment, decrement, add, and reset operations.

```swift
enum CounterCommand: Command {
  case increment
  case decrement
  case add(Int)
  case reset
}

await stateful(
  "Counter maintains consistency",
  model: CounterModel(),
  system: { Counter() },
  commands: CounterCommand.self,
  commandCount: 20
)
```

### 2. Stack (LIFO)
A stack data structure testing push/pop operations and LIFO behavior.

```swift
enum StackCommand<Element>: Command {
  case push(Element)
  case pop
  case clear
  
  func precondition(state: [Element]) -> Bool {
    switch self {
    case .pop:
      return !state.isEmpty // Can only pop from non-empty stack
    default:
      return true
    }
  }
}
```

### 3. Bank Account (Complex Business Logic)
A bank account with deposits, withdrawals, and account locking.

```swift
enum BankAccountCommand: Command {
  case deposit(Decimal)
  case withdraw(Decimal)
  case lock
  case unlock
  
  func precondition(state: BankAccountState) -> Bool {
    switch self {
    case .deposit(let amount), .withdraw(let amount):
      return amount > 0 && !state.isLocked
    case .withdraw(let amount):
      return state.balance >= amount // Sufficient funds
    default:
      return true
    }
  }
}
```

## Key Concepts

### StateModel Protocol
Defines the initial state and types for your system:

```swift
struct CounterModel: StateModel {
  typealias System = Counter
  typealias State = Int
  let initialState: Int = 0
}
```

### Command Protocol
Defines operations that can be performed on your system:

```swift
func precondition(state: State) -> Bool
func execute(system: System, state: State) async throws -> State
func postcondition(state: State, newState: State, system: System) async throws -> Bool
```

### Arbitrary Commands
Commands must be `Arbitrary` for random generation:

```swift
static var gen: Gen<CounterCommand> {
  frequency([
    (3, constant(.increment)),
    (3, constant(.decrement)),
    (2, Int.gen.map(CounterCommand.add)),
    (1, constant(.reset))
  ])
}
```

## What Gets Tested

1. **State Consistency**: The system state matches the model state after each command
2. **Precondition Validation**: Commands are only executed when preconditions are met
3. **Postcondition Verification**: System behavior matches expected outcomes
4. **Command Sequences**: Random sequences of valid commands maintain consistency
5. **Error Handling**: Invalid operations are handled correctly (bank account example)

## Expected Behavior

All tests should pass, demonstrating that:
- The counter correctly tracks its value through all operations
- The stack maintains LIFO order and size constraints
- The bank account enforces business rules (sufficient funds, account locking)

If a test fails, SwiftQC will automatically shrink the failing command sequence to the minimal example that reproduces the issue.