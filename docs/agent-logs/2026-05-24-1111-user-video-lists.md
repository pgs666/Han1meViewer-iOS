## User Input

Original:

```text
继续下一步
```

English translation:

```text
Continue to the next step.
```

## Changes

- Avoided player implementation changes as requested earlier.
- Added shared `UserVideoListType` and `UserVideoListPage` models.
- Added parser support for website user video lists such as watch later and favorite videos.
- Added `UserVideoListRepository` and `KtorUserVideoListRepository`.
- Added `UserVideoListFeature`, which resolves the current user id from the home page and loads the selected user list.
- Added Swift `UserVideoListViewModel` and `UserVideoListView`.
- Wired Mine's "稍后观看" and "收藏影片" rows to real list screens instead of placeholder alerts.

## Why

The Mine tab still had important Android drawer entries that were placeholders. Watch later and favorites are useful non-player vertical slices because they reuse login cookies, the current user id, Ktor requests, HTML parsing, Swift ViewModel state, pagination, cached images, and navigation.

## Mistakes Or Failed Attempts

- None.

## Verification

- `./gradlew :shared:jvmTest` passed locally on Windows.
- Pending: GitHub Actions iOS build.

## Known Limits

- The new screens are read-only. Removing items from watch later or favorites is not implemented yet.
- The feature currently reloads the home page to resolve `userId` for each list load. This is simple and correct for now, but can be cached after more account features land.
