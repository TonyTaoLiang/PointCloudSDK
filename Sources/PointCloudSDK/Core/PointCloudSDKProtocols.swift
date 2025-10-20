//
//  PointCloudSDKProtocols.swift
//  PointCloudSDK
//
//  Created by chenying on 2025/10/17.
//
#if os(iOS)

import Foundation

public protocol PointCloudSDKDelegate: AnyObject {
    // 连接状态
    func sdk(_ sdk: PointCloudManager, connectionStatusChanged connected: Bool)
    // 设备状态
    func sdk(_ sdk: PointCloudManager, deviceStatusChanged status: Status)
    // 拍照响应
    func sdk(_ sdk: PointCloudManager, didReceivePhotoResponse isHDR: Bool, status: Int32)
    // 点云数据到达（原始点数组，主线程回调）
    func sdk(_ sdk: PointCloudManager, didReceivePointCloud points: [PointCloudPoint])
    // 控制命令结果（新增）
    func sdk(_ sdk: PointCloudManager, didReceiveControlCommandResult result: Result<Void, AppError>)
}

// SDK 内部用于 MessageHandler 与 SDK 交互的上下文（非 public）
protocol MessageHandlingContext: AnyObject {
    func pushPointCloud(_ points: [PointCloudPoint])
    func notifyConnectionStatus(_ connected: Bool)
    func notifyDeviceStatus(_ status: Status)
    func notifyPhotoResponse(_ isHDR: Bool, _ status: Int32)
}

#endif
