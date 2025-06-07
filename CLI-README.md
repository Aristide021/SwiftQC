# SwiftQC CLI

A command-line interface for SwiftQC property-based testing.

## Overview

SwiftQC CLI provides a standalone command-line tool for running property-based tests using the full SwiftQC framework. It supports:

- **Property-based testing** with automatic shrinking
- **Stateful testing** for complex state machines
- **Parallel testing** for concurrent operations
- **Interactive mode** for exploratory testing
- **Multiple reporters** (console, JSON, verbose)

## Requirements

### XCTest Libraries

The SwiftQC CLI requires XCTest libraries to be available at runtime because SwiftQC uses Swift Testing, which depends on XCTest. These libraries are provided with Xcode.

**Required:**
- Xcode (provides XCTest frameworks)
- macOS (for the libXCTestSwiftSupport.dylib and frameworks)

### Swift Version

- Swift 6.1+ (Swift 6 for full language support)

## Installation & Building

```bash
# Clone the repository
git clone https://github.com/your-org/SwiftQC.git
cd SwiftQC

# Build the CLI
swift build --target SwiftQCCLI
```

## Running the CLI

### Option 1: Use the Convenience Script

```bash
# Make the script executable (first time only)
chmod +x run-swiftqc-cli.sh

# Run the CLI
./run-swiftqc-cli.sh --help
./run-swiftqc-cli.sh run --count 100
./run-swiftqc-cli.sh examples
```

### Option 2: Use the Makefile

```bash
# Show available commands
make help

# Build and run with help
make run-help

# Run examples
make run-examples

# Run a sample test
make run-sample

# Run with custom arguments
make run ARGS="run --count 50 --seed 12345"
```

### Option 3: Manual Environment Setup

```bash
# Set up environment variables
export DYLD_LIBRARY_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib"
export DYLD_FRAMEWORK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks:/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks"

# Run the CLI
./.build/debug/SwiftQCCLI --help
```

## Usage Examples

### Basic Property Testing

```bash
# Run built-in integer properties
./run-swiftqc-cli.sh run --properties integers --count 100

# Run string properties with specific seed for reproducibility
./run-swiftqc-cli.sh run --properties strings --count 50 --seed 12345

# Run all properties with verbose output
./run-swiftqc-cli.sh run --reporter verbose --count 200
```

### Interactive Mode

```bash
# Start interactive session
./run-swiftqc-cli.sh interactive

# This will give you a REPL-like interface where you can:
# - Define custom generators
# - Run properties interactively
# - Explore shrinking behavior
```

### Examples and Help

```bash
# Show usage examples
./run-swiftqc-cli.sh examples

# Get help for specific subcommands
./run-swiftqc-cli.sh help run
./run-swiftqc-cli.sh help stateful
```

## Available Subcommands

- **`run`** (default) - Run property-based tests
- **`stateful`** - Run stateful property-based tests
- **`interactive`** - Interactive SwiftQC session
- **`examples`** - Show SwiftQC usage examples

## Common Options

- **`--count N`** - Number of test cases to generate (default: 100)
- **`--seed N`** - Random seed for reproducible tests
- **`--reporter TYPE`** - Output format: `console`, `json`, `verbose`
- **`--properties LIST`** - Comma-separated list of properties to run

## Troubleshooting

### `@main` vs Top-Level Code Error

If you see:
```
'main' attribute cannot be used in a module that contains top-level code
```

This happens when you have both a `main.swift` file AND a `@main` attribute in the same project. Swift only allows one entry point mechanism. 

**Solution**: Rename `main.swift` to something else (we use `SwiftQCCLI.swift`).

### XCTest Library Not Found

If you see an error like:
```
dyld: Library not loaded: @rpath/libXCTestSwiftSupport.dylib
```

This means the XCTest libraries aren't available. Solutions:

1. **Use the provided script or Makefile** (recommended)
2. **Check Xcode installation**: `xcode-select --print-path`
3. **Manually set environment variables** as shown above

### Arithmetic Overflow Errors

Property-based testing intentionally generates edge cases that may cause arithmetic overflow. This is expected behavior - SwiftQC found a counterexample! The error shows:

- The exact inputs that caused the failure
- The property that failed
- The assertion that was violated

This is SwiftQC working correctly by finding edge cases in your code.

## Technical Details

### Why XCTest Dependencies?

SwiftQC uses Swift Testing for its issue suppression system, which ensures that during shrinking, only the final minimal counterexample is reported (not every intermediate failure). Swift Testing has a dependency on XCTest, which requires these runtime libraries.

### Library Paths Explained

- **`DYLD_LIBRARY_PATH`** - Points to `libXCTestSwiftSupport.dylib`
- **`DYLD_FRAMEWORK_PATH`** - Points to `XCTest.framework` and `XCTestCore.framework`

These are located in Xcode's platform directories and are required at runtime.

## Contributing

When contributing to the CLI:

1. Test with the provided scripts/Makefile
2. Ensure XCTest libraries are available in your environment  
3. Test on both Intel and Apple Silicon Macs if possible
4. Update this README if adding new features

## License

Same as SwiftQC main library - MIT License. 