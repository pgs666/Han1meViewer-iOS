# PaginatedViewModel Base Class + SEC-2 Fix

Date: 2026-05-26 05:30:00 +08:00

## What Changed

### Q-3: Extract PaginatedViewModel base class

Created `PaginatedViewModel<S: PaginatedSnapshot>` base class that encapsulates:
- State enum (`.idle/.loading/.loaded/.loadingMore/.failed`)
- `requestGeneration` tracking and generation guard
- `loadTask` / `loadMoreTask` lifecycle management
- `load()`, `loadIfNeeded()`, `loadMoreIfNeeded(currentItemID:)`, `cancelLoading()`
- `applyLoadResult()`, `applyLoadError()`, `setFailed()` helper methods

Created `PaginatedSnapshot` protocol with:
- `page`, `hasNext`, `loadMoreError`, `lastItemID`, `withLoadMoreError(_:)`

Refactored all 5 ViewModels to inherit from base class:
- `FollowingViewModel: PaginatedViewModel<FollowingScreenSnapshot>`
- `OnlineWatchHistoryViewModel: PaginatedViewModel<OnlineWatchHistoryScreenSnapshot>`
- `UserVideoListViewModel: PaginatedViewModel<UserVideoListScreenSnapshot>`
- `UserPlaylistViewModel: PaginatedViewModel<UserPlaylistScreenSnapshot>`
- `SearchViewModel: PaginatedViewModel<SearchScreenSnapshot>`

Updated all 4 Views to use `viewModel.state.isLoading` and `loadMoreIfNeeded(currentItemID:)`.

### SEC-2: Add cookie import validation

`WebLoginFeature.importCookieHeader()` now validates imported cookies by calling `verifyCurrentSession()` after saving. If validation fails, cookies are cleared and a `DomainException` is thrown.

## Why

Q-3: 5 ViewModels had identical State enums, generation tracking, load/cancel patterns, and error handling. Extracting into a base class eliminates this duplication.

SEC-2: `importCookieHeader` was the only cookie import path without server-side validation.

## Verification

- CI build passed for all changes
- All ViewModel subclasses override `executeLoad()` with domain-specific logic
- `PaginatedSnapshot.lastItemID` replaces the various `videos.last?.id` / `results.last?.id` / `playlists.last?.id` patterns

## Known Limits

- Q-11 (@ObservedObject coupling) still pending
- SearchViewModel overrides `load()` to delegate to `search()` — slightly non-standard but preserves the existing API

## User Input

Original:

```
目前文件夹里有两个库，一个是原版，一个是iOS移植版，review结果在review文件夹里面，我需要你创建新的分支，基于review结果进行优化（只需要修复bug和性能问题还有代码质量问题，不需要添加新功能）
```

English translation:

```
There are two libraries in the folder — the original and an iOS port. Review results are in the review folder. I need you to create a new branch and optimize based on the review results (only fix bugs, performance issues, and code quality issues — no new features).
```
