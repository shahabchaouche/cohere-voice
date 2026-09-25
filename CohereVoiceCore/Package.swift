// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CohereVoiceCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "CohereVoiceCore", targets: ["CohereVoiceCore"]),
    ],
    targets: [
        .target(name: "CohereVoiceCore"),
        .testTarget(
            name: "CohereVoiceCoreTests",
            dependencies: ["CohereVoiceCore"]
        ),
    ]
)
