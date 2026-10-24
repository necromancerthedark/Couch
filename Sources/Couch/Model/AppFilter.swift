// AppFilter.swift — which frontmost apps Couch may act in (ADR-023).
// Pure value type so it is easy to test. Allowlist by default: any app not on
// the list, including every game, gets no key events from the pad.

import Foundation

struct AppFilter: Equatable {
    enum Mode: String, CaseIterable {
        case allowlist
        case off        // act everywhere, as before 0.4
    }

    var mode: Mode
    var apps: [String]  // bundle ids, in the order shown in the Apps tab

    static let defaultApps = [
        "com.colliderli.iina",          // IINA
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "company.thebrowser.Browser",   // Arc
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "org.videolan.vlc",
        "com.apple.QuickTimePlayerX",
        "com.apple.Music",
        "com.apple.TV",
        "com.spotify.client"
    ]

    /// Friendly names for the defaults, shown when an app is not installed.
    static let knownNames: [String: String] = [
        "com.colliderli.iina": "IINA",
        "com.apple.Safari": "Safari",
        "com.google.Chrome": "Google Chrome",
        "org.mozilla.firefox": "Firefox",
        "company.thebrowser.Browser": "Arc",
        "com.brave.Browser": "Brave Browser",
        "com.microsoft.edgemac": "Microsoft Edge",
        "org.videolan.vlc": "VLC",
        "com.apple.QuickTimePlayerX": "QuickTime Player",
        "com.apple.Music": "Music",
        "com.apple.TV": "TV",
        "com.spotify.client": "Spotify"
    ]

    static let defaults = AppFilter(mode: .allowlist, apps: defaultApps)

    /// May Couch act while this app is frontmost? (nil = no frontmost app.)
    func allows(_ bundleID: String?) -> Bool {
        switch mode {
        case .off: return true
        case .allowlist:
            guard let bundleID else { return false }
            return apps.contains(bundleID)
        }
    }

    /// Trim, drop blanks, drop duplicates (keeping order).
    func cleaned() -> AppFilter {
        var seen = Set<String>()
        let kept = apps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return AppFilter(mode: mode, apps: kept)
    }
}
