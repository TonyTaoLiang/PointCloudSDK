//
//  UIKitWrapper.swift
//  PointCloudSDK
//
//  Created by chenying on 2025/10/17.
//

//import SwiftUI
//import UIKit
//
//@objc public class PointCloudUIView: UIView {
//    private var hostingController: UIHostingController<PointCloudDracoView>?
//
//    public init(view: PointCloudDracoView) {
//        super.init(frame: .zero)
//        let host = UIHostingController(rootView: view)
//        hostingController = host
//        host.view.backgroundColor = .clear
//        addSubview(host.view)
//        host.view.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            host.view.topAnchor.constraint(equalTo: topAnchor),
//            host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
//            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
//            host.view.trailingAnchor.constraint(equalTo: trailingAnchor)
//        ])
//    }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//}
