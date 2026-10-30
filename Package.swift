// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacPet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MacPet", path: "Sources/MacPet")
    ]
)
