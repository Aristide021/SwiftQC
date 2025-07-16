# Changelog

All notable changes to SwiftQC will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-07-16

### Added

#### Core Features
- **Property-based testing framework** with `forAll` function for automatic test case generation
- **Automatic shrinking** to minimal counterexamples when properties fail
- **Swift 6.0+ support** with full Sendable compliance and modern concurrency
- **Swift Testing integration** with seamless issue reporting
- **XCTest compatibility** for existing test suites

#### Arbitrary Protocol & Built-in Types
- `Arbitrary` protocol for associating types with generators and shrinkers
- Built-in `Arbitrary` conformances for:
  - Numeric types: `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`
  - Floating point: `Float`, `Double`, `CGFloat`, `Decimal`
  - Text: `String`, `Character`, `Unicode.Scalar`
  - Collections: `Array`, `Dictionary`, `Set`, `ContiguousArray`
  - Optional and Result types: `Optional`, `Result`
  - Other: `Bool`, `Data`, `Date`, `DateComponents`, `URL`, `UUID`, `Void`
  - Ranges: `Range`, `ClosedRange`

#### Generators
- Composable generator system via PointFree's `swift-gen`
- Built-in generators for all standard Swift types
- Generator combinators: `map`, `flatMap`, `zip`, `frequency`
- Deterministic generation with seed support

#### Shrinkers
- Pluggable shrinking system for minimal counterexamples
- Built-in shrinkers for all `Arbitrary` types
- Shrinking strategies: toward zero, empty collections, simpler structures
- Tuple and lens-based shrinking combinators

#### Stateful Testing
- `StateModel` protocol for modeling stateful systems
- `Command` protocol for defining state-changing operations
- `stateful()` runner with full command sequence shrinking
- Precondition and postcondition validation
- Model-based testing for complex state machines

#### Parallel Testing
- `ParallelModel` protocol for concurrent system testing
- `parallel()` runner for race condition detection
- Sequential and parallel command execution phases
- Model-system divergence detection

#### CLI Tool
- `SwiftQCCLI` executable for interactive property testing
- Command-line interface with examples and help
- Makefile with convenient build and run targets

#### Documentation
- Comprehensive documentation in `Docs/` directory:
  - Getting Started guide
  - Arbitrary types tutorial
  - Generators and Shrinkers guides
  - Stateful and Parallel testing documentation
  - Integration guide for Swift Testing
- Complete README with examples and installation instructions
- API documentation with code examples

#### Development Infrastructure
- GitHub Actions CI/CD pipeline with self-hosted runner support
- Multi-platform testing capability (macOS focus)
- Swift 6.0 and 6.1 compatibility testing
- Code coverage reporting with Codecov integration
- SwiftLint configuration for code quality
- Automated documentation generation and deployment
- Release automation with GitHub releases

### Technical Details
- **Swift Tools Version**: 6.0
- **Minimum Platforms**: macOS 12.0, iOS 13.0, tvOS 13.0, watchOS 6.0
- **Dependencies**: 
  - PointFree's `swift-gen` for composable generators
  - Apple's `swift-testing` for modern test framework integration
  - Apple's `swift-argument-parser` for CLI functionality
  - Apple's `swift-atomics` for thread-safe operations

### Quality Assurance
- **130+ comprehensive tests** covering all major functionality
- Property-based testing validates the library's own correctness
- Full test coverage for all `Arbitrary` conformances
- Stateful and parallel testing validation
- Generator and shrinker correctness verification

---

*This is the initial public release of SwiftQC, bringing modern property-based testing to the Swift ecosystem with a focus on type safety, performance, and developer experience.*