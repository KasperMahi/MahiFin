// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MahiFinCore",
    platforms: [.iOS(.v18), .tvOS(.v18), .macOS(.v13)],
    products: [.library(name: "MahiFinCore", targets: ["MahiFinCore"])],
    targets: [
        .target(name: "MahiFinCore"),
        .testTarget(name: "MahiFinCoreTests", dependencies: ["MahiFinCore"], resources: [.copy("Fixtures")])
    ]
)
