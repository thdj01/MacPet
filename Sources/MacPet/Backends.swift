import Foundation
import Security

struct ChatMessage: Codable, Equatable {
    var role: String      // "user" or "assistant"
    var content: String
}

enum AIError: LocalizedError {
    case noKey(String)
    case http(Int, String)
    case refusal
    case network(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .noKey(let provider): return "No API key set for \(provider)."
        case .http(401, _), .http(403, _): return "The API key was rejected."
        case .http(429, _): return "Rate limited. Wait a moment and try again."
        case .http(let code, let msg): return "Error \(code): \(msg.prefix(200))"
        case .refusal: return "The model declined to answer."
        case .network(let why): return why
        case .empty: return "The model returned an empty reply."
        }
    }
}

/// A free cloud provider that speaks the OpenAI chat-completions format.
struct CloudPreset {
    let id: String
    let name: String
    let baseURL: String
    let preferredModels: [String]
    let keyPage: String

    static let all: [CloudPreset] = [
        CloudPreset(id: "groq", name: "Groq", baseURL: "https://api.groq.com/openai/v1",
                    preferredModels: ["llama-3.3-70b-versatile", "openai/gpt-oss-120b"], keyPage: "https://console.groq.com/keys"),
        CloudPreset(id: "gemini", name: "Google Gemini", baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
                    preferredModels: ["gemini-2.5-flash", "models/gemini-2.5-flash"], keyPage: "https://aistudio.google.com/apikey"),
        CloudPreset(id: "openrouter", name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1",
                    preferredModels: ["meta-llama/llama-3.3-70b-instruct:free"], keyPage: "https://openrouter.ai/keys"),
        CloudPreset(id: "cerebras", name: "Cerebras", baseURL: "https://api.cerebras.ai/v1",
                    preferredModels: ["llama-3.3-70b", "gpt-oss-120b"], keyPage: "https://cloud.cerebras.ai"),
    ]

    static func find(_ id: String) -> CloudPreset { all.first { $0.id == id } ?? all[0] }
}

/// Streams a reply from a chat backend as text chunks.
enum Backends {
    // MARK: Ollama (local, free)

    static let ollamaURL = URL(string: "http://localhost:11434")!

    static func ollama(model: String, system: String?, messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        var all: [[String: Any]] = []
        if let system { all.append(["role": "system", "content": system]) }
        all += messages.map { ["role": $0.role, "content": $0.content] }
        let body: [String: Any] = [
            "model": model, "messages": all, "stream": true, "think": false, "keep_alive": "30m",
            "options": ["num_ctx": 8192, "num_predict": 2048],
        ]
        var req = URLRequest(url: ollamaURL.appendingPathComponent("api/chat"))
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return lines(req, offline: "Ollama isn't running. Start it with: brew services start ollama") { line in
            guard let obj = json(line) else { return nil }
            if let err = obj["error"] as? String { throw AIError.http(500, err) }
            return (obj["message"] as? [String: Any])?["content"] as? String
        }
    }

    static func ollamaModels() async -> [String]? {
        var req = URLRequest(url: ollamaURL.appendingPathComponent("api/tags"))
        req.timeoutInterval = 3
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let models = json(data)?["models"] as? [[String: Any]] else { return nil }
        return models.compactMap { $0["name"] as? String }.sorted()
    }

    static func ollamaWarmUp(model: String) async {
        var req = URLRequest(url: ollamaURL.appendingPathComponent("api/generate"))
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["model": model, "keep_alive": "30m"])
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: OpenAI-compatible clouds (Groq, Gemini, OpenRouter, Cerebras)

