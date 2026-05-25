# Review Batch Fixes

Date: 2026-05-26 04:10:00 +08:00

## What Changed

Batch of fixes based on comprehensive review audit (review/ and review-2/).

### 1. Make `HanimeInfo.videoCode` non-nullable (Q-9)

- Changed `val videoCode: String?` to `val videoCode: String` in `HanimeModels.kt`
- Removed redundant `mapNotNull { item.videoCode ?: return@mapNotNull null }` patterns in 6 consumer files:
  - `SearchFeature.kt`
  - `HomeFeature.kt`
  - `OnlineWatchHistoryFeature.kt`
  - `UserVideoListFeature.kt` (2 occurrences)
  - `VideoFeature.kt` (2 occurrences)
- The parser (`KsoupHtmlParser.kt`) already filters null videoCode at construction time, so the model was needlessly nullable.

### 2. Add `requireSuccessfulMutation` to `setMyListItem` (HIGH-3)

- `KtorVideoRepository.setMyListItem()` was the only mutation method missing response validation
- Added `requireSuccessfulMutation(response, "Failed to update list state.")` after the response

### 3. Add generation guard to `like()` (HIGH-7)

- `CommentViewModel.like()` created a bare `Task` without checking `requestGeneration`
- Added `let generation = requestGeneration` capture and `guard generation == self.requestGeneration` check
- Prevents stale like requests from a previous load cycle from mutating state

### 4. Standardize metadata separators (Q-14)

- HomeView and SearchView used `" · "`, others used `" / "`
- Standardized all to `" · "` in:
  - `FollowingViewModel.swift`
  - `OnlineWatchHistoryViewModel.swift`
  - `UserVideoListViewModel.swift`
  - `VideoDetailViewModel.swift`

## Why

These address remaining issues from two rounds of code review. Q-9 eliminates repetitive null-check boilerplate across the codebase. HIGH-3 and HIGH-7 fix correctness bugs. Q-14 fixes inconsistent user-facing formatting.

## Verification

- CI build passed (GitHub Actions run 26418740750, 3m42s)
- All JVM tests passed
- iOS device build succeeded
- IPA packaging succeeded

## Known Limits

- CRIT-4/SEC-1 (Keychain migration) not addressed — requires new KMP dependency and expect/actual implementation
- Q-1/Q-2 (giant files), Q-3/Q-4 (pagination abstraction), Q-11 (@ObservedObject coupling) not addressed — structural refactoring for future iteration
- SEC-2 is a false positive — `importCookieHeader` is not called from production code

## User Input

Original:

```
目前文件夹里有两个库，一个是原版，一个是iOS移植版，review结果在review文件夹里面，我需要你创建新的分支，基于review结果进行优化（只需要修复bug和性能问题还有代码质量问题，不需要添加新功能）
```

English translation:

```
There are two libraries in the folder — the original and an iOS port. Review results are in the review folder. I need you to create a new branch and optimize based on the review results (only fix bugs, performance issues, and code quality issues — no new features).
```
