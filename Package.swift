// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KiviFit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "KiviFit", targets: ["KiviFit"])
    ],
    dependencies: [
        // MediaPipe Tasks Vision for iOS
        .package(
            url: "https://github.com/google/mediapipe",
            from: "0.10.14"
        )
    ],
    targets: [
        .target(
            name: "KiviFit",
            dependencies: [
                .product(name: "MediaPipeTasksVision", package: "mediapipe")
            ],
            path: "KiviFit/Sources",
            resources: [
                .copy("../Resources/pose_landmarker_heavy.task"),
                .copy("../Resources/pose_landmarker_lite.task")
            ]
        )
    ]
)
