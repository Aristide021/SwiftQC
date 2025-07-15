# Generators (`Gen`) in SwiftQC

Effective property-based testing hinges on the ability to generate a diverse and relevant range of random inputs for the properties under test. SwiftQC achieves this by deeply **integrating** and **leveraging** the powerful, composable random value generation capabilities of **[PointFree's `swift-gen`](https://github.com/pointfreeco/swift-gen)** library (version 0.4.0 or compatible).

### The Role of `swift-gen`

SwiftQC adopts the `Gen` type directly from the `swift-gen` library as the fundamental building block for all random value generation. This means:

-   **Full Power of `swift-gen`:** You have access to the complete feature set of `swift-gen` for creating, combining, and transforming generators when working with SwiftQC.
-   **Familiarity:** If you're already acquainted with `swift-gen`, its usage within SwiftQC will be entirely natural.
-   **Core Type:** The primary type for generation is `Gen<Value>`, sourced from the `swift-gen` module.
-   **Importing:** While SwiftQC re-exports some `Gen` functionality, it's often beneficial to `import Gen` directly in your test files alongside `import SwiftQC` for full access to all `Gen` combinators and static methods.

### Key Concepts of `Gen` (from `swift-gen`)

`swift-gen` provides a rich, functional API for building generators. Here are some core concepts:

1.  **Composability is Key:**
    Complex generators are typically constructed by combining or transforming simpler ones:
    -   **`map(_:)`**: Transforms the output of a generator into a new type or value.
        ```swift
        // Assuming 'import Gen'
        let positiveIntGen: Gen<Int> = Gen.int(in: 1...100)
        let userMessageGen: Gen<String> = positiveIntGen.map { id in "User ID: \(id)" }
        ```
    -   **`flatMap(_:)`**: Uses the output of one generator to create and return an entirely new generator. This is powerful for creating dependent generators.
        ```swift
        // Assuming 'import Gen'
        let arrayLengthGen: Gen<Int> = Gen.int(in: 0...5)
        let variableLengthBoolArrayGen: Gen<[Bool]> = arrayLengthGen.flatMap { count in
            // Create an array generator of 'count' booleans
            Gen.bool.array(of: .always(count))
        }
        ```
    -   **`zip` (Global Functions):** Combine multiple generators into a single generator that produces tuples of their values.
        ```swift
        // Assuming 'import Gen'
        let coordinateGen: Gen<(Int, Int)> = zip(Gen.int(in: -10...10), Gen.int(in: -10...10))
        let userProfileGen: Gen<(String, Int, Bool)> = zip(String.gen, Int.gen(in: 18...99), Gen.bool)
        ```
        *(Note: `zip` functions are global in `swift-gen` and support various arities).*

2.  **Rich Set of Primitive Generators:**
    `swift-gen` offers many built-in ways to generate common values:
    -   **Numbers:** `Gen.int(in:)`, `Gen.uint(in:)`, `Gen.double(in:)`, `Gen.float(in:)`. Also typed versions like `Gen.int8(in:)`, `Gen.uint64(in:)`, `Gen.cgFloat(in:)`.
    -   **Booleans:** `Gen.bool` (generates `true` or `false`). `Gen.bool(trueRatio:)` for biased booleans.
    -   **Characters:**
        *   `Gen<Character>.letter`: `a-z`, `A-Z`.
        *   `Gen<Character>.lowercaseLetter`: `a-z`.
        *   `Gen<Character>.uppercaseLetter`: `A-Z`.
        *   `Gen<Character>.digit`: `0-9`.
        *   `Gen<Character>.whitespace`: Space, tab.
        *   `Gen<Character>.newline`: `\n`.
        *   `Gen<Character>.ascii`: Printable ASCII characters.
        *   `Gen.character(in: CharacterSet)`: Generates characters from a given `CharacterSet`.
        *   `Gen.unicodeScalar(in: Range<Unicode.Scalar>)`: For specific Unicode scalar ranges.
    -   **Collections (Instance Methods on Element Generators):**
        *   `elementGen.array(of: Gen<Int>)`: Creates `Gen<[Element]>` with count from `Gen<Int>`.
        *   `characterGen.string(of: Gen<Int>)`: Creates `Gen<String>` with count from `Gen<Int>`.
        *   `pairGen.dictionary(ofAtMost: Gen<Int>)`: Creates `Gen<[Key: Value]>` (where `pairGen` is `Gen<(Key,Value)>`).
    -   **Constants & Choices:**
        *   `Gen.always(_:)`: A generator that always produces the given constant value.
        *   `Gen.element(of: [Element])`: Picks a random element from a non-empty array (returns `Gen<Element?>`, use `.compactMap { $0 }` if array is guaranteed non-empty).
        *   `Gen.one(of: [Gen<Value>])`: Picks one generator from an array of generators and runs it.
        *   `Gen.frequency(_:)`: Chooses between generators based on assigned integer weights.
    -   **Optionals:** `someGen.optional` or `someGen.optional(probabilityOfNil:)`.

### How Generators are Used in SwiftQC

SwiftQC integrates these generators seamlessly with its `forAll` testing function:

1.  **Implicitly via the `Arbitrary` Protocol:**
    When a type conforms to SwiftQC's `Arbitrary` protocol, it defines a `static var gen: Gen<Value>`. SwiftQC's `forAll` function will automatically use this `gen` to produce test inputs. This `Gen` *is* a `swift-gen` generator.
    ```swift
    // Assuming Int and User have Arbitrary conformances in SwiftQC
    await forAll("User Age Property") { (user: User, ageOffset: Int) in
        // SwiftQC uses User.gen and Int.gen automatically
        let newAge = user.age + ageOffset
        // ... your property logic ...
    }
    ```

2.  **Explicitly Providing a `Gen` to `forAll`:**
    For types not conforming to `Arbitrary`, or when you need more control over generation for a specific test, you can pass any `Gen<Value>` instance directly to a `forAll` overload:
    ```swift
    // Assuming 'import Gen'
    struct Product { let id: String; let price: Double }

    let specialProductGen: Gen<Product> = zip(
        Gen.uuid.map(\.uuidString), // Gen<String> for ID
        Gen.double(in: 10.0...1000.0)  // Gen<Double> for price
    ).map(Product.init)

    await forAll(specialProductGen, "Special Product Pricing") { (product: Product) in
        // ... your property logic ...
    }

    // Example: Generating positive integers only for a specific test
    let positiveIntGen = Gen.int(in: 1...(Int.max / 2)) // Avoid overflow with max
    await forAll(positiveIntGen, "Property for positive integers") { (positiveNum: Int) in
        #expect(positiveNum > 0)
    }
    ```

### Seeding and Determinism

`swift-gen` is designed for deterministic random number generation. Its generators, when run with a seedable `RandomNumberGenerator` (like `Xoshiro`, which is used by default in SwiftQC's re-export of `Gen`), will produce the same sequence of values for the same seed.

SwiftQC's `forAll` function manages this:
-   An optional `seed: UInt64?` parameter can be provided to `forAll` for reproducible test runs.
-   If no seed is given, SwiftQC generates one.
-   Upon test failure, the specific seed used for that failing run is reported, allowing you to easily reproduce and debug the exact scenario.

### `Gen.compose` for Complex Types

For constructing instances of complex types (structs or classes, especially those with many properties), `swift-gen` provides `Gen.compose`. This offers an imperative-style interface to build up an instance using multiple generation steps.

```swift
// Assuming 'import Gen'
struct ComplexObject {
    let id: Int
    let name: String
    let isActive: Bool
    let metadata: [String: String]?
}

let complexObjectGen: Gen<ComplexObject> = Gen.compose { c in
    // c is a 'GenComposer'
    let id = c.generate(using: Gen.int(in: 1...1000))
    let name = c.generate(using: String.gen(of: Gen<Character>.letter.string(of: .always(10)))) // Example of a specific string gen
    let isActive = c.generate(using: Gen.bool)
    let metadataGen: Gen<[String: String]?> = ArbitraryDictionary<String, String>.gen.optional(probabilityOfNil: 0.3)
    let metadata = c.generate(using: metadataGen)
    
    return ComplexObject(id: id, name: name, isActive: isActive, metadata: metadata)
}
```
This `complexObjectGen` can then be used with `forAll` or within an `Arbitrary` conformance.

### Official `swift-gen` Documentation

For the most exhaustive and up-to-date information on all `swift-gen` features, combinators, and advanced usage patterns, please consult the official **[swift-gen documentation on GitHub](https://github.com/pointfreeco/swift-gen#readme)**.

By building upon the solid foundation of `swift-gen`, SwiftQC empowers you to define precise and powerful generation strategies for your property-based tests.