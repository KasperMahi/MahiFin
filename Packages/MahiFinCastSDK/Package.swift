// swift-tools-version: 5.7
import PackageDescription

let package = Package(name: "MahiFinCastSDK", platforms: [.iOS("18.0")], products: [.library(name: "MahiFinCastSDK", targets: ["MahiFinCastSDK"])], dependencies: [
    .package(url: "https://github.com/googlecast/google-cast-ios-sdk.git", exact: "4.8.6"),
    .package(url: "https://github.com/google/gtm-session-fetcher.git", exact: "3.0.0")
], targets: [.target(name: "MahiFinCastSDK", dependencies: [
    .product(name: "GoogleCastDynamic", package: "google-cast-ios-sdk"),
    .product(name: "GTMSessionFetcher", package: "gtm-session-fetcher")
])])
