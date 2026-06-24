import Foundation
import Network
import QuartzCore

private let pushDisplayMirrorMagic = Data([0x50, 0x53, 0x4D, 0x46]) // PSMF: PushOS Mirror Frame
private let pushDisplayMirrorHeaderByteCount = 8

/// Sends encoded Push display frames to a separate mirror process over localhost TCP.
///
/// This keeps mirroring out of the PushOS process. The receiving process can be
/// stopped/restarted independently and can throttle/decode/display frames without
/// affecting the hardware transport path.
public final class PushDisplayTCPFrameSink: PushDisplayFrameSink {
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let minimumFrameInterval: TimeInterval
    private let queue = DispatchQueue(label: "PushDisplayTCPFrameSink")
    private var connection: NWConnection?
    private var isReady = false
    private var lastSentAt: TimeInterval = 0
    private var didLogReady = false

    public init(host: String = "127.0.0.1", port: UInt16 = 48484, maxFPS: Double = 15) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!
        self.minimumFrameInterval = maxFPS > 0 ? 1.0 / maxFPS : 0
        queue.async { [weak self] in
            self?.connect()
        }
    }

    public func receive(pushDisplayFrame frame: PushDisplayFrame) {
        guard frame.isValidForPushDisplay else { return }

        let now = CACurrentMediaTime()
        guard now - lastSentAt >= minimumFrameInterval else { return }
        lastSentAt = now

        let encodedPixels = frame.encodedPixels
        queue.async { [weak self] in
            self?.send(encodedPixels)
        }
    }

    private func connect() {
        guard connection == nil else { return }

        let connection = NWConnection(host: host, port: port, using: .tcp)
        self.connection = connection
        isReady = false

        connection.stateUpdateHandler = { [weak self] state in
            self?.queue.async {
                self?.handleConnectionState(state)
            }
        }
        connection.start(queue: queue)
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            isReady = true
            if !didLogReady {
                NSLog("PushDisplayTCPFrameSink: connected to mirror at \(host):\(port)")
                didLogReady = true
            }
        case .failed, .cancelled:
            reconnect()
        default:
            break
        }
    }

    private func reconnect() {
        connection?.cancel()
        connection = nil
        isReady = false
        queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.connect()
        }
    }

    private func send(_ encodedPixels: [UInt8]) {
        guard isReady, let connection else {
            connect()
            return
        }

        var payload = Data()
        payload.reserveCapacity(pushDisplayMirrorHeaderByteCount + encodedPixels.count)
        payload.append(pushDisplayMirrorMagic)
        var length = UInt32(encodedPixels.count).bigEndian
        withUnsafeBytes(of: &length) { payload.append(contentsOf: $0) }
        payload.append(contentsOf: encodedPixels)

        connection.send(content: payload, completion: .contentProcessed { [weak self] error in
            guard let error else { return }
            NSLog("PushDisplayTCPFrameSink: send failed: \(error)")
            self?.queue.async { self?.reconnect() }
        })
    }

    deinit {
        connection?.cancel()
    }
}

/// Receives encoded Push display frames from `PushDisplayTCPFrameSink`.
public final class PushDisplayTCPFrameServer {
    private let port: NWEndpoint.Port
    private weak var sink: PushDisplayFrameSink?
    private let queue = DispatchQueue(label: "PushDisplayTCPFrameServer")
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    private final class ConnectionState {
        var buffer = Data()
    }

    public init(port: UInt16 = 48484, sink: PushDisplayFrameSink) {
        self.port = NWEndpoint.Port(rawValue: port)!
        self.sink = sink
    }

    public func start() throws {
        let listener = try NWListener(using: .tcp, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        connections.append(connection)
        let state = ConnectionState()

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            if case .cancelled = state, let connection {
                self?.connections.removeAll { $0 === connection }
            }
        }

        connection.start(queue: queue)
        receive(from: connection, state: state)
    }

    private func receive(from connection: NWConnection, state: ConnectionState) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                state.buffer.append(data)
                self.deliverFrames(from: &state.buffer)
            }

            if isComplete || error != nil {
                connection.cancel()
                return
            }

            self.receive(from: connection, state: state)
        }
    }

    private func deliverFrames(from buffer: inout Data) {
        while buffer.count >= pushDisplayMirrorHeaderByteCount {
            let base = buffer.startIndex
            let magicEnd = buffer.index(base, offsetBy: 4)
            guard buffer[base..<magicEnd] == pushDisplayMirrorMagic else {
                buffer.removeFirst()
                continue
            }

            let lengthStart = magicEnd
            let lengthEnd = buffer.index(lengthStart, offsetBy: 4)
            let frameLength = buffer[lengthStart..<lengthEnd].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            let totalLength = pushDisplayMirrorHeaderByteCount + Int(frameLength)
            guard buffer.count >= totalLength else { return }

            let payloadStart = lengthEnd
            let payloadEnd = buffer.index(base, offsetBy: totalLength)
            let encodedPixels = Array(buffer[payloadStart..<payloadEnd])
            buffer.removeSubrange(base..<payloadEnd)

            sink?.receive(pushDisplayFrame: PushDisplayFrame(encodedPixels: encodedPixels))
        }
    }

    deinit {
        stop()
    }
}
