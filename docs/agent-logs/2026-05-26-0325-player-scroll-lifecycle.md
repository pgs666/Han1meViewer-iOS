# Agent Log: Player Scroll Lifecycle

Time: 2026-05-26 03:25:00 +08:00

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

- Moved `pausePlayer()` from the scrollable player header's `onDisappear` to the `VideoDetailView` page-level `onDisappear`.
- Kept player preparation on the header's `onAppear`, relying on the existing view model guard to avoid recreating the same player.

## Why

The review identified that `AndroidStylePlayerHeader` sits inside a `LazyVStack`, so SwiftUI can destroy and recreate the header during scroll. Pausing from the header lifecycle turns a scroll operation into a playback interruption. The page-level lifecycle better matches user intent: keep playback stable while scrolling inside the detail page, but pause and persist position when leaving the page.

## Verification

Planned verification for this change:

- Run `git diff --check` locally.
- Push the Swift change and wait for the relevant GitHub Actions workflow.
