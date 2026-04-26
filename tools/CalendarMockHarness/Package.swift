// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "CalendarMockHarness",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "CalendarMockHarness", path: "Sources/CalendarMockHarness")
    ]
)
