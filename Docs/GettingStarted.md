# Getting Started with SwiftQC

This guide will help you get started with SwiftQC for property-based testing in Swift.

## Installation

Add SwiftQC to your project via Swift Package Manager:

```swift
// Package.swift
.package(url: "https://github.com/your-repo/SwiftQC.git", .upToNextMajor(from: "1.0.0"))
```

Or in Xcode: **File → Add Packages…** and enter the repository URL.

## Basic Usage

Import the necessary modules in your test file:

```swift
import SwiftQC
import Gen  // Gen is re-exported but often useful to import directly
import Testing  // Or XCTest if not using Swift Testing
```

## Using `forAll` for Property Testing

The `forAll` function is the primary way to run property tests in SwiftQC. It automatically:
- Generates random values of the specified types
- Runs your property with those values
- Shrinks inputs if any failures are found
- Reports concise results

### Single Input Properties

For properties involving a single input type that conforms to `Arbitrary`:

```swift
@Test
func intIdentity() async {
    await forAll("Integer identity property") { (n: Int) in
        #expect(n + 0 == n)  // Using Swift Testing
        // Or: XCTAssertEqual(n + 0, n)  // Using XCTest
    }
}

@Test
func stringReversalIdentity() async {
    await forAll("String reversal identity") { (s: String) in
        let reversed = String(s.reversed())
        let backToOriginal = String(reversed.reversed())
        #expect(backToOriginal == s)
    }
}
```

### Multiple Input (Tuple) Properties

For properties involving multiple inputs, provide the types (`.self`) after the description:

```swift
@Test
func additiveCommutativity() async {
    await forAll("Integer addition is commutative", Int.self, Int.self) { (a: Int, b: Int) in
        #expect(a + b == b + a)
    }
}

@Test
func stringConcatenationLength() async {
    await forAll(
        "String concatenation preserves length", 
        String.self, String.self, String.self
    ) { (s1: String, s2: String, s3: String) in
        let combined = s1 + s2 + s3
        #expect(combined.count == s1.count + s2.count + s3.count)
    }
}
```

### Dictionary Properties

A specialized overload handles `Dictionary` properties:

```swift
@Test
func dictionaryMerging() async {
    await forAll(
        "Dictionary merging combines entries", 
        String.self,  // Key type
        Int.self,     // Value type
        forDictionary: true
    ) { (dict1: [String: Int]) in
        // Generate a second dictionary using the same parameters
        let dict2 = ArbitraryDictionary<String, Int>.gen.run()
        
        let merged = dict1.merging(dict2) { (current, _) in current }
        
        #expect(merged.count <= dict1.count + dict2.count)
        for (key, value) in dict1 {
            #expect(merged[key] == value)
        }
    }
}

// You can also create custom Arbitrary types for specialized dictionaries
struct EvenIntArbitrary: Arbitrary, Sendable {
    typealias Value = Int
    static var gen: Gen<Int> { Int.gen.map { $0 * 2 } }
    static var shrinker: any Shrinker<Int> { Shrinkers.int.map { $0 & ~1 } } // Ensure even
}

@Test
func dictionaryWithCustomValues() async {
    await forAll(
        "Dictionary with even integer values", 
        String.self, 
        EvenIntArbitrary.self, 
        forDictionary: true
    ) { (dict: [String: Int]) in
        for value in dict.values {
            #expect(value % 2 == 0)
        }
    }
}
```

## Working with Custom Types

For custom types, implement the `Arbitrary` protocol (see [Arbitrary.md](Arbitrary.md) for details):

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

@Test
func pointProperties() async {
    await forAll("Point reflection property") { (p: Point) in
        let reflected = Point(x: -p.x, y: -p.y)
        let backToOriginal = Point(x: -reflected.x, y: -reflected.y)
        #expect(backToOriginal.x == p.x)
        #expect(backToOriginal.y == p.y)
    }
}
```

## Controlling Test Parameters

You can control test parameters like iterations count and seed:

```swift
@Test
func intPropertyWithControlledParams() async {
    // Run with 500 iterations instead of the default
    await forAll("Integer property with more iterations", count: 500) { (n: Int) in
        #expect(n * 1 == n)
    }
    
    // Run with a specific seed for reproducibility
    await forAll(
        "Integer property with fixed seed",
        count: 100,
        withSeed: 12345
    ) { (n: Int) in
        #expect(n + n == 2 * n)
    }
}
```

## Using with XCTest

If you're using XCTest instead of Swift Testing:

```swift
import XCTest
import SwiftQC

class MyPropertyTests: XCTestCase {
    func testIntegerProperties() async {
        await forAll("Integer addition is commutative") { (a: Int, b: Int) in
            XCTAssertEqual(a + b, b + a)
        }
    }
}
```

## What to Explore Next

Explore the `Docs/` directory for more detailed information:
- [Arbitrary.md](Arbitrary.md) - Implementing custom Arbitrary types
- [Shrinkers.md](Shrinkers.md) - Understanding the shrinking process
- [Generators.md](Generators.md) - Composing complex generators
- [Stateful.md](Stateful.md) - Stateful testing techniques
- [Parallel.md](Parallel.md) - Parallel testing capabilities
- [Integration.md](Integration.md) - Swift Testing integration details
