// MediaController.swift — wires the GameController input layer to the fixed
// mapping and the CGEvent output layer (see ADR-001, ADR-009).

import GameController
import CoreGraphics
import ApplicationServices

final class MediaController {
    /// Remote switch (menu / Settings).
    var enabled = true
    /// False while the frontmost app is not allowed by the app filter (ADR-023).
    var appAllowed = true
    /// Couch acts only when the Remote switch is on and the frontmost app is allowed.
    private var isActive: Bool { enabled && appAllowed }
    var onControllerChange: ((String?) -> Void)?
    /// Receives pad state for the Controller tab (only used while observed).
    weak var monitor: PadMonitor?

    private let output = OutputLayer()
    private var controller: GCController?
    private var observers: [NSObjectProtocol] = []
    private var prevState: [InputID: Bool] = [:]
    private var ltSeek: AdaptiveRepeater!
    private var rtSeek: AdaptiveRepeater!
    private var volUpRep: AdaptiveRepeater!
    private var volDownRep: AdaptiveRepeater!
    private var stickDeadzone: Float = Mapping.stickDeadzone
    private var volUpHeld = false
    private var volDownHeld = false
    private var pollTimer: Timer?
    private var triggerThreshold: Float = Mapping.triggerThreshold
    private var ltHeld = false
    private var rtHeld = false
    private var lastLoggedState = ""

    // MARK: Accessibility (needed to post events — ADR-009)

    func ensureAccessibility(prompt: Bool = false) {
        let trusted = AXIsProcessTrusted()
        DebugLog.log("accessibility: trusted=\(trusted) prompt=\(prompt)")
        if trusted { return }
        if prompt {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        }
    }

    // MARK: Lifecycle

    func start(config cfg: Config.Values) {
        // Menu-bar agent is never frontmost; without this GameController
        // delivers no input to a background process.
        GCController.shouldMonitorBackgroundEvents = true
        DebugLog.log("start: controllers=\(GCController.controllers().count)")
        buildRepeaters(cfg)

        if let first = GCController.controllers().first { attach(first) }

        observers = [
            NotificationCenter.default.addObserver(
                forName: Notification.Name.GCControllerDidConnect, object: nil, queue: .main
            ) { [weak self] note in
                guard let self, let c = note.object as? GCController else { return }
                if self.controller == nil { self.attach(c) }
            },
            NotificationCenter.default.addObserver(
                forName: Notification.Name.GCControllerDidDisconnect, object: nil, queue: .main
            ) { [weak self] note in
                if let c = note.object as? GCController { self?.detach(c) }
            }
        ]

        // Fallback poll (20Hz): keeps state fresh even if valueChangedHandler
        // stalls. Edge detection makes it safe: no double fires, no repeats.
        let poll = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let gp = self.controller?.extendedGamepad else { return }
            self.handle(gp: gp)
        }
        pollTimer = poll
        RunLoop.main.add(poll, forMode: .common)
    }

    /// Apply new tuning values live (Settings window). Stops anything running
    /// and clears held flags, as on attach, so no repeat outlives its settings.
    func reconfigure(_ cfg: Config.Values) {
        guard ltSeek != nil else { return }
        stopAllRepeaters()
        ltHeld = false
        rtHeld = false
        volUpHeld = false
        volDownHeld = false
        buildRepeaters(cfg)
        DebugLog.log("settings: applied live")
    }

    /// Fire an action as if the pad did (Debug tab action tester).
    func perform(_ action: MediaAction) {
        output.perform(action)
    }

    private func buildRepeaters(_ cfg: Config.Values) {
        triggerThreshold = cfg.triggerThreshold
        stickDeadzone = cfg.stickDeadzone
        ltSeek = AdaptiveRepeater(
            threshold: cfg.triggerThreshold,
            slow: cfg.seekSlow,
            fast: cfg.seekFast,
            read: { [weak self] in self?.controller?.extendedGamepad?.leftTrigger.value ?? 0 },
            fire: { [weak self] in
                guard let self, self.isActive else { return }
                self.output.perform(.seekBack)
            }
        )
        rtSeek = AdaptiveRepeater(
            threshold: cfg.triggerThreshold,
            slow: cfg.seekSlow,
            fast: cfg.seekFast,
            read: { [weak self] in self?.controller?.extendedGamepad?.rightTrigger.value ?? 0 },
            fire: { [weak self] in
                guard let self, self.isActive else { return }
                self.output.perform(.seekForward)
            }
        )
        // Left stick Y = player volume: repeats while pushed, faster when further.
        volUpRep = AdaptiveRepeater(
            threshold: cfg.stickDeadzone, slow: cfg.volumeSlow, fast: cfg.volumeFast,
            read: { [weak self] in max(0, self?.controller?.extendedGamepad?.leftThumbstick.yAxis.value ?? 0) },
            fire: { [weak self] in
                guard let self, self.isActive else { return }
                self.output.perform(.playerVolUp)
            }
        )
        volDownRep = AdaptiveRepeater(
            threshold: cfg.stickDeadzone, slow: cfg.volumeSlow, fast: cfg.volumeFast,
            read: { [weak self] in max(0, -(self?.controller?.extendedGamepad?.leftThumbstick.yAxis.value ?? 0)) },
            fire: { [weak self] in
                guard let self, self.isActive else { return }
                self.output.perform(.playerVolDown)
            }
        )
        volUpRep.onIdle = { [weak self] in self?.volUpHeld = false }
        volDownRep.onIdle = { [weak self] in self?.volDownHeld = false }
        ltSeek.onIdle = { [weak self] in self?.ltHeld = false }
        rtSeek.onIdle = { [weak self] in self?.rtHeld = false }
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
        stopAllRepeaters()
    }

    private func stopAllRepeaters() {
        ltSeek?.stop()
        rtSeek?.stop()
        volUpRep?.stop()
        volDownRep?.stop()
    }

    private func attach(_ c: GCController) {
        DebugLog.log("attach: vendorName='\(c.vendorName ?? "-")' productCategory='\(c.productCategory)' extendedGamepad=\(c.extendedGamepad != nil)")
        // Not an extended gamepad: nothing we can map, so don't show it as live.
        guard let gp = c.extendedGamepad else { return }
        controller = c
        monitor?.setDevice(c)
        onControllerChange?(c.vendorName?.trimmingCharacters(in: .whitespaces) ?? "Gamepad")
        stopAllRepeaters()
        ltHeld = false
        rtHeld = false
        volUpHeld = false
        volDownHeld = false
        // Prime the framework: read full state ONCE before setting the handler.
        // GameController only starts updating an input after its first access
        // (pad-dump did exactly this; without it valueChangedHandler never fires).
        logState(gp: gp)
        gp.valueChangedHandler = { [weak self] gamepad, _ in
            self?.handle(gp: gamepad)
        }
        prevState.removeAll()
    }

    private func detach(_ c: GCController) {
        if controller === c {
            DebugLog.log("detach: vendorName='\(c.vendorName ?? "-")'")
            c.extendedGamepad?.valueChangedHandler = nil
            controller = nil
            monitor?.setDevice(nil)
            stopAllRepeaters()
            ltHeld = false
            rtHeld = false
            volUpHeld = false
            volDownHeld = false
            prevState.removeAll()
            onControllerChange?(nil)
            // Another pad still connected? Take it over.
            if let other = GCController.controllers().first(where: { $0 !== c && $0.extendedGamepad != nil }) {
                attach(other)
            }
        }
    }

    // MARK: Input handling

    private func handle(gp: GCExtendedGamepad) {
        logState(gp: gp)
        monitor?.update(gp: gp)
        guard isActive else {
            // Track state without acting, so a button held or released while
            // paused (Remote off, or an unlisted app in front) does not fire a
            // bogus edge when Couch becomes active again.
            stopAllRepeaters()
            ltHeld = gp.leftTrigger.value > triggerThreshold
            rtHeld = gp.rightTrigger.value > triggerThreshold
            let y = gp.leftThumbstick.yAxis.value
            volUpHeld = y > stickDeadzone
            volDownHeld = y < -stickDeadzone
            for (id, _) in Mapping.edgeTable { prevState[id] = Mapping.value(id: id, gp: gp) }
            return
        }
        handleEdges(gp: gp)
        handleTriggers(gp: gp)
        handleStick(gp: gp)
    }

    // Triggers: start/stop hold-to-seek on press/release edges.
    private func handleTriggers(gp: GCExtendedGamepad) {
        let t = triggerThreshold
        let lh = gp.leftTrigger.value > t
        if lh { if !ltHeld { ltSeek.start() } } else if ltHeld { ltSeek.stop() }
        ltHeld = lh
        let rh = gp.rightTrigger.value > t
        if rh { if !rtHeld { rtSeek.start() } } else if rtHeld { rtSeek.stop() }
        rtHeld = rh
    }

    // Left stick Y: step immediately on the push, then repeat while held.
    private func handleStick(gp: GCExtendedGamepad) {
        let y = gp.leftThumbstick.yAxis.value
        let up = y > stickDeadzone
        if up {
            if !volUpHeld { output.perform(.playerVolUp); volUpRep.start() }
        } else if volUpHeld { volUpRep.stop() }
        volUpHeld = up
        let down = y < -stickDeadzone
        if down {
            if !volDownHeld { output.perform(.playerVolDown); volDownRep.start() }
        } else if volDownHeld { volDownRep.stop() }
        volDownHeld = down
    }

    // Log full input state, only when it changes.
    private func logState(gp: GCExtendedGamepad) {
        func b(_ x: Bool) -> String { x ? "1" : "0" }
        func t(_ x: Float) -> String { String(format: "%.2f", x) }
        let s = "A=" + b(gp.buttonA.isPressed) +
                " B=" + b(gp.buttonB.isPressed) +
                " X=" + b(gp.buttonX.isPressed) +
                " Y=" + b(gp.buttonY.isPressed) +
                " Menu=" + b(gp.buttonMenu.isPressed) +
                " LS=" + b(gp.leftShoulder.isPressed) +
                " RS=" + b(gp.rightShoulder.isPressed) +
                " LT=" + t(gp.leftTrigger.value) +
                " RT=" + t(gp.rightTrigger.value) +
                " Dpad u=" + b(gp.dpad.up.isPressed) +
                " d=" + b(gp.dpad.down.isPressed) +
                " l=" + b(gp.dpad.left.isPressed) +
                " r=" + b(gp.dpad.right.isPressed) +
                " (" + t(gp.dpad.xAxis.value) + "," + t(gp.dpad.yAxis.value) + ")" +
                " LStick(" + t(gp.leftThumbstick.xAxis.value) + "," + t(gp.leftThumbstick.yAxis.value) + ")" +
                " RStick(" + t(gp.rightThumbstick.xAxis.value) + "," + t(gp.rightThumbstick.yAxis.value) + ")"
        if s != lastLoggedState {
            lastLoggedState = s
            DebugLog.log("input: \(s)")
        }
    }

    // Fire each mapped input once on press (rising edge).
    private func handleEdges(gp: GCExtendedGamepad) {
        for (id, action) in Mapping.edgeTable {
            let pressed = Mapping.value(id: id, gp: gp)
            let was = prevState[id] ?? false
            if pressed && !was {
                DebugLog.log("fire: \(action) trusted=\(AXIsProcessTrusted())")
                output.perform(action)
            }
            prevState[id] = pressed
        }
    }
}