import AppKit
import IOSurface

/// Transparent, borderless, always-on-top panel that never steals focus.
final class PetPanel: NSPanel {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

enum SceneRenderer {
    /// Draws the pet, particles and the speech bubble into a flipped context.
    static func draw(_ ctx: CGContext, bounds: NSRect, pose: Pose, particles: [Particle], bubble: String?) {
        let anchor = CGPoint(x: bounds.midX, y: bounds.maxY - 8)

        ctx.saveGState()
        ctx.translateBy(x: anchor.x, y: anchor.y + pose.bob)
        ctx.scaleBy(x: pose.scale * pose.facing, y: pose.scale * pose.squash)
        ctx.translateBy(x: 0, y: -45)
        ctx.rotate(by: pose.tilt)
        ctx.translateBy(x: 0, y: 45)
        PetRenderer.draw(ctx, pose)
        ctx.restoreGState()

        for p in particles {
            let alpha = min(1, p.life / 0.5)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: p.size * pose.scale, weight: .bold),
                .foregroundColor: p.color.withAlphaComponent(alpha),
            ]
            let s = NSAttributedString(string: p.glyph, attributes: attrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: anchor.x + p.x - sz.width / 2, y: anchor.y + p.y - sz.height / 2))
        }

        if let text = bubble {
            drawBubble(text, tipX: anchor.x, tipY: anchor.y - 110 * pose.scale, bounds: bounds)
        }
    }

    private static var cachedText = ""
    private static var cachedString = NSAttributedString()
    private static var cachedSize = NSSize.zero

    /// Size of the bubble body for `text` (cached), used to size the sprite.
    static func bubbleSize(_ text: String) -> NSSize {
        prepare(text)
        return NSSize(width: ceil(cachedSize.width) + 22, height: ceil(cachedSize.height) + 14)
    }

    private static func prepare(_ text: String) {
        if text != cachedText {
            let base = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
            let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 12.5) } ?? base
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            cachedString = NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: NSColor(white: 0.12, alpha: 1), .paragraphStyle: para,
            ])
            cachedSize = cachedString.boundingRect(with: NSSize(width: 230, height: 400),
                                                   options: [.usesLineFragmentOrigin, .usesFontLeading]).size
            cachedText = text
        }
    }

    static func drawBubble(_ text: String, tipX: CGFloat, tipY: CGFloat, bounds: NSRect) {
        prepare(text)
        let str = cachedString
        let w = ceil(cachedSize.width) + 22, h = ceil(cachedSize.height) + 14
        let x = min(max(tipX - w / 2, 4), bounds.width - w - 4)
        let y = max(4, tipY - h - 12)
        let rect = NSRect(x: x, y: y, width: w, height: h)

        let body = NSBezierPath(roundedRect: rect, xRadius: 11, yRadius: 11)
        let tail = NSBezierPath()
        let tx = min(max(tipX, rect.minX + 14), rect.maxX - 14)
        tail.move(to: NSPoint(x: tx - 7, y: rect.maxY - 1))
        tail.line(to: NSPoint(x: tx + 1, y: rect.maxY + 10))
        tail.line(to: NSPoint(x: tx + 7, y: rect.maxY - 1))
        tail.close()

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        NSColor(srgbRed: 0.22, green: 0.12, blue: 0.08, alpha: 1).setStroke()
        for p in [body, tail] { p.lineWidth = 3; p.stroke() }
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.setFill()
        body.fill()
        tail.fill()
        str.draw(with: NSRect(x: rect.minX + 11, y: rect.minY + 7, width: w - 22, height: h - 14),
                 options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}

/// Layer-hosting view: the pet lives in a small sprite layer that moves inside a larger, mostly
/// stationary window. Moving a layer is far cheaper than moving a window every frame.
final class PetView: NSView {
    let pet: Pet
    var menuProvider: (() -> NSMenu)?
    var onTalk: (() -> Void)?
    var spriteSize = NSSize(width: 160, height: 220)
    var spriteOrigin = CGPoint.zero
    private let sprite = CALayer()

    init(frame: NSRect, pet: Pet) {
        self.pet = pet
        super.init(frame: frame)
        let root = CALayer()
        layer = root
        wantsLayer = true
        sprite.anchorPoint = .zero
        sprite.contentsGravity = .resize
        root.addSublayer(sprite)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Two IOSurfaces we draw into directly and hand to Core Animation (zero-copy), alternating each frame.
    private var surfaces: [(IOSurface, CGContext)] = []
    private var surfaceIndex = 0

    private func makeSurfaces(width: Int, height: Int, space: CGColorSpace) {
        surfaces = (0..<2).compactMap { _ in
            let props: [IOSurfacePropertyKey: Any] = [
                .width: width, .height: height, .bytesPerElement: 4,
                .pixelFormat: 0x4247_5241, // 'BGRA'
            ]
            guard let surf = IOSurface(properties: props) else { return nil }
            if let plist = space.copyPropertyList() {
                IOSurfaceSetValue(unsafeBitCast(surf, to: IOSurfaceRef.self), "IOSurfaceColorSpace" as CFString, plist)
            }
            guard let ctx = CGContext(data: surf.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: surf.bytesPerRow, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            else { return nil }
            return (surf, ctx)
        }
    }

    func render() {
        let backing = window?.backingScaleFactor ?? 2
        let pw = Int(spriteSize.width * backing), ph = Int(spriteSize.height * backing)
        guard pw > 0, ph > 0 else { return }
        let space = window?.screen?.colorSpace?.cgColorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        if surfaces.first?.1.width != pw || surfaces.first?.1.height != ph || surfaces.first?.1.colorSpace != space {
            makeSurfaces(width: pw, height: ph, space: space)
        }
        guard !surfaces.isEmpty else { return }
        surfaceIndex = (surfaceIndex + 1) % surfaces.count
        let (surf, ctx) = surfaces[surfaceIndex]
        surf.lock(options: [], seed: nil)
        ctx.saveGState()
        ctx.clear(CGRect(x: 0, y: 0, width: pw, height: ph))
        ctx.translateBy(x: 0, y: CGFloat(ph))
        ctx.scaleBy(x: backing, y: -backing)
        let prev = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        SceneRenderer.draw(ctx, bounds: NSRect(origin: .zero, size: spriteSize), pose: pet.pose(),
                           particles: pet.particles, bubble: pet.bubbleText)
        NSGraphicsContext.current = prev
        ctx.restoreGState()
        surf.unlock(options: [], seed: nil)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sprite.frame = CGRect(origin: spriteOrigin, size: spriteSize)
        sprite.contents = surf
        CATransaction.commit()
    }

    /// Clickable area around WALL•E's body, in global coordinates; everything else passes through.
    func isOnPet(_ global: NSPoint) -> Bool {
        let s = pet.scale
        return NSRect(x: pet.pos.x - 44 * s, y: pet.pos.y - 12, width: 88 * s, height: 125 * s).contains(global)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) { onTalk?(); return }
        pet.mouseDown(at: NSEvent.mouseLocation)
    }
    override func mouseDragged(with event: NSEvent) { pet.mouseDragged(at: NSEvent.mouseLocation) }
    override func mouseUp(with event: NSEvent) { pet.mouseUp(at: NSEvent.mouseLocation, clickCount: event.clickCount) }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = menuProvider?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }
    }
}
