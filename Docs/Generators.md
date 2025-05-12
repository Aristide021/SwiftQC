## Generators (`Gen`)

Effective property-based testing relies on the ability to generate a wide variety of random inputs for your properties. SwiftQC achieves this by **integrating** and **leveraging** the powerful and composable random value generation capabilities of **[PointFree's `swift-gen`](https://github.com/pointfreeco/swift-gen)** library.

### Using `swift-gen`

SwiftQC uses the `Gen` type directly from the `swift-gen` library as the foundation for all random value generation. This means:

-   You have access to the full feature set of `swift-gen` for creating and combining generators when working with SwiftQC.
-   If you're already familiar with `swift-gen`, you can use it immediately within SwiftQC.
-   The core type you'll interact with for generation is `Gen<Value>` from the `swift-gen` module.
-   You may need to `import Gen` in your test files alongside `import SwiftQC` to work directly with the `Gen` type or its combinators.

### Core Concepts of `Gen`

(Referencing common `swift-gen` features – it's good to summarize key aspects here even if pointing to external docs for full details)

1.  **Composable by Design:**
    You build complex generators by combining simpler ones.
    -   `map(_:)`: Transform the output of a generator.
        ```swift
        // Assuming 'import Gen'
        let positiveIntGen = Gen.int(in: 1...100)
        let stringifiedIntGen: Gen<String> = positiveIntGen.map { "Number: \($0)" }
        ```
    -   `flatMap(_:)`: Use the output of one generator to create another generator.
        ```swift
        // Assuming 'import Gen'
        let arrayLengthGen = Gen.int(in: 1...5)
        let variableLengthArrayGen: Gen<[Bool]> = arrayLengthGen.flatMap { count in
            Gen.bool.array(of: .always(count))
        }
        ```
    -   `zip(_:,_:,...)`: Combine multiple generators into a generator of tuples.
        ```swift
        // Assuming 'import Gen'
        let pointGen: Gen<(Int, Int)> = zip(Gen.int(in: -10...10), Gen.int(in: -10...10))
        ```

2.  **Rich Set of Primitives:**
    `swift-gen` provides many built-in generators for common types:
    -   Numbers: `Gen.int(in:)`, `Gen.double(in:)`, `Gen.float(in:)`
    -   Booleans: `Gen.bool`
    -   Characters: `Gen<Character>.letter`, `Gen<Character>.number`, `Gen<Character>.ascii`, etc.
    -   Collections: Instance methods like `genOfElement.array(of: Gen<Int>)`, `genOfElement.string(of: Gen<Int>)`.
    -   `Gen.always(_:)`: A generator that always produces a constant value.
    -   `Gen.element(of:)`: Picks a random element from a collection.
    -   `Gen.frequency(_:)`: Chooses between generators based on weights.
    -   `Gen.optional`: Turns a `Gen<T>` into a `Gen<T?>`.

### Using Generators in SwiftQC

There are two main ways to use generators with SwiftQC's `forAll` function:

1.  **Implicitly via `Arbitrary`:**
    When you test a type that conforms to SwiftQC's `Arbitrary` protocol, SwiftQC automatically uses its `static var gen: Gen<Value>` requirement. The `Gen` type here *is* the one from `swift-gen`.
    ```swift
    // Int.gen and String.gen (defined via Arbitrary conformance) are used automatically
    await forAll("User ID and Email property") { (id: Int, email: String) in
        // ... your property logic ...
    }
    ```

2.  **Explicitly Providing a Generator:**
    You can provide any custom `Gen<Value>` (from `swift-gen`) directly to `forAll`. This is useful for non-`Arbitrary` types, for overriding default generation, or for specific test scenarios.
    ```swift
    // Assuming 'import Gen' and User type exists
    let specificUserGen: Gen<User> = ... // Your custom Gen<User>
    await forAll(specificUserGen, "Custom User property") { (user: User) in
        // ... your property logic ...
    }

    // Example: Generating even numbers by transforming Int.gen
    // Assuming 'import Gen'
    let evenNumberGen = Gen.int(in: 1...50).map { $0 * 2 }
    await forAll(evenNumberGen, "Property for even numbers") { (evenNum: Int) in
        #expect(evenNum % 2 == 0)
    }
    ```

### Seeding and Determinism

`swift-gen` generators can be run with a specific `RandomNumberGenerator` (like `Xoshiro`, which is seedable). SwiftQC's `forAll` function manages seeding:
-   You can provide an explicit seed for reproducible test runs.
-   If no seed is provided, one is generated.
-   The seed used is reported on test failure, allowing you to easily reproduce the exact failing case.

### Full Documentation for `swift-gen`

For a comprehensive guide to all the features, functions, and advanced capabilities of the underlying generator library, please refer to the official **[swift-gen documentation on GitHub](https://github.com/pointfreeco/swift-gen#readme)**.

By building upon `swift-gen`, SwiftQC provides a robust and flexible foundation for generating the diverse inputs needed for effective property-based testing.