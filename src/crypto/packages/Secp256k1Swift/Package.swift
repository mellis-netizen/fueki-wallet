// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Secp256k1Swift",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "Secp256k1Swift",
            targets: ["Secp256k1Swift"]
        ),
    ],
    dependencies: [
        // Use bitcoin-core's secp256k1 implementation
        .package(url: "https://github.com/bitcoin-core/secp256k1.git", branch: "master")
    ],
    targets: [
        // C wrapper around libsecp256k1
        .target(
            name: "CSecp256k1",
            dependencies: [
                .product(name: "secp256k1", package: "secp256k1")
            ],
            path: "Sources/CSecp256k1",
            publicHeadersPath: "include"
        ),
        // Swift wrapper providing high-level API
        .target(
            name: "Secp256k1Swift",
            dependencies: ["CSecp256k1"],
            path: "Sources/Secp256k1Swift"
        ),
        // Comprehensive test suite
        .testTarget(
            name: "Secp256k1SwiftTests",
            dependencies: ["Secp256k1Swift"],
            path: "Tests/Secp256k1SwiftTests"
        ),
    ]
)
