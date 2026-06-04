// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "remotyy",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .executable(name: "remotyy-macOS", targets: ["remotyy-macOS"]),
        .library(name: "remotyy-ios", targets: ["remotyy-ios"]),
    ],
    dependencies: [
        // WebRTC SDK for iOS/macOS
        .package(url: "https://github.com/webrtc-sdk/Specs.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "remotyy-macOS",
            dependencies: [],
            path: "remotyy-macOS",
            sources: [
                "remotyyMenuBarApp.swift",
                "MenuBarView.swift",
                "SettingsView.swift",
            ]
        ),
        .target(
            name: "remotyy-ios",
            dependencies: [],
            path: "ios/remotyy",
            sources: [
                "remotyyApp.swift",
                "ContentView.swift",
                "ConnectionView.swift",
                "TerminalView.swift",
            ]
        ),
    ]
)
