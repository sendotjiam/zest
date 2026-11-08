// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Zest",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Zest"
        ),
        .testTarget(
            name: "ZestTests",
            dependencies: ["Zest"]
        ),
    ]
)
