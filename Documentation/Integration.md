## Swift Testing Integration

SwiftQC is designed to work seamlessly with the **Swift Testing** framework, offering a refined experience for property-based testing, especially when it comes to reporting failures found during the input shrinking process.

### Intelligent Issue Reporting During Shrinking

A core feature of property-based testing is **shrinking**: when a test fails with a randomly generated input, the testing library attempts to find a "smaller" or simpler version of that input that still causes the failure. This minimal counterexample is much easier to debug.

During this shrinking process, SwiftQC might test many intermediate candidates, several of which could also fail the property. If each of these intermediate failures were reported as a distinct test issue, it would lead to verbose and cluttered test output, making it harder to identify the true minimal cause.

**How SwiftQC Integrates:**

To provide a clean and focused testing experience, SwiftQC's property runners (like `forAll` and the upcoming stateful/parallel runners) intelligently manage issue reporting when used with Swift Testing:

1.  **Initial Failure:** When a property first fails with a generated input, SwiftQC captures this event.
2.  **Shrinking Phase with Suppression:** SwiftQC then enters the shrinking phase. For each smaller candidate input it tries:
    *   It executes the property against the candidate *within* a `Testing.withKnownIssue(isIntermittent: true)` block (this is an internal detail of the `PropertyRunner.swift`'s `shrink` function).
    *   If the candidate also fails, this `withKnownIssue` mechanism marks the failure as "known" and "intermittent." This prevents Swift Testing from immediately reporting it as a new, distinct test failure and cluttering your test logs. SwiftQC notes this failing candidate and continues to look for an even smaller one.
3.  **Final Minimal Counterexample Reporting:** Once the shrinking process concludes that it has found the *minimal* input that still causes the property to fail:
    *   SwiftQC re-runs the property one last time with this minimal input.
    *   The result of *this specific run* is then reported to Swift Testing using `Testing.Issue.record(...)`.

**The Benefit:**

This integrated approach ensures that:

-   Your Swift Testing report will primarily highlight **only the single, minimal counterexample** that definitively falsifies your property.
-   You avoid "issue spam" from multiple failing inputs encountered during the shrinking process.
-   The reported failure includes all relevant details, such as the minimal input itself, the error thrown, and the random `seed` used for that `forAll` run (which allows for easy reproduction).

**User Experience:**

As a user of SwiftQC with Swift Testing, you generally don't need to do anything special to enable this behavior. Simply write your properties using `forAll` and your assertions using `#expect` (or other Swift Testing assertions):

```swift
import SwiftQC
import Testing

@Test
func arraySortingProperty() async {
    // Assume 'Int.self' makes Array<Int> Arbitrary
    await forAll("Array sorting should be idempotent", [Int].self) { (originalArray: [Int]) in
        let sortedOnce = originalArray.sorted()
        let sortedTwice = sortedOnce.sorted() // Sorting an already sorted array
        #expect(sortedTwice == sortedOnce)
    }
}
```
If this property were to fail (e.g., due to a bug in a custom sort or an issue with `Equatable` on a complex element type), SwiftQC would handle the shrinking and report only the simplest failing `originalArray` to Swift Testing.

**Using with XCTest:**

While SwiftQC's most refined issue reporting is tailored for Swift Testing, it remains fully compatible with XCTest. When used in an XCTest environment, `forAll` will still run, generate inputs, and shrink failures. Failures will typically be reported using `XCTFail` via the `XCTestReporter` (or a custom reporter), providing details of the minimal counterexample.
