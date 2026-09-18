// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "MeridianCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "MeridianCore",
            targets: ["MeridianCore"]
        ),
        .library(
            name: "Resilience",
            targets: ["Resilience"]
        ),
        // Compatibility alias for transition
        .library(
            name: "DataStructures",
            targets: ["MeridianCore"]
        ),
        // Pure 2D Vector Geometry & Mathematical Foundations
        .library(
            name: "VectorGeometry",
            targets: ["VectorGeometry"]
        ),
        // Animation, Easing Equations & Interpolation Tweens
        .library(
            name: "VectorAnimation",
            targets: ["VectorAnimation"]
        ),
        // Graph & Tree Auto-Layout Solvers
        .library(
            name: "VectorLayout",
            targets: ["VectorLayout"]
        ),
        // Generic Reusable SwiftUI Components & Design System
        .library(
            name: "MeridianUI",
            targets: ["MeridianUI"]
        ),
        // Interactive macOS Markdown Live-Preview Demo Application
        .executable(
            name: "MeridianMarkdownDemo",
            targets: ["MeridianMarkdownDemo"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MeridianCore",
            dependencies: [],
            path: "Sources/MeridianCore",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "Resilience",
            dependencies: ["MeridianCore"],
            path: "Sources/Resilience",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "VectorGeometry",
            dependencies: [],
            path: "Sources/VectorGeometry",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "VectorAnimation",
            dependencies: ["VectorGeometry"],
            path: "Sources/VectorAnimation",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "VectorLayout",
            dependencies: ["VectorGeometry"],
            path: "Sources/VectorLayout",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "MeridianUI",
            dependencies: ["VectorGeometry"],
            path: "Sources/MeridianUI",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .executableTarget(
            name: "MeridianMarkdownDemo",
            dependencies: ["MeridianUI"],
            path: "Sources/MeridianMarkdownDemo",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "MeridianCoreTests",
            dependencies: ["MeridianCore"],
            path: "Tests/MeridianCoreTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "ResilienceTests",
            dependencies: ["MeridianCore", "Resilience"],
            path: "Tests/ResilienceTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "VectorGeometryTests",
            dependencies: ["VectorGeometry"],
            path: "Tests/VectorGeometryTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "VectorAnimationTests",
            dependencies: ["VectorGeometry", "VectorAnimation"],
            path: "Tests/VectorAnimationTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "VectorLayoutTests",
            dependencies: ["VectorGeometry", "VectorLayout"],
            path: "Tests/VectorLayoutTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "MeridianUITests",
            dependencies: ["MeridianUI", "MeridianMarkdownDemo"],
            path: "Tests/MeridianUITests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        )
    ]
)
