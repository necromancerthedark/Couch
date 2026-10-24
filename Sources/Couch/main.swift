// main.swift — app bootstrap.
//
// Runs as a menu-bar (agent) app: no Dock icon, lives in the status bar.
// See ADR-005 (menu-bar form) and ADR-008 (AppKit over SwiftUI).
//
// `Couch --screenshots <dir>` is a developer mode that renders the Settings
// tabs with demo data to PNGs (see Screenshots.swift).

import AppKit

let app = NSApplication.shared
let args = CommandLine.arguments

if let i = args.firstIndex(of: "--screenshots"), i + 1 < args.count {
    let delegate = ScreenshotDelegate(dir: URL(fileURLWithPath: args[i + 1]))
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
} else {
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
