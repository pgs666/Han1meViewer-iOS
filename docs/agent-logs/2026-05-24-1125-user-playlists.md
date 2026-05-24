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

- Avoided player implementation changes.
- Added shared models for user playlists.
- Added playlist HTML parsing for `/user/{id}/playlists`.
- Added `UserPlaylistRepository`, `KtorUserPlaylistRepository`, and `UserPlaylistFeature`.
- Added Swift `UserPlaylistViewModel` and `UserPlaylistView`.
- Wired Mine's "播放清单" row to the real playlist list screen.

## Why

After watch later and favorites, the next Android drawer entry with a clear non-player vertical slice is the user's playlist collection. This keeps porting focused on real app functionality while leaving playback for the later rewrite.

## Mistakes Or Failed Attempts

- None.

## Verification

- `./gradlew :shared:jvmTest` passed locally on Windows.
- Pending: GitHub Actions iOS build.

## Known Limits

- This screen currently lists playlists only.
- Opening a playlist's videos, creating playlists, editing playlists, and deleting playlists are still future steps.
