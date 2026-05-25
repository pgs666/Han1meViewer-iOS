# Pagination Abstraction

Date: 2026-05-26 04:30:00 +08:00

## What Changed

Extracted duplicated pagination code into shared components (Q-3, Q-4).

### New files
- `iosApp/PaginationState.swift` — Shared `PaginationState<Snapshot>` enum and `mergeByIdentifiable()` helper
- `iosApp/PaginationFooterView.swift` — Reusable pagination footer with loading spinner, error retry, and "loaded all" states

### Refactored Views (footer replacement)
- `FollowingView.swift` — replaced `followingFooter()` with `PaginationFooterView`
- `SearchView.swift` — replaced `searchFooter()` with `PaginationFooterView`
- `OnlineWatchHistoryView.swift` — replaced `footer()` with `PaginationFooterView`
- `UserPlaylistView.swift` — replaced `footer()` with `PaginationFooterView`
- `UserVideoListView.swift` — replaced `footer()` with `PaginationFooterView`

### Refactored ViewModels (merging helper replacement)
- `FollowingViewModel.swift` — replaced private `merging()` with shared `mergeByIdentifiable()`
- `SearchViewModel.swift` — same
- `OnlineWatchHistoryViewModel.swift` — same
- `UserPlaylistViewModel.swift` — same
- `UserVideoListViewModel.swift` — same

## Why

5 Views had identical copy-pasted footer code (~40 lines each). 5 ViewModels had identical `merging()` dedup helpers (~7 lines each). Extracting these into shared components eliminates ~180 lines of duplication.

## Verification

- All changes are pure refactoring — no behavior change
- Footer rendering logic is identical (same conditions, same UI)
- `mergeByIdentifiable` uses the same `Set`-based dedup algorithm

## Known Limits

- ViewModels still have duplicated State enums and loadMoreIfNeeded patterns — full ViewModel base class extraction would require more invasive refactoring
- Q-1/Q-2 (giant file splitting) not addressed in this commit

## User Input

Original:

```
目前文件夹里有两个库，一个是原版，一个是iOS移植版，review结果在review文件夹里面，我需要你创建新的分支，基于review结果进行优化（只需要修复bug和性能问题还有代码质量问题，不需要添加新功能）
```

English translation:

```
There are two libraries in the folder — the original and an iOS port. Review results are in the review folder. I need you to create a new branch and optimize based on the review results (only fix bugs, performance issues, and code quality issues — no new features).
```
