// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "AppCenter",
    platforms: [
    .iOS("9.0"),
    .macOS("10.9"),
    .tvOS("11.0")
    ],
    products: [
        .library(
            name: "AppCenter",
            targets: ["AppCenter iOS Framework"]),
    ],
    targets: [
        .target(
            name: "AppCenter iOS Framework",
            path: "AppCenter/AppCenter"
        )
    ]
)
