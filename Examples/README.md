# SwiftQC Examples

This directory contains comprehensive examples demonstrating different aspects of property-based testing with SwiftQC. Each example is a standalone Swift package that you can build and run independently.

## 📁 Available Examples

### [BasicUsage](BasicUsage/) - Property Testing Fundamentals
**Perfect for beginners** - Learn the core concepts of property-based testing.

- **Basic properties**: Arithmetic, string, and collection operations
- **Custom `Arbitrary` types**: Creating testable custom data structures  
- **Multiple parameter testing**: Properties with multiple inputs
- **Dictionary testing**: Specialized dictionary property patterns
- **Shrinking demonstration**: Understanding minimal counterexamples

```bash
cd BasicUsage && swift test
```

**Key concepts**: `forAll`, `Arbitrary` protocol, generators, shrinkers

---

### [StatefulExample](StatefulExample/) - Testing Stateful Systems
**For testing systems that change over time** - Model complex stateful behavior.

- **Simple counter**: Basic state transitions
- **Stack (LIFO)**: Data structure with preconditions
- **Bank account**: Complex business logic with validation
- **Command sequences**: Testing operation sequences
- **Automatic shrinking**: Minimal failing command sequences

```bash
cd StatefulExample && swift test
```

**Key concepts**: `StateModel`, `Command` protocol, preconditions, postconditions

---

### [ParallelExample](ParallelExample/) - Concurrent System Testing
**For finding race conditions** - Test thread-safe implementations.

- **Actor-based counter**: Thread-safe by design
- **Concurrent set**: Safe collection operations
- **Cache with race conditions**: Demonstrating failure detection
- **Linearizability checking**: Verifying concurrent correctness
- **Race condition detection**: Finding concurrency bugs

```bash
cd ParallelExample && swift test
```

**Key concepts**: `ParallelModel`, `ParallelCommand`, linearizability, race detection

## 🚀 Quick Start

Choose your starting point based on your needs:

1. **New to property-based testing?** → Start with [BasicUsage](BasicUsage/)
2. **Testing APIs or state machines?** → Try [StatefulExample](StatefulExample/)  
3. **Working with concurrent code?** → Explore [ParallelExample](ParallelExample/)

## 🏗️ Building and Running

Each example is a complete Swift package with its own `Package.swift`:

```bash
# Run the example program (shows descriptions)
cd Examples/BasicUsage
swift run

# Run the property tests  
swift test

# Build without running
swift build
```

## 📚 Learning Path

### 1. Start with BasicUsage
- Understand `forAll` and basic properties
- Learn about `Arbitrary` types and generators
- See shrinking in action with failing tests
- Practice writing simple properties

### 2. Move to StatefulExample
- Model stateful systems with `StateModel`
- Create commands with preconditions and postconditions
- Test complex business logic
- Understand command sequence shrinking

### 3. Explore ParallelExample
- Test concurrent systems for race conditions
- Understand linearizability and consistency
- Learn to model parallel behavior
- Practice finding concurrency bugs

## 🧪 Property-Based Testing Benefits

These examples demonstrate how SwiftQC helps you:

- **Find edge cases** you wouldn't think to test manually
- **Test invariants** that should hold for all valid inputs
- **Automatically shrink** failing cases to minimal examples
- **Model complex behavior** with stateful and parallel testing
- **Increase confidence** through exhaustive random testing

## 🔧 Integration Patterns

The examples show different integration approaches:

- **Swift Testing**: Modern `@Test` functions with `#expect`
- **XCTest**: Traditional test classes (see docs for examples)
- **Standalone**: Command-line tools for exploration

## 📖 Further Reading

After working through these examples, explore:

- [Documentation](../Docs/) - Comprehensive guides for each feature
- [Source Code](../Sources/SwiftQC/) - Implementation details
- [Tests](../Tests/) - SwiftQC's own property-based tests

Each example includes detailed README files with step-by-step explanations and concepts to help you master property-based testing with SwiftQC.