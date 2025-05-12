# Arbitrary Protocol

The `Arbitrary` protocol is a core concept in SwiftQC that connects types to their generators and shrinkers. It provides a standardized way for types to define how random values should be generated and shrunk during property testing.

## Protocol Definition

```swift
public protocol Arbitrary: Sendable {
    associatedtype Value: Sendable
    
    /// The generator used to create random values of this type
    static var gen: Gen<Value> { get }
    
    /// The shrinker used to find smaller counterexamples of this type
    static var shrinker: any Shrinker<Value> { get }
}
```

The protocol has three key requirements:
1. An associated `Value` type that must be `Sendable`
2. A static `gen` property that returns a generator for values of this type
3. A static `shrinker` property that returns a shrinker for values of this type

## Built-in Arbitrary Types

SwiftQC provides `Arbitrary` conformance for many standard Swift types:

### Primitive Types
- `Int`, `Int8`, `Int16`, `Int32`, `Int64`
- `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`
- `Float`, `Double`, `CGFloat`
- `Bool`
- `Character`, `Unicode.Scalar`
- `String`
- `Decimal`
- `UUID`
- `Date` (with reasonable date ranges)

### Collection Types
- `Array<T>` where `T: Arbitrary`
- `Dictionary<K, V>` (via `ArbitraryDictionary<K, V>` wrapper)
- `Set<T>` where `T: Arbitrary & Hashable`
- `Optional<T>` where `T: Arbitrary`
- `Result<Success, Failure>` where both `Success` and `Failure` are `Arbitrary`

## Conforming Custom Types to Arbitrary

There are several ways to make your types conform to `Arbitrary`:

### 1. Basic Conformance

For simple types, implement the required properties:

```swift
struct Point: Arbitrary, Sendable {
    let x: Int
    let y: Int
    
    typealias Value = Point
    
    static var gen: Gen<Point> {
        zip(Int.gen, Int.gen).map { x, y in
            Point(x: x, y: y)
        }
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

### 2. Using Deriving for Simple Cases

For simple types composed of other `Arbitrary` types, you can use a simple mapping approach:

```swift
struct User: Arbitrary, Sendable {
    let id: UUID
    let name: String
    let age: Int
    
    typealias Value = User
    
    static var gen: Gen<User> {
        zip(UUID.gen, String.gen, Int.gen.map { abs($0) % 100 + 18 })
            .map { User(id: $0, name: $1, age: $2) }
    }
    
    static var shrinker: any Shrinker<User> {
        // Simple no-shrink implementation if shrinking isn't needed
        NoShrink<User>()
        
        // Or a proper shrinker if needed:
        // Shrinkers.map(
        //    from: Shrinkers.tuple(UUID.shrinker, String.shrinker, Int.shrinker),
        //    to: { User(id: $0.0, name: $0.1, age: $0.2) },
        //    from: { ($0.id, $0.name, $0.age) }
        // )
    }
}
```

### 3. For Enum Types

For enums, use `Gen.frequency` to specify the relative frequency of each case:

```swift
enum PaymentMethod: Arbitrary, Sendable {
    case creditCard(number: String, expiry: String)
    case paypal(email: String)
    case applePay
    
    typealias Value = PaymentMethod
    
    static var gen: Gen<PaymentMethod> {
        Gen.frequency([
            (3, zip(
                String.gen.filter { $0.count >= 13 && $0.count <= 19 },
                String.gen.filter { $0.count == 5 }
            ).map { PaymentMethod.creditCard(number: $0, expiry: $1) }),
            (2, String.gen.filter { $0.contains("@") }.map { PaymentMethod.paypal(email: $0) }),
            (1, Gen.always(PaymentMethod.applePay))
        ])
    }
    
    static var shrinker: any Shrinker<PaymentMethod> {
        // Custom enum shrinker implementation
        EnumShrinker { value in
            switch value {
            case .creditCard(let number, let expiry):
                return [.applePay] + // Shrink to simpler case
                       String.shrinker.shrink(number).map { PaymentMethod.creditCard(number: $0, expiry: expiry) } +
                       String.shrinker.shrink(expiry).map { PaymentMethod.creditCard(number: number, expiry: $0) }
            case .paypal(let email):
                return [.applePay] + // Shrink to simpler case
                       String.shrinker.shrink(email).map { PaymentMethod.paypal(email: $0) }
            case .applePay:
                return [] // Nothing simpler to shrink to
            }
        }
    }
}
```

## Testing Your Arbitrary Implementation

Once you've defined your `Arbitrary` conformance, test it using `forAll`:

```swift
@Test
func pointReflectionIsItsOwnInverse() async {
    await forAll("Point reflection property") { (point: Point) in
        let reflected = Point(x: -point.x, y: -point.y)
        let original = Point(x: -reflected.x, y: -reflected.y)
        #expect(original.x == point.x)
        #expect(original.y == point.y)
    }
}
```

## Using ArbitraryDictionary

`ArbitraryDictionary` is a wrapper that provides `Arbitrary` conformance for dictionaries:

```swift
let dictGen = ArbitraryDictionary<String, Int>.gen 
// Generates Dictionary<String, Int>

// Or use the ergonomic forAll overload:
await forAll(
    "Dictionary property", 
    String.self, 
    Int.self, 
    forDictionary: true
) { (dict: Dictionary<String, Int>) in
    // Test the property
}
```

The `ArbitraryDictionary` wrapper is used internally by the ergonomic `forAll` overload for dictionaries, but you can use it directly for more control over dictionary generation if needed.

### Direct Usage Example

```swift
// Custom dictionary shrinking logic
struct CustomDictionary<K: Arbitrary & Hashable, V: Arbitrary>: Arbitrary {
    typealias Value = Dictionary<K.Value, V.Value>
    
    static var gen: Gen<Dictionary<K.Value, V.Value>> {
        ArbitraryDictionary<K, V>.gen
    }
    
    static var shrinker: any Shrinker<Dictionary<K.Value, V.Value>> {
        // Custom dictionary shrinking logic
        MyCustomShrinkingLogic<K.Value, V.Value>()
    }
}

// Using the custom dictionary type
await forAll(
    "Custom dictionary property", 
    CustomDictionary<String, Int>.self
) { (dict: Dictionary<String, Int>) in
    // Test the property
}
```

## Bias and Control

For finer control over the generated values, you can use generators with specific biases:

```swift
struct PositiveInt: Arbitrary, Sendable {
    typealias Value = Int
    
    static var gen: Gen<Int> { 
        Gen.int(in: 1...Int.max) 
    }
    
    static var shrinker: any Shrinker<Int> { 
        Shrinkers.int.filter { $0 > 0 } 
    }
}

await forAll(
    "Square root of positive integers", 
    PositiveInt.self
) { (n: Int) in
    #expect(n > 0)
    let sqrt = Double(n).squareRoot()
    #expect(sqrt > 0)
}
```

This approach is particularly useful for test-local generators that enforce specific constraints needed for your properties. 