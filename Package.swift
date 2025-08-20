// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeterministicColorGen",
    platforms: [
        .iOS(.v15),
        .macOS(.v15),
        .tvOS(.v15),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "DeterministicColorGen",
            targets: ["DeterministicColorGen"]
        ),
    ],
    targets: [
        .target(
            name: "DeterministicColorGen"
        ),
        .testTarget(
            name: "DeterministicColorGenTests",
            dependencies: ["DeterministicColorGen"]
        ),
    ]
)
