import Foundation

/// A single Push display frame at the same encoded boundary used by the USB transport.
///
/// `encodedPixels` is the Push-ready payload produced by `PixelExtractor.getPixelsForPush`:
/// 960×160 pixels, BGR565 little-endian, XOR-shaped, with 128 bytes of row padding.
/// This is the lowest-friction mirror point because the same bytes can be sent to
/// hardware, recorded, streamed to a preview process, or decoded for a web canvas.
public struct PushDisplayFrame: Equatable {
    public static let width = 960
    public static let height = 160
    public static let bytesPerPixel = 2
    public static let rowPixelBytes = width * bytesPerPixel
    public static let rowPaddingBytes = 128
    public static let rowStride = rowPixelBytes + rowPaddingBytes
    public static let encodedByteCount = rowStride * height

    private static let xorPattern: [UInt8] = [0xE7, 0xF3, 0xE7, 0xFF]

    public let encodedPixels: [UInt8]
    public let timestamp: Date

    public init(encodedPixels: [UInt8], timestamp: Date = Date()) {
        self.encodedPixels = encodedPixels
        self.timestamp = timestamp
    }

    public var isValidForPushDisplay: Bool {
        encodedPixels.count == Self.encodedByteCount
    }

    /// Decodes the Push-ready BGR565/XOR payload into tightly packed RGB888 bytes.
    /// Row padding is ignored. Invalid/truncated frames return an empty buffer.
    public func decodedRGB888Bytes() -> [UInt8] {
        guard isValidForPushDisplay else { return [] }

        var decoded = [UInt8](repeating: 0, count: Self.width * Self.height * 3)

        for y in 0 ..< Self.height {
            let sourceRow = y * Self.rowStride
            let destRow = y * Self.width * 3

            for x in 0 ..< Self.width {
                let sourceOffset = sourceRow + x * Self.bytesPerPixel
                let byte0 = encodedPixels[sourceOffset] ^ Self.xorPattern[(x * 2) & 3]
                let byte1 = encodedPixels[sourceOffset + 1] ^ Self.xorPattern[(x * 2 + 1) & 3]
                let bgr565 = UInt16(byte0) | (UInt16(byte1) << 8)

                let r5 = UInt8(bgr565 & 0x1F)
                let g6 = UInt8((bgr565 >> 5) & 0x3F)
                let b5 = UInt8((bgr565 >> 11) & 0x1F)

                let destOffset = destRow + x * 3
                decoded[destOffset] = (r5 << 3) | (r5 >> 2)
                decoded[destOffset + 1] = (g6 << 2) | (g6 >> 4)
                decoded[destOffset + 2] = (b5 << 3) | (b5 >> 2)
            }
        }

        return decoded
    }

    /// Decodes the Push-ready BGR565/XOR payload into tightly packed RGBA8888 bytes.
    /// This is convenient for browser `ImageData` and native preview views.
    public func decodedRGBA8888Bytes(alpha: UInt8 = 255) -> [UInt8] {
        guard isValidForPushDisplay else { return [] }

        var decoded = [UInt8](repeating: 0, count: Self.width * Self.height * 4)

        for y in 0 ..< Self.height {
            let sourceRow = y * Self.rowStride
            let destRow = y * Self.width * 4

            for x in 0 ..< Self.width {
                let sourceOffset = sourceRow + x * Self.bytesPerPixel
                let byte0 = encodedPixels[sourceOffset] ^ Self.xorPattern[(x * 2) & 3]
                let byte1 = encodedPixels[sourceOffset + 1] ^ Self.xorPattern[(x * 2 + 1) & 3]
                let bgr565 = UInt16(byte0) | (UInt16(byte1) << 8)

                let r5 = UInt8(bgr565 & 0x1F)
                let g6 = UInt8((bgr565 >> 5) & 0x3F)
                let b5 = UInt8((bgr565 >> 11) & 0x1F)

                let destOffset = destRow + x * 4
                decoded[destOffset] = (r5 << 3) | (r5 >> 2)
                decoded[destOffset + 1] = (g6 << 2) | (g6 >> 4)
                decoded[destOffset + 2] = (b5 << 3) | (b5 >> 2)
                decoded[destOffset + 3] = alpha
            }
        }

        return decoded
    }
}

/// Receives each encoded Push display frame without taking ownership of the hardware path.
/// Implementations can record frames, forward them over a websocket, update a local preview,
/// or bridge decoded bytes into a web view.
public protocol PushDisplayFrameSink: AnyObject {
    func receive(pushDisplayFrame frame: PushDisplayFrame)
}

/// Lightweight adapter for callers that want to attach a closure as a mirror sink.
public final class ClosurePushDisplayFrameSink: PushDisplayFrameSink {
    private let handler: (PushDisplayFrame) -> Void

    public init(_ handler: @escaping (PushDisplayFrame) -> Void) {
        self.handler = handler
    }

    public func receive(pushDisplayFrame frame: PushDisplayFrame) {
        handler(frame)
    }
}
