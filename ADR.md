# Architecture Decision Records (ADR)

Log of decisions for the **Couch** project (controller → Mac media
remote). Each record: context → decision → consequences. Status: **Accepted**
unless noted.

---

## ADR-001 — Use GameController framework for input (not raw IOHID)

- **Status:** Accepted
- **Phase:** 0
- **Context:** The pad (Cosmic Byte Blitz) reports as an Xbox controller. The
  original plan targeted raw `IOHIDManager`. On the current macOS 26 SDK the
  classic IOHID API is **removed** (`IOHIDValueGetValue`,
  `IOHIDValueGetUsage`, `kIOHIDDeviceKey*`,
  `IOHIDManagerRegisterDeviceCallback` are gone). This breaks most tutorials and
  wrapper libraries (e.g. Gadget won't compile). The lower-level IOHID API that
  remains is element-based and awkward.
- **Decision:** Use Apple's **GameController** framework. It maps XInput-style
  pads to `GCExtendedGamepad` with named, normalized inputs and a single
  `valueChangedHandler`.
- **Consequences:**
  - (+) Far less code; Xbox mapping handled by the framework; normalized
    values (axes -1…1, triggers 0…1, buttons 0/1).
  - (+) **Reading a controller needs no TCC permission** (verified in Phase 0).
  - (−) Some identity props were trimmed in this SDK (`vendorID`, `productID`,
    `localizationName`, `isConnected` are absent) — use `vendorName` +
    `productCategory` from the `GCDevice` base instead.
  - (−) SDK-specific: relies on a modern SDK; would need re-checking on older
    macOS if ever targeted.

## ADR-002 — Scope is a media remote only (no mouse cursor)

- **Status:** Accepted
- **Phase:** planning (user decision #1)
- **Context:** The user primarily wants to control video playback. True
  mouse-cursor control was secondary.
- **Decision:** Output = media keys + keyboard only. No cursor/click synthesis.
- **Consequences:** Simpler output layer (no velocity tuning, no click
  injection). Cursor control can be added later as an opt-in mode if wanted.

## ADR-003 — Target players: IINA + YouTube/browser

- **Status:** Accepted
- **Phase:** planning (user decision #2)
- **Context:** The two main playback targets.
- **Decision:** Design the preset so it works in both. Lean on **media keys**
  (most universal) plus **arrow keys** for seek/volume.
- **Consequences:** Both IINA and browsers respond to play/pause, next/prev
  media keys and arrow keys, so one preset covers both. Other players (VLC,
  mpv) largely work too.

## ADR-004 — Fixed mapping (no rebind UI)

- **Status:** Accepted
- **Phase:** planning (user decision #3)
- **Context:** Rebinding UI is extra work; the user wants a sensible fixed
  preset first.
- **Decision:** Encode the preset as a single constant table in
  `Mapping.swift`. No user-facing rebind UI.
- **Consequences:** (+) Minimal UI, faster to ship. (−) Changes require a code
  edit + rebuild (acceptable for a personal tool). A rebind UI is a future
  option.

## ADR-005 — Menu-bar background app

- **Status:** Accepted
- **Phase:** planning (user decision #4)
- **Context:** A utility that should run quietly in the background.
- **Decision:** Menu-bar (status item) agent app, launch at login, no Dock
  icon (`LSUIElement` + `.accessory` activation policy).
- **Consequences:** Always available, out of the way. Menu offers on/off,
  permission check, quit.

## ADR-006 — Swift + SwiftPM + thin .app bundle

- **Status:** Accepted
- **Phase:** planning (user decision #5/#6)
- **Context:** Native macOS tool; no cross-platform need.
- **Decision:** Swift. Build with SwiftPM; package the executable into a
  minimal `.app` bundle (`Scripts/build-app.sh`) so it behaves as a proper
  agent app.
- **Consequences:** (+) No Xcode project needed; fast builds; easy to script.
  (−) Menu-bar + TCC behave best when bundled, so a packaging script is
  required (not just running the bare binary).

## ADR-007 — Ad-hoc signed, local-only distribution

- **Status:** Accepted
- **Phase:** planning (user decision #7)
- **Context:** Personal tool, run on the user's Mac.
- **Decision:** Ad-hoc sign the `.app`; no Developer ID, no notarization, no
  distribution.
- **Consequences:** (+) Zero setup. (−) After each rebuild the code signature
  changes, so macOS may require **re-granting Accessibility** (TCC keys the
  grant to the signature). Keep the binary stable for daily use, or re-add
  after rebuilds.

## ADR-008 — AppKit NSStatusItem for the menu bar (not SwiftUI MenuBarExtra)

- **Status:** Accepted
- **Phase:** 1
- **Context:** Need a reliable status-item menu inside a SwiftPM-built bundle.
- **Decision:** Use AppKit `NSApplication` + `NSStatusItem`.
- **Consequences:** (+) Most robust in a non-standard (SwiftPM) bundle; full
  control of the menu. (−) More boilerplate than SwiftUI; not using SwiftUI
  here (no rich UI needed).

## ADR-009 — Output via CGEvent (media keys + keyboard)

- **Status:** Accepted
- **Phase:** 2
- **Context:** Need to drive IINA/browser from the pad.
- **Decision:** Post synthetic events with `CGEvent` to `.cghidEventTap`.
  Media keys use `CGEventSource(.hidSystemState)`; regular keys (arrows) use
  `.combinedSessionState`.
- **Consequences:** (+) One mechanism covers media keys, seek, volume, and
  brightness. (−) Requires **Accessibility** permission (prompted on launch +
  a menu item to re-prompt).

## ADR-010 — Fixed preset key assignments

- **Status:** Accepted
- **Phase:** 3 (user approved)
- **Context:** Concrete mapping (see also PLAN.md §5).
- **Decision:**
  | Pad input | Action | Event |
  |---|---|---|
  | A | Play/Pause | media `0xF88B` |
  | D-pad ◄ / ► | Seek back / fwd | arrows `←`/`→` |
  | D-pad ▲ / ▼ | Volume up / down | arrows `↑`/`↓` |
  | B | Next track/video | media `0xF88E` |
  | X | Previous track/video | media `0xF88F` |
  | Menu | Mute | media `0xF8A2` |
  | LB (leftShoulder) | Brightness down | media `0xF8A0` |
  | RB (rightShoulder) | Brightness up | media `0xF8A1` |
- **Consequences:** Edge-triggered (fire on press). Defined once in
  `Mapping.edgeTable`.

## ADR-011 — Analog triggers → hold-to-seek

- **Status:** Accepted
- **Phase:** 3 (user approved)
- **Context:** Triggers are true analog (0…1). A natural use is scrubbing.
- **Decision:** LT = seek back, RT = seek forward. While held above a
  threshold (0.15), repeatedly send seek events; the repeat interval shrinks as
  the press deepens (0.50s → 0.08s), i.e. deeper = faster scrub. Implemented
  with an `AdaptiveRepeater` (self-rescheduling timer).
- **Consequences:** (+) Smooth scrubbing control. (−) Slightly more complex
  than edge-triggered actions; seek step size is whatever the target app does
  per arrow key (IINA ≈10s, YouTube ≈5s).

## ADR-012 — Shoulders → screen brightness

- **Status:** Accepted
- **Phase:** 3 (user request)
- **Context:** User asked whether LB/RB (recorded as LS/RS in the Phase 0
  capture) could toggle screen brightness.
- **Decision:** Yes — map LB → brightness down, RB → brightness up (swapped after hands-on test), posting
  media keys `0xF8A0` / `0xF8A1`.
- **Consequences:** (+) Reuses the media-key output path. (−) Caveat: these
  control **system display brightness** — works on the internal MacBook
  display; on an external-only monitor setup it may do nothing (external
  monitors often aren't software-controllable).

## ADR-013 — Background input needs `shouldMonitorBackgroundEvents`

- **Status:** Accepted
- **Phase:** 1 (blocker fix)
- **Context:** The packaged app attached the pad and read a primed state but
  never received value changes. A bare `pad-dump` CLI on the same pad did.
  Cause: GameController delivers input only to the **frontmost** app. A
  menu-bar `.accessory` agent is never frontmost. `pad-dump` only worked
  because its parent terminal was frontmost. Ruled out: bundle/LSUIElement,
  ad-hoc signature, TCC, `NSApplication` run loop, App Nap, stick priming.
- **Decision:** Set `GCController.shouldMonitorBackgroundEvents = true` in
  `MediaController.start()`.
- **Consequences:** Input flows while another app is frontmost. Verified:
  A/D-pad/B logged, mapped, and posted as CGEvents. `pad-dump` results are
  only valid when its host app is frontmost.

## ADR-014 — Runtime tuning via config.json

- **Status:** Accepted
- **Context:** Rebuilding `dist/` invalidates the Accessibility grant (ADR-007).
- **Decision:** `~/Library/Application Support/Couch/config.json`
  keys `triggerThreshold`, `seekSlow`, `seekFast` override defaults at launch.
- **Consequences:** Tune without rebuild, so the grant survives.

## ADR-015 — Media keys are NX system-defined events, not virtual keycodes

- **Status:** Accepted (supersedes the media-key part of ADR-009)
- **Context:** Posting `CGEvent` virtual keys `0xF88B` etc. is not a real
  media key. Seek/volume (arrows) worked, but play/pause, next and prev did
  nothing.
- **Decision:** Post `NSEvent.otherEvent(.systemDefined, subtype 8)` with
  `data1 = (keyType << 16) | (0xA00 down / 0xB00 up)` to `.cghidEventTap`.
  Types: play 16, next 17, prev 18, mute 7, brightness up 2 / down 3.
- **Consequences:** Verified by hand: A/B/X/Menu/LB/RB all work in a player.

---

## Phase status

| Phase | Name | Status |
|---|---|---|
| 0 | Feasibility spike (`pad-dump`) | ✅ Done — pad confirmed as `GCExtendedGamepad` |
| 1 | Input layer (GameController) | ✅ Done (ADR-013) |
| 2 | Output layer (CGEvent) | ✅ Done, media keys posting |
| 3 | Fixed mapping | ✅ Done |
| 4 | Menu-bar shell + polish | ✅ Dist app verified end to end |
| 5 | Local distribution | ⏳ |