## User Input

Original:

```text
要记录进入全屏前的屏幕方向，退出全屏后自动切回原本的屏幕方向
```

English translation:

```text
Record the screen orientation before entering fullscreen, and automatically switch back to the original screen orientation after exiting fullscreen.
```

## Change

- Updated `AppOrientationController` to save the current interface orientation and supported orientation mask when entering fullscreen.
- Exiting fullscreen now restores the recorded orientation instead of always requesting portrait.
- Repeated fullscreen metric updates no longer overwrite the original pre-fullscreen orientation.

## Why

- The user can enter fullscreen from either portrait or landscape. Exiting should return to the orientation they came from.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI after commit and push.
