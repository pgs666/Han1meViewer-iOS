# Persist Download Covers

## User Input

Original:

```text
现在下载的视频没有封面，可以在下载的时候顺便把当前视频的封面存下来当作列表中的封面，然后删除的时候顺便清理掉，不要被当作缓存清除
```

English translation:

```text
Downloaded videos currently have no covers. Save the current video's cover while downloading and use it as the cover in the list, clean it up when deleting the download, and do not let cache clearing remove it.
```

## What Changed

- Added one persistent cover file per video/quality download entry.
- Cover downloads start asynchronously when a video is enqueued.
- Downloaded bytes are validated as a decodable image before being persisted.
- Existing download rows with a remote cover URL automatically backfill a missing local cover when `DownloadManager` is configured.
- The downloads list prefers the local cover and falls back to the remote image until persistence finishes or if it fails.
- Deleting a download cancels its cover request and removes its video, resume data, persistent cover, and database row together.

## Storage Decision

Cover files use the existing `Application Support/Downloads` directory alongside downloaded videos. `CacheStorage.clear()` only removes the app's caches directories and Nuke/URL caches, so persistent download covers are not treated as disposable cache data.

## Verification

- Confirmed the enqueue, startup backfill, list rendering, and deletion paths all use the same deterministic cover URL.
- Confirmed a deleted database row is checked before an asynchronously fetched cover can be written.
- Confirmed `CacheStorage` only clears `cachesDirectory`, not `applicationSupportDirectory`.
- Final JVM tests and iOS device build are performed by GitHub Actions after push.

## Known Limits

- If the remote cover request fails, the list continues using its existing remote-image fallback and retries backfill on the next app launch.
