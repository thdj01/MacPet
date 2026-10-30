import AppKit

private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

/// Chassis finishes the user can pick from the menu.
enum Coat: String, CaseIterable {
    case ginger, gray, charcoal, cream

    var title: String {
        switch self {
        case .ginger: return "WALL•E (Classic)"
        case .gray: return "EVE (Clean White)"
        case .charcoal: return "BURN•E (Welder)"
        case .cream: return "M•O (Cleaner)"
        }
    }

    var colors: (fur: CGColor, dark: CGColor, belly: CGColor) {
        let p = profile
        return (p.chassis, p.metalDark, p.accent)
    }

    struct Profile {
        let chassis: CGColor
        let chassisDark: CGColor
        let metal: CGColor
        let metalDark: CGColor
        let eyeLens: CGColor
        let eyeGlow: CGColor
        let accent: CGColor
        let meter: CGColor
        let outline: CGColor
    }

    var profile: Profile {
        func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
            Palette.c(r, g, b, a)
        }
        switch self {
        case .ginger:
            // Classic weathered industrial yellow WALL-E
            return Profile(
                chassis: c(0.93, 0.68, 0.22),
                chassisDark: c(0.68, 0.44, 0.16),
                metal: c(0.52, 0.50, 0.48),
                metalDark: c(0.24, 0.23, 0.24),
                eyeLens: c(0.18, 0.65, 0.92),
                eyeGlow: c(0.45, 0.85, 1.0),
                accent: c(0.85, 0.22, 0.20),
                meter: c(0.30, 0.88, 0.35),
                outline: c(0.14, 0.12, 0.12)
            )
        case .gray:
            // Sleek pearlescent EVE space finish
            return Profile(
                chassis: c(0.95, 0.96, 0.98),
                chassisDark: c(0.78, 0.80, 0.85),
                metal: c(0.68, 0.72, 0.78),
                metalDark: c(0.18, 0.20, 0.24),
                eyeLens: c(0.10, 0.70, 1.0),
                eyeGlow: c(0.40, 0.88, 1.0),
                accent: c(0.20, 0.60, 0.95),
                meter: c(0.20, 0.80, 1.0),
                outline: c(0.12, 0.14, 0.18)
            )
        case .charcoal:
            // Dark graphite industrial welder robot
            return Profile(
                chassis: c(0.32, 0.30, 0.32),
                chassisDark: c(0.20, 0.18, 0.20),
                metal: c(0.48, 0.46, 0.48),
                metalDark: c(0.14, 0.13, 0.15),
                eyeLens: c(1.0, 0.55, 0.15),
                eyeGlow: c(1.0, 0.80, 0.30),
                accent: c(1.0, 0.40, 0.15),
                meter: c(1.0, 0.65, 0.20),
                outline: c(0.08, 0.08, 0.09)
            )
        case .cream:
            // Vintage sun-bleached desert cleaner
            return Profile(
                chassis: c(0.96, 0.90, 0.76),
                chassisDark: c(0.78, 0.70, 0.54),
                metal: c(0.60, 0.58, 0.54),
                metalDark: c(0.25, 0.24, 0.22),
                eyeLens: c(0.25, 0.78, 0.45),
                eyeGlow: c(0.50, 0.95, 0.65),
                accent: c(0.85, 0.45, 0.25),
                meter: c(0.35, 0.85, 0.45),
                outline: c(0.18, 0.15, 0.12)
            )
        }
    }
}

enum Palette {
    static func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    static var chassis = Coat.ginger.profile.chassis
    static var chassisDark = Coat.ginger.profile.chassisDark
    static var metal = Coat.ginger.profile.metal
    static var metalDark = Coat.ginger.profile.metalDark
    static var eyeLens = Coat.ginger.profile.eyeLens
    static var eyeGlow = Coat.ginger.profile.eyeGlow
    static var accent = Coat.ginger.profile.accent
    static var meter = Coat.ginger.profile.meter
    static var outline = Coat.ginger.profile.outline

    // Compatibility properties for external references
    static var fur: CGColor { get { chassis } set { chassis = newValue } }
    static var furDark: CGColor { get { chassisDark } set { chassisDark = newValue } }
    static var belly: CGColor { get { metal } set { metal = newValue } }
    static var earInner: CGColor { metal }
    static var nose: CGColor { accent }
    static var pad: CGColor { metalDark }
    static var eyeIris: CGColor { eyeLens }
    static var eyeIrisLight: CGColor { eyeGlow }

    static let white = c(1, 1, 1)
    static let black = c(0.06, 0.06, 0.06)
    static let red = c(0.92, 0.20, 0.20)
    static let yellow = c(1.0, 0.85, 0.20)
    static let green = c(0.25, 0.85, 0.35)
    static let glass = c(0.10, 0.14, 0.18)
    static let glassReflect = c(1, 1, 1, 0.55)
    static let rust = c(0.55, 0.35, 0.18, 0.6)
    static let blush = c(1.0, 0.35, 0.45, 0.5)
    static let sweat = c(0.55, 0.80, 1.0, 0.95)
    static let candy = c(1.0, 0.70, 0.85)
    static let stick = c(0.92, 0.85, 0.70)
    static let book = c(0.20, 0.42, 0.70)
    static let wood = c(0.62, 0.46, 0.30)
}

