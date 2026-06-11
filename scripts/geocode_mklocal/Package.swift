// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "GeocodeMK",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GeocodeMK",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
