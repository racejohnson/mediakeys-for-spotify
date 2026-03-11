// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MediaKeysForSpotify",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MediaKeysForSpotify",
            targets: ["MediaKeysForSpotify"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MediaKeysForSpotify",
            path: "Sources/MediaKeysForSpotify",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MediaKeysForSpotifyTests",
            dependencies: ["MediaKeysForSpotify"],
            path: "Tests/MediaKeysForSpotifyTests"
        )
    ]
)
