// ToggleMenuItem.swift — a menu row with a label and a pill switch (see ADR-017).
// Used as NSMenuItem.view, so clicking it does not close the menu.
//
// NSSwitch is not used: menu windows are never key, so NSSwitch always renders
// in its inactive (grey) look. PillSwitch draws the active accent colour itself.

import AppKit

final class PillSwitch: NSView {
    var isOn = false { didSet { refresh() } }
    private let track = CALayer()
    private let knob = CALayer()

    override var intrinsicContentSize: NSSize { NSSize(width: 34, height: 20) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(track)
        layer?.addSublayer(knob)
        knob.backgroundColor = NSColor.white.cgColor
        knob.shadowOpacity = 0.35
        knob.shadowRadius = 1
        knob.shadowOffset = CGSize(width: 0, height: -0.5)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func layout() {
        super.layout()
        refresh()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }

    private func refresh() {
        let h = bounds.height, w = bounds.width
        let pad: CGFloat = 2
        let d = h - 2 * pad
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        track.frame = bounds
        track.cornerRadius = h / 2
        knob.frame = NSRect(x: isOn ? w - pad - d : pad, y: pad, width: d, height: d)
        knob.cornerRadius = d / 2
        effectiveAppearance.performAsCurrentDrawingAppearance {
            track.backgroundColor = isOn
                ? NSColor.controlAccentColor.cgColor
                : NSColor.tertiaryLabelColor.cgColor
        }
        CATransaction.commit()
    }
}

final class ToggleMenuItemView: NSView {
    private let label: NSTextField
    private let pill = PillSwitch()
    private let onChange: (Bool) -> Void

    var isOn: Bool {
        get { pill.isOn }
        set {
            pill.isOn = newValue
            setAccessibilityValue(newValue ? "on" : "off")
        }
    }

    init(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        self.label = NSTextField(labelWithString: title)
        self.onChange = onChange
        // Standard menu row height; width is resized to the menu by the menu.
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
        autoresizingMask = [.width]

        label.font = .menuFont(ofSize: 0)
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        addSubview(pill)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            pill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.widthAnchor.constraint(equalToConstant: 34),
            pill.heightAnchor.constraint(equalToConstant: 20)
        ])

        setAccessibilityRole(.checkBox)
        setAccessibilityLabel(title)
        self.isOn = isOn
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // Whole row is the hit target.
    override func mouseDown(with event: NSEvent) {
        flip()
    }

    override func accessibilityPerformPress() -> Bool {
        flip()
        return true
    }

    private func flip() {
        isOn.toggle()
        onChange(isOn)
    }
}
