# H1: 统一使用 /deletePlayitem 端点

## User Input

Original:
H1. 删除收藏 / 删除稍后再看用了不同端点 — Android 统一用 deletePlayitem 端点，iOS 用 /save 和 /like 端点，导致多一次 HTML 抓取和潜在失败。

English translation:
H1. Deleting favorites/watch-later uses different endpoints — Android uses unified deletePlayitem endpoint, iOS uses /save and /like endpoints, causing an extra HTML fetch and potential failures.

## What Changed
- `KtorUserVideoListRepository.kt`: Replaced separate `/save` and `/like` endpoints with unified `/deletePlayitem`
- Use `playlist_id="likes"` for favorites, `"saves"` for watch-later (matching Android's `MyListType` enum)
- Removed `getVideoForMutation()` helper (no longer needed)
- Removed unused `HanimeVideo` import

## Why Changed
- Android's verified endpoint `/deletePlayitem` is simpler and more reliable
- iOS was making an extra GET request to fetch video page before deleting favorites
- Review item H1 from `review-ios-vs-android.md`

## Verification
- CI passed (run 26435366402, completed success)

## Mistakes
- None

## Known Limits
- None
