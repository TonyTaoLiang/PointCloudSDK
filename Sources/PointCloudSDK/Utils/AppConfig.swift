//
//  AppConfig.swift
//  PointCloudSDK
//
//  Created by chenying on 2025/10/17.
//
#if os(iOS)

import Foundation

enum AppConfig {
    static let earlySampleStep: Int = 1
    static let sampleInterval: Int = 1
    static let maxPointsDefault: Int = 1_000_000
    static let minPointsPerObject: Int = 1000
    static let maxPointsLowerBound: Int = 50000
    static let maxPointsUpperBound: Int = 150000
    static let maxPointsStep: Int = 10000
    static let efficientGridSize: Float = 0.05
    static let spatialMapGridSize: Float = 0.25
    static let uniformSampleGridSize: Float = 0.05
    static let showFPSDebugOverlay: Bool = true
    static let enableFinalPointLimit: Bool = false
}

#endif
