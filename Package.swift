// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mullion",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic (config, key names, grid math). No AppKit, so it is unit-testable anywhere.
        .target(name: "MullionCore"),
        // The macOS agent: hotkeys, Accessibility, screens.
        .executableTarget(name: "Mullion", dependencies: ["MullionCore"]),
        .testTarget(name: "MullionCoreTests", dependencies: ["MullionCore"]),
    ]
)
