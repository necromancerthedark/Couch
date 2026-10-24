// AppDelegate.swift — menu-bar (status item) shell (see ADR-005, ADR-008).

import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var padItem: NSMenuItem!
    private var remoteRow: ToggleMenuItemView!
    private var loginRow: ToggleMenuItemView!
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
        menu.addItem(.separator())

        remoteRow = ToggleMenuItemView(title: "Remote", isOn: media.enabled) { [weak self] on in
            guard let self else { return }
            self.media.enabled = on
            self.updateUI(on: on)
        }
        let remoteItem = NSMenuItem()
        remoteItem.view = remoteRow
        menu.addItem(remoteItem)

        loginRow = ToggleMenuItemView(title: "Launch at Login",
                                      isOn: SMAppService.mainApp.status == .enabled) { [weak self] on in
            self?.setLaunchAtLogin(on)
        }
        let loginItem = NSMenuItem()
        loginItem.view = loginRow
        menu.addItem(loginItem)
        menu.addItem(.separator())

        let checkItem = NSMenuItem(title: "Check Accessibility…",
                                   action: #selector(checkPermissions), keyEquivalent: "")
        checkItem.target = self
        menu.addItem(checkItem)

        let aboutItem = NSMenuItem(title: "About Couch",
                                   action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit",
                                  action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
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
        remoteRow.isOn = on
        // Filled icon = live; outline = remote off or no pad.
        let live = on && padConnected
        statusItem.button?.image = NSImage(
            systemSymbolName: live ? "gamecontroller.fill" : "gamecontroller",
            accessibilityDescription: "Couch")
        statusItem.button?.toolTip = on
            ? "Couch — media remote (on)"
            : "Couch — media remote (off)"
    }

    // Re-read both states so changes made elsewhere (Login Items) show up.
    func menuWillOpen(_ menu: NSMenu) {
        remoteRow.isOn = media.enabled
        loginRow.isOn = SMAppService.mainApp.status == .enabled
    }

    @objc private func checkPermissions() {
        media.ensureAccessibility(prompt: true)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        let svc = SMAppService.mainApp
        do {
            if on { try svc.register() } else { try svc.unregister() }
        } catch {
            DebugLog.log("login item: \(error)")
        }
        // Snap the switch to the real state if the change failed.
        loginRow.isOn = svc.status == .enabled
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Couch",
            .credits: aboutCredits()
        ])
    }

    private func aboutCredits() -> NSAttributedString {
        let center = NSMutableParagraphStyle()
        center.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .paragraphStyle: center,
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor
        ]
        let text = NSMutableAttributedString(
            string: "Gamepad media remote for macOS.\nby Kumar Gaurav Pandey\n", attributes: base)
        var link = base
        link[.link] = URL(string: "https://github.com/necromancerthedark")!
        text.append(NSAttributedString(string: "github.com/necromancerthedark", attributes: link))
        return text
    }

    @objc private func quit() {
        media.stop()
        NSApplication.shared.terminate(nil)
    }
}