s# Shrinkers in SwiftQC

When a property test in SwiftQC fails, finding the simplest possible input that still causes the failure is crucial for effective debugging. This is where **Shrinkers** come into play. A shrinker takes a failing value and systematically produces a sequence of "smaller" or simpler candidate values. SwiftQC then tests these candidates to pinpoint a minimal counterexample.

## The `Shrinker` Protocol

The foundation for all shrinking behavior in SwiftQC is the `Shrinker` protocol:

```swift
public protocol Shrinker<Value>: Sendable {
    /// The type of value this shrinker operates on.
    associatedtype Value // This will be constrained to `Sendable` via `Arbitrary.Value`

    /// Given a `value`, produces an array of "smaller" or simpler candidate values.
    ///
    /// - Parameter value: The value that caused a property to fail.
    /// - Returns: An array of candidate values to test. These should be
    ///   semantically "smaller" or simpler. If no smaller values can be
    ///   produced (i.e., the input is already minimal), an empty array should be returned.
    func shrink(_ value: Self.Value) -> [Self.Value]
}
```

**Key Requirements & Properties:**

*   **`Sendable` Conformance:** The `Shrinker` protocol itself requires `Sendable`.
*   **`associatedtype Value`:** Defines the type of data the shrinker can handle. When used with the `Arbitrary` protocol, this `Value` will also be `Sendable`.
*   **`shrink(_:)` Method:** This is the core function. Implementations should ensure:
    *   Returned values are genuinely "smaller" or simpler to avoid infinite shrinking loops.
    *   The original failing value is not returned as a shrink candidate.
    *   An empty array is returned if the input value cannot be shrunk further.

## Accessing Shrinkers

While you can create and use `Shrinker` instances directly, they are most commonly accessed via a type's conformance to the `Arbitrary` protocol:

```swift
// From the Arbitrary protocol
static var shrinker: any Shrinker<Self.Value> { get }

// Example: Getting the Int shrinker
let intShrinker = Int.shrinker // Accesses the default shrinker for Int
let smallInts = intShrinker.shrink(100) // e.g., [0, 50, 99, -100, ...]
```

## Built-in Shrinkers (`Shrinkers` Enum)

SwiftQC provides a collection of pre-built shrinkers for many standard Swift and Foundation types. These are typically exposed as static factory properties on the `Shrinkers` enum, and are used by the default `Arbitrary` conformances.

Here's a list of available shrinkers (accessed like `Shrinkers.int` or `Shrinkers.array(ofElementShrinker: SomeType.shrinker)`):

*   **Numeric:**
    *   `Shrinkers.int`: Shrinks `Int` towards 0, halves, and decrements/increments magnitude.
    *   `Shrinkers.int8`, `Shrinkers.uint8`, `Shrinkers.int16`, `Shrinkers.uint16`, `Shrinkers.int32`, `Shrinkers.uint32`, `Shrinkers.int64`, `Shrinkers.uint64`: Similar logic tailored for fixed-width integers.
    *   `Shrinkers.double`, `Shrinkers.float`: Shrink towards 0.0, ±1.0, and by halving magnitude.
    *   `Shrinkers.cgFloat`: (Platform-dependent) Similar to `Double`/`Float`.
    *   `Shrinkers.decimal`: Shrinks `Decimal` towards `Decimal.zero`, ±1, and attempts to simplify by halving or rounding.
*   **Textual:**
    *   `Shrinkers.string`: Shrinks strings by removing characters, trying common simple strings (e.g., "", "a", "0"), and halving length.
    *   `Shrinkers.character`: Shrinks `Character` values towards common simple characters (a, A, 0, space, etc.) and by simplifying their underlying `Unicode.Scalar` representation.
    *   `Shrinkers.unicodeScalar`: Shrinks `Unicode.Scalar` values towards `\0`, simple ASCII scalars, and by halving their numeric value.
*   **Boolean:**
    *   `Shrinkers.bool`: Shrinks `true` to `[false]`, and `false` to `[]`.
