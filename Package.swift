// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "F50Dashboard",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "F50Dashboard",
            path: "Sources/F50Dashboard"
        )
    ]
)
