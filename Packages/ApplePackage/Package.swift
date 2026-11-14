// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ApplePackage",
    platforms: [.iOS(.v14)],
    products: [.library(name: "ApplePackage", targets: ["ApplePackage"])],
    dependencies: [
        .package(url: "https://github.com/Lakr233/openssl-spm.git", from: "4.0.1"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0")),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.2.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .target(name: "CApplePackage", publicHeadersPath: "include"),
        .target(
            name: "ApplePackage",
            dependencies: [
                .target(name: "CApplePackage"),
                .product(name: "OpenSSL", package: "openssl-spm"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Logging", package: "swift-log"),
            ],
            resources: [.process("SAP/Resources")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
