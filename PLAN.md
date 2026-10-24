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

### Phase 7 — Volume Split: Stick = Player, D-pad = System — **DONE** (see §12, ADR-019)
- Left stick up/down changes the **player** volume (arrow keys), analog.
- D-pad ▲/▼ change the **system** volume, one notch per press.

### Phase 8 — Settings, Controller and Debug Window — **DONE** (see §13, ADR-020–022)
- A companion window (SwiftUI) to the menu-bar app: tune settings, see a
  visual map of what each button does, inspect the pad live, and debug.
- The menu-bar app stays the main interface. Mapping stays fixed (ADR-004).

### Phase 9 — App Allowlist (no input while gaming) — **DONE** (see §15, ADR-023)
- Couch acts only when the frontmost app is on an allowlist.

### Phase 10 — CI (GitHub Actions) — **IN PROGRESS** (see §16)
- Build, test and package on every pull request and on pushes to `main`.

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

Phases 0–9 done; Phase 10 (CI, §16) in progress. After it, in rough order: more
tests, other pads (needs hardware), notarization (needs a paid Apple Developer ID).
Decided against: rebindable mapping (mapping stays fixed, ADR-004). Parked:
cursor mode (ADR-002), a big scope change from "media remote".

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

## 12. Next Update: Volume Split (Phase 7)

### Goal
Two clearly separate volume controls:
- **Left stick ▲/▼ = player volume** (fast, analog).
- **D-pad ▲/▼ = system volume** (precise, one notch per press).

This replaces today's mapping where D-pad ▲/▼ send arrow keys (player volume).

### Behaviour
- **D-pad ▲ / ▼:** one system volume notch per press. Edge-triggered like the
  other buttons, no repeat on hold (the controlled, predictable control).
- **Left stick ▲ / ▼:** player volume through the arrow keys. A step fires
  immediately on the push, then repeats while held. Pushing further repeats
  faster (same linear ramp as trigger scrubbing, ADR-011).
- Stick inside the deadzone: stops. Stick left/right does nothing. Right stick
  stays unmapped.
- Remote switch off: both are ignored, like every other input.

### Design
- **System volume output:** real NX system-defined events (ADR-015 path),
  `NX_KEYTYPE_SOUND_UP` = 0, `NX_KEYTYPE_SOUND_DOWN` = 1. Add to the `NXKey`
  enum. Each event is one notch and shows the macOS volume overlay.
- **Actions:** add `systemVolUp` / `systemVolDown`. The existing `volUp` /
  `volDown` (arrow keys) stay and are now fired only by the stick; rename them
  `playerVolUp` / `playerVolDown` for clarity.
- **Mapping:** in `Mapping.edgeTable`, `dpadUp` → `systemVolUp`, `dpadDown` →
  `systemVolDown`.
- **Stick input:** read `gp.leftThumbstick.yAxis.value` (-1…1). Up amount =
  `max(0, y)`, down amount = `max(0, -y)`.
- **Stick repeat:** reuse `AdaptiveRepeater` twice (up, down). `read` returns
  the up or down amount, `threshold` is the deadzone. Fire the first step on
  the rising edge, then `start()` for the repeats. `onIdle` clears the held
  flags (same pattern as the triggers).
- **State:** `volUpHeld` / `volDownHeld` in `MediaController`, reset in
  `attach`, `detach`, and while Remote is off (stop repeaters, track state
  without acting).
- **Config (`config.json`, validated like the others):** `stickDeadzone`
  (default 0.30, allowed 0.1 – 0.9), `volumeSlow` (0.30 s), `volumeFast`
  (0.08 s). Defaults live in `Mapping.swift`.
- **Docs:** README controls table, diagram and mapping text; ADR-019 (supersedes
  the D-pad row of ADR-010); mark Phase 7 done.

### Tradeoffs and risks
- Behaviour change: D-pad ▲/▼ no longer touch the player. Anyone used to the
  old mapping must use the stick for player volume.
- Stick drift: a worn stick resting above 0.30 could creep the player volume.
  Mitigation: tunable deadzone. Lower impact than system volume would be.
- System volume has no hold-to-repeat, so a big change needs several presses.
  Chosen on purpose for control; a repeat-on-hold option can come later.
- Player step size depends on the app: YouTube 5% per arrow, IINA its own step.
- No Accessibility, signing or grant change, so the grant survives the rebuild.