/// Renders WALL•E: the iconic compacting robot with binocular camera eyes, cube chassis, tank treads, and hydraulic arms.
enum PetRenderer {
    static let sides: [CGFloat] = [-1, 1]

    static func setCoat(_ coat: Coat) {
        let p = coat.profile
        Palette.chassis = p.chassis
        Palette.chassisDark = p.chassisDark
        Palette.metal = p.metal
        Palette.metalDark = p.metalDark
        Palette.eyeLens = p.eyeLens
        Palette.eyeGlow = p.eyeGlow
        Palette.accent = p.accent
        Palette.meter = p.meter
        Palette.outline = p.outline
    }

    // MARK: Primitives

    static func paint(_ c: CGContext, _ fill: CGColor, _ stroke: Bool = true, _ lw: CGFloat = 1.3) {
        c.setFillColor(fill)
        if stroke {
            c.setStrokeColor(Palette.outline)
            c.setLineWidth(lw)
            c.drawPath(using: .fillStroke)
        } else {
            c.fillPath()
        }
    }

    static func ellipse(_ c: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                        _ fill: CGColor, stroke: Bool = true, lw: CGFloat = 1.2) {
        c.beginPath()
        c.addEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        paint(c, fill, stroke, lw)
    }

    static func rrect(_ c: CGContext, _ r: CGRect, _ rad: CGFloat, _ fill: CGColor, stroke: Bool = true, lw: CGFloat = 1.2) {
        let rr = min(rad, r.width / 2 - 0.01, r.height / 2 - 0.01)
        c.beginPath()
        c.addPath(CGPath(roundedRect: r, cornerWidth: rr, cornerHeight: rr, transform: nil))
        paint(c, fill, stroke, lw)
    }

    static func line(_ c: CGContext, _ pts: [CGPoint], _ w: CGFloat, _ color: CGColor) {
        c.beginPath()
        c.addLines(between: pts)
        c.setStrokeColor(color)
        c.setLineWidth(w)
        c.strokePath()
    }

    // MARK: Main Character Draw

    static func draw(_ c: CGContext, _ p: Pose) {
        c.setLineJoin(.round)
        c.setLineCap(.round)

        if p.post {
            drawHiding(c, p)
            return
        }

        if p.isClimbing {
            drawClimbingSideView(c, p)
            return
        }

        if p.isRopeway {
            drawRopeway(c, p)
            return
        }

        // Treads on ground
        drawTreads(c, p)

        // Main compactor cube chassis
        drawChassis(c, p)

        // Hydraulic shovel arms
        drawArms(c, p)

        // Articulated neck & binocular camera eyes
        drawNeckAndEyes(c, p)

        // Held items (candy, book, etc.)
        drawHeld(c, p)
    }

    // MARK: Tank Treads

    static func drawTreads(_ c: CGContext, _ p: Pose) {
        let ph = p.walkPhase
        let moving = p.walkAmount > 0
        let treadY: CGFloat = (p.legs == .sit && p.eyes == .closed) ? -1 : 0

        // Left and right tank tread modules
        for s in sides {
            let tx = s * 20.0
            c.saveGState()
            if p.legs == .dangle {
                c.translateBy(x: tx, y: -16)
                c.rotate(by: s * -0.07)
                c.translateBy(x: -tx, y: 16)
            }

            // Tread outer triangular belt contour
            let treadPath = CGMutablePath()
            treadPath.move(to: P(tx - 11, treadY - 17))
            treadPath.addLine(to: P(tx + 11, treadY - 17))
            treadPath.addQuadCurve(to: P(tx + 14, treadY - 2), control: P(tx + 15, treadY - 9))
            treadPath.addLine(to: P(tx - 14, treadY - 2))
            treadPath.addQuadCurve(to: P(tx - 11, treadY - 17), control: P(tx - 15, treadY - 9))
            treadPath.closeSubpath()

            // Dark rubber tread belt
            c.beginPath(); c.addPath(treadPath)
            paint(c, Palette.metalDark, true, 1.4)

            // Inner wheel well
            let well = CGRect(x: tx - 9.5, y: treadY - 15, width: 19, height: 11.5)
            rrect(c, well, 3.5, Palette.c(0.18, 0.17, 0.18), stroke: false)

            // Road wheels (sprockets) inside the tread
            for wx in [tx - 5.5, tx + 5.5] {
                ellipse(c, wx, treadY - 8.5, 4.0, 4.0, Palette.metal, stroke: true, lw: 1.0)
                ellipse(c, wx, treadY - 8.5, 1.5, 1.5, Palette.metalDark, stroke: false)
            }
            // Center roller
            ellipse(c, tx, treadY - 6.5, 2.6, 2.6, Palette.metal, stroke: true, lw: 0.9)

            // Tread cleats moving with walkPhase
            let rot = moving ? ph * 2.0 : 0
            for i in 0..<6 {
                let off = CGFloat(i) * 4.6 - 11.5 + (moving ? CGFloat(sin(Double(rot + CGFloat(i)))) * 1.5 : 0)
                line(c, [P(tx + off, treadY - 1.8), P(tx + off, treadY - 0.2)], 1.3, Palette.metal)
            }
            c.restoreGState()
        }
    }

    // MARK: Compactor Box Chassis

