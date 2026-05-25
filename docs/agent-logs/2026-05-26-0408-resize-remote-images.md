# Agent Log: Resize Remote Images

Time: 2026-05-26 04:08:00 +08:00

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

- Added Nuke `ImageRequest` support to `CachedRemoteImage` with an optional resize width.
- Passed resize widths at every current `CachedRemoteImage` call site based on the displayed image size.
- Kept the home banner at a larger requested width while constraining row thumbnails and avatars to their smaller displayed widths.

## Why

The review identified that remote images were displayed in small frames but fetched/decoded without size constraints. Supplying resize processors reduces unnecessary decoded image memory and improves scrolling behavior for thumbnail-heavy lists.

## Verification

Planned verification for this change:

- Run `git diff --check` locally.
- Push the Swift/Nuke change and wait for the relevant GitHub Actions workflow.
