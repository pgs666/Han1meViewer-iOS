# Adaptive Refresh Button Color

Date: 2026-05-26 13:05:00 +08:00

## What Changed

Changed toolbar refresh button from `.foregroundStyle(.white)` to `.foregroundStyle(.primary)` across:
- FollowingView
- OnlineWatchHistoryView
- UserVideoListView
- UserPlaylistView

## Why

`.white` was invisible in light mode. `.primary` adapts automatically: black in light mode, white in dark mode.

## Verification

- `git diff --check` passed locally.

## User Input

Original:

```text
你想想这个按钮在亮色模式下是不是该是黑色的？你怎么不写自适应的
```

English translation:

```text
Think about it - shouldn't this button be black in light mode? Why didn't you make it adaptive?
```
