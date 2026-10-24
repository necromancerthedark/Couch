// DebugView.swift — live event feed, log viewer, diagnostics, action tester.

import SwiftUI

struct DebugView: View {
    enum Page: String, CaseIterable, Identifiable {
        case events = "Events", log = "Log", diagnostics = "Diagnostics", tester = "Tester"
        var id: String { rawValue }
    }

    @ObservedObject var model: AppModel
    @ObservedObject var events: EventLog
    @State private var page: Page = .events

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PageTitle(text: "Debug")
                Spacer()
                Picker("Page", selection: $page) {
                    ForEach(Page.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 330)
            }
            switch page {
            case .events: EventsPage(events: events)
            case .log: LogPage()
            case .diagnostics: DiagnosticsPage(model: model)
            case .tester: TesterPage(model: model)
            }
        }
        .padding(24)
    }
}

// MARK: - Events

private struct EventsPage: View {
    @ObservedObject var events: EventLog
    @State private var shown: Set<LogEvent.Kind> = [.action, .system, .error]
    @State private var paused = false

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var rows: [LogEvent] {
        events.events.reversed().filter { shown.contains($0.kind) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ForEach(LogEvent.Kind.allCases, id: \.self) { kind in
                    Toggle(kind.rawValue, isOn: Binding(
                        get: { shown.contains(kind) },
                        set: { on in if on { shown.insert(kind) } else { shown.remove(kind) } }))
                        .toggleStyle(.checkbox)
                }
                Spacer()
                Toggle("Pause", isOn: $paused).toggleStyle(.checkbox)
                    .onChange(of: paused) { events.paused = $0 }
                Button("Clear") { events.clear() }
            }
            List(rows) { e in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(Self.time.string(from: e.date))
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    Text(e.kind.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(color(e.kind).opacity(0.18), in: Capsule())
                        .foregroundStyle(color(e.kind))
                        .frame(width: 64, alignment: .leading)
                    Text(e.text).font(.system(size: 11, design: .monospaced)).lineLimit(2)
                }
            }
            .overlay {
                if rows.isEmpty {
                    Text("Nothing yet. Press a button on the pad.").foregroundStyle(.secondary)
                }
            }
            Text("Showing the newest 500 events. Inputs are hidden by default because they are noisy.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func color(_ k: LogEvent.Kind) -> Color {
        switch k {
        case .input: return .gray
        case .action: return .accentColor
        case .system: return .teal
        case .error: return .red
        }
    }
}

// MARK: - Log file

private struct LogPage: View {
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(DebugLog.url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Spacer()
                Button("Refresh") { load() }
                Button("Copy") { copy(text) }
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([DebugLog.url]) }
            }
            ScrollView {
                Text(text.isEmpty ? "Log is empty." : text)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .onAppear { load() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: DebugLog.url) else { text = ""; return }
        // Last 200 KB is plenty and keeps the view fast.
        let tail = data.suffix(200_000)
        text = String(decoding: tail, as: UTF8.self)
    }
}

// MARK: - Diagnostics

private struct DiagnosticsPage: View {
    @ObservedObject var model: AppModel
    @State private var report = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Refresh") { refresh() }
                Button("Copy diagnostics") { copy(report) }
                Spacer()
                if !model.accessibilityTrusted {
                    Button("Prompt for Accessibility") { model.promptAccessibility(); refresh() }
                }
            }
            ScrollView {
                Text(report)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            Text("Paste this into a bug report. It contains no personal data.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { refresh() }
    }

    private func refresh() {
        model.refreshAccessibility()
        report = model.diagnosticsReport()
    }
}

// MARK: - Action tester

private struct TesterPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fire an action as if the pad did. If a button here works but the pad does nothing, the problem is input. If neither works, it is output (usually Accessibility).")
                .font(.callout).foregroundStyle(.secondary)
            if !model.accessibilityTrusted {
                Label("Accessibility is not granted, so these will not do anything.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                ForEach(MediaAction.allCases, id: \.description) { action in
                    Button {
                        if !model.demo { model.media.perform(action) }
                    } label: {
                        Text(action.title).frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
            }
            Spacer()
        }
    }
}

private func copy(_ s: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(s, forType: .string)
}
