// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Stayfari",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "Stayfari", targets: ["Stayfari"])
  ],
  targets: [
    .target(
      name: "StayfariCore",
      path: "Sources/StayfariCore"
    ),
    .executableTarget(
      name: "Stayfari",
      dependencies: ["StayfariCore"],
      path: "Sources/Stayfari"
    ),
    .testTarget(
      name: "StayfariCoreTests",
      dependencies: ["StayfariCore"],
      path: "Tests/StayfariCoreTests"
    ),
    .testTarget(
      name: "StayfariTests",
      dependencies: ["Stayfari", "StayfariCore"],
      path: "Tests/StayfariTests"
    )
  ]
)
