import AppKit

enum PetState {
    case idle, walk, run, sit, sleep, air, grabbed, dance, petted, eat, hide, read, dizzy, wave, surprise, climb, ropeway
}

struct PetInput {
    var cursor: CGPoint
    var cursorSpeed: CGFloat
    var overPet: Bool
    var keyIdle: Double
    var anyIdle: Double
}

struct Particle {
    var x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat
    var life: Double, maxLife: Double
    var glyph: String
    var color: NSColor
    var size: CGFloat
}

enum Lines {
    static let click = ["Mrrp?", "Hi there!", "Hehe, that tickles!", "Need something?", "Meow!", "Boop!"]
    static let compliment = ["Aww, you think so? ♪", "Hehe, stop it~ ♪", "You're pretty great too! ♪"]
    static let petted = ["Purrrr... ♥", "Mmm, right there~", "Hehe ♥"]
    static let grabbed = ["Whoa! Put me down!", "Hey! I'm not luggage!", "Where are we going?!"]
    static let hide = ["Eek!", "(you can't see me...)", "W-who's there?!"]
    static let dizzy = ["Ow ow ow...", "Everything's spinning...", "Oof."]
    static let hungry = ["I'm a little hungry... treat?", "My tummy's rumbling..."]
    static let eat = ["Ooh, a treat!", "Mmm~ yummy!"]
    static let read = ["Reading along with you 📖"]
    static let wake = ["Huh?! I wasn't sleeping!", "Five more minutes..."]
}

/// The pet's body: state machine, physics and reactions.
@MainActor
final class Pet {
    let world: World
    let stats: Stats
    let settings: Settings

    var pos = CGPoint.zero              // feet, global Cocoa coordinates
    var vel = CGVector.zero
    var facing: CGFloat = 1
    private(set) var state: PetState = .air
    private var stateTime = 0.0
    private var stateDuration = 0.0
    private var time = 0.0

    private var walkDir: CGFloat = 1
    private var walkPhase: CGFloat = 0
    private var walkMayFall = false
    private var platformID: CGWindowID?
    private var platformFrameX: CGFloat?
    private var jumpIntent = false
    private let gravity: CGFloat = 2200

    private var climbSide: CGFloat = -1
    private var climbPhase: CGFloat = 0
    private var climbGoingDown = false
    private var ropeDir: CGFloat = 1

    private var blinkTimer = 3.0
    private var blinking = 0.0
    private var lookX: CGFloat = 0
    private var lookY: CGFloat = 0
    private(set) var scale: CGFloat = 1
    private var rumbleTime = 0.0
    private var landingSquash: CGFloat = 0

    private(set) var bubbleText: String?
    private var bubbleTime = 0.0
    private(set) var particles: [Particle] = []
    private var spawnTimer = 0.0
    private var lastDT = 1.0 / 60

    private var petAccum: CGFloat = 0
    private var lastCursor = CGPoint.zero
    private var hideCooldown = 0.0
    private var typingTime = 0.0
    private var activeTime = 0.0
    private var checkTimer = 0.0
    private var lastHungerNag = -1000.0
    private var lastLonelyNag = -1000.0
    private var lastNightNag = -2400.0
    private var lastBatteryCheck = -1000.0
    private var batteryWarned = false
    private var firstLanding = true
    private var pendingAction: (() -> Void)?
    private var refreshTimer = 0.0

    /// True while the chat window is open: the pet stays put and pays attention.
    var attentive = false
    private var mood = "neutral"
    private var moodTime = 0.0
    private var thinkingTime = 0.0
    private var showingDots = false
    private var lastAnyIdle = 0.0
    private var talkingTime = 0.0
    private(set) var standingOnApp: String?

    private(set) var isMouseDown = false
    private var dragging = false
    private var downPoint = CGPoint.zero
    private var grabOffset = CGVector.zero
    private var dragSamples: [(Double, CGPoint)] = []

    init(world: World, stats: Stats, settings: Settings) {
        self.world = world
        self.stats = stats
        self.settings = settings
        scale = CGFloat(settings.size)
    }

    var isGrounded: Bool { state != .air && state != .grabbed && state != .climb && state != .ropeway }
    var isFast: Bool { state == .air || state == .grabbed || state == .climb || state == .ropeway }
    var isCalm: Bool { (state == .idle || state == .sleep || state == .sit || state == .read) && landingSquash == 0 }
    var stateName: String {
        switch state {
        case .idle, .wave, .surprise: return "Hanging out"
        case .walk: return "Wandering"
        case .run: return "Running to you"
        case .sit: return "Sitting"
        case .sleep: return "Sleeping"
        case .air: return "Flying!"
        case .grabbed: return "Being carried"
        case .dance: return "Dancing"
        case .petted: return "Being petted"
        case .eat: return "Eating a treat"
        case .hide: return "Hiding (badly)"
        case .read: return "Reading along"
        case .dizzy: return "Dizzy"
        case .climb: return climbGoingDown ? "Climbing down" : "Climbing the wall"
        case .ropeway: return "Ziplining across!"
        }
    }

