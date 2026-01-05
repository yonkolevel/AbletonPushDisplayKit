import Cocoa
import SwiftUI

typealias Pixel = UInt8

class PixelExtractor {
    public static let DISPLAY_WIDTH = 960
    public static let DISPLAY_HEIGHT = 160
    
    static func getPixelsForPush(bitmap: NSBitmapImageRep) -> [UInt8] {
        let displayPitch = 1920 + 128
        var processedImage = [UInt8](repeating: 0, count: displayPitch * DISPLAY_HEIGHT)

        guard let bitmapData = bitmap.bitmapData else {
            return processedImage
        }

        let bytesPerRow = bitmap.bytesPerRow
        let samplesPerPixel = bitmap.samplesPerPixel

        // XOR mask pattern: 0xE7, 0xF3, 0xE7, 0xFF (repeating)
        let xorMask: UInt32 = 0xFFE7F3E7

        processedImage.withUnsafeMutableBytes { destBuffer in
            let dest = destBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)

            for y in 0..<DISPLAY_HEIGHT {
                let srcRowStart = y * bytesPerRow
                let destRowStart = y * displayPitch
                var xorOffset = 0

                for x in 0..<DISPLAY_WIDTH {
                    let srcPixel = srcRowStart + x * samplesPerPixel
                    let red = bitmapData[srcPixel]
                    let green = bitmapData[srcPixel + 1]
                    let blue = bitmapData[srcPixel + 2]

                    // Convert RGB888 to BGR565 (Push display format) with XOR encoding
                    // BGR565: bits 15-11 = Blue, bits 10-5 = Green (6 bits), bits 4-0 = Red
                    // Little-endian bytes:
                    //   Byte 0: GGGRRRRR (low 3 bits of green + 5 bits of red)
                    //   Byte 1: BBBBBGGG (5 bits of blue + high 3 bits of green)
                    let destOffset = destRowStart + x * 2
                    let xorByte0 = UInt8((xorMask >> (xorOffset * 8)) & 0xFF)
                    xorOffset = (xorOffset + 1) & 3
                    let xorByte1 = UInt8((xorMask >> (xorOffset * 8)) & 0xFF)
                    xorOffset = (xorOffset + 1) & 3

                    let r5 = red >> 3           // 5 bits of red
                    let g6 = green >> 2         // 6 bits of green
                    let b5 = blue >> 3          // 5 bits of blue

                    dest[destOffset] = ((g6 << 5) | r5) ^ xorByte0
                    dest[destOffset + 1] = ((b5 << 3) | (g6 >> 3)) ^ xorByte1
                }
            }
        }

        return processedImage
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
