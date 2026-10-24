// AppsView.swift — the app allowlist: where Couch may act (ADR-023).

import SwiftUI
import UniformTypeIdentifiers

struct AppsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var front: FrontmostAppMonitor

    private var filter: AppFilter { settings.values.appFilter }

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: Binding(
                    get: { filter.mode },
                    set: { model.setFilterMode($0) })) {
                    Text("Only in these apps").tag(AppFilter.Mode.allowlist)
                    Text("Everywhere").tag(AppFilter.Mode.off)
                }
                .pickerStyle(.segmented)
                Text(filter.mode == .allowlist
                     ? "Couch acts only while one of the apps below is in front, so games and other apps get no key presses from the pad."
                     : "Couch acts in every app. Games will receive its media keys, volume and arrow keys.")
                    .font(.caption).foregroundStyle(.secondary)
                statusRow
            }

            if filter.mode == .allowlist {
                Section {
                    ForEach(filter.apps, id: \.self) { id in row(id) }
                    if filter.apps.isEmpty {
                        Text("The list is empty, so Couch will not act anywhere. Add an app below.")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    HStack {
                        Text("Allowed apps")
                        Spacer()
                        Button("Reset to defaults") { model.resetApps() }.buttonStyle(.link)
                    }
                }

                Section {
                    HStack {
                        Menu("Add running app…") {
                            let candidates = runningCandidates()
                            if candidates.isEmpty {
                                Text("No other apps running")
                            }
                            ForEach(candidates, id: \.bundleID) { app in
                                Button(app.name) { model.allowApp(app.bundleID) }
                            }
                        }
                        .fixedSize()
                        Button("Add app…") { pickApp() }
                    }
                    Text("Tip: with an app in front, choose **Allow <app>** in the Couch menu-bar menu to add it in one click.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Pieces

    private var statusRow: some View {
        let paused = model.pausedIn
        return HStack(spacing: 8) {
            Image(systemName: paused == nil ? "checkmark.circle.fill" : "pause.circle.fill")
                .foregroundStyle(paused == nil ? Color.green : Color.orange)
            Text(statusText(paused))
                .font(.callout)
        }
    }

    private func statusText(_ paused: String?) -> String {
        if front.current?.bundleID == AppModel.ownBundleID {
            return "Paused while this window is in front. Couch never acts in itself."
        }
        return paused.map { "Paused in \($0)" }
            ?? "Active in \(front.current?.name ?? "the frontmost app")"
    }

    private func row(_ id: String) -> some View {
        let info = AppInfo.resolve(id)
        return HStack(spacing: 10) {
            Image(nsImage: info.icon).resizable().frame(width: 28, height: 28)
                .opacity(info.installed ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 1) {
                Text(info.name)
                Text(info.installed ? id : "\(id) · not installed")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.removeApp(id) } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove \(info.name)")
        }
    }

    /// Regular running apps that are not already listed (and not Couch itself).
    private func runningCandidates() -> [FrontApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> FrontApp? in
                guard let id = app.bundleIdentifier,
                      id != AppModel.ownBundleID,
                      !filter.apps.contains(id) else { return nil }
                return FrontApp(bundleID: id, name: app.localizedName ?? id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Allow"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier {
                model.allowApp(id)
            } else {
                DebugLog.log("filter error: no bundle id in \(url.path)")
            }
        }
    }
}
