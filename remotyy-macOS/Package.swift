// swift-tools-version: 5.9
// Swift Package Manager config

import PackageDescription

let package = Package(
    name: "remotyy",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "remotyy",
            dependencies: ["remotyyLib"],
            path: "Sources/remotyy",
            sources: [
                "remotyyMenuBarApp.swift",
            ],
            swiftSettings: [
                .unsafeFlags(["-O"])
            ]
        ),
        .target(
            name: "remotyyLib",
            path: "Sources/remotyyLib",
            sources: [
                "AppDelegate.swift",
                "HostManager.swift",
                "SettingsView.swift",
                "QRHostView.swift",
            ],
            swiftSettings: [
                .unsafeFlags(["-O"])
            ]
        ),
        .testTarget(
            name: "remotyyTests",
            dependencies: ["remotyyLib"],
            path: "Tests",
            swiftSettings: [
                .unsafeFlags(["-O"])
            ]
        ),
    ]
)
