import SwiftUI
import AbletonPushDisplayKit

enum DemoType: String, CaseIterable {
    case clock = "Clock"
    case visualizer = "Visualizer"
    case gradient = "Gradient"
    case pong = "Pong"
    case starfield = "Starfield"
}

class DebugState: ObservableObject {
    static let shared = DebugState()
    @Published var time = Date()
    @Published var currentDemo: DemoType = .clock
    @Published var animationPhase: Double = 0
    @Published var barHeights: [CGFloat] = Array(repeating: 0.5, count: 32)

    // Pong game state
    @Published var ballX: CGFloat = 480
    @Published var ballY: CGFloat = 80
    @Published var ballVX: CGFloat = 6
    @Published var ballVY: CGFloat = 4
    @Published var paddle1Y: CGFloat = 60
    @Published var paddle2Y: CGFloat = 60
    @Published var score1: Int = 0
    @Published var score2: Int = 0
    @Published var playerInput: CGFloat = 0

    // Starfield state
    struct Star {
        var x: CGFloat
        var y: CGFloat
        var z: CGFloat  // depth (affects speed and size)
    }
    @Published var stars: [Star] = []
    @Published var warpSpeed: CGFloat = 1.0

    private var timer: Timer?
    private var animationTimer: Timer?

    func initStarfield() {
        stars = (0..<150).map { _ in
            Star(
                x: CGFloat.random(in: 0...960),
                y: CGFloat.random(in: 0...160),
                z: CGFloat.random(in: 0.1...1.0)
            )
        }
    }

    func updateStarfield() {
        let centerX: CGFloat = 480
        let centerY: CGFloat = 80

        for i in 0..<stars.count {
            // Move stars outward from center based on depth
            let dx = stars[i].x - centerX
            let dy = stars[i].y - centerY
            let speed = (1.1 - stars[i].z) * 8 * warpSpeed

            stars[i].x += dx * 0.02 * speed
            stars[i].y += dy * 0.02 * speed
            stars[i].z -= 0.008 * warpSpeed  // Stars come closer

            // Reset stars that go off screen or too close
            if stars[i].x < 0 || stars[i].x > 960 ||
               stars[i].y < 0 || stars[i].y > 160 ||
               stars[i].z <= 0 {
                // Reset to center with random offset
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let dist = CGFloat.random(in: 5...50)
                stars[i].x = centerX + cos(angle) * dist
                stars[i].y = centerY + sin(angle) * dist
                stars[i].z = 1.0
            }
        }
    }

