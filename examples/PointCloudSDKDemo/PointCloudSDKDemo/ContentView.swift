//
//  ContentView.swift
//  PointCloudSDKDemo
//
//  Created by chenying on 2025/10/20.
//

import SwiftUI
import PointCloudSDK

struct ContentView: View {
    var body: some View {
        VStack {
            Text("PointCloud Demo")
                .font(.headline)
                .padding(.top, 40)
            Button {
                PointCloudManager.shared.connect(sn: "30224014", host: "192.168.201.1", port: 1883)
            } label: {
                Text("Connect")
            }.padding(.top, 20)
            Button {
                PointCloudManager.shared.startCapture { result in
                    switch result {
                    case .success:
                        print("StartCapture Success")
                    case .failure(let error):
                        print("StartCapture Failed: \(error)")
                    }
                }
            } label: {
                Text("StartCapture")
            }.padding(.top, 20)
            Button {
                PointCloudManager.shared.stopCapture { result in
                    switch result {
                    case .success:
                        print("StopCapture Success")
                    case .failure(let error):
                        print("StopCapture Failed: \(error)")
                    }
                }
            } label: {
                Text("StopCapture")
            }.padding(.top, 20)
            PointCloudManager.shared.createPointCloudView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
