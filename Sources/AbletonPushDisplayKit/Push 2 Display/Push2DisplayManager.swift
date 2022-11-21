import Foundation
import AppKit
import SwiftUI


let ABLETON_VENDOR_ID:Int = 2982
let PUSH2_PRODUCT_ID: Int = 1967
let PUSH2_BULK_EP_OUT:UInt8 = 0x01
let TRANSFER_TIMEOUT:UInt32  = 1000 // milliseconds


let kLineSize      = 2048; // total line size
let kLineCountPerSendBuffer   = 8

let kSendBufferCount = 3;
let kSendBufferSize  = kLineCountPerSendBuffer * kLineSize; // buffer length in bytes

func createRGBA( _ r:UInt8,  _ g:UInt8,  _ b:UInt8,  _ a:UInt8)->UInt8
{
    return (r<<24) | (g<<16) | b | a
}


func getPixelsForPush()->[UInt8]{
    let xOrMasks: [UInt8] = [0xe7, 0xf3, 0xe7, 0xff];
    let displayPitch = 1920 + 128;
    var xorOffset: UInt8 = 0;
    var processedImage: [UInt8] = [UInt8].init(repeating: 0, count: displayPitch * 160);
    
    for y in 0..<160 {
        for x  in 0..<960 {
            let sourceByte = (y * 960 + x) * 4;
            
            let red = UInt8.random(in: 0..<255);
            let green =  UInt8.random(in: 0..<255);
            let blue =  UInt8.random(in: 0..<255);
            
            let destByte = y * displayPitch + x * 2;
            processedImage[Int(destByte)] = (red >> 3) ^ UInt8(xOrMasks[Int(xorOffset)]);
            xorOffset = (xorOffset + 1) % 4;
            processedImage[destByte + 1] =
            ((blue & 0xf8) | (green >> 5)) ^ UInt8(xOrMasks[Int(xorOffset)]);
            xorOffset = (xorOffset + 1) % 4;
        }
    }
    
    return processedImage;
}

var frameHeader:[UInt8] = [
    0xFF, 0xCC, 0xAA, 0x88,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00
]


class Push2DisplayManager: Push2DisplayManagerProtocol {
    private var deviceInterface: USBInterfaceInterface!
    @Published var isConnected = false
    private var timer = Timer()
    init() {
        
    }
    
    func connect(completion: @escaping (Result<Bool, Error>) -> Void) {
        do {
            let deviceInterface = try USBDeviceInterface.create(vendorIdentifier: 10626, productIdentifier: 6503)
            let interfaceInterface = try deviceInterface.createInterfaceInterface()
            try interfaceInterface.open(seize: true)
            self.deviceInterface = interfaceInterface
            self.isConnected = true
            completion(.success(true))
        }catch let error  {
            print(error)
        }
    }
    
    
    @objc private func sendPixels(pixels: [UInt8]) {
        guard isConnected, let interface = self.deviceInterface else {
            return
        }
        
        do {
            try interface.open(seize: true)
            try interface.openAndPerform {
                try interface.write(frameHeader, pipe: Int(PUSH2_BULK_EP_OUT))
                try interface.write(pixels, pipe: Int(PUSH2_BULK_EP_OUT), noDataTimeout: TimeInterval(TRANSFER_TIMEOUT), completionTimeout: TimeInterval(TRANSFER_TIMEOUT))
            }
            
        }catch let error  {
            print(error)
        }
    }
    
    
    func updateDisplay(image: NSBitmapImageRep) {
        self.timer.invalidate()
        
        
        let data = PixelExtractor.getPixelsForPush(bitmap: image)
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1/12, repeats: true) { timer in
                DispatchQueue.global(qos: .userInteractive).async {
                    self.sendPixels(pixels: data)
                }
            }
            
            RunLoop.current.add(self.timer, forMode: .common)
        }
    }
}
