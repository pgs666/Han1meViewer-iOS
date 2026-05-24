# Fix Video Snapshot Copy Argument Order

## User Input

Original:

```text
现在用的是默认分支，不要手动触发一次编译了
```

English translation:

```text
We are on the default branch now. Do not manually trigger another build.
```

## Changes

- Fixed the Swift compile error from the automatic push build:
  - `copy(isFav:favTimes:)` used arguments in the wrong order.
  - Changed it to `copy(favTimes:isFav:)` to match the method signature.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- No manual GitHub Actions run will be triggered.
