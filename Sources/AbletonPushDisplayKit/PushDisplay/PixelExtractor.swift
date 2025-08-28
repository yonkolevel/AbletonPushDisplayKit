import Cocoa
import SwiftUI

typealias Pixel = UInt8

class PixelExtractor {
    public static let DISPLAY_WIDTH = 960
    public static let DISPLAY_HEIGHT = 160
    
    static func getPixelsForPush(bitmap: NSBitmapImageRep)->[UInt8]{
        let xOrMasks:[UInt8] = [0xe7, 0xf3, 0xe7, 0xff];
        let displayPitch = 1920 + 128;
        var xorOffset = 0;
        var processedImage: [UInt8] = [UInt8].init(repeating: 0, count: displayPitch * DISPLAY_HEIGHT);

        for y in 0..<DISPLAY_HEIGHT {
            for x  in 0..<DISPLAY_WIDTH {
                guard let color = bitmap.colorAt(x: x, y: y),
                      let colorComponents = color.components() else {
                    continue
                }
                let red = Pixel(colorComponents.1.red)
                let green = Pixel(colorComponents.1.green)
                let blue = Pixel(colorComponents.1.blue)
                
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
    
    
    // MARK: - Test Functions
    
    /// Create a test bitmap filled with specified color
    static func createTestBitmap(color: NSColor) -> NSBitmapImageRep {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: DISPLAY_WIDTH,
                                     pixelsHigh: DISPLAY_HEIGHT,
                                     bitsPerSample: 8,
                                     samplesPerPixel: 4,
                                     hasAlpha: true,
                                     isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0,
                                     bitsPerPixel: 0)!
        
        // Convert color to device RGB colorspace BEFORE setting
        let deviceColor = color.usingColorSpace(.deviceRGB) ?? NSColor.black
        
        for y in 0..<DISPLAY_HEIGHT {
            for x in 0..<DISPLAY_WIDTH {
                bitmap.setColor(deviceColor, atX: x, y: y)
            }
        }
        
        return bitmap
    }
    
    static func createTestBitmapDirect(red: UInt8, green: UInt8, blue: UInt8) -> NSBitmapImageRep {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: DISPLAY_WIDTH,
                                     pixelsHigh: DISPLAY_HEIGHT,
                                     bitsPerSample: 8,
                                     samplesPerPixel: 4,
                                     hasAlpha: true,
                                     isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0,
                                     bitsPerPixel: 0)!
        
        guard let bitmapData = bitmap.bitmapData else {
            print("No bitmap data!")
            return bitmap
        }
        
        for y in 0..<DISPLAY_HEIGHT {
            for x in 0..<DISPLAY_WIDTH {
                let pixelIndex = (y * bitmap.bytesPerRow + x * 4)
                
                if pixelIndex + 3 < bitmap.bytesPerRow * DISPLAY_HEIGHT {
                    bitmapData[pixelIndex] = red     // R
                    bitmapData[pixelIndex + 1] = green   // G
                    bitmapData[pixelIndex + 2] = blue    // B
                    bitmapData[pixelIndex + 3] = 255     // A (full opacity)
                }
            }
        }
        
        
        return bitmap
    }
    
    /// Test with pure colors
    static func testPureColors() -> [String: [UInt8]] {
        return [
            "red": getPixelsForPush(bitmap: createTestBitmap(color: .red)),
            "green": getPixelsForPush(bitmap: createTestBitmap(color: .green)),
            "blue": getPixelsForPush(bitmap: createTestBitmap(color: .blue)),
            "white": getPixelsForPush(bitmap: createTestBitmap(color: .white)),
            "black": getPixelsForPush(bitmap: createTestBitmap(color: .black))
        ]
    }
    
    
}
