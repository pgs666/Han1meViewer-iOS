# Agent Log: Hide Inline Player Speed And Quality Controls

## User Input

Original:

```text
能不能让播放器在不全屏的时候不显示播放倍速和视频画质的按钮？全屏后再显示，防止让进度条变成短短的一条
```

English translation:

```text
Can the player hide the playback speed and video quality buttons when it is not fullscreen, and show them only after entering fullscreen, so the progress bar does not become very short?
```

## What Changed

- Updated `iosApp/KSPlayerView.swift` so the playback speed menu and quality menu are only rendered when `isFullscreen` is true.
- Left the fullscreen button visible in both inline and fullscreen modes.
- Preserved the existing behavior that the quality menu only appears when there is more than one playback source.

## Why

The inline video player has limited horizontal space. Rendering play/pause, timestamps, the progress slider, playback speed, quality, and fullscreen controls in one row made the slider too short. Hiding speed and quality while inline keeps the main playback controls usable, while still exposing those menus in fullscreen where there is enough room.

## Mistakes Or Failed Attempts

- None.

## Verification

- `git diff --check` passed.
- `./gradlew :shared:jvmTest` passed on local Linux aarch64. Kotlin/Native is still unsupported on this host, so the actual iOS Swift build is left to GitHub Actions.

## Known Limits

- This is a visibility/layout change only. The selected playback rate and source state are unchanged.