    // MARK: - Public actions

    func dropFromTop() {
        pos = world.startPoint
        vel = .zero
        platformID = nil
        jumpIntent = false
        enter(.air)
    }

    func say(_ text: String, _ duration: Double = 4) {
        bubbleText = text
        bubbleTime = duration
        showingDots = false
    }


    func startThinking() { thinkingTime = 60 }

    /// Keeps the mouth moving while a reply streams in.
    func talk() {
        talkingTime = 0.35
        if thinkingTime > 0 { stopThinking() }
    }

    func stopThinking() {
        thinkingTime = 0
        if showingDots { bubbleText = nil; showingDots = false }
    }

    /// Applies an AI reply: speech, facial mood, and an optional body action.
    func react(say text: String, mood m: String, action: String) {
        thinkingTime = 0
        say(text, min(10, 2.5 + Double(text.count) * 0.065))
        mood = m
        moodTime = 5
        if m == "happy" || m == "excited" || m == "proud" { stats.cheer(1) }
        guard isGrounded, state != .eat, state != .grabbed else { return }
        switch action {
        case "dance": enter(.dance, 4)
        case "wave": enter(.wave, 1.8)
        case "jump":
            vel = CGVector(dx: 0, dy: 560)
            platformID = nil
            jumpIntent = true
            enter(.air)
        case "hide": enter(.hide, 3)
        case "sit": enter(.sit, 8)
        case "sleep": goToSleep(announce: false)
        case "run_to_cursor": if !attentive { enter(.run, 6) }
        default:
            if state == .sleep { enter(.idle, 2) }
        }
    }

    /// Wakes the pet up and has it face the user for a chat.
    func payAttention() {
        attentive = true
        if state == .sleep || state == .walk || state == .run || state == .read { enter(.idle, 3) }
    }

    func feed() {
        perform { [self] in
            enter(.eat, 5)
            stats.feed()
            say(Lines.eat.randomElement()!)
        }
    }

    func superSize() {
        rumbleTime = 15
        say("Super size! ✨", 2.5)
        for _ in 0..<10 { spawn("✦", .systemYellow, size: 18) }
    }

    func dance() {
        perform { [self] in
            enter(.dance, 4.5)
            stats.cheer(5)
            say(Lines.compliment.randomElement()!)
        }
    }

    func toggleSleep() {
        if state == .sleep {
            enter(.surprise, 1.2)
            say(Lines.wake.randomElement()!)
        } else {
            perform { [self] in goToSleep() }
        }
    }

    func comeHere() { perform { [self] in enter(.run, 8) } }

    private func perform(_ f: @escaping () -> Void) {
        if isGrounded { f() } else { pendingAction = f }
    }

    // MARK: - Mouse

    func mouseDown(at p: CGPoint) {
        isMouseDown = true
        dragging = false
        downPoint = p
        grabOffset = CGVector(dx: pos.x - p.x, dy: pos.y - p.y)
    }

    func mouseDragged(at p: CGPoint) {
        guard isMouseDown else { return }
        if !dragging && hypot(p.x - downPoint.x, p.y - downPoint.y) > 4 {
            dragging = true
            platformID = nil
            dragSamples = []
            enter(.grabbed)
            say(Lines.grabbed.randomElement()!, 2.5)
        }
    }

    func mouseUp(at p: CGPoint, clickCount: Int) {
        guard isMouseDown else { return }
        isMouseDown = false
        if dragging {
            dragging = false
            var v = CGVector.zero
            if let first = dragSamples.first, let last = dragSamples.last, last.0 - first.0 > 0.01 {
                let dt = CGFloat(last.0 - first.0)
                v = CGVector(dx: (last.1.x - first.1.x) / dt, dy: (last.1.y - first.1.y) / dt)
                let m = hypot(v.dx, v.dy)
                if m > 2600 { v.dx *= 2600 / m; v.dy *= 2600 / m }
            }
            vel = v
            jumpIntent = false
            enter(.air)
        } else {
            clicked(count: clickCount)
        }
    }

    private func clicked(count: Int) {
        if PortfolioCapture.active, isGrounded {
            enter(.wave, 3.5)
            say("Hi there!", 3.5)
            return
        }
        stats.cheer(2)
        if state == .climb || state == .ropeway {
            vel = CGVector(dx: facing * -40, dy: -60)
            say("Whoaaa! 💨", 1.8)
            startFalling(keepVelocity: true)
            return
        }
        if state == .sleep {
            enter(.surprise, 1.2)
            say(Lines.wake.randomElement()!)
            return
        }
        guard isGrounded, state != .eat else { return }
        if count >= 2 {
            enter(.dance, 4.5)
            say(Lines.compliment.randomElement()!)
            return
        }
        switch Int.random(in: 0..<4) {
        case 0:
            vel = CGVector(dx: 0, dy: 520)
            platformID = nil
            jumpIntent = true
            enter(.air)
            say("!", 1.2)
        case 1:
            enter(.surprise, 1.0)
            say(Lines.click.randomElement()!)
        default:
            enter(.wave, 1.6)
            say(Lines.click.randomElement()!)
        }
    }