    static func drawChassis(_ c: CGContext, _ p: Pose) {
        let compacted = (p.legs == .sit && p.eyes == .closed)
        let chY: CGFloat = compacted ? -14 : -16
        let chH: CGFloat = compacted ? 22 : 28

        // Main cube body
        let bodyRect = CGRect(x: -17, y: chY - chH, width: 34, height: chH)
        rrect(c, bodyRect, 3.5, Palette.chassis, stroke: true, lw: 1.4)

        // Upper lip / lid rim
        rrect(c, CGRect(x: -18.5, y: chY - chH - 2.5, width: 37, height: 4.2), 1.8, Palette.metal, stroke: true, lw: 1.1)

        // Front compactor door hatch seams
        line(c, [P(0, chY - chH + 2), P(0, chY - 2)], 1.1, Palette.c(0.3, 0.2, 0.1, 0.5))
        line(c, [P(-15, chY - chH * 0.5), P(15, chY - chH * 0.5)], 1.0, Palette.c(0.3, 0.2, 0.1, 0.4))

        // Rust weathering patches on corners
        ellipse(c, -13, chY - 5, 3.5, 2.5, Palette.rust, stroke: false)
        ellipse(c, 12, chY - chH + 6, 3.0, 2.5, Palette.rust, stroke: false)

        // Solar Charge Gauge / Battery Meter (Iconic Wall-E chest display!)
        let meterRect = CGRect(x: -11, y: chY - chH + 6, width: 22, height: 5.5)
        rrect(c, meterRect, 1.4, Palette.c(0.12, 0.12, 0.14), stroke: true, lw: 0.9)

        // Glowing LED charge bars
        let barCount = (p.eyes == .closed) ? 1 : 4
        for b in 0..<4 {
            let bx = -8.5 + CGFloat(b) * 4.6
            let col = b < barCount ? (b == 3 ? Palette.meter : (b == 2 ? Palette.yellow : Palette.red)) : Palette.c(0.25, 0.25, 0.25)
            rrect(c, CGRect(x: bx, y: chY - chH + 7.2, width: 3.4, height: 3.1), 0.7, col, stroke: false)
        }

        // Circular "WALL•E" logo badge on front door
        ellipse(c, -8.0, chY - 8.0, 3.2, 3.2, Palette.c(0.85, 0.22, 0.20), stroke: true, lw: 0.8)
        ellipse(c, -8.0, chY - 8.0, 1.4, 1.4, Palette.yellow, stroke: false)

        // Warning hazard stripes at lower edge
        line(c, [P(2, chY - 2.5), P(6, chY - 7.5)], 1.3, Palette.c(0.15, 0.15, 0.15, 0.6))
        line(c, [P(7, chY - 2.5), P(11, chY - 7.5)], 1.3, Palette.c(0.15, 0.15, 0.15, 0.6))
    }

    // MARK: Hydraulic Arms & Shovel Grippers

    static func drawArms(_ c: CGContext, _ p: Pose) {
        let compacted = (p.legs == .sit && p.eyes == .closed)
        if compacted {
            // Folded flat into side slots
            rrect(c, CGRect(x: -20.0, y: -32, width: 3.0, height: 16), 1.2, Palette.metal, stroke: true, lw: 0.9)
            rrect(c, CGRect(x: 17.0, y: -32, width: 3.0, height: 16), 1.2, Palette.metal, stroke: true, lw: 0.9)
            return
        }

        let angles = [p.armL, p.armR]
        for (i, s) in sides.enumerated() {
            let a = angles[i]
            let sh = P(s * 18.0, -30)

            // Shoulder swivel bracket
            ellipse(c, sh.x, sh.y, 2.8, 2.8, Palette.metalDark, stroke: true, lw: 1.0)

            // Hand destination based on arm angle
            let h = handPoint(side: s, angle: a)

            // Hydraulic piston strut connecting shoulder to hand
            let mid = P((sh.x + h.x) * 0.5 + s * 2.0, (sh.y + h.y) * 0.5)
            line(c, [sh, mid], 5.2, Palette.outline)
            line(c, [sh, mid], 3.4, Palette.metal)
            line(c, [mid, h], 4.4, Palette.outline)
            line(c, [mid, h], 2.8, Palette.metal)

            // Mechanical Shovel / Gripper Hand
            drawGripper(c, at: h, side: s, angle: a)
        }
    }

    static func drawGripper(_ c: CGContext, at pt: CGPoint, side s: CGFloat, angle a: CGFloat) {
        c.saveGState()
        c.translateBy(x: pt.x, y: pt.y)

        // Wrist pivot
        ellipse(c, 0, 0, 2.4, 2.4, Palette.metalDark, stroke: false)

        // 3-finger metallic scoop/shovel gripper
        let open = a > 1.4 // spread wide when waving or dancing
        let spread: CGFloat = open ? 4.2 : 2.2

        line(c, [P(0, 0), P(s * 5, -spread)], 2.0, Palette.outline)
        line(c, [P(0, 0), P(s * 5, -spread)], 1.2, Palette.metal)

        line(c, [P(0, 0), P(s * 6, 0)], 2.0, Palette.outline)
        line(c, [P(0, 0), P(s * 6, 0)], 1.2, Palette.metal)

        line(c, [P(0, 0), P(s * 5, spread)], 2.0, Palette.outline)
        line(c, [P(0, 0), P(s * 5, spread)], 1.2, Palette.metal)

        c.restoreGState()
    }

    // MARK: Articulated Neck & Binocular Visor Eyes

