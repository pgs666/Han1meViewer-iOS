# Lock iPhone Portrait Outside Fullscreen Video

## User Input

Original:

```text
我希望iPhone下，除了全屏播放视频场景以外的所有页面都锁定竖屏
```

English translation:

```text
On iPhone, I want all pages except fullscreen video playback to be locked to portrait.
```

## Changes

- Updated the app orientation controller so the default orientation mask is portrait on iPhone.
- Kept iPad unrestricted with all orientations available.
- Preserved fullscreen video behavior so it can still switch to portrait or landscape based on the video.
- Restored the pre-fullscreen orientation mask when exiting fullscreen playback.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only an existing line-ending warning for `iosApp/AppOrientationController.swift`.
