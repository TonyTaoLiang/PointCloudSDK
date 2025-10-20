//
//  Logger.swift
//  PointCloudSDK
//
//  Created by chenying on 2025/10/17.
//
#if os(iOS)

import Foundation

func DebugPrint(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let filename = URL(fileURLWithPath: file).lastPathComponent
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let timestamp = dateFormatter.string(from: Date())
    print("[\(timestamp)][\(filename):\(line)]", items)
    #endif
}

#endif
