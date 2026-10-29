// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YourDotMini",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "YourDotMiniAuthPilot", targets: ["YourDotMiniAuthPilot"]),
        .executable(name: "YourDotMini", targets: ["YourDotMini"]),
        .executable(name: "WindowFocusChecks", targets: ["WindowFocusChecks"]),
        .executable(name: "SandboxChecks", targets: ["SandboxChecks"]),
    ],
    targets: [
        .target(name: "PilotCore"),
        .executableTarget(name: "YourDotMiniAuthPilot", dependencies: ["PilotCore"]),
        .testTarget(name: "PilotCoreTests", dependencies: ["PilotCore"]),
        .target(name: "YourDotMiniCore"),
        .target(name: "YourDotMiniUI", dependencies: ["YourDotMiniCore", "PilotCore"]),
        .executableTarget(name: "YourDotMini", dependencies: ["YourDotMiniUI", "YourDotMiniCore"]),
        .testTarget(name: "YourDotMiniCoreTests", dependencies: ["YourDotMiniCore"]),
        .testTarget(name: "YourDotMiniUITests", dependencies: ["YourDotMiniUI"]),
        .executableTarget(name: "WindowFocusChecks", dependencies: ["YourDotMiniUI", "YourDotMiniCore"],
                          path: "Tests/WindowFocusChecks"),
        .executableTarget(name: "SandboxChecks", dependencies: ["YourDotMiniUI", "YourDotMiniCore"],
                          path: "Tests/SandboxChecks"),
    ]
)