    static func drawNeckAndEyes(_ c: CGContext, _ p: Pose) {
        let compacted = (p.legs == .sit && p.eyes == .closed)

        c.saveGState()

        if compacted {
            // Head retracted snug against the top of the chassis
            c.translateBy(x: 0, y: -42)
            drawBinocularEyes(c, p: p, compacted: true)
            c.restoreGState()
            return
        }

        // Neck stalk rising from chassis
        let neckBase = P(0, -44)
        let neckTop = P(p.lookX * 2.0, -58)

        // Articulated hydraulic pistons / spine segments
        line(c, [neckBase, neckTop], 7.2, Palette.outline)
        line(c, [neckBase, neckTop], 4.6, Palette.metal)
        for t in [0.3, 0.7] {
            let py = neckBase.y + (neckTop.y - neckBase.y) * CGFloat(t)
            rrect(c, CGRect(x: -4.5, y: py - 1.5, width: 9, height: 3.0), 1.2, Palette.metalDark, stroke: true, lw: 0.8)
        }

        // Head mount & tilt
        c.translateBy(x: neckTop.x, y: neckTop.y)
        c.rotate(by: p.headTilt + p.lookX * 0.08)

        drawBinocularEyes(c, p: p, compacted: false)

        c.restoreGState()
    }

    static func drawBinocularEyes(_ c: CGContext, p: Pose, compacted: Bool) {
        var tiltL: CGFloat = 0
        var tiltR: CGFloat = 0

        switch p.eyes {
        case .happy:
            tiltL = -0.15; tiltR = 0.15
        case .surprised:
            tiltL = 0.0; tiltR = 0.0
        case .angry:
            tiltL = 0.25; tiltR = -0.25
        case .dizzy:
            tiltL = -0.35; tiltR = -0.35
        case .closed:
            tiltL = 0.18; tiltR = -0.18
        case .open:
            tiltL = -0.06; tiltR = 0.06
        }

        // Bridge bracket connecting the two binocular units
        rrect(c, CGRect(x: -5.5, y: -5, width: 11, height: 6), 1.8, Palette.metalDark, stroke: true, lw: 1.0)
        ellipse(c, 0, -2.0, 1.5, 1.5, Palette.metal, stroke: false)

        // Left & Right Binocular Units
        for (i, s) in sides.enumerated() {
            let tilt = (i == 0 ? tiltL : tiltR)
            let eyeX = s * 9.5

            c.saveGState()
            c.translateBy(x: eyeX, y: -4.0)
            c.rotate(by: tilt)

            // Binocular housing contour (teardrop / rounded trapezoid camera housing)
            let housing = CGMutablePath()
            housing.move(to: P(s * 2.0, -9.5))
            housing.addLine(to: P(-s * 8.0, -9.5))
            housing.addQuadCurve(to: P(-s * 9.5, 7.0), control: P(-s * 10.5, -1))
            housing.addLine(to: P(s * 4.5, 7.0))
            housing.addQuadCurve(to: P(s * 2.0, -9.5), control: P(s * 5.5, -1))
            housing.closeSubpath()

            // Outer weathered metal housing
            c.beginPath(); c.addPath(housing)
            paint(c, Palette.metal, true, 1.4)

            // Top visor brow plate (weathered bronze)
            let brow = CGMutablePath()
            brow.move(to: P(s * 2.5, -10.5))
            brow.addLine(to: P(-s * 9.5, -10.5))
            brow.addLine(to: P(-s * 8.0, -8.0))
            brow.addLine(to: P(s * 2.0, -8.0))
            brow.closeSubpath()
            c.beginPath(); c.addPath(brow)
            paint(c, Palette.chassisDark, true, 1.1)

            // Optical Glass Camera Lens Unit
            let lx = -s * 2.0
            let ly: CGFloat = -0.5
            let lr: CGFloat = 6.6

            // Dark camera lens rim
            ellipse(c, lx, ly, lr + 0.6, lr + 0.6, Palette.black, stroke: true, lw: 1.2)

            // Deep optical glass lens
            ellipse(c, lx, ly, lr, lr, Palette.glass, stroke: false)

            if compacted || p.eyes == .closed {
                // Dimmed sleeping camera lens with single soft amber LED point
                ellipse(c, lx, ly, 1.5, 1.5, Palette.c(0.4, 0.3, 0.1), stroke: false)
            } else if p.eyes == .surprised {
                // Wide dilated glowing lens
                ellipse(c, lx, ly, lr * 0.85, lr * 0.85, Palette.eyeGlow, stroke: false)
                ellipse(c, lx, ly, lr * 0.55, lr * 0.55, Palette.white, stroke: false)
            } else {
                // Luminous optical camera aperture with pupil aperture tracking
                let ox = p.lookX * 2.0
                let oy = p.lookY * 1.5

                // Blue optical aperture glow
                ellipse(c, lx, ly, lr * 0.78, lr * 0.78, Palette.eyeLens, stroke: false)
                ellipse(c, lx + ox * 0.3, ly + oy * 0.3, lr * 0.55, lr * 0.55, Palette.eyeGlow, stroke: false)

                // Central camera aperture pupil
                ellipse(c, lx + ox * 0.6, ly + oy * 0.6, 2.2, 2.2, Palette.black, stroke: false)

                // Specular lens reflection curved highlight (magical Pixar glass look!)
                let glint = CGMutablePath()
                glint.addArc(center: P(lx, ly), radius: lr * 0.65, startAngle: -.pi * 0.85, endAngle: -.pi * 0.25, clockwise: false)
                c.beginPath(); c.addPath(glint)
                c.setStrokeColor(Palette.glassReflect); c.setLineWidth(1.6); c.strokePath()

                // Small secondary glint
                ellipse(c, lx + 1.5, ly - 2.5, 1.1, 1.1, Palette.white, stroke: false)
            }

            c.restoreGState()
        }

        // Blush: cute warm LED glow on sides of eyes
        if p.blush {
            ellipse(c, -13, 2, 3.5, 2.5, Palette.blush, stroke: false)
            ellipse(c, 13, 2, 3.5, 2.5, Palette.blush, stroke: false)
        }

        // Sweat droplet for startled / flustered poses
        if p.sweat {
            let sx: CGFloat = 16, sy: CGFloat = -18
            c.beginPath()
            c.move(to: P(sx, sy - 8))
            c.addQuadCurve(to: P(sx + 3.0, sy), control: P(sx + 2.5, sy - 3.0))
            c.addArc(center: P(sx, sy), radius: 3.0, startAngle: 0, endAngle: .pi, clockwise: false)
            c.addQuadCurve(to: P(sx, sy - 8), control: P(sx - 2.5, sy - 3.0))
            paint(c, Palette.sweat, true, 1.0)
        }
    }

