# Harden Current User Cache Token

Date: 2026-05-26 12:16:00 +08:00

## What Changed

- Replaced integer current-user cache generation with an object identity token.
- Compared cache tokens by reference identity so every clear operation creates a distinct invalidation marker.

## Why

Integer generation was better than a plain atomic cache, but `load() + 1` followed by `store()` could still lose increments if multiple session clears happened concurrently. A fresh object token avoids that lost-update case without adding a new dependency or changing the public API.

## Verification

- Pending local JVM validation and CI after commit.

## User Input

Original:

```text
修复上面你觉得有价值的问题
```

English translation:

```text
Fix the issues above that you think are valuable.
```