    // MARK: - Loop

    private func enter(_ s: PetState, _ duration: Double = 0) {
        state = s
        stateTime = 0
        stateDuration = duration
    }

    func update(dt: Double, input: PetInput) {
        time += dt
        stateTime += dt
        lastDT = dt
        let fdt = CGFloat(dt)

        blinkTimer -= dt
        if blinkTimer <= 0 { blinking = 0.13; blinkTimer = .random(in: 2...5.5) }
        if blinking > 0 { blinking -= dt }

        stats.tick(dt, sleeping: state == .sleep, petted: state == .petted)

        let targetScale = CGFloat(settings.size) * (rumbleTime > 0 ? 1.6 : 1)
        scale += (targetScale - scale) * min(1, fdt * 5)
        if rumbleTime > 0 {
            rumbleTime -= dt
            if Int(time * 8) % 3 == 0 && Double.random(in: 0...1) < 0.3 { spawn("✦", .systemYellow, size: 14) }
            if rumbleTime <= 0 { say("Back to normal size!", 3) }
        }
        landingSquash = max(0, landingSquash - fdt * 1.2)
        hideCooldown -= dt
        if bubbleTime > 0 {
            bubbleTime -= dt
            if bubbleTime <= 0 { bubbleText = nil; showingDots = false }
        }
        if moodTime > 0 { moodTime -= dt }
        if talkingTime > 0 { talkingTime -= dt }
        if thinkingTime > 0 {
            thinkingTime -= dt
            if bubbleText == nil || showingDots {
                bubbleText = ["•", "• •", "• • •"][Int(time * 3) % 3]
                bubbleTime = 0.5
                showingDots = true
            }
            if thinkingTime <= 0 { stopThinking() }
        }
        updateParticles(dt)
        updateLook(input, fdt)

        if input.keyIdle < 2 { typingTime += dt } else if input.keyIdle > 20 { typingTime = 0 }

        refreshTimer -= dt
        if refreshTimer <= 0 {
            refreshTimer = platformID != nil ? 0.2 : 1.0
            world.refresh(enabled: settings.standOnWindows)
        }

        handleCursor(input, dt)
        if isGrounded { checkSupport() }

        switch state {
        case .idle, .sit, .wave, .surprise, .dizzy, .hide:
            if state == .idle || state == .sit {
                if settings.followCursor && abs(input.cursor.x - pos.x) > 260 && stateTime > 0.8 {
                    enter(.run, 6)
                    break
                }
                if state == .idle && abs(input.cursor.x - pos.x) > 40 && abs(lookX) > 0.7 && stateTime > 0.5 {
                    facing = input.cursor.x > pos.x ? 1 : -1
                }
            }
            if stateTime > stateDuration { decide() }

        case .walk, .run:
            var dir = walkDir
            if state == .run {
                let dx = input.cursor.x - pos.x
                if abs(dx) < 28 {
                    enter(.wave, 1.6)
                    if Bool.random() { say("Found you! Hehe") }
                    break
                }
                dir = dx > 0 ? 1 : -1
            }
            facing = dir
            let speed: CGFloat = state == .run ? 230 : (stats.happiness < 25 ? 45 : 75)
            walkPhase += fdt * (state == .run ? 16 : 9)
            let moved = groundMove(dir * speed * sqrt(scale) * fdt, allowFall: state == .run || walkMayFall)
            if state != .walk && state != .run { break }
            if !moved {
                if state == .run {
                    enter(.idle, 1)
                } else {
                    let (minX, maxX) = world.xBounds
                    let nearBorder = (pos.x <= minX + 35 && walkDir < 0) || (pos.x >= maxX - 35 && walkDir > 0)
                    if nearBorder && Double.random(in: 0...1) < 0.65 {
                        startClimbing(side: walkDir < 0 ? -1 : 1)
                    } else {
                        walkDir = -walkDir
                    }
                }
            }
            if stateTime > stateDuration { decide() }

        case .climb:
            updateClimb(fdt)

        case .ropeway:
            updateRopeway(fdt)

        case .sleep:
            every(1.3) { spawn("z", .labelColor.withAlphaComponent(0.7), at: CGPoint(x: 20 * scale * facing, y: -95 * scale), size: 15, vx: 14 * facing) }
            if petAccum > 200 { every(0.5) { spawn("♥", .systemPink, size: 12) } }
            if stats.energy >= 98 {
                enter(.wave, 1.6)
                say("Ahh~ fully rested!")
            }

        case .air:
            updateAir(fdt)

        case .grabbed:
            pos = CGPoint(x: input.cursor.x + grabOffset.dx, y: input.cursor.y + grabOffset.dy)
            dragSamples.append((time, pos))
            dragSamples.removeAll { time - $0.0 > 0.08 }
            walkPhase += fdt * 10

        case .dance:
            every(0.45) { spawn(["♪", "♫"].randomElement()!, .systemPurple, size: 17) }
            if stateTime > stateDuration { enter(.idle, 1) }

        case .petted:
            every(0.25) { spawn("♥", .systemPink, size: 15) }
            if stateTime > stateDuration { enter(.idle, 1.2) }

        case .eat:
            every(0.6) { spawn("·", .systemPink, at: CGPoint(x: 10 * scale * facing, y: -50 * scale), size: 18, up: false) }
            if stateTime > stateDuration {
                enter(.wave, 1.6)
                say("Ahh~ delicious! Thank you!")
            }

        case .read:
            if input.keyIdle > 45 || stateTime > stateDuration { decide() }
        }

        clampToScreens()

        checkTimer += dt
        if checkTimer >= 1 {
            checkTimer = 0
            periodicChecks(input)
        }
    }

