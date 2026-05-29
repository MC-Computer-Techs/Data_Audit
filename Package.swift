// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DataAuditMac",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftcsv/SwiftCSV.git", from: "0.8.1")
    ],
    targets: [
        .executableTarget(
            name: "DataAuditMac",
            dependencies: ["SwiftCSV"]
        ),
    ]
)
