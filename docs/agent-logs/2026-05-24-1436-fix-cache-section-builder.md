# Fix Cache Section Builder

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

- Rewrote the cache Settings section to use explicit header and footer builders.

## Why

GitHub Actions failed during Swift compilation because `Section("缓存") { ... } footer: { ... }` hit the same generic inference problem as the previous Settings section shorthand.

## Mistakes Or Failed Attempts

- The initial cache Settings implementation repeated a shorthand `Section` style that is not reliable for the current iOS 15-compatible build.

## Verification

- Pending local KMP test and GitHub Actions iOS build rerun.

## Known Limits

- This is only a SwiftUI build compatibility fix; cache behavior is unchanged.
