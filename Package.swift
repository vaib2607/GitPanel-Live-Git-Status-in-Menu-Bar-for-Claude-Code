// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GitPanel",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GitPanel",
            path: "Sources/GitPanel",
            swiftSettings: [.unsafeFlags(["-Xfrontend", "-parse-as-library"])]
        )
    ]
)
