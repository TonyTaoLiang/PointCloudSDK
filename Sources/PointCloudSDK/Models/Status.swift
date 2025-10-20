//
//  Status.swift
//  PointCloudSDK
//
//  Created by chenying on 2025/10/17.
//

import Foundation

public struct Status: OptionSet {
    public let rawValue: Int32
    
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let unavailable   = Status(rawValue: 0)  // bit0: 不可用
    public static let continuous    = Status(rawValue: 1)  // bit1: 连续模式
    public static let fixedPoint    = Status(rawValue: 2)  // bit2: 定点模式
    public static let lowDiskSpace  = Status(rawValue: 4)  // bit4: 磁盘容量低
    public static let idle          = Status(rawValue: 8)  // bit8: 空闲

    public static let none: Status = []
    public static let all: Status  = [.unavailable, .continuous, .fixedPoint, .lowDiskSpace, .idle]
}

