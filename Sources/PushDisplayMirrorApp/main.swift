import AppKit
import AbletonPushDisplayKit

final class MirrorAppDelegate: NSObject, NSApplicationDelegate {
    private var mirrorWindow: PushDisplayMirrorWindowController?
    private var server: PushDisplayTCPFrameServer?

    func applicationDidFinishLaunching(_: Notification) {
        let mirrorWindow = PushDisplayMirrorWindowController()
        self.mirrorWindow = mirrorWindow
        mirrorWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        let port = UInt16(ProcessInfo.processInfo.environment["PUSHOS_MIRROR_PORT"] ?? "48484") ?? 48484
        do {
            let server = PushDisplayTCPFrameServer(port: port, sink: mirrorWindow)
            try server.start()
            self.server = server
            NSLog("PushDisplayMirrorApp: listening on 127.0.0.1:\(port)")
        } catch {
            NSLog("PushDisplayMirrorApp: failed to listen: \(error)")
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_: Notification) {
        server?.stop()
    }
}

let app = NSApplication.shared
let delegate = MirrorAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
