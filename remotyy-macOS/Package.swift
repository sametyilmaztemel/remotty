// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "remotyy",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "remotyy",
            path: ".",
            exclude: ["Info.plist", "build", "remotyy.xcodeproj"],
            sources: [
                "main.swift",
                "AppDelegate.swift",
                "HostManager.swift",
            ],
            swiftSettings: [
                .unsafeFlags(["-O"])
            ]
        ),
    ]
)