    func startTimer() {
        initStarfield()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.time = Date()
            NotificationCenter.default.post(name: .pushViewShouldUpdate, object: nil)
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animationPhase += 0.05

            for i in 0..<self.barHeights.count {
                let base = sin(self.animationPhase * 2 + Double(i) * 0.3) * 0.3 + 0.5
                let noise = Double.random(in: -0.1...0.1)
                self.barHeights[i] = CGFloat(max(0.1, min(1.0, base + noise)))
            }

            if self.currentDemo == .pong {
                self.updatePong()
            }

            if self.currentDemo == .starfield {
                self.updateStarfield()
            }

            NotificationCenter.default.post(name: .pushViewShouldUpdate, object: nil)
        }
    }

    func updatePong() {
        let paddleHeight: CGFloat = 40
        let paddleWidth: CGFloat = 8
        let ballSize: CGFloat = 10
        let fieldWidth: CGFloat = 960
        let fieldHeight: CGFloat = 160

        // Move ball
        ballX += ballVX
        ballY += ballVY

        // Ball collision with top/bottom walls
        if ballY <= ballSize/2 {
            ballY = ballSize/2
            ballVY = abs(ballVY)
        }
        if ballY >= fieldHeight - ballSize/2 {
            ballY = fieldHeight - ballSize/2
            ballVY = -abs(ballVY)
        }

        // Player 1 paddle (left) - follows input
        paddle1Y += playerInput * 5
        paddle1Y = max(paddleHeight/2, min(fieldHeight - paddleHeight/2, paddle1Y))

        // Player 2 paddle (right) - AI follows ball with some delay
        let targetY = ballY
        let aiSpeed: CGFloat = 3.5
        if paddle2Y < targetY - 5 {
            paddle2Y += aiSpeed
        } else if paddle2Y > targetY + 5 {
            paddle2Y -= aiSpeed
        }
        paddle2Y = max(paddleHeight/2, min(fieldHeight - paddleHeight/2, paddle2Y))

        // Ball collision with paddles
        let paddle1X: CGFloat = 30
        let paddle2X: CGFloat = fieldWidth - 30

        // Left paddle collision
        if ballX - ballSize/2 <= paddle1X + paddleWidth/2 &&
           ballX + ballSize/2 >= paddle1X - paddleWidth/2 &&
           ballY >= paddle1Y - paddleHeight/2 &&
           ballY <= paddle1Y + paddleHeight/2 {
            ballX = paddle1X + paddleWidth/2 + ballSize/2
            ballVX = abs(ballVX) * 1.02  // Speed up slightly
            let hitPos = (ballY - paddle1Y) / (paddleHeight/2)
            ballVY += hitPos * 2
        }

        // Right paddle collision
        if ballX + ballSize/2 >= paddle2X - paddleWidth/2 &&
           ballX - ballSize/2 <= paddle2X + paddleWidth/2 &&
           ballY >= paddle2Y - paddleHeight/2 &&
           ballY <= paddle2Y + paddleHeight/2 {
            ballX = paddle2X - paddleWidth/2 - ballSize/2
            ballVX = -abs(ballVX) * 1.02
            let hitPos = (ballY - paddle2Y) / (paddleHeight/2)
            ballVY += hitPos * 2
        }

        // Limit ball speed
        let maxSpeed: CGFloat = 12
        ballVX = max(-maxSpeed, min(maxSpeed, ballVX))
        ballVY = max(-maxSpeed/2, min(maxSpeed/2, ballVY))

        // Scoring
        if ballX < 0 {
            score2 += 1
            resetBall(direction: 1)
        }
        if ballX > fieldWidth {
            score1 += 1
            resetBall(direction: -1)
        }
    }

    func resetBall(direction: CGFloat) {
        ballX = 480
        ballY = 80
        ballVX = 5 * direction
        ballVY = CGFloat.random(in: -3...3)
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

@main
struct PushDebugApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var pushController: PushViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start shared timer
        DebugState.shared.startTimer()

        // Start sending to Push device
        let debugView = DebugPushView()
        pushController = PushViewController(pushView: AnyView(debugView))
        pushController?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DebugState.shared.stopTimer()
        pushController?.stop()
    }
}

struct ContentView: View {
    @ObservedObject private var state = DebugState.shared
    @State private var localKeyMonitor: Any?
    @State private var globalKeyMonitor: Any?

    var body: some View {
        VStack(spacing: 12) {
            Picker("Demo", selection: $state.currentDemo) {
                ForEach(DemoType.allCases, id: \.self) { demo in
                    Text(demo.rawValue).tag(demo)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 400)

            GeometryReader { geo in
                DebugPushView()
                    .frame(width: 960, height: 160)
                    .scaleEffect(0.5)
                    .frame(width: 480, height: 80)
                    .onContinuousHover { phase in
                        guard state.currentDemo == .pong else { return }
                        switch phase {
                        case .active(let location):
                            // Map mouse Y to paddle position (0-160)
                            let normalizedY = location.y / 80.0  // 0 to 1
                            let paddleY = normalizedY * 160
                            state.paddle1Y = max(20, min(140, paddleY))
                        case .ended:
                            break
                        }
                    }
            }
            .frame(width: 480, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))

            if state.currentDemo == .pong {
                Text("Move mouse over preview to control paddle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Sending to Push device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .fixedSize()
        .onAppear {
            setupKeyMonitors()
        }
        .onDisappear {
            removeKeyMonitors()
        }
    }

    func setupKeyMonitors() {
        // Local monitor (when app is focused)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            handleKeyEvent(event)
            return event
        }

        // Global monitor (when app is not focused) - requires accessibility permissions
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            handleKeyEvent(event)
        }
    }

    func removeKeyMonitors() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func handleKeyEvent(_ event: NSEvent) {
        guard state.currentDemo == .pong else { return }

        if event.type == .keyDown {
            switch event.keyCode {
            case 13, 126: // W or Up arrow
                state.playerInput = -1
            case 1, 125:  // S or Down arrow
                state.playerInput = 1
            default:
                break
            }
        } else if event.type == .keyUp {
            switch event.keyCode {
            case 13, 126, 1, 125:
                state.playerInput = 0
            default:
                break
            }
        }
    }
}

struct DebugPushView: View {
    @ObservedObject private var state = DebugState.shared

