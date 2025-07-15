# Contributing to SwiftQC

Thank you for your interest in contributing to SwiftQC! This document provides guidelines for contributing to this property-based testing library for Swift.

## Code of Conduct

By participating in this project, you agree to be respectful, constructive, and collaborative. We are committed to providing a welcoming and inclusive environment for all contributors.

## How to Contribute

### Reporting Issues

- Use the [GitHub issue tracker](https://github.com/Aristide021/SwiftQC/issues)
- Check existing issues before creating a new one
- Include relevant details:
  - Swift version
  - Platform (macOS, iOS, etc.)
  - Code example that demonstrates the issue
  - Expected vs actual behavior

### Suggesting Features

- Open a [GitHub issue](https://github.com/Aristide021/SwiftQC/issues) with the "enhancement" label
- Describe the use case and benefits
- Consider if it fits SwiftQC's scope and philosophy

### Development Setup

1. **Fork and clone the repository**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/SwiftQC.git
   cd SwiftQC
   ```

2. **Ensure you have the requirements**:
   - Swift 6.0+
   - macOS 12.0+ for full development (CLI features)

3. **Build and test**:
   ```bash
   swift build
   swift test
   ```

4. **Run linting**:
   ```bash
   swiftlint
   ```

### Pull Request Process

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Follow existing code style and patterns
   - Add tests for new functionality
   - Update documentation as needed
   - Ensure all tests pass

3. **Commit your changes**:
   ```bash
   git commit -m "Add feature: brief description"
   ```

4. **Push and create a pull request**:
   ```bash
   git push origin feature/your-feature-name
   ```

5. **PR Requirements**:
   - Clear description of changes
   - Tests that verify the new functionality
   - Documentation updates if needed
   - All CI checks must pass

### Code Style Guidelines

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and reasonably sized
- Use SwiftLint to maintain consistent formatting

### Testing

- Write tests for all new functionality
- Use both unit tests and integration tests
- Test edge cases and error conditions
- Ensure tests are deterministic and reliable

### Documentation

- Update relevant documentation in `/Docs` for significant changes
- Add DocC comments to public APIs
- Update README.md if the change affects usage
- Consider adding examples to `/Examples` for major features

## Development Areas

SwiftQC has several areas where contributions are welcome:

### Core Areas
- **Generators**: Expanding `Arbitrary` conformances
- **Shrinkers**: Improving shrinking algorithms
- **Property Testing**: Enhancing the core `forAll` functionality

### Advanced Areas
- **Stateful Testing**: Improvements to command-based testing
- **Parallel Testing**: Enhanced concurrency testing features
- **Performance**: Optimizations and benchmarking

### Tooling
- **CLI**: Enhancements to the command-line interface
- **Documentation**: Improving docs and examples
- **CI/CD**: Build and deployment improvements

## Getting Help

- **Questions**: Use [GitHub Discussions](https://github.com/Aristide021/SwiftQC/discussions)
- **Issues**: Use the [issue tracker](https://github.com/Aristide021/SwiftQC/issues)
- **Documentation**: Check the [docs folder](Docs/) and [examples](Examples/)

## License

By contributing to SwiftQC, you agree that your contributions will be licensed under the Apache License 2.0.

## Recognition

Contributors are recognized in our release notes and documentation. Thank you for helping make SwiftQC better!