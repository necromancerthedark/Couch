// Config.swift — runtime-tunable values, read from
// ~/Library/Application Support/Couch/config.json if present.
//
// Why: every rebuild changes the ad-hoc signature, which invalidates the
// Accessibility grant (ADR-007). Tuning via this file means NO rebuild, so
// the grant stays valid. Defaults come from Mapping.swift.
//
// Example config.json:
//   { "triggerThreshold": 0.15, "seekSlow": 0.5, "seekFast": 0.08 }

import Foundation

enum Config {
    struct Values {
        var triggerThreshold: Float
        var seekSlow: TimeInterval
        var seekFast: TimeInterval
        var stickDeadzone: Float
        var volumeSlow: TimeInterval
        var volumeFast: TimeInterval
    }

    static let url: URL = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Application Support/Couch/config.json")

    static func load() -> Values {
        var v = Values(
            triggerThreshold: Mapping.triggerThreshold,
            seekSlow: Mapping.seekSlowInterval,
            seekFast: Mapping.seekFastInterval,
            stickDeadzone: Mapping.stickDeadzone,
            volumeSlow: Mapping.volumeSlowInterval,
            volumeFast: Mapping.volumeFastInterval
        )
        guard
            let data = try? Data(contentsOf: url),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return v }
        if let x = obj["triggerThreshold"] as? Double { v.triggerThreshold = Float(x) }
        if let x = obj["seekSlow"] as? Double { v.seekSlow = x }
        if let x = obj["seekFast"] as? Double { v.seekFast = x }
        if let x = obj["stickDeadzone"] as? Double { v.stickDeadzone = Float(x) }
        if let x = obj["volumeSlow"] as? Double { v.volumeSlow = x }
        if let x = obj["volumeFast"] as? Double { v.volumeFast = x }

        // Reject nonsense: bad values would divide by zero or flood key events.
        let d = Values(triggerThreshold: Mapping.triggerThreshold,
                       seekSlow: Mapping.seekSlowInterval,
                       seekFast: Mapping.seekFastInterval,
                       stickDeadzone: Mapping.stickDeadzone,
                       volumeSlow: Mapping.volumeSlowInterval,
                       volumeFast: Mapping.volumeFastInterval)
        if !(0.01...0.95).contains(v.triggerThreshold) {
            DebugLog.log("config: triggerThreshold \(v.triggerThreshold) out of 0.01...0.95, using default")
            v.triggerThreshold = d.triggerThreshold
        }
        let ok = v.seekFast >= 0.02 && v.seekSlow <= 5 && v.seekFast <= v.seekSlow
        if !ok {
            DebugLog.log("config: seek intervals invalid (need 0.02 <= seekFast <= seekSlow <= 5), using defaults")
            v.seekSlow = d.seekSlow
            v.seekFast = d.seekFast
        }
        if !(0.1...0.9).contains(v.stickDeadzone) {
            DebugLog.log("config: stickDeadzone \(v.stickDeadzone) out of 0.1...0.9, using default")
            v.stickDeadzone = d.stickDeadzone
        }
        if !(v.volumeFast >= 0.02 && v.volumeSlow <= 5 && v.volumeFast <= v.volumeSlow) {
            DebugLog.log("config: volume intervals invalid (need 0.02 <= volumeFast <= volumeSlow <= 5), using defaults")
            v.volumeSlow = d.volumeSlow
            v.volumeFast = d.volumeFast
        }
        return v
    }
}