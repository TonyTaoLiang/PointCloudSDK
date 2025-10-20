//
//  PointCloudDracoView.swift
//  PointCloudSDK
//
//  Created by chenying on 2025/10/17.
//

#if os(iOS)
import SwiftUI
import UIKit
import SceneKit

@available(iOS 15.0, *)
public struct PointCloudDracoView: UIViewRepresentable {
    // 不再依赖 Store，而直接使用 SDK 提供的 pointCloudStore
    @ObservedObject public var pointCloudStore: PointCloudStore

    public init(pointCloudStore: PointCloudStore) {
        self.pointCloudStore = pointCloudStore
    }

    public func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = SCNScene()
        sceneView.allowsCameraControl = true
        sceneView.backgroundColor = UIColor(Color(hex: 0x262626))
        sceneView.rendersContinuously = true
        sceneView.preferredFramesPerSecond = 60

//        pointCloudStore.markerDelegate = context.coordinator
        context.coordinator.lastSceneToken = pointCloudStore.sceneDirtyToken
        let scene = sceneView.scene!
        context.coordinator.scene = scene
        context.coordinator.renderer = PointCloudSceneRenderer(scene: scene)

//        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSceneTap(_:)))
//        sceneView.addGestureRecognizer(tap)
        return sceneView
    }

    public func updateUIView(_ uiView: SCNView, context: Context) {
        if AppModeManager.shared.isRealtimeMode {
            rebuildScene(in: uiView, context: context)
            return
        }

        let currentToken = pointCloudStore.sceneDirtyToken
        guard context.coordinator.lastSceneToken != currentToken else { return }
        context.coordinator.lastSceneToken = currentToken
        guard !context.coordinator.isBuildingScene else { return }
        context.coordinator.isBuildingScene = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let scene = context.coordinator.scene else { return }
            scene.rootNode.childNodes.filter { $0.categoryBitMask == 1 << 1 }.forEach { $0.removeFromParentNode() }
            self.rebuildScene(in: uiView, context: context)
            context.coordinator.isBuildingScene = false
            DebugPrint("🔁 触发回放点云刷新")
            // 如果 SDK 需要回调上层回放结果，可通过 delegate
//            context.coordinator.shouldAddMarker(transform: self.pointCloudStore.stationTransforms)
        }
    }

    private func rebuildScene(in sceneView: SCNView, context: Context) {
        guard let scene = context.coordinator.scene else {
            DebugPrint("❌ scene 不存在")
            return
        }
        if pointCloudStore.points.isEmpty {
            scene.rootNode.childNodes.filter { $0.categoryBitMask == (context.coordinator.renderer?.nodeCategory ?? 0) }
                .forEach { node in node.removeFromParentNode() }
            context.coordinator.renderer?.realtimeNode = nil
            return
        }

        if let renderer = context.coordinator.renderer {
            let snapshotPoints = pointCloudStore.safeSnapshot()
            if AppModeManager.shared.isRealtimeMode {
                renderer.setMode(.realtime)
                renderer.renderRealtimeChunk(snapshotPoints)
            } else {
                renderer.setMode(.playback)
                renderer.renderPlayback(points: snapshotPoints)
            }
        }

        if scene.rootNode.childNodes.first(where: { $0.camera != nil }) == nil {
            let (center, maxDistance) = calculateBoundingSphere(points: pointCloudStore.points)
            scene.rootNode.addChildNode(createCameraNode(center: center, radius: maxDistance))
        }

        if scene.rootNode.childNodes.first(where: { $0.light != nil }) == nil {
            scene.rootNode.addChildNode(createAmbientLight())
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject {
        let parent: PointCloudDracoView
//        let markerManager = StationMarkerManager()
        var scene: SCNScene?
        var lastSceneToken: UUID? = nil
        var isBuildingScene: Bool = false
        var renderer: PointCloudSceneRenderer?

        init(_ parent: PointCloudDracoView) {
            self.parent = parent
        }

//        @objc func handleSceneTap(_ gesture: UITapGestureRecognizer) {
//            guard let view = gesture.view as? SCNView else { return }
//            let location = gesture.location(in: view)
//            let hitTestOptions: [SCNHitTestOption: Any] = [
//                .categoryBitMask: 1 << 2,
//                .boundingBoxOnly: false,
//                .ignoreHiddenNodes: false
//            ]
//            let hitResults = view.hitTest(location, options: hitTestOptions)
//            for hit in hitResults {
//                if let name = hit.node.name, name.hasPrefix("marker_") {
//                    markerManager.handleTap(nodeName: name)
//                    parent.onStationSelected(name.replacingOccurrences(of: "marker_", with: ""))
//                    return
//                }
//            }
//        }

//        public func shouldAddMarker(transform: [String : simd_float4x4]) {
//            guard let scene = self.scene else { return }
//            markerManager.updateIfNeeded(in: scene, stationTransforms: self.parent.pointCloudStore.stationTransforms, stationFloors: self.parent.selectedFloorsByStation, selectedFloor: self.parent.selectedFloor)
//            markerManager.onStationSelected = { id in
//                self.parent.onStationSelected(id)
//            }
//        }

//        public func shouldRemoveMarker() {
//            guard let scene = self.scene else { return }
//            markerManager.clearMarkers(from: scene)
//        }
    }
}

extension PointCloudDracoView {
    
    // 计算包围盒参数（用于相机定位）
    private func calculateBoundingSphere(points: [PointCloudPoint]) -> (center: SCNVector3, radius: Float) {
        var minPos = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxPos = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        
        points.forEach { point in
            // 从 SIMD3<Float16> 提取坐标并转换为 Float
            let x = Float(point.position.x)
            let y = Float(point.position.y)
            let z = Float(point.position.z)
            let pos = SIMD3<Float>(x, y, z)
            
            minPos = simd_min(minPos, pos)
            maxPos = simd_max(maxPos, pos)
        }
        
        let center = (minPos + maxPos) * 0.5
        let radius = simd_distance(minPos, maxPos) * 0.5
        return (SCNVector3(center), radius)
    }
    
    // 创建自动定位相机节点
    private func createCameraNode(center: SCNVector3, radius: Float) -> SCNNode {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = Double(radius * 10)
        cameraNode.camera?.zNear = Double(radius * 0.001)
        cameraNode.position = SCNVector3(
            center.x,
            center.y,
            center.z + radius * 3
        )
        cameraNode.look(at: center)
        return cameraNode
    }
    
    // 创建环境光节点
    private func createAmbientLight() -> SCNNode {
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .ambient
        lightNode.light?.intensity = 1000
        lightNode.light?.color = UIColor.white
        return lightNode
    }
}
#endif
