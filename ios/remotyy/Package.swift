// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "remotyy-ios",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "remotyy-ios",
            type: .dynamic,
            targets: ["remotyy-ios"]
        ),
    ],
    dependencies: [
        // WebRTC framework for iOS
        .package(url: "https://github.com/webrtc-sdk/webrtc-ios", branch: "main"),
    ],
    targets: [
        .target(
            name: "remotyy-ios",
            dependencies: [
                .product(name: "WebRTC", package: "webrtc-ios"),
            ],
            path: ".",
            sources: [
                "remotyyApp.swift",
                "ContentView.swift",
                "ConnectionView.swift",
                "TerminalView.swift",
            ],
            resources: [
                .process("Assets.xcassets"),
            ]
        ),
    ]
)
