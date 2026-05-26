# L1: 添加在线观看历史 Popular 排序

## User Input

Original:
L1. OnlineWatchHistorySort 缺 Popular 枚举值 — Android Latest / Popular / Oldest 三档，iOS 只有 Latest / Oldest

English translation:
L1. OnlineWatchHistorySort missing Popular enum value — Android has Latest / Popular / Oldest, iOS only has Latest / Oldest

## What Changed
- `HanimeModels.kt`: Added `Popular("popular")` to `OnlineWatchHistorySort` enum
- `OnlineWatchHistoryFeature.kt`: Added `loadPopular(page)` method
- `OnlineWatchHistoryViewModel.swift`: Added `case popular` to `SortMode` enum with localized title and load logic

## Why Changed
- Android supports 3 sort modes for online watch history
- iOS was missing the Popular sort option
- Review item L1 from `review-ios-vs-android.md`

## Verification
- CI pending

## Mistakes
- None

## Known Limits
- Need to add localized string for "online_history.sort.popular" in Localizable.strings
