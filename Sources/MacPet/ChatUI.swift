import AppKit

/// Floating chat window next to the pet. It takes keyboard focus without activating the app.
final class ChatWindow: NSPanel, NSTextFieldDelegate {
    private let transcript = NSTextView()
    private let scroll = NSScrollView()
    private let input = NSTextField()
    private let sendButton = NSButton()
    private let newButton = NSButton()
    private let status = NSTextField(labelWithString: "")

    var onSend: ((String) -> Void)?
    var onStop: (() -> Void)?
    var onNewChat: (() -> Void)?
    var onClose: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
                   styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 300, height: 300)
        title = "Chat"

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 520))
        contentView = root

        scroll.frame = NSRect(x: 0, y: 70, width: 400, height: 450)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        transcript.frame = scroll.bounds
        transcript.autoresizingMask = [.width]
        transcript.isEditable = false
        transcript.isSelectable = true
        transcript.drawsBackground = false
        transcript.textContainerInset = NSSize(width: 14, height: 12)
        scroll.documentView = transcript
        root.addSubview(scroll)

        status.frame = NSRect(x: 14, y: 46, width: 372, height: 18)
        status.autoresizingMask = [.width]
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        root.addSubview(status)

        newButton.frame = NSRect(x: 10, y: 10, width: 34, height: 28)
        newButton.bezelStyle = .texturedRounded
        newButton.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New chat")
        newButton.toolTip = "New chat"
        newButton.target = self
        newButton.action = #selector(newChat)
        root.addSubview(newButton)

        input.frame = NSRect(x: 50, y: 12, width: 290, height: 24)
        input.autoresizingMask = [.width]
        input.placeholderString = "Message…"
        input.font = .systemFont(ofSize: 13)
        input.bezelStyle = .roundedBezel
        input.delegate = self
        input.target = self
        input.action = #selector(sendOrStop)
        root.addSubview(input)

        sendButton.frame = NSRect(x: 346, y: 10, width: 44, height: 28)
        sendButton.autoresizingMask = [.minXMargin]
        sendButton.bezelStyle = .texturedRounded
        sendButton.target = self
        sendButton.action = #selector(sendOrStop)
        root.addSubview(sendButton)
        setBusy(false)
    }

    override var canBecomeKey: Bool { true }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.cancelOperation(_:)) { close(); return true }
        return false
    }

    override func close() {
        super.close()
        onClose?()
    }

    private var busy = false

    @objc private func sendOrStop() {
        if busy { onStop?(); return }
        let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input.stringValue = ""
        onSend?(text)
    }

    @objc private func newChat() { onNewChat?() }

    func restoreInput(_ text: String) { if input.stringValue.isEmpty { input.stringValue = text } }

    private func setBusy(_ b: Bool) {
        busy = b
        sendButton.image = NSImage(systemSymbolName: b ? "stop.fill" : "arrow.up.circle.fill", accessibilityDescription: b ? "Stop" : "Send")
        sendButton.toolTip = b ? "Stop" : "Send"
    }

    func show(near pet: CGPoint, scale: CGFloat) {
        if !isVisible {
            let screen = NSScreen.screens.first { $0.frame.contains(pet) } ?? NSScreen.main
            let vf = screen?.visibleFrame ?? .zero
            var x = pet.x + 60 * scale
            if x + frame.width > vf.maxX - 8 { x = pet.x - 60 * scale - frame.width }
            let y = min(max(pet.y, vf.minY + 8), vf.maxY - frame.height - 8)
            setFrameOrigin(NSPoint(x: max(vf.minX + 8, x), y: y))
        }
        orderFrontRegardless()
        makeKey()
        makeFirstResponder(input)
    }

    /// Redraws the conversation. Cheap enough to call on every streamed chunk (throttled by the caller).
    func update(petName: String, history: [ChatMessage], streaming: String?, statusText: String, error: String?) {
        title = "Chat with \(petName)"
        setBusy(streaming != nil)
        status.stringValue = error.map { "⚠️ \($0)" } ?? statusText
        status.textColor = error == nil ? .secondaryLabelColor : .systemRed

        let out = NSMutableAttributedString()
        if history.isEmpty && streaming == nil {
            out.append(NSAttributedString(string: "Say hi to \(petName)! Ask anything: questions, writing, code, ideas.",
                                          attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.secondaryLabelColor]))
        }
        var items = history
        if let streaming { items.append(ChatMessage(role: "assistant", content: streaming.isEmpty ? "…" : streaming)) }
        for m in items {
            let isUser = m.role == "user"
            let header = NSMutableParagraphStyle()
            header.paragraphSpacingBefore = 10
            out.append(NSAttributedString(string: (isUser ? "You" : petName) + "\n", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 12),
                .foregroundColor: isUser ? NSColor.systemBlue : NSColor.systemOrange,
                .paragraphStyle: header,
            ]))
            out.append(Self.format(m.content))
            out.append(NSAttributedString(string: "\n"))
        }
        let atBottom = scroll.contentView.bounds.maxY >= transcript.bounds.height - 40
        transcript.textStorage?.setAttributedString(out)
        if atBottom || streaming != nil { transcript.scrollToEndOfDocument(nil) }
    }

    /// Light Markdown: **bold**, *italic*, `code`, links, and ``` code blocks in a monospaced font.
    static func format(_ text: String) -> NSAttributedString {
        let body = NSFont.systemFont(ofSize: 13)
        let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let out = NSMutableAttributedString()
        for (i, part) in text.components(separatedBy: "```").enumerated() {
            if i % 2 == 1 {
                var code = part
                if let nl = code.firstIndex(of: "\n") { code = String(code[code.index(after: nl)...]) } // drop language tag
                out.append(NSAttributedString(string: code.trimmingCharacters(in: .newlines) + "\n", attributes: [
                    .font: mono, .foregroundColor: NSColor.labelColor, .backgroundColor: NSColor.quaternaryLabelColor,
                ]))
                continue
            }
            let (plain, math) = LaTeX.extract(part)
            let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            let ns: NSMutableAttributedString
            if let md = try? AttributedString(markdown: plain, options: options) {
                ns = NSMutableAttributedString(md)
                ns.enumerateAttributes(in: NSRange(location: 0, length: ns.length)) { attrs, range, _ in
                    var font = body
                    if let intent = attrs[.inlinePresentationIntent] as? UInt {
                        let p = InlinePresentationIntent(rawValue: intent)
                        if p.contains(.code) { font = mono }
                        else if p.contains(.stronglyEmphasized) { font = .boldSystemFont(ofSize: 13) }
                        else if p.contains(.emphasized) { font = NSFontManager.shared.convert(body, toHaveTrait: .italicFontMask) }
                    }
                    ns.addAttributes([.font: font, .foregroundColor: NSColor.labelColor], range: range)
                }
            } else {
                ns = NSMutableAttributedString(string: plain, attributes: [.font: body, .foregroundColor: NSColor.labelColor])
            }
            if !math.isEmpty { insertMath(math, into: ns) }
            out.append(ns)
        }
        return out
    }

    /// Swaps LaTeX placeholders for their Unicode rendering; display math gets its own centered line.
    private static func insertMath(_ math: [LaTeX.Segment], into ns: NSMutableAttributedString) {
        let s = ns.string as NSString
        for idx in stride(from: s.length - 1, through: 0, by: -1) {
            let k = Int(s.character(at: idx)) - Int(LaTeX.placeholderBase)
            guard k >= 0 && k < math.count else { continue }
            let m = math[k]
            var attrs = ns.attributes(at: idx, effectiveRange: nil)
            attrs[.foregroundColor] = NSColor.labelColor
            guard m.display else {
                ns.replaceCharacters(in: NSRange(location: idx, length: 1), with: NSAttributedString(string: m.text, attributes: attrs))
                continue
            }
            let rep = NSMutableAttributedString()
            if idx > 0 && s.character(at: idx - 1) != 10 { rep.append(NSAttributedString(string: "\n", attributes: attrs)) }
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            centered.paragraphSpacing = 4
            centered.paragraphSpacingBefore = 4
            attrs[.font] = NSFont.systemFont(ofSize: 14)
            attrs[.paragraphStyle] = centered
            rep.append(NSAttributedString(string: m.text, attributes: attrs))
            if idx + 1 < s.length && s.character(at: idx + 1) != 10 { rep.append(NSAttributedString(string: "\n", attributes: attrs)) }
            ns.replaceCharacters(in: NSRange(location: idx, length: 1), with: rep)
        }
    }
}
