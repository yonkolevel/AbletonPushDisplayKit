import Foundation
import AppKit
import SwiftUI
import Combine

public class PushViewController {
    private var displayManager: PushDisplayManager
    private var subscriptions = Set<AnyCancellable>()
    private var pushView: AnyView

    private let renderQueue = DispatchQueue(label: "push.render", qos: .userInteractive)
    private let displayQueue = DispatchQueue(label: "push.display", qos: .userInteractive)

    private var currentFrameData: [UInt8]?
    private var needsRerender = true
    private var lastRenderTime: TimeInterval = 0

    private var renderTimer: Timer?
    private var displayTimer: Timer?

    private let renderFPS: Double = 30
    private let displayFPS: Double = 30

    public init(pushView: AnyView) {
        self.pushView = pushView
        self.displayManager = PushDisplayManager()

        displayManager.$isConnected
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                if connected {
                    NSLog("PushViewController: Connected, starting loops")
                    self?.startLoops()
                } else {
                    NSLog("PushViewController: Disconnected, stopping loops")
                    self?.stopLoops()
                }
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .pushViewShouldUpdate)
            .sink { [weak self] _ in
                self?.needsRerender = true
            }
            .store(in: &subscriptions)
    }

    public func start() {
        if displayManager.isConnected {
            startLoops()
        }
    }

    public func stop() {
        stopLoops()
        displayManager.disconnect()
    }

    private func startLoops() {
        stopLoops()

        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0/renderFPS, repeats: true) { [weak self] _ in
            self?.renderIfNeeded()
        }
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0/displayFPS, repeats: true) { [weak self] _ in
            self?.sendFrame()
        }
    }

    private func stopLoops() {
        renderTimer?.invalidate()
        renderTimer = nil
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func renderIfNeeded() {
        guard needsRerender else { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastRenderTime >= 1.0/60.0 else { return }

        needsRerender = false
        lastRenderTime = now

        renderQueue.async { [weak self] in
            guard let self = self else { return }
            let bitmap = DispatchQueue.main.sync { self.createBitmap() }
            let frameData = PixelExtractor.getPixelsForPush(bitmap: bitmap)
            DispatchQueue.main.async {
                self.currentFrameData = frameData
            }
        }
    }

    private func sendFrame() {
        guard displayManager.isConnected, let frameData = currentFrameData else { return }
        displayQueue.async { [weak self] in
            self?.displayManager.sendPixels(pixels: frameData)
        }
    }

    @MainActor private func createBitmap() -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: pushView.frame(width: 960, height: 160))
        renderer.proposedSize = ProposedViewSize(width: 960, height: 160)
        renderer.scale = 1.0

        if let nsImage = renderer.nsImage {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                          pixelsWide: 960, pixelsHigh: 160,
                                          bitsPerSample: 8, samplesPerPixel: 4,
                                          hasAlpha: true, isPlanar: false,
                                          colorSpaceName: .deviceRGB,
                                          bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            nsImage.draw(in: NSRect(origin: .zero, size: NSSize(width: 960, height: 160)))
            NSGraphicsContext.restoreGraphicsState()
            return bitmap
        }

        let hostingView = NSHostingView(rootView: pushView.frame(width: 960, height: 160))
        hostingView.frame = NSRect(x: 0, y: 0, width: 960, height: 160)
        hostingView.needsLayout = true
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                      pixelsWide: 960, pixelsHigh: 160,
                                      bitsPerSample: 8, samplesPerPixel: 4,
                                      hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        hostingView.draw(NSRect(x: 0, y: 0, width: 960, height: 160))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    public func setAnimating(_ isAnimating: Bool) {
        renderTimer?.invalidate()
        let interval = isAnimating ? 1.0/60.0 : 1.0/10.0
        renderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.renderIfNeeded()
        }
    }
}

extension PixelExtractor {
    static func createBlackFrame() -> [UInt8] {
        return createSolidColorFrame(red: 0, green: 0, blue: 0)
    }

    static func createSolidColorFrame(red: UInt8, green: UInt8, blue: UInt8) -> [UInt8] {
        let bitmap = createTestBitmapDirect(red: red, green: green, blue: blue)
        return getPixelsForPush(bitmap: bitmap)
    }
}
