// SettingsStore.swift — observable wrapper around Config for the Settings window.
// Changes validate, persist (debounced) and apply live via onChange (ADR-020).

import Foundation
import Combine

final class SettingsStore: ObservableObject {
    @Published var values: Config.Values {
        didSet { if !applying { apply() } }
    }
    @Published private(set) var warnings: [String] = []

    /// Called on every accepted change so the input layer can reconfigure live.
    var onChange: ((Config.Values) -> Void)?

    private let demo: Bool
    private var applying = false
    private var saveWork: DispatchWorkItem?

    init(demo: Bool = false) {
        self.demo = demo
        self.values = demo ? Config.defaults : Config.load()
    }

    /// Re-read config.json (it may have been hand-edited).
    func reload() {
        guard !demo else { return }
        applying = true
        values = Config.load()
        applying = false
        warnings = []
        onChange?(values)
    }

    func resetAll() { values = Config.defaults }

    private func apply() {
        let (valid, found) = Config.validate(values)
        if valid != values {
            applying = true
            values = valid
            applying = false
        }
        warnings = found
        onChange?(valid)
        guard !demo else { return }
        saveWork?.cancel()
        let work = DispatchWorkItem { Config.save(valid) }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
