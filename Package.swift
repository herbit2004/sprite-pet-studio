// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SpritePetStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SpritePetStudio", targets: ["SpritePetStudio"]),
        .executable(name: "spritepetctl", targets: ["SpritePetCtl"])
    ],
    targets: [
        .executableTarget(
            name: "SpritePetStudio",
            resources: [
                .copy("Resources/BuiltinProjects"),
                .copy("Resources/AppIcon.icns")
            ]
        ),
        .executableTarget(name: "SpritePetCtl")
    ]
)
