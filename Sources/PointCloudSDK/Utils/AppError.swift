//
//  AppError.swift
//  PointCloudSDK
//
//  Created by chenying on 2025/10/17.
//
#if os(iOS)

import Foundation

public enum AppError: Error, Identifiable {
    public var id: String { localizedDescription }
    case isSendingCommand
    case mqttClientNotConnected
    case serializationFailed(reason: String)
    case mqttPublishFailed(reason: String)
}

extension AppError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .isSendingCommand: return "正在发送指令"
        case .mqttClientNotConnected: return "MQTT 客户端未连接"
        case .serializationFailed(let reason): return "协议序列化失败: \(reason)"
        case .mqttPublishFailed(let reason): return "MQTT 发送失败: \(reason)"
        }
    }
}

#endif