    // MARK: - Decisions

    private func decide() {
        if PortfolioCapture.active { enter(.idle, 600); return }
        // Dev aid: PET_FORCE=walk, PET_FORCE=climb, or PET_FORCE=idle pins behavior.
        if let forced = ProcessInfo.processInfo.environment["PET_FORCE"] {
            if forced == "climb" {
                startClimbing()
                return
            }
            walkDir = -walkDir
            enter(forced == "walk" ? .walk : .idle, 5)
            return
        }
        if attentive {
            enter(Bool.random() ? .idle : .sit, 4)
            return
        }
        if stats.energy < 12 { goToSleep(); return }
        enum Action { case idle, walk, sit, jump, dance, chase, read, sleep, climb }
        var opts: [(Action, Double)] = [(.idle, 2), (.walk, 4), (.sit, 1.5)]
        let (minX, maxX) = world.xBounds
        let nearEdge = pos.x <= minX + 55 || pos.x >= maxX - 55
        if nearEdge { opts.append((.climb, 3.5)) }
        if settings.standOnWindows && jumpTarget() != nil { opts.append((.jump, 1.6)) }
        if stats.happiness > 65 { opts.append((.dance, 0.5)) }
        opts.append((.chase, settings.followCursor ? 3 : 0.5))
        if typingTime > 15 { opts.append((.read, 3)) }
        if stats.energy < 35 { opts.append((.sleep, 2)) }

        var r = Double.random(in: 0..<opts.reduce(0) { $0 + $1.1 })
        var choice = Action.idle
        for (a, w) in opts {
            if r < w { choice = a; break }
            r -= w
        }

        switch choice {
        case .idle: enter(.idle, .random(in: 1.5...4))
        case .walk:
            walkDir = Bool.random() ? 1 : -1
            walkMayFall = Double.random(in: 0...1) < 0.35
            enter(.walk, .random(in: 2...6))
        case .sit: enter(.sit, .random(in: 4...10))
        case .jump: if let t = jumpTarget() { jump(to: t.0, x: t.1) } else { enter(.idle, 2) }
        case .dance:
            enter(.dance, 4)
            if Bool.random() { say(Lines.compliment.randomElement()!) }
        case .chase: enter(.run, 6)
        case .read:
            enter(.read, .random(in: 15...30))
            if Double.random(in: 0...1) < 0.4 { say(Lines.read.randomElement()!) }
        case .sleep: goToSleep()
        case .climb: startClimbing()
        }
    }

    // MARK: - Climbing & Ropeway

    func startClimbing(side: CGFloat? = nil) {
        platformID = nil
        jumpIntent = false
        let (minX, maxX) = world.xBounds
        let s: CGFloat
        if let side = side {
            s = side
        } else {
            s = abs(pos.x - minX) < abs(pos.x - maxX) ? -1 : 1
        }
        climbSide = s
        climbGoingDown = false
        pos.x = s < 0 ? minX + 24 : maxX - 24
        facing = s < 0 ? 1 : -1
        climbPhase = 0
        enter(.climb)
        say(["Up we go! 🧗", "Wall-E climb!", "Screen climbing!"].randomElement()!, 2.2)
    }

