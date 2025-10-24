// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "PointCloudSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PointCloudSDK",
            targets: ["PointCloudSDK"]),
    ],
    targets: [
        .binaryTarget(
            name: "PointCloudSDK",
            url: "https://github.com/TonyTaoLiang/PointCloudSDK.git/releases/download/1.0.1/PointCloudSDK.xcframework.zip",
            checksum: "0948762adc81786e0053eee4217edd472c6084b87526ade9b62e492deaeeaa49"
        )
    ]
)
