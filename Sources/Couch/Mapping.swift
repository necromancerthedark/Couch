// Mapping.swift — the FIXED input→action preset (see ADR-004, ADR-010,
// ADR-011, ADR-012). Single source of truth for what each pad input does.

import GameController

// Logical pad inputs we map (subset of GCExtendedGamepad).
enum InputID: Hashable {
    case a, b, x, y, menu
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case leftShoulder, rightShoulder
}

// Semantic actions the output layer realizes as events.
enum MediaAction: CustomStringConvertible {
    case playPause
    case seekBack, seekForward
    case volUp, volDown
    case next, prev
    case mute
    case fullscreen
    case brightnessUp, brightnessDown

    var description: String {
        switch self {
        case .playPause: return "playPause"
        case .seekBack: return "seekBack"
        case .seekForward: return "seekForward"
        case .volUp: return "volUp"
        case .volDown: return "volDown"
        case .next: return "next"
        case .prev: return "prev"
        case .mute: return "mute"
        case .fullscreen: return "fullscreen"
        case .brightnessUp: return "brightnessUp"
        case .brightnessDown: return "brightnessDown"
        }
    }
}

enum Mapping {

    // Button / D-pad / shoulder: fire once on press (rising edge).
    static let edgeTable: [(InputID, MediaAction)] = [
        (.a, .playPause),
        (.dpadLeft, .seekBack),
        (.dpadRight, .seekForward),
        (.dpadUp, .volUp),
        (.dpadDown, .volDown),
        (.b, .next),
        (.x, .prev),
        (.menu, .mute),
        (.y, .fullscreen),                // ADR-018
        (.leftShoulder, .brightnessDown), // ADR-012
        (.rightShoulder, .brightnessUp)   // ADR-012
    ]

    // Read the current pressed state of a logical input from a gamepad.
    static func value(id: InputID, gp: GCExtendedGamepad) -> Bool {
        switch id {
        case .a:            return gp.buttonA.isPressed
        case .b:            return gp.buttonB.isPressed
        case .x:            return gp.buttonX.isPressed
        case .y:            return gp.buttonY.isPressed
        case .menu:         return gp.buttonMenu.isPressed
        case .dpadUp:       return gp.dpad.up.isPressed
        case .dpadDown:     return gp.dpad.down.isPressed
        case .dpadLeft:     return gp.dpad.left.isPressed
        case .dpadRight:    return gp.dpad.right.isPressed
        case .leftShoulder: return gp.leftShoulder.isPressed
        case .rightShoulder:return gp.rightShoulder.isPressed
        }
    }

    // Triggers: analog hold-to-seek (ADR-011). LT=seek back, RT=seek forward.
    // Deeper press = faster scrub. Below the threshold, treated as released.
    static let triggerThreshold: Float = 0.15
    static let seekSlowInterval: TimeInterval = 0.50  // just above threshold
    static let seekFastInterval: TimeInterval = 0.08  // full press

}
