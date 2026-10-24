// AppDelegate.swift — menu-bar (status item) shell (see ADR-005, ADR-008).

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem!
    private let media = MediaController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLog.reset()
        DebugLog.log("launch: pid=\(ProcessInfo.processInfo.processIdentifier) path=\(Bundle.main.bundlePath)")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gamecontroller",
                                   accessibilityDescription: "Couch")
            button.toolTip = "Couch — media remote"
        }

        let menu = NSMenu()

        enabledItem = NSMenuItem(title: "Remote: ON",
                                 action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(enabledItem)
        menu.addItem(.separator())

        let checkItem = NSMenuItem(title: "Check Accessibility…",
                                   action: #selector(checkPermissions), keyEquivalent: "")
        checkItem.target = self
        menu.addItem(checkItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit",
                                  action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        media.onStateChange = { [weak self] on in
            self?.updateUI(on: on)
        }

        // Prompt for Accessibility on first launch (needed to post events).
        media.ensureAccessibility(prompt: true)

        media.start()
    }

    private func updateUI(on: Bool) {
        enabledItem.title = on ? "Remote: ON" : "Remote: OFF"
        statusItem.button?.toolTip = on
            ? "Couch — media remote (on)"
            : "Couch — media remote (off)"
    }

    @objc private func toggleEnabled() {
        media.enabled.toggle()
        updateUI(on: media.enabled)
    }

    @objc private func checkPermissions() {
        media.ensureAccessibility(prompt: true)
    }

    @objc private func quit() {
        media.stop()
        NSApplication.shared.terminate(nil)
    }
}