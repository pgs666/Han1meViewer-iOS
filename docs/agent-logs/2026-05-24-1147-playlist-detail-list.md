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
- Added KMP loading for videos inside a user playlist via `/playlist?list={listCode}`.
- Reused the existing user video list parser for playlist detail pages by supporting the website's `.playlist-video-list` container.
- Added `PlaylistVideoListFeature`.
- Updated Swift `UserVideoListViewModel` and `UserVideoListView` so they can load either watch/favorite lists or playlist-detail lists.
- Made playlist rows navigable to their video list.

## Why

The playlist collection screen was only an endpoint. Letting users open a playlist and view its videos completes the next useful non-player vertical slice.

## Mistakes Or Failed Attempts

- None.

## Verification

- `./gradlew :shared:jvmTest` passed locally on Windows.
- Pending: GitHub Actions iOS build.

## Known Limits

- Playlist video lists are still read-only.
- Creating, editing, deleting playlists, and removing videos from playlists remain future work.
