// AdaptiveRepeater.swift — hold-to-seek for analog inputs (see ADR-011).
//
// Driven by start()/stop() on the input's rising/falling edge (called from
// MediaController's edge logic). While running, a self-rescheduling timer
// fires one event per tick; the deeper the press, the faster the ticks.
// Safe to drive from both event callbacks and the fallback poll.

import Foundation

final class AdaptiveRepeater {
    private var timer: Timer?
    private let threshold: Float
    private let slow: TimeInterval
    private let fast: TimeInterval
    private let read: () -> Float
    private let fire: () -> Void
    /// Called when the repeater stops itself because the input dropped below threshold.
    var onIdle: (() -> Void)?

    init(threshold: Float, slow: TimeInterval, fast: TimeInterval,
         read: @escaping () -> Float, fire: @escaping () -> Void) {
        self.threshold = threshold
        self.slow = slow
        self.fast = fast
        self.read = read
        self.fire = fire
    }

    var isRunning: Bool { timer != nil }

    /// Rising edge: begin repeating (first tick after one interval).
    func start() {
        guard timer == nil else { return }
        schedule(interval(for: read()))
    }

    /// Falling edge: stop repeating.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // Linear ramp: just-above-threshold -> slow, full press -> fast.
    private func interval(for value: Float) -> TimeInterval {
        let norm = min(1.0, max(0.0, (value - threshold) / (1.0 - threshold)))
        return slow - Double(norm) * (slow - fast)
    }

    private func schedule(_ t: TimeInterval) {
        let newTimer = Timer(timeInterval: t, repeats: false) { [weak self] _ in
            guard let self else { return }
            let v = self.read()
            if v > self.threshold {
                self.fire()
                self.schedule(self.interval(for: v))
            } else {
                self.timer = nil
                self.onIdle?()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
}