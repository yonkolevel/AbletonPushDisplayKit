import Foundation
import AppKit
import SwiftUI
import Combine
import CoreVideo
import QuartzCore

struct FrameRateLimiter {
    private let minimumFrameInterval: TimeInterval
    private var lastFrameTime: TimeInterval?

    init(maximumFramesPerSecond: Double) {
        minimumFrameInterval = 1 / max(1, maximumFramesPerSecond)
    }

    mutating func shouldRender(at time: TimeInterval) -> Bool {
        guard let lastFrameTime else {
            self.lastFrameTime = time
            return true
        }
        guard time - lastFrameTime >= minimumFrameInterval else { return false }
        self.lastFrameTime = time
        return true
    }
}

final class FrameWorkGate {
    private let permit = DispatchSemaphore(value: 1)

    @discardableResult
    func enqueue(on queue: DispatchQueue, work: @escaping () -> Void) -> Bool {
        guard permit.wait(timeout: .now()) == .success else { return false }

        queue.async { [permit] in
            defer { permit.signal() }
            work()
        }
        return true
    }
}

public class PushViewController {
    private var displayManager: PushDisplayManager
    private var subscriptions = Set<AnyCancellable>()
    private var pushView: AnyView

    // Drain AppKit/CG autoreleases after each frame instead of retaining one image per display tick.
    private let renderQueue = DispatchQueue(label: "push.render", qos: .userInteractive, autoreleaseFrequency: .workItem)
    private let displayQueue = DispatchQueue(label: "push.display", qos: .userInteractive)
    private let renderGate = FrameWorkGate()
    private let displayGate = FrameWorkGate()

    // Double-buffered frame data
    private var frameBuffer0: [UInt8]?
    private var frameBuffer1: [UInt8]?
    private var currentReadBuffer: Int = 0
    private let bufferLock = NSLock()

    private var displayLink: CVDisplayLink?
    private var frameRateLimiter: FrameRateLimiter
    private var isRunning = false
    private var lastFPSLogTime: TimeInterval = 0
    private var framesThisSecond: Int = 0

    public convenience init(pushView: AnyView) {
        self.init(pushView: pushView, maximumFramesPerSecond: 60)
    }

    public init(pushView: AnyView, maximumFramesPerSecond: Double) {
        self.pushView = pushView
        frameRateLimiter = FrameRateLimiter(maximumFramesPerSecond: maximumFramesPerSecond)
        displayManager = PushDisplayManager()

        displayManager.$isConnected
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                if connected {
                    NSLog("PushViewController: Connected, starting display link")
                    self?.startDisplayLink()
                } else {
                    NSLog("PushViewController: Disconnected, stopping display link")
                    self?.stopDisplayLink()
                }
            }
            .store(in: &subscriptions)
    }

    public func start() {
        if displayManager.isConnected {
            startDisplayLink()
        }
    }

    public func stop() {
        stopDisplayLink()
        displayManager.disconnect()
    }

    /// Hint that the underlying SwiftUI view's observable state has changed.
    /// Rendering polls at the configured maximum frame rate; this is a no-op
    /// semantically but kept as a typed replacement for posting
    /// `.pushViewShouldUpdate` from outside the module.
    public func setNeedsUpdate() {
        NotificationCenter.default.post(name: .pushViewShouldUpdate, object: self)
    }

    private func startDisplayLink() {
        guard !isRunning else { return }
        isRunning = true

        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let displayLink = link else {
            NSLog("PushViewController: Failed to create CVDisplayLink")
            return
        }

        self.displayLink = displayLink

        let callback: CVDisplayLinkOutputCallback = { displayLink, inNow, inOutputTime, flagsIn, flagsOut, context in
            let controller = Unmanaged<PushViewController>.fromOpaque(context!).takeUnretainedValue()
            controller.displayLinkCallback()
            return kCVReturnSuccess
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, callback, pointer)
        CVDisplayLinkStart(displayLink)
        NSLog("PushViewController: CVDisplayLink started")
    }

    private func stopDisplayLink() {
        guard isRunning else { return }
        isRunning = false

        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
        displayLink = nil
        NSLog("PushViewController: CVDisplayLink stopped")
    }

    private func displayLinkCallback() {
        guard frameRateLimiter.shouldRender(at: CACurrentMediaTime()) else { return }

        // Keep at most one render and one USB write in flight. The two frame
        // buffers retain the latest completed frames, so queued stale work is useless.
        renderGate.enqueue(on: renderQueue) { [weak self] in
            self?.renderFrame()
        }
        displayGate.enqueue(on: displayQueue) { [weak self] in
            self?.sendFrame()
        }
    }

    private func renderFrame() {
        let bitmap = DispatchQueue.main.sync { [weak self] () -> NSBitmapImageRep? in
            guard let self = self else { return nil }
            return self.createBitmap()
        }

        guard let bitmap = bitmap else { return }
        let frameData = PixelExtractor.getPixelsForPush(bitmap: bitmap)

        // Write to the buffer not being read
        bufferLock.lock()
        let writeBuffer = 1 - currentReadBuffer
        if writeBuffer == 0 {
            frameBuffer0 = frameData
        } else {
            frameBuffer1 = frameData
        }
        currentReadBuffer = writeBuffer
        bufferLock.unlock()
    }

    private func sendFrame() {
        guard displayManager.isConnected else { return }

        bufferLock.lock()
        let frameData = currentReadBuffer == 0 ? frameBuffer0 : frameBuffer1
        bufferLock.unlock()

        guard let data = frameData else { return }
        displayManager.sendPixels(pixels: data)

        // FPS logging
        framesThisSecond += 1
        let now = CACurrentMediaTime()
        if now - lastFPSLogTime >= 1.0 {
            NSLog("PushViewController: FPS: %d", framesThisSecond)
            framesThisSecond = 0
            lastFPSLogTime = now
        }
    }

    @MainActor private func createBitmap() -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: pushView.frame(width: 960, height: 160))
        renderer.proposedSize = ProposedViewSize(width: 960, height: 160)
        renderer.scale = 1.0

        // Create a consistent RGBA bitmap and draw into it
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                      pixelsWide: 960, pixelsHigh: 160,
                                      bitsPerSample: 8, samplesPerPixel: 4,
                                      hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

        // Use cgImage if available (faster), otherwise nsImage
        if let cgImage = renderer.cgImage {
            let context = NSGraphicsContext.current?.cgContext
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: 960, height: 160))
        } else if let nsImage = renderer.nsImage {
            nsImage.draw(in: NSRect(origin: .zero, size: NSSize(width: 960, height: 160)))
        } else {
            // Last resort fallback - use hosting view
            let hostingView = NSHostingView(rootView: pushView.frame(width: 960, height: 160))
            hostingView.frame = NSRect(x: 0, y: 0, width: 960, height: 160)
            hostingView.needsLayout = true
            hostingView.layoutSubtreeIfNeeded()
            hostingView.draw(NSRect(x: 0, y: 0, width: 960, height: 160))
        }

        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    public func setAnimating(_ isAnimating: Bool) {
        // With CVDisplayLink, always running at display refresh rate
        // This method kept for API compatibility
    }

    deinit {
        stopDisplayLink()
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
