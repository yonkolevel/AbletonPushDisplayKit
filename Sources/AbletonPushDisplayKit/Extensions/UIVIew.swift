//
//  UIVIew.swift
//  Push2 Display Process PlayGround (macOS)
//
//  Created by Ricardo Abreu on 15/11/2022.
//

import Foundation
#if os(iOS)
import SwiftUI
import UIKit

extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view

        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
#endif
