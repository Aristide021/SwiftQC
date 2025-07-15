// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "SwiftQC",
  platforms: [
    .macOS(.v12), // Consider updating macOS version for newer Swift features if possible
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6), // watchOS might need a higher version for swift-testing
  ],
  products: [
    .library(
      name: "SwiftQC",
      targets: ["SwiftQC"]
    ),
    .executable(
      name: "SwiftQCCLI",
      targets: ["SwiftQCCLI"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-gen.git", from: "0.4.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
    // Ensure your swift-testing version is compatible with your Swift tools version
    .package(url: "https://github.com/apple/swift-testing.git", from: "0.7.0"), // Or latest compatible
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "SwiftQC",
      dependencies: [
        .product(name: "Gen", package: "swift-gen"),
        .product(name: "Testing", package: "swift-testing"),
        .product(name: "Atomics", package: "swift-atomics"),
      ],
      path: "Sources/SwiftQC"
    ),
    .executableTarget(
      name: "SwiftQCCLI",
      dependencies: [
        "SwiftQC",
        .product(name: "Gen", package: "swift-gen"),
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "Sources/SwiftQCCLI"
    ),
    // MARK: — Tests
    .testTarget(
      name: "SwiftQCTests",
      dependencies: [
        "SwiftQC", // Your library
        .product(name: "Atomics", package: "swift-atomics"),
        .product(name: "Gen", package: "swift-gen"),     // <-- ADD THIS
        .product(name: "Testing", package: "swift-testing") // <-- ADD THIS
      ],
      path: "Tests/SwiftQCTests"
    )
  ]
)
