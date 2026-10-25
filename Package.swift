// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Songcrumb", platforms: [.macOS(.v14)], products: [
    .library(name: "SongcrumbCore", targets: ["SongcrumbCore"])
], targets: [
    .target(name: "SongcrumbCore", path: "Songcrumb/Core"),
    .testTarget(name: "SongcrumbCoreTests", dependencies: ["SongcrumbCore"], path: "Tests", exclude: ["CoreChecks/Runner.swift"])
])
