// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Ticker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Ticker",
            path: "Sources/Ticker"
        ),
        .testTarget(
            name: "TickerTests",
            dependencies: ["Ticker"],
            path: "Tests/TickerTests"
        )
    ]
)
