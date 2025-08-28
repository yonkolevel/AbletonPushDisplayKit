//
//  PushDisplayManagerProtocol.swift
//  AbletonPushDisplayKit
//
//  Created by Ricardo Abreu on 15/08/2022.
//

import Foundation

/// Protocol defining the interface for Push device display managers
/// Handles USB communication and connection management for Ableton Push devices
protocol PushDisplayManagerProtocol {
    var isConnected: Bool { get }
    func connect(completion: @escaping (Result<Bool, Error>) -> Void)
    func connect(to device: PushDevice, completion: @escaping (Result<Bool, Error>) -> Void)
    func sendPixels(pixels: [UInt8])
    func disconnect()
}
