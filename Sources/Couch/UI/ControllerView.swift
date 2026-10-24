// ControllerView.swift — drawn controller with the function of every input,
// live highlighting, and device details. Labels come from Mapping, so the map
// cannot drift from what the app actually does (ADR-020).

import SwiftUI

struct ControllerView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var pad: PadMonitor
    @State private var showFunctions = true

    init(model: AppModel) {
        self.model = model
        self.pad = model.pad
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PageTitle(text: "Controller")
                    Spacer()
                    Picker("Labels", selection: $showFunctions) {
                        Text("Functions").tag(true)
                        Text("Raw names").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 200)
                }

                ZStack {
                    ControllerDiagram(
                        snapshot: pad.snapshot,
                        deadzone: model.settings.values.stickDeadzone,
                        functions: showFunctions)
                        .opacity(pad.device == nil ? 0.35 : 1)
                    if pad.device == nil {
                        VStack(spacing: 4) {
                            Text("No controller").font(.headline)
                            Text("Press the Xbox button to wake the pad.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .frame(maxWidth: .infinity)

                DeviceDetails(device: pad.device, snapshot: pad.snapshot)
            }
            .padding(24)
        }
    }
}

// MARK: - Diagram

struct ControllerDiagram: View {
    let snapshot: PadSnapshot
    let deadzone: Float
    let functions: Bool

    private func on(_ id: InputID) -> Bool { snapshot.pressed.contains(id) }

    private func label(_ id: InputID, raw: String) -> String {
        functions ? (Mapping.function(for: id) ?? "Unmapped") : raw
    }

    var body: some View {
        ZStack {
            silhouette

            // Triggers and bumpers: bars with the label inside.
            bar("LT", functions ? "Scrub back" : "", fill: CGFloat(snapshot.lt), at: CGPoint(x: 160, y: 18), tall: true)
            bar("RT", functions ? "Scrub forward" : "", fill: CGFloat(snapshot.rt), at: CGPoint(x: 480, y: 18), tall: true)
            bar("LB", functions ? label(.leftShoulder, raw: "") : "",
                fill: on(.leftShoulder) ? 1 : 0, at: CGPoint(x: 160, y: 46), tall: false)
            bar("RB", functions ? label(.rightShoulder, raw: "") : "",
                fill: on(.rightShoulder) ? 1 : 0, at: CGPoint(x: 480, y: 46), tall: false)

            // Left stick (player volume), with the deadzone ring.
            stick(snapshot.ls, center: CGPoint(x: 175, y: 128), ring: true)
            caption(functions ? "Left stick: player volume" : "Left stick",
                    x: 175, y: 168, width: 150)

            // D-pad
            dpadCell(.dpadUp, CGPoint(x: 245, y: 206))
            dpadCell(.dpadDown, CGPoint(x: 245, y: 250))
            dpadCell(.dpadLeft, CGPoint(x: 223, y: 228))
            dpadCell(.dpadRight, CGPoint(x: 267, y: 228))
            caption(label(.dpadUp, raw: "D-pad ▲"), x: 245, y: 188, width: 110)
            caption(label(.dpadDown, raw: "D-pad ▼"), x: 245, y: 274, width: 110)
            caption(label(.dpadLeft, raw: "D-pad ◄"), x: 206, y: 228, width: 100, anchor: .trailing)
            caption(label(.dpadRight, raw: "D-pad ►"), x: 284, y: 228, width: 100, anchor: .leading)

            // Menu
            Capsule()
                .fill(on(.menu) ? Color.accentColor : Color.secondary.opacity(0.25))
                .frame(width: 38, height: 16)
                .position(x: 320, y: 135)
            caption(label(.menu, raw: "Menu"), x: 320, y: 156, width: 80)

            // Face buttons
            face(.y, "Y", CGPoint(x: 470, y: 118))
            face(.x, "X", CGPoint(x: 430, y: 150))
            face(.b, "B", CGPoint(x: 510, y: 150))
            face(.a, "A", CGPoint(x: 470, y: 182))
            caption(label(.y, raw: "Y"), x: 470, y: 94, width: 100)
            caption(label(.x, raw: "X"), x: 412, y: 150, width: 100, anchor: .trailing)
            caption(label(.b, raw: "B"), x: 528, y: 150, width: 100, anchor: .leading)
            caption(label(.a, raw: "A"), x: 470, y: 208, width: 100)

            // Right stick (unmapped)
            stick(snapshot.rs, center: CGPoint(x: 395, y: 235), ring: false)
            caption(functions ? "Right stick: unmapped" : "Right stick",
                    x: 395, y: 274, width: 150)
        }
        .frame(width: 640, height: 300)
    }

