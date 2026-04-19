//
//  PushViewController+Notifications.swift
//  AbletonPushDisplayKit
//
//  Created by Ricardo Abreu on 15/08/2022.
//

import Foundation


public extension Notification.Name {
    /// Hint to the view controller that the rendered view's state may have
    /// changed. Prefer `PushViewController.setNeedsUpdate()` in new code.
    static let pushViewShouldUpdate = Notification.Name(rawValue: "pushViewShouldUpdate")

    /// Posted when a Push device connects. Prefer observing
    /// `PushDisplayManager.$isConnected` in new code.
    static let pushDeviceConnected = Notification.Name(rawValue: "pushDeviceConnected")

    /// Posted when the Push device disconnects. Prefer observing
    /// `PushDisplayManager.$isConnected` in new code.
    static let pushDeviceDisconnected = Notification.Name(rawValue: "pushDeviceDisconnected")
}
