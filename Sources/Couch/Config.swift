// Config.swift — runtime-tunable values, stored in
// ~/Library/Application Support/Couch/config.json (hand-editable, and edited by
// the Settings window). Tuning needs no rebuild, so the Accessibility grant
// stays valid (ADR-007, ADR-014). Defaults come from Mapping.swift.
//
// Example config.json:
//   { "triggerThreshold": 0.15, "seekSlow": 0.5, "seekFast": 0.08,
//     "stickDeadzone": 0.30, "volumeSlow": 0.30, "volumeFast": 0.08 }

import Foundation

enum Config {
    struct Values: Equatable {
        var triggerThreshold: Float
        var seekSlow: TimeInterval
        var seekFast: TimeInterval
        var stickDeadzone: Float
        var volumeSlow: TimeInterval
        var volumeFast: TimeInterval
        var appFilter: AppFilter
    }

    static let defaults = Values(
        triggerThreshold: Mapping.triggerThreshold,
        seekSlow: Mapping.seekSlowInterval,
        seekFast: Mapping.seekFastInterval,
        stickDeadzone: Mapping.stickDeadzone,
        volumeSlow: Mapping.volumeSlowInterval,
        volumeFast: Mapping.volumeFastInterval,
        appFilter: AppFilter.defaults
    )

    /// Valid ranges, shared by the validator and the Settings sliders.
    enum Limits {
        static let triggerThreshold: ClosedRange<Float> = 0.01...0.95
        static let stickDeadzone: ClosedRange<Float> = 0.1...0.9
        static let intervalMin: TimeInterval = 0.02
        static let intervalMax: TimeInterval = 5
    }

    static let url: URL = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Application Support/Couch/config.json")

    /// Read config.json (if any) and validate it. Bad values fall back to defaults.
    static func load() -> Values {
        var v = defaults
        if let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let x = obj["triggerThreshold"] as? Double { v.triggerThreshold = Float(x) }
            if let x = obj["seekSlow"] as? Double { v.seekSlow = x }
            if let x = obj["seekFast"] as? Double { v.seekFast = x }
            if let x = obj["stickDeadzone"] as? Double { v.stickDeadzone = Float(x) }
            if let x = obj["volumeSlow"] as? Double { v.volumeSlow = x }
            if let x = obj["volumeFast"] as? Double { v.volumeFast = x }
            if let f = obj["appFilter"] as? [String: Any] {
                if let m = f["mode"] as? String {
                    if let mode = AppFilter.Mode(rawValue: m) {
                        v.appFilter.mode = mode
                    } else {
                        DebugLog.log("config: appFilter.mode '\(m)' unknown, using allowlist")
                    }
                }
                if let a = f["apps"] as? [String] { v.appFilter.apps = a }
            }
        }
        let (valid, warnings) = validate(v)
        warnings.forEach { DebugLog.log("config: \($0)") }
        return valid
    }

    /// Reject nonsense: bad values would divide by zero or flood key events.
    static func validate(_ input: Values) -> (Values, [String]) {
        var v = input
        var warnings: [String] = []
        if !Limits.triggerThreshold.contains(v.triggerThreshold) {
            warnings.append("triggerThreshold \(v.triggerThreshold) out of \(Limits.triggerThreshold), using default")
            v.triggerThreshold = defaults.triggerThreshold
        }
        if !(v.seekFast >= Limits.intervalMin && v.seekSlow <= Limits.intervalMax && v.seekFast <= v.seekSlow) {
            warnings.append("seek intervals invalid (need 0.02 <= seekFast <= seekSlow <= 5), using defaults")
            v.seekSlow = defaults.seekSlow
            v.seekFast = defaults.seekFast
        }
        if !Limits.stickDeadzone.contains(v.stickDeadzone) {
            warnings.append("stickDeadzone \(v.stickDeadzone) out of \(Limits.stickDeadzone), using default")
            v.stickDeadzone = defaults.stickDeadzone
        }
        if !(v.volumeFast >= Limits.intervalMin && v.volumeSlow <= Limits.intervalMax && v.volumeFast <= v.volumeSlow) {
            warnings.append("volume intervals invalid (need 0.02 <= volumeFast <= volumeSlow <= 5), using defaults")
            v.volumeSlow = defaults.volumeSlow
            v.volumeFast = defaults.volumeFast
        }
        v.appFilter = v.appFilter.cleaned()
        if v.appFilter.mode == .allowlist && v.appFilter.apps.isEmpty {
            warnings.append("appFilter allowlist is empty, so Couch will not act in any app")
        }
        return (v, warnings)
    }

    static func save(_ v: Values) {
        let obj: [String: Any] = [
            "triggerThreshold": Double(v.triggerThreshold),
            "seekSlow": v.seekSlow,
            "seekFast": v.seekFast,
            "stickDeadzone": Double(v.stickDeadzone),
            "volumeSlow": v.volumeSlow,
            "volumeFast": v.volumeFast,
            "appFilter": ["mode": v.appFilter.mode.rawValue, "apps": v.appFilter.apps] as [String: Any]
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
