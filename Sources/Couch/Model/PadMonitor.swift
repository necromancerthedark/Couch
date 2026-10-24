// PadMonitor.swift — observable snapshot of the pad for the Controller tab.
// MediaController feeds it, but only while a window is watching, so the
// menu-bar app does no extra work when the window is closed (ADR-020).

import Foundation
import GameController

struct Vec2: Equatable {
    var x: Float = 0
    var y: Float = 0
}

struct PadSnapshot: Equatable {
    var pressed: Set<InputID> = []
    var lt: Float = 0
    var rt: Float = 0
    var ls = Vec2()
    var rs = Vec2()
}

struct DeviceInfo: Equatable {
    var name: String
    var category: String
    var battery: String
    var haptics: Bool
    var light: Bool
}

final class PadMonitor: ObservableObject {
    @Published private(set) var snapshot = PadSnapshot()
    @Published private(set) var device: DeviceInfo?

    private(set) var observed = false
    private weak var controller: GCController?
    private var lastBatteryRead = Date.distantPast

    func setDevice(_ c: GCController?) {
        controller = c
        device = c.map(Self.info(for:))
        if c == nil { snapshot = PadSnapshot() }
    }

    /// Window opened or closed. On open, pull the current state immediately.
    func setObserved(_ on: Bool) {
        observed = on
        guard on else { return }
        if let c = controller {
            device = Self.info(for: c)
            if let gp = c.extendedGamepad { update(gp: gp) }
        }
    }

    func update(gp: GCExtendedGamepad) {
        guard observed else { return }
        var s = PadSnapshot()
        for id in InputID.allCases where Mapping.value(id: id, gp: gp) { s.pressed.insert(id) }
        s.lt = gp.leftTrigger.value
        s.rt = gp.rightTrigger.value
        s.ls = Vec2(x: gp.leftThumbstick.xAxis.value, y: gp.leftThumbstick.yAxis.value)
        s.rs = Vec2(x: gp.rightThumbstick.xAxis.value, y: gp.rightThumbstick.yAxis.value)
        if s != snapshot { snapshot = s }
        if Date().timeIntervalSince(lastBatteryRead) > 5, let c = controller {
            lastBatteryRead = Date()
            let info = Self.info(for: c)
            if info != device { device = info }
        }
    }

    /// Demo data for screenshots (no pad needed).
    func loadDemo() {
        snapshot = PadSnapshot(pressed: [.a, .rightShoulder], lt: 0.55, rt: 0,
                               ls: Vec2(x: -0.12, y: 0.74), rs: Vec2())
        device = DeviceInfo(name: "Xbox Bluetooth Gamepad", category: "Xbox One",
                            battery: "78% · discharging", haptics: false, light: false)
    }

    private static func info(for c: GCController) -> DeviceInfo {
        var battery = "Not reported"
        if let b = c.battery {
            let pct = Int((b.batteryLevel * 100).rounded())
            let state: String
            switch b.batteryState {
            case .charging: state = "charging"
            case .full: state = "full"
            case .discharging: state = "discharging"
            default: state = "unknown"
            }
            battery = "\(pct)% · \(state)"
        }
        return DeviceInfo(
            name: (c.vendorName ?? "Gamepad").trimmingCharacters(in: .whitespaces),
            category: c.productCategory,
            battery: battery,
            haptics: c.haptics != nil,
            light: c.light != nil)
    }
}
