# Extract Player Network Speed Sampler

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

- Extracted AVPlayer discovery, access-log sampling, progressive-download buffer sampling, and speed formatting into `KSPlayerNetworkSpeedSampler`.
- Moved the previous buffer endpoint and sample timestamp into the sampler.
- Preserved the existing mount reset behavior through an explicit `reset()` API.
- Reused the sampler's AVPlayer discovery for `AVPlayerStatusObserver` wiring.
- Reduced `KSPlayerView.swift` from 1,060 lines to 971 lines.

## Why

Network speed sampling is a stateful responsibility with a narrow API and does not belong to the SwiftUI control layout or gesture state machine. Extracting it removes reflection and AVFoundation sampling details from the main player view without widening the player's private UI state.

## Mistakes Or Failed Attempts

- The initial extraction missed that `AVPlayerStatusObserver` reused the old AVPlayer discovery helper and that `onAppear` reset the sampling baseline. Structural searches found both references before commit; they were moved behind explicit sampler APIs.

## Verification

- Ran `git diff --check`.
- Searched for stale references to the removed sampling properties and helper methods.
- Confirmed that mount-time reset and status-observer rebinding still occur at their original lifecycle points.
- The authoritative JVM tests, XcodeGen generation, and unsigned device build will run in GitHub Actions after push.

## Known Limits And Follow-Up

- The sampler still uses reflection because KSPlayer does not expose its wrapped AVPlayer through the public API used here.
- The gesture state machine remains the next large responsibility in `KSPlayerView.swift`.
