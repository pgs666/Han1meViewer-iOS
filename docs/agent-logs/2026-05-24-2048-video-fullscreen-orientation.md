## User Input

Original:

```text
全屏模式要根据视频的横竖屏切换全屏界面的横竖屏
```

English translation:

```text
Fullscreen mode should switch the fullscreen interface orientation based on whether the video is landscape or portrait.
```

## Change

- Added app-level orientation control for iOS fullscreen playback.
- Added supported portrait and landscape orientations to `Info.plist`.
- Added an app delegate bridge so the app can dynamically restrict supported orientations while the fullscreen player is shown.
- The fullscreen SwiftUI player now observes `AVPlayerItem.presentationSize`:
  - landscape videos request landscape fullscreen
  - portrait videos request portrait fullscreen
- The fullscreen player also adjusts its SwiftUI aspect ratio to the detected video dimensions.
- Exiting fullscreen restores normal app orientation behavior and requests portrait.

## Why

- SwiftUI alone cannot reliably force iOS interface orientation.
- Android changes fullscreen orientation based on video dimensions, so the iOS implementation needs a small UIKit orientation bridge while keeping the player UI in SwiftUI.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI after commit and push.
