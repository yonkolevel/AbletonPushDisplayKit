//
//  PushViewController+Notifications.swift
//  AbletonPushDisplayKit
//
//  Created by Ricardo Abreu on 15/08/2022.
//

import Foundation


public extension Notification.Name {
    static let pushViewShouldUpdate = Notification.Name(rawValue: "pushViewShouldUpdate")
    static let pushDeviceConnected = Notification.Name(rawValue: "pushDeviceConnected")
    static let pushDeviceDisconnected = Notification.Name(rawValue: "pushDeviceDisconnected")
}
