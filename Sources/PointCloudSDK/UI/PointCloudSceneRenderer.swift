//
//  PointCloudSceneRenderer.swift
//  Landmarks
//
//  Created by chenying on 2025/7/16.
//

#if os(iOS)

import SceneKit

enum PointCloudRenderMode {
    case realtime
    case playback
}

class PointCloudSceneRenderer {
    private weak var scene: SCNScene?
    private let chunkSize = 50_000
    let nodeCategory = 1 << 1
    var realtimeNode: SCNNode?
    private var renderMode: PointCloudRenderMode = .playback

    init(scene: SCNScene) {
        self.scene = scene
    }

    // 设置模式（默认 playback）
    func setMode(_ mode: PointCloudRenderMode) {
        self.renderMode = mode
    }

    // 实时点云渲染（只更新 geometry，不刷新 node）
    func renderRealtimeChunk(_ newPoints: [PointCloudPoint]) {

        if newPoints.isEmpty {
            DispatchQueue.main.async {
                self.realtimeNode?.removeFromParentNode()
                self.realtimeNode = nil
            }
            return
        }

        let safePoints = newPoints.map {
            PointCloudPoint(position: $0.position, color: $0.color)
        }
        // 后台构建Geometry 减少卡顿
        DispatchQueue.global(qos: .userInitiated).async {
            let geometry = self.createGeometry(from: safePoints)

            DispatchQueue.main.async {
                if let node = self.realtimeNode {
                    node.geometry = geometry
                } else {
                    let node = SCNNode(geometry: geometry)
                    node.categoryBitMask = self.nodeCategory
                    node.renderingOrder = -1
                    self.scene?.rootNode.addChildNode(node)
                    self.realtimeNode = node
                }
            }
        }
    }

    // 回放点云渲染（清空重建所有 chunk）
    func renderPlayback(points: [PointCloudPoint]) {
        let safePoints = points.map {
            PointCloudPoint(position: $0.position, color: $0.color)
        }

        let chunks = createChunkedNodes(from: safePoints)

        DispatchQueue.main.async {
            self.clearOldNodes()
            self.realtimeNode = nil // ⚠️ 切换模式时必须清除

            var index = 0
            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
                if index >= chunks.count {
                    timer.invalidate()
                    return
                }
                self.scene?.rootNode.addChildNode(chunks[index])
                index += 1
            }
        }
    }

    private func clearOldNodes() {
        scene?.rootNode.enumerateChildNodes { node, _ in
            if node.categoryBitMask == self.nodeCategory {
                node.removeFromParentNode()
            }
        }
    }

    private func createChunkedNodes(from points: [PointCloudPoint]) -> [SCNNode] {
        var nodes: [SCNNode] = []

        for start in stride(from: 0, to: points.count, by: chunkSize) {
            let end = min(start + chunkSize, points.count)
            let chunk = Array(points[start..<end])
            let geometry = createGeometry(from: chunk)
            let node = SCNNode(geometry: geometry)
            node.categoryBitMask = nodeCategory
            node.renderingOrder = -1
            nodes.append(node)
        }

        return nodes
    }

    private func createGeometry(from points: [PointCloudPoint]) -> SCNGeometry {
        let count = points.count

        let positions = points.map { $0.position }
        let colors = points.map { $0.color }

        let vertexData = Data(bytes: positions, count: positions.count * MemoryLayout<SIMD3<Float32>>.stride)
        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SIMD3<Float32>>.stride)

        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float32>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float32>>.stride
        )

        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float32>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float32>>.stride
        )

        var indices = [UInt32](0..<UInt32(count))
        let indexData = Data(bytes: &indices, count: indices.count * MemoryLayout<UInt32>.size)

        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: count,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])

        let material = SCNMaterial()
        material.lightingModel = .constant
        material.readsFromDepthBuffer = false
        material.writesToDepthBuffer = false
        material.isDoubleSided = false
        geometry.materials = [material]

        return geometry
    }
}
#endif
