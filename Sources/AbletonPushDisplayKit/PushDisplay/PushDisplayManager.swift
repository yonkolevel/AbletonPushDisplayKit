import Foundation
import Combine

public enum PushDevice {
    case push2
    case push3
    case push3SA

    var productID: Int {
        switch self {
        case .push2: return 6503
        case .push3: return 6504
        case .push3SA: return 6505
        }
    }

    public var description: String {
        switch self {
        case .push2: return "Push 2"
        case .push3: return "Push 3"
        case .push3SA: return "Push 3 SA"
        }
    }
}

let ABLETON_VENDOR_ID: Int = 10626
let PUSH_BULK_EP_OUT: UInt8 = 0x01
let TRANSFER_TIMEOUT: UInt32 = 1000

var frameHeader: [UInt8] = [
    0xFF, 0xCC, 0xAA, 0x88,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00
]

public class PushDisplayManager: PushDisplayManagerProtocol {
    private var deviceInterface: USBInterfaceInterface?
    @Published public var isConnected = false
    @Published public var connectedDevice: PushDevice?
    private var deviceObserver: Any?
    private var reconnectTimer: Timer?
    private var isConnecting = false
    private var lastDisconnectTime: Date?

    public init() {
        startObservingDevices()
        tryConnect()
        startReconnectPolling()
    }

    private func startReconnectPolling() {
        DispatchQueue.main.async { [weak self] in
            self?.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self, !self.isConnected else { return }
                self.tryConnect()
            }
            RunLoop.main.add(self!.reconnectTimer!, forMode: .common)
        }
    }

    private func startObservingDevices() {
        do {
            let matchingDict = USBDeviceInterface.matchingDictionary(
                vendorIdentifier: ABLETON_VENDOR_ID,
                productIdentifier: nil
            )
            deviceObserver = try USBDeviceInterface.observeDeviceList(
                matchingDictionary: matchingDict,
                notificationNames: [kIOFirstMatchNotification, kIOTerminatedNotification],
                queue: .main
            ) { [weak self] notificationName, _ in
                self?.handleDeviceNotification(name: notificationName)
            }
        } catch {
            NSLog("PushDisplayManager: Failed to start device observation: \(error)")
        }
    }

    private func handleDeviceNotification(name: String) {
        NSLog("PushDisplayManager: Notification received: \(name), isConnected=\(isConnected)")

        if name == kIOTerminatedNotification {
            if isConnected {
                handleDisconnection()
            }
        }

        // Always try to connect after any device change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            NSLog("PushDisplayManager: Checking for devices after notification...")
            self.tryConnect()
        }
    }

    private func handleDisconnection() {
        NSLog("PushDisplayManager: Disconnected")
        deviceInterface = nil
        isConnected = false
        connectedDevice = nil
        lastDisconnectTime = Date()
    }

    private func tryConnect() {
        guard !isConnected && !isConnecting else { return }

        if let lastDisconnect = lastDisconnectTime,
           Date().timeIntervalSince(lastDisconnect) < 1.0 {
            return
        }

        let devices = PushDisplayManager.detectConnectedPushDevices()
        guard let device = devices.first else {
            NSLog("PushDisplayManager: No Push devices found")
            return
        }

        isConnecting = true
        NSLog("PushDisplayManager: Connecting to \(device.description)...")

        do {
            let devInterface = try USBDeviceInterface.create(
                vendorIdentifier: ABLETON_VENDOR_ID,
                productIdentifier: device.productID
            )
            let interfaceInterface = try devInterface.createInterfaceInterface()
            try interfaceInterface.open(seize: true)

            self.deviceInterface = interfaceInterface
            self.connectedDevice = device
            self.isConnected = true
            NSLog("PushDisplayManager: Connected to \(device.description)")
        } catch {
            NSLog("PushDisplayManager: Failed to connect: \(error)")
        }

        isConnecting = false
    }

    func connect(completion: @escaping (Result<Bool, Error>) -> Void) {
        tryConnect()
        completion(.success(isConnected))
    }

    func connect(to device: PushDevice, completion: @escaping (Result<Bool, Error>) -> Void) {
        do {
            let devInterface = try USBDeviceInterface.create(
                vendorIdentifier: ABLETON_VENDOR_ID,
                productIdentifier: device.productID
            )
            let interfaceInterface = try devInterface.createInterfaceInterface()
            try interfaceInterface.open(seize: true)
            self.deviceInterface = interfaceInterface
            self.connectedDevice = device
            self.isConnected = true
            completion(.success(true))
        } catch {
            completion(.failure(error))
        }
    }

    @objc public func sendPixels(pixels: [UInt8]) {
        guard isConnected, let interface = deviceInterface else { return }

        do {
            try interface.openAndPerform {
                try interface.write(frameHeader, pipe: Int(PUSH_BULK_EP_OUT))
                try interface.write(pixels, pipe: Int(PUSH_BULK_EP_OUT),
                                  noDataTimeout: TimeInterval(TRANSFER_TIMEOUT),
                                  completionTimeout: TimeInterval(TRANSFER_TIMEOUT))
            }
        } catch {
            NSLog("PushDisplayManager: Send failed, disconnecting")
            handleDisconnection()
        }
    }

    static public func detectConnectedPushDevices() -> [PushDevice] {
        var connectedDevices: [PushDevice] = []
        for device in [PushDevice.push2, .push3, .push3SA] {
            do {
                let _ = try USBDeviceInterface.create(
                    vendorIdentifier: ABLETON_VENDOR_ID,
                    productIdentifier: device.productID
                )
                connectedDevices.append(device)
            } catch {}
        }
        return connectedDevices
    }

    func disconnect() {
        try? deviceInterface?.close()
        deviceInterface?.release()
        deviceInterface = nil
        isConnected = false
        connectedDevice = nil
    }

    deinit {
        deviceObserver = nil
        disconnect()
    }
}
