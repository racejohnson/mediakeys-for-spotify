// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MediaKeysForSpotify",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MediaKeysForSpotify",
            path: "Sources/MediaKeysForSpotify",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "MediaKeysForSpotifyTests",
            dependencies: ["MediaKeysForSpotify"],
            path: "Tests/MediaKeysForSpotifyTests",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
