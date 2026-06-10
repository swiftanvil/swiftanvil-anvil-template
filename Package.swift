// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnvilTemplate",
    platforms: [.iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "AnvilTemplate", targets: ["AnvilTemplate"])
    ],
    targets: [
        .target(name: "AnvilTemplate"),
        .testTarget(name: "AnvilTemplateTests", dependencies: ["AnvilTemplate"])
    ],
    swiftLanguageModes: [.v6]
)