    // MARK: Hiding Behind Post

    static func drawHiding(_ c: CGContext, _ p: Pose) {
        // Wooden post
        rrect(c, CGRect(x: -7, y: -150, width: 14, height: 150), 3.0, Palette.wood, lw: 1.2)
        for y in stride(from: -140.0, through: -10.0, by: 12.0) {
            line(c, [P(-6, CGFloat(y)), P(6, CGFloat(y + 2))], 0.8, Palette.c(0.48, 0.35, 0.22))
        }

        // Wall-E body peeking from behind post
        c.saveGState()
        c.translateBy(x: 12, y: 0)
        drawTreads(c, p)
        drawChassis(c, p)
        c.restoreGState()

        // Binocular eyes peeking around the edge of the wood
        c.saveGState()
        c.translateBy(x: 10, y: -58)
        c.rotate(by: -0.15)
        drawBinocularEyes(c, p: p, compacted: false)
        c.restoreGState()

        // One metal gripper holding the side of the post
        drawGripper(c, at: P(6, -30), side: -1, angle: 0.8)
    }

    // MARK: Climbing Wall (WALL•E Full Profile / Side View)

    static func drawClimbingSideView(_ c: CGContext, _ p: Pose) {
        let ph = p.climbPhase
        let goingDown = p.climbGoingDown

        // 1. The Vertical Screen Wall Line
        line(c, [P(-20, -85), P(-20, 15)], 3.0, Palette.metalDark)
        line(c, [P(-20, -85), P(-20, 15)], 1.2, Palette.c(0.65, 0.72, 0.82, 0.6))
        // Wall texture rungs / grip slots
        for y in stride(from: -80.0, through: 10.0, by: 15.0) {
            line(c, [P(-22, CGFloat(y)), P(-18, CGFloat(y))], 1.4, Palette.c(0.4, 0.45, 0.52))
        }

        // 2. Far Arm (Background Arm reaching high up to grip the wall)
        let farPhase = ph
        let handFarY = -56.0 - sin(Double(farPhase)) * 14.0
        let handFar = P(-19, CGFloat(handFarY))
        let shFar = P(-4, -30)

        // Far arm hydraulic struts
        let midFar = P((shFar.x + handFar.x) * 0.5 - 2, (shFar.y + handFar.y) * 0.5)
        line(c, [shFar, midFar], 4.8, Palette.outline)
        line(c, [shFar, midFar], 3.0, Palette.metalDark)
        line(c, [midFar, handFar], 4.0, Palette.outline)
        line(c, [midFar, handFar], 2.4, Palette.metal)
        // Far gripper holding wall
        drawGripper(c, at: handFar, side: -1, angle: 1.0)

        // 3. Side View of Tank Tread (Signature WALL•E Profile!)
        let treadPath = CGMutablePath()
        treadPath.move(to: P(-15, -2))
        treadPath.addLine(to: P(15, -2))
        treadPath.addQuadCurve(to: P(18, -6), control: P(18, -3))
        treadPath.addLine(to: P(0, -18))
        treadPath.addQuadCurve(to: P(-4, -18), control: P(-2, -19.5))
        treadPath.addLine(to: P(-17, -6))
        treadPath.addQuadCurve(to: P(-15, -2), control: P(-18, -3))
        treadPath.closeSubpath()

        // Heavy dark rubber belt
        c.beginPath(); c.addPath(treadPath)
        paint(c, Palette.metalDark, true, 1.4)

        // Inner triangular wheel cutout
        let innerPath = CGMutablePath()
        innerPath.move(to: P(-12, -4))
        innerPath.addLine(to: P(12, -4))
        innerPath.addLine(to: P(-2, -15))
        innerPath.closeSubpath()
        c.beginPath()
        c.addPath(innerPath)
        paint(c, Palette.c(0.18, 0.17, 0.18), false)

        // Internal Road Wheels & Sprockets
        // Rear drive sprocket (closest to wall)
        ellipse(c, -9, -8, 5.2, 5.2, Palette.metal, stroke: true, lw: 1.0)
        ellipse(c, -9, -8, 2.2, 2.2, Palette.metalDark, stroke: false)
        ellipse(c, -9, -8, 0.9, 0.9, Palette.chassisDark, stroke: false)

        // Front idler sprocket
        ellipse(c, 9, -8, 5.2, 5.2, Palette.metal, stroke: true, lw: 1.0)
        ellipse(c, 9, -8, 2.2, 2.2, Palette.metalDark, stroke: false)
        ellipse(c, 9, -8, 0.9, 0.9, Palette.chassisDark, stroke: false)

        // Top tensioner roller wheel
        ellipse(c, -2, -14, 3.2, 3.2, Palette.metal, stroke: true, lw: 0.9)
        ellipse(c, -2, -14, 1.2, 1.2, Palette.metalDark, stroke: false)

        // Center bottom road rollers
        for rx in [-3.0, 3.0] {
            ellipse(c, CGFloat(rx), -5.5, 2.4, 2.4, Palette.metal, stroke: true, lw: 0.8)
            ellipse(c, CGFloat(rx), -5.5, 0.8, 0.8, Palette.metalDark, stroke: false)
        }

        // Heavy triangular track suspension bracket connecting the hubs
        line(c, [P(-9, -8), P(9, -8)], 2.2, Palette.metalDark)
        line(c, [P(-9, -8), P(-2, -14)], 2.0, Palette.metalDark)
        line(c, [P(9, -8), P(-2, -14)], 2.0, Palette.metalDark)

        // Rotating Track Cleats (Tread pads rolling as he climbs)
        let cleatDir: CGFloat = goingDown ? -1 : 1
        for i in 0..<7 {
            let offset = CGFloat(i) * 4.6 - 13.0 + CGFloat(sin(Double(ph * 3.0 + CGFloat(i)))) * 1.5 * cleatDir
            line(c, [P(offset, -2.5), P(offset, -0.5)], 1.3, Palette.metal)
        }

        // 4. Side View of Cube Compactor Chassis
        let bodyRect = CGRect(x: -13, y: -46, width: 27, height: 28)
        rrect(c, bodyRect, 3.5, Palette.chassis, stroke: true, lw: 1.4)

        // Top lid lip rim
        rrect(c, CGRect(x: -14.5, y: -48.5, width: 30, height: 4.2), 1.6, Palette.metal, stroke: true, lw: 1.1)

        // Side Arm Rail Channel (Iconic WALL•E sliding track!)
        line(c, [P(-8, -26), P(8, -33)], 4.2, Palette.outline)
        line(c, [P(-8, -26), P(8, -33)], 2.6, Palette.metalDark)
        // Carriage slider block
        ellipse(c, 3, -31, 2.6, 2.6, Palette.metal, stroke: true, lw: 0.9)

        // Rust weathering patches
        ellipse(c, -10, -22, 3.2, 2.2, Palette.rust, stroke: false)
        ellipse(c, 11, -42, 2.8, 2.2, Palette.rust, stroke: false)

        // Side solar LED slit indicator
        rrect(c, CGRect(x: 10, y: -44, width: 2.4, height: 4.0), 0.8, Palette.meter, stroke: false)

        // Warning hazard stripes at lower-front edge
        line(c, [P(7, -23), P(11, -19)], 1.3, Palette.c(0.15, 0.15, 0.15, 0.65))
        line(c, [P(10, -23), P(14, -19)], 1.3, Palette.c(0.15, 0.15, 0.15, 0.65))

        // Rivet dots on corners
        for pt in [P(-11, -44), P(-11, -20), P(12, -20)] {
            ellipse(c, pt.x, pt.y, 0.9, 0.9, Palette.metalDark, stroke: false)
        }

        // 5. Articulated Hydraulic Neck (Side Profile)
        let neckBase = P(-5, -46)
        let neckPivot = P(-2, -58)
        let headMount = P(4, -66)

        // Lower piston strut
        line(c, [neckBase, neckPivot], 6.5, Palette.outline)
        line(c, [neckBase, neckPivot], 4.0, Palette.metalDark)
        line(c, [neckBase, neckPivot], 2.2, Palette.metal)

        // Knuckle elbow pivot
        ellipse(c, neckPivot.x, neckPivot.y, 2.8, 2.8, Palette.metalDark, stroke: true, lw: 1.0)

        // Upper hydraulic piston rod
        line(c, [neckPivot, headMount], 5.5, Palette.outline)
        line(c, [neckPivot, headMount], 3.2, Palette.metal)

        // 6. Binocular Visor Camera Eye (Side Profile looking up along wall)
        let lookAngle: CGFloat = goingDown ? 0.22 : -0.28

        // Far eye peeking slightly behind in depth
        c.saveGState()
        c.translateBy(x: headMount.x - 2.0, y: headMount.y - 3.5)
        c.rotate(by: lookAngle + p.lookY * 0.12)
        let farEye = CGMutablePath()
        farEye.move(to: P(-6, -6))
        farEye.addLine(to: P(6, -6))
        farEye.addQuadCurve(to: P(8.5, 4), control: P(9.5, -1))
        farEye.addLine(to: P(-4, 4))
        farEye.closeSubpath()
        c.beginPath(); c.addPath(farEye)
        paint(c, Palette.c(0.42, 0.40, 0.38), true, 1.1)
        ellipse(c, 7.0, -1.0, 1.8, 4.2, Palette.metalDark, stroke: false)
        c.restoreGState()

        // Near eye (main unit in foreground)
        c.saveGState()
        c.translateBy(x: headMount.x, y: headMount.y)
        c.rotate(by: lookAngle + p.lookY * 0.12)

        // Eye Teardrop Camera Housing Profile
        let eyeHousing = CGMutablePath()
        eyeHousing.move(to: P(-7, -7))
        eyeHousing.addLine(to: P(7, -7))
        eyeHousing.addQuadCurve(to: P(9.5, 5), control: P(10.5, -1))
        eyeHousing.addLine(to: P(-5, 5))
        eyeHousing.addQuadCurve(to: P(-7, -7), control: P(-8.5, -1))
        eyeHousing.closeSubpath()

        c.beginPath(); c.addPath(eyeHousing)
        paint(c, Palette.metal, true, 1.3)

        // Top brow shield plate
        let browPath = CGMutablePath()
        browPath.move(to: P(-7.5, -8))
        browPath.addLine(to: P(8.0, -8))
        browPath.addLine(to: P(7.0, -5.5))
        browPath.addLine(to: P(-6.5, -5.5))
        browPath.closeSubpath()
        c.beginPath(); c.addPath(browPath)
        paint(c, Palette.chassisDark, true, 1.0)

        // Rear camera adjustment focus knob
        ellipse(c, -7.5, -1.0, 1.8, 3.2, Palette.metalDark, stroke: true, lw: 0.8)

        // Front Optical Glass Lens (Oval in side profile)
        let lx: CGFloat = 8.0, ly: CGFloat = -1.0
        // Black lens rim
        ellipse(c, lx, ly, 2.4, 5.8, Palette.black, stroke: true, lw: 1.1)
        // Deep glass optic
        ellipse(c, lx, ly, 1.8, 5.0, Palette.glass, stroke: false)
        // Luminous camera aperture glowing blue
        ellipse(c, lx, ly, 1.3, 3.8, Palette.eyeLens, stroke: false)
        ellipse(c, lx + 0.2, ly, 0.8, 2.4, Palette.eyeGlow, stroke: false)
        // Pupil center
        ellipse(c, lx + 0.3, ly, 0.5, 1.2, Palette.black, stroke: false)
        // Specular curved glint highlight
        line(c, [P(lx - 0.5, ly - 3.2), P(lx - 0.5, ly - 0.5)], 1.2, Palette.glassReflect)

        c.restoreGState()

        // 7. Foreground Near Arm (Pulling down against the wall)
        let nearPhase = ph + .pi
        let handNearY = -40.0 - sin(Double(nearPhase)) * 14.0
        let handNear = P(-19, CGFloat(handNearY))
        let shNear = P(3, -31)

        let midNear = P((shNear.x + handNear.x) * 0.5, (shNear.y + handNear.y) * 0.5 + 2)
        line(c, [shNear, midNear], 5.2, Palette.outline)
        line(c, [shNear, midNear], 3.4, Palette.metal)
        line(c, [midNear, handNear], 4.4, Palette.outline)
        line(c, [midNear, handNear], 2.8, Palette.metal)
        // Gripper holding wall
        drawGripper(c, at: handNear, side: -1, angle: 1.2)
    }

