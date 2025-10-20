//
//  PointCloudSDK.swift
//  PointCloudSDK
//
//  Created by chenying on 2025/10/17.
//

#if os(iOS)

import Foundation
import Combine
import SwiftUI

public final class PointCloudManager {
    public static let shared = PointCloudManager()

    // delegate 用于通知 host app
    public weak var delegate: PointCloudSDKDelegate?

    // SDK 内部组件
    public private(set) var pointCloudStore: PointCloudStore = PointCloudStore()
    private var mqttClient: MQTTClient = MQTTClient.shared

    // 订阅
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 将 mqttClient 的 connection publisher 路由到 delegate
        mqttClient.connectionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self = self else { return }
                self.delegate?.sdk(self, connectionStatusChanged: connected)
            }.store(in: &cancellables)

        // 设置 message handling context，供 MessageHandlers 使用
        mqttClient.messageContext = self
    }

    // MARK: - Initialization / Connect
    /// 不再需要外部提供 Redux Store。SDK 内部持有 pointCloudStore。
    public func initialize() {
        // 未来可扩展 SDKConfig
    }

    /// 连接设备
    public func connect(sn: String, host: String, port: UInt16 = 1883) {
        mqttClient.configure(sn: sn, host: host, port: port)
    }

    public func disconnect() {
        mqttClient.disconnect()
    }

    // MARK: - Expose store read-only helpers
    /// 线程安全快照
    public func snapshotPoints() -> [PointCloudPoint] {
        return pointCloudStore.safeSnapshot()
    }

    // MARK: - SwiftUI view create helper
    public func createPointCloudView() -> some View {
        return PointCloudDracoView(
            pointCloudStore: pointCloudStore
        )
    }

    // MARK: - UIKit wrapper
    /// 返回一个可直接加入 UIKit 层级的 UIView（自动托管 SwiftUI）
//    public func makePointCloudUIKitView() -> UIView {
//        let hosting = UIHostingController(
//            rootView: createPointCloudView()
//        )
//        hosting.view.backgroundColor = .clear
//        hosting.view.translatesAutoresizingMaskIntoConstraints = false
//        let container = UIView()
//        container.addSubview(hosting.view)
//        NSLayoutConstraint.activate([
//            hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
//            hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
//            hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
//            hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
//        ])
//        return container
//    }
}

// MARK: - MessageHandlingContext adapter
extension PointCloudManager: MessageHandlingContext {
    func notifyPhotoResponse(_ isHDR: Bool, _ status: Int32) {
        DispatchQueue.main.async {
            self.delegate?.sdk(self, didReceivePhotoResponse: isHDR, status: status)
        }
    }
    
    
    func notifyDeviceStatus(_ status: Status) {
        DispatchQueue.main.async {
            self.delegate?.sdk(self, deviceStatusChanged: status)
        }
    }
    
    func pushPointCloud(_ points: [PointCloudPoint]) {
        // 入点云存储并通过 delegate 上报
        DispatchQueue.main.async {
            self.pointCloudStore.append(points) // 实时模式使用 append
            self.delegate?.sdk(self, didReceivePointCloud: points)
        }
    }

    func notifyConnectionStatus(_ connected: Bool) {
        DispatchQueue.main.async {
            self.delegate?.sdk(self, connectionStatusChanged: connected)
        }
    }
}

extension PointCloudManager {
    
    /// 发送控制命令（基于闭包回调）
    /// - Parameters:
    ///   - code: 0:停止采集 1:开始采集 2:拍照
    ///   - completion: 命令执行结果回调
    private func sendControlCommand(_ code: Int32, _ topic: String, completion: ((Result<Void, AppError>) -> Void)? = nil) {
        let timestamp = Date().timeIntervalSince1970
        var setControlParam = Ars_V1_SetControlParam()
        setControlParam.header = Ars_V1_Header()
        setControlParam.header.seq = 1
        setControlParam.header.timestamp = Int64(timestamp)
        setControlParam.header.type = .notify
        setControlParam.code = code
        
        
        mqttClient.publishMessage(
            topicTemplate: topic,
            protoMessage: setControlParam
        ) { [weak self] result in
            DispatchQueue.main.async {
                // 回调给调用者
                completion?(result)
                
                // 同时通过 delegate 通知
                if let self = self {
                    self.delegate?.sdk(self, didReceiveControlCommandResult: result)
                }
            }
        }
    }
    
    /// 便捷方法：开始采集
    public func startCapture(completion: ((Result<Void, AppError>) -> Void)? = nil) {
        sendControlCommand(1, ProtoTopics.setControlParam, completion: completion)
    }
    
    /// 便捷方法：停止采集
    public func stopCapture(completion: ((Result<Void, AppError>) -> Void)? = nil) {
        sendControlCommand(0, ProtoTopics.setControlParam, completion: completion)
    }
    
    /// 便捷方法：拍照
    public func takePhoto(completion: ((Result<Void, AppError>) -> Void)? = nil) {
        sendControlCommand(2, ProtoTopics.setControlParam, completion: completion)
    }
}
#endif
