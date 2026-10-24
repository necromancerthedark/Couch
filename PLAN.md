# Controller → Mac Media Remote (Video Playback Focus)

## 1. Goal

Use a Bluetooth gamepad (Cosmic Byte Blitz, which macOS reports as an
Xbox-compatible controller) to control the Mac. Primary use: **video playback
control** (play/pause, seek, volume, next/prev, back) targeting **IINA** and
**YouTube/browser**. No mouse-cursor control.

## 2. Decisions (locked)

| # | Decision | Choice |
|---|---|---|
| 1 | Output scope | **(a) media remote only** (keys + media keys, no cursor) |
| 2 | Target players | **IINA** + **YouTube/browser** |
| 3 | Mapping | **Fixed** preset (no rebind UI) |
| 4 | App form | **Menu-bar** background app |
| 5 | Stack | **Swift** + **GameController** framework for input (see §3) |
| 6 | Build | **SwiftPM** + thin `.app` bundle |
| 7 | Distribution | **Run locally**, ad-hoc signed |

## 3. Key Technical Findings (from Phase 0)

- **macOS has no XInput.** The "Xbox" pad is a standard HID gamepad.
- **The classic raw IOHID API is gone in recent SDKs.** On the current macOS 26
  SDK, `IOHIDValueGetValue`, `IOHIDValueGetUsage`, `kIOHIDDeviceKey*`, and
  `IOHIDManagerRegisterDeviceCallback` have been **removed**. This breaks most
  tutorials and wrapper libraries (e.g. Gadget will not compile).
- **Use the GameController framework instead.** Apple's modern, high-level
  gamepad API. It maps XInput-style pads to a `GCExtendedGamepad` with **named,
  normalized inputs** (`buttonA/B/X/Y`, `dpad`, `leftThumbstick`,
  `rightThumbstick`, `leftShoulder`, `rightShoulder`, `leftTrigger`,
  `rightTrigger`) and a single `valueChangedHandler`. Far less code than raw
  HID, and it handles the Xbox mapping for us.
  - SDK note: identity props moved/trimmed — use `GCController.vendorName` and
    `.productCategory` (from the `GCDevice` base). `vendorID`/`productID`/
    `localizationName`/`isConnected` are not present in this SDK.
  - Enumerate via `GCController.controllers()` (class method) and observe
    `GCControllerDidConnectNotification` /
    `GCControllerDidDisconnectNotification`.
- **Reading a controller does NOT require any TCC permission** (verified: the
  spike runs with no prompt). Only the *output* layer (posting `CGEvent`s) will
  need **Accessibility**.
- **Spike built & validated:** `pad-dump` (SwiftPM executable) enumerates
  controllers and streams full named-input state. It compiles and runs clean on
  this SDK (shows 0 controllers until the pad is connected).

## 4. Conceptual Architecture

```
┌────────────────┐  named inputs  ┌────────────┐  actions    ┌─────────────┐
│ GameController │───────────────▶│  Mapping   │────────────▶│   Output    │
│ (GCController) │ A/B/X/Y, dpad,  │ (fixed     │ play, seek, │ (CGEvent)   │
│  extendedGamepad│ sticks, trig    │ preset)    │ vol, next   │ media keys  │
└────────────────┘                └────────────┘             │ + keyboard   │
       ▲                                                     └─────────────┘
       │ connect/disconnect notifications                          ▲
┌────────────────┐                                            needs
│  App shell     │◀───────────────┐                      Accessibility
│   (menu bar)   │                │                          grant
└────────────────┘            ┌───┴────────┐
                              │  Settings  │
                              │  (prefs)   │
                              └────────────┘
```

- **Input layer** — GameController: observe connect/disconnect, read the
  `GCExtendedGamepad` named inputs, apply deadzone to sticks/triggers.
- **Mapping layer** — fixed preset mapping inputs → semantic actions
  (`PlayPause`, `SeekForward`, `SeekBack`, `VolUp`, `VolDown`, `Next`, `Prev`,
  `Mute`, `Back`).
- **Output layer** — realize actions as `CGEvent`s: **media keys** (play/pause
  `0xF88B`, next `0xF88E`, prev `0xF88F`, vol up/down `0xF887`/`0xF888`,
  mute `0xF8A2`) + **regular keys** (arrows, etc.). Requires Accessibility.
