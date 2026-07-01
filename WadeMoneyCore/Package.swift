// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WadeMoneyCore",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [
        .library(name: "WadeMoneyCore", targets: ["WadeMoneyCore"]),
    ],
    targets: [
        .target(name: "WadeMoneyCore"),
        .testTarget(name: "WadeMoneyCoreTests", dependencies: ["WadeMoneyCore"]),
    ]
)
