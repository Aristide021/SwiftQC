import SwiftQC
import Testing
import Foundation

// Note: These examples demonstrate SwiftQC basic property testing
// The examples are kept simple to ensure they compile properly

@main
struct BasicUsageExample {
  static func main() async {
    print("🧪 SwiftQC Basic Usage Examples")
    print("==============================")
    print()
    print("This example demonstrates basic property-based testing with SwiftQC.")
    print("Run with: swift test")
    print()
    print("Examples included:")
    print("• Basic property tests for various types")
    print("• Demonstrates automatic test case generation")
    print("• Shows shrinking capabilities")
    print()
    print("Each test function shows a different aspect of property-based testing.")
    print("When tests fail, SwiftQC automatically finds minimal counterexamples.")
    print()
    print("Check the test functions to understand the API usage.")
  }
}