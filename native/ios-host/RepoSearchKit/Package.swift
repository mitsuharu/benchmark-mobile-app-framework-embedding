// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "RepoSearchKit",
  platforms: [.iOS("16.4")],
  products: [
    .library(name: "RepoSearchKit", targets: ["RepoSearchKit"])
  ],
  targets: [
    .target(name: "RepoSearchKit")
  ],
  // Same language mode as the host apps of every implementation.
  swiftLanguageModes: [.v5]
)
