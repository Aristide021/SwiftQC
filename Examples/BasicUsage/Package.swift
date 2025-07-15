// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "BasicUsageExample",
  platforms: [
    .macOS(.v12),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .executable(
      name: "BasicUsageExample",
      targets: ["BasicUsageExample"]
    ),
  ],
  dependencies: [
    .package(path: "../.."), // SwiftQC
    .package(url: "https://github.com/apple/swift-testing.git", from: "0.7.0"),
  ],
  targets: [
    .executableTarget(
      name: "BasicUsageExample",
      dependencies: [
        .product(name: "SwiftQC", package: "SwiftQC"),
        .product(name: "Testing", package: "swift-testing"),
      ]
    ),
    .testTarget(
      name: "BasicUsageExampleTests",
      dependencies: [
        "BasicUsageExample",
        .product(name: "SwiftQC", package: "SwiftQC"),
        .product(name: "Testing", package: "swift-testing"),
      ]
    ),
  ]
)