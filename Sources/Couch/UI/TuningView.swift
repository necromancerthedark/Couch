// TuningView.swift — sliders for every config value. Changes apply live and
// are saved to config.json (ADR-020).

import SwiftUI

struct TuningView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var pad: PadMonitor

    private var v: Config.Values { settings.values }

    var body: some View {
        Form {
            Section {
                row("Trigger threshold",
                    "How far a trigger must be pressed before it counts.",
                    value: floatBinding(\.triggerThreshold),
                    range: Double(Config.Limits.triggerThreshold.lowerBound)...Double(Config.Limits.triggerThreshold.upperBound),
                    unit: "")
                LevelPreview(title: "LT", value: pad.snapshot.lt, marker: v.triggerThreshold)
                LevelPreview(title: "RT", value: pad.snapshot.rt, marker: v.triggerThreshold)
                row("Slowest seek interval",
                    "Time between seeks at a light press.",
                    value: doubleBinding(\.seekSlow),
                    range: v.seekFast...Config.Limits.intervalMax, unit: "s")
                row("Fastest seek interval",
                    "Time between seeks at a full press.",
                    value: doubleBinding(\.seekFast),
                    range: Config.Limits.intervalMin...v.seekSlow, unit: "s")
            } header: {
                header("Triggers: hold to seek") {
                    settings.values.triggerThreshold = Config.defaults.triggerThreshold
                    settings.values.seekSlow = Config.defaults.seekSlow
                    settings.values.seekFast = Config.defaults.seekFast
                }
            }

            Section {
                row("Stick deadzone",
                    "How far the left stick must be pushed to change the player volume.",
                    value: floatBinding(\.stickDeadzone),
                    range: Double(Config.Limits.stickDeadzone.lowerBound)...Double(Config.Limits.stickDeadzone.upperBound),
                    unit: "")
                LevelPreview(title: "Stick ▲", value: max(0, pad.snapshot.ls.y), marker: v.stickDeadzone)
                LevelPreview(title: "Stick ▼", value: max(0, -pad.snapshot.ls.y), marker: v.stickDeadzone)
                row("Slowest volume interval",
                    "Time between volume steps just past the deadzone.",
                    value: doubleBinding(\.volumeSlow),
                    range: v.volumeFast...Config.Limits.intervalMax, unit: "s")
                row("Fastest volume interval",
                    "Time between volume steps at a full push.",
                    value: doubleBinding(\.volumeFast),
                    range: Config.Limits.intervalMin...v.volumeSlow, unit: "s")
            } header: {
                header("Left stick: player volume") {
                    settings.values.stickDeadzone = Config.defaults.stickDeadzone
                    settings.values.volumeSlow = Config.defaults.volumeSlow
                    settings.values.volumeFast = Config.defaults.volumeFast
                }
            }

            Section {
                HStack {
                    Button("Reset everything") { settings.resetAll() }
                    Button("Reveal config.json") {
                        NSWorkspace.shared.activateFileViewerSelecting([Config.url])
                    }
                }
                ForEach(settings.warnings, id: \.self) { w in
                    Label(w, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.caption)
                }
                Text("Changes apply immediately and are saved to config.json, which you can also edit by hand.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { settings.reload() }
    }

    // MARK: Helpers

    private func header(_ title: String, reset: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button("Reset", action: reset).buttonStyle(.link)
        }
    }

    private func row(_ title: String, _ help: String, value: Binding<Double>,
                     range: ClosedRange<Double>, unit: String) -> some View {
        // Slider needs lower < upper; keep a hair of travel at the limits.
        let safe = range.lowerBound < range.upperBound
            ? range : range.lowerBound...(range.lowerBound + 0.01)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue) + (unit.isEmpty ? "" : " \(unit)"))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: safe)
            Text(help).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func floatBinding(_ kp: WritableKeyPath<Config.Values, Float>) -> Binding<Double> {
        Binding(get: { Double(settings.values[keyPath: kp]) },
                set: { settings.values[keyPath: kp] = Float($0) })
    }

    private func doubleBinding(_ kp: WritableKeyPath<Config.Values, TimeInterval>) -> Binding<Double> {
        Binding(get: { settings.values[keyPath: kp] },
                set: { settings.values[keyPath: kp] = $0 })
    }
}

/// Live bar with the threshold marked, so you can see where a press starts to count.
struct LevelPreview: View {
    let title: String
    let value: Float
    let marker: Float

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.caption).foregroundStyle(.secondary).frame(width: 54, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(value > marker ? Color.accentColor : Color.secondary.opacity(0.6))
                        .frame(width: g.size.width * CGFloat(min(1, max(0, value))))
                    Rectangle().fill(Color.primary.opacity(0.7))
                        .frame(width: 2, height: 12)
                        .offset(x: g.size.width * CGFloat(marker) - 1)
                }
            }
            .frame(height: 8)
            Text(String(format: "%.2f", value)).font(.caption).monospacedDigit()
                .foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
        }
    }
}