### Implementation steps
1. `OutputLayer`: add `soundUp` / `soundDown` to `NXKey`, handle
   `systemVolUp` / `systemVolDown`, rename the arrow volume actions.
2. `Mapping`: new actions, new D-pad mapping, stick defaults.
3. `Config`: add and validate `stickDeadzone`, `volumeSlow`, `volumeFast`.
4. `MediaController`: two repeaters, `handleStick(gp:)`, reset paths.
5. README, ADR-019, mark Phase 7 done.

### Test plan
- D-pad ▲ / ▼: system volume moves one notch per press, macOS overlay shows,
  the player's own volume does not change. Holding does not repeat.
- Stick ▲ / ▼: immediate step, then repeats, faster when pushed further.
  Release stops. The player volume changes, the system volume does not.
- Remote off: neither works. Hold the stick, switch Remote on: no step until
  released and pushed again.
- Invalid `stickDeadzone` in `config.json`: logged, default used.
- Rebuild with the stable identity, `trusted=true` stays.

### Open questions (defaults chosen)
- D-pad system volume repeats on hold: default **no**, one notch per press.
- Stick keys: default **arrow ▲/▼** (works in IINA and YouTube).

## 13. Next Update: GUI Window (Phase 8)

### Goal
Add a **companion window** to the menu-bar app (not a replacement): configure
settings, **see what every button does** on a visual controller map, view the
pad's live state and details, and **debug** problems without opening Terminal.
The menu-bar item stays the always-on entry point and keeps working with the
window closed.

### Windows and tabs
One window, sidebar navigation (`NavigationSplitView`):

| Tab | Contents |
|---|---|
| **General** | Remote switch, Launch at Login, Accessibility status with a fix button, version |
| **Controller** | Visual map of the pad with each input's function, live highlighting, device details (below) |
| **Tuning** | Sliders for every `config.json` value, live-applied, reset to defaults |
| **Debug** | Live event feed, log viewer, diagnostics, manual action tester |
| **About** | Icon, version, credits, links |

Opened from the menu ("Settings…", ⌘,) and by clicking the app in Finder or
the Dock while it runs.

### Controller tab (the visual map)
A drawn controller with a **function label on every input**, so it doubles as
the mapping reference. The map is generated from `Mapping`, so it can never
drift from what the app does. The mapping itself is fixed and not editable
here (ADR-004 stands).
```
┌ Xbox Bluetooth Gamepad ─────────────────────────────┐
│  Category: Xbox One    Battery: 78% (discharging)    │
│  Connection: Bluetooth  Background input: on         │
│                                                      │
│   LT scrub back ▮▮▮▯▯▯      RT scrub fwd ▯▯▯▯▯▯       │
│   LB brightness − ○         RB brightness + ●        │
│     ▲ system vol +                 (Y) fullscreen ○   │
│  ◄ seek  ┤D-pad├ seek ►     (X) prev ○   (B) next ○   │
│     ▼ system vol −                 (A) play/pause ●   │
│                    [Menu] mute                        │
│  (  ◉  ) left stick: player volume  (  ·  ) right     │
└──────────────────────────────────────────────────────┘
```
- Each input shows its function. Pressed buttons light up, triggers fill,
  and the left stick shows a moving dot with numeric X/Y inside its deadzone
  ring (drawn from the current setting). A toggle switches the labels between
  "functions" and "raw input names".
- The right stick is shown as "unmapped".
- Device facts from `GCController`: vendor name, product category, battery
  level and state (`GCDevice.battery`) when available, haptics and light
  support, whether it is an extended gamepad. Shows "No controller" with a
  hint (press the Xbox button to wake the pad) when none is attached.
- Updates only while the window is visible, at about 30 Hz.

### Tuning tab
- Sliders with numbers for `triggerThreshold`, `seekSlow`, `seekFast`,
  `stickDeadzone`, `volumeSlow`, `volumeFast`, using the same valid ranges
  as `Config` (one shared validator).
- Changes apply **immediately** (no relaunch) and are written to `config.json`.
- "Reset to defaults" per group. A live preview next to the deadzone sliders
  shows the stick or trigger value against the threshold.

### Debug tab
- **Event feed:** timestamped rows for inputs, fired actions and posted keys,
  filterable (inputs / actions / errors), pause and clear. Capped at 500 rows.
- **Log viewer:** the contents of `Couch.log`, with Copy, Reveal in Finder,
  and Clear.
