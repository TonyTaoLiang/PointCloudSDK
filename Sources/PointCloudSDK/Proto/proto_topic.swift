//
//  proto_topic.swift
//  Landmarks
//
//  Created by chenying on 2025/2/21.
//

import Foundation

enum ProtoTopics {
    static let investigationSet = "/server/{SN}/control/investigation/set"
    static let investigationAck = "/{SN}/server/control/investigation/ack"
    static let pointCloud = "/{SN}/server/draco/dense_map/ack"
    static let pointCloudLite = "/JMK/server/dense_map/ack"
    static let setControlParam = "/server/JMK/control/device/set"
    static let statusAck = "/JMK/server/status/base/ack"
    static let shootAck = "/JMK/server/shoot/ack"
    static let projectSet = "/server/{SN}/control/projectmanager/set"
    static let projectAck = "/{SN}/server/control/projectmanager/ack"
    static let loginSet = "/server/{SN}/control/login/set"
    static let loginAck = "/{ClientID}/{SN}/server/control/login/ack"
    static let logoutSet = "/server/{SN}/control/logout/set"
    static let logoutAck = "/{ClientID}/{SN}/server/control/logout/ack"
    static let heartbeatSet = "/{ClientID}/server/{SN}/control/heartbeat/set"
    static let recordFinishStatusAck = "/{SN}/server/record_finish/status/ack"
    static let recordStatusAck = "/{SN}/server/status/record/ack"
    static let fileTransmitAck = "/{SN}/server/transmit/file/ack"
    static let controlTransmitSet = "/server/{SN}/control/transmit/set"
    static let controlTransmitAck = "/{SN}/server/control/transmit/ack"
    static let controlImageSet = "/server/{SN}/control/image/set"
    static let controlImageAck = "/{SN}/server/control/image/ack"
}