    private func updateClimb(_ dt: CGFloat) {
        let (minX, maxX) = world.xBounds
        let wallX = climbSide < 0 ? minX + 24 : maxX - 24
        pos.x = wallX
        facing = climbSide < 0 ? 1 : -1

        let speed: CGFloat = 130 * sqrt(scale)
        climbPhase += dt * 10
        walkPhase = climbPhase

        if climbGoingDown {
            pos.y -= speed * dt
            let f = world.floor(atX: pos.x, y: pos.y)
            if pos.y <= f {
                pos.y = f
                land(impact: 300)
                say(["Made it down safely! ✨", "Tada! Down we go!"].randomElement()!, 2.5)
                return
            }
        } else {
            pos.y += speed * dt
            if Int(time * 8) % 3 == 0 && Double.random(in: 0...1) < 0.4 {
                spawn("·", .systemYellow, at: CGPoint(x: (climbSide < 0 ? -12 : 12) * scale, y: -15 * scale), size: 10, up: false)
            }
            let ceiling = world.ceiling(atX: pos.x, y: pos.y)
            let topLimit = ceiling - 55 * scale
            if pos.y >= topLimit {
                pos.y = topLimit
                startRopeway()
            }
        }
    }

    private func startRopeway() {
        ropeDir = climbSide < 0 ? 1 : -1
        facing = ropeDir
        enter(.ropeway)
        say(["Wheeeeee! 🚠", "Zipline time! ♪", "Waaall-Eeee!"].randomElement()!, 2.5)
        for _ in 0..<3 { spawn("✦", .systemYellow, size: 14) }
    }

    private func updateRopeway(_ dt: CGFloat) {
        let (minX, maxX) = world.xBounds
        facing = ropeDir
        let speed: CGFloat = 175 * sqrt(scale)
        pos.x += ropeDir * speed * dt
        walkPhase += dt * 8

        let screenW = max(100, maxX - minX)
        let t = max(0, min(1, (pos.x - minX) / screenW))
        let sag = sin(t * .pi) * (18 * scale)
        let ceiling = world.ceiling(atX: pos.x, y: pos.y)
        pos.y = ceiling - 55 * scale - sag

        if Int(time * 12) % 3 == 0 {
            spawn("―", .labelColor.withAlphaComponent(0.35),
                  at: CGPoint(x: -ropeDir * 20 * scale, y: -25 * scale),
                  size: 13, up: false, vx: -ropeDir * 120)
        }

        let reachedOpposite = (ropeDir > 0 && pos.x >= maxX - 28) || (ropeDir < 0 && pos.x <= minX + 28)
        if reachedOpposite {
            finishRopeway()
        }
    }

    private func finishRopeway() {
        let (minX, maxX) = world.xBounds
        let newSide: CGFloat = ropeDir > 0 ? 1 : -1
        climbSide = newSide
        climbGoingDown = true
        pos.x = newSide < 0 ? minX + 24 : maxX - 24
        facing = newSide < 0 ? 1 : -1
        enter(.climb)
        say(["Climbing down! 🪜", "Safe arrival!", "Down we go!"].randomElement()!, 2.0)
    }

    private func goToSleep(announce: Bool = true) {
        enter(.sleep)
        if announce { say("Yawn... nap time...") }
    }

    private func jumpTarget() -> (Platform, CGFloat)? {
        let cands = world.platforms.filter { p in
            let dy = p.y - pos.y
            guard dy > 40, dy < 380, p.maxX - p.minX > 60, p.id != platformID else { return false }
            let nearest = min(max(pos.x, p.minX + 20), p.maxX - 20)
            return abs(nearest - pos.x) < 350
        }
        guard let p = cands.randomElement() else { return nil }
        let x = min(max(pos.x + .random(in: -150...150), p.minX + 20), p.maxX - 20)
        return (p, x)
    }

    private func jump(to p: Platform, x tx: CGFloat) {
        let dy = p.y - pos.y
        let vy = sqrt(2 * gravity * (dy + 60))
        let t = (vy + sqrt(max(0, vy * vy - 2 * gravity * dy))) / gravity
        vel = CGVector(dx: (tx - pos.x) / t, dy: vy)
        facing = vel.dx >= 0 ? 1 : -1
        platformID = nil
        jumpIntent = true
        enter(.air)
        if Double.random(in: 0...1) < 0.3 { say("Hup!", 1.2) }
    }

    /// Deterministic staging for local portfolio captures; normal launches never use this.
    func portfolioAction(_ action: String) {
        guard PortfolioCapture.active else { return }
        switch action {
        case "reset":
            firstLanding = false
            pos = CGPoint(x: 690, y: world.floor(atX: 690, y: 100))
            platformID = nil
            vel = .zero
            bubbleText = nil
            facing = 1
            enter(.idle, 600)
        case "walk": walkDir = 1; enter(.walk, 2.2)
        case "jump":
            world.refresh(enabled: true)
            if let p = world.platforms.first(where: { $0.owner == "CaptureStage" }) {
                jump(to: p, x: min(max(pos.x + 80, p.minX + 40), p.maxX - 40))
            }
        case "sit": bubbleText = nil; enter(.sit, 600)
        case "wave": clicked(count: 1)
        case "dance": dance()
        case "sleep": bubbleText = nil; enter(.sleep)
        default: break
        }
    }

