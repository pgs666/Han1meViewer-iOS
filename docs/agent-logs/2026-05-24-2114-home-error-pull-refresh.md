## User Input

Original:

```text
然后首页遇到加载失败之后的页面也要支持下拉刷新
```

English translation:

```text
Also, when the home page hits a loading failure, that page should support pull-to-refresh too.
```

## Change

- Wrapped the home error state in a `ScrollView`.
- Kept the existing `.refreshable` on the home content so the failed state can be pulled down to retry.
- Preserved the centered error layout with enough scrollable height to make pull-to-refresh available.

## Why

- SwiftUI pull-to-refresh only works on scrollable content. The previous error `VStack` filled the screen but was not scrollable.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI after commit and push.
