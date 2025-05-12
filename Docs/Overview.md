## Overview

**SwiftQC** is a **Swift 6+** property-based testing library designed to unify concepts from QuickCheck, Hedgehog, and modern Swift testing. It provides composable generators, pluggable shrinkers, **definitions for** stateful and parallel testing, and integration with Swift Testing.

### Core Concepts

-   **Generators (`Gen`)**: Defines how to produce random values, leveraging **PointFree's `swift-gen`**.
-   **Shrinkers (`Shrinker`)**: Defines how to produce "smaller" values for finding minimal counterexamples. Conforms to `Sendable`.
-   **Arbitrary (`Arbitrary`)**: A protocol (`Sendable`) that ties a type to its default generator and shrinker. Requires `associatedtype Value: Sendable`.
-   **Property Runner**: Executes property tests (`forAll`), handling generation, **seed management for reproducibility**, shrinking, and reporting.
-   **Stateful Testing (`StateModel`)**: Protocol definition for testing stateful systems using command sequences **(Runner implementation TBD)**.
-   **Parallel Testing (`ParallelModel`)**: Protocol definition extending `StateModel` for testing concurrent systems **(Runner implementation TBD)**.
-   **Swift Testing Integration**: The property runner directly integrates with Swift Testing's `Issue` system (`withKnownIssue`, `Issue.record`) for seamless issue suppression during shrinking and final failure reporting.

### Installation

Add the following dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/Aristide021/SwiftQC.git", .upToNextMajor(from: "1.0.0"))
```

Then import the necessary modules in your test file:

```swift
import SwiftQC
import Gen 
import Testing // Or XCTest
```