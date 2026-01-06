import XCTest
import SwiftUI
@testable import AbletonPushDisplayKit

// MARK: - PushDevice Tests

final class PushDeviceTests: XCTestCase {

    func testProductIDs() {
        XCTAssertEqual(PushDevice.push2.productID, 6503)
        XCTAssertEqual(PushDevice.push3.productID, 6504)
        XCTAssertEqual(PushDevice.push3SA.productID, 6505)
    }

    func testDescriptions() {
        XCTAssertEqual(PushDevice.push2.description, "Push 2")
        XCTAssertEqual(PushDevice.push3.description, "Push 3")
        XCTAssertEqual(PushDevice.push3SA.description, "Push 3 SA")
    }

    func testAllCasesHaveUniqueProductIDs() {
        let productIDs = [PushDevice.push2, .push3, .push3SA].map { $0.productID }
        let uniqueIDs = Set(productIDs)
        XCTAssertEqual(productIDs.count, uniqueIDs.count, "All product IDs should be unique")
    }
}

// MARK: - PixelExtractor Tests

final class PixelExtractorTests: XCTestCase {

    func testDisplayDimensions() {
        XCTAssertEqual(PixelExtractor.DISPLAY_WIDTH, 960)
        XCTAssertEqual(PixelExtractor.DISPLAY_HEIGHT, 160)
    }

    func testOutputSize() {
        let bitmap = PixelExtractor.createTestBitmapDirect(red: 0, green: 0, blue: 0)
        let pixels = PixelExtractor.getPixelsForPush(bitmap: bitmap)

        // Output should be (960*2 + 128) * 160 = 2048 * 160 = 327,680 bytes
        let expectedPitch = 1920 + 128
        let expectedSize = expectedPitch * PixelExtractor.DISPLAY_HEIGHT
        XCTAssertEqual(pixels.count, expectedSize)
    }

    func testCreateTestBitmapDirectDimensions() {
        let bitmap = PixelExtractor.createTestBitmapDirect(red: 255, green: 0, blue: 0)
        XCTAssertEqual(bitmap.pixelsWide, PixelExtractor.DISPLAY_WIDTH)
        XCTAssertEqual(bitmap.pixelsHigh, PixelExtractor.DISPLAY_HEIGHT)
    }

    func testCreateTestBitmapDirectFillsColor() {
        let bitmap = PixelExtractor.createTestBitmapDirect(red: 128, green: 64, blue: 32)
        guard let data = bitmap.bitmapData else {
            XCTFail("Bitmap data should not be nil")
            return
        }

        // Check first pixel
        XCTAssertEqual(data[0], 128, "Red channel")
        XCTAssertEqual(data[1], 64, "Green channel")
        XCTAssertEqual(data[2], 32, "Blue channel")
        XCTAssertEqual(data[3], 255, "Alpha channel")
    }

    func testBGR565EncodingBlack() {
        // Black: RGB(0,0,0) -> BGR565 = 0x0000, XORed with mask
        let bitmap = PixelExtractor.createTestBitmapDirect(red: 0, green: 0, blue: 0)
        let pixels = PixelExtractor.getPixelsForPush(bitmap: bitmap)

        // First two bytes should be 0x0000 XOR 0xE7F3 (first two bytes of mask in little-endian)
        // XOR mask: 0xFFE7F3E7 -> bytes are E7, F3, E7, FF
        XCTAssertEqual(pixels[0], 0xE7, "First byte of black pixel")
        XCTAssertEqual(pixels[1], 0xF3, "Second byte of black pixel")
    }

    func testBGR565EncodingWhite() {
        // White: RGB(255,255,255) -> BGR565 = 0xFFFF
        // R5=31, G6=63, B5=31
        // Byte0 = (G6 << 5) | R5 = (63 << 5) | 31 = 0xFF
        // Byte1 = (B5 << 3) | (G6 >> 3) = (31 << 3) | 7 = 0xFF
        // XORed with E7, F3 -> 0x18, 0x0C
        let bitmap = PixelExtractor.createTestBitmapDirect(red: 255, green: 255, blue: 255)
        let pixels = PixelExtractor.getPixelsForPush(bitmap: bitmap)

        XCTAssertEqual(pixels[0], 0xFF ^ 0xE7, "First byte of white pixel")
        XCTAssertEqual(pixels[1], 0xFF ^ 0xF3, "Second byte of white pixel")
    }

    func testBGR565EncodingPureRed() {
        // Pure Red: RGB(255,0,0) -> BGR565
        // R5=31, G6=0, B5=0
        // Byte0 = (0 << 5) | 31 = 0x1F
        // Byte1 = (0 << 3) | 0 = 0x00
        // XORed with E7, F3
        let bitmap = PixelExtractor.createTestBitmapDirect(red: 255, green: 0, blue: 0)
        let pixels = PixelExtractor.getPixelsForPush(bitmap: bitmap)

        XCTAssertEqual(pixels[0], 0x1F ^ 0xE7, "First byte of red pixel")
        XCTAssertEqual(pixels[1], 0x00 ^ 0xF3, "Second byte of red pixel")
    }

