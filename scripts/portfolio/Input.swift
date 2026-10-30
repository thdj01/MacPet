import AppKit
import CoreGraphics

let args = CommandLine.arguments
func move(_ x: Double, _ y: Double) {
    let target = CGPoint(x: x, y: y)
    let start = CGEvent(source: nil)!.location
    for i in 1...30 {
        let t = Double(i) / 30
        let ease = t * t * (3 - 2 * t)
        let p = CGPoint(x: start.x + (x - start.x) * ease, y: start.y + (y - start.y) * ease)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)!.post(tap: .cghidEventTap)
        usleep(12_000)
    }
    CGWarpMouseCursorPosition(target)
}
func key(_ code: CGKeyCode, flags: CGEventFlags = []) {
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        e.flags = flags
        e.post(tap: .cghidEventTap)
        usleep(35_000)
    }
}
switch args[1] {
case "move": move(Double(args[2])!, Double(args[3])!)
case "click", "right":
    move(Double(args[2])!, Double(args[3])!)
    usleep(180_000)
    let right = args[1] == "right"
    for type in right ? [CGEventType.rightMouseDown, .rightMouseUp] : [.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: CGPoint(x: Double(args[2])!, y: Double(args[3])!), mouseButton: right ? .right : .left)!.post(tap: .cghidEventTap)
        usleep(70_000)
    }
case "chat": key(8, flags: [.maskControl, .maskAlternate])
case "escape": key(53)
case "enter": key(36)
case "type":
    let codes: [Character: CGKeyCode] = ["a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"o":31,"u":32,"i":34,"p":35,"l":37,"j":38,"k":40,"n":45,"m":46," ":49]
    for c in args[2] {
        if let code = codes[Character(String(c).lowercased())] {
            key(code, flags: c.isUppercase ? [.maskShift] : [])
            usleep(35_000)
            continue
        }
        var units = Array(String(c).utf16)
        let e = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        e.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!
        up.post(tap: .cghidEventTap)
        usleep(75_000)
    }
default: break
}
