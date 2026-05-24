# Fix Settings Section Builder

## User Input

Original:

```text
继续完成下一步
```

English translation:

```text
Continue completing the next step.
```

## What Changed

- Rewrote the Settings local-data section to use an explicit header/footer section builder.
- Moved the two destructive local-data buttons into a small `localDataActions` view builder.

## Why

GitHub Actions failed during Swift compilation because the shorthand section initializer with a footer was not inferred correctly for the iOS 15-compatible build.

## Mistakes Or Failed Attempts

- The previous commit used `Section("本地数据") { ... } footer: { ... }`, which compiled poorly in CI and failed with a generic inference error.

## Verification

- Pending local KMP test and GitHub Actions iOS build rerun.

## Known Limits

- This is only a build compatibility fix; it does not change the settings behavior.
