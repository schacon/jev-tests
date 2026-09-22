// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TetrisHeatmap",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidUse.git", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "TetrisHeatmap",
            dependencies: [.product(name: "FluidUse", package: "FluidUse")]
        )
    ]
)
