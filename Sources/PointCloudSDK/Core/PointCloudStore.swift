//
//  PointCloudStore.swift
//  Landmarks
//
//  Created by chenying on 2025/3/4.
//

#if os(iOS)

import simd
import Foundation
import Combine

protocol PointCloudMarkerDelegate: AnyObject {
    func shouldAddMarker(transform: [String: simd_float4x4])
    func shouldRemoveMarker()
}

public class PointCloudStore: ObservableObject {
    @Published var points: [PointCloudPoint] = [] // 当前用于显示的点
    var dynamicMaxPoints: Int = AppConfig.maxPointsDefault
    weak var markerDelegate: PointCloudMarkerDelegate?
    @Published var isShowingGlobalMerged: Bool = false
    @Published var currentStation: String = "0"
    var stationPointClouds: [String: [PointCloudPoint]] = [:]
    var stationTransforms: [String: simd_float4x4] = ["0" : matrix_identity_float4x4]
    var globalMergedPoints: [PointCloudPoint] = []
    private var accumulatedTransform = matrix_identity_float4x4
    private let sampleInterval = AppConfig.sampleInterval
    private let minPointsPerObject = AppConfig.minPointsPerObject
    private var spatialMap: [GridKey: [PointCloudPoint]] = [:]
    private let spatialQueue = DispatchQueue(label: "com.pointcloud.spatial")

    @Published var sceneDirtyToken = UUID()

