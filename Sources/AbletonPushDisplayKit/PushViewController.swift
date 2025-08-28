import Foundation
import AppKit
import SwiftUI
import Combine

public class PushViewController {
    private var displayManager: PushDisplayManager
    private var subscriptions: Set<AnyCancellable>
    private var isDisplayConnected: Bool
    private var pushView: AnyView
    
    // Threading and caching
    private let renderQueue = DispatchQueue(label: "push.render", qos: .userInteractive)
    private let displayQueue = DispatchQueue(label: "push.display", qos: .userInteractive)
    
    // Frame management
    private var currentFrameData: [UInt8]?
    private var needsRerender = true
    private var lastRenderTime: TimeInterval = 0
    private var lastDisplayTime: TimeInterval = 0
    
    // Timers
    private var renderTimer: Timer?
    private var displayTimer: Timer?
    
    // Configuration
    private let targetRenderFPS: Double = 30
    private let displayRefreshFPS: Double = 10
    private let maxRenderFPS: Double = 60
    
    public init(pushView: AnyView) {
        self.pushView = pushView
        self.isDisplayConnected = false
        if let connectedPush = PushDisplayManager.detectConnectedPushDevices().first {
            self.displayManager = PushDisplayManager(device: connectedPush)
        } else {
            self.displayManager = PushDisplayManager()
        }
        
        self.subscriptions = Set<AnyCancellable>()
        
        self.displayManager.connect { result in
            switch result {
            case .success(let isConnected):
                self.isDisplayConnected = isConnected
                if isConnected {
                    self.startDisplayLoop()
                }
            case .failure(let error):
                self.isDisplayConnected = false
                print("Push connection failed: \(error)")
            }
        }
        
        // Listen for view updates
        NotificationCenter.default
            .publisher(for: .pushViewShouldUpdate)
            .sink { [weak self] _ in
                self?.markNeedsRerender()
            }
            .store(in: &subscriptions)
    }
    
    public func start() {
        guard isDisplayConnected else {
            print("Push not connected")
            return
        }
        
        startRenderLoop()
    }
    
    public func stop() {
        stopAllTimers()
        displayManager.disconnect()
    }
    
    // MARK: - Threading Architecture
    
    private func startRenderLoop() {
        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0/targetRenderFPS, repeats: true) { [weak self] _ in
            self?.renderIfNeeded()
        }
    }
    
    private func startDisplayLoop() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0/displayRefreshFPS, repeats: true) { [weak self] _ in
            self?.sendCurrentFrame()
        }
    }
    
    private func stopAllTimers() {
        renderTimer?.invalidate()
        renderTimer = nil
        displayTimer?.invalidate()
        displayTimer = nil
    }
    
    // MARK: - Smart Rendering
    
    private func markNeedsRerender() {
        needsRerender = true
    }
    
    private func renderIfNeeded() {
        guard needsRerender else { return }
        
        let now = CFAbsoluteTimeGetCurrent()
        let minRenderInterval = 1.0 / maxRenderFPS
        guard now - lastRenderTime >= minRenderInterval else { return }
        
        needsRerender = false
        lastRenderTime = now
        
        renderQueue.async { [weak self] in
            self?.performRender()
        }
    }
    
    private func performRender() {
        let bitmap = renderSwiftUIViewToBitmap()
        let frameData = PixelExtractor.getPixelsForPush(bitmap: bitmap)
        
        // Thread-safe frame update
        DispatchQueue.main.async { [weak self] in
            self?.currentFrameData = frameData
        }
    }
    
    private func sendCurrentFrame() {
        guard let frameData = currentFrameData else {
            // No frame ready - send black to keep display alive
            sendKeepAliveFrame()
            return
        }
        
        displayQueue.async { [weak self] in
            self?.displayManager.sendPixels(pixels: frameData)
        }
        
        lastDisplayTime = CFAbsoluteTimeGetCurrent()
    }
    
    private func sendKeepAliveFrame() {
        // Send black frame to prevent display timeout
        let blackFrame = PixelExtractor.createBlackFrame()
        displayQueue.async { [weak self] in
            self?.displayManager.sendPixels(pixels: blackFrame)
        }
    }
    
    // MARK: - Optimized Rendering
    
    private func renderSwiftUIViewToBitmap() -> NSBitmapImageRep {
        return DispatchQueue.main.sync {
            return self.createBitmapFromView()
        }
    }
    
    @MainActor private func createBitmapFromView() -> NSBitmapImageRep {
        if #available(macOS 13.0, *) {
            let renderer = ImageRenderer(content: pushView.frame(width: 960, height: 160))
            renderer.proposedSize = ProposedViewSize(width: 960, height: 160)
            renderer.scale = 1.0 // Important: No scaling
            
            if let nsImage = renderer.nsImage {
                return createBitmapFromNSImage(nsImage)
            }
        }
        
        return renderWithHostingView()
    }
    
    @available(macOS 13.0, *)
    private func createBitmapFromNSImage(_ image: NSImage) -> NSBitmapImageRep {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                      pixelsWide: 960,
                                      pixelsHigh: 160,
                                      bitsPerSample: 8,
                                      samplesPerPixel: 4,
                                      hasAlpha: true,
                                      isPlanar: false,
                                      colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0,
                                      bitsPerPixel: 0)!
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        
        image.draw(in: NSRect(origin: .zero, size: NSSize(width: 960, height: 160)))
        
        NSGraphicsContext.restoreGraphicsState()
        
        return bitmap
    }
    
    private func renderWithHostingView() -> NSBitmapImageRep {
        let hostingView = NSHostingView(rootView: pushView.frame(width: 960, height: 160))
        hostingView.frame = NSRect(x: 0, y: 0, width: 960, height: 160)
        
        // Force layout
        hostingView.needsLayout = true
        hostingView.layoutSubtreeIfNeeded()
        
        // Create bitmap
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                      pixelsWide: PixelExtractor.DISPLAY_WIDTH,
                                      pixelsHigh: PixelExtractor.DISPLAY_HEIGHT,
                                      bitsPerSample: 8,
                                      samplesPerPixel: 4,
                                      hasAlpha: true,
                                      isPlanar: false,
                                      colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0,
                                      bitsPerPixel: 0)!
        
        // Render to bitmap
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        
        hostingView.draw(NSRect(x: 0, y: 0, width: 960, height: 160))
        
        NSGraphicsContext.restoreGraphicsState()
        
        return bitmap
    }
    
    // MARK: - Public Controls
    
    public func setAnimating(_ isAnimating: Bool) {
        if isAnimating {
            // Higher render rate for animations
            renderTimer?.invalidate()
            renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                self?.renderIfNeeded()
            }
        } else {
            // Lower render rate for static content
            renderTimer?.invalidate()
            renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0/10.0, repeats: true) { [weak self] _ in
                self?.renderIfNeeded()
            }
        }
    }
}

// MARK: - PixelExtractor Extension

extension PixelExtractor {
    static func createBlackFrame() -> [UInt8] {
        return createSolidColorFrame(red: 0, green: 0, blue: 0)
    }
    
    static func createSolidColorFrame(red: UInt8, green: UInt8, blue: UInt8) -> [UInt8] {
        let bitmap = createTestBitmapDirect(red: red, green: green, blue: blue)
        return getPixelsForPush(bitmap: bitmap)
    }
}
