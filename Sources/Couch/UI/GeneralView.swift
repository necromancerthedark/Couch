// GeneralView.swift — Remote and Launch at Login switches, Accessibility status.

import SwiftUI

struct GeneralView: View {
    @ObservedObject var model: AppModel
    private let tick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                Toggle("Remote", isOn: $model.remoteEnabled)
                    .toggleStyle(.switch)
                Text("Turns the whole gamepad on or off without quitting.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Launch at Login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch)
            }

            Section("Accessibility") {
                HStack(spacing: 10) {
                    Image(systemName: model.accessibilityTrusted
                          ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.accessibilityTrusted ? .green : .orange)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.accessibilityTrusted ? "Permission granted" : "Permission needed")
                            .font(.headline)
                        Text(model.accessibilityTrusted
                             ? "Couch can send media keys and key presses."
                             : "Without it the pad is read but nothing is sent. Turn Couch on in the list, then relaunch it.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("Re-check") { model.refreshAccessibility() }
                    Button("Open Accessibility Settings") {
                        NSWorkspace.shared.open(URL(string:
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                    if !model.accessibilityTrusted {
                        Button("Prompt again") { model.promptAccessibility() }
                    }
                }
            }

            Section("Status") {
                LabeledContent("Controller", value: model.pad.device?.name ?? "No controller")
                LabeledContent("Version", value: AppModel.version)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            model.refreshAccessibility()
            model.refreshLaunchAtLogin()
        }
        .onReceive(tick) { _ in
            model.refreshAccessibility()
            model.refreshLaunchAtLogin()
        }
    }
}