    func testBGR565EncodingPureGreen() {
        // Pure Green: RGB(0,255,0) -> BGR565
        // R5=0, G6=63, B5=0
        // Byte0 = (63 << 5) | 0 = 0xE0
        // Byte1 = (0 << 3) | 7 = 0x07
        // XORed with E7, F3
        let bitmap = PixelExtractor.createTestBitmapDirect(red: 0, green: 255, blue: 0)
        let pixels = PixelExtractor.getPixelsForPush(bitmap: bitmap)

        XCTAssertEqual(pixels[0], 0xE0 ^ 0xE7, "First byte of green pixel")
        XCTAssertEqual(pixels[1], 0x07 ^ 0xF3, "Second byte of green pixel")
    }

    func testBGR565EncodingPureBlue() {
        // Pure Blue: RGB(0,0,255) -> BGR565
        // R5=0, G6=0, B5=31
        // Byte0 = (0 << 5) | 0 = 0x00
        // Byte1 = (31 << 3) | 0 = 0xF8
        // XORed with E7, F3
        let bitmap = PixelExtractor.createTestBitmapDirect(red: 0, green: 0, blue: 255)
        let pixels = PixelExtractor.getPixelsForPush(bitmap: bitmap)

        XCTAssertEqual(pixels[0], 0x00 ^ 0xE7, "First byte of blue pixel")
        XCTAssertEqual(pixels[1], 0xF8 ^ 0xF3, "Second byte of blue pixel")
    }

    func testXORMaskRepeats() {
        // Verify XOR mask pattern repeats every 4 bytes
        let bitmap = PixelExtractor.createTestBitmapDirect(red: 0, green: 0, blue: 0)
        let pixels = PixelExtractor.getPixelsForPush(bitmap: bitmap)

        // For black pixels (all zeros), output is just the XOR mask
        // Pattern: E7, F3, E7, FF (repeating)
        XCTAssertEqual(pixels[0], 0xE7)
        XCTAssertEqual(pixels[1], 0xF3)
        XCTAssertEqual(pixels[2], 0xE7)
        XCTAssertEqual(pixels[3], 0xFF)
        // Should repeat
        XCTAssertEqual(pixels[4], 0xE7)
        XCTAssertEqual(pixels[5], 0xF3)
    }

    func testRowPadding() {
        // Each row should have 128 bytes of padding after 1920 bytes of pixel data
        let bitmap = PixelExtractor.createTestBitmapDirect(red: 0, green: 0, blue: 0)
        let pixels = PixelExtractor.getPixelsForPush(bitmap: bitmap)

        let pitch = 1920 + 128

        // Check that padding bytes at end of first row are zero
        for i in 1920..<pitch {
            XCTAssertEqual(pixels[i], 0, "Padding byte at index \(i) should be 0")
        }
    }
}

// MARK: - PushDisplayManager Tests

final class PushDisplayManagerTests: XCTestCase {

    func testInitialState() {
        let manager = PushDisplayManager()
        // Without a device connected, should start as not connected
        // (We can't guarantee this in CI but it's a valid test locally)
        // Just verify the manager can be created without crashing
        XCTAssertNotNil(manager)
    }

    func testDetectConnectedPushDevicesReturnsArray() {
        // This should return an array (possibly empty if no devices)
        let devices = PushDisplayManager.detectConnectedPushDevices()
        XCTAssertNotNil(devices)
        // Verify all detected devices are valid PushDevice values
        for device in devices {
            XCTAssertTrue([PushDevice.push2, .push3, .push3SA].contains(device))
        }
    }

    func testDisconnectDoesNotCrash() {
        let manager = PushDisplayManager()
        // Should not crash even if not connected
        manager.disconnect()
        XCTAssertFalse(manager.isConnected)
    }

    func testConnectedDeviceIsNilWhenNotConnected() {
        let manager = PushDisplayManager()
        // Wait briefly for any connection attempts
        let expectation = XCTestExpectation(description: "Wait for initial connection attempt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // If no device is physically connected, connectedDevice should be nil
        if !manager.isConnected {
            XCTAssertNil(manager.connectedDevice)
        }
    }

    func testSendPixelsDoesNotCrashWhenDisconnected() {
        let manager = PushDisplayManager()
        manager.disconnect() // Ensure disconnected

        // Create valid pixel data
        let pitch = 1920 + 128
        let pixels = [UInt8](repeating: 0, count: pitch * 160)

        // Should not crash
        manager.sendPixels(pixels: pixels)
    }
}

// MARK: - Frame Header Tests

final class FrameHeaderTests: XCTestCase {

    func testFrameHeaderSize() {
        XCTAssertEqual(frameHeader.count, 16)
    }

    func testFrameHeaderMagicBytes() {
        // First 4 bytes should be the magic header
        XCTAssertEqual(frameHeader[0], 0xFF)
        XCTAssertEqual(frameHeader[1], 0xCC)
        XCTAssertEqual(frameHeader[2], 0xAA)
        XCTAssertEqual(frameHeader[3], 0x88)
    }

    func testFrameHeaderPadding() {
        // Remaining bytes should be zero
        for i in 4..<16 {
            XCTAssertEqual(frameHeader[i], 0x00, "Padding byte at index \(i) should be 0")
        }
    }
}

// MARK: - Constants Tests

final class ConstantsTests: XCTestCase {

    func testVendorID() {
        XCTAssertEqual(ABLETON_VENDOR_ID, 10626)
    }

    func testBulkEndpoint() {
        XCTAssertEqual(PUSH_BULK_EP_OUT, 0x01)
    }

    func testTransferTimeout() {
        XCTAssertEqual(TRANSFER_TIMEOUT, 1000)
    }
}
