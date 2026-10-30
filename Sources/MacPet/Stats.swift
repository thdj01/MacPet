import Foundation

/// Chopper's needs, 0...100, saved between launches.
final class Stats {
    private let d = PortfolioCapture.defaults
    var hunger: Double
    var happiness: Double
    var energy: Double
    private var saveTimer = 0.0

    static let hungerRate = 100.0 / (5 * 3600)
    static let happyRate = 100.0 / (4 * 3600)
    static let tireRate = 100.0 / (6 * 3600)
    static let sleepRate = 100.0 / (15 * 60)

    init() {
        hunger = d.object(forKey: "stat.hunger") as? Double ?? 80
        happiness = d.object(forKey: "stat.happiness") as? Double ?? 80
        energy = d.object(forKey: "stat.energy") as? Double ?? 90
        let last = d.double(forKey: "stat.lastSaved")
        if last > 0 {
            let elapsed = min(max(0, Date().timeIntervalSince1970 - last), 24 * 3600)
            hunger = max(20, hunger - elapsed * Stats.hungerRate)
            happiness = max(25, happiness - elapsed * Stats.happyRate)
            energy = min(100, energy + elapsed * Stats.sleepRate)
        }
    }

    private func clamp(_ v: Double) -> Double { min(100, max(0, v)) }

    func tick(_ dt: Double, sleeping: Bool, petted: Bool) {
        hunger = clamp(hunger - dt * Stats.hungerRate)
        happiness = clamp(happiness - dt * Stats.happyRate * (hunger < 25 ? 2 : 1) + (petted ? dt * 5 : 0))
        energy = clamp(sleeping ? energy + dt * Stats.sleepRate : energy - dt * Stats.tireRate)
        saveTimer += dt
        if saveTimer > 30 { saveTimer = 0; save() }
    }

    func feed() { hunger = clamp(hunger + 35); happiness = clamp(happiness + 8) }
    func cheer(_ amount: Double) { happiness = clamp(happiness + amount) }
    func tire(_ amount: Double) { energy = clamp(energy - amount) }

    func save() {
        d.set(hunger, forKey: "stat.hunger")
        d.set(happiness, forKey: "stat.happiness")
        d.set(energy, forKey: "stat.energy")
        d.set(Date().timeIntervalSince1970, forKey: "stat.lastSaved")
    }
}

final class Settings {
    private let d = PortfolioCapture.defaults
    private func bool(_ k: String, _ def: Bool) -> Bool { d.object(forKey: k) as? Bool ?? def }

    var followCursor: Bool {
        get { bool("followCursor", false) }
        set { d.set(newValue, forKey: "followCursor") }
    }
    var standOnWindows: Bool {
        get { bool("standOnWindows", true) }
        set { d.set(newValue, forKey: "standOnWindows") }
    }
    var reminders: Bool {
        get { bool("reminders", true) }
        set { d.set(newValue, forKey: "reminders") }
    }
    var petName: String {
        get { d.string(forKey: "petName") ?? "Mochi" }
        set { d.set(newValue, forKey: "petName") }
    }
    var coat: Coat {
        get { Coat(rawValue: d.string(forKey: "coat") ?? "") ?? .ginger }
        set { d.set(newValue.rawValue, forKey: "coat") }
    }
    /// "local" (Ollama), "cloud" (free OpenAI-compatible provider) or "claude".
    var provider: String {
        get { d.string(forKey: "provider") ?? "local" }
        set { d.set(newValue, forKey: "provider") }
    }
    var localModel: String {
        get { d.string(forKey: "localModel") ?? "gemma3:4b" }
        set { d.set(newValue, forKey: "localModel") }
    }
    var cloudPreset: String {
        get { d.string(forKey: "cloudPreset") ?? "groq" }
        set { d.set(newValue, forKey: "cloudPreset") }
    }
    func cloudModel(for preset: String) -> String? { d.string(forKey: "cloudModel.\(preset)") }
    func setCloudModel(_ model: String, for preset: String) { d.set(model, forKey: "cloudModel.\(preset)") }
    var claudeModel: String {
        get { d.string(forKey: "claudeModel") ?? "claude-opus-5-5" }
        set { d.set(newValue, forKey: "claudeModel") }
    }
    /// Optional system prompt. Empty means the model gets no instructions at all.
    var customInstructions: String {
        get { d.string(forKey: "customInstructions") ?? "" }
        set { d.set(newValue, forKey: "customInstructions") }
    }
    var size: Double {
        get { d.object(forKey: "size") as? Double ?? 1.0 }
        set { d.set(newValue, forKey: "size") }
    }
}
