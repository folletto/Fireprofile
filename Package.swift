// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Fireprofile",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Fireprofile",
            path: "Sources/Fireprofile"  // folder name kept as-is on disk
        )
    ]
)
