# SwiftQC: Modern Property-Based Testing for Swift

**SwiftQC** is a powerful **Swift 6+** property-based testing library. It draws inspiration from established frameworks like QuickCheck and Hedgehog, unifying their best ideas with modern Swift testing practices into a single, cohesive system.

SwiftQC empowers you to write more robust and reliable software by automatically generating a wide variety of test inputs, checking your code against specified properties, and helping you find minimal counterexamples when failures occur.

## Key Features

SwiftQC provides a comprehensive suite of tools for property-based testing:

1.  **Composable Generators (`Gen`):** Leverages the flexible and powerful **[PointFree's `swift-gen`](https://github.com/pointfreeco/swift-gen)** library for creating random data generators. SwiftQC re-exports `Gen` for your convenience.
2.  **Pluggable Shrinkers (`Shrinker`):** A core `Shrinker<Value>: Sendable` protocol allows types to define how failing inputs can be reduced to their simplest form, making debugging significantly easier.
3.  **Ergonomic `Arbitrary` Protocol:** A `Sendable` protocol that links a type (`associatedtype Value: Sendable`) to its default generator (`Gen`) and shrinker (`any Shrinker`). SwiftQC provides many built-in conformances for standard types.
4.  **Intelligent Property Runner (`forAll`):**
    *   Automatically drives the testing process.
    *   Handles random input generation using `Arbitrary` conformances or explicit `Gen` instances.
    *   Manages **deterministic seeding** for reproducible test failures.
    *   Performs automatic **shrinking** of inputs upon failure.
    *   Provides clear reporting of test outcomes.
5.  **Stateful Testing (`StateModel` & `stateful` Runner):**
    *   Includes a `StateModel` protocol for defining models of stateful systems.
    *   Provides a **`stateful` runner** that generates sequences of commands, executes them against a model and a system-under-test (SUT), and checks for behavioral consistency.
    *   Features complete sequence shrinking to find minimal failing command sequences.
6.  **Parallel Testing (`ParallelModel` & `parallel` Runner):**
    *   Defines a `ParallelModel` protocol that extends `StateModel` for testing concurrent systems.
    *   Provides a **`parallel` runner** with core concurrent execution, model-SUT divergence detection, and basic shrinking.
    *   *(Advanced linearizability checking and sophisticated concurrency analysis features are planned for future releases).*
7.  **Seamless Swift Testing Integration:**
    *   The property runner intelligently integrates with Swift Testing's `Issue` system. It uses `Testing.withKnownIssue` to suppress intermediate failures during shrinking and `Testing.Issue.record` to report only the final, minimal counterexample, ensuring clean and focused test reports.
8.  **Modern Swift Design:** Built with Swift 6+ features in mind, including a focus on `Sendable` for concurrency safety and `async/await` for asynchronous properties.

---

## Installation

Integrate SwiftQC into your project using Swift Package Manager.

1.  Add SwiftQC as a dependency in your `Package.swift` file:
    ```swift
    // Package.swift
    dependencies: [
        .package(url: "https://github.com/your-username/SwiftQC.git", .upToNextMajor(from: "1.0.0")) // TODO: Update with your actual repository URL
    ],
    ```

2.  Add `SwiftQC` to your test target's dependencies:
    ```swift
    // Package.swift
    targets: [
        .testTarget(
            name: "MyLibraryTests",
            dependencies: ["MyLibrary", "SwiftQC"] // Add "SwiftQC" here
        )
    ]
    ```

3.  In your test files, import the necessary modules:
    ```swift
    import SwiftQC
    import Gen      // Often useful for direct access to Gen<T> and its combinators
    import Testing  // If using the Swift Testing framework
    // import XCTest // Or if using XCTest
    ```

---

## Core Concepts at a Glance

*   **`Gen<Value>` (from `swift-gen`):** The foundation for describing how to generate random values. Composable using `map`, `flatMap`, `zip`, etc.
*   **`Shrinker<Value>`:** A protocol defining how to produce "smaller" or simpler versions of a `Value` to aid in debugging.
*   **`Arbitrary` Protocol:** Links a specific data type (its `Value`) to its default `Gen` and `Shrinker`. Conforming your types to `Arbitrary` makes them easily usable with `forAll`.
*   **`forAll` Function:** The main entry point for running property tests. It takes a property (a closure) and, for types conforming to `Arbitrary`, automatically handles generation and shrinking. Specialized overloads provide ergonomic support for multiple inputs (tuples) and dictionaries.
*   **`StateModel` Protocol & `stateful` Runner:** For testing systems whose behavior depends on a sequence of operations and internal state.
*   **`ParallelModel` Protocol & `parallel` Runner:** For testing concurrent systems with basic execution and divergence detection (advanced linearizability features TBD).

This overview should give you a good starting point. For more in-depth information on specific features, please refer to the other documents in the `Docs/` directory:

-   [GettingStarted.md](GettingStarted.md)
-   [Arbitrary.md](Arbitrary.md)
-   [Generators.md](Generators.md)
-   [Shrinkers.md](Shrinkers.md)
-   [Stateful.md](Stateful.md)
-   [Parallel.md](Parallel.md)
-   [Integration.md](Integration.md)
