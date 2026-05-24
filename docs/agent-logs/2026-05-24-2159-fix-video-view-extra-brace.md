# Fix Video View Extra Brace

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

- Fixed the Swift syntax error reported by GitHub Actions: `VideoDetailView.swift` had one extra closing brace after the new adaptive video page layout was inserted.
- Kept the default branch workflow behavior unchanged and did not manually trigger a new GitHub Actions run.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- No manual GitHub Actions run was triggered for this fix.
