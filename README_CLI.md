# SwiftQCCLI - Property-Based Testing Command Line Interface

SwiftQCCLI is a command line interface for exploring and demonstrating property-based testing concepts using the SwiftQC framework.

## Features

- 🧪 **Property-Based Testing Demonstrations** - Run examples of mathematical and programming properties
- 🎲 **Generator Exploration** - Interactive generator demonstrations
- 🔧 **Composition Examples** - Advanced generator composition techniques
- ⚖️ **Frequency-Based Generation** - Weighted random value generation
- 🎯 **Interactive Mode** - Explore SwiftQC concepts interactively

## Installation

Build the CLI from the SwiftQC project:

```bash
swift build
```

## Usage

### Basic Commands

```bash
# Show help
swift run SwiftQCCLI --help

# Run property demonstrations (default command)
swift run SwiftQCCLI run --count 100 --verbose

# List available examples
swift run SwiftQCCLI examples list

# Run a specific example
swift run SwiftQCCLI examples run integer-properties

# Interactive mode
swift run SwiftQCCLI interactive
```

### Run Command

The `run` command executes property-based testing demonstrations:

```bash
# Run with default settings (100 iterations)
swift run SwiftQCCLI run

# Run with custom iteration count
swift run SwiftQCCLI run --count 1000

# Run with verbose output
swift run SwiftQCCLI run --verbose

# Run with fixed seed for reproducibility
swift run SwiftQCCLI run --seed 12345
```

### Examples

Available examples include:

#### Property-Based Examples
- `integer-properties` - Basic integer mathematical properties
- `string-properties` - String manipulation properties
- `array-properties` - Array operation properties
- `sorting-properties` - Sorting algorithm properties
- `arithmetic-properties` - Mathematical properties

#### Generator Demonstrations
- `generators` - Basic generator usage
- `frequency` - Frequency-based generation
- `composition` - Advanced generator composition

Example usage:
```bash
swift run SwiftQCCLI examples run integer-properties --count 50
swift run SwiftQCCLI examples run generators
swift run SwiftQCCLI examples run composition
```

### Interactive Mode

Interactive mode provides a REPL-like experience:

```bash
swift run SwiftQCCLI interactive
```

Available interactive commands:
- `help` - Show available commands
- `test <n>` - Run a quick property test with n iterations
- `examples` - Run quick demonstration examples
- `gen <type>` - Demonstrate generator for type (int, string, array, bool)
- `quit` - Exit interactive mode

Example session:
```
swiftqc> gen int
🎲 Generator Demo: int
Generating 5 random integers:
  1. 74
  2. -21
  3. 73
  4. -15
  5. -75

swiftqc> test 10
⚡ Quick Property Test (10 iterations)
✅ Property passed all 10 iterations!

swiftqc> quit
👋 Goodbye!
```

## Example Output

### Property Testing
```
🔢 Integer Property Examples
═══════════════════════════
✅ Addition Identity: PASSED (100 iterations)
✅ Addition Commutativity: PASSED (100 iterations)
✅ Multiplication Identity: PASSED (100 iterations)
```

### Generator Demonstrations
```
🎲 Generator Demonstrations
═══════════════════════════

1. Basic Generators:
   Integer: 51
   Boolean: false
   Float: 0.052985674901430024

2. Composite Generators:
   Array: [3, 2, 1, 2]
   Pair: (8, "dbv")

3. String Generation:
   Random string: 'qxcydtsn'
```

### Frequency-Based Generation
```
⚖️  Frequency-based Generation
═══════════════════════════

1. Weighted Boolean (25% true, 75% false):
   Results: [false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
   True count: 1/20 (5.0%)

2. Weighted Integers:
   Sample: [4, 1, 8, 1000, 105, 1001, 3, 1500, 9, 150]
```

## Architecture

The CLI is built using:
- **ArgumentParser** - Command-line argument parsing
- **Gen** - Random value generation (from swift-gen)
- **Custom Property Testing** - Simplified property testing implementation

The CLI demonstrates SwiftQC concepts without requiring the full SwiftQC library, making it lightweight and avoiding testing framework dependencies.

## Property Testing Concepts

The CLI demonstrates key property-based testing concepts:

1. **Properties** - Mathematical or logical statements that should hold for all inputs
2. **Generators** - Functions that produce random test inputs
3. **Composition** - Combining simple generators to create complex ones
4. **Frequency** - Weighted random generation for realistic test data

## Examples of Properties Tested

- **Identity Laws**: `n + 0 = n`, `n * 1 = n`
- **Commutativity**: `a + b = b + a`
- **Idempotence**: `sort(sort(arr)) = sort(arr)`
- **Preservation**: `|sort(arr)| = |arr|`
- **Inverse Operations**: `reverse(reverse(arr)) = arr`

## Contributing

The CLI serves as both a demonstration tool and a learning resource for property-based testing concepts. It can be extended with additional examples and generators as needed. 