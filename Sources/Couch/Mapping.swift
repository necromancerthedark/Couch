// Mapping.swift — the FIXED input→action preset (see ADR-004, ADR-010,
// ADR-011, ADR-012). Single source of truth for what each pad input does.

import GameController

// Logical pad inputs we map (subset of GCExtendedGamepad).
enum InputID: Hashable, CaseIterable {
    case a, b, x, y, menu
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case leftShoulder, rightShoulder
}

// Semantic actions the output layer realizes as events.
enum MediaAction: CustomStringConvertible, CaseIterable {
    case playPause
    case seekBack, seekForward
    case playerVolUp, playerVolDown     // arrow keys, driven by the left stick
    case systemVolUp, systemVolDown     // macOS volume, driven by the D-pad
    case next, prev
    case mute
    case fullscreen
    case brightnessUp, brightnessDown

    var description: String {
        switch self {
        case .playPause: return "playPause"
        case .seekBack: return "seekBack"
        case .seekForward: return "seekForward"
        case .playerVolUp: return "playerVolUp"
        case .playerVolDown: return "playerVolDown"
        case .systemVolUp: return "systemVolUp"
        case .systemVolDown: return "systemVolDown"
        case .next: return "next"
        case .prev: return "prev"
        case .mute: return "mute"
        case .fullscreen: return "fullscreen"
        case .brightnessUp: return "brightnessUp"
        case .brightnessDown: return "brightnessDown"
        }
    }
}

extension MediaAction {
    /// Human-readable name, shown in the Settings window.
    var title: String {
        switch self {
        case .playPause: return "Play / pause"
        case .seekBack: return "Seek back"
        case .seekForward: return "Seek forward"
        case .playerVolUp: return "Player volume +"
        case .playerVolDown: return "Player volume −"
        case .systemVolUp: return "System volume +"
        case .systemVolDown: return "System volume −"
        case .next: return "Next"
        case .prev: return "Previous"
        case .mute: return "Mute"
        case .fullscreen: return "Fullscreen"
        case .brightnessUp: return "Brightness +"
        case .brightnessDown: return "Brightness −"
        }
    }
}

enum Mapping {

    /// What a logical input does, from the preset. Drives the controller map.
    static func function(for id: InputID) -> String? {
        edgeTable.first { $0.0 == id }?.1.title
    }

    // Button / D-pad / shoulder: fire once on press (rising edge).
    static let edgeTable: [(InputID, MediaAction)] = [
        (.a, .playPause),
        (.dpadLeft, .seekBack),
        (.dpadRight, .seekForward),
        (.dpadUp, .systemVolUp),          // ADR-019
        (.dpadDown, .systemVolDown),      // ADR-019
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

    // Left stick Y = player volume (ADR-019). Same ramp idea as the triggers.
    static let stickDeadzone: Float = 0.30
    static let volumeSlowInterval: TimeInterval = 0.30  // just past the deadzone
    static let volumeFastInterval: TimeInterval = 0.08  // full push

}
