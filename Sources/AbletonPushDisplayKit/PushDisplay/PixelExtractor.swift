import Cocoa
import SwiftUI

typealias Pixel = UInt8

public enum PixelExtractor {
    public static let DISPLAY_WIDTH = 960
    public static let DISPLAY_HEIGHT = 160

    public static func getPixelsForPush(bitmap: NSBitmapImageRep) -> [UInt8] {
        let displayPitch = 1920 + 128
        var processedImage = [UInt8](repeating: 0, count: displayPitch * DISPLAY_HEIGHT)

        guard let bitmapData = bitmap.bitmapData else {
            return processedImage
        }

        let bytesPerRow = bitmap.bytesPerRow
        let samplesPerPixel = bitmap.samplesPerPixel

        processedImage.withUnsafeMutableBytes { destBuffer in
            var y = 0
            while y < DISPLAY_HEIGHT {
                var source = bitmapData.advanced(by: y * bytesPerRow)
                var destination = destBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    .advanced(by: y * displayPitch)
                var x = 0

                while x < DISPLAY_WIDTH {
                    let red = source[0]
                    let green = source[1]
                    let blue = source[2]
                    let g6 = green >> 2

                    // BGR565, little-endian, XORed with E7 F3 E7 FF.
                    destination[0] = ((g6 << 5) | (red >> 3)) ^ 0xE7
                    destination[1] = ((blue & 0xF8) | (g6 >> 3)) ^ (x & 1 == 0 ? 0xF3 : 0xFF)

                    source = source.advanced(by: samplesPerPixel)
                    destination = destination.advanced(by: 2)
                    x += 1
                }
                y += 1
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

        for y in 0 ..< DISPLAY_HEIGHT {
            for x in 0 ..< DISPLAY_WIDTH {
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

        for y in 0 ..< DISPLAY_HEIGHT {
            for x in 0 ..< DISPLAY_WIDTH {
                let pixelIndex = (y * bitmap.bytesPerRow + x * 4)

                if pixelIndex + 3 < bitmap.bytesPerRow * DISPLAY_HEIGHT {
                    bitmapData[pixelIndex] = red // R
                    bitmapData[pixelIndex + 1] = green // G
                    bitmapData[pixelIndex + 2] = blue // B
                    bitmapData[pixelIndex + 3] = 255 // A (full opacity)
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
