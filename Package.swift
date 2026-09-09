// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "AiSentry",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AiSentry"
        ),
    ],
    swiftLanguageModes: [.v6]
)
