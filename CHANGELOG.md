# Changelog

## 0.2.0 - 2026-10-25

### Changed

- Replaced the permanent three-column inspector layout with a digital timer, optional workspace sidebar, and dedicated soundscape and record pages.
- Kept the primary timer action in one position and preserved the chosen workspace layout across start, pause, and resume.
- Moved task entry above the timer, added named duration presets and explicit idle mode selection, and consolidated advanced settings.
- Recent tasks now fill the task field without starting or replacing an active session.
- Added an explicit early-end confirmation in the timer view and clearer completion and next-round guidance.
- Added persistent mute with volume restoration; soundscape changes preserve volume and mute settings.
- Consolidated the redundant silent-break soundscape into the Deep Work combination.
- Added Chinese names for bundled sounds while preserving their stable file identifiers and categories.
- Reduced the default window to 980 × 720 and minimum content size to 680 × 640, with adaptive light and dark colors.
- Scoped bare Return and Space shortcuts to the timer workspace outside text editing.

### Fixed

- An end confirmation belongs to the round that opened it and cannot stop a later automatically started round.
- Confirming end at the timer deadline preserves the completed focus record and scheduled transition.
- Menu and command stops at the deadline also retain an already completed focus record before returning to idle.
- Holding a timer shortcut no longer repeatedly toggles pause and resume.
- Task editing retains spaces between words; surrounding whitespace is normalized when a round starts.

### Verification

- Added regressions for recent task selection, idle mode selection, active preset protection, soundscape volume preservation, mute and preview playback, legacy settings, next-round duration changes, and localized sound selection.
- Added regressions for stale end confirmations, confirmations at the deadline, and session identity across pause and resume.
- Added a regression for per-character task editing, whitespace normalization, and complete-character length limits.
- All 27 self-tests passed; a clean Release build, DMG integrity and mounted-file checks, and a launch/version smoke test passed.

### Compatibility And Distribution

- Requires macOS 13.0 or later on Apple silicon (arm64).
- Existing records and settings remain compatible; installations without a saved mute setting default to unmuted.
- The app is ad-hoc signed and not notarized. Gatekeeper may block first launch on another Mac.
- DMG SHA-256: `1960bbcdcc244f5b647c8e8eca5a2a0b13b17c60e4685e2e33eed518dcb48a4b`.

## 0.1.1 - 2026-09-09

Patch release focused on timer correctness and playback reliability.

### Fixed

- Manual rest actions now honor the scheduled short or long break.
- Pausing at the exact end of a session now completes the session instead of leaving a stuck `00:00` timer.
- Restored legacy zero-second paused sessions are recovered without duplicating records.
- Delayed wake and sleep recovery preserve the session's original completion time for records, notifications, and statistics.
- Resuming a paused session stops sound previews before session playback starts.
- Replaying a sound during fade-out cancels the stale stop callback so playback continues.

### Verification

- 14 self-tests passed.
- Release build completed with full Xcode.
- DMG SHA-256: `d1802e4c7a5fbd8209aa77a504e2b4b6233a3b57496af381653f9abd0cde197d`.

## 0.1.0 - 2026-06-22

Initial Noise release.

### Added

- Pomodoro timer with focus, short break, long break, pause, resume, and stop states.
- Custom focus, short break, long break, and long-break interval settings.
- White-noise soundscapes with focus and break sound selection, grouped sound picker, presets, preview, volume, fade in, and fade out.
- macOS notifications for completed focus and break sessions.
- Menu bar extra with countdown, quick start, pause/resume, stop, and main-window access.
- Focus records with today and seven-day stats, top task summaries, recent records, CSV export, and Markdown export.
- Compact focus layout that hides side panels while a focus session is running.
- Local state recovery for elapsed timers and corrupt state backup.
- Local macOS app bundle and DMG packaging scripts.

### Fixed

- Restored expired focus sessions are recorded on launch.
- Corrupt state files are moved aside before new state is saved.
- Missing break sound IDs fall back to silence.
- Export cancellation no longer leaves stale status behind.
- Timer progress reset no longer animates backward.
- The right inspector panel now uses the normal window background and the default window height shows the full inspector content.

### Compatibility

- Requires macOS 13.0 or later.
- Bundle identifier: `com.crazyjal.noise`.
- DMG SHA-256: `07cd55618baffd57947328474fac5abf0249ebe0954ba19e081fe7161350e917`.

### Signing And Notarization

- The release DMG is locally signed with the available `codesign` identity, defaulting to ad-hoc signing when no Developer ID identity is configured.
- Notarization is not configured for this release. Users may see normal Gatekeeper warnings for an unsigned or ad-hoc signed distribution.
