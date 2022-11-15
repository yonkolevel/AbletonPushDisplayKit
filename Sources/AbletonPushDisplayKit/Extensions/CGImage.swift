//
//  CGImage.swift
//  MidiCircuitPlayGround
//
//  Created by Ricardo Abreu on 09/11/2020.
//

import Foundation
import Cocoa


public enum ImageFormat {
    case png
    case jpeg(CGFloat)
}

extension CGImage {
    @discardableResult func writeCGImage(to destinationURL: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypePNG, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, self, nil)
        return CGImageDestinationFinalize(destination)
    }
}

