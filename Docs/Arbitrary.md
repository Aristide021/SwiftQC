# Arbitrary Protocol

The `Arbitrary` protocol is a cornerstone of SwiftQC. It provides a standardized way for types to define how random instances should be **generated** and how failing test cases involving these instances should be **shrunk** to find minimal counterexamples. This allows SwiftQC's `forAll` runner to seamlessly work with any conforming type.

## Protocol Definition

The `Arbitrary` protocol is simple yet powerful:

```swift
public protocol Arbitrary: Sendable {
    /// The specific type of value that will be generated and shrunk.
    /// This type must also be `Sendable`.
    associatedtype Value: Sendable
    
    /// A `Gen<Value>` (from the `swift-gen` library) that produces
    /// random instances of `Self.Value`.
    static var gen: Gen<Self.Value> { get }
    
    /// An `any Shrinker<Self.Value>` that provides a strategy for
    /// creating "smaller" or simpler instances of `Self.Value`
    /// from a failing one.
    static var shrinker: any Shrinker<Self.Value> { get }
}
```

**Key Requirements:**

1.  **`Sendable` Conformance:** The `Arbitrary` type itself must be `Sendable`.
2.  **`associatedtype Value: Sendable`:** The actual values generated and shrunk must be `Sendable`.
3.  **`static var gen: Gen<Self.Value>`:** A static generator for the associated `Value` type.
4.  **`static var shrinker: any Shrinker<Self.Value>`:** A static, type-erased shrinker for the associated `Value` type.

## Built-in Arbitrary Conformances

SwiftQC provides `Arbitrary` conformances for a wide range of standard Swift and Foundation types out-of-the-box, making it easy to start writing property tests immediately:

*   **Numeric Types:**
    *   Integers: `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `UInt8`, `UInt16`, `UInt32`, `UInt64`.
        *(Note: `UInt` currently does not have a direct conformance; use a fixed-width unsigned integer like `UInt64` instead.)*
    *   Floating-Point: `Float`, `Double`.
    *   Platform-Specific: `CGFloat` (where available).
    *   Special: `Decimal`.
*   **Textual Types:**
    *   `String`
    *   `Character`
    *   `Unicode.Scalar`
*   **Boolean Type:**
    *   `Bool`
*   **Opaque/Identifier Types:**
    *   `UUID`
    *   `Data`
*   **Date & Time:**
    *   `Date` (generates dates within a reasonable range around the present).
    *   `DateComponents` (generates with optional, plausible component values).
*   **Standard Collections & Structures:**
    *   `Array<Element>` (where `Element: Arbitrary`)
    *   `ContiguousArray<Element>` (where `Element: Arbitrary` and `Element.Value: Hashable` for the default shrinker)
    *   `Set<Element>` (where `Element: Arbitrary` and `Element.Value: Hashable`)
    *   `Dictionary<Key, Value>` (provided via the `ArbitraryDictionary<KeyArbitraryType, ValueArbitraryType>` wrapper, where `KeyArbitraryType: Arbitrary`, `KeyArbitraryType.Value: Hashable`, and `ValueArbitraryType: Arbitrary`).
    *   `Optional<Wrapped>` (where `Wrapped: Arbitrary`)
    *   `Result<Success, Failure>` (where `Success: Arbitrary`, `Failure: Arbitrary`, and `Failure.Value: Error`)
    *   `Range<Bound>` (where `Bound: Arbitrary`, `Bound.Value: Comparable & Hashable & Strideable`, and `Bound.Value.Stride: SignedInteger`)
    *   `ClosedRange<Bound>` (where `Bound: Arbitrary`, `Bound.Value: Comparable & Hashable & Strideable`, and `Bound.Value.Stride: SignedInteger`)
    *   Tuples (up to 5 elements, e.g., `(T1, T2)`, provided via `Tuple2<T1, T2>` wrapper where `T1, T2: Arbitrary`)
*   **Other:**
    *   `Void` (or `()`, provided via `VoidWrapper`).

## Conforming Your Custom Types

Making your own types `Arbitrary` is straightforward. Here are common patterns:

### 1. Simple Structs (Composed of Arbitrary Types)

If your struct is composed of fields that are already `Arbitrary`:

```swift
import SwiftQC
import Gen // For zip and other Gen combinators

struct Point: Sendable, Equatable { // Equatable often useful for testing
    let x: Int
    let y: Int
}

extension Point: Arbitrary {
    typealias Value = Point // Self.Value is Point

    static var gen: Gen<Point> {
        // Zip the generators of the components and map to the initializer
        zip(Int.gen, Int.gen).map { xCoord, yCoord in
            Point(x: xCoord, y: yCoord)
        }
        // Shorter: zip(Int.gen, Int.gen).map(Point.init)
    }

    static var shrinker: any Shrinker<Point> {
        // Use a tuple shrinker for the components and map back to Point
        // Assuming PairShrinker exists and is accessible, e.g., via Shrinkers.pair
        PairShrinker(Int.shrinker, Int.shrinker).map(
            into: Point.init, // (Int, Int) -> Point
            from: { point in (point.x, point.y) } // Point -> (Int, Int)
        )
        // If a generic `Shrinkers.map` or specific tuple shrinkers aren't available,
        // you might write a custom struct `PointShrinker: Shrinker`.
    }
}
```

### 2. Enums

Use `Gen.frequency` for weighted generation of cases or `Gen.one(of:)` for equal probability. Shrinking typically involves trying simpler cases or shrinking associated values.

```swift
import SwiftQC
import Gen

