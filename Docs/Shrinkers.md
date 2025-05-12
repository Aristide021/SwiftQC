## Shrinkers

SwiftQC uses **Shrinkers** to find minimal counterexamples when a property test fails. A shrinker takes a failing value and produces a sequence of "smaller" values that are more likely to reveal the root cause of the failure.

### The `Shrinker` Protocol

The core concept is defined by the `Shrinker` protocol:

```swift
public protocol Shrinker<Value>: Sendable{
    associatedtype Value
    func shrink(_ value: Value) -> [Value]
}
```

Types conforming to `Shrinker` provide a `shrink` function that, given a `value`, returns an array of values considered "smaller" than the input.

### Built-in Shrinkers

SwiftQC provides built-in shrinkers for common types via the `Shrinkers` enum:

-   `Shrinkers.int`: Shrinks `Int` values towards zero.
-   `Shrinkers.range(_ bounds: ClosedRange<Int>)`: Shrinks `Int` within a range towards the lower bound.
-   `Shrinkers.array(ofElementShrinker:)`: Shrinks arrays by removing elements or shrinking individual elements (requires a shrinker for the element type).
-   `Shrinkers.string`: Shrinks strings towards the empty string and simpler sequences.
-   `Shrinkers.double`: Shrinks `Double` values towards zero and simple values like 1.0 and -1.0.
-   `Shrinkers.float`: Shrinks `Float` values towards zero and simple values like 1.0 and -1.0.
-   Tuple shrinkers are also available.

These built-in shrinkers are used automatically when you use types that conform to the `Arbitrary` protocol.
