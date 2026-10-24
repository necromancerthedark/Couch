// AppModel.swift — shared state for the menu-bar item and the Settings window.
// Owns the input layer and the observable models the UI binds to (ADR-020).

import AppKit
import Combine
import GameController
import ServiceManagement
import Security

final class AppModel: ObservableObject {
    let demo: Bool
    let settings: SettingsStore
    let pad = PadMonitor()
    let events = EventLog()
    let media = MediaController()

    @Published var remoteEnabled = true {
        didSet { media.enabled = remoteEnabled }
    }
    @Published private(set) var accessibilityTrusted: Bool
    @Published private(set) var launchAtLogin: Bool

    init(demo: Bool = false) {
        self.demo = demo
        self.settings = SettingsStore(demo: demo)
        self.accessibilityTrusted = demo ? true : AXIsProcessTrusted()
        self.launchAtLogin = demo ? true : SMAppService.mainApp.status == .enabled
        settings.onChange = { [weak self] values in self?.media.reconfigure(values) }
        if demo {
            pad.loadDemo()
            events.loadDemo()
        }
    }

    /// Start the input layer. Not used in demo mode (no pad, no key events).
    func start() {
        guard !demo else { return }
        DebugLog.sink = { [events] line in events.append(line) }
        media.monitor = pad
        media.ensureAccessibility(prompt: true)
        media.start(config: settings.values)
        refreshAccessibility()
    }

    func stop() { media.stop() }

    // MARK: Accessibility

    func refreshAccessibility() {
        guard !demo else { return }
        let trusted = AXIsProcessTrusted()
        if trusted != accessibilityTrusted { accessibilityTrusted = trusted }
    }

    func promptAccessibility() {
        media.ensureAccessibility(prompt: true)
        refreshAccessibility()
    }

    // MARK: Launch at login

    func refreshLaunchAtLogin() {
        guard !demo else { return }
        let on = SMAppService.mainApp.status == .enabled
        if on != launchAtLogin { launchAtLogin = on }
    }

    func setLaunchAtLogin(_ on: Bool) {
        let svc = SMAppService.mainApp
        do {
            if on { try svc.register() } else { try svc.unregister() }
        } catch {
            DebugLog.log("login item error: \(error)")
        }
        // Snap to the real state if the change failed.
        launchAtLogin = svc.status == .enabled
    }

    // MARK: Diagnostics

    static var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let b = info?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    /// Who signed this build: certificate name, or ad-hoc / unsigned.
    static var signingIdentity: String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess,
              let code else { return "unknown" }
        var cfInfo: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &cfInfo) == errSecSuccess,
              let info = cfInfo as? [String: Any] else { return "unknown" }
        if let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
           let first = certs.first,
           let name = SecCertificateCopySubjectSummary(first) as String? {
            return name
        }
        return "ad-hoc or unsigned"
    }

    func diagnosticsReport() -> String {
        let d = pad.device
        var lines = [
            "Couch \(Self.version)",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Signing: \(demo ? "Couch Local Signing" : Self.signingIdentity)",
            "Accessibility: \(accessibilityTrusted ? "trusted" : "NOT trusted")",
            "Remote: \(remoteEnabled ? "on" : "off")",
            "Launch at login: \(launchAtLogin ? "on" : "off")",
            "Background input: \(GCController.shouldMonitorBackgroundEvents ? "on" : "off")",
            "Controller: \(d.map { "\($0.name) (\($0.category)), battery \($0.battery)" } ?? "none")",
            "Config: \(Config.url.path)",
            "Config warnings: \(settings.warnings.isEmpty ? "none" : settings.warnings.joined(separator: "; "))",
            "Settings: \(settings.values)"
        ]
        lines.append("Log: \(DebugLog.url.path)")
        return lines.joined(separator: "\n")
    }
}