*   **Collections & Structures:**
    *   `Shrinkers.array(ofElementShrinker:)`: Generic shrinker for arrays. Reduces length (to empty, half, one less) and shrinks individual elements using the provided `elementShrinker`.
    *   `Shrinkers.set(elementShrinker:)`: (Assuming you add this) Similar to array shrinker but for `Set`, maintaining uniqueness.
    *   `Shrinkers.dictionary(keyShrinker:valueShrinker:)`: (Assuming you add this) Shrinks dictionaries by removing pairs, shrinking values, and potentially shrinking keys.
    *   `Shrinkers.optional(wrappedShrinker:)`: Shrinks `Optional<T>.some(value)` to `nil` and also to `.some(shrunkValue)`.
    *   `Shrinkers.result(successShrinker:failureShrinker:)`: Shrinks the `.success` or `.failure` associated value.
    *   Tuple Shrinkers (e.g., `PairShrinker`, `TripleShrinker`): Shrink individual components of a tuple. Accessed via `Shrinkers.tuple(s1, s2, ...)` or directly.
*   **Other Foundation Types:**
    *   `Shrinkers.uuid`: Typically shrinks to a "nil" UUID (`0000...`) or a small set of known simple UUIDs.
    *   `Shrinkers.date`: Shrinks `Date` values towards a reference date (e.g., Unix epoch or `Date(timeIntervalSinceReferenceDate: 0)`) by shrinking the underlying `TimeInterval`.
    *   `Shrinkers.data`: Shrinks `Data` by reducing its byte count (to empty, half, one less) and by shrinking individual bytes (similar to `[UInt8]`).
    *   `Shrinkers.dateComponents`: Shrinks `DateComponents` by making individual components `nil` or shrinking their integer values towards simpler defaults (e.g., month 1, day 1, hour 0).
    *   `Shrinkers.url`: Shrinks `URL`s by simplifying components: scheme (https to http), host, path (removing segments), query parameters, and fragment.
*   **Ranges:**
    *   `Shrinkers.range(boundShrinker:)`: (Assuming generic) Shrinks `Range<Bound>` by adjusting `lowerBound` and `upperBound` inwards or shrinking the bounds themselves.
    *   `Shrinkers.closedRange(boundShrinker:)`: (Assuming generic) Similar for `ClosedRange<Bound>`.
*   **Utility:**
    *   `NoShrink<Value>()`: A generic shrinker that performs no shrinking (returns an empty array). Useful for types that are atomic or considered already minimal.

*(Note: The availability of specific static accessors like `Shrinkers.set` or `Shrinkers.dictionary` depends on their explicit addition to the `Shrinkers` enum. The underlying shrinker structs like `SetShrinker` or `DictionaryShrinker` might be used directly by `Arbitrary` conformances if not exposed on the `Shrinkers` enum.)*

## Implementing Custom Shrinkers

For your custom types, or if the default shrinkers don't suit your needs, you can implement the `Shrinker` protocol.

**Example: A `PositiveIntShrinker`**

This shrinker ensures that all shrunk `Int` values remain positive.

```swift
import SwiftQC

struct PositiveIntShrinker: Shrinker {
    typealias Value = Int

    private let intShrinker = Shrinkers.int // Use the default Int shrinker

    func shrink(_ value: Int) -> [Int] {
        // Ensure the input value itself is positive for this shrinker to make sense
        guard value > 0 else { return [] }

        // Delegate to the standard Int shrinker, then filter to keep only positive results.
        // Also, ensure shrunk values are strictly smaller than the original positive value.
        let potentialShrinks = intShrinker.shrink(value)
            .filter { $0 > 0 && $0 < value }
            .removingDuplicates() // Helper if you have one, or use Set

        // It can also be beneficial to offer '1' if it's smaller and not already present.
        var finalShrinks = potentialShrinks
        if value > 1 && !finalShrinks.contains(1) {
            finalShrinks.append(1)
            finalShrinks.sort() // Re-sort if adding specific values
        }
        return finalShrinks
    }
}

// Helper to remove duplicates (if not available elsewhere)
fileprivate extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}
```

**Tips for Writing Good Shrinkers:**

*   **Target Simplicity:** Aim for "simpler" values – typically values closer to zero, empty collections, default enum cases, or `nil`.
*   **Strictly Smaller:** Ensure every candidate returned by `shrink()` is genuinely smaller or simpler than the input to avoid infinite loops. The `PropertyRunner` also has safeguards, but well-behaved shrinkers are key.
*   **Smallest First (Often):** Offering the most-shrunk candidates first can sometimes speed up finding the absolute minimal counterexample.
*   **Balance:** Don't generate too many shrink candidates, as each one needs to be re-tested. Focus on high-probability simplifications.
*   **Test Your Shrinkers:** Write unit tests for your custom shrinkers to ensure they behave as expected (see `ShrinkersTests.swift` for examples).
