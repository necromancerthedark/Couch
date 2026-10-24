// SettingsWindowController.swift — owns the companion window (ADR-020).
// Couch stays a menu-bar agent: it shows a Dock icon only while this window is
// open, and drops back to .accessory when it closes.

import AppKit
import SwiftUI

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    let nav = NavState()
    private(set) var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show(tab: SettingsTab? = nil) {
        if let tab { nav.selection = tab }
        if window == nil { window = makeWindow() }
        guard let window else { return }
        NSApp.setActivationPolicy(.regular)
        model.pad.setObserved(true)
        model.refreshAccessibility()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: RootView(model: model, nav: nav))
        let w = NSWindow(contentViewController: host)
        w.title = "Couch"
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        w.setContentSize(NSSize(width: 900, height: 620))
        w.isReleasedWhenClosed = false
        w.setFrameAutosaveName("CouchSettings")
        w.center()
        w.delegate = self
        return w
    }

    func windowWillClose(_ notification: Notification) {
        model.pad.setObserved(false)
        NSApp.setActivationPolicy(.accessory)
    }
}