enum UserAction: Sendable, Equatable {
    case tap(x: Int, y: Int)
    case swipe(direction: String)
    case idle
}

extension UserAction: Arbitrary {
    typealias Value = UserAction

    static var gen: Gen<UserAction> {
        Gen.frequency([
            (3, zip(Int.gen(in: 0...1024), Int.gen(in: 0...768)).map(UserAction.tap)),
            (2, Gen.element(of: ["up", "down", "left", "right"]).compactMap { $0 }.map(UserAction.swipe)),
            (1, Gen.always(UserAction.idle))
        ])
    }

    static var shrinker: any Shrinker<UserAction> {
        // Define a custom shrinker struct for enums
        struct UserActionShrinker: Shrinker {
            func shrink(_ value: UserAction) -> [UserAction] {
                var shrinks: [UserAction] = []
                // Always try to shrink to the simplest case first
                if value != .idle {
                    shrinks.append(.idle)
                }

                switch value {
                case .tap(let x, let y):
                    // Shrink associated values
                    for sx in Int.shrinker.shrink(x) { shrinks.append(.tap(x: sx, y: y)) }
                    for sy in Int.shrinker.shrink(y) { shrinks.append(.tap(x: x, y: sy)) }
                    // Could also shrink to a simpler version of tap, e.g., .tap(x:0, y:0)
                    if x != 0 || y != 0 { shrinks.append(.tap(x:0, y:0)) }
                case .swipe(let direction):
                    // Shrink associated value (String)
                    for sd in String.shrinker.shrink(direction) {
                        // Ensure shrunk direction is still valid if there are constraints
                        if ["up", "down", "left", "right"].contains(sd) || sd.isEmpty {
                            shrinks.append(.swipe(direction: sd))
                        }
                    }
                    // Offer a default swipe direction if current is not it
                    if direction != "up" { shrinks.append(.swipe(direction: "up"))}
                case .idle:
                    break // Simplest case, no further shrinks
                }
                return Array(Set(shrinks.filter { $0 != value })) // Deduplicate
            }
        }
        return UserActionShrinker()
    }
}
```

### 3. Controlling Generation with Custom `Gen`

Sometimes you need finer control over the generated values, perhaps to ensure they meet certain preconditions for your tests.

```swift
struct PositiveIntProvider: Arbitrary, Sendable {
    typealias Value = Int // The type we are providing an Arbitrary for

    static var gen: Gen<Int> {
        Gen.int(in: 1...Int.max) // Ensure positive
    }

    static var shrinker: any Shrinker<Int> {
        // Adapt Int.shrinker to only produce positive results
        struct PositiveIntShrinker: Shrinker {
            func shrink(_ value: Int) -> [Int] {
                return Int.shrinker.shrink(value).filter { $0 > 0 }
            }
        }
        return PositiveIntShrinker()
    }
}

// Usage:
await forAll(
    "Property for positive integers",
    PositiveIntProvider.self // Pass the Arbitrary provider type
) { (n: Int) in // The closure receives the Int
    #expect(n > 0)
    // ... your test logic ...
}
```This pattern is useful for creating test-local "providers" of `Arbitrary` values with specific characteristics.

### 4. Using `ArbitraryDictionary`

For dictionaries, SwiftQC provides the `ArbitraryDictionary<KeyArbitrary, ValueArbitrary>` wrapper due to Swift's type system constraints. The ergonomic `forAll` overload for dictionaries handles this internally.

```swift
// Ergonomic usage (recommended):
await forAll(
    "Dictionary property",
    String.self, // Type providing Arbitrary for Keys (String.Value must be Hashable)
    Int.self,    // Type providing Arbitrary for Values
    forDictionary: true // Disambiguating parameter
) { (dict: Dictionary<String, Int>) in // Closure receives the actual Dictionary
    // ... test dict ...
}

// Direct usage of ArbitraryDictionary (less common, for advanced control):
await forAll(
    "Direct ArbitraryDictionary usage",
    ArbitraryDictionary<String, Int>.self // Pass the wrapper type as the Arbitrary provider
) { (dict: Dictionary<String, Int>) in // Closure still receives the Dictionary
    // ... test dict ...
}
```
If you need a dictionary with custom `Arbitrary` types for its keys or values, you'd use the ergonomic `forAll` and pass your custom `Arbitrary`-conforming types:
```swift
struct MyCustomKey: Arbitrary, Hashable, Sendable { /* ... */ }
struct MyCustomValue: Arbitrary, Sendable { /* ... */ }

await forAll(
    "Custom Dictionary Content",
    MyCustomKey.self,
    MyCustomValue.self,
    forDictionary: true
) { (dict: Dictionary<MyCustomKey.Value, MyCustomValue.Value>) in
    // ...
}
```

## Testing Your `Arbitrary` Implementation

After defining an `Arbitrary` conformance, it's crucial to test it:
1.  **Test `gen`:** Does it produce a variety of valid instances? Does it cover edge cases if appropriate?
2.  **Test `shrinker`:** For non-minimal values, does it produce "smaller" values? Does it include sensible simple targets (e.g., 0, empty, nil)? Does it produce an empty array for already minimal values?
3.  **Test with `forAll`:** Write a simple property test using your new `Arbitrary` type to ensure it integrates correctly with the `forAll` runner.

Refer to `ArbitraryTests.swift` in the SwiftQC test suite for examples of how to structure these tests.