    // MARK: - Physics

    private func groundMove(_ dx: CGFloat, allowFall: Bool) -> Bool {
        let nx = pos.x + dx
        if let pid = platformID {
            guard let seg = world.segments(id: pid).first(where: { pos.x >= $0.minX - 2 && pos.x <= $0.maxX + 2 }) else {
                startFalling()
                return true
            }
            if nx < seg.minX || nx > seg.maxX {
                guard allowFall else { return false }
                pos.x = nx
                vel = CGVector(dx: dx / 0.016, dy: 0)
                startFalling(keepVelocity: true)
                return true
            }
        } else {
            if world.screen(atX: nx + (dx > 0 ? 22 : -22), y: pos.y + 5) == nil { return false }
        }
        pos.x = nx
        return true
    }

    private func checkSupport() {
        if let pid = platformID {
            let segs = world.segments(id: pid)
            guard let first = segs.first else { startFalling(); return }
            let dx = first.frameX - (platformFrameX ?? first.frameX)
            pos.x += dx
            platformFrameX = first.frameX
            if let seg = segs.first(where: { pos.x >= $0.minX - 2 && pos.x <= $0.maxX + 2 }) {
                pos.y = seg.y
            } else {
                startFalling()
            }
        } else {
            let f = world.floor(atX: pos.x, y: pos.y + 5)
            if pos.y > f + 2 { startFalling() } else { pos.y = f }
        }
    }

    private func startFalling(keepVelocity: Bool = false) {
        platformID = nil
        standingOnApp = nil
        jumpIntent = false
        if !keepVelocity { vel = .zero }
        enter(.air)
    }

    private func updateAir(_ dt: CGFloat) {
        vel.dy -= gravity * dt
        vel.dx *= (1 - 0.4 * dt)
        let prevY = pos.y
        pos.x += vel.dx * dt
        pos.y += vel.dy * dt

        let (minX, maxX) = world.xBounds
        if pos.x < minX + 25 { pos.x = minX + 25; vel.dx = abs(vel.dx) * 0.5 }
        if pos.x > maxX - 25 { pos.x = maxX - 25; vel.dx = -abs(vel.dx) * 0.5 }
        let top = world.ceiling(atX: pos.x, y: prevY)
        if vel.dy > 0 && pos.y + 115 * scale > top {
            pos.y = top - 115 * scale
            vel.dy = -vel.dy * 0.3
        }
        if abs(vel.dx) > 60 { facing = vel.dx > 0 ? 1 : -1 }

        if vel.dy <= 0, let hit = world.landing(x: pos.x, fromY: prevY, toY: pos.y) {
            pos.y = hit.y
            platformID = hit.platform?.id
            platformFrameX = hit.platform?.frameX
            land(impact: -vel.dy)
        }
    }

    private func land(impact: CGFloat) {
        vel = .zero
        landingSquash = min(0.25, impact / 5000)
        let wasJump = jumpIntent
        jumpIntent = false
        if let a = pendingAction {
            pendingAction = nil
            enter(.idle, 1)
            a()
            return
        }
        standingOnApp = platformID.flatMap { world.segments(id: $0).first?.owner }
        if impact > 1500 && !wasJump {
            enter(.dizzy, 1.8)
            say(Lines.dizzy.randomElement()!, 2.5)
            stats.cheer(-3)
        } else if firstLanding {
            firstLanding = false
            enter(.wave, 2.2)
            say("Hi! I'm \(settings.petName)! Press ⌃⌥C to chat with me.", 5)
        } else {
            enter(.idle, .random(in: 0.5...1.5))
        }
    }

    private func clampToScreens() {
        let (minX, maxX) = world.xBounds
        pos.x = min(max(pos.x, minX + 20), maxX - 20)
        let lowest = NSScreen.screens.map(\.visibleFrame.minY).min() ?? 0
        let highest = NSScreen.screens.map(\.frame.maxY).max() ?? 1000
        if pos.y < lowest - 50 || pos.y > highest + 400 { dropFromTop() }
    }

    // MARK: - Senses

    private func updateLook(_ input: PetInput, _ dt: CGFloat) {
        var tx: CGFloat = 0, ty: CGFloat = 0
        let dx = input.cursor.x - pos.x
        let dy = input.cursor.y - (pos.y + 70 * scale)
        if hypot(dx, dy) < 700 {
            tx = max(-1, min(1, dx / 160))
            ty = max(-1, min(1, -dy / 160))
        }
        lookX += (tx - lookX) * min(1, dt * 8)
        lookY += (ty - lookY) * min(1, dt * 8)
    }

