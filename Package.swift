// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MediaKeysForSpotifyV2",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MediaKeysForSpotifyV2",
            targets: ["MediaKeysForSpotifyV2"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MediaKeysForSpotifyV2",
            path: "Sources/MediaKeysForSpotifyV2",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MediaKeysForSpotifyV2Tests",
            dependencies: ["MediaKeysForSpotifyV2"],
            path: "Tests/MediaKeysForSpotifyV2Tests"
        )
    ]
)
