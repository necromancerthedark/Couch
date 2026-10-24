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
    }

    static let url: URL = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Application Support/Couch/config.json")

    static func load() -> Values {
        var v = Values(
            triggerThreshold: Mapping.triggerThreshold,
            seekSlow: Mapping.seekSlowInterval,
            seekFast: Mapping.seekFastInterval
        )
        guard
            let data = try? Data(contentsOf: url),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return v }
        if let x = obj["triggerThreshold"] as? Double { v.triggerThreshold = Float(x) }
        if let x = obj["seekSlow"] as? Double { v.seekSlow = x }
        if let x = obj["seekFast"] as? Double { v.seekFast = x }
        return v
    }
}