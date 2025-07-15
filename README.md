# SwiftQC

**SwiftQC** is a **Swift 6+** property-based testing library designed to unify concepts from QuickCheck, Hedgehog, and modern Swift testing into a single, cohesive framework.

It provides:
- Composable Generators (`Gen` via **PointFree's `swift-gen`**)
- Pluggable Shrinkers (`Shrinker`, `Sendable`) for minimal counterexamples
- An `Arbitrary` protocol (`Sendable`) tying types (`Value: Sendable`) to their default `(Gen, Shrinker)`
- A Property Runner (`forAll`) with automatic shrinking, seed handling, and seamless **Swift Testing issue integration**
- **Stateful testing** via `StateModel` protocol and `stateful()` runner with full sequence shrinking support ✅
- **Parallel testing** via `ParallelModel` protocol and `parallel()` runner (core functionality complete, advanced linearizability features TBD)

## Installation

### 📦 Library (Swift Package Manager)

Add SwiftQC to your project:

```swift
// Package.swift
.package(url: "https://github.com/sheldon-aristide/SwiftQC.git", from: "1.0.0"),
```

Or in Xcode: **File → Add Packages…** and enter the repository URL.

### 🔧 CLI Tool (Development Use)

⚠️ **Current Limitation**: CLI requires full Xcode due to Swift Testing dependencies.

```bash
# Clone and run locally (recommended for now)
git clone https://github.com/sheldon-aristide/SwiftQC.git
cd SwiftQC
swift run SwiftQCCLI --help
swift run SwiftQCCLI run --count 100
swift run SwiftQCCLI interactive
```

**Note**: We recommend using the library directly in your projects rather than the CLI for production use.

📋 **See [INSTALL.md](INSTALL.md) for detailed installation options and troubleshooting.**

## Quick Start

Import the library and write a property test in your test suite:

```swift
import SwiftQC
import Testing // Or XCTest

// In your test file (e.g., MyLibraryTests.swift)
@Test // Using Swift Testing syntax
func additionIsCommutative() async {
  // Test that integer addition is commutative
  await forAll("Int addition is commutative") { (a: Int, b: Int) in
    #expect(a + b == b + a)
    // Or using XCTest:
    // XCTAssertEqual(a + b, b + a)
  }
}

// --- Or using XCTest ---
// class MyLibraryTests: XCTestCase {
//   func testAdditionIsCommutative() async {
//     await forAll("Int addition is commutative") { (a: Int, b: Int) in
//       XCTAssertEqual(a + b, b + a)
//     }
//   }
// }
```

Run your tests using the standard command:

```bash
swift test
```

SwiftQC's `forAll` function will automatically generate random inputs, run your property, shrink failures to minimal examples, and report results (integrating with Swift Testing's issue system if used).

## Built-in Types Supporting `Arbitrary`

SwiftQC provides `Arbitrary` conformance for many standard Swift types out of the box:

- Numeric: `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`, `Float`, `Double`, `CGFloat`, `Decimal`
- Text: `Character`, `String`, `Unicode.Scalar`
- Boolean: `Bool`
- Data: `Data`, `UUID`
- Collections: `Array<T>`, `Dictionary<K, V>` (via `ArbitraryDictionary<K, V>`), `Set<T>`, `Optional<T>`, `Result<Success, Failure>`
- Time: `Date` (with reasonable ranges)

## Using `forAll`

SwiftQC provides several overloads of the `forAll` function for different testing scenarios.

### Single Input

For properties involving a single type conforming to `Arbitrary`:

```swift
import SwiftQC
import Testing

@Test
func stringReversalIdentity() async {
    await forAll("String reversal identity") { (s: String) in
        let reversed = String(s.reversed())
        let backToOriginal = String(reversed.reversed())
        #expect(backToOriginal == s)
    }
}
```

### Multiple Inputs (Tuples)

For properties involving multiple `Arbitrary` types, provide the types (`.self`) after the description:

```swift
@Test
func stringConcatenationLength() async {
    await forAll(
        "String concatenation preserves length", 
        String.self, String.self
    ) { (s1: String, s2: String) in
        let combined = s1 + s2
        #expect(combined.count == s1.count + s2.count)
    }
}
```

### Dictionary Inputs

A specialized overload handles `Dictionary` properties. You need to provide the `Arbitrary` types for the Key and Value. The Key's `Value` must be `Hashable`.

```swift
@Test
func dictionaryMerging() async {
    await forAll(
        "Dictionary merging combines entries", 
        String.self,   // Key type
        Int.self,      // Value type
        forDictionary: true
    ) { (dict: [String: Int]) in
        let emptyDict: [String: Int] = [:]
        let merged = dict.merging(emptyDict) { (current, _) in current }
        #expect(merged == dict)
    }
}
```

## Custom `Arbitrary` Types

You can make any type `Arbitrary` by implementing the protocol:

```swift
struct Point: Arbitrary, Sendable {
    let x: Int
    let y: Int
    
    typealias Value = Point
    
    static var gen: Gen<Point> {
        zip(Int.gen, Int.gen).map { Point(x: $0, y: $1) }
    }
    
    static var shrinker: any Shrinker<Point> {
        Shrinkers.map(
            from: Shrinkers.tuple(Int.shrinker, Int.shrinker),
            to: { Point(x: $0.0, y: $0.1) },
            from: { ($0.x, $0.y) }
        )
    }
}
```

See [Arbitrary.md](Docs/Arbitrary.md) for detailed instructions and examples.

## Examples

Explore **hands-on examples** in the [`Examples/` directory](Examples/):

- **[BasicUsage](Examples/BasicUsage/)** - Property testing fundamentals, custom types, shrinking
- **[StatefulExample](Examples/StatefulExample/)** - Testing state machines, command sequences  
- **[ParallelExample](Examples/ParallelExample/)** - Concurrent testing, race condition detection

Each example is a complete Swift package you can build and run:

```bash
cd Examples/BasicUsage && swift test
```

## Documentation

Explore the **`Docs/` directory** for comprehensive documentation:

- [GettingStarted.md](Docs/GettingStarted.md) - A complete guide to using SwiftQC
- [Arbitrary.md](Docs/Arbitrary.md) - Creating custom `Arbitrary` types
- [Generators.md](Docs/Generators.md) - Working with and composing generators
- [Shrinkers.md](Docs/Shrinkers.md) - Understanding shrinking for minimal counterexamples
- [Stateful.md](Docs/Stateful.md) - Testing stateful systems
- [Parallel.md](Docs/Parallel.md) - Testing concurrent systems
- [Integration.md](Docs/Integration.md) - Integration with Swift Testing

## License

SwiftQC is released under the MIT License. See [LICENSE](LICENSE) for details.
