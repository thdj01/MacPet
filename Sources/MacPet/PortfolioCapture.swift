import AppKit

/// Opt-in local fixtures for reproducible native screen captures.
/// No history, credentials, model servers, or normal preferences are accessed.
enum PortfolioCapture {
    static let active = CommandLine.arguments.contains("--portfolio")
    static let commandFile = "/private/tmp/macpet-portfolio-command"
    static let defaults: UserDefaults = {
        guard active else { return .standard }
        let name = "com.macpet.portfolio"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        d.register(defaults: ["petName": "Mochi", "size": 1.3,
                              "provider": "local", "localModel": "qwen3:8b",
                              "stat.hunger": 68.0, "stat.happiness": 87.0,
                              "stat.energy": 46.0, "reminders": false])
        return d
    }()

    static func reply() -> AsyncThrowingStream<String, Error> {
        let answer = """
        A **closure** is a block of code you can store in a variable or pass to a function.

        ```swift
        let greet = { (topic: String) -> String in
            "Hello, \\(topic)!"
        }

        greet("Swift") // "Hello, Swift!"
        ```

        The part before **in** describes the inputs and return type. The part after it is the body.

        Closures are especially handy when working with collections:

        ```swift
        let scores = [12, 18, 24]
        let doubled = scores.map { $0 * 2 }
        // [24, 36, 48]
        ```

        Here, **$0** means the current element. Swift infers its type, so you can keep the closure short.
        """
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Task.sleep(for: .milliseconds(450))
                    let chars = Array(answer)
                    for offset in stride(from: 0, to: chars.count, by: 5) {
                        try Task.checkCancellation()
                        continuation.yield(String(chars[offset..<min(offset + 5, chars.count)]))
                        try await Task.sleep(for: .milliseconds(65))
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
