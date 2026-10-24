# Couch

A macOS menu-bar app that turns a Bluetooth gamepad into a media remote for
IINA, YouTube and any other player. Lean back, thumbs on the pad.

No mouse cursor, no rebind UI. Keys and media keys only, with one fixed mapping.

Built and tested with an Xbox-protocol pad (Cosmic Byte Blitz) on macOS 26.
Input uses Apple's GameController framework, so other pads macOS maps to an
extended gamepad should work too.

## Mapping

| Pad input | Action |
|---|---|
| A | Play / pause |
| B | Next track |
| X | Previous track |
| Menu | Mute |
| D-pad ◄ / ► | Seek back / forward (arrow keys) |
| D-pad ▲ / ▼ | Volume up / down (arrow keys) |
| LB / RB | Brightness down / up |
| LT / RT | Hold to scrub back / forward. Press deeper to scrub faster |

Brightness keys control the system display. They may do nothing on an
external monitor.

## Build and run

Needs macOS 13+ and Swift 5.9+. Command Line Tools are enough, Xcode is not
required.

```sh
./Scripts/build-app.sh        # builds and ad-hoc signs dist/Couch.app
./Scripts/build-app.sh run    # same, then launches it
```

## First run: Accessibility

Posting key events needs Accessibility permission. Reading the pad does not.

1. System Settings → Privacy & Security → Accessibility.
2. Add `dist/Couch.app` and turn it on.
3. Quit and relaunch Couch. A process started before the grant does not get it.

Run `./Scripts/grant-accessibility.sh` to open the pane and reveal the app.

### Keep the grant across rebuilds

An ad-hoc signature changes on every build, which drops the grant. Run this
once to create a local self-signed identity ("Couch Local Signing") in your
login keychain:

```sh
./Scripts/setup-signing.sh    # asks for your password once
```

`build-app.sh` then signs with it automatically and the grant survives
rebuilds. Grant Accessibility once more after the first build with the new
identity. Without the identity, builds fall back to ad-hoc and you must
re-grant after each one. Remove the certificate later in Keychain Access.

## Tuning without a rebuild

Optional file `~/Library/Application Support/Couch/config.json`:

```json
{ "triggerThreshold": 0.15, "seekSlow": 0.5, "seekFast": 0.08 }
```

`seekSlow` and `seekFast` are the repeat intervals in seconds at light and
full trigger press.

## Troubleshooting

Log: `~/Library/Logs/Couch.log` (reset at each launch). It records the
Accessibility state, controller attach and detach, and each input and action.

- Pad sleeps after about 5 minutes idle. Press the Xbox button to wake it.
- Gamepad input only reaches background apps because Couch sets
  `GCController.shouldMonitorBackgroundEvents` (see ADR-013).

## Layout

```
Sources/Couch/     menu-bar app (input, mapping, output)
Sources/pad-dump/  CLI that prints live pad state, for debugging
Scripts/           build-app.sh, setup-signing.sh, grant-accessibility.sh, make-icon.swift
Resources/         Info.plist
PLAN.md, ADR.md    roadmap and decision records
```
