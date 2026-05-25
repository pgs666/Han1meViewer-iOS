# Agent Log: Validate Mutation HTTP Status

Time: 2026-05-26 02:22:00 +08:00

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

- Added a shared mutation status guard for non-2xx HTTP responses.
- Applied it to video favorite/list/subscription mutations.
- Applied it to comment post/reply/reaction/report mutations.
- Applied it to user list and online watch history deletion mutations.
- Added JVM tests for success and failure status handling.

## Why

The review identified that several mutation endpoints ignored failed HTTP statuses and could leave the UI assuming success. Checking response status converts failed mutations into domain errors so callers can roll back or show the existing action error flow.

## Verification

Planned verification for this change:

- Run `git diff --check` locally.
- Run shared JVM tests locally.
- Push the code change and wait for the iOS app build workflow.

## Known Limits And Follow-up

- Online watch history deletion still performs its existing JSON `success` validation after the HTTP status check.
- This validates transport-level success; endpoint-specific JSON validation can be added for other mutation endpoints if the API returns reliable mutation bodies.
