// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GitPanel",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GitPanelCore", targets: ["GitPanelCore"]),
        .executable(name: "GitPanel", targets: ["GitPanel"])
    ],
    targets: [
        .target(
            name: "GitPanelCore",
            path: "Sources/GitPanelCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "GitPanel",
            dependencies: ["GitPanelCore"],
            path: "Sources/GitPanel",
            sources: ["main.swift"],
            swiftSettings: [.unsafeFlags(["-Xfrontend", "-parse-as-library"])]
        ),
        .testTarget(
            name: "GitPanelTests",
            dependencies: ["GitPanelCore"],
            path: "Tests/GitPanelTests"
        )
    ]
)
