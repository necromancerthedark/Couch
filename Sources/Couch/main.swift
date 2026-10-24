// main.swift — app bootstrap.
//
// Runs as a menu-bar (agent) app: no Dock icon, lives in the status bar.
// See ADR-005 (menu-bar form) and ADR-008 (AppKit over SwiftUI).

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()