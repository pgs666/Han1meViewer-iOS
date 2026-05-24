# Clear Cache Setting

## User Input

Original:

```text
然后在设置里面加清除缓存的功能（并在按钮里面统计当前缓存的大小），继续完成下一步
```

English translation:

```text
Then add a clear-cache feature in Settings, and show the current cache size inside the button. Continue completing the next step.
```

## What Changed

- Added `CacheStorage` for measuring and clearing the app Caches directory.
- Added a Settings cache section with a destructive "清除缓存（size）" button.
- Refreshes the displayed cache size when Settings appears and before clearing.
- Clears `URLCache` responses in addition to deleting files under the app Caches directory.

## Why

Images and network temporary files can grow over time, so Settings needs a direct cache cleanup action with visible current usage.

## Mistakes Or Failed Attempts

- None so far.

## Verification

- Pending local KMP tests and GitHub Actions iOS build.

## Known Limits

- The size is based on files in the app Caches directory. In-memory image cache may remain until the app naturally releases it or restarts.
- The cache cleanup intentionally does not remove login cookies, SQLDelight databases, search history, or watch history.
