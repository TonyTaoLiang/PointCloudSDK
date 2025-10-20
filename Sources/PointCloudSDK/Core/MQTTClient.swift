//
//  MQTTClient.swift
//  PointCloudSDK
//
//  Created by chenying on 2025/10/17.
//

#if os(iOS)

import Foundation
@_implementationOnly import CocoaMQTT
@_implementationOnly import SwiftProtobuf
import Combine
import Network

class MQTTClient {
    static let shared = MQTTClient()

    // 从原代码保留的连接状态 publisher
    private let connectionStatusSubject = PassthroughSubject<Bool, Never>()
    var connectionStatusPublisher: AnyPublisher<Bool, Never> {
        connectionStatusSubject.eraseToAnyPublisher()
    }
    private func updateConnectionStatus(_ connected: Bool) {
        DispatchQueue.main.async {
            self.connectionStatusSubject.send(connected)
        }
    }

    // message handling context：MessageHandlers 会通过这个上下文把解析好的数据推回 SDK（而不是 dispatch 到 Store）
    weak var messageContext: MessageHandlingContext?

    private var mqttClient: CocoaMQTT?
    private var sn: String = ""
    private var host: String = ""
    private var port: UInt16 = 1883
    var handlers: [String: MessageHandler] = [:]

    // 消息节流
    private var lastPointCloudTime: Date?
    private let minProcessingInterval: TimeInterval = 1
    private var heartbeatTimer: DispatchSourceTimer?

    private init() {}

    func configure(sn: String, host: String, port: UInt16 = 1883) {
        disconnect()
        self.sn = sn
        self.host = host
        self.port = port
        setupMQTTClient()
    }

    private func setupMQTTClient() {
        DebugPrint("Start Connecting")
        let clientID = loadOrGenerateClientID()
        mqttClient = CocoaMQTT(clientID: clientID, host: host, port: port)
        mqttClient?.username = "Rayzoom"
        mqttClient?.password = "12345678"
        mqttClient?.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
        mqttClient?.keepAlive = 60
        mqttClient?.delegate = self
        let _ = mqttClient?.connect()
    }

    func disconnect() {
        stopHeartbeat()
        mqttClient?.delegate = nil
        mqttClient?.disconnect()
        mqttClient = nil
        self.updateConnectionStatus(false)
    }

    private func startHeartbeat() {
        stopHeartbeat()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        timer.schedule(deadline: .now(), repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self = self, let mqttClient = self.mqttClient else { return }
            let topic = ProtoTopics.heartbeatSet.replacingOccurrences(of: "{SN}", with: self.sn).replacingOccurrences(of: "{ClientID}", with: mqttClient.clientID)
            var basicString = Ars_V1_BasicString()
            basicString.data = mqttClient.clientID
            MQTTClient.shared.publishMessage(topicTemplate: topic, protoMessage: basicString) { _ in }
        }
        heartbeatTimer = timer
        timer.resume()
    }

    private func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    func loginRequest() {
        guard let mqttClient = self.mqttClient else { return }
        let topic = ProtoTopics.loginSet.replacingOccurrences(of: "{SN}", with: sn)
        var basicString = Ars_V1_BasicString()
        basicString.data = mqttClient.clientID
        MQTTClient.shared.publishMessage(topicTemplate: topic, protoMessage: basicString) { _ in }
    }

    func loginSuccess() {
        updateConnectionStatus(true)
        startHeartbeat()
    }

    private func loadOrGenerateClientID() -> String {
        if let existing = UserDefaults.standard.string(forKey: "MQTTClientID") {
            return existing
        }
        let newID = "iOS-" + UUID().uuidString
        UserDefaults.standard.set(newID, forKey: "MQTTClientID")
        return newID
    }

    func subscribeAndRegisterHandlers() {
        self.handlers = [
            ProtoTopics.investigationAck.replacingOccurrences(of: "{SN}", with: sn): InvestigationAckHandler(),
            ProtoTopics.pointCloud.replacingOccurrences(of: "{SN}", with: sn) : PointCloudHandler(context: messageContext),
            ProtoTopics.pointCloudLite : PointCloudHandler(context: messageContext),
            ProtoTopics.statusAck : StatusHandler(context: messageContext),
            ProtoTopics.shootAck : shootResponseHandler(context: messageContext),
            ProtoTopics.loginAck.replacingOccurrences(of: "{SN}", with: sn).replacingOccurrences(of: "{ClientID}", with: mqttClient!.clientID) : LoginResponseHandler(context: messageContext)
        ]

        // subscribe topics
        for topic in handlers.keys {
            mqttClient?.subscribe(topic)
        }
    }

    // MARK: Publish
    func publishMessage<T: SwiftProtobuf.Message>(topicTemplate: String, protoMessage: T, qos: CocoaMQTTQoS = .qos0, retained: Bool = false, completion: @escaping (Result<Void, AppError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var topic = topicTemplate
            if topicTemplate.contains("{SN}") {
                topic = topicTemplate.replacingOccurrences(of: "{SN}", with: self.sn)
            }

            do {
                let payload = try protoMessage.serializedData()
                let byteArray: [UInt8] = Array(payload)
                let message = CocoaMQTTMessage(topic: topic, payload: byteArray, qos: qos, retained: retained)
                guard let mqttClient = self.mqttClient else {
                    throw AppError.mqttClientNotConnected
                }
                mqttClient.publish(message)
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                let appError: AppError
                if let protoError = error as? SwiftProtobuf.BinaryEncodingError {
                    appError = .serializationFailed(reason: protoError.localizedDescription)
                } else {
                    appError = .mqttPublishFailed(reason: error.localizedDescription)
                }
                DispatchQueue.main.async { completion(.failure(appError)) }
            }
        }
    }

    // MARK: Handling incoming messages
    func handleMessage(topic: String, payload: Data) {
        // 节流 dense_map
        if topic.contains("dense_map") {
            let now = Date()
            if let lastTime = lastPointCloudTime, now.timeIntervalSince(lastTime) < minProcessingInterval {
                return
            }
            lastPointCloudTime = now
        }

        if let handler = handlers[topic] {
            handler.handleMessage(payload: payload)
        } else {
            DebugPrint("没有找到处理策略: \(topic)")
        }
    }
}

// MARK: CocoaMQTTDelegate
extension MQTTClient: CocoaMQTTDelegate {
    
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        DebugPrint("didConnectAck received: \(ack)")
        if ack == .accept {
            DebugPrint("MQTT connected")
            subscribeAndRegisterHandlers()
            loginRequest()
        } else {
            disconnect()
        }
    }
    func mqtt(_ mqtt: CocoaMQTT, didFailToConnectWithError error: Error) {
        DebugPrint("MQTT connection failed with error: \(error)")
        disconnect()
    }
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        if !message.topic.contains("heartbeat") {
            DebugPrint("Published message: \(message) to topic: \(message.topic)")
        }
    }
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        handleMessage(topic: message.topic, payload: Data(bytes: message.payload, count: message.payload.count))
    }
    func mqtt(_ mqtt: CocoaMQTT, didDisconnectWithError error: Error?) {
        if let e = error { DebugPrint("Disconnected with error: \(e.localizedDescription)") }
        disconnect()
    }
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        DebugPrint("DidDisconnected.....\(String(describing: err))")
        updateConnectionStatus(false)
        messageContext?.notifyConnectionStatus(false)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        
    }
    
}

#endif
