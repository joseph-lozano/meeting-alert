// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MeetingAlert",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "MeetingAlertCore"),
        .executableTarget(name: "MeetingAlert", dependencies: ["MeetingAlertCore"]),
        .testTarget(name: "MeetingAlertCoreTests", dependencies: ["MeetingAlertCore"]),
    ],
    swiftLanguageModes: [.v5]
)