- **App shell** — menu-bar resident app, launch at login, Accessibility
  onboarding.

## 5. Default Fixed Mapping (proposed — covers IINA + YouTube)

| Controller input | Action | Event | IINA | YouTube |
|---|---|---|---|---|
| A | Play/Pause | media key `0xF88B` | ✓ | ✓ |
| D-pad Left / Right | Seek back / fwd | arrow keys `←`/`→` | ✓ | ✓ (5 s) |
| D-pad Up / Down | Volume up / down | arrow keys `↑`/`↓` (or media `0xF887`/`0xF888`) | ✓ | ✓ |
| B | Next track/video | media key `0xF88E` | ✓ | ✓ |
| X | Previous track/video | media key `0xF88F` | ✓ | ✓ |
| Menu | Mute | media key `0xF8A2` | ✓ | ✓ |

Media keys are the most universal — they work across IINA, browsers, and other
players, so the fixed preset centers on them with arrow keys for seek/volume.
Final key choices are yours to tweak in code (single constant table).

## 6. Phased Roadmap

### Phase 0 — Feasibility Spike — **DONE**
- `pad-dump` built with GameController; compiles + runs clean, no permission
  needed.
- **Ran against the connected pad. Result:**
  - Identity: `vendorName='Xbox Bluetooth Gamepad '`, `productCategory='Xbox One'`.
  - **Maps to `GCExtendedGamepad`** (`extendedGamepad=yes`).
  - All inputs read + normalized: A/B/X/Y (0/1), D-pad (discrete + axis ±1.0),
    LS/RS (0/1), LT/RT (**analog** 0.0→1.0), both thumbsticks (±1.0, no drift).
  - Zero permission prompt to read.
- No workarounds needed. Proceed to Phase 1.

### Phase 1 — Input Layer
- Menu-bar app skeleton.
- GameController observation (connect/disconnect), read `GCExtendedGamepad`.
- Normalize: deadzone on sticks, edge detection on buttons (press vs hold).
- Handle multiple pads, reconnect.

### Phase 2 — Output Layer
- Post media keys + keyboard events via `CGEvent`.
- Prompt for / gate on Accessibility at first run.

### Phase 3 — Mapping (Fixed Preset)
- Encode the §5 preset as a constant table (input → action).
- Wire input edges → actions → output.
- Persist any user tweaks (speed/deadzone) to prefs.

### Phase 4 — Menu-bar Shell + Polish
- Menu: enable/disable, quit, "check permissions", about.
- Launch at login, app icon, Accessibility onboarding.
- Edge cases: no focused window, full-screen player, pad disconnect.

### Phase 5 — Distribution (local)
- Ad-hoc signed `.app` bundle; helper script to grant Accessibility; README.

## 7. Permissions Required

- **Accessibility** — required to post `CGEvent`s (output layer only).
  System Settings → Privacy & Security → Accessibility.
- **None needed to read the controller** (GameController) — verified.
- Bluetooth handled by the OS.

## 8. Risks / Open Questions

- Some apps ignore media keys → the preset already leans on media keys +
  arrow keys; verify IINA and YouTube both respond during Phase 2 testing.
- Stick → action velocity is subjective → keep a speed/deadzone pref.
- macOS may require re-granting Accessibility after OS updates.
- Confirm the Cosmic Byte Blitz exposes `GCExtendedGamepad` (XInput layout) vs
  only a generic `GCPhysicalInputProfile` — the pad-dump run will show this.

## 9. Proposed File Layout

```
Controller-mouse/
├─ PLAN.md
├─ Package.swift
├─ Sources/
│  ├─ pad-dump/          (Phase 0 spike — DONE)
│  └─ (later) Couch/  (menu-bar app: Input, Mapping, Output, App)
└─ Resources/           (icons, menu)
```

## 10. Next Step

Pad confirmed readable. **Scaffold the menu-bar app (Phase 1–3):**
GameController input layer → fixed mapping → `CGEvent` output (media keys +
arrows), with Accessibility onboarding. Key remaining choice: the exact §5
preset (or tweaks). Then build + test against IINA and YouTube.