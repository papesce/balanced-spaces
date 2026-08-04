// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BalancedSpaces",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "BalancedSpaces",
            path: "Sources/BalancedSpaces"
        )
    ]
)
