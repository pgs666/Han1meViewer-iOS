## User Input

Original:

```text
播放器的全屏功能也要实现，另外下方还有相关影片呢
```

English translation:

```text
The player's fullscreen feature also needs to be implemented, and there are related videos below as well.
```

## Change

- Added a fullscreen button to the SwiftUI playback header.
- Added a SwiftUI `fullScreenCover` that reuses the same `AVPlayer`, preserving playback state while entering and exiting fullscreen.
- Improved KMP video related-item parsing to match Android's fallback behavior:
  - normal related cards
  - simplified `.home-rows-videos-div` cards
- Kept the related videos section at the bottom of the introduction tab, now with better parser coverage.

## Why

- Android's playback page has a fullscreen affordance and related videos below the introduction content.
- The previous iOS parser could miss related videos when the site returned the simplified related-card layout.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI after commit and push.