    var body: some View {
        switch state.currentDemo {
        case .clock:
            ClockDemoView()
        case .visualizer:
            VisualizerDemoView()
        case .gradient:
            GradientDemoView()
        case .pong:
            PongDemoView()
        case .starfield:
            StarfieldDemoView()
        }
    }
}

// MARK: - Clock Demo
struct ClockDemoView: View {
    @ObservedObject private var state = DebugState.shared

    var body: some View {
        ZStack {
            Color.black

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.time, format: .dateTime.hour().minute().second())
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text(state.time, format: .dateTime.weekday(.wide).month().day())
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .padding(.leading, 20)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<8, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hue: Double(i) / 8.0, saturation: 0.8, brightness: 0.9))
                            .frame(width: 40, height: 100)
                    }
                }
                .padding(.trailing, 20)
            }
        }
    }
}

// MARK: - Audio Visualizer Demo
struct VisualizerDemoView: View {
    @ObservedObject private var state = DebugState.shared

    var body: some View {
        ZStack {
            Color.black

            HStack(spacing: 4) {
                ForEach(0..<32, id: \.self) { i in
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barGradient(for: state.barHeights[i]))
                            .frame(width: 24, height: 140 * state.barHeights[i])
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    func barGradient(for height: CGFloat) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: 0.3 - Double(height) * 0.3, saturation: 0.9, brightness: 0.9),
                Color(hue: 0.15 - Double(height) * 0.15, saturation: 0.9, brightness: 0.95)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

// MARK: - Animated Gradient Demo
struct GradientDemoView: View {
    @ObservedObject private var state = DebugState.shared

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, to: size.width, by: 4) {
                let hue = (sin(state.animationPhase + x / 80) + 1) / 2
                let brightness = (sin(state.animationPhase * 1.5 + x / 60) + 1) / 4 + 0.6

                context.fill(
                    Path(CGRect(x: x, y: 0, width: 4, height: size.height)),
                    with: .color(Color(hue: hue, saturation: 0.8, brightness: brightness))
                )
            }
        }
    }
}

// MARK: - Pong Game Demo
struct PongDemoView: View {
    @ObservedObject private var state = DebugState.shared

    let paddleWidth: CGFloat = 8
    let paddleHeight: CGFloat = 40
    let ballSize: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            // Background
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

            // Center line
            let dashHeight: CGFloat = 8
            let dashGap: CGFloat = 8
            for y in stride(from: CGFloat(0), to: size.height, by: dashHeight + dashGap) {
                context.fill(
                    Path(CGRect(x: size.width/2 - 1, y: y, width: 2, height: dashHeight)),
                    with: .color(.gray.opacity(0.5))
                )
            }