- **Diagnostics panel:** Accessibility trusted yes/no (re-check and re-prompt
  buttons), controller attached, background events on, app version, macOS
  version, signing identity, config file path and validity, last config
  warnings. "Copy diagnostics" puts all of it on the clipboard for bug reports.
- **Action tester:** a button per action (play/pause, next, fullscreen, system
  volume, and so on) that fires it as if the pad did, to tell input problems
  from output problems.

### Architecture
- **UI:** SwiftUI window hosted in an `NSWindow` (`NSHostingController`).
  ADR-008 chose AppKit for the status item because the menu needed no rich UI;
  the window does, so SwiftUI is right here. The status item stays AppKit.
- **App model (the main refactor):** today `MediaController` owns input,
  state and config. Split out observable objects the UI can bind to:
  - `SettingsStore` (`ObservableObject`): all tunables plus Remote on/off.
    Loads and saves `config.json`, validates, and tells `MediaController` to
    `reconfigure()` (rebuild the repeaters) on change.
  - `PadMonitor` (`ObservableObject`): the latest pad snapshot (buttons,
    triggers, sticks) and device info. Updated by `MediaController.handle`.
  - `EventLog` (`ObservableObject`): ring buffer fed by `DebugLog.log` plus
    structured events (input / action / error).
  - `AppModel`: owns the three above and `MediaController`, and is shared by
    the menu and the window.
- **Activation:** Couch stays a menu-bar agent (`LSUIElement`). While the
  window is open, switch to `.regular` so it gets a Dock icon, a menu bar and
  proper focus, then back to `.accessory` on close. No change to launch at
  login or the Accessibility grant.
- **Build:** still SwiftPM with Command Line Tools only. SwiftUI builds
  without Xcode (no previews). No new dependencies.
- **Config file stays the source of truth** and stays hand-editable. The
  window and the file stay in sync (re-read on window open).

### Phases
- **Phase 8:** everything above.
### Tradeoffs and risks
- The refactor touches the core input path. Mitigation: keep behaviour
  identical first (step 1 with no UI), verify the pad still works, then add
  the UI.
- Publishing pad state 30 times a second costs CPU. Mitigation: publish only
  while the window is visible.
- Live-applying settings means rebuilding repeaters while a trigger may be
  held. Mitigation: stop repeaters and reset held flags, as on attach.
- Agent apps showing windows can misbehave with focus. Mitigation: the
  `.regular`/`.accessory` switch and `NSApp.activate`, tested with the window
  closed and reopened.
- Battery info is not exposed by every pad over Bluetooth. Show "not
  reported" instead of a wrong value.
- A bigger app means more to maintain. Mitigation: one file per tab, no
  third-party code.

### Implementation steps
1. Refactor: `SettingsStore`, `PadMonitor`, `EventLog`, `AppModel`. No UI yet.
   Verify behaviour is unchanged on the pad.
2. Window shell: `SettingsWindowController`, sidebar, "Settings…" menu item,
   activation switching, Dock icon while open.
3. General and About tabs.
4. Controller tab: drawn controller, function labels generated from
   `Mapping`, live highlighting, device info.
5. Tuning tab with live apply and reset.
6. Debug tab: event feed, log viewer, diagnostics, action tester.
7. README screenshots, ADR-020 (GUI window), ADR for the model split, mark
   Phase 8 done.
8. Release v0.3.

### Test plan
- Pad behaviour is identical before and after step 1.
- Window opens from the menu and from Finder, closes, reopens; the Dock icon
  appears and disappears; the menu-bar item keeps working throughout.
- Controller tab: every label matches what the input really does, every
  button, both triggers and both sticks react, the right stick reads
  "unmapped"; unplug and replug the pad updates the details.
- Tuning: change `stickDeadzone` while the stick is held, the behaviour
  changes without a relaunch; an out-of-range value is rejected; hand-edit
  `config.json`, reopen the window, the sliders match.
- Debug: action tester fires real events; "Copy diagnostics" output is
  complete; the event feed stays capped.
- Rebuild with the stable identity: `trusted=true` stays.

### Open questions (defaults chosen)
- **Dock presence:** default **menu-bar app that shows a Dock icon only while
  the window is open**. Alternative: always a normal Dock app.
