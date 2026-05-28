// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Calibrator",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Calibrator"),
    ]
)
