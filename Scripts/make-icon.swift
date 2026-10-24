// make-icon.swift - draws Resources/AppIcon.icns (gradient squircle + white gamepad glyph).
//   swift Scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let size = CGFloat(px)
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let inset = size * 0.1
    let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let bg = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.98, green: 0.45, blue: 0.30, alpha: 1),
                        NSColor(red: 0.55, green: 0.20, blue: 0.55, alpha: 1)])!
        .draw(in: bg, angle: -60)
    let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let s = sym.size
        sym.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height))
    }
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let set = "Resources/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: set)
try! FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base)@2x.png"))
}
