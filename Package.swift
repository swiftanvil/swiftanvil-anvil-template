// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnvilTemplate",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "AnvilTemplate", targets: ["AnvilTemplate"]),
    ],
    targets: [
        .target(name: "AnvilTemplate"),
        .testTarget(name: "AnvilTemplateTests", dependencies: ["AnvilTemplate"]),
    ],
    swiftLanguageModes: [.v6]
)
