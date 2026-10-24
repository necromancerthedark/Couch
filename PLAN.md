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

### Phase 1 — Input Layer — **DONE**
- Menu-bar app skeleton.
- GameController observation (connect/disconnect), read `GCExtendedGamepad`.
- Normalize: deadzone on sticks, edge detection on buttons (press vs hold).
- Handle multiple pads, reconnect.

### Phase 2 — Output Layer — **DONE** (NX media keys, ADR-015)
- Post media keys + keyboard events via `CGEvent`.
- Prompt for / gate on Accessibility at first run.

### Phase 3 — Mapping (Fixed Preset) — **DONE**
- Encode the §5 preset as a constant table (input → action).
- Wire input edges → actions → output.
- Persist any user tweaks (speed/deadzone) to prefs.

### Phase 4 — Menu-bar Shell + Polish — **DONE**
- Menu: enable/disable, quit, "check permissions", about.
- Launch at login, app icon, Accessibility onboarding.
- Edge cases: no focused window, full-screen player, pad disconnect.
- Done: enable/disable, quit, Accessibility check, About, Launch at Login
  (`SMAppService`), controller status line, filled/outline menu-bar icon,
  fall back to another pad on disconnect. App icon: `Scripts/make-icon.swift` → `Resources/AppIcon.icns`.

### Phase 5 — Distribution (local) — **DONE**
- Signed `.app` bundle (stable local identity, ADR-016), `grant-accessibility.sh`, README.

### Phase 6 — Menu Toggle Switches — **DONE** (see §11, ADR-017)
- Replace "Remote: ON/OFF" text and the "Launch at Login" checkmark with real
  toggle switches.

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

All phases done. Possible extras: rebindable mapping, cursor mode (ADR-002).

## 11. Next Update: Menu Toggle Switches (Phase 6)

### Goal
The menu shows two on/off settings as **toggle switches** (`NSSwitch`) instead
of text ("Remote: ON/OFF") or a checkmark ("Launch at Login").

### Target menu
```
Controller: Xbox Bluetooth Gamepad     (disabled label, unchanged)
────────────────────────────
Remote                       [ ●━ ]    switch
Launch at Login              [ ●━ ]    switch
────────────────────────────
Check Accessibility…
About Couch
────────────────────────────
Quit
```
Label on the left, switch right-aligned. Title stays "Remote" (state is shown
by the switch, not by the words ON/OFF).

### Design
- **Control:** `NSSwitch` (macOS 10.15+, project targets 13). Fits native
  look, adapts to light/dark and accent colour.
- **Menu integration:** `NSMenuItem.view` = a small container `NSView`
  (`NSTextField` label + `NSSwitch`, Auto Layout, width matches the menu).
  New file `ToggleMenuItem.swift` holds a reusable `ToggleMenuItemView`
  (title, initial state, `onChange: (Bool) -> Void`) so both rows share one
  implementation.
- **Menu stays open** after a click (custom-view behaviour): the switch moves
  and the effect applies immediately. This is the intended behaviour.
- **Remote switch:** `onChange` sets `media.enabled`, then `updateUI`
  (menu-bar icon filled/outline, tooltip). Same logic as `toggleEnabled`
  today, which goes away.
- **Launch at Login switch:** `onChange` calls `SMAppService.register()` /
  `unregister()`. If it throws, log the error and **snap the switch back** to
  the real `SMAppService.mainApp.status`, so the UI never lies.
- **State sync:** make `AppDelegate` an `NSMenuDelegate`. In
  `menuWillOpen`, re-read both states (`media.enabled`,
  `SMAppService.mainApp.status == .enabled`) and set the switches. Covers
  changes made elsewhere (System Settings → Login Items).
- **Accessibility (VoiceOver):** set the switch's accessibility label to the
  row title. Row click on the label also toggles (add a click gesture), so the
  hit area is the full row, not just the small switch.
- **Unchanged:** controller line, Check Accessibility, About, Quit (normal
  items, normal highlight and keyboard behaviour).

### Tradeoffs and risks
- Custom-view menu items lose the standard hover highlight and arrow-key
  navigation for those two rows. Acceptable: both are mouse-driven settings.
  Mitigation: full-row click target.
- Row width must be set manually or the switch floats oddly. Mitigation:
  fixed width (about 220 pt) plus Auto Layout insets matching standard menu
  padding.
- `NSSwitch` tint follows the system accent colour, which may differ from
  the app's coral icon. Accepted (native look wins).
- No change to input, output, signing or the Accessibility grant, so the
  grant survives the rebuild (stable signing identity, ADR-016).

### Implementation steps
1. Add `Sources/Couch/ToggleMenuItem.swift` (`ToggleMenuItemView`).
2. In `AppDelegate`: build two toggle items, wire `onChange` handlers, remove
   `toggleEnabled` / `toggleLogin` selectors and the text/checkmark updates.
3. Adopt `NSMenuDelegate`, refresh switch states in `menuWillOpen`.
4. Keep `updateUI` for the icon and tooltip, drop the title mutation.
5. Add ADR-017 (toggle switches via custom menu item views).
6. Update README mapping/menu notes if they mention ON/OFF.

### Test plan
- Remote switch off: pad presses do nothing, icon turns outline. On: controls
  work again. Menu stays open throughout.
- Launch at Login on, then check System Settings → Login Items shows Couch.
  Turn it off there, reopen the Couch menu, switch reads off.
- Force a register failure (log the error): switch snaps back.
- Light and dark appearance, VoiceOver reads "Remote, switch, on/off".
- Rebuild with the stable identity; Accessibility stays `trusted=true`.

### Open questions (defaults chosen)
- Row title "Remote" vs "Remote enabled": default **"Remote"**.
- Close the menu after toggling: default **stay open**.
