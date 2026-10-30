import AppKit

/// The walkable top edge of another app's window, in Cocoa global coordinates.
struct Platform {
    let id: CGWindowID
    let minX: CGFloat
    let maxX: CGFloat
    let y: CGFloat
    let frameX: CGFloat
    let owner: String
}

/// Knows about screens, the Dock-safe floor, and the tops of other windows.
final class World {
    private(set) var platforms: [Platform] = []

    var mainHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 900 }

    var xBounds: (CGFloat, CGFloat) {
        let fs = NSScreen.screens.map(\.frame)
        return (fs.map(\.minX).min() ?? 0, fs.map(\.maxX).max() ?? 1440)
    }

    func screen(atX x: CGFloat, y: CGFloat) -> NSScreen? {
        let cands = NSScreen.screens.filter { x >= $0.frame.minX && x < $0.frame.maxX }
        if cands.isEmpty { return nil }
        if let s = cands.first(where: { y >= $0.frame.minY - 2 && y <= $0.frame.maxY }) { return s }
        let below = cands.filter { $0.frame.maxY <= y }
        return below.max(by: { $0.frame.maxY < $1.frame.maxY }) ?? cands.min(by: { $0.frame.minY < $1.frame.minY })
    }

    func floor(atX x: CGFloat, y: CGFloat) -> CGFloat {
        if let s = screen(atX: x, y: y) { return s.visibleFrame.minY }
        return NSScreen.screens.map(\.visibleFrame.minY).min() ?? 0
    }

    func ceiling(atX x: CGFloat, y: CGFloat) -> CGFloat {
        screen(atX: x, y: y)?.visibleFrame.maxY ?? 10_000
    }

    var startPoint: CGPoint {
        let v = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return CGPoint(x: v.midX, y: v.maxY - 160)
    }

    func segments(id: CGWindowID) -> [Platform] { platforms.filter { $0.id == id } }

    /// Highest surface crossed while falling from `fromY` to `toY` at `x`.
    func landing(x: CGFloat, fromY: CGFloat, toY: CGFloat) -> (y: CGFloat, platform: Platform?)? {
        var best: (y: CGFloat, platform: Platform?)?
        let f = floor(atX: x, y: fromY)
        if toY <= f { best = (f, nil) }
        for p in platforms where x >= p.minX && x <= p.maxX && p.y <= fromY + 0.5 && p.y >= toY {
            if best == nil || p.y > best!.y { best = (p.y, p) }
        }
        return best
    }

    func refresh(enabled: Bool) {
        guard enabled else { platforms = []; return }
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        let myPID = ProcessInfo.processInfo.processIdentifier
        let mainH = mainHeight

        // Front-to-back list of normal app windows (CG coordinates, origin top-left).
        var rects: [(CGWindowID, CGRect)] = []
        var owners: [CGWindowID: String] = [:]
        for w in info {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != myPID,
                  let num = w[kCGWindowNumber as String] as? Int,
                  let bounds = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { continue }
            if let a = w[kCGWindowAlpha as String] as? Double, a < 0.1 { continue }
            rects.append((CGWindowID(num), r))
            owners[CGWindowID(num)] = w[kCGWindowOwnerName as String] as? String ?? "an app"
        }

        var result: [Platform] = []
        for (i, (id, r)) in rects.enumerated() {
            guard r.width >= 140, r.height >= 100 else { continue }
            let topY = mainH - r.minY
            guard let scr = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: r.midX, y: topY - 1)) }),
                  topY < scr.visibleFrame.maxY - 90 else { continue }

            // Remove the parts of this top edge that windows in front of it cover.
            var segs: [(CGFloat, CGFloat)] = [(r.minX + 12, r.maxX - 12)]
            for j in 0..<i {
                let f = rects[j].1
                if f.minY <= r.minY + 1 && f.maxY >= r.minY - 1 {
                    segs = segs.flatMap { s -> [(CGFloat, CGFloat)] in
                        let a = f.minX - 15, b = f.maxX + 15
                        if b <= s.0 || a >= s.1 { return [s] }
                        var out: [(CGFloat, CGFloat)] = []
                        if a > s.0 { out.append((s.0, a)) }
                        if b < s.1 { out.append((b, s.1)) }
                        return out
                    }
                }
            }
            for s in segs where s.1 - s.0 >= 50 {
                result.append(Platform(id: id, minX: s.0, maxX: s.1, y: topY, frameX: r.minX, owner: owners[id] ?? "an app"))
            }
        }
        platforms = result
    }
}
