// swift-tools-version: 6.4

import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency")
]
let uiModuleSettings: [SwiftSetting] = approachableConcurrencySettings + [
    .defaultIsolation(MainActor.self)
]

let package = Package(
    name: "DaywellFeatures",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "AppRootFeature", targets: ["AppRootFeature"]),
        .library(name: "TasksFeature", targets: ["TasksFeature"]),
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
    ],
    dependencies: [
        .package(path: "../DaywellCore"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.26.2"
        )
    ],
    targets: [
        .target(
            name: "AppRootFeature",
            dependencies: [
                "TasksFeature",
                "SettingsFeature",
                .product(name: "DesignSystem", package: "DaywellCore"),
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                )
            ],
            swiftSettings: uiModuleSettings
        ),
        .target(
            name: "TasksFeature",
            dependencies: [
                .product(name: "Domain", package: "DaywellCore"),
                .product(name: "Clients", package: "DaywellCore"),
                .product(name: "DesignSystem", package: "DaywellCore"),
                .product(name: "Persistence", package: "DaywellCore"),
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                )
            ],
            swiftSettings: uiModuleSettings
        ),
        .target(
            name: "SettingsFeature",
            dependencies: [
                .product(name: "Domain", package: "DaywellCore"),
                .product(name: "Clients", package: "DaywellCore"),
                .product(name: "DesignSystem", package: "DaywellCore"),
                .product(name: "Persistence", package: "DaywellCore"),
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                )
            ],
            swiftSettings: uiModuleSettings
        ),
        // Tests
        .testTarget(
            name: "TasksFeatureTests",
            dependencies: ["TasksFeature"],
            swiftSettings: uiModuleSettings
        ),
        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: ["SettingsFeature"],
            swiftSettings: uiModuleSettings
        ),
    ]
)
