# Agent Log: Cancellable List Loads

Time: 2026-05-26 03:42:00 +08:00

Repository: `/home/pgs/Project/Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## User Input

Original:

```text
修复上面你觉得有价值的问题
```

English translation:

```text
Fix the issues above that you think are valuable.
```

## What Changed

- Replaced top-level load-triggering `onAppear` usage with `.task` in online watch history, user playlists, and user video lists.
- Added `loadIfNeeded()` helpers so those views only perform the first load from the idle state.
- Added `cancelLoading()` helpers and call them from page-level `onDisappear` to cancel in-flight initial and pagination loads when the page is left.

## Why

The review identified view-level `onAppear` loads as a lifecycle problem because requests continue after the view disappears. FollowingView already used the cancellable pattern; these related paginated account/list pages now follow the same behavior.

## Verification

Planned verification for this change:

- Run `git diff --check` locally.
- Push the Swift change and wait for the relevant GitHub Actions workflow.
