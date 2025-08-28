// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FileOtter",
    platforms: [
        .macOS(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13),
    ],
    products: [
        .library(name: "FileOtter", targets: ["FileOtter"]),
    ],
    targets: [
        .target(name: "FileOtter"),
        .testTarget(name: "FileOtterTests", dependencies: ["FileOtter"]),
    ]
)
