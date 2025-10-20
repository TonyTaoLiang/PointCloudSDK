//
//  PointCloudParser.swift
//  Landmarks
//
//  Created by chenying on 2025/5/8.
//
#if os(iOS)

import Foundation

public struct PointCloudPoint: Equatable {
    
    var position: SIMD3<Float32>
    var color: SIMD3<Float32>
    
    init(position: SIMD3<Float32>, color: SIMD3<Float32>) {
        self.position = position
        self.color = color
    }
    
    init(x: Float, y: Float, z: Float, minZ: Float, maxZ: Float) {
        self.position = SIMD3<Float32>(Float32(x), Float32(y), Float32(z))
        
        // 计算归一化Z值
        let normalizedZ = (z - minZ) / (maxZ - minZ)
        
        // 在[0.33, 0.66]范围进行颜色插值
        let clampedZ = max(0.33, min(normalizedZ, 0.66))
        let ratio = (clampedZ - 0.33) / (0.66 - 0.33)
        
        // 颜色渐变：绿(0,1,0) -> 蓝(0,0,1)
        self.color = SIMD3<Float32>(
            0.0,          // R
            ratio,  // G
            1.0 - ratio       // B
        )
    }
    
    // MARK: - 数据解析逻辑
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.position == rhs.position && lhs.color == rhs.color
    }
}

struct ColorMap {
    // 热力图颜色映射（蓝->青->绿->黄->红）
    static func heatMapColor(normalized value: Float) -> (r: UInt8, g: UInt8, b: UInt8) {
        let clampedValue = max(0.0, min(1.0, value))
        
        let colors: [(Float, Float, Float)] = [
            (0.0, 0.0, 1.0),   // 蓝色
            (0.0, 1.0, 1.0),   // 青色
            (0.0, 1.0, 0.0),   // 绿色
            (1.0, 1.0, 0.0),   // 黄色
            (1.0, 0.0, 0.0)    // 红色
        ]
        
        let segment = 1.0 / Float(colors.count - 1)
        let index = Int(clampedValue / segment)
        let weight = (clampedValue - Float(index) * segment) / segment
        
        let c1 = colors[index]
        let c2 = colors[min(index + 1, colors.count - 1)]
        
        let r = c1.0 + weight * (c2.0 - c1.0)
        let g = c1.1 + weight * (c2.1 - c1.1)
        let b = c1.2 + weight * (c2.2 - c1.2)
        
        return (
            r: UInt8(r * 255),
            g: UInt8(g * 255),
            b: UInt8(b * 255)
        )
    }
}

class PointCloudParser {
    
    //前置采样减少数据量
    static func parse(from proto: Ars_V1_PointCloudLite) -> [PointCloudPoint]? {
        // 1. 早期采样 - 在解析前减少数据量
        guard let (rawPoints, minZ, maxZ) = parseWithEarlySampling(from: proto) else {
            return nil
        }
        
        // 2. 构建点云数据（使用Z值映射颜色）
        return rawPoints.map { point in
            return PointCloudPoint(
                x: point.x,
                y: point.y,
                z: point.z,
                minZ: minZ,
                maxZ: maxZ
            )
        }
    }
    
    // 带早期采样的解析方法
    private static func parseWithEarlySampling(from proto: Ars_V1_PointCloudLite) -> (
        points: [(x: Float, y: Float, z: Float)],
        minZ: Float,
        maxZ: Float
    )? {
        // 1. 检查必要字段
        guard let xIndex = findChannelIndex(fields: proto.fields, name: "x"),
              let yIndex = findChannelIndex(fields: proto.fields, name: "y"),
              let zIndex = findChannelIndex(fields: proto.fields, name: "z") else {
            DebugPrint("Error: Missing required fields (x/y/z)")
            return nil
        }
        
        // 2. 提取元数据
        let xOffset = Int(proto.fields[xIndex].offset)
        let yOffset = Int(proto.fields[yIndex].offset)
        let zOffset = Int(proto.fields[zIndex].offset)
        let pointStep = Int(proto.pointStep)
        let data = proto.data
        
        // 3. 计算总点数和采样策略
        let totalBytes = data.count
        let totalPoints = totalBytes / pointStep
        
        // 动态采样策略：
        // - 小点云（<1000点）：不采样
        // - 中等点云（1000-5000点）：每2点取1个
        // - 大点云（>5000点）：每4点取1个
//        let sampleStep: Int
//        switch totalPoints {
//        case ..<20000:
//            sampleStep = 1
//        case 20000..<50000:
//            sampleStep = 2
//        default:
//            sampleStep = AppConfig.sampleInterval
//        }
        // 实时采集不用采样，设备端已抽稀处理
        let sampleStep = AppConfig.earlySampleStep
        
        // 4. 遍历解析采样点
        var points = [(x: Float, y: Float, z: Float)]()
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        
        // 使用UnsafeBufferPointer提高性能
        data.withUnsafeBytes { bufferPtr in
            let baseAddress = bufferPtr.baseAddress!
            
            for i in stride(from: 0, to: totalPoints, by: sampleStep) {
                let byteOffset = i * pointStep
                
                // 检查数据边界
                guard byteOffset + pointStep <= totalBytes else { break }
                
                // 解析坐标
                let x = baseAddress.load(fromByteOffset: byteOffset + xOffset, as: Float.self)
                let y = baseAddress.load(fromByteOffset: byteOffset + yOffset, as: Float.self)
                let z = baseAddress.load(fromByteOffset: byteOffset + zOffset, as: Float.self)
                
                // 更新Z范围
                minZ = min(minZ, z)
                maxZ = max(maxZ, z)
                
                points.append((x, y, z))
            }
        }
        
        // 防止除零错误
        if maxZ <= minZ {
            maxZ = minZ + 1.0
        }
        
        return points.isEmpty ? nil : (points, minZ, maxZ)
    }
    
    
    private static func findChannelIndex(fields: [Ars_V1_PointField], name: String) -> Int? {
        return fields.firstIndex { $0.name.lowercased() == name.lowercased() }
    }
    
    // 解析RGB值
    private static func parseRGB(from proto: Ars_V1_PointCloudLite, at index: Int) -> (r: UInt8, g: UInt8, b: UInt8)? {
        guard let rgbIndex = findChannelIndex(fields: proto.fields, name: "rgb"),
              let _ = findChannelIndex(fields: proto.fields, name: "rgba") else {
            return nil
        }
        
        let offset = Int(proto.fields[rgbIndex].offset)
        let data = proto.data
        let pointStep = Int(proto.pointStep)
        let byteOffset = index * pointStep + offset
        
        guard byteOffset + 3 <= data.count else { return nil }
        
        return (
            r: data[byteOffset],
            g: data[byteOffset + 1],
            b: data[byteOffset + 2]
        )
    }
}

#endif
