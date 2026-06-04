// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "remotty-ios",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "remotty-ios",
            type: .dynamic,
            targets: ["remotty-ios"]
        ),
    ],
    dependencies: [
        // WebRTC framework for iOS
        .package(url: "https://github.com/webrtc-sdk/webrtc-ios", branch: "main"),
    ],
    targets: [
        .target(
            name: "remotty-ios",
            dependencies: [
                .product(name: "WebRTC", package: "webrtc-ios"),
            ],
            path: ".",
            sources: [
                "remottyApp.swift",
                "ContentView.swift",
                "ConnectionView.swift",
                "TerminalView.swift",
                "WebRTCService.swift",
                "TouchHandler.swift",
                "ScreenView.swift",
            ],
            resources: [
                .process("Assets.xcassets"),
            ]
        ),
    ]
)
