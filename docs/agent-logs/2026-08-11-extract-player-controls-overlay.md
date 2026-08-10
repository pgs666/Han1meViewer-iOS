# Extract Player Controls Overlay

## User Input

Original:

```text
继续下一步更改
```

English translation:

```text
Continue with the next change.
```

## What Changed

- Extracted the complete player controls overlay into `KSPlayerControlsOverlay`.
- Moved the top bar, progress controls, playback-rate menu, quality menu, and fullscreen control out of `KSPlayerView`.
- Kept player lifecycle, playback callbacks, gesture handling, and auto-hide task ownership in `KSPlayerView`.
- Removed a duplicate `SwiftUI` import from `KSPlayerView.swift`.

## Why

The controls form one cohesive view with a narrow binding-and-callback boundary. Moving them reduces the main player's layout responsibilities without changing the gesture state machine or playback lifecycle.

## Mistakes Or Failed Attempts

- None.

## Verification

- Ran local structural checks and `git diff --check`.
- The authoritative JVM tests, XcodeGen generation, and unsigned device build will run in GitHub Actions after push.

## Known Limits And Follow-Up

- The gesture state machine remains the largest responsibility in `KSPlayerView.swift`.
- Device behavior will be verified using the CI artifact and PlumeSign's combined sign-and-install flow.
