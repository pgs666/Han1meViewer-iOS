# Player Source Switching Implementation

## User Input

Original:

```text
继续下一步
```

English translation:

```text
Continue to the next step.
```

## What Changed

- Added `VideoPlaybackSourceSnapshot` and playback source accessors to KMP `VideoDetailSnapshot`.
- Added Swift `VideoPlaybackSourceRow` mapping.
- Updated `VideoDetailView` to open `PlayerView` with all parsed playback sources.
- Replaced the simple single-URL `PlayerView` with an AVPlayer view that supports source selection.
- Source switching attempts to preserve the current playback timestamp and resume if the previous player was playing.
- Cleaned up several video detail strings into normal Chinese while touching the screen.

## Why

The video parser can return multiple playback sources, but iOS previously discarded everything except the default. Quality/source switching is part of making online playback usable.

## Mistakes Or Failed Attempts

- I used a PowerShell text rewrite to repair one corrupted `相关影片` section title after an `apply_patch` context match failed. That was a mistake because manual file edits should use `apply_patch`; the resulting file content was reviewed afterward and the rest of the changes used `apply_patch`.

## Verification Planned

- Run `./gradlew :shared:jvmTest`.
- Push and wait for GitHub Actions `iOS App Build`.

## Known Limits

- Source switching preserves timestamp, but playback continuity depends on source timelines matching.
- There is no custom full-screen control layer yet; playback still uses `VideoPlayer`.
