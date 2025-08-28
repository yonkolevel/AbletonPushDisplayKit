import Foundation

// MARK: - Device Configuration

public enum PushDevice {
    case push2
    case push3
    case push3SA
    
    var productID: Int {
        switch self {
        case .push2: return 6503 // 0x1967
        case .push3: return 6504 // 0x1968
        case .push3SA: return 6505 // 0x1969
        }
    }
    
    var description: String {
        switch self {
        case .push2: return "Push 2"
        case .push3: return "Push 3"
        case .push3SA: return "Push 3 SA"
        }
    }
}

// MARK: - Constants

let ABLETON_VENDOR_ID: Int = 10626  // 0x2982
let PUSH_BULK_EP_OUT: UInt8 = 0x01
let TRANSFER_TIMEOUT: UInt32 = 1000

var frameHeader: [UInt8] = [
    0xFF, 0xCC, 0xAA, 0x88,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00
]

// MARK: - Display Manager
// Manages the USB communication with Ableton Push devices
public class PushDisplayManager: PushDisplayManagerProtocol {
    private var deviceInterface: USBInterfaceInterface!
    @Published var isConnected = false
    private var targetDevice: PushDevice = .push3SA
    
    init() {
        
    }
    
    init(device: PushDevice) {
        self.targetDevice = device
    }
    
    func connect(completion: @escaping (Result<Bool, Error>) -> Void) {
        connect(to: targetDevice, completion: completion)
    }
    
    func connect(to device: PushDevice, completion: @escaping (Result<Bool, Error>) -> Void) {
        do {
            let deviceInterface = try USBDeviceInterface.create(
                vendorIdentifier: ABLETON_VENDOR_ID,
                productIdentifier: device.productID
            )
            let interfaceInterface = try deviceInterface.createInterfaceInterface()
            try interfaceInterface.open(seize: true)
            self.deviceInterface = interfaceInterface
            self.targetDevice = device
            self.isConnected = true
            print("Connected to \(device.description)")
            completion(.success(true))
        } catch let error {
            print("Failed to connect to \(device.description): \(error)")
            completion(.failure(error))
        }
    }
    
    @objc public func sendPixels(pixels: [UInt8]) {
        guard isConnected, let interface = self.deviceInterface else {
            return
        }
        
        do {
            try interface.openAndPerform {
                try interface.write(frameHeader, pipe: Int(PUSH_BULK_EP_OUT))
                try interface.write(pixels, pipe: Int(PUSH_BULK_EP_OUT),
                                  noDataTimeout: TimeInterval(TRANSFER_TIMEOUT),
                                  completionTimeout: TimeInterval(TRANSFER_TIMEOUT))
            }
        } catch let error {
            print("Failed to send pixels to device: \(error)")
        }
    }
    
    
    // MARK: - Device Detection
    
    static public func detectConnectedPushDevices() -> [PushDevice] {
        var connectedDevices: [PushDevice] = []
        let allDevices: [PushDevice] = [.push2, .push3, .push3SA]
        
        for device in allDevices {
            do {
                let _ = try USBDeviceInterface.create(
                    vendorIdentifier: ABLETON_VENDOR_ID,
                    productIdentifier: device.productID
                )
                connectedDevices.append(device)
            } catch {
                // Device not connected, continue checking other devices
            }
        }
        
        return connectedDevices
    }
    
    func disconnect() {
        do {
            try deviceInterface?.close()
            deviceInterface.release()
        } catch {
            print("Error disconnecting from device: \(error)")
        }
        deviceInterface = nil
        isConnected = false
    }
    
    deinit {
        disconnect()
    }
}
