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
            dependencies: [
                "AppCenter iOS Fat Framework",
                "AppCenter iOS Documentation",
                "AppCenter macOS Framework",
                "AppCenter macOS Fat Framework",
                "AppCenter macOS Documentation",
                "AppCenter tvOS Framework",
                "AppCenter tvOS Fat Framework",
                "AppCenter tvOS Documentation"
        ],
            path: "AppCenter"
        )
    ]
)
