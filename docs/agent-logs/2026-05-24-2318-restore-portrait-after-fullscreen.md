# Restore Portrait After Fullscreen Video

## User Input

Original:

```text
从全屏中退出到详情页，依然是横屏
```

English translation:

```text
After exiting fullscreen back to the detail page, it is still in landscape.
```

## Changes

- Strengthened orientation restoration after fullscreen playback.
- `AppOrientationController` now explicitly requests the current allowed orientation after restoring the orientation mask.
- iOS 16+ geometry updates now also ask the root view controller to refresh supported orientations.
- Added a parent `fullScreenCover` `onDismiss` correction so the detail page re-applies the restored orientation after the fullscreen cover is gone.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only existing line-ending warnings for edited Swift files.
- Final behavior still needs iPhone device verification because this Windows environment cannot run the iOS app.
