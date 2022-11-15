//
//  CGImage.swift
//  MidiCircuitPlayGround
//
//  Created by Ricardo Abreu on 08/11/2020.
//

import Foundation
import Cocoa
import SwiftUI

extension NSWindowController {
    func getWindowImage() ->CGImage?{
        let windowId = self.window?.windowNumber
        
        let windowImage: CGImage? =
            CGWindowListCreateImage(.null, .optionIncludingWindow, UInt32(windowId!),
                                    [.boundsIgnoreFraming, .nominalResolution])
        
        return windowImage ?? nil
    }
}


//extension NSHostingView {
//    var renderedImage {
////        // rect of capure
////        let rect = self.bounds
////        // create the context of bitmap
////
////        let context: CGContext = CGContext(rect)
////        self.layer!.render(in: context)
////        // get a image from current context bitmap
////        let capturedImage: NSImage = UIGraphicsGetImageFromCurrentImageContext()!
////        UIGraphicsEndImageContext()
////        return capturedImage
//    }
//}


