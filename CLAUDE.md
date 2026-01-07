# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AbletonPushDisplayKit is a Swift library for rendering SwiftUI views to Ableton Push 2/3 hardware displays via USB. It achieves 60fps rendering using CVDisplayLink and direct bitmap pixel conversion.

## Build Commands

```bash
# Build the library
swift build

# Build and run the debug app (visual demos + Push output)
swift build --product PushDebug
.build/debug/PushDebug

# Run tests
swift test
```

## Architecture

### Core Components

**PushDisplayManager** (`Sources/AbletonPushDisplayKit/PushDisplay/PushDisplayManager.swift`)
- Manages USB connection to Push devices (Push 2, Push 3, Push 3 SA)
- Uses IOKit for device observation and hot-plug detection
- Handles USB bulk transfers to send frame data
- Publishes connection state via Combine (`@Published isConnected`)

**PushViewController** (`Sources/AbletonPushDisplayKit/PushViewController.swift`)
- Renders SwiftUI views to Push display at 60fps
- Uses CVDisplayLink for vsync-aligned frame timing
- Double-buffered frame data to prevent tearing
- Converts SwiftUI → NSBitmapImageRep → BGR565 pixel format

**PixelExtractor** (`Sources/AbletonPushDisplayKit/PushDisplay/PixelExtractor.swift`)
- Converts RGB888 bitmap to Push's BGR565 format with XOR encoding
- Direct bitmap data pointer access for performance
- Push display format: 960x160 pixels, 16-bit color, XOR mask `0xFFE7F3E7`

**ZIMIOUSB** (`Sources/AbletonPushDisplayKit/ZIMIOUSB/`)
- Low-level IOKit USB wrapper for device communication
- Handles device enumeration, interface claiming, and bulk transfers

### Data Flow

```
SwiftUI View → ImageRenderer → NSBitmapImageRep → PixelExtractor (BGR565 + XOR) → USB Bulk Transfer → Push Display
```

### PushDebug App

Demo application in `Sources/PushDebug/` with multiple demos:
- Clock, Visualizer, Gradient, Pong game, Starfield animation
- Mouse control for Pong (hover over preview)
- All demos render at 60fps to connected Push device

## Push Display Protocol

- Resolution: 960x160 pixels
- Color format: BGR565 (16-bit), little-endian
- Frame size: 16-byte header + 327,680 bytes pixel data
- XOR encoding: Each byte XORed with pattern `[0xE7, 0xF3, 0xE7, 0xFF]`
- USB endpoint: 0x01 bulk transfer
- Native refresh: 60fps with double-buffering

## Supported Devices

| Device | Product ID |
|--------|------------|
| Push 2 | 6503 |
| Push 3 | 6504 |
| Push 3 SA | 6505 |

Vendor ID: 10626 (Ableton)
