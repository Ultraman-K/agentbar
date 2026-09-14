// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentBar",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CodexQuotaCore", targets: ["CodexQuotaCore"]),
        .executable(name: "agentbar", targets: ["AgentBar"])
    ],
    targets: [
        .target(name: "CodexQuotaCore"),
        .executableTarget(name: "AgentBar", dependencies: ["CodexQuotaCore"], resources: [.copy("Resources")])
    ]
)
