// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Browstay",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "Browstay", targets: ["Browstay"])
  ],
  targets: [
    .target(
      name: "BrowstayCore",
      path: "Sources/BrowstayCore"
    ),
    .executableTarget(
      name: "Browstay",
      dependencies: ["BrowstayCore"],
      path: "Sources/Browstay"
    ),
    .testTarget(
      name: "BrowstayCoreTests",
      dependencies: ["BrowstayCore"],
      path: "Tests/BrowstayCoreTests"
    ),
    .testTarget(
      name: "BrowstayTests",
      dependencies: ["Browstay", "BrowstayCore"],
      path: "Tests/BrowstayTests"
    )
  ]
)
