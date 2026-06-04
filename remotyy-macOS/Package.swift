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
            path: ".",
            exclude: ["Info.plist"],
            sources: [
                "remotyyMenuBarApp.swift",
                "MenuBarView.swift",
                "SettingsView.swift",
            ],
            swiftSettings: [
                .unsafeFlags(["-O"])
            ]
        ),
    ]
)