    // MARK: Ropeway Zipline Traverse

    static func drawRopeway(_ c: CGContext, _ p: Pose) {
        // 1. Overhead Zipline Cable stretching across the window
        line(c, [P(-105, -82), P(105, -82)], 3.4, Palette.metalDark)
        line(c, [P(-105, -82.6), P(105, -82.6)], 1.3, Palette.c(0.72, 0.78, 0.88))
        // Cable twist spiral marks
        for x in stride(from: -95.0, through: 95.0, by: 16.0) {
            line(c, [P(CGFloat(x), -83.5), P(CGFloat(x + 5), -80.5)], 0.9, Palette.c(0.2, 0.22, 0.26))
        }

        // 2. Dual-Pulley Zipline Trolley Carriage
        // Left grooved pulley wheel rolling on cable
        ellipse(c, -8.5, -86, 4.4, 4.4, Palette.metal, stroke: true, lw: 1.1)
        ellipse(c, -8.5, -86, 1.8, 1.8, Palette.metalDark, stroke: false)
        // Right grooved pulley wheel rolling on cable
        ellipse(c, 8.5, -86, 4.4, 4.4, Palette.metal, stroke: true, lw: 1.1)
        ellipse(c, 8.5, -86, 1.8, 1.8, Palette.metalDark, stroke: false)

        // Steel hanger frame bracket dropping to grab rings
        let hangerPath = CGMutablePath()
        hangerPath.move(to: P(-11, -85))
        hangerPath.addLine(to: P(11, -85))
        hangerPath.addLine(to: P(9.5, -73))
        hangerPath.addLine(to: P(-9.5, -73))
        hangerPath.closeSubpath()
        c.beginPath(); c.addPath(hangerPath)
        paint(c, Palette.metalDark, true, 1.2)

        // Pulley axle bridge bar
        rrect(c, CGRect(x: -11, y: -87, width: 22, height: 3.5), 1.2, Palette.metal, stroke: true, lw: 0.9)

        // Suspension grab carabiner rings
        ellipse(c, -7.5, -70, 3.2, 3.2, Palette.metal, stroke: true, lw: 1.2)
        ellipse(c, -7.5, -70, 1.5, 1.5, Palette.metalDark, stroke: false)
        ellipse(c, 7.5, -70, 3.2, 3.2, Palette.metal, stroke: true, lw: 1.2)
        ellipse(c, 7.5, -70, 1.5, 1.5, Palette.metalDark, stroke: false)

        // 3. Suspended WALL•E Body (with dynamic zipline pendulum sway)
        c.saveGState()
        let sway = sin(Double(p.walkPhase * 1.5)) * 0.08 + Double(p.tilt)
        c.translateBy(x: 0, y: -70)
        c.rotate(by: CGFloat(sway))
        c.translateBy(x: 0, y: 70)

        // Arms reaching straight up to the grab rings
        let ringL = P(-7.5, -70)
        let ringR = P(7.5, -70)
        let shL = P(-18, -32)
        let shR = P(18, -32)

        for (sh, ring, s) in [(shL, ringL, -1.0), (shR, ringR, 1.0)] {
            ellipse(c, sh.x, sh.y, 2.8, 2.8, Palette.metalDark, stroke: true, lw: 1.0)
            let mid = P((sh.x + ring.x) * 0.5 + CGFloat(s) * 2, (sh.y + ring.y) * 0.5)
            line(c, [sh, mid], 5.0, Palette.outline)
            line(c, [sh, mid], 3.2, Palette.metal)
            line(c, [mid, ring], 4.2, Palette.outline)
            line(c, [mid, ring], 2.6, Palette.metal)
            // Grippers locked onto the rings
            drawGripper(c, at: ring, side: CGFloat(s), angle: 2.6)
        }

        // Dangling Tank Treads below the body (swinging playfully)
        c.saveGState()
        let treadSway = CGFloat(sin(Double(p.walkPhase * 1.5 - 0.4))) * 0.1
        c.translateBy(x: 0, y: -16)
        c.rotate(by: treadSway)
        c.translateBy(x: 0, y: 16)
        var treadPose = p
        treadPose.legs = .dangle
        drawTreads(c, treadPose)
        c.restoreGState()

        // Main compactor cube chassis
        drawChassis(c, p)

        // Articulated neck & binocular eyes looking forward with joy
        var headPose = p
        headPose.eyes = .happy
        headPose.mouth = .grin
        drawNeckAndEyes(c, headPose)

        c.restoreGState()

        // 4. Wind speed streaks trailing behind
        line(c, [P(-16, -72), P(-38, -72)], 1.5, Palette.c(1, 1, 1, 0.45))
        line(c, [P(-20, -42), P(-46, -42)], 1.5, Palette.c(1, 1, 1, 0.35))
        line(c, [P(-15, -15), P(-32, -15)], 1.2, Palette.c(1, 1, 1, 0.3))
    }

