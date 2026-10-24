// OutputLayer.swift — realizes MediaActions as synthetic keyboard / media-key
// events via CGEvent (see ADR-009). Requires Accessibility permission.

import AppKit
import CoreGraphics
import Foundation

final class OutputLayer {

    // System "media key" virtual key codes (HID consumer page).
    private enum MediaKey: UInt16 {
        case playPause      = 0xF88B
        case nextTrack      = 0xF88E
        case prevTrack      = 0xF88F
        case volumeUp       = 0xF887
        case volumeDown     = 0xF888
        case mute           = 0xF8A2
        case brightnessUp   = 0xF8A0   // ADR-012
        case brightnessDown = 0xF8A1   // ADR-012
    }

    // Regular keyboard codes (arrows) for seek / volume.
    private enum Key: UInt16 {
        case left  = 0x7B
        case right = 0x7C
        case up    = 0x7E
        case down  = 0x7D
    }

    func perform(_ action: MediaAction) {
        DebugLog.log("perform: \(action)")
        switch action {
        case .playPause:       postSystemKey(16)   // NX_KEYTYPE_PLAY
        case .next:            postSystemKey(17)       // NX_KEYTYPE_NEXT
        case .prev:            postSystemKey(18)       // NX_KEYTYPE_PREVIOUS
        case .mute:            postSystemKey(7)        // NX_KEYTYPE_MUTE
        case .brightnessUp:    postSystemKey(2)     // NX_KEYTYPE_BRIGHTNESS_UP
        case .brightnessDown:  postSystemKey(3)   // NX_KEYTYPE_BRIGHTNESS_DOWN
        case .volUp:           postKey(.up)
        case .volDown:         postKey(.down)
        case .seekBack:        postKey(.left)
        case .seekForward:     postKey(.right)
        }
    }

    // Media keys must be posted from the HID system state source.
    private func postMedia(_ key: MediaKey) {
        let src = CGEventSource(stateID: .hidSystemState)
        post(code: key.rawValue, source: src)
    }

    // Real HID media key: system-defined event (subtype 8), keyType in data1.
    private func postSystemKey(_ keyType: Int) {
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