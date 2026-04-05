// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LibreLinkForMac",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LibreLinkForMac",
            path: "Sources/LibreLinkForMac",
            exclude: ["Info.plist"]
        )
    ]
)
