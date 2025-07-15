# SwiftQC Installation Guide

SwiftQC can be installed in multiple ways depending on your needs:

## 📦 Package Manager Installation (Library)

### Swift Package Manager
Add SwiftQC to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sheldon-aristide/SwiftQC.git", from: "1.0.0")
]
```

Or add it via Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/sheldon-aristide/SwiftQC.git`
3. Select version `1.0.0` or later

## 🔧 CLI Tool Installation

⚠️ **Current Limitation**: The CLI currently requires full Xcode installation due to Swift Testing dependencies. We're working on a standalone version for future releases.

### Option 1: Local Development Use (Recommended)

```bash
# Clone and enter directory
git clone https://github.com/sheldon-aristide/SwiftQC.git
cd SwiftQC

# Run directly (from project directory) - requires Xcode
swift run SwiftQCCLI --help
swift run SwiftQCCLI run --count 100
swift run SwiftQCCLI interactive
```

### Option 2: Manual Installation (Advanced Users)

⚠️ **Requires full Xcode installation** (Command Line Tools alone are insufficient)

```bash
# Prerequisites: Install Xcode from Mac App Store and accept license
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Clone the repository
git clone https://github.com/sheldon-aristide/SwiftQC.git
cd SwiftQC

# Build the CLI in release mode
swift build -c release --target SwiftQCCLI

# Install to your PATH (requires sudo)
sudo cp .build/release/SwiftQCCLI /usr/local/bin/swiftqc

# Make it executable
sudo chmod +x /usr/local/bin/swiftqc

# Verify installation
swiftqc --help
```

### Future: Standalone CLI (Roadmap)

We're working on decoupling the CLI from Swift Testing dependencies to enable:
- Homebrew installation without Xcode requirement
- Mint package manager support
- Standalone binary distribution

**For now, we recommend using the library directly in your projects** rather than relying on the CLI for production use.

## 🎯 Quick Start After Installation

### Using the Library
```swift
import SwiftQC

// Simple property test with type inference
await forAll("Addition is commutative") { (x: Int) in
    let y = 42
    #expect(x + y == y + x)
}

// Multi-parameter test
await forAll("String concatenation length", types: String.self, String.self) { (s1, s2) in
    #expect((s1 + s2).count == s1.count + s2.count)
}
```

### Using the CLI
```bash
# Run property demonstrations
swiftqc run --count 200

# Interactive mode
swiftqc interactive

# Show examples
swiftqc examples

# Get help
swiftqc --help
```

## ⚙️ Requirements

### Library
- **macOS 12.0+** / **iOS 13.0+** / **tvOS 13.0+** / **watchOS 6.0+**
- **Swift 6.0+**

### CLI Tool
- **macOS 12.0+**
- **Swift 6.0+**
- **Xcode 15.0+** (full installation required - provides XCTest runtime libraries)
- **Xcode Command Line Tools** are not sufficient; full Xcode is required

## 🔍 Verification

After installation, verify everything works:

```bash
# Check CLI is installed
swiftqc --version

# Run a quick test
swiftqc run --count 10

# Try interactive mode
swiftqc interactive
```

## 🚀 Next Steps

- Read the [Getting Started Guide](README.md)
- Explore [Examples](Examples/)
- Check out [Documentation](Docs/)
- Learn about [Stateful Testing](Docs/Stateful.md)
- Try [Parallel Testing](Docs/Parallel.md)

## 🐛 Troubleshooting

### CLI Installation Issues

**Problem**: `swiftqc: command not found`
**Solution**: Ensure `/usr/local/bin` is in your PATH:
```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Problem**: Permission denied during installation
**Solution**: Use `sudo` for the copy command:
```bash
sudo cp .build/release/SwiftQCCLI /usr/local/bin/swiftqc
```

**Problem**: Build fails during installation
**Solution**: Ensure you have Xcode and Swift 6.0+ installed:
```bash
# Install Xcode from App Store, then:
xcode-select --install
swift --version
```

**Problem**: `dyld: Library not loaded: @rpath/libXCTestSwiftSupport.dylib`
**Solution**: The CLI requires full Xcode installation (not just Command Line Tools):
```bash
# 1. Install Xcode from Mac App Store
# 2. Launch Xcode and accept license
# 3. Set Xcode path:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
# 4. Verify:
xcrun --find swift
```

### Library Integration Issues

**Problem**: Package resolution fails
**Solution**: Try clearing the package cache:
```bash
# In Xcode: File → Packages → Reset Package Caches
# Or via command line:
swift package reset
```

**Problem**: Swift Testing conflicts
**Solution**: SwiftQC uses Swift Testing 0.7.0+. Ensure compatibility with your project's testing setup.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/sheldon-aristide/SwiftQC/issues)
- **Discussions**: [GitHub Discussions](https://github.com/sheldon-aristide/SwiftQC/discussions)
- **Documentation**: [Docs folder](Docs/)

---

**Note**: Replace `sheldon-aristide/SwiftQC` with your actual GitHub username/repository path when publishing.