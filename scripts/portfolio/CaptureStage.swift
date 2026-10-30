import AppKit

final class Wallpaper: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(colors: [NSColor(srgbRed: 0.94, green: 0.94, blue: 0.92, alpha: 1),
                            NSColor(srgbRed: 0.83, green: 0.86, blue: 0.87, alpha: 1)])!
            .draw(in: bounds, angle: -75)
    }
}

final class Stage: NSObject, NSApplicationDelegate {
    var wallpaper: NSWindow!
    var note: NSWindow!
    var timer: Timer?
    var last = ""
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && !$0.isHidden && $0.processIdentifier != getpid() }
        if let data = try? JSONEncoder().encode(apps.compactMap(\.bundleIdentifier)) {
            try? data.write(to: URL(fileURLWithPath: "/private/tmp/macpet-hidden-apps.json"))
        }
        for app in apps {
            app.hide()
        }
        wallpaper = NSWindow(contentRect: NSScreen.main!.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        wallpaper.contentView = Wallpaper()
        wallpaper.isReleasedWhenClosed = false
        wallpaper.orderFrontRegardless()
        note = NSWindow(contentRect: NSRect(x: 420, y: 120, width: 740, height: 270),
                        styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        note.title = "Swift Notes"
        note.isReleasedWhenClosed = false
        note.backgroundColor = NSColor(srgbRed: 0.99, green: 0.985, blue: 0.97, alpha: 1)
        let text = NSTextView(frame: NSRect(x: 30, y: 20, width: 680, height: 220))
        text.isEditable = false
        text.drawsBackground = false
        let content = NSMutableAttributedString(string: "Closures, in a few lines\n", attributes: [
            .font: NSFont.systemFont(ofSize: 27, weight: .semibold), .foregroundColor: NSColor.labelColor])
        content.append(NSAttributedString(string: "\nA small function you can keep and pass around.\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.secondaryLabelColor]))
        content.append(NSAttributedString(string: "let scores = [12, 18, 24]\nlet doubled = scores.map { $0 * 2 }\n// [24, 36, 48]", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular),
            .foregroundColor: NSColor(srgbRed: 0.28, green: 0.35, blue: 0.42, alpha: 1)]))
        text.textStorage?.setAttributedString(content)
        note.contentView?.addSubview(text)
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let cmd = try? String(contentsOfFile: "/private/tmp/macpet-stage-command", encoding: .utf8), cmd != self.last else { return }
            self.last = cmd
            if cmd.contains("show") { self.note.orderFrontRegardless() }
            if cmd.contains("hide") { self.note.orderOut(nil) }
            if cmd.contains("quit") { NSApp.terminate(nil) }
        }
    }
}
if CommandLine.arguments.contains("--restore") {
    if let data = try? Data(contentsOf: URL(fileURLWithPath: "/private/tmp/macpet-hidden-apps.json")),
       let ids = try? JSONDecoder().decode([String].self, from: data) {
        for id in ids { NSRunningApplication.runningApplications(withBundleIdentifier: id).forEach { $0.unhide() } }
    }
    exit(0)
}
let app = NSApplication.shared
let delegate = Stage()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
