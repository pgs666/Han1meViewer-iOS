# Agent Log: Fix Autoplay Disabled Paused State

## User Input

Original:

```text
自动播放修复的逻辑有一点点小问题：加载好后播放器没有认为自己是暂停状态，双击之后反而是暂停，顺便还导致了加载好之后视频没有在播放但是上下滑动下方view时不会让视频自动收起
另外，记得使用--exit-status来监控
```

English translation:

```text
There is a small issue with the autoplay fix: after loading, the player does not think it is paused. Double-tapping pauses instead, and after loading the video is not playing but scrolling the lower view does not automatically collapse the video. Also, remember to use --exit-status for monitoring.
```

## What Changed

- Updated `iosApp/KSPlayerView.swift` so the first `.bufferFinished` autoplay enforcement also updates the local `isPlaying` value with the action that was actually applied.
- When `auto_play_on_enter` is disabled, the player still loads, then pauses, and now explicitly reports paused state to the parent view.

## Why

The previous fix paused the KSPlayer layer after buffering, but then continued to copy `state.isPlaying` from the original `.bufferFinished` callback. That old value could remain true even after `layer.pause()`, leaving SwiftUI and `VideoDetailView` believing playback was active. This broke double-tap play/pause semantics and prevented the paused-only scroll collapse behavior.

## Mistakes Or Failed Attempts

- The first autoplay-disabled loading fix handled the media loading behavior but missed the SwiftUI playing-state mirror used by controls and parent layout.

## Verification

- `git diff --check` passed.
- `./gradlew :shared:jvmTest` passed on local Linux aarch64. Kotlin/Native remains unsupported on this host, so the iOS Swift build is verified through GitHub Actions with `--exit-status`.

## Known Limits

- This fixes state mirroring for the autoplay-disabled startup pause. It does not change KSPlayer's underlying state enum semantics.