    private func handleCursor(_ input: PetInput, _ dt: Double) {
        let moved = hypot(input.cursor.x - lastCursor.x, input.cursor.y - lastCursor.y)
        lastCursor = input.cursor
        if input.overPet && !isMouseDown { petAccum += min(moved, 60) }
        petAccum = max(0, petAccum - CGFloat(dt) * 120)

        if petAccum > 320 {
            switch state {
            case .idle, .walk, .run, .sit, .read, .wave:
                enter(.petted, 2.2)
                if Bool.random() { say(Lines.petted.randomElement()!) }
            case .petted:
                stateDuration = max(stateDuration, stateTime + 1.2)
            default:
                break
            }
        }

        let center = CGPoint(x: pos.x, y: pos.y + 55 * scale)
        if input.cursorSpeed > 3000, hideCooldown <= 0,
           hypot(input.cursor.x - center.x, input.cursor.y - center.y) < 150 * scale,
           state == .idle || state == .walk || state == .sit {
            hideCooldown = 45
            enter(.hide, 3)
            say(Lines.hide.randomElement()!, 2.5)
        }
    }

    private func periodicChecks(_ input: PetInput) {
        if input.anyIdle > 300 { activeTime = 0 } else { activeTime += 1 }

        if settings.reminders {
            if activeTime >= 50 * 60 {
                activeTime = 0
                say("You've been at it for 50 minutes. Time to stand up and stretch! 🙂")
                if isGrounded && state != .sleep { enter(.run, 5) }
            }
            let hour = Calendar.current.component(.hour, from: Date())
            if hour < 5 && input.anyIdle < 60 && time - lastNightNag > 45 * 60 {
                lastNightNag = time
                say("It's really late... maybe get some sleep? 🌙")
            }
            if time - lastBatteryCheck > 60 {
                lastBatteryCheck = time
                if let b = Sensors.battery() {
                    if !b.charging && b.percent <= 15 && !batteryWarned {
                        batteryWarned = true
                        say("Your Mac is at \(b.percent)%! Plug it in, quick! 🔌")
                        if state != .sleep && isGrounded { enter(.surprise, 1.5) }
                    } else if b.charging || b.percent > 20 {
                        batteryWarned = false
                    }
                }
            }
        }

        if stats.hunger < 25 && time - lastHungerNag > 180 && state != .sleep {
            lastHungerNag = time
            say(Lines.hungry.randomElement()!)
        }
        if stats.happiness < 25 && time - lastLonelyNag > 300 && state != .sleep {
            lastLonelyNag = time
            say("...nobody's playing with me.")
        }
        if lastAnyIdle > 600 && input.anyIdle < 5 && state != .air && state != .grabbed {
            if state == .sleep { enter(.idle, 2) }
            say("Welcome back! 👋")
        }
        lastAnyIdle = input.anyIdle
    }

    // MARK: - Particles

    private func every(_ interval: Double, _ f: () -> Void) {
        spawnTimer -= lastDT
        if spawnTimer <= 0 {
            spawnTimer = interval
            f()
        }
    }

    private func spawn(_ glyph: String, _ color: NSColor, at: CGPoint? = nil, size: CGFloat = 16,
                       up: Bool = true, vx: CGFloat? = nil) {
        let base = at ?? CGPoint(x: .random(in: -28...28) * scale, y: -105 * scale)
        particles.append(Particle(x: base.x, y: base.y,
                                  vx: vx ?? .random(in: -20...20),
                                  vy: up ? .random(in: -60 ... -35) : 40,
                                  life: 1.6, maxLife: 1.6, glyph: glyph, color: color, size: size))
    }

