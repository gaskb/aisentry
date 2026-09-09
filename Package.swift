// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "UsageSentry",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "UsageSentry"
        ),
    ],
    swiftLanguageModes: [.v6]
)
