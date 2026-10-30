import AppKit
import ServiceManagement
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let world = World()
    private let stats = Stats()
    private let settings = Settings()
    private var pet: Pet!
    private var panel: PetPanel!
    private var view: PetView!
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()
    private var lastCursor = NSEvent.mouseLocation
    private var frame = 0
    private var keyIdle = 999.0
    private var anyIdle = 0.0
    private let size = NSSize(width: 900, height: 760)
    private var assistant: Assistant!
    private let chat = ChatWindow()
    private var hotKeyRef: EventHotKeyRef?
    private var portfolioCommand = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        PetRenderer.setCoat(settings.coat)
        pet = Pet(world: world, stats: stats, settings: settings)
        panel = PetPanel(size: size)
        view = PetView(frame: NSRect(origin: .zero, size: size), pet: pet)
        view.menuProvider = { [weak self] in self?.buildMenu() ?? NSMenu() }
        view.onTalk = { [weak self] in self?.openChat() }
        setUpAssistant()
        panel.contentView = view
        pet.dropFromTop()
        syncWindow()
        panel.orderFrontRegardless()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.menuIcon()
        statusItem.button?.toolTip = settings.petName
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        startTimer(fps: 30)
        registerHotKey()
        assistant.refreshModels(warm: true)
        if PortfolioCapture.active {
            NSApp.appearance = NSAppearance(named: .aqua)
            pet.portfolioAction("reset")
        }
    }

    // MARK: - Assistant

    private func setUpAssistant() {
        assistant = Assistant(settings: settings)
        assistant.pet = pet
        assistant.onUpdate = { [weak self] in self?.refreshChat() }
        assistant.onRestoreInput = { [weak self] text in self?.chat.restoreInput(text) }
        chat.onSend = { [weak self] text in self?.assistant.send(text) }
        chat.onStop = { [weak self] in self?.assistant.stop() }
        chat.onNewChat = { [weak self] in self?.assistant.newChat() }
        chat.onClose = { [weak self] in self?.pet.attentive = false }
    }

    private func refreshChat() {
        guard chat.isVisible else { return }
        chat.update(petName: settings.petName, history: assistant.history, streaming: assistant.streamingText,
                    statusText: assistant.providerLabel, error: assistant.lastError ?? assistant.problem)
    }

    @objc func openChat() {
        pet.payAttention()
        chat.show(near: pet.pos, scale: pet.scale)
        if PortfolioCapture.active {
            chat.setFrame(NSRect(x: 1110, y: 220, width: 490, height: 650), display: true)
        }
        refreshChat()
    }

    /// Global ⌃⌥C opens the chat. Carbon hot keys need no special permissions.
    private func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { (NSApp.delegate as? AppDelegate)?.openChat() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x4450_4554), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_C), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    /// Small text prompt. Returns nil on Cancel; `extra` adds a third button that returns "".
    private func ask(_ title: String, _ info: String, value: String = "", placeholder: String = "",
                     secure: Bool = false, multiline: Bool = false, extra: String? = nil) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        let field: NSView
        var read: () -> String
        if multiline {
            let scroll = NSTextView.scrollableTextView()
            scroll.frame = NSRect(x: 0, y: 0, width: 380, height: 140)
            let tv = scroll.documentView as! NSTextView
            tv.string = value
            tv.font = .systemFont(ofSize: 13)
            field = scroll
            read = { tv.string }
        } else {
            let tf = secure ? NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
                            : NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
            tf.stringValue = value
            tf.placeholderString = placeholder
            field = tf
            read = { tf.stringValue }
        }
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        if let extra { alert.addButton(withTitle: extra) }
        alert.window.initialFirstResponder = field is NSScrollView ? (field as! NSScrollView).documentView : field
        switch alert.runModal() {
        case .alertFirstButtonReturn: return read().trimmingCharacters(in: .whitespacesAndNewlines)
        case .alertThirdButtonReturn: return ""
        default: return nil
        }
    }

    @objc private func useLocal(_ sender: NSMenuItem) {
        if let model = sender.representedObject as? String { settings.localModel = model }
        settings.provider = "local"
        assistant.refreshModels(warm: true)
    }

    @objc private func useCloud(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        let preset = CloudPreset.find(id)
        settings.cloudPreset = id
        if assistant.key(for: id) == nil {
            NSWorkspace.shared.open(URL(string: preset.keyPage)!)
            guard let key = ask("\(preset.name) API key",
                                "Sign up for free at \(preset.keyPage) (opened in your browser), create a key, and paste it here. It's stored in your Keychain.",
                                placeholder: "Paste key", secure: true), !key.isEmpty else { return }
            Keychain.save(key, id)
        }
        settings.provider = "cloud"
        assistant.refreshModels()
    }

    @objc private func setCloudModel(_ sender: NSMenuItem) {
        guard let model = sender.representedObject as? String else { return }
        settings.setCloudModel(model, for: settings.cloudPreset)
        settings.provider = "cloud"
        refreshChat()
    }

    @objc private func changeCloudKey() {
        let preset = assistant.preset
        guard let key = ask("\(preset.name) API key", "Get a key at \(preset.keyPage).", placeholder: "Paste key",
                            secure: true, extra: "Remove Key") else { return }
        if key.isEmpty { Keychain.delete(preset.id) } else { Keychain.save(key, preset.id) }
        assistant.refreshModels()
    }

    @objc private func useClaude(_ sender: NSMenuItem) {
        if let model = sender.representedObject as? String { settings.claudeModel = model }
        if assistant.key(for: "claude") == nil {
            guard let key = ask("Claude API key", "Paste an Anthropic API key from console.anthropic.com. It's stored in your Keychain.",
                                placeholder: "sk-ant-...", secure: true), !key.isEmpty else { return }
            Keychain.save(key, "claude")
        }
        settings.provider = "claude"
        refreshChat()
    }

    @objc private func editInstructions() {
        guard let text = ask("Custom instructions",
                             "Optional. Leave empty and the model gets no instructions at all. Example: \"Answer briefly. I'm a Swift developer in India.\"",
                             value: settings.customInstructions, multiline: true) else { return }
        settings.customInstructions = text
    }

    @objc private func newChat() { assistant.newChat() }

    @objc private func rename() {
        guard let name = ask("Rename your pet", "", value: settings.petName), !name.isEmpty else { return }
        settings.petName = name
        statusItem.button?.toolTip = name
        pet.say("\(name)? I love it!", 3)
        refreshChat()
    }

    @objc private func setCoat(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let coat = Coat(rawValue: raw) else { return }
        settings.coat = coat
        PetRenderer.setCoat(coat)
        statusItem.button?.image = Self.menuIcon()
    }

    private var timerFPS = 0.0

    /// 60 Hz only while the pet moves fast; 30 Hz otherwise to save battery.
    private func startTimer(fps: Double) {
        guard fps != timerFPS else { return }
        timerFPS = fps
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.2 / fps
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func applicationWillTerminate(_ notification: Notification) { stats.save() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openChat()
        return false
    }

    private func tick() {
        if PortfolioCapture.active,
           let command = try? String(contentsOfFile: PortfolioCapture.commandFile, encoding: .utf8),
           command != portfolioCommand {
            portfolioCommand = command
            let action = command.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ").last ?? ""
            switch action {
            case "chat": openChat()
            case "close": chat.close()
            case "new": assistant.newChat()
            case "quit": NSApp.terminate(nil)
            default: pet.portfolioAction(action)
            }
            if chat.isVisible {
                chat.setFrame(NSRect(x: 1110, y: 220, width: 490, height: 650), display: true)
            }
        }
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 1.0 / 20.0)
        lastTick = now
        frame += 1
        if PortfolioCapture.active && frame % 15 == 0 {
            let state: [String: Any] = ["x": pet.pos.x, "y": pet.pos.y, "state": pet.stateName,
                                        "model": assistant.currentModel, "chat": chat.isVisible,
                                        "streaming": assistant.streamingText != nil,
                                        "prompt": assistant.history.first?.content ?? ""]
            if let data = try? JSONSerialization.data(withJSONObject: state) {
                try? data.write(to: URL(fileURLWithPath: "/private/tmp/macpet-portfolio-status.json"), options: .atomic)
            }
        }

        let cursor = NSEvent.mouseLocation
        let speed = hypot(cursor.x - lastCursor.x, cursor.y - lastCursor.y) / CGFloat(max(dt, 0.001))
        lastCursor = cursor
        if frame % 10 == 0 {
            keyIdle = Sensors.secondsSinceKeyPress()
            anyIdle = Sensors.secondsSinceAnyInput()
        }
        let over = view.isOnPet(cursor)

        pet.update(dt: dt, input: PetInput(cursor: cursor, cursorSpeed: speed, overPet: over,
                                           keyIdle: keyIdle, anyIdle: anyIdle))
        syncWindow()
        let ignore = !(over || pet.isMouseDown)
        if ignore != panel.ignoresMouseEvents { panel.ignoresMouseEvents = ignore }
        view.render()
        draws += 1
        if debug && frame % Int(timerFPS * 5) == 0 {
            FileHandle.standardError.write("state=\(pet.stateName) fps=\(timerFPS) per5s draws=\(draws) windowMoves=\(moves)\n".data(using: .utf8)!)
            draws = 0; moves = 0
        }
        // 60 Hz while flying or carried, 30 Hz normally, 15 Hz when calm.
        startTimer(fps: pet.isFast ? 60 : (pet.isCalm ? 15 : 30))
    }

    private var moves = 0, draws = 0
    private let debug = ProcessInfo.processInfo.environment["PET_DEBUG"] != nil

    /// Smallest window that fits WALL•E plus any bubble, particles or prop.
    private func desiredSize() -> NSSize {
        let s = pet.scale
        var w = 150 * s, h = 165 * s
        if pet.state == .ropeway || pet.state == .climb { h = max(h, 205 * s); w = max(w, 190 * s) }
        if !pet.particles.isEmpty { h = max(h, 215 * s); w = max(w, 170 * s) }
        if pet.state == .hide { h = max(h, 190 * s) }
        if let text = pet.bubbleText {
            let b = SceneRenderer.bubbleSize(text)
            w = max(w, b.width + 16)
            h = max(h, 110 * s + b.height + 30)
        }
        return NSSize(width: (w / 20).rounded(.up) * 20, height: (h / 20).rounded(.up) * 20)
    }

    private func syncWindow() {
        let want = desiredSize()
        view.spriteSize = want
        let spriteRect = NSRect(x: (pet.pos.x - want.width / 2).rounded(), y: (pet.pos.y - 8).rounded(),
                                width: want.width, height: want.height)
        // Only move the window when the sprite gets near its edge.
        if !panel.frame.insetBy(dx: 6, dy: 6).contains(spriteRect) {
            panel.setFrameOrigin(NSPoint(x: (pet.pos.x - size.width / 2).rounded(), y: (pet.pos.y - 220).rounded()))
            moves += 1
        }
        view.spriteOrigin = CGPoint(x: spriteRect.minX - panel.frame.minX, y: spriteRect.minY - panel.frame.minY)
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        assistant.refreshModels()
        menu.removeAllItems()
        for item in buildMenu().items {
            item.menu?.removeItem(item)
            menu.addItem(item)
        }
    }

    private func bar(_ v: Double) -> String {
        let n = Int((v / 10).rounded())
        return String(repeating: "■", count: n) + String(repeating: "□", count: 10 - n)
    }

    func buildMenu() -> NSMenu {
        let m = NSMenu()
        func info(_ s: String) {
            let i = NSMenuItem(title: s, action: nil, keyEquivalent: "")
            i.isEnabled = false
            m.addItem(i)
        }
        func item(_ title: String, _ sel: Selector, key: String = "", on: Bool? = nil) {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            i.target = self
            if let on { i.state = on ? .on : .off }
            m.addItem(i)
        }

        info("\(settings.petName): \(pet.stateName)")
        info("🍬 Food    \(bar(stats.hunger))")
        info("💖 Joy     \(bar(stats.happiness))")
        info("⚡ Energy  \(bar(stats.energy))")
        m.addItem(.separator())
        item("Chat…  ⌃⌥C", #selector(openChat), key: "t")
        item("New Chat", #selector(newChat))
        m.addItem(.separator())
        item("Give a Treat", #selector(feed), key: "f")
        item("Super Size", #selector(rumble), key: "r")
        item("Dance!", #selector(dance), key: "d")
        item("Come Here!", #selector(comeHere), key: "c")
        item("🧗 Climb Wall & Zipline", #selector(climbWall), key: "w")
        item(pet.state == .sleep ? "Wake Up" : "Take a Nap", #selector(toggleSleep), key: "n")
        item("Drop From the Top", #selector(reset))
        m.addItem(.separator())

        // Assistant settings
        let aiItem = NSMenuItem(title: "Assistant", action: nil, keyEquivalent: "")
        let ai = NSMenu()
        func aiEntry(_ title: String, _ sel: Selector?, on: Bool? = nil, rep: Any? = nil, enabled: Bool = true, to menu: NSMenu? = nil) {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            i.target = self
            i.isEnabled = enabled
            i.representedObject = rep
            if let on { i.state = on ? .on : .off }
            (menu ?? ai).addItem(i)
        }
        aiEntry(assistant.problem.map { "⚠️ \($0)" } ?? "Using \(assistant.providerLabel)", nil, enabled: false)
        ai.addItem(.separator())

        let provider = settings.provider
        aiEntry("Local · free, private, offline", nil, enabled: false)
        for model in assistant.localModels ?? [] {
            aiEntry("    \(model)", #selector(useLocal(_:)), on: provider == "local" && settings.localModel == model, rep: model)
        }
        if assistant.localModels == nil { aiEntry("    Ollama isn't running", nil, enabled: false) }
        ai.addItem(.separator())

        aiEntry("Free cloud · needs a free key", nil, enabled: false)
        for p in CloudPreset.all {
            let hasKey = assistant.key(for: p.id) != nil
            aiEntry("    \(p.name)\(hasKey ? "" : "  (add key…)")", #selector(useCloud(_:)),
                    on: provider == "cloud" && settings.cloudPreset == p.id, rep: p.id)
        }
        if provider == "cloud" {
            let modelsItem = NSMenuItem(title: "    \(assistant.preset.name) Model", action: nil, keyEquivalent: "")
            let models = NSMenu()
            let list = assistant.cloudModels[assistant.preset.id] ?? [assistant.currentModel]
            for id in list.prefix(40) {
                aiEntry(id, #selector(setCloudModel(_:)), on: assistant.currentModel == id, rep: id, to: models)
            }
            modelsItem.submenu = models
            ai.addItem(modelsItem)
            aiEntry("    Change \(assistant.preset.name) Key…", #selector(changeCloudKey))
        }
        ai.addItem(.separator())

        aiEntry("Claude · paid key", nil, enabled: false)
        for (name, id) in [("Claude Opus 5.5", "claude-opus-5-5"), ("Claude Sonnet 5.5", "claude-sonnet-5-5"), ("Claude Haiku 5.5", "claude-haiku-5-5")] {
            aiEntry("    \(name)", #selector(useClaude(_:)), on: provider == "claude" && settings.claudeModel == id, rep: id)
        }
        ai.addItem(.separator())
        aiEntry("Custom Instructions…", #selector(editInstructions))
        aiItem.submenu = ai
        m.addItem(aiItem)

        // Pet settings
        let petItem = NSMenuItem(title: "Pet", action: nil, keyEquivalent: "")
        let petMenu = NSMenu()
        func petEntry(_ title: String, _ sel: Selector, on: Bool? = nil, rep: Any? = nil) {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            i.target = self
            i.representedObject = rep
            if let on { i.state = on ? .on : .off }
            petMenu.addItem(i)
        }
        petEntry("Rename…", #selector(rename))
        petMenu.addItem(.separator())
        for coat in Coat.allCases { petEntry(coat.title, #selector(setCoat(_:)), on: settings.coat == coat, rep: coat.rawValue) }
        petMenu.addItem(.separator())
        for (name, v) in [("Small", 0.75), ("Medium", 1.0), ("Large", 1.3)] {
            petEntry(name, #selector(setSize(_:)), on: abs(settings.size - v) < 0.01, rep: v)
        }
        petMenu.addItem(.separator())
        petEntry("Follow My Cursor", #selector(toggleFollow), on: settings.followCursor)
        petEntry("Stand on Windows", #selector(toggleWindows), on: settings.standOnWindows)
        petEntry("Break Reminders", #selector(toggleReminders), on: settings.reminders)
        petItem.submenu = petMenu
        m.addItem(petItem)
        item("Launch at Login", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled)
        m.addItem(.separator())
        item("Quit", #selector(quit), key: "q")
        return m
    }

    @objc private func feed() { pet.feed() }
    @objc private func rumble() { pet.superSize() }
    @objc private func dance() { pet.dance() }
    @objc private func comeHere() { pet.comeHere() }
    @objc private func climbWall() { pet.startClimbing() }
    @objc private func toggleSleep() { pet.toggleSleep() }
    @objc private func reset() { pet.dropFromTop() }
    @objc private func toggleFollow() { settings.followCursor.toggle() }
    @objc private func toggleWindows() { settings.standOnWindows.toggle() }
    @objc private func toggleReminders() { settings.reminders.toggle() }
    @objc private func setSize(_ sender: NSMenuItem) { settings.size = sender.representedObject as? Double ?? 1 }
    @objc private func quit() { stats.save(); NSApp.terminate(nil) }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            pet.say("I couldn't change the login setting: \(error.localizedDescription)", 5)
        }
    }

    static func menuIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 24, height: 18), flipped: true) { _ in
            guard let c = NSGraphicsContext.current?.cgContext else { return false }
            c.translateBy(x: 12, y: 17.5)
            c.scaleBy(x: 0.26, y: 0.26)
            c.translateBy(x: 0, y: 43)
            PetRenderer.drawPortrait(c)
            return true
        }
        img.isTemplate = false
        return img
    }
}
