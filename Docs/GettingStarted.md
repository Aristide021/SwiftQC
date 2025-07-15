# Getting Started with SwiftQC

This guide provides a quick introduction to using SwiftQC for property-based testing in your Swift projects. SwiftQC helps you write more robust tests by checking your code against a wide variety of randomly generated inputs and finding minimal counterexamples when failures occur.

## Installation

Add SwiftQC to your project's `Package.swift` dependencies:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Aristide021/SwiftQC.git", .upToNextMajor(from: "1.0.0")) // Replace with actual URL
]
```

Then, add `SwiftQC` to your test target's dependencies:
```swift
// Package.swift
targets: [
    .testTarget(
        name: "MyLibraryTests",
        dependencies: ["MyLibrary", "SwiftQC"]
    )
]
```
In Xcode, you can also use **File → Add Packages…** and enter the repository URL.

## Basic Usage

Import the necessary modules in your test file:

```swift
import SwiftQC
import Gen      // For direct access to Gen<T> and its combinators
import Testing  // If using Swift Testing
// import XCTest // If using XCTest
```

## Using `forAll` for Property Testing

The `forAll` function is the heart of SwiftQC. It automatically:

1.  **Generates** random inputs based on the types specified or their `Arbitrary` conformance.
2.  **Runs** your property closure with these generated inputs for a configurable number of iterations.
3.  **Shrinks** any failing input to find a simpler, minimal counterexample that still causes the failure.
4.  **Reports** success or the minimal failure, integrating with Swift Testing's issue system or allowing custom reporters.

### 1. Single Input Properties

If your property takes a single input type that conforms to `Arbitrary` (like most standard Swift types):

```swift
import SwiftQC
import Testing // Or XCTest

@Test // Swift Testing example
func integerIdentityProperty() async {
    await forAll("Integer identity: n + 0 == n") { (n: Int) in
        #expect(n + 0 == n)
        // Or using XCTest:
        // XCTAssertEqual(n + 0, n)
    }
}

@Test
func stringReversalIsItsOwnInverse() async {
    await forAll("String double reversal yields original") { (s: String) in
        #expect(String(s.reversed().reversed()) == s)
    }
}
```
SwiftQC will automatically use `Int.gen` and `Int.shrinker` (or `String.gen` and `String.shrinker`) from their `Arbitrary` conformances.

### 2. Multiple Input (Tuple) Properties

For properties with multiple inputs, provide the `Arbitrary`-conforming types (`.self`) after the description to help SwiftQC select the correct overload. SwiftQC supports ergonomic overloads for up to 5 tuple inputs.

```swift
@Test
func additionIsCommutative() async {
    await forAll(
        "Integer addition is commutative",
        Int.self,    // Type for 'a'
        Int.self     // Type for 'b'
    ) { (a: Int, b: Int) in
        #expect(a + b == b + a)
    }
}

@Test
func stringConcatenationLength() async {
    await forAll(
        "String concatenation length",
        String.self, // Type for s1
        String.self, // Type for s2
        String.self  // Type for s3
    ) { (s1: String, s2: String, s3: String) in
        let combined = s1 + s2 + s3
        #expect(combined.count == s1.count + s2.count + s3.count)
    }
}
```

### 3. Dictionary Properties

SwiftQC provides a specialized ergonomic `forAll` overload for testing properties involving `Dictionary` inputs. You need to specify the `Arbitrary`-conforming types for the Key and Value, and an additional `forDictionary: true` parameter to help with overload resolution. The Key's generated value (`K.Value`) must be `Hashable`.

```swift
@Test
func dictionaryContainsKeyAfterInsertion() async {
    // Assuming String and Int have Arbitrary conformances
    await forAll(
        "Dictionary contains key after insertion",
        String.self,  // Arbitrary type for Keys (String.Value is String, which is Hashable)
        Int.self,     // Arbitrary type for Values
        forDictionary: true
    ) { (initialDict: Dictionary<String, Int>) in
        // Generate an additional key-value pair to insert
        var rng = Xoshiro() // For local ad-hoc generation if needed
        let keyToInsert = String.gen.run(using: &rng)
        let valueToInsert = Int.gen.run(using: &rng)

        var modifiedDict = initialDict
        modifiedDict[keyToInsert] = valueToInsert
        #expect(modifiedDict[keyToInsert] == valueToInsert)
    }
}
```
Internally, this uses `ArbitraryDictionary<K, V>` to provide generation and shrinking for dictionaries.

## Conforming Custom Types to `Arbitrary`

To test properties with your own custom types, they must conform to the `Arbitrary` protocol. This involves providing a static generator (`gen`) and a static shrinker (`shrinker`).

```swift
import SwiftQC
import Gen // For zip, Gen.int etc.