    // MARK: Held Items

    static func drawHeld(_ c: CGContext, _ p: Pose) {
        switch p.held {
        case .none:
            break
        case .candy(let amt):
            let h = handPoint(side: 1, angle: p.armR)
            let top = P(h.x + 10, h.y - 12)
            line(c, [h, top], 2.4, Palette.stick)
            guard amt > 0.05 else { return }
            ellipse(c, top.x + 2, top.y - 5, 8.0, 8.0, Palette.candy, stroke: true, lw: 1.3)
            ellipse(c, top.x + 0.5, top.y - 7.0, 2.5, 2.5, Palette.white, stroke: false)
        case .book:
            // Holding open manual / book with both grippers
            rrect(c, CGRect(x: -16, y: -38, width: 32, height: 18), 2.2, Palette.book, lw: 1.2)
            line(c, [P(0, -38), P(0, -20)], 1.3, Palette.outline)
            rrect(c, CGRect(x: -13, y: -35, width: 9, height: 3.0), 1, Palette.white, stroke: false)
            rrect(c, CGRect(x: 4, y: -35, width: 9, height: 3.0), 1, Palette.white, stroke: false)
            drawGripper(c, at: P(-15, -28), side: -1, angle: 0.2)
            drawGripper(c, at: P(15, -28), side: 1, angle: 0.2)
        }
    }

    // MARK: Hand Positioning Helper

    static func handPoint(side s: CGFloat, angle a: CGFloat) -> CGPoint {
        let sh = P(s * 18.0, -30)
        if a > 1.2 {
            // Waving / raised hand in air
            let dir = P(s * sin(a), cos(a))
            return P(sh.x + dir.x * 16, sh.y + dir.y * 16)
        } else if a < -0.3 {
            // Holding item close
            return P(s * 15, -28)
        } else {
            // Normal resting / working arm
            let dir = P(s * sin(a) * 0.8, cos(a))
            return P(sh.x + dir.x * 14, sh.y + dir.y * 14)
        }
    }

    // MARK: Menu Bar Icon Portrait

    static func drawPortrait(_ c: CGContext) {
        c.setLineJoin(.round)
        c.setLineCap(.round)
        c.saveGState()
        // Center the binocular eyes perfectly in menu bar icon
        c.translateBy(x: 0, y: -58)
        drawBinocularEyes(c, p: Pose(), compacted: false)
        c.restoreGState()
    }
}
