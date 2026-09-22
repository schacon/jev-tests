// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FormGhost",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidUse.git", from: "0.2.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.8"),
    ],
    targets: [
        .executableTarget(
            name: "FormGhost",
            dependencies: [
                .product(name: "FluidUse", package: "FluidUse"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            resources: [.copy("Resources")]
        )
    ]
)
