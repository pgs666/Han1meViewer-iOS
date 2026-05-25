# 2026-05-25 17:40 P0 runtime bug fixes

## Request

Fix five P0 issues reported during iOS migration review:

- Cloudflare cookie import uses a plain Boolean gate and can race between cookie observer and navigation callbacks.
- Video detail does not restore `watch_history.playback_position_millis`.
- `AndroidStylePlayerHeader` recreates `AVPlayer` on each view appearance and does not persist playback progress.
- Comment latest/earliest sorting collapses when relative date strings are not in the hard-coded Chinese format.
- Login WebView imports cookies too early by treating any non-`/login` Hanime navigation as successful login.

## Changes

- Added a SQLDelight `selectByVideoCode` query and shared watch-history lookup so video loading preserves existing playback position instead of overwriting it with `0`.
- Added `VideoFeature.recordPlaybackPosition` and exposed `playbackPositionMillis` on `VideoDetailSnapshot`.
- Moved iOS `AVPlayer` ownership into `VideoDetailViewModel`, preserving position when switching sources and saving position before player release/pause.
- Serialized Cloudflare clearance-cookie import state with a dedicated dispatch queue.
- Changed login completion detection to wait for logged-in DOM markers before importing cookies, while still using shared login verification as the final authority.
- Reworked comment date sorting to parse combined/variant relative date expressions and preserve/reverse server order when dates are unknown.

## Validation

- Pending: run shared Kotlin checks locally and iOS build through GitHub Actions.
