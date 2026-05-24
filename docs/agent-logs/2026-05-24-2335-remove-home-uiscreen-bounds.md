# Remove UIScreen Bounds From Home View

## User Input

Original:

```text
仅剩的小问题：

- UIScreen.main.bounds 仍存在于 HomeView.swift 第 51 行和第 115 行（第 115 行是本次新增的 banner 布局代码）
```

English translation:

```text
Only small issues remain:

- UIScreen.main.bounds still exists in HomeView.swift line 51 and line 115. Line 115 is the newly added banner layout code.
```

## Changes

- Replaced the failed-state minimum height calculation with a `GeometryReader` container height.
- Replaced the banner height calculation with SwiftUI `aspectRatio`, so it no longer depends on global screen bounds.
- Kept the current iPad compact banner width cap.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only an existing line-ending warning for `iosApp/HomeView.swift`.
- `rg` found no remaining `UIScreen.main.bounds` usage in `iosApp` or `shared`.
- Swift compilation still needs CI or Xcode verification.
