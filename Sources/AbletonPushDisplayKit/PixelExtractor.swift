////
////  PixelExtractor.swift
////  MidiCircuitPlayGround
////
////  Created by Ricardo Abreu on 08/11/2020.
////



// extract pixel from a CGImage
/* use case:
 let extractor = PixelExtractor(img: UIImage(named: "gauge_vertical")!.CGImage!)
 let color = extractor.color_at(x: 10, y: 20)
 */

import Cocoa
import SwiftUI

typealias Pixel = UInt8

class PixelExtractor {
    // change this to pointer
    static func getColorAt(x: Int, y: Int, image: CGImage)->NSColor {
        
        assert(0<=x && x<image.width)
        assert(0<=y && y<image.height)
        
        let bitmap = NSBitmapImageRep(cgImage: image)
        
        let color = bitmap.colorAt(x: 0, y: 0)!
        
        // need a pointer to a C-style array of CGFloat
        let compCount = color.numberOfComponents
        let comps = UnsafeMutablePointer<CGFloat>.allocate(capacity: compCount)
        // get the components
        color.getComponents(comps)
        // construct a new color in the device/bitmap space with the same components
        let correctedColor = NSColor(colorSpace: bitmap.colorSpace,
                                     components: comps,
                                     count: compCount)
        // convert to sRGB
        let genericRGBColor = correctedColor.usingColorSpace(.genericRGB)!
        
        
        return genericRGBColor
    }
    
 
    static func getPixelsForPush(bitmap: NSBitmapImageRep)->[UInt8]{
        let xOrMasks:[UInt8] = [0xe7, 0xf3, 0xe7, 0xff];
        let displayPitch = 1920 + 128;
        var xorOffset = 0;
        var processedImage: [UInt8] = [UInt8].init(repeating: 0, count: displayPitch * 160);

        for y in 0..<160 {
            for x  in 0..<960 {
                let color = bitmap.colorAt(x: x, y: y)
                if color == nil {
                    continue
                }
                let colorComponents = color!.components()
                let red = Pixel((colorComponents?.1.red)!)
                let green = Pixel((colorComponents?.1.green)!);
                let blue = Pixel((colorComponents?.1.blue)!);
                let alpha = Pixel((colorComponents?.1.alpha)!);
                
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
}
