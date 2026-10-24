// AppDelegate.swift — menu-bar (status item) shell (see ADR-005, ADR-008).

import AppKit
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var padItem: NSMenuItem!
    private var remoteRow: ToggleMenuItemView!
    private var loginRow: ToggleMenuItemView!
    private var padConnected = false
    private let model = AppModel()
    private lazy var settingsWindow = SettingsWindowController(model: model)
    private var cancellables = Set<AnyCancellable>()

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

        remoteRow = ToggleMenuItemView(title: "Remote", isOn: model.remoteEnabled) { [weak self] on in
            self?.model.remoteEnabled = on
        }
        let remoteItem = NSMenuItem()
        remoteItem.view = remoteRow
        menu.addItem(remoteItem)

        loginRow = ToggleMenuItemView(title: "Launch at Login",
                                      isOn: model.launchAtLogin) { [weak self] on in
            self?.model.setLaunchAtLogin(on)
            self?.loginRow.isOn = self?.model.launchAtLogin ?? on
        }
        let loginItem = NSMenuItem()
        loginItem.view = loginRow
        menu.addItem(loginItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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

        model.media.onControllerChange = { [weak self] name in
            self?.padConnected = name != nil
            self?.padItem.title = name.map { "Controller: \($0)" } ?? "No controller"
            self?.updateUI(on: self?.model.remoteEnabled ?? true)
        }

        // Keep the menu switch and icon in step when the window changes Remote.
        model.$remoteEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] on in self?.updateUI(on: on) }
            .store(in: &cancellables)
        model.$launchAtLogin
            .receive(on: DispatchQueue.main)
            .sink { [weak self] on in self?.loginRow.isOn = on }
            .store(in: &cancellables)

        installMainMenu()
        model.start()
    }

    // Clicking the app in Finder or the Dock while it runs opens the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }

    // The main menu only shows while the window is open (Dock icon visible).
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let app = NSMenu()
        app.addItem(withTitle: "About Couch", action: #selector(showAbout), keyEquivalent: "").target = self
        app.addItem(.separator())
        let prefs = app.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        prefs.target = self
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Couch", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit Couch", action: #selector(quit), keyEquivalent: "q").target = self
        appItem.submenu = app

        let winItem = NSMenuItem()
        main.addItem(winItem)
        let win = NSMenu(title: "Window")
        win.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        win.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winItem.submenu = win
        NSApp.mainMenu = main
        NSApp.windowsMenu = win
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
        model.refreshLaunchAtLogin()
        remoteRow.isOn = model.remoteEnabled
        loginRow.isOn = model.launchAtLogin
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func checkPermissions() {
        model.promptAccessibility()
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
        model.stop()
        NSApplication.shared.terminate(nil)
    }
}