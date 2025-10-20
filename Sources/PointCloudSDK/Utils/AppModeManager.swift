//
//  AppModeManager.swift
//  Landmarks
//
//  Created by chenying on 2025/7/11.
//
#if os(iOS)

import Foundation

enum AppMode {
    case realtime
    case replay
}

class AppModeManager {
    static let shared = AppModeManager()
    
    private init() {}

    // 当前 App 模式（默认实时）
    var mode: AppMode = .realtime

    var isRealtimeMode: Bool {
        return mode == .realtime
    }

    func switchToRealtime() {
        mode = .realtime
        DebugPrint("🚀 切换到 实时模式")
    }

    func switchToReplay() {
        mode = .replay
        DebugPrint("📼 切换到 回放模式")
    }
}


#endif