- **Rebinding:** **decided: no.** Mapping stays fixed; the window only shows it.
- **Window style:** **sidebar with tabs** (System Settings look). Confirmed.
- **Dark mode and accent colour:** follow the system.

## 14. Backlog (to discuss): Couch while gaming

**Status:** decided, see §15 (app allowlist). Kept below as the background.

### Problem
Couch receives pad input even when another app is frontmost
(`shouldMonitorBackgroundEvents`, ADR-013) and posts system-wide key events.
While a game is in front, a game and Couch both read the pad, and Couch also
injects input into the game or the system:

- A fires the system play/pause key (can start or pause Music or other media apps).
- D-pad ▲/▼ change the Mac's volume; LB/RB change the screen brightness.
- Y types `F`; D-pad ◄ ►, the left stick and the triggers send arrow keys into the game window.

The game's own pad support is not broken. Only Couch's injected keys cause trouble.

### Workaround today
Switch **Remote** off (menu or Settings → General) before gaming, or quit Couch.

### Options
1. **Pause hotkey:** a pad chord (for example hold Menu plus one button) toggles
   Remote. Small. Costs a free button combo and must not fire by accident.
2. **App allowlist (leaning this way):** Couch acts only when the frontmost app
   is on a list (IINA, browsers, and so on) and stays quiet otherwise. Most
   reliable for gaming. Needs a settings list, a way to pick apps, and
   handling for unexpected cases such as video in a browser tab you did not list.
3. **Auto-pause for fullscreen non-listed apps:** least predictable, most magic.

### Open questions
- Allowlist or denylist (list the games instead)?
- Should Remote's menu icon show "paused for <app>" so it is obvious why it is quiet?
- Where does the list live: `config.json`, the Settings window, or both?
- Should media keys (play/pause, volume) still work everywhere while seek and
  fullscreen keys only work in listed apps?

## 15. Next Update: App Allowlist (Phase 9)

### Goal
Couch acts only when the **frontmost app** is on an allowlist (IINA, browsers and
so on). Otherwise it ignores the pad, so games get no injected keys (§14).

### Decisions
| Question | Decision |
|---|---|
| Allowlist or denylist | **Allowlist.** Fails safe: any unlisted game is silent. |
| Media keys everywhere | **No, all-or-nothing.** Possible later as an opt-in. `Remote` stays the manual override. |
| Where is the UI | A separate **Apps** tab in the Settings window. |
| Default list | The list below. New apps can be added. |

### Behaviour
- Frontmost app on the list: Couch behaves as today.
- Frontmost app not on the list: **paused**. No actions, repeaters stopped, pad
  state still tracked, so a button held while switching apps does not fire on
  return (same rule as Remote off).
- Mode: **Allowlist** (default) or **Off** (act everywhere, as before).
- Couch's own Settings window is not on the list, so the pad does not act while
  it is frontmost. The Controller tab still shows live input and the Debug
  action tester still works, because neither goes through the gate.

### Default list
IINA `com.colliderli.iina`, Safari `com.apple.Safari`, Chrome
`com.google.Chrome`, Firefox `org.mozilla.firefox`, Arc
`company.thebrowser.Browser`, Brave `com.brave.Browser`, Edge
`com.microsoft.edgemac`, VLC `org.videolan.vlc`, QuickTime Player
`com.apple.QuickTimePlayerX`, Music `com.apple.Music`, TV `com.apple.TV`,
Spotify `com.spotify.client`. The IDs for IINA, Safari, Chrome, Brave,
QuickTime, Music, TV and Spotify were checked on this Mac. Firefox, Arc, Edge
and VLC are not installed here and come from their published IDs, so they need
a check.

### Design
- **Detection:** `NSWorkspace.shared.frontmostApplication`, kept current by a
  `FrontmostAppMonitor` observing `NSWorkspace.didActivateApplicationNotification`.
  No new permission, no signing or Accessibility grant change.
- **Filter:** a pure `AppFilter` struct (mode, set of bundle ids,
  `allows(bundleID)`), so it is trivial to unit test.
- **Gate:** in `MediaController`, `isActive = enabled && filterAllows`. It
  replaces the `enabled` checks in `handle` and the repeater `fire` closures.
  When it turns false (Remote off, or the app changes) it stops repeaters and
  syncs edge and held state without acting, as the Remote-off path does today.