struct Point: Sendable, Equatable { // Equatable is useful for assertions
    let x: Int
    let y: Int
}

extension Point: Arbitrary {
    // 1. Specify the type of value generated and shrunk
    typealias Value = Point

    // 2. Provide a generator
    static var gen: Gen<Point> {
        zip(Int.gen, Int.gen).map { xCoord, yCoord in
            Point(x: xCoord, y: yCoord)
        }
        // Shorter alternative: zip(Int.gen, Int.gen).map(Point.init)
    }

    // 3. Provide a shrinker
    static var shrinker: any Shrinker<Point> {
        // Use a tuple shrinker for (Int, Int) and map results back to Point
        // This assumes you have PairShrinker or a similar utility.
        PairShrinker(Int.shrinker, Int.shrinker).map(
            into: Point.init, // Constructor or closure: (Int, Int) -> Point
            from: { point in (point.x, point.y) } // Closure: Point -> (Int, Int)
        )
        // If you don't have a generic map for shrinkers,
        // you'd define a `struct PointShrinker: Shrinker { ... }`.
    }
}

// Now you can use Point in forAll:
@Test
func pointReflectionIsIdentity() async {
    await forAll("Point reflection is identity") { (p: Point) in
        let reflected = Point(x: -p.x, y: -p.y)
        let backToOriginal = Point(x: -reflected.x, y: -reflected.y)
        #expect(backToOriginal.x == p.x && backToOriginal.y == p.y)
    }
}
```
For more details and patterns, see [Arbitrary.md](Arbitrary.md).

## Controlling Test Parameters

You can customize `forAll` runs by specifying the `count` (number of successful iterations) and a `seed` (for reproducible results):

```swift
@Test
func controlledIntegerProperty() async {
    // Run with 1000 iterations instead of the default 100
    await forAll("Integer property with more iterations", count: 1000) { (n: Int) in
        #expect(n * 1 == n)
    }
    
    // Run with a specific seed for reproducibility.
    // If this test fails, running it again with seed 12345 will generate the exact same sequence of inputs.
    let mySeed: UInt64 = 12345
    await forAll(
        "Integer property with fixed seed",
        count: 100, // Count still applies
        seed: mySeed 
    ) { (n: Int) in
        #expect(n + n == 2 * n)
    }
}
```
The `seed` used for a run (whether user-provided or auto-generated) is reported upon test failure.

## Using with XCTest

SwiftQC works seamlessly with XCTest as well:

```swift
import XCTest
import SwiftQC
import Gen // Often needed for custom generators

class MyLibraryXCTests: XCTestCase {
    func testIntegerPropertiesWithXCTest() async {
        // Note: XCTest methods are not async by default unless you manage expectations.
        // For simplicity with async forAll, you might wrap XCTest calls.
        // Or ensure your property is not async if the XCTest method isn't.
        // Here, assuming forAll handles the async nature appropriately within XCTest.
        await forAll("Integer addition is commutative (XCTest)") { (a: Int, b: Int) in
            XCTAssertEqual(a + b, b + a)
        }
    }
}
```

## What to Explore Next

This guide covers the basics to get you started. To dive deeper into SwiftQC's capabilities, explore the `Docs/` directory:

-   **[Arbitrary.md](Arbitrary.md):** Detailed guide on making your custom types `Arbitrary`.
-   **[Generators.md](Generators.md):** Learn more about composing complex `Gen`erators using `swift-gen`.
-   **[Shrinkers.md](Shrinkers.md):** Understand the shrinking process and how to write effective shrinkers.
-   **[Stateful.md](Stateful.md):** Introduction to testing stateful systems (runner now implemented!).
-   **[Parallel.md](Parallel.md):** Overview of planned features for testing concurrent systems.
-   **[Integration.md](Integration.md):** Details on how SwiftQC integrates with Swift Testing's issue reporting.

Happy testing!
