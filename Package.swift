// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Maclum",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MaclumCore", targets: ["MaclumCore"]),
        .executable(name: "Maclum", targets: ["MaclumApp"]),
    ],
    targets: [
        .target(name: "MaclumCore"),
        .executableTarget(name: "MaclumApp", dependencies: ["MaclumCore"]),
        .testTarget(name: "MaclumCoreTests", dependencies: ["MaclumCore"]),
        .testTarget(name: "MaclumAppTests", dependencies: ["MaclumApp", "MaclumCore"]),
    ]
)
