# Fix Search History and Related Images

Date: 2026-05-26 11:46:00 +08:00

## What Changed

- Preserved `SearchViewModel.search(recordHistory:)` through the pagination refactor.
- Added `resetPaginationToIdle()` so returning to search history cancels stale loads and invalidates their generation.
- Switched related video thumbnails from `AsyncImage` to `CachedRemoteImage` with resize processors.
- Removed a trailing blank line at EOF reported by `git diff --check`.

## Why

The previous pagination refactor accidentally forced all first-page searches into history, including launch requests that explicitly passed `recordHistory: false`. It also left a stale-load race when returning to the search history screen. Related video thumbnails bypassed the Nuke cache/resize path introduced earlier.

## Verification

- `git diff --check` passed locally.
- CI is required after commit because the touched files include Swift UI code.

## User Input

Original:

```text
修复上面你觉得有价值的问题
```

English translation:

```text
Fix the issues above that you think are valuable.
```
