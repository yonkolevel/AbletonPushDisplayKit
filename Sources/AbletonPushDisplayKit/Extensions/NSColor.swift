//
//  NSColor.swift
//  MidiCircuitPlayGround
//
//  Created by Ricardo Abreu on 09/11/2020.
//

import Foundation
import Cocoa



extension NSColor {

    func components() -> ((alpha: String, red: String, green: String, blue: String, css: String), (alpha: CGFloat, red: CGFloat, green: CGFloat, blue: CGFloat), (alpha: CGFloat, red: CGFloat, green: CGFloat, blue: CGFloat))? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if let color = self.usingColorSpaceName(NSColorSpaceName.calibratedRGB) {
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let nsTuple = (alpha: alpha, red: red, green: green, blue: blue)
            red = round(red * 255.0)
            green = round(green * 255.0)
            blue = round(blue * 255.0)
            alpha = round(alpha * 255.0)
            let xalpha = String(Int(alpha), radix: 16, uppercase: true)
            let xred = String(Int(red), radix: 16, uppercase: true)
            let xgreen = String(Int(green), radix: 16, uppercase: true)
            let xblue = String(Int(blue), radix: 16, uppercase: true)
            let css = "#\(xred)\(xgreen)\(xblue)"
            let hexTuple = (alpha: xalpha, red: xred, green: xgreen, blue: xblue, css: css)
            let rgbTuple = (alpha: alpha, red: red, green: green, blue: blue)
            return (hexTuple, rgbTuple, nsTuple)
        }
        return nil
    }

}

//let c = NSColor(red: 0.2, green: 0.456231576, blue: 0.7, alpha: 1)
//let (hexTuple, rgbTuple, nsTuple) = c.components()!


