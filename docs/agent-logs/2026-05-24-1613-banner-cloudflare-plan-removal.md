## User Input

Original:

```text
先做banner跳转，然后做cloudflare，可以删除掉当前的md文件了
```

English translation:

```text
Do the banner navigation first, then Cloudflare handling. The current Markdown file can be deleted.
```

## What Changed

- Deleted `docs/iOS-PORTING-PLAN.md`.
- Added banner image, description, and video code fields to the home snapshot exposed by `HomeFeature`.
- Updated the Swift home view model and home view so the banner can show its image and navigate to `VideoDetailView` when a video code is available.
- Added `DomainException` as a throwable wrapper for shared domain errors.
- Added Cloudflare challenge detection to the shared Ktor client for HTTP 403 responses with Cloudflare headers.

## Why

- The home parser already captured banner metadata, but the feature snapshot discarded everything except the title.
- The app needed a first Cloudflare handling step before deeper write operations, so blocked requests are surfaced as a clear domain failure instead of being parsed as normal HTML.
- The temporary implementation plan was no longer aligned with the current order because player-related work is intentionally postponed.

## Mistakes Or Failed Attempts

- No failed implementation attempt in this step.

## Verification

- Pending local Gradle verification and GitHub Actions iOS build after this change.

## Known Limits

- This does not add a full WKWebView Cloudflare challenge recovery screen yet.
- It does not modify player behavior or playback progress tracking.