    private func updateParticles(_ dt: Double) {
        let f = CGFloat(dt)
        for i in particles.indices {
            particles[i].x += particles[i].vx * f
            particles[i].y += particles[i].vy * f
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    // MARK: - Pose

    private func applyMood(_ p: inout Pose, _ t: CGFloat) {
        switch mood {
        case "happy": p.eyes = .happy; p.mouth = .grin
        case "shy": p.eyes = .happy; p.blush = true; p.mouth = .wavy; p.headTilt = 0.12
        case "excited": p.mouth = .grin; p.bob += -abs(sin(t * 10)) * 4; p.armL = 2.2; p.armR = 2.2
        case "sad": p.eyes = .closed; p.mouth = .flat; p.headTilt = 0.18; p.armL = 0.1; p.armR = 0.1
        case "scared": p.eyes = .surprised; p.mouth = .wavy; p.sweat = true
        case "angry": p.eyes = .angry; p.mouth = .wavy; p.blush = true
        case "sleepy": p.eyes = .closed; p.mouth = .flat; p.headTilt = 0.1
        case "curious": p.mouth = .open; p.headTilt = -0.15; p.lookY = -0.4
        case "proud": p.eyes = .happy; p.mouth = .grin; p.tilt = -0.06; p.armL = 1.0; p.armR = 1.0
        default: break
        }
    }

    func pose() -> Pose {
        var p = Pose()
        let t = CGFloat(time)
        p.facing = facing
        p.scale = scale
        p.lookX = lookX * facing
        p.lookY = lookY
        p.squash = 1 + sin(t * 2.2) * 0.015 - landingSquash
        p.armL = 0.3 + sin(t * 2) * 0.05
        p.armR = p.armL

        switch state {
        case .idle:
            break
        case .wave:
            p.armR = 2.6 + sin(t * 14) * 0.35
            p.mouth = .grin
        case .surprise:
            p.eyes = .surprised
            p.mouth = .open
            p.armL = 1.4; p.armR = 1.4
            p.bob = -max(0, sin(CGFloat(stateTime) * 9)) * 4
        case .walk, .run:
            p.walkPhase = walkPhase
            p.walkAmount = 1
            p.bob = -abs(sin(walkPhase)) * 2.5
            p.armL = 0.3 + sin(walkPhase) * 0.45
            p.armR = 0.3 - sin(walkPhase) * 0.45
            if state == .run {
                p.mouth = .open
                p.tilt = 0.1
            }
        case .sit:
            p.legs = .sit
            p.armL = 0.15; p.armR = 0.15
        case .sleep:
            p.legs = .sit
            p.eyes = .closed
            p.mouth = .flat
            p.headTilt = 0.22 + sin(t * 1.2) * 0.04
            p.squash = 1 + sin(t * 1.4) * 0.03
            p.armL = 0.1; p.armR = 0.1
        case .air:
            p.legs = .dangle
            p.walkPhase = t * 8
            if jumpIntent {
                p.armL = 2.0; p.armR = 2.0
                p.mouth = .grin
            } else {
                p.armL = 2.3 + sin(t * 10) * 0.3
                p.armR = 2.3 - sin(t * 10) * 0.3
                p.eyes = vel.dy < -300 ? .surprised : .open
                p.mouth = .open
            }
        case .grabbed:
            p.legs = .dangle
            p.walkPhase = walkPhase
            p.armL = 2.5 + sin(t * 12) * 0.4
            p.armR = 2.5 - sin(t * 12) * 0.4
            p.eyes = .surprised
            p.mouth = .wavy
            p.sweat = true
            p.tilt = sin(t * 3) * 0.1
        case .dance:
            p.armL = 2.4 + sin(t * 8) * 0.5
            p.armR = 2.4 + sin(t * 8 + .pi) * 0.5
            p.tilt = sin(t * 8) * 0.15
            p.bob = -abs(sin(t * 8)) * 6
            p.walkPhase = t * 8
            p.walkAmount = 0.6
            p.eyes = .happy
            p.mouth = .grin
            p.blush = true
        case .petted:
            p.eyes = .happy
            p.mouth = .grin
            p.blush = true
            p.armL = 0.6 + sin(t * 6) * 0.2
            p.armR = 0.6 - sin(t * 6) * 0.2
            p.tilt = sin(t * 5) * 0.06
        case .eat:
            p.legs = .sit
            p.armR = 2.5
            p.armL = 0.3
            p.held = .candy(CGFloat(max(0, 1 - stateTime / max(stateDuration, 0.1))))
            p.mouth = .munch
            p.munchPhase = t * 10
            p.eyes = .happy
            p.blush = true
        case .hide:
            p.post = true
            p.lookX = -1
            p.lookY = 0
            p.sweat = true
            p.mouth = .wavy
            p.tilt = -0.12
            p.armL = 0.9; p.armR = 0.9
        case .read:
            p.legs = .sit
            p.held = .book
            p.armL = -0.5; p.armR = -0.5
            p.lookX = 0
            p.lookY = 1
        case .dizzy:
            p.eyes = .dizzy
            p.mouth = .wavy
            p.tilt = sin(t * 6) * 0.15
            p.headTilt = sin(t * 6) * 0.1
        case .climb:
            p.isClimbing = true
            p.climbPhase = climbPhase
            p.climbGoingDown = climbGoingDown
            p.eyes = .open
            p.mouth = .open
            p.tilt = 0
            p.bob = 0
        case .ropeway:
            p.isRopeway = true
            p.walkPhase = walkPhase
            p.eyes = .happy
            p.mouth = .grin
            p.tilt = sin(t * 7) * 0.08
            p.armL = 2.8
            p.armR = 2.8
        }

        if moodTime > 0, [.idle, .sit, .wave, .walk, .petted, .read, .surprise].contains(state) { applyMood(&p, t) }
        if talkingTime > 0 && state != .sleep && state != .eat { p.mouth = sin(t * 16) > 0 ? .open : .smile }
        p.tailWag = sin(t * (state == .dance || state == .petted ? 9 : 2.2)) * (state == .sleep ? 0.05 : 0.22)
        if blinking > 0 && p.eyes == .open { p.eyes = .closed }
        if rumbleTime > 0 && (p.mouth == .smile || p.mouth == .flat) { p.mouth = .grin }
        return p
    }
}