    // 回放串行处理 避免拼接错位
    func appendSync(_ newPoints: [PointCloudPoint]) -> [PointCloudPoint] {
        ensureStationZeroTransformIfNeeded()
        return voxelGridFilter(newPoints, voxelSize: AppConfig.efficientGridSize)
    }
    // 实时采集
    func append(_ newPoints: [PointCloudPoint], completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.ensureStationZeroTransformIfNeeded()

            let filtered = self.voxelGridFilter(newPoints, voxelSize: AppConfig.efficientGridSize)

            // 单批次最多 dynamicMaxPoints
            let batchPoints = filtered.count > self.dynamicMaxPoints
                ? Array(filtered.prefix(self.dynamicMaxPoints))
                : filtered
            
            DispatchQueue.main.async {
                let total = self.points.count + batchPoints.count
                if total > self.dynamicMaxPoints {
                    let overflow = total - self.dynamicMaxPoints
                    // 批量移除最旧的点
                    self.points.replaceSubrange(0..<overflow, with: [])
                    self.stationPointClouds[self.currentStation, default: []].replaceSubrange(0..<overflow, with: [])
                    DebugPrint("⚠️ 总点数超量，批量移除 \(overflow) 个旧点")
                }
                
                self.points.append(contentsOf: batchPoints)
                self.stationPointClouds[self.currentStation, default: []].append(contentsOf: batchPoints)
                DebugPrint("✅ 添加点：\(batchPoints.count)，总数：\(self.points.count)")
            }
        }
    }

    func finalizeCurrentStation(withTransform relativeTransform: simd_float4x4) {

        let stationID = currentStation
        let originalPoints = stationPointClouds[stationID] ?? []
        accumulatedTransform = accumulatedTransform * relativeTransform.inverse
        stationTransforms[stationID] = accumulatedTransform
        let transformedPoints = applyTransform(accumulatedTransform, to: originalPoints)
        globalMergedPoints.append(contentsOf: transformedPoints)
        
        // 每个站点的点云切换成矩阵转换后的
        stationPointClouds[stationID] = transformedPoints
        
        // 添加标记
        markerDelegate?.shouldAddMarker(transform: stationTransforms)
        toggleViewMode()
        
        let t = accumulatedTransform.columns.3
        DebugPrint("📦 当前累积变换平移: x: \(t.x), y: \(t.y), z: \(t.z)")
        DebugPrint("🔫 globalMergedPoints 总数：\(globalMergedPoints.count)，当前站点总数：\(transformedPoints.count)")
    }

    func toggleViewMode() {
        DebugPrint("🍔显示拼接点云")
        isShowingGlobalMerged = true
        points = isShowingGlobalMerged ? globalMergedPoints : (stationPointClouds[currentStation] ?? [])
    }

    func switchToStation(_ station: String) {
        currentStation = station
        isShowingGlobalMerged = false
        points = stationPointClouds[station] ?? []
        // 移除之前标记
        markerDelegate?.shouldRemoveMarker()
        // 触发重构 防止切换站点之前的点云没清
        sceneDirtyToken = UUID()
    }

    func applyTransform(_ matrix: simd_float4x4, to points: [PointCloudPoint]) -> [PointCloudPoint] {
        return points.map { pt in
            let pos = SIMD4<Float>(Float(pt.position.x), Float(pt.position.y), Float(pt.position.z), 1.0)
            let transformed = matrix * pos
            var newPt = pt
            newPt.position = SIMD3<Float32>(Float32(transformed.x), Float32(transformed.y), Float32(transformed.z))
            return newPt
        }
    }

    func loadPoseMatrix(from content: String) -> simd_float4x4? {
        let floats: [Float] = content
            .components(separatedBy: .whitespacesAndNewlines)
            .compactMap { Float($0) }

        guard floats.count >= 16 else {
            DebugPrint("❌ 矩阵数据不足，至少需要 16 个浮点数，实际为 \(floats.count)")
            return nil
        }

        let base = 0 //16
        return simd_float4x4(rows: [
            SIMD4<Float>(floats[base + 0],  floats[base + 1],  floats[base + 2],  floats[base + 3]),
            SIMD4<Float>(floats[base + 4],  floats[base + 5],  floats[base + 6],  floats[base + 7]),
            SIMD4<Float>(floats[base + 8],  floats[base + 9],  floats[base + 10], floats[base + 11]),
            SIMD4<Float>(floats[base + 12], floats[base + 13], floats[base + 14], floats[base + 15])
        ])
    }

    func updateMaxPointsBasedOnFPS(_ fps: Int) {
        if fps < 25 {
            dynamicMaxPoints = max(AppConfig.maxPointsLowerBound, dynamicMaxPoints - AppConfig.maxPointsStep)
        } else if fps > 50 {
            dynamicMaxPoints = min(AppConfig.maxPointsUpperBound, dynamicMaxPoints + AppConfig.maxPointsStep)
        }
    }

    func clear() {
        DebugPrint("🗑️ PointCloudStore Clear")
        DispatchQueue.main.async {
            self.points.removeAll()
            self.globalMergedPoints.removeAll()
            self.stationPointClouds.removeAll()
            self.stationTransforms.removeAll()
            self.accumulatedTransform = matrix_identity_float4x4
        }

        DispatchQueue.global(qos: .utility).async {
            self.spatialQueue.sync {
                self.spatialMap.removeAll()
            }
        }
    }

    // Voxel Grid Downsampling类似 PCL 的做法 只保留每个体素平均值（或中心点）
    private func voxelGridFilter(_ points: [PointCloudPoint], voxelSize: Float) -> [PointCloudPoint] {
        var grid = [GridKey: (sum: SIMD3<Float>, color: SIMD3<Float>, count: Int)]()

        for pt in points {
            let pos = pt.position
            let key = GridKey(
                x: Int(floor(pos.x / voxelSize)),
                y: Int(floor(pos.y / voxelSize)),
                z: Int(floor(pos.z / voxelSize))
            )
            var entry = grid[key] ?? (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 0), 0)
            entry.sum += pos
            entry.color += pt.color
            entry.count += 1
            grid[key] = entry
        }

        return grid.values.map { entry in
            PointCloudPoint(
                position: entry.sum / Float(entry.count),
                color: entry.color / Float(entry.count)
            )
        }
    }

    private func buildSpatialMap(for points: [PointCloudPoint]) {
        let gridSize = AppConfig.spatialMapGridSize
        for point in points {
            let pos = SIMD3<Float>(point.position)
            let key = GridKey(
                x: Int(round(pos.x / gridSize)),
                y: Int(round(pos.y / gridSize)),
                z: Int(round(pos.z / gridSize))
            )
            spatialMap[key, default: [PointCloudPoint]()].append(point)
        }
    }

    private func cleanByObjectDensity() -> [PointCloudPoint] {
        var result = [PointCloudPoint]()
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: spatialMap.count) { index in
            let bucketEntry = Array(self.spatialMap)[index]
            let bucket = bucketEntry.value

            let keepCount: Int
            if bucket.count <= AppConfig.minPointsPerObject {
                keepCount = bucket.count
            } else {
                let keepRatio = max(0.5, 1.0 - log(Float(bucket.count)) / 10.0)
                keepCount = Int(Float(bucket.count) * keepRatio)
            }

            let kept: [PointCloudPoint]
            if keepCount < bucket.count {
                kept = self.uniformSample(points: bucket, count: keepCount)
            } else {
                kept = bucket
            }

            lock.lock()
            result.append(contentsOf: kept)
            lock.unlock()
        }
        return result
    }

    private func uniformSample(points: [PointCloudPoint], count: Int) -> [PointCloudPoint] {
        let subGridSize = AppConfig.uniformSampleGridSize
        var subGrids = [GridKey: PointCloudPoint]()

        for point in points {
            let pos = SIMD3<Float>(point.position)
            let key = GridKey(
                x: Int(round(pos.x / subGridSize)),
                y: Int(round(pos.y / subGridSize)),
                z: Int(round(pos.z / subGridSize))
            )
            if subGrids[key] == nil {
                subGrids[key] = point
            }
        }

        if subGrids.count < count {
            let additionalCount = count - subGrids.count
            let shuffledPoints = points.shuffled().prefix(additionalCount)
            return Array(subGrids.values) + Array(shuffledPoints)
        }

        return Array(subGrids.values.shuffled().prefix(count))
    }

    private func cleanupSpatialMap() {
            spatialMap = spatialMap.filter { !$0.value.isEmpty }
            for (key, bucket) in spatialMap {
                if bucket.count > 2 * minPointsPerObject {
                    spatialMap[key] = Array(bucket.suffix(2 * minPointsPerObject))
                }
            }
    }
}