- **Config (`config.json`):** `"appFilter": { "mode": "allowlist", "apps": ["com.colliderli.iina", ...] }`.
  Validated: unknown mode falls back to allowlist, blank ids are dropped,
  an empty list is allowed (Couch then never acts, with a warning in Debug).
  Defaults live in `Mapping.swift`.
- **Menu:** the controller line reads "paused in <App>" when blocked. A menu item
  "Allow <App>" adds the frontmost app in one click. Opening the status menu
  does not change the frontmost app, so it always names the app you were in.
  The menu-bar icon is outline while paused.
- **Apps tab:** list with app icon, name and bundle id, a remove button per row,
  **Add running app…** (menu of running apps), **Add app…** (file picker for a
  `.app`, reads its bundle id), **Reset to defaults**, and a mode switch
  (Allowlist / Off). Changes apply live and save to `config.json`.
- **Debug:** diagnostics show the frontmost app, mode and whether Couch is
  paused. The event feed logs each pause and resume.

### Tradeoffs and risks
- **Background playback:** a player that is not frontmost cannot be controlled.
  This is the price of the allowlist (see the decision above).
- **Silent failure:** a new player is not listed and nothing happens. Mitigation:
  the "paused in <App>" label and the one-click "Allow" item.
- **PWAs and web apps** have their own bundle ids and must be added one by one.
- **Focus flicker** (notification overlays) could drop a held repeat. The gate
  resets cleanly when the app returns.
- **Behaviour change:** a fresh install no longer acts in unlisted apps. Note it
  in the CHANGELOG as a deliberate default.

### Implementation steps
1. `AppFilter` and `FrontmostAppMonitor`, with tests if XCTest is available.
2. `appFilter` in `Config` and `SettingsStore`, validation, defaults.
3. Gate in `MediaController` (edges, triggers, stick, repeaters), live reconfigure.
4. Menu: paused label, "Allow <App>" item, icon state.
5. Apps tab (list, add running, add from file, reset, mode).
6. Debug diagnostics and event lines.
7. Docs: ADR-023, README (new section and screenshot), CHANGELOG, mark Phase 9
   done. Regenerate screenshots with `Scripts/make-screenshots.sh`.
8. Release v0.4.

### Test plan
- IINA or a browser frontmost: every control works as before.
- Terminal or a game frontmost: no key events, no volume or brightness change.
  The menu says "paused in <App>" and the icon is outline.
- Hold the stick, switch to an unlisted app, then back: nothing fires on return.
- "Allow <App>" adds it and Couch starts acting at once. Remove it, it stops.
- Add apps through both paths. Hand-edit `config.json`, reopen the window, the
  list matches. A bad mode or blank id is cleaned up and logged.
- Mode Off behaves like today. Remote off still wins over the filter.
- Rebuild with the stable identity: `trusted=true` stays.

### Open questions (defaults chosen)
- Opt-in "media keys everywhere": default **not in this phase**.
- Treat apps that declare the Games category as always blocked: default **no**
  (many games do not declare it; an allowlist already covers them).

## 16. Next Update: CI (Phase 10)

### Goal
Catch a broken build or failing test before a PR is merged, without any cost or
setup beyond the repo.

### Design
- One workflow, `.github/workflows/ci.yml`, on `pull_request` and pushes to
  `main`. A newer push to the same ref cancels the older run.
- Runner `macos-15` (Apple silicon, full Xcode). Free and unlimited for public
  repos on a personal account; the repo is public.
- Steps: print the toolchain, run `Scripts/test.sh` (plain `swift test` there),
  run `Scripts/build-app.sh` (release build, package, ad-hoc sign), then check
  the bundle (signature verifies, icon present, version printed).
- No secrets, read-only token (`permissions: contents: read`), no artifacts
  uploaded, no release automation. CI cannot use the local "Couch Local
  Signing" identity, so it only verifies; releases are still built on the
  maintainer's Mac (ADR-016).
- README gets a CI status badge. Making the check required before merge is a
  branch-protection setting on GitHub, left to the repo owner.

### Risks
- The runner has an older Swift/SDK than the dev machine (Swift 6.3, macOS 26
  SDK), so something could compile locally and fail there. That is what the
  first run is for: fix real incompatibilities, do not hide them.
- Hardware-free by design: nothing here exercises the pad or Accessibility.

### Test plan
- The workflow goes green on its own PR; a deliberate failure (not committed)
  turns it red.
- `Scripts/test.sh` and `Scripts/build-app.sh` still work locally.

