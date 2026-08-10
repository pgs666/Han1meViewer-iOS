# Split Large iOS Views

## User Input

Original:

```text
开始拆吧
```

English translation:

```text
Start splitting them.
```

## What Changed

- Moved the video detail introduction, artist card, metadata, actions, share sheet, tag flow, and flow layout out of `VideoDetailView.swift` into `VideoDetailComponents.swift`.
- Reduced `VideoDetailView.swift` from 872 lines to 343 lines so it primarily owns page state, navigation, player placement, and tab composition.
- Extracted player gesture kinds, display formatting, supported playback rates, and KSPlayer option construction into `KSPlayerSupport.swift`.
- Updated `KSPlayerView.swift` to consume those stateless helpers without exposing its private playback state.

## Why

The two files were the largest Swift sources in the project. Video detail already had clean component boundaries, while the player is a tightly coupled state machine. This pass performs the safe component split and establishes stateless player boundaries without weakening the player's internal access control.

## Mistakes Or Failed Attempts

- The first component draft compressed two action closures into ternary expressions. They were changed back to explicit `if/else` blocks before commit because clarity is more important than reducing line count.
- The player could not be mechanically divided into cross-file extensions because its methods depend on private `@State` properties; doing that would require widening most of the implementation to module scope.

## Verification

- Ran `git diff --check`.
- Searched for stale references to the moved player helpers.
- Confirmed the extracted files remain under the recursively included `iosApp` XcodeGen source path.
- The authoritative JVM tests, XcodeGen generation, and unsigned device build will run in GitHub Actions after push.

## Known Limits And Follow-Up

- `KSPlayerView.swift` remains large. Its next safe decomposition should introduce dedicated control-overlay and gesture-controller types with explicit inputs rather than cross-file extensions over internal state.
- This commit intentionally does not address the behavioral review findings around download completion, custom-domain headers, or Cloudflare cancellation.
