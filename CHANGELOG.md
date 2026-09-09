# Changelog

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
