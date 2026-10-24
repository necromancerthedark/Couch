# Changelog

All notable changes to Couch. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions follow [Semantic Versioning](https://semver.org/) (pre-1.0: a minor bump may change behaviour).

**How this is maintained:** every PR that changes behaviour adds a line under
`## [Unreleased]`. To release, rename that section to the new version and date, bump
`Resources/Info.plist`, then publish with
`gh release create vX.Y --notes-file <(Scripts/release-notes.sh X.Y) ...`.

## [Unreleased]

### Changed
- CI: GitHub Actions builds, tests and packages every pull request.

## [0.4] - 2026-10-25

### Added
- **App allowlist.** Couch now acts only while an allowed app is frontmost, so games and other apps no longer receive its media keys, volume, brightness and arrow keys.
  - New **Apps** tab in the Settings window: mode (*Only in these apps* / *Everywhere*), the allowed list with icons, **Add running app…**, **Add app…** (file picker) and **Reset to defaults**.
  - The menu shows "paused in <App>" and a one-click **Allow <App>** item when Couch is blocked, and the menu-bar icon is outline while paused.
  - Default list: IINA, Safari, Chrome, Firefox, Arc, Brave, Edge, VLC, QuickTime Player, Music, TV, Spotify.
  - `config.json` gets an `appFilter` block (`mode`, `apps`).
- Unit tests (`Scripts/test.sh`) for the app filter and config validation.
- Debug tab diagnostics show the frontmost app, the filter mode and whether Couch is paused.

### Changed
- **Behaviour change:** a fresh install no longer acts in apps that are not on the list. Add an app from the menu or the Apps tab, or set the mode to *Everywhere* for the old behaviour. The **Remote** switch still turns everything off.
- Docs: README shows a controller diagram again, names the release asset in the install step, and has a section on the allowlist.

## [0.3] - 2026-10-24

### Added
- **Settings window** (menu → *Settings…*, ⌘,). A Dock icon shows only while it is open.
  - **General:** Remote and Launch at Login switches, Accessibility status with re-check and open-settings buttons.
  - **Controller:** a drawn pad showing what every input does, lit up live, with battery and device details.
  - **Tuning:** a slider for every setting with live preview bars. Applies instantly and saves to `config.json`.
  - **Debug:** live event feed, log viewer, copyable diagnostics, and an action tester that fires each action without the pad.
  - **About:** icon, version and credits.
- `Couch --screenshots <dir>` and `Scripts/make-screenshots.sh` to regenerate README images.

### Changed
- Tuning changes apply live, with no relaunch.
- README rewritten with a header, badges, screenshots and collapsible sections.
- Version 0.3 (build 3).

### Fixed
- An unknown battery state showed as "0%". It now shows "Not reported".

## [0.2] - 2026-10-24

### Changed
- **Volume split.** D-pad ▲ / ▼ now change the **system volume**, one notch per press. They no longer send arrow keys.
- The **left stick** ▲ / ▼ now changes the **player volume** (arrow keys). Hold to repeat, push further to go faster. This is where the old D-pad volume moved.

### Added
- `config.json` keys `stickDeadzone`, `volumeSlow` and `volumeFast`. Invalid values fall back to the defaults.

## [0.1] - 2026-10-24

First release.

### Added
- Menu-bar app that turns a Bluetooth gamepad into a media remote for IINA, YouTube and other players.
- Fixed mapping: A play/pause, B next, X previous, Y fullscreen (`F` key), Menu mute, D-pad ◄ ► seek, D-pad ▲ ▼ volume, LB / RB brightness, LT / RT hold to scrub (deeper press scrubs faster).
- **Remote** and **Launch at Login** switches in the menu, About panel with credits, filled / outline menu-bar icon.
- Real system-defined media key events, so play/pause, next, previous and mute work in players.
- Stable local signing identity (`Scripts/setup-signing.sh`) so the Accessibility grant survives rebuilds.
- `config.json` for trigger and seek tuning, validated on load.
- Log at `~/Library/Logs/Couch.log`, capped at 1 MB.

### Fixed
- Input reached the app only while it was frontmost. Couch now asks for background pad events.
- Buttons held while Remote was off fired when it was switched back on.
- A trigger repeat could stop while the trigger was still held.
- Non-gamepad devices showed as a connected controller. Only one pad is active at a time now.

[Unreleased]: https://github.com/necromancerthedark/Couch/compare/v0.4...HEAD
[0.4]: https://github.com/necromancerthedark/Couch/compare/v0.3...v0.4
[0.3]: https://github.com/necromancerthedark/Couch/compare/v0.2...v0.3
[0.2]: https://github.com/necromancerthedark/Couch/compare/v0.1...v0.2
[0.1]: https://github.com/necromancerthedark/Couch/releases/tag/v0.1
