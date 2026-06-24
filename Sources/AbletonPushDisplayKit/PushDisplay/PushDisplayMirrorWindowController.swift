import AppKit
import Foundation

/// A native macOS preview window that mirrors the exact Push frame stream.
///
/// This is useful when you want to run PushOS normally while also seeing the
/// transport-layer output on the computer. Frames arrive as Push-ready BGR565 +
/// XOR payloads and are decoded to RGBA before being displayed.
public final class PushDisplayMirrorWindowController: NSWindowController, PushDisplayFrameSink {
    private let imageView: NSImageView
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    public init() {
        imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: PushDisplayFrame.width, height: PushDisplayFrame.height))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.magnificationFilter = .nearest
        imageView.layer?.minificationFilter = .nearest

        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: PushDisplayFrame.width, height: PushDisplayFrame.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PushOS Display Mirror"
        window.contentAspectRatio = NSSize(width: PushDisplayFrame.width, height: PushDisplayFrame.height)
        window.contentView = imageView

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func receive(pushDisplayFrame frame: PushDisplayFrame) {
        let rgba = frame.decodedRGBA8888Bytes()
        guard !rgba.isEmpty else { return }
        guard let cgImage = makeImage(fromRGBA: rgba) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.imageView.image = NSImage(cgImage: cgImage, size: NSSize(width: PushDisplayFrame.width, height: PushDisplayFrame.height))
        }
    }

    private func makeImage(fromRGBA rgba: [UInt8]) -> CGImage? {
        let data = Data(rgba)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        return CGImage(
            width: PushDisplayFrame.width,
            height: PushDisplayFrame.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: PushDisplayFrame.width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
