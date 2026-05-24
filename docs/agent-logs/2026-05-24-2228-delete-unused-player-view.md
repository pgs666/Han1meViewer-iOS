# Delete Unused PlayerView

## User Input

Original:

```text
PlayerView.swift 仍然存在，未被引用，可以删除
```

English translation:

```text
PlayerView.swift still exists, is unreferenced, and can be deleted.
```

## Changes

- Removed the obsolete `iosApp/PlayerView.swift` file.
- Confirmed playback is now handled by the current video detail page implementation instead of this unused standalone view.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only an existing line-ending warning for `iosApp/AppOrientationController.swift`.
