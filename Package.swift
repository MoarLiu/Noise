// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Noise",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Noise", targets: ["Noise"])
    ],
    targets: [
        .executableTarget(
            name: "Noise",
            path: "Sources/Noise",
            exclude: [
                "Resources"
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Combine"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
