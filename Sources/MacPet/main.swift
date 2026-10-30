import AppKit

if let i = CommandLine.arguments.firstIndex(of: "--preview") {
    let out = i + 1 < CommandLine.arguments.count ? CommandLine.arguments[i + 1] : "preview.png"
    Preview.render(to: out)
    exit(0)
}

if CommandLine.arguments.contains("--bench") { Preview.bench(); exit(0) }
if let i = CommandLine.arguments.firstIndex(of: "--ask"), i + 1 < CommandLine.arguments.count {
    let model = i + 2 < CommandLine.arguments.count ? CommandLine.arguments[i + 2] : "gemma3:4b"
    Task { @MainActor in
        await Preview.ask(CommandLine.arguments[i + 1], model: model)
        exit(0)
    }
    RunLoop.main.run()
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
