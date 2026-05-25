# Agent Log: History Retention Limits

Time: 2026-05-26 01:28:54 +08:00

Repository: `/home/pgs/Project/Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## User Input

Original:

```text
修复上面你觉得有价值的问题
```

English translation:

```text
Fix the issues above that you think are valuable.
```

## What Changed

- Added SQLDelight prune queries for local watch history and search history.
- `WatchHistoryStore.record(...)` now keeps only the most recent 1000 items.
- `SearchHistoryStore.record(...)` now keeps only the most recent 100 items.
- Added store-level tests for both retention limits.

## Why

The review noted that both local history tables could grow without bound. Retention limits prevent unbounded database growth while preserving the newest entries users actually access.

## Verification

Planned verification for this change:

- Run targeted JVM tests for `WatchHistoryStoreTest` and `SearchHistoryStoreTest`.
- Run `git diff --check`.
- Push the code change and wait for the iOS app build workflow.

## Known Limits And Follow-up

- The retention limits are fixed constants for now.
- This does not address plaintext cookie storage; that still needs a separate Keychain migration.
