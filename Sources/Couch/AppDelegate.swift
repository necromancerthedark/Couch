// AppDelegate.swift — menu-bar (status item) shell (see ADR-005, ADR-008).

import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem!
    private var padItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var padConnected = false
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

        padItem = NSMenuItem(title: "No controller", action: nil, keyEquivalent: "")
        padItem.isEnabled = false
        menu.addItem(padItem)
        enabledItem = NSMenuItem(title: "Remote: ON",
                                 action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(enabledItem)
        menu.addItem(.separator())

        let checkItem = NSMenuItem(title: "Check Accessibility…",
                                   action: #selector(checkPermissions), keyEquivalent: "")
        checkItem.target = self
        menu.addItem(checkItem)

        loginItem = NSMenuItem(title: "Launch at Login",
                               action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        let aboutItem = NSMenuItem(title: "About Couch",
                                   action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit",
                                  action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        media.onStateChange = { [weak self] on in
            self?.updateUI(on: on)
        }

        media.onControllerChange = { [weak self] name in
            self?.padConnected = name != nil
            self?.padItem.title = name.map { "Controller: \($0)" } ?? "No controller"
            self?.updateUI(on: self?.media.enabled ?? true)
        }

        // Prompt for Accessibility on first launch (needed to post events).
        media.ensureAccessibility(prompt: true)

        media.start()
    }

    private func updateUI(on: Bool) {
        enabledItem.title = on ? "Remote: ON" : "Remote: OFF"
        // Filled icon = live; outline = remote off or no pad.
        let live = on && padConnected
        statusItem.button?.image = NSImage(
            systemSymbolName: live ? "gamecontroller.fill" : "gamecontroller",
            accessibilityDescription: "Couch")
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

    @objc private func toggleLogin() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled { try svc.unregister() } else { try svc.register() }
        } catch {
            DebugLog.log("login item: \(error)")
        }
        loginItem.state = svc.status == .enabled ? .on : .off
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Couch",
            .credits: NSAttributedString(string: "Gamepad media remote for macOS.")
        ])
    }

    @objc private func quit() {
        media.stop()
        NSApplication.shared.terminate(nil)
    }
}