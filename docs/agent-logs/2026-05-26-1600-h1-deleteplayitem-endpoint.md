# H1: 统一使用 /deletePlayitem 端点删除收藏和稍后观看

## 原始输入
H1. 删除收藏 / 删除稍后再看用了不同端点 — Android 统一用 deletePlayitem 端点，iOS 用 /save 和 /like 端点，导致多一次 HTML 抓取和潜在失败。

## English Summary
Aligned iOS deletion of favorites and watch-later with Android's verified `/deletePlayitem` endpoint. Removed the extra GET request to fetch video page before deleting favorites. Both types now use the same endpoint with `playlist_id` set to `"likes"` or `"saves"` matching Android's `MyListType` enum values.

## Changes
- `KtorUserVideoListRepository.kt`: Replaced separate `/save` and `/like` endpoints with unified `/deletePlayitem`
- Removed `getVideoForMutation()` helper (no longer needed)
- Removed unused `HanimeVideo` import
