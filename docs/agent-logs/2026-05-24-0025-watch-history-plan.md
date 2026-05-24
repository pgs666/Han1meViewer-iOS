# Watch History Plan

## User Input

Original:

```text
继续下一步
```

English translation:

```text
Continue to the next step.
```

## What I Plan To Change

- Use the existing SQLDelight `watch_history` table instead of adding a new database shape.
- Add a shared KMP watch history store and feature.
- Record a history item after `VideoFeature.loadVideo()` successfully loads video detail.
- Expose `watchHistoryFeature()` from `SharedAppEnvironment`.
- Add an iOS watch history screen under `我的 -> 观看历史`.
- Let history rows navigate back into `VideoDetailView`.

## Why

The app already has real Home, Search, Following, Video, and Player slices. Watch history is a natural next step because it turns repeated video browsing into local app state and proves the SQLDelight table beyond session cookies.

## Verification Planned

- Run `./gradlew :shared:jvmTest`.
- Push and wait for GitHub Actions `iOS App Build`.

## Known Limits

- This first pass records video detail visits, not precise AVPlayer playback position.
- There is no edit mode or bulk clear yet.
