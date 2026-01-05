import SwiftUI
import AbletonPushDisplayKit

enum DemoType: String, CaseIterable {
    case clock = "Clock"
    case visualizer = "Visualizer"
    case gradient = "Gradient"
}

class DebugState: ObservableObject {
    static let shared = DebugState()
    @Published var time = Date()
    @Published var currentDemo: DemoType = .clock
    @Published var animationPhase: Double = 0
    @Published var barHeights: [CGFloat] = Array(repeating: 0.5, count: 32)

    private var timer: Timer?
    private var animationTimer: Timer?

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.time = Date()
            NotificationCenter.default.post(name: .pushViewShouldUpdate, object: nil)
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animationPhase += 0.05

            for i in 0..<self.barHeights.count {
                let base = sin(self.animationPhase * 2 + Double(i) * 0.3) * 0.3 + 0.5
                let noise = Double.random(in: -0.1...0.1)
                self.barHeights[i] = CGFloat(max(0.1, min(1.0, base + noise)))
            }

            NotificationCenter.default.post(name: .pushViewShouldUpdate, object: nil)
        }
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

    var body: some View {
        VStack(spacing: 12) {
            Picker("Demo", selection: $state.currentDemo) {
                ForEach(DemoType.allCases, id: \.self) { demo in
                    Text(demo.rawValue).tag(demo)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            DebugPushView()
                .frame(width: 960, height: 160)
                .scaleEffect(0.5)
                .frame(width: 480, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))

            Text("Sending to Push device")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .fixedSize()
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

#Preview {
    DebugPushView()
        .frame(width: 960, height: 160)
}
