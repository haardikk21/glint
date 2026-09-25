// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Glint",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Glint", targets: ["Glint"])],
    targets: [.executableTarget(name: "Glint", path: "Sources/Glint")]
)