    // MARK: Pieces

    private var silhouette: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 90).frame(width: 440, height: 210).position(x: 320, y: 185)
        }
        .foregroundStyle(.primary)
        .compositingGroup()
        .opacity(0.07)
    }

    private func bar(_ raw: String, _ text: String, fill: CGFloat, at p: CGPoint, tall: Bool) -> some View {
        let h: CGFloat = tall ? 22 : 20
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.22))
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.85))
                    .frame(width: g.size.width * min(1, max(0, fill)))
            }
            Text(text.isEmpty ? raw : "\(raw)  \(text)")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
        }
        .frame(width: 150, height: h)
        .position(p)
    }

    private func face(_ id: InputID, _ raw: String, _ p: CGPoint) -> some View {
        let pressed = on(id)
        return Circle()
            .fill(pressed ? Color.accentColor : Color.secondary.opacity(0.25))
            .frame(width: 28, height: 28)
            .overlay(Text(raw).font(.system(size: 12, weight: .bold))
                .foregroundStyle(pressed ? Color.white : Color.primary))
            .position(p)
    }

    private func dpadCell(_ id: InputID, _ p: CGPoint) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(on(id) ? Color.accentColor : Color.secondary.opacity(0.25))
            .frame(width: 20, height: 20)
            .position(p)
    }

    private func stick(_ v: Vec2, center: CGPoint, ring: Bool) -> some View {
        let r: CGFloat = 30
        let past = ring && hypot(v.x, v.y) > deadzone
        return ZStack {
            Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1.5).frame(width: r * 2, height: r * 2)
            if ring {
                Circle()
                    .stroke(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: r * 2 * CGFloat(deadzone), height: r * 2 * CGFloat(deadzone))
            }
            Circle()
                .fill(past ? Color.accentColor : Color.secondary.opacity(0.6))
                .frame(width: 14, height: 14)
                .offset(x: CGFloat(v.x) * (r - 7), y: CGFloat(-v.y) * (r - 7))
        }
        .position(center)
    }

    private enum Anchor { case leading, trailing, center }

    private func caption(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
                         anchor: Anchor = .center) -> some View {
        let cx: CGFloat
        let align: Alignment
        switch anchor {
        case .leading: cx = x + width / 2; align = .leading
        case .trailing: cx = x - width / 2; align = .trailing
        case .center: cx = x; align = .center
        }
        return Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(width: width, alignment: align)
            .position(x: cx, y: y)
    }
}

// MARK: - Details

struct DeviceDetails: View {
    let device: DeviceInfo?
    let snapshot: PadSnapshot

    var body: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 6) {
                row("Name", device?.name ?? "—")
                row("Category", device?.category ?? "—")
                row("Battery", device?.battery ?? "—")
                row("Haptics", device.map { $0.haptics ? "Yes" : "No" } ?? "—")
                row("Light bar", device.map { $0.light ? "Yes" : "No" } ?? "—")
                Divider().gridCellUnsizedAxes(.horizontal)
                row("Triggers", String(format: "LT %.2f   RT %.2f", snapshot.lt, snapshot.rt))
                row("Left stick", String(format: "x %+.2f   y %+.2f", snapshot.ls.x, snapshot.ls.y))
                row("Right stick", String(format: "x %+.2f   y %+.2f", snapshot.rs.x, snapshot.rs.y))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Text("Details").font(.headline)
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }
}
