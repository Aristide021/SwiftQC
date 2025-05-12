## Swift Testing Integration

SwiftQC integrates with the Swift Testing framework, particularly concerning the handling of issues during the property test shrinking process.

### Shrinking and Issue Reporting

When a property test fails, SwiftQC attempts to shrink the failing input to find a minimal counterexample. During this shrinking process, multiple intermediate inputs might also fail the property. If each of these intermediate failures were reported as a distinct test failure, it could clutter the test results.

To provide a cleaner experience, SwiftQC's internal property runner (specifically the `shrink` function within `PropertyRunner.swift`) uses the `Testing.withKnownIssue` function when testing shrink candidates.

```swift
// Inside the shrink loop (conceptual):
await withKnownIssue(isIntermittent: true) {
    do {
        // Try the property with the potentially smaller 'candidate' input
        try await property(candidate)
    } catch {
        // If it fails, mark it internally but don't immediately fail the test run
        candidateFailed = true
    }
}
```

This approach marks the intermediate failures encountered during shrinking as "known issues" with the `isIntermittent: true` flag. This prevents them from immediately halting the test run or appearing as separate failures in the standard Swift Testing report.

Once the shrinking process is complete, SwiftQC identifies the minimal failing input. It then re-runs the property one last time with this minimal input *outside* the `withKnownIssue` block and uses `Testing.Issue.record(...)` to report this single, final, minimal failure to the Swift Testing framework.

This ensures that only the most relevant failure (the minimal counterexample that definitively falsifies the property) is highlighted in the Swift Testing results, along with associated details like the failing input and the seed used for the run.