// 网格坐标结构体
struct GridKey: Hashable {
    let x, y, z: Int
}

extension PointCloudStore {
    func safeSnapshot() -> [PointCloudPoint] {
        if Thread.isMainThread {
            return self.points
        } else {
            return DispatchQueue.main.sync {
                return self.points
            }
        }
    }
    
    // 获取线程安全的站点点云快照
    func snapshotStationPointClouds() -> [String: [PointCloudPoint]] {
        if Thread.isMainThread {
            return self.stationPointClouds
        } else {
            return DispatchQueue.main.sync {
                return self.stationPointClouds
            }
        }
    }
    
    // 按楼层更新可见点云
//    func updateVisiblePoints(for floor: Floor, stationFloors: [String: Floor]) {
//        
//        DebugPrint("updateVisiblePoints called for floor: \(floor.name)")
//        DebugPrint("stationFloors content: \(stationFloors.map { "\($0.key):\($0.value.name)" })")
//        let stationIDs = stationFloors.compactMap { (id, f) -> String? in
//            // 只按名字比较，避免 UUID/实例不同导致比较失败
//            return f.name == floor.name ? id : nil
//        }
//        
//        DebugPrint("🔎 matched stationIDs: \(stationIDs)")
//        
//        var matchedTransforms: [String: simd_float4x4] = [:]
//        var merged: [PointCloudPoint] = []
//        let snapshot = snapshotStationPointClouds()
//        for id in stationIDs {
//            if let pts = snapshot[id] {
//                merged.append(contentsOf: pts)
//                if let transform = stationTransforms[id] {
//                    matchedTransforms[id] = transform
//                }
//                DebugPrint("➕ add station \(id) count \(pts.count)")
//            } else {
//                DebugPrint("⚠️ station \(id) has no points in snapshot")
//            }
//        }
//        
//        DispatchQueue.main.async {
//            //避免回放进入的重复刷新
//            if self.points.count != merged.count {
//                self.points = merged
//                self.sceneDirtyToken = UUID()
//            }
//            // 先清空 marker，再添加当前楼层的 marker
//            self.markerDelegate?.shouldRemoveMarker()
//            self.markerDelegate?.shouldAddMarker(transform: matchedTransforms)
//            DebugPrint("楼层切换到 \(floor.name)，站点数：\(stationIDs.count)，点数：\(merged.count), self.points: \(self.points.count) self.safePoints: \(self.safeSnapshot().count)")
//        }
//    }
    
    func ensureStationZeroTransformIfNeeded() {
        if stationTransforms["0"] == nil {
            stationTransforms["0"] = matrix_identity_float4x4
            DebugPrint("补回 station[0] 的初始变换矩阵")
        }
    }

}

#endif
