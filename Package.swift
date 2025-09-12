// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TintedMac",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "TintedMac",
            targets: ["TintedMac"]
        ),
        .library(
            name: "TintedMacInject",
            type: .dynamic,
            targets: ["TintedMacInject"]
        ),
        .executable(
            name: "TintedMacHelper",
            targets: ["TintedMacHelper"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/aspauldingcode/TintedThemingSwift", from: "1.0.0"),
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0")
    ],
    targets: [
        .target(
            name: "WindowAdditions",
            path: "Shared/WindowAdditions",
            sources: ["WindowAdditions.mm"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "TintedMacProtocol",
            path: "Shared",
            sources: ["TintedMacProtocol.swift"]
        ),
        .executableTarget(
            name: "TintedMac",
            dependencies: [
                "WindowAdditions",
                "TintedThemingSwift",
                "TintedMacConfig"
            ],
            path: "TintedMac"
        ),
        .target(
            name: "TintedMacConstructor",
            path: "Shared/TintedMacConstructor"
        ),
        .target(
            name: "TintedMacConfig",
            dependencies: [
                "TOMLKit"
            ],
            path: "Shared/TintedMacConfig"
        ),
        .target(
            name: "TintedMacInject",
            dependencies: [
                "TintedMacConstructor",
                "WindowAdditions",
                "TintedThemingSwift",
                "TintedMacConfig",
                "TintedMacProtocol"
            ],
            path: "TintedMacInject"
        ),
        .executableTarget(
            name: "TintedMacHelper",
            dependencies: [
                "TintedMacConfig",
                "TintedMacProtocol"
            ],
            path: "TintedMacHelper"
        ),

    ]
)
