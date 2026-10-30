import AppKit

/// Renders a sheet of poses to a PNG so the art can be checked without launching the app.
enum Preview {
    static func render(to path: String) {
        var poses: [(String, Pose, String?)] = []
        poses.append(("idle", Pose(), nil))
        var p = Pose(); p.tailWag = 0.2; p.walkAmount = 1; p.walkPhase = 1; p.armL = 0.8; p.armR = -0.1; p.bob = -2
        poses.append(("walk", p, nil))
        p = Pose(); p.armR = 2.6; p.mouth = .grin
        poses.append(("wave", p, "Hi! I'm Mochi! Press ⌃⌥C to chat with me."))
        p = Pose(); p.legs = .sit; p.eyes = .closed; p.mouth = .flat; p.headTilt = 0.22
        poses.append(("sleep", p, nil))
        p = Pose(); p.armL = 2.8; p.armR = 2.0; p.tilt = 0.12; p.eyes = .happy; p.mouth = .grin; p.blush = true
        poses.append(("dance", p, "Aww, you think so? ♪"))
        p = Pose(); p.legs = .sit; p.armR = 2.5; p.held = .candy(0.8); p.eyes = .happy; p.blush = true; p.mouth = .munch; p.munchPhase = 1
        poses.append(("eat", p, nil))
        p = Pose(); p.post = true; p.lookX = -1; p.sweat = true; p.mouth = .wavy; p.tilt = -0.12; p.armL = 0.9; p.armR = 0.9
        poses.append(("hide", p, nil))
        p = Pose(); p.legs = .sit; p.held = .book; p.armL = -0.5; p.armR = -0.5; p.lookY = 1
        poses.append(("read", p, nil))
        p = Pose(); p.legs = .dangle; p.armL = 2.5; p.armR = 2.9; p.eyes = .surprised; p.mouth = .wavy; p.sweat = true
        poses.append(("grabbed", p, nil))
        p = Pose(); p.eyes = .dizzy; p.mouth = .wavy; p.tilt = 0.12; p.facing = -1
        poses.append(("dizzy", p, nil))
        p = Pose(); p.eyes = .angry; p.mouth = .wavy; p.blush = true
        poses.append(("mood: angry", p, "Hey!"))
        p = Pose(); p.eyes = .happy; p.blush = true; p.mouth = .wavy; p.headTilt = 0.12
        poses.append(("mood: shy", p, nil))
        p = Pose(); p.eyes = .closed; p.mouth = .flat; p.headTilt = 0.18; p.armL = 0.1; p.armR = 0.1
        poses.append(("mood: sad", p, nil))
        p = Pose(); p.mouth = .open; p.headTilt = -0.15; p.lookY = -0.4
        poses.append(("mood: curious", p, "• • •"))
        p = Pose(); p.legs = .sit; p.eyes = .happy; p.mouth = .grin
        poses.append(("chat reply", p, "Sure! A closure in Swift is a self-contained block of code you can pass around and call later …"))
        p = Pose(); p.isClimbing = true; p.climbPhase = 1.2
        poses.append(("climb (side view)", p, "Up we go! 🧗"))
        p = Pose(); p.isRopeway = true; p.walkPhase = 2.0; p.eyes = .happy; p.mouth = .grin
        poses.append(("ropeway (zipline)", p, "Wheeeeee! 🚠"))


        let cell = NSSize(width: 260, height: 300)
        let cols = 5
        let rows = (poses.count + cols - 1) / cols
        let W = Int(cell.width) * cols, H = Int(cell.height) * rows
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W * 2, pixelsHigh: H * 2, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = NSSize(width: W, height: H)
        guard let base = NSGraphicsContext(bitmapImageRep: rep) else { return }
        let cg = base.cgContext
        cg.translateBy(x: 0, y: CGFloat(H))
        cg.scaleBy(x: 1, y: -1)
        let ctx = NSGraphicsContext(cgContext: cg, flipped: true)
        NSGraphicsContext.current = ctx
        cg.setFillColor(CGColor(srgbRed: 0.93, green: 0.95, blue: 0.98, alpha: 1))
        cg.fill(CGRect(x: 0, y: 0, width: W, height: H))

        for (i, item) in poses.enumerated() {
            let ox = CGFloat(i % cols) * cell.width, oy = CGFloat(i / cols) * cell.height
            cg.saveGState()
            cg.translateBy(x: ox, y: oy)
            SceneRenderer.draw(cg, bounds: NSRect(origin: .zero, size: cell), pose: item.1, particles: [], bubble: item.2)
            NSAttributedString(string: item.0, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)])
                .draw(at: NSPoint(x: 8, y: 6))
            cg.restoreGState()
        }
        NSGraphicsContext.current = nil
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}

extension Preview {
    /// Times offscreen rendering of a walking frame: `MacPet --bench`.
    static func bench() {
        let size = NSSize(width: 160, height: 220)
        let ctx = CGContext(data: nil, width: 320, height: 440, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        ctx.translateBy(x: 0, y: 440)
        ctx.scaleBy(x: 2, y: -2)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        var p = Pose()
        p.walkAmount = 1
        let n = 600
        let t0 = CACurrentMediaTime()
        for i in 0..<n {
            p.walkPhase = CGFloat(i) * 0.3
            p.armL = 0.3 + sin(p.walkPhase) * 0.45
            ctx.clear(CGRect(x: 0, y: 0, width: 160, height: 220))
            SceneRenderer.draw(ctx, bounds: NSRect(origin: .zero, size: size), pose: p, particles: [], bubble: nil)
            _ = ctx.makeImage()
        }
        let ms = (CACurrentMediaTime() - t0) / Double(n) * 1000
        print(String(format: "%.3f ms per frame -> %.1f%% CPU at 30 fps", ms, ms * 30 / 10))
    }
}

extension Preview {
    /// Streams one question to a local Ollama model and prints the reply: `MacPet --ask "question" [model]`.
    @MainActor
    static func ask(_ question: String, model: String) async {
        let start = Date()
        var first: Date?
        do {
            for try await chunk in Backends.ollama(model: model, system: nil, messages: [ChatMessage(role: "user", content: question)]) {
                if first == nil { first = Date() }
                print(chunk, terminator: "")
                fflush(stdout)
            }
            print(String(format: "\n[first words after %.1fs, done in %.1fs]",
                         (first ?? Date()).timeIntervalSince(start), Date().timeIntervalSince(start)))
        } catch {
            print("\nERROR:", error.localizedDescription)
        }
    }
}