    static func cloud(_ preset: CloudPreset, key: String, model: String, system: String?, messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        var all: [[String: Any]] = []
        if let system { all.append(["role": "system", "content": system]) }
        all += messages.map { ["role": $0.role, "content": $0.content] }
        var req = URLRequest(url: URL(string: preset.baseURL + "/chat/completions")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        req.setValue("DeskPet", forHTTPHeaderField: "X-Title")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["model": model, "messages": all, "stream": true])
        return lines(req, offline: "Can't reach \(preset.name). Are you online?") { line in
            guard line.hasPrefix("data:") else { return nil }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { return nil }
            guard let obj = json(payload) else { return nil }
            if let err = obj["error"] as? [String: Any] { throw AIError.http(500, err["message"] as? String ?? "stream error") }
            let choice = (obj["choices"] as? [[String: Any]])?.first
            return (choice?["delta"] as? [String: Any])?["content"] as? String
        }
    }

    static func cloudModels(_ preset: CloudPreset, key: String) async -> [String]? {
        var req = URLRequest(url: URL(string: preset.baseURL + "/models")!)
        req.timeoutInterval = 10
        req.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let list = json(data)?["data"] as? [[String: Any]] else { return nil }
        var ids = list.compactMap { $0["id"] as? String }
        if preset.id == "openrouter" { ids = ids.filter { $0.hasSuffix(":free") } }
        let skip = ["whisper", "tts", "embed", "guard", "moderation", "image", "audio", "vision-preview", "imagen", "veo", "aqa"]
        return ids.filter { id in !skip.contains { id.lowercased().contains($0) } }.sorted()
    }

    // MARK: Claude (paid key)

    static func claude(key: String, model: String, system: String?, messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "stream": true,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "cache_control": ["type": "ephemeral"],
        ]
        if let system { body["system"] = system }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 300
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if !model.contains("haiku") {
            // On a safety decline, re-run server-side on Anthropic's recommended fallback model.
            body["fallbacks"] = "default"
            req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return lines(req, offline: "Can't reach Claude. Are you online?") { line in
            guard line.hasPrefix("data:"), let obj = json(line.dropFirst(5).trimmingCharacters(in: .whitespaces)) else { return nil }
            switch obj["type"] as? String {
            case "content_block_delta":
                let delta = obj["delta"] as? [String: Any]
                return delta?["type"] as? String == "text_delta" ? delta?["text"] as? String : nil
            case "message_delta":
                if (obj["delta"] as? [String: Any])?["stop_reason"] as? String == "refusal" { throw AIError.refusal }
                return nil
            case "error":
                throw AIError.http(500, (obj["error"] as? [String: Any])?["message"] as? String ?? "stream error")
            default:
                return nil
            }
        }
    }

    // MARK: helpers

    private static func json(_ s: some StringProtocol) -> [String: Any]? { json(Data(s.utf8)) }
    private static func json(_ d: Data) -> [String: Any]? { (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] }

    /// Runs a streaming request and turns each response line into text via `parse`.
    private static func lines(_ req: URLRequest, offline: String,
                              parse: @escaping @Sendable (String) throws -> String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, resp): (URLSession.AsyncBytes, URLResponse)
                    do {
                        (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    } catch {
                        throw AIError.network(offline)
                    }
                    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    if code != 200 {
                        var text = ""
                        for try await l in bytes.lines { text += l; if text.count > 2000 { break } }
                        let obj = json(text)
                        let msg = (obj?["error"] as? [String: Any])?["message"] as? String ?? obj?["error"] as? String ?? text
                        throw AIError.http(code, msg)
                    }
                    for try await l in bytes.lines {
                        try Task.checkCancellation()
                        if let chunk = try parse(l), !chunk.isEmpty { continuation.yield(chunk) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// API keys live in the login Keychain, one entry per provider.
enum Keychain {
    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.macpet.deskpet",
         kSecAttrAccount as String: account]
    }

    static func read(_ account: String) -> String? {
        var q = base(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func save(_ key: String, _ account: String) {
        SecItemDelete(base(account) as CFDictionary)
        var q = base(account)
        q[kSecValueData as String] = Data(key.utf8)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete(_ account: String) { SecItemDelete(base(account) as CFDictionary) }
}
