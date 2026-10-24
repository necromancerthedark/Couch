// Screenshots.swift — `Couch --screenshots <dir>` renders every Settings tab
// with demo data into PNGs for the README. It captures the app's own window
// in-process, so it needs no Screen Recording permission, no pad, and sends no
// key events (demo mode never starts the input layer).

import AppKit

final class ScreenshotDelegate: NSObject, NSApplicationDelegate {
    private let dir: URL
    private let model = AppModel(demo: true)
    private lazy var controller = SettingsWindowController(model: model)

    init(dir: URL) {
        self.dir = dir
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        controller.show(tab: .general)
        capture(SettingsTab.allCases[...])
    }

    private func capture(_ tabs: ArraySlice<SettingsTab>) {
        guard let tab = tabs.first else {
            print("screenshots written to \(dir.path)")
            NSApp.terminate(nil)
            return
        }
        controller.nav.selection = tab
        // Tuning is a long page; capture it tall so nothing is cut off.
        controller.window?.setContentSize(NSSize(width: 900, height: (tab == .tuning || tab == .apps) ? 880 : 620))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [self] in
            save(name: tab.rawValue.lowercased())
            capture(tabs.dropFirst())
        }
    }

    private func save(name: String) {
        guard let frame = controller.window?.contentView?.superview else { return }
        frame.layoutSubtreeIfNeeded()
        guard let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { return }
        frame.cacheDisplay(in: frame.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
