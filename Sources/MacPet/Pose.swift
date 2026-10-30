import CoreGraphics

enum EyeStyle {
    case open, closed, happy, surprised, angry, dizzy
}

enum MouthStyle {
    case smile, open, grin, munch, flat, wavy
}

enum LegStyle {
    case stand, sit, dangle
}

enum HeldItem {
    case none
    case candy(CGFloat)
    case book
}

struct Pose {
    var facing: CGFloat = 1
    var scale: CGFloat = 1
    var bob: CGFloat = 0
    var squash: CGFloat = 1
    var tilt: CGFloat = 0
    var headTilt: CGFloat = 0
    var walkPhase: CGFloat = 0
    var walkAmount: CGFloat = 0
    var armL: CGFloat = 0
    var armR: CGFloat = 0
    var eyes: EyeStyle = .open
    var mouth: MouthStyle = .smile
    var munchPhase: CGFloat = 0
    var lookX: CGFloat = 0
    var lookY: CGFloat = 0
    var blush: Bool = false
    var sweat: Bool = false
    var legs: LegStyle = .stand
    var held: HeldItem = .none
    var post: Bool = false
    var tailWag: CGFloat = 0

    // Climbing & Ropeway
    var isClimbing: Bool = false
    var isRopeway: Bool = false
    var climbPhase: CGFloat = 0
    var climbGoingDown: Bool = false
}

