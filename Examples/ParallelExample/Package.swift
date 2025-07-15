// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "ParallelExample",
  platforms: [
    .macOS(.v12),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .executable(
      name: "ParallelExample",
      targets: ["ParallelExample"]
    ),
  ],
  dependencies: [
    .package(path: "../.."), // SwiftQC
    .package(url: "https://github.com/apple/swift-testing.git", from: "0.7.0"),
  ],
  targets: [
    .executableTarget(
      name: "ParallelExample",
      dependencies: [
        .product(name: "SwiftQC", package: "SwiftQC"),
        .product(name: "Testing", package: "swift-testing"),
      ]
    ),
  ]
)