            // Scores
            context.draw(
                Text("\(state.score1)")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3)),
                at: CGPoint(x: size.width * 0.35, y: size.height / 2)
            )
            context.draw(
                Text("\(state.score2)")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3)),
                at: CGPoint(x: size.width * 0.65, y: size.height / 2)
            )

            // Left paddle (player)
            let paddle1Rect = CGRect(
                x: 30 - paddleWidth/2,
                y: state.paddle1Y - paddleHeight/2,
                width: paddleWidth,
                height: paddleHeight
            )
            context.fill(
                Path(roundedRect: paddle1Rect, cornerRadius: 3),
                with: .color(.cyan)
            )

            // Right paddle (AI)
            let paddle2Rect = CGRect(
                x: size.width - 30 - paddleWidth/2,
                y: state.paddle2Y - paddleHeight/2,
                width: paddleWidth,
                height: paddleHeight
            )
            context.fill(
                Path(roundedRect: paddle2Rect, cornerRadius: 3),
                with: .color(.orange)
            )

            // Ball with glow effect
            let ballRect = CGRect(
                x: state.ballX - ballSize/2,
                y: state.ballY - ballSize/2,
                width: ballSize,
                height: ballSize
            )

            // Glow
            context.fill(
                Path(ellipseIn: ballRect.insetBy(dx: -4, dy: -4)),
                with: .color(.white.opacity(0.2))
            )
            // Ball
            context.fill(
                Path(ellipseIn: ballRect),
                with: .color(.white)
            )

            // Ball trail
            let trailLength = 5
            for i in 1...trailLength {
                let alpha = 0.15 * Double(trailLength - i) / Double(trailLength)
                let offset = CGFloat(i) * 3
                let trailRect = CGRect(
                    x: state.ballX - state.ballVX.sign * offset - ballSize/4,
                    y: state.ballY - state.ballVY.sign * offset * 0.3 - ballSize/4,
                    width: ballSize/2,
                    height: ballSize/2
                )
                context.fill(
                    Path(ellipseIn: trailRect),
                    with: .color(.white.opacity(alpha))
                )
            }
        }
    }
}

extension CGFloat {
    var sign: CGFloat {
        self >= 0 ? 1 : -1
    }
}

// MARK: - Starfield Animation Demo
struct StarfieldDemoView: View {
    @ObservedObject private var state = DebugState.shared

    var body: some View {
        Canvas { context, size in
            // Deep space background with subtle gradient
            let bgGradient = Gradient(colors: [
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color.black
            ])
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(bgGradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
            )

            // Draw stars
            for star in state.stars {
                let brightness = 1.0 - Double(star.z)
                let starSize = (1.0 - star.z) * 4 + 1

                // Star glow (larger, dimmer)
                if starSize > 2 {
                    let glowRect = CGRect(
                        x: star.x - starSize,
                        y: star.y - starSize,
                        width: starSize * 2,
                        height: starSize * 2
                    )
                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .color(Color.white.opacity(brightness * 0.3))
                    )
                }

                // Star core
                let coreRect = CGRect(
                    x: star.x - starSize/2,
                    y: star.y - starSize/2,
                    width: starSize,
                    height: starSize
                )

                // Color based on depth - closer stars are slightly blue/white
                let hue = star.z < 0.3 ? 0.6 : (star.z < 0.6 ? 0.15 : 0.0)
                let saturation = star.z < 0.5 ? 0.3 : 0.0

                context.fill(
                    Path(ellipseIn: coreRect),
                    with: .color(Color(hue: hue, saturation: saturation, brightness: brightness))
                )

                // Motion trail for fast-moving stars
                if star.z < 0.4 {
                    let centerX: CGFloat = 480
                    let centerY: CGFloat = 80
                    let dx = star.x - centerX
                    let dy = star.y - centerY
                    let trailLength = (0.4 - star.z) * 15

                    let trailPath = Path { path in
                        path.move(to: CGPoint(x: star.x, y: star.y))
                        path.addLine(to: CGPoint(
                            x: star.x - dx * 0.01 * trailLength,
                            y: star.y - dy * 0.01 * trailLength
                        ))
                    }
                    context.stroke(
                        trailPath,
                        with: .color(Color.white.opacity(brightness * 0.5)),
                        lineWidth: starSize * 0.5
                    )
                }
            }

            // Subtle vignette effect
            let vignetteGradient = Gradient(stops: [
                .init(color: .clear, location: 0.3),
                .init(color: Color.black.opacity(0.5), location: 1.0)
            ])
            context.fill(
                Path(ellipseIn: CGRect(x: -100, y: -50, width: size.width + 200, height: size.height + 100)),
                with: .radialGradient(vignetteGradient, center: CGPoint(x: size.width/2, y: size.height/2), startRadius: 200, endRadius: 600)
            )
        }
    }
}

#Preview {
    DebugPushView()
        .frame(width: 960, height: 160)
}
