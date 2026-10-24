// OutputLayer.swift — realizes MediaActions as synthetic keyboard / media-key
// events via CGEvent (see ADR-009). Requires Accessibility permission.

import AppKit
import CoreGraphics
import Foundation

final class OutputLayer {

    // NX_KEYTYPE_* values for system-defined media key events (ADR-015).
    private enum NXKey: Int {
        case soundUp = 0
        case soundDown = 1
        case mute = 7
        case brightnessUp = 2
        case brightnessDown = 3
        case play = 16
        case next = 17
        case previous = 18
    }

    // Regular keyboard codes (arrows) for seek / volume.
    private enum Key: UInt16 {
        case left  = 0x7B
        case right = 0x7C
        case up    = 0x7E
        case down  = 0x7D
        case f     = 0x03   // fullscreen in IINA and YouTube
    }

    func perform(_ action: MediaAction) {
        DebugLog.log("perform: \(action)")
        switch action {
        case .playPause:       postSystemKey(.play)
        case .next:            postSystemKey(.next)
        case .prev:            postSystemKey(.previous)
        case .mute:            postSystemKey(.mute)
        case .brightnessUp:    postSystemKey(.brightnessUp)
        case .brightnessDown:  postSystemKey(.brightnessDown)
        case .fullscreen:      postKey(.f)
        case .playerVolUp:     postKey(.up)
        case .playerVolDown:   postKey(.down)
        case .systemVolUp:     postSystemKey(.soundUp)
        case .systemVolDown:   postSystemKey(.soundDown)
        case .seekBack:        postKey(.left)
        case .seekForward:     postKey(.right)
        }
    }

    // Real HID media key: system-defined event (subtype 8), keyType in data1.
    private func postSystemKey(_ key: NXKey) {
        let keyType = key.rawValue
        for down in [true, false] {
            let flags = down ? 0xA00 : 0xB00
            let ev = NSEvent.otherEvent(
                with: .systemDefined, location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                timestamp: 0, windowNumber: 0, context: nil,
                subtype: 8, data1: (keyType << 16) | flags, data2: -1)
            ev?.cgEvent?.post(tap: .cghidEventTap)
        }
        DebugLog.log("post: systemKey=\(keyType) (NX media key)")
    }

    // Regular keys use the combined session state source.
    private func postKey(_ key: Key) {
        let src = CGEventSource(stateID: .combinedSessionState)
        post(code: key.rawValue, source: src)
    }

    private func post(code: UInt16, source: CGEventSource?) {
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        let up   = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        down?.post(tap: CGEventTapLocation.cghidEventTap)
        up?.post(tap: CGEventTapLocation.cghidEventTap)
        DebugLog.log("post: code=0x\(String(code, radix: 16, uppercase: true)) src=\(source != nil) eventCreated=\(down != nil)")
    }
}