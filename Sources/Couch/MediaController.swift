// MediaController.swift — wires the GameController input layer to the fixed
// mapping and the CGEvent output layer (see ADR-001, ADR-009).

import GameController
import CoreGraphics
import ApplicationServices

final class MediaController {
    var enabled = true
    var onStateChange: ((Bool) -> Void)?
    var onControllerChange: ((String?) -> Void)?

    private let output = OutputLayer()
    private var controller: GCController?
    private var observers: [NSObjectProtocol] = []
    private var prevState: [InputID: Bool] = [:]
    private var ltSeek: AdaptiveRepeater!
    private var rtSeek: AdaptiveRepeater!
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

    func start() {
        // Menu-bar agent is never frontmost; without this GameController
        // delivers no input to a background process.
        GCController.shouldMonitorBackgroundEvents = true
        DebugLog.log("start: controllers=\(GCController.controllers().count)")
        let cfg = Config.load()
        triggerThreshold = cfg.triggerThreshold
        ltSeek = AdaptiveRepeater(
            threshold: cfg.triggerThreshold,
            slow: cfg.seekSlow,
            fast: cfg.seekFast,
            read: { [weak self] in self?.controller?.extendedGamepad?.leftTrigger.value ?? 0 },
            fire: { [weak self] in
                guard let self, self.enabled else { return }
                self.output.perform(.seekBack)
            }
        )
        rtSeek = AdaptiveRepeater(
            threshold: cfg.triggerThreshold,
            slow: cfg.seekSlow,
            fast: cfg.seekFast,
            read: { [weak self] in self?.controller?.extendedGamepad?.rightTrigger.value ?? 0 },
            fire: { [weak self] in
                guard let self, self.enabled else { return }
                self.output.perform(.seekForward)
            }
        )

        for c in GCController.controllers() { attach(c) }

        observers = [
            NotificationCenter.default.addObserver(
                forName: Notification.Name.GCControllerDidConnect, object: nil, queue: .main
            ) { [weak self] note in
                if let c = note.object as? GCController { self?.attach(c) }
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

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
        ltSeek?.stop()
        rtSeek?.stop()
    }

    private func attach(_ c: GCController) {
        DebugLog.log("attach: vendorName='\(c.vendorName ?? "-")' productCategory='\(c.productCategory)' extendedGamepad=\(c.extendedGamepad != nil)")
        controller = c
        onControllerChange?(c.vendorName?.trimmingCharacters(in: .whitespaces) ?? "Gamepad")
        guard let gp = c.extendedGamepad else { return }
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
            controller = nil
            ltSeek?.stop()
            rtSeek?.stop()
            ltHeld = false
            rtHeld = false
            prevState.removeAll()
            onControllerChange?(nil)
            // Another pad still connected? Take it over.
            if let other = GCController.controllers().first(where: { $0 !== c }) { attach(other) }
        }
    }

    // MARK: Input handling

    private func handle(gp: GCExtendedGamepad) {
        logState(gp: gp)
        guard enabled else {
            ltSeek.stop()
            rtSeek.stop()
            ltHeld = false
            rtHeld = false
            return
        }
        handleEdges(gp: gp)
        handleTriggers(gp: gp)
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