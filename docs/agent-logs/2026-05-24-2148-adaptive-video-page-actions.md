# Adaptive Video Page And Actions

## User Input

Original:

```text
我希望播放页的页面能够自适应iPad和iPhone，iPad版的页面我希望能和图上类似，同样要求使用纯swiftUI实现
然后我还希望播放页的那些按钮都接入实际功能
```

English translation:

```text
I want the playback page to adapt to both iPad and iPhone. For the iPad version, I want the page to look similar to the screenshot, and it should also be implemented with pure SwiftUI.
I also want those buttons on the playback page to be connected to real functionality.
```

## Changes

- Added video detail mutation APIs in the KMP shared layer for favorite and playlist/watch-later updates.
- Passed video page CSRF token and current user id through `VideoDetailSnapshot` to Swift.
- Added Swift ViewModel actions for toggling favorite, toggling watch later, and updating playlist membership.
- Added a wide iPad layout that keeps the player/detail column on the left and shows related videos as a right-side list.
- Kept the iPhone layout as the existing single-column SwiftUI page.
- Connected video page buttons to real actions where available:
  - Favorite toggles site favorite state.
  - Watch later toggles the site save list.
  - Playlist opens a list selector and updates the chosen playlist.
  - Download opens the official download page.
  - Original comic and web page buttons open their URLs.

## Notes

- The player implementation itself was not deeply refactored; this keeps the user's plan to fully rebuild the player later intact.
- Share still needs a dedicated native `ShareLink` replacement if the current web-opening behavior is not sufficient.
- The first local KMP compile failed because `KtorVideoRepository` tried to call the suspending cookie bridge helper inside a non-suspending `submitForm` request builder. This was corrected by reading the stored cookie header before building the request, matching the existing user-list repository pattern.

## Verification

- `./gradlew :shared:jvmTest` passed after fixing the cookie header issue.
- `git diff --check` passed.
- GitHub Actions iOS build is pending.
