// FrontmostAppMonitor.swift — tracks which app is frontmost (ADR-023).
// NSWorkspace only: no permission needed. Opening Couch's own status menu does
// not change the frontmost app, so the menu can act on "the app you were in".

import AppKit

struct FrontApp: Equatable {
    let bundleID: String
    let name: String
}

final class FrontmostAppMonitor: ObservableObject {
    @Published private(set) var current: FrontApp?

    private var observer: NSObjectProtocol?

    init(demo: Bool = false) {
        if demo {
            current = FrontApp(bundleID: "com.colliderli.iina", name: "IINA")
            return   // demo data stays fixed for screenshots
        }
        current = Self.read(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.current = Self.read(app)
        }
    }

    deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    private static func read(_ app: NSRunningApplication?) -> FrontApp? {
        guard let id = app?.bundleIdentifier else { return nil }
        return FrontApp(bundleID: id, name: app?.localizedName ?? id)
    }
}

/// Name and icon for a bundle id, for the Apps tab and the menu.
enum AppInfo {
    struct Resolved {
        let name: String
        let icon: NSImage
        let installed: Bool
    }

    static func resolve(_ bundleID: String) -> Resolved {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            return Resolved(name: name, icon: NSWorkspace.shared.icon(forFile: url.path), installed: true)
        }
        let generic = NSWorkspace.shared.icon(for: .application)
        return Resolved(name: AppFilter.knownNames[bundleID] ?? bundleID, icon: generic, installed: false)
    }
}
