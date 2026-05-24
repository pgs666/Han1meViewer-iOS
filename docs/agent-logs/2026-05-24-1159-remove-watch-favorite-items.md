## User Input

Original:

```text
继续完成下一步
```

English translation:

```text
Continue completing the next step.
```

## Changes

- Kept avoiding player implementation changes.
- Added KMP repository support for removing watch-later and favorite videos.
- Added `UserVideoListFeature.remove(videoCode:)`.
- Added swipe-to-delete support in Swift for watch later and favorite screens.
- Kept playlist detail video lists read-only.

## Why

Watch later and favorite lists were readable but not manageable. Swipe deletion is the smallest useful action that completes these list screens without touching playback.

## Mistakes Or Failed Attempts

- First local compile failed because `submitForm` request builders cannot call the suspend cookie injection helper directly. I added a cookie-header accessor and inject the preloaded header in the form request builder.
- The first GitHub Actions iOS build failed with a Swift compiler diagnostic crash in `UserVideoListView.content`, likely triggered by an optional `onDelete` closure inside a complex `@ViewBuilder` expression. I split removable and read-only rows into separate helper views.

## Verification

- `./gradlew :shared:jvmTest` passed locally on Windows after the cookie injection fix.
- GitHub Actions iOS build failed once on Swift compilation before the row builder split.
- Pending: rerun verification after the SwiftUI split.

## Known Limits

- Deletion is optimistic; if the website request fails, the screen reloads and shows an error.
- Playlist item deletion is not implemented yet because it uses a separate playlist-specific endpoint.
