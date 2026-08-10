# Fix Current Series Video Navigation

## User Input

Original:

```text
首先，播放页的播放列表那一栏展开后支持判断是否同一个视频不跳转，但是默认状态下还是会跳转，修复它
```

English translation:

```text
First, after expanding the playlist section on the playback page, it can detect the current video and avoid navigating to it, but the default collapsed state still navigates. Fix it.
```

## What Changed

- Replaced the default horizontal series list's direct `NavigationLink` with a button action.
- Added `openVideoIfNeeded(_:)` so tapping the item marked as currently playing does nothing.
- Kept navigation for every other series item through the parent view's existing `onOpenVideo` path.

## Why

The expanded series sheet already checked `VideoRelatedRow.isPlaying` before navigation. The default horizontal list bypassed that logic because every card was wrapped in an unconditional `NavigationLink`.

## Verification

- Confirmed both the default list and expanded sheet now guard the item whose `isPlaying` value is true.
- Confirmed non-current items still call the existing series navigation callback.
- Reviewed the resulting diff for unrelated changes.
- `git diff --check` passed.
- Swift parsing could not run because `swiftc` is unavailable in the current Linux environment.
- `./gradlew jvmTest` could not start because the Gradle distribution download failed during the TLS handshake; no KMP code was changed by this fix.

## Known Limits

- A local iOS compile is unavailable in the current Linux environment. The Swift integration build still needs macOS/GitHub Actions verification.
