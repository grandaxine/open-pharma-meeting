// swift-tools-version: 5.9
import PackageDescription
let names = ["MeetingDataKit", "PrivacyPolicyKit", "MeetingCaptureKit", "TranscriptionKit", "EnterpriseConnectorKit", "ReportKit"]
let package = Package(name: "OpenPharmaMeeting", platforms: [.iOS(.v16), .macOS(.v13)], products: names.map { .library(name: $0, targets: [$0]) }, targets: names.map { name in
    .target(name: name, dependencies: name == "MeetingDataKit" ? [] : ["MeetingDataKit"])
} + [.testTarget(name: "PlatformTests", dependencies: names.map { .byName(name: $0) })])
