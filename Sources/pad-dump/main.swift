// pad-dump — Phase 0 feasibility spike (GameController framework).
//
// Enumerates connected game controllers, prints identity + full named-input
// state, and streams live changes. Confirms the Cosmic Byte Blitz (Xbox-
// protocol over Bluetooth) is readable, and captures its inputs so we can build
// an accurate default media map.
//
// Why GameController and not raw IOHID? Recent macOS SDKs removed the classic
// IOHID value/keys API (IOHIDValueGetValue, kIOHIDDeviceKey*, etc.), which
// breaks most tutorials and wrapper libs. GameController is Apple's modern,
// high-level gamepad API and maps XInput-style pads to named inputs.
//
// Usage:
//   pad-dump [--duration <seconds>]      (default 90)

import Foundation
import GameController
import AppKit

// Print the full named-input state of an extended gamepad on one line.
func printGamepad(_ gp: GCExtendedGamepad) {
    func b(_ x: Bool) -> String { x ? "1" : "0" }
    func t(_ x: Float) -> String { String(format: "%.2f", x) }
    let dpad = gp.dpad
    let ls = gp.leftThumbstick
    let rs = gp.rightThumbstick
    let line =
      "A=" + b(gp.buttonA.isPressed) +
      " B=" + b(gp.buttonB.isPressed) +
      " X=" + b(gp.buttonX.isPressed) +
      " Y=" + b(gp.buttonY.isPressed) +
      " Menu=" + b(gp.buttonMenu.isPressed) +
      " LS=" + b(gp.leftShoulder.isPressed) +
      " RS=" + b(gp.rightShoulder.isPressed) +
      " LT=" + t(gp.leftTrigger.value) +
      " RT=" + t(gp.rightTrigger.value) +
      "  | Dpad u=" + b(dpad.up.isPressed) +
      " d=" + b(dpad.down.isPressed) +
      " l=" + b(dpad.left.isPressed) +
      " r=" + b(dpad.right.isPressed) +
      " (" + t(dpad.xAxis.value) + "," + t(dpad.yAxis.value) + ")" +
      "  | LStick(" + t(ls.xAxis.value) + "," + t(ls.yAxis.value) +
      ") RStick(" + t(rs.xAxis.value) + "," + t(rs.yAxis.value) + ")"
    print(line)
}

// Describe a controller: identity + wire up a live value handler.
func describe(_ c: GCController) {
    let vendor = c.vendorName ?? "(nil)"
    let cat = c.productCategory
    print("[connect] vendorName='\(vendor)' productCategory='\(cat)' extendedGamepad=" + (c.extendedGamepad != nil ? "yes" : "no"))
    guard let gp = c.extendedGamepad else {
        print("  (no GCExtendedGamepad — inputs not mapped to the XInput layout)")
        return
    }
    printGamepad(gp)
    gp.valueChangedHandler = { changed, _ in
        printGamepad(changed)
    }
}

func printControllers() {
    let cs = GCController.controllers()
    print("=== connected controllers: \(cs.count) ===")
    for (idx, c) in cs.enumerated() {
        print("  [\(idx)] vendorName='\(c.vendorName ?? "-")' productCategory='\(c.productCategory)' extendedGamepad=" + (c.extendedGamepad != nil ? "yes" : "no"))
    }
    for c in cs { describe(c) }
    print("")
}

// ---- arg parsing ----
var args = Array(CommandLine.arguments.dropFirst())
var duration = 90.0
var i = 0
while i < args.count {
    switch args[i] {
    case "--duration":
        i += 1; duration = (i < args.count) ? (Double(args[i]) ?? 90.0) : 90.0
    case "--help", "-h":
        print("usage: pad-dump [--duration <seconds>]")
        exit(0)
    default:
        break
    }
    i += 1
}

// ---- main ----
// Unbuffer stdout: when redirected to a file, Swift's print() is block-
// buffered and output is only visible on process exit.
setvbuf(stdout, nil, _IONBF, 0)
print("pad-dump (GameController). Watching for controllers...")
print("Connect the gamepad via Bluetooth, then press buttons / move sticks.\n")

let obsConnect = NotificationCenter.default.addObserver(
    forName: Notification.Name.GCControllerDidConnect, object: nil, queue: .main
) { note in
    if let c = note.object as? GCController {
        print("\n>>> CONTROLLER CONNECTED")
        describe(c)
    }
}
let obsDisconnect = NotificationCenter.default.addObserver(
    forName: Notification.Name.GCControllerDidDisconnect, object: nil, queue: .main
) { note in
    if let c = note.object as? GCController {
        print("\n>>> CONTROLLER DISCONNECTED: \(c.vendorName ?? "-")")
    }
}

printControllers()

let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault,
    CFAbsoluteTimeGetCurrent() + duration, 0, 0, 0,
    { _ in
        print("\n=== timeout, exiting ===")
        CFRunLoopStop(CFRunLoopGetMain())
    })
CFRunLoopAddTimer(CFRunLoopGetMain(), timer, .defaultMode)

// --appkit accessory|default: run under NSApplication instead of bare CFRunLoop
// (probe for process-context effects on GameController delivery).
if let mi = CommandLine.arguments.firstIndex(of: "--appkit") {
    let mode = mi + 1 < CommandLine.arguments.count ? CommandLine.arguments[mi + 1] : "default"
    let app = NSApplication.shared
    if mode == "accessory" { app.setActivationPolicy(.accessory) }
    print("running under NSApplication mode=\(mode)")
    app.run()
} else {
    CFRunLoopRun()
}
print("done.")
_ = obsConnect
_ = obsDisconnect
