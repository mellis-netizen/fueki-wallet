// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FuekiWallet",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FuekiWallet",
            targets: ["FuekiWallet"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.

        // Cryptography & Security - Production Ready
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),

        // Blockchain Support - Production Ready
        .package(url: "https://github.com/web3swift-team/web3swift.git", from: "3.1.0"),

        // Bitcoin Support - Production Ready
        .package(url: "https://github.com/yenom/BitcoinKit.git", from: "1.1.0"),

        // Solana Support - Production Ready
        .package(url: "https://github.com/portto/solana-swift.git", from: "1.2.1"),

        // Networking - Production Ready
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.1"),

        // Code Quality - Production Ready
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.54.0"),

        // Testing Support
        .package(url: "https://github.com/Quick/Quick.git", from: "7.3.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "FuekiWallet",
            dependencies: [
                "CryptoSwift",
                "BigInt",
                "KeychainAccess",
                .product(name: "web3swift", package: "web3swift"),
                .product(name: "BitcoinKit", package: "BitcoinKit"),
                .product(name: "Solana", package: "solana-swift"),
                "Alamofire",
            ],
            path: "FuekiWallet"
        ),
        .testTarget(
            name: "FuekiWalletTests",
            dependencies: [
                "FuekiWallet",
                "Quick",
                "Nimble"
            ],
            path: "FuekiWalletTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
