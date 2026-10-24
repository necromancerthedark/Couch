// EventLog.swift — in-memory ring buffer of recent log lines for the Debug tab.
// Fed by DebugLog.sink; the log file stays the durable record (ADR-020).

import Foundation

struct LogEvent: Identifiable {
    enum Kind: String, CaseIterable {
        case input = "Inputs"
        case action = "Actions"
        case system = "System"
        case error = "Errors"
    }

    let id: Int
    let date: Date
    let kind: Kind
    let text: String
}

final class EventLog: ObservableObject {
    @Published private(set) var events: [LogEvent] = []
    var paused = false

    private var nextID = 0
    private let capacity = 500

    func append(_ line: String, date: Date = Date()) {
        guard !paused else { return }
        nextID += 1
        events.append(LogEvent(id: nextID, date: date, kind: Self.classify(line), text: line))
        if events.count > capacity { events.removeFirst(events.count - capacity) }
    }

    func clear() { events.removeAll() }

    static func classify(_ line: String) -> LogEvent.Kind {
        if line.hasPrefix("input:") { return .input }
        if line.hasPrefix("fire:") || line.hasPrefix("perform:") || line.hasPrefix("post:") { return .action }
        if line.hasPrefix("config:") || line.hasPrefix("login item:") || line.contains("error") { return .error }
        return .system
    }

    /// Demo data for screenshots.
    func loadDemo() {
        let now = Date()
        let rows: [(String, TimeInterval)] = [
            ("launch: pid=4242 path=/Applications/Couch.app", -62),
            ("accessibility: trusted=true prompt=true", -62),
            ("attach: vendorName='Xbox Bluetooth Gamepad' productCategory='Xbox One' extendedGamepad=true", -58),
            ("fire: playPause trusted=true", -31),
            ("perform: playPause", -31),
            ("post: systemKey=16 (NX media key)", -31),
            ("fire: systemVolUp trusted=true", -12),
            ("perform: systemVolUp", -12),
            ("post: systemKey=0 (NX media key)", -12),
            ("perform: playerVolUp", -4),
            ("fire: fullscreen trusted=true", -2)
        ]
        rows.forEach { append($0.0, date: now.addingTimeInterval($0.1)) }
    }
}
