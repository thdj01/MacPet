import AppKit

/// The pet's assistant brain: a plain conversation with whichever model the user picked.
/// No system prompt is sent unless the user writes custom instructions.
@MainActor
final class Assistant {
    weak var pet: Pet?
    var onUpdate: (() -> Void)?
    /// Called when a send fails before any reply arrived, with the text to put back in the input box.
    var onRestoreInput: ((String) -> Void)?

    private let settings: Settings
    private(set) var history: [ChatMessage] = []
    /// Messages before this index are kept for display but no longer sent to the model.
    private var contextStart = 0
    private(set) var streamingText: String?
    private(set) var lastError: String?
    private(set) var localModels: [String]?
    private(set) var cloudModels: [String: [String]] = [:]
    private var task: Task<Void, Never>?
    private var lastUIUpdate = Date.distantPast

    init(settings: Settings) {
        self.settings = settings
        if !PortfolioCapture.active { load() }
    }

    var isBusy: Bool { task != nil }

    // MARK: - Provider info

    var preset: CloudPreset { CloudPreset.find(settings.cloudPreset) }

    func key(for account: String) -> String? {
        guard !PortfolioCapture.active else { return nil }
        return Keychain.read(account).flatMap { $0.isEmpty ? nil : $0 }
    }

    var currentModel: String {
        switch settings.provider {
        case "cloud": return settings.cloudModel(for: preset.id) ?? preset.preferredModels[0]
        case "claude": return settings.claudeModel
        default: return settings.localModel
        }
    }

    var providerLabel: String {
        switch settings.provider {
        case "cloud": return "\(preset.name) · \(currentModel)"
        case "claude": return "Claude · \(currentModel)"
        default: return "Local · \(currentModel)"
        }
    }

    /// Why the assistant can't answer right now, or nil when it's ready.
    var problem: String? {
        switch settings.provider {
        case "cloud": return key(for: preset.id) == nil ? "Add a free \(preset.name) API key from the menu." : nil
        case "claude": return key(for: "claude") == nil ? "Add a Claude API key from the menu." : nil
        default:
            if localModels == nil { return "Ollama isn't running. Start it with: brew services start ollama" }
            if localModels?.isEmpty == true { return "No local models installed. Try: ollama pull gemma3:4b" }
            return nil
        }
    }

    func refreshModels(warm: Bool = false) {
        if PortfolioCapture.active {
            localModels = ["qwen3:8b", "gemma3:4b"]
            onUpdate?()
            return
        }
        Task { @MainActor in
            localModels = await Backends.ollamaModels()
            if let m = localModels, !m.isEmpty, !m.contains(settings.localModel) { settings.localModel = m[0] }
            if settings.provider == "cloud", let k = key(for: preset.id) {
                let p = preset
                if let list = await Backends.cloudModels(p, key: k), !list.isEmpty {
                    cloudModels[p.id] = list
                    if settings.cloudModel(for: p.id).map({ !list.contains($0) }) ?? true {
                        settings.setCloudModel(p.preferredModels.first(where: list.contains) ?? list[0], for: p.id)
                    }
                }
            }
            if warm, settings.provider == "local", localModels?.isEmpty == false {
                await Backends.ollamaWarmUp(model: settings.localModel)
            }
            onUpdate?()
        }
    }

    // MARK: - Chat

    func send(_ text: String) {
        guard !isBusy else { return }
        if let problem {
            lastError = problem
            onRestoreInput?(text)
            pet?.react(say: "I can't think right now... check my menu?", mood: "sad", action: "none")
            onUpdate?()
            refreshModels()
            return
        }
        lastError = nil
        history.append(ChatMessage(role: "user", content: text))
        trimContext()
        save()
        streamingText = ""
        pet?.startThinking()
        onUpdate?()

        let messages = Array(history[contextStart...])
        let instructions = settings.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let system = instructions.isEmpty ? nil : instructions
        let stream: AsyncThrowingStream<String, Error>
        if PortfolioCapture.active {
            stream = PortfolioCapture.reply()
        } else { switch settings.provider {
        case "cloud":
            stream = Backends.cloud(preset, key: key(for: preset.id) ?? "", model: currentModel, system: system, messages: messages)
        case "claude":
            stream = Backends.claude(key: key(for: "claude") ?? "", model: currentModel, system: system, messages: messages)
        default:
            stream = Backends.ollama(model: currentModel, system: system, messages: messages)
        } }

        task = Task { @MainActor in
            var failure: Error?
            do {
                for try await chunk in stream {
                    streamingText = (streamingText ?? "") + chunk
                    pet?.talk()
                    if Date().timeIntervalSince(lastUIUpdate) > 0.05 {
                        lastUIUpdate = Date()
                        onUpdate?()
                    }
                }
            } catch is CancellationError {
            } catch {
                failure = error
            }
            finish(userText: text, failure: failure)
        }
    }

    func stop() { task?.cancel() }

    private func finish(userText: String, failure: Error?) {
        let reply = (streamingText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        streamingText = nil
        task = nil
        pet?.stopThinking()
        if reply.isEmpty {
            // Nothing came back: drop the unanswered message so the conversation stays well-formed.
            if history.last?.role == "user" { history.removeLast() }
            lastError = (failure ?? AIError.empty).localizedDescription
            onRestoreInput?(userText)
            pet?.react(say: "Oops, I couldn't answer that.", mood: "sad", action: "none")
        } else {
            history.append(ChatMessage(role: "assistant", content: reply))
            if let failure { lastError = "Reply was cut short: \(failure.localizedDescription)" }
            pet?.react(say: Self.preview(reply), mood: "happy", action: "none")
        }
        save()
        onUpdate?()
    }

    func newChat() {
        stop()
        history = []
        contextStart = 0
        lastError = nil
        save()
        onUpdate?()
    }

    /// Short version of a reply for the speech bubble; the full text is in the chat window.
    static func preview(_ text: String) -> String {
        let plain = LaTeX.plain(text).replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "  ", with: " ")
        if plain.count <= 110 { return plain }
        let cut = plain.prefix(110)
        if let end = cut.lastIndex(where: { ".!?".contains($0) }), cut.distance(from: cut.startIndex, to: end) > 30 {
            return String(cut[...end]) + " …"
        }
        return String(cut).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Long chats slide forward in big steps, so the sent prefix rarely changes (keeps provider caches warm).
    private func trimContext() {
        guard history.count - contextStart > 40 else { return }
        contextStart += 20
        while contextStart < history.count && history[contextStart].role != "user" { contextStart += 1 }
    }

    // MARK: - Persistence

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeskPet", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chat.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        history = saved.history
        contextStart = min(saved.contextStart, history.count)
        if history.last?.role == "user" { history.removeLast() }
    }

    private func save() {
        guard !PortfolioCapture.active else { return }
        if let data = try? JSONEncoder().encode(Saved(history: history, contextStart: contextStart)) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private struct Saved: Codable {
        var history: [ChatMessage]
        var contextStart: Int
    }
}
