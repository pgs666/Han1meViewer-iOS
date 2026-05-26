# White Refresh Button

Date: 2026-05-26 12:42:00 +08:00

## What Changed

Changed toolbar refresh button icon color from red (inherited from tint) to white across:
- FollowingView
- OnlineWatchHistoryView
- UserVideoListView
- UserPlaylistView

## Why

The refresh button was inheriting the app's red tint color, but turned white when disabled/loading. User requested consistent white color from the start.

## Verification

- `git diff --check` passed locally.

## User Input

Original:

```text
当前页面顶端的刷新按钮在点击之后会变成白色，要么一开始就设置成白的好了，不要用红色了
```

English translation:

```text
The refresh button at the top of the page turns white after clicking. Just set it to white from the start, don't use red.
```
