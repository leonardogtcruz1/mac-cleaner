// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacCleaner",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MacCleanerCore",
            targets: ["MacCleanerCore"]
        ),
        .executable(
            name: "MacCleaner",
            targets: ["MacCleaner"]
        )
    ],
    targets: [
        .target(
            name: "MacCleanerCore",
            path: "Sources/MacCleanerCore"
        ),
        .executableTarget(
            name: "MacCleaner",
            dependencies: ["MacCleanerCore"],
            path: "Sources/MacCleaner"
        ),
        .testTarget(
            name: "MacCleanerCoreTests",
            dependencies: ["MacCleanerCore"],
            path: "Tests/MacCleanerCoreTests"
        )
    ]
)
