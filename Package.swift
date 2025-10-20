// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PointCloudSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // SDK 对外提供的静态库
        .library(
            name: "PointCloudSDK",
            targets: ["PointCloudSDK"]
        )
    ],
    dependencies: [
        // MQTT 通信
        .package(url: "https://github.com/emqx/CocoaMQTT.git", from: "2.1.0"),
        // Protobuf
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.32.0")
    ],
    targets: [
        .target(
            name: "PointCloudSDK",
            dependencies: [
                .product(name: "CocoaMQTT", package: "CocoaMQTT"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            path: "Sources/PointCloudSDK",
            resources: []
        ),
        .testTarget(
            name: "PointCloudSDKTests",
            dependencies: ["PointCloudSDK"],
            path: "Tests/PointCloudSDKTests"
        )
    ]
)

