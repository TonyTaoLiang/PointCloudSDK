//
//  MQTTMessageHandler.swift
//  PointCloudSDK
//
//  Created by chenying on 2025/10/17.
//

#if os(iOS)
import Foundation

protocol MessageHandler {
    func handleMessage(payload: Data)
}

class InvestigationAckHandler: MessageHandler {
    func handleMessage(payload: Data) {
        DispatchQueue.global(qos: .default).async {
            if let ack = try? Ars_V1_Response(serializedBytes: payload) {
                DebugPrint("收到应答：\(ack)")
            }
        }
    }
}

class PointCloudHandler: MessageHandler {
    weak var context: MessageHandlingContext?
    private let queue = DispatchQueue(label: "com.pointcloud.processing", qos: .utility, attributes: .concurrent)
    init(context: MessageHandlingContext?) {
        self.context = context
    }
    func handleMessage(payload: Data) {
        queue.async {
            do {
                let proto = try Ars_V1_PointCloudLite(serializedBytes: payload)
                if let points = PointCloudParser.parse(from: proto) {
                    // 将解析后的点云数据推回到 SDK（由 SDK 决定如何存储/上报）
                    self.context?.pushPointCloud(points)
                }
            } catch {
                DebugPrint("PointCloud 解析失败: \(error)")
            }
        }
    }
}

class StatusHandler: MessageHandler {
    weak var context: MessageHandlingContext?
    private let queue = DispatchQueue(label: "com.status.processing", qos: .userInitiated, attributes: .concurrent)
    init(context: MessageHandlingContext?) {
        self.context = context
    }
    
    func handleMessage(payload: Data) {
        queue.async {
            do {
                let proto = try Ars_V1_Status(serializedBytes: payload)
                DebugPrint("ReceiveStatus:------ \(proto.controlstatus)")
                let status = Status(rawValue: proto.controlstatus)
                self.context?.notifyDeviceStatus(status)
            } catch {
                DebugPrint("解析失败: \(error)")
            }
        }
    }
}

class shootResponseHandler: MessageHandler {
    
    weak var context: MessageHandlingContext?
    private let queue = DispatchQueue(label: "com.shoot.processing", qos: .userInteractive, attributes: .concurrent)
    init(context: MessageHandlingContext?) {
        self.context = context
    }
    
    func handleMessage(payload: Data) {
        queue.async {
            do {
                let proto = try Ars_V1_ShootResponse(serializedBytes: payload)
                self.context?.notifyPhotoResponse(proto.isHdr, proto.status)
            } catch {
                DebugPrint("解析失败: \(error)")
            }
        }
    }
}

// LoginResponseHandler
class LoginResponseHandler: MessageHandler {
    weak var context: MessageHandlingContext?
    init(context: MessageHandlingContext?) { self.context = context }
    private let queue = DispatchQueue(label: "com.login.processing", qos: .default, attributes: .concurrent)
    func handleMessage(payload: Data) {
        queue.async {
            do {
                let res = try Ars_V1_Response(serializedBytes: payload)
                if res.code == 0 {
                    MQTTClient.shared.loginSuccess()
                    self.context?.notifyConnectionStatus(true)
                } else {
                    DebugPrint("登录失败: \(res.reason)")
                    MQTTClient.shared.disconnect()
                    self.context?.notifyConnectionStatus(false)
                }
            } catch {
                DebugPrint("解析失败: \(error)")
            }
        }
    }
}

#endif

