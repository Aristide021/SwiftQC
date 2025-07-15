# Basic Usage Example

This example demonstrates the fundamentals of property-based testing with SwiftQC.

## What You'll Learn

- How to write basic property tests using `forAll`
- Testing arithmetic, string, and collection properties
- Creating custom `Arbitrary` types
- Understanding automatic shrinking to minimal counterexamples
- Integration with Swift Testing

## Running the Example

```bash
cd Examples/BasicUsage
swift run  # Shows example descriptions
swift test # Runs all property tests
```

## Key Concepts Demonstrated

### 1. Basic Properties
```swift
@Test("Addition is commutative")
func additionIsCommutative() async {
  await forAll("Int addition is commutative") { (a: Int, b: Int) in
    #expect(a + b == b + a)
  }
}
```

### 2. Multiple Parameters
```swift
await forAll("String concatenation preserves length", String.self, String.self) { (s1: String, s2: String) in
  let combined = s1 + s2
  #expect(combined.count == s1.count + s2.count)
}
```

### 3. Custom Types
```swift
struct Point: Arbitrary, Sendable, Equatable {
  let x: Int
  let y: Int
  
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

### 4. Dictionary Testing
```swift
await forAll("Dictionary merging preserves original", String.self, Int.self, forDictionary: true) { (dict: [String: Int]) in
  let empty: [String: Int] = [:]
  let merged = dict.merging(empty) { current, _ in current }
  #expect(merged == dict)
}
```

## Properties Tested

- **Arithmetic**: Commutativity and associativity of addition
- **Strings**: Reversal involution, concatenation length preservation
- **Arrays**: Map identity, filter count relationships
- **Dictionaries**: Merging behavior with empty dictionaries
- **Optionals**: Map behavior with nil values
- **Custom Types**: Distance calculations between points

## Expected Output

All tests should pass, demonstrating that these mathematical and programming properties hold for randomly generated inputs. If you uncomment the failing test, you'll see SwiftQC's shrinking in action as it finds the minimal counterexample.