// swift-tools-version: 6.0
// This is a Skip (https://skip.tools) package.
import PackageDescription

let package = Package(
    name: "skip-socketio",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SkipSocketIO", targets: ["SkipSocketIO"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0"),
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.1.1"),
    ],
    targets: [
        .target(name: "SkipSocketIO", dependencies: [
            .product(name: "SkipFoundation", package: "skip-foundation"),
            .product(name: "SocketIO", package: "socket.io-client-swift", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .macCatalyst])),
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "SkipSocketIOTests", dependencies: [
            "SkipSocketIO",
            .product(name: "SkipTest", package: "skip")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)

if Context.environment["SKIP_BRIDGE"] ?? "0" != "0" {
    package.dependencies += [.package(url: "https://source.skip.tools/skip-bridge.git", "0.0.0"..<"2.0.0")]
    package.targets.forEach({ target in
        target.dependencies += [.product(name: "SkipBridge", package: "skip-bridge")]
    })
    // all library types must be dynamic to support bridging
    package.products = package.products.map({ product in
        guard let libraryProduct = product as? Product.Library else { return product }
        return .library(name: libraryProduct.name, type: .dynamic, targets: libraryProduct.targets)
    })
}
