// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "rivium_push",
    platforms: [.iOS("13.0")],
    products: [
        .library(name: "rivium-push", targets: ["rivium_push"])
    ],
    dependencies: [
        .package(url: "https://github.com/Rivium-co/rivium-push-ios-sdk.git", from: "0.1.18")
    ],
    targets: [
        // Objective-C code: Swift Package Manager builds it as its own target.
        .target(
            name: "rivium_push_objc",
            path: "Sources/rivium_push_objc"
        ),
        .target(
            name: "rivium_push",
            dependencies: ["rivium_push_objc", .product(name: "RiviumPush", package: "rivium-push-ios-sdk")]
        )
    ]
)
