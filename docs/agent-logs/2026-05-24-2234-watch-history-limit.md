# Limit Watch History Queries

## User Input

Original:

```text
之前提到的 Bug（未修复）

5. WatchHistory 无 LIMIT
```

English translation:

```text
Previously mentioned bugs that are not fixed yet:

5. WatchHistory has no LIMIT.
```

## Changes

- Added a `LIMIT ?` clause to the SQLDelight watch history recent query.
- Added a default recent-history limit of 100 items.
- Kept the existing Swift-facing `loadRecent()` API available and added a limited overload for future callers.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only existing line-ending warnings for edited watch history files.
