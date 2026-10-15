// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MahiFinCore",
    platforms: [.iOS("18.0"), .tvOS("18.0"), .macOS(.v13)],
    products: [.library(name: "MahiFinCore", targets: ["MahiFinCore"])],
    targets: [
        .target(name: "MahiFinCore"),
        .executableTarget(name: "MahiFinIntegrationProbe", dependencies: ["MahiFinCore"]),
        .testTarget(name: "MahiFinCoreTests", dependencies: ["MahiFinCore"], resources: [.copy("Fixtures")])
    ]
)
