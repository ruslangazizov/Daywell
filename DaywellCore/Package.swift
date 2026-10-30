// swift-tools-version: 6.4

import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency")
]
let uiModuleSettings: [SwiftSetting] = approachableConcurrencySettings + [
    .defaultIsolation(MainActor.self)
]

let package = Package(
    name: "DaywellCore",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Clients", targets: ["Clients"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies",
            from: "1.17.1"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-sharing",
            from: "2.10.1"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-identified-collections",
            from: "1.1.1"
        )
    ],
    targets: [
        .target(
            name: "Domain",
            dependencies: [
                .product(name: "IdentifiedCollections", package: "swift-identified-collections")
            ],
            swiftSettings: uiModuleSettings
        ),
        .target(
            name: "DesignSystem",
            swiftSettings: uiModuleSettings
        ),
        .target(
            name: "Persistence",
            dependencies: [
                "Domain",
                .product(name: "Sharing", package: "swift-sharing"),
            ],
            swiftSettings: approachableConcurrencySettings
        ),
        .target(
            name: "Clients",
            dependencies: [
                "Domain",
                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            swiftSettings: approachableConcurrencySettings
        ),
        // Tests
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            swiftSettings: approachableConcurrencySettings
        ),
    ]
)
