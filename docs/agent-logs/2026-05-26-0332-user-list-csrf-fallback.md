# Agent Log: User List CSRF Fallback

Time: 2026-05-26 03:32:00 +08:00

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

- Added a shared mutation helper that chooses a preferred CSRF token only when it is non-blank.
- Used that helper when removing a favorite from a user video list so a blank video-page token does not override the already validated list token.
- Added unit coverage for the fallback behavior.

## Why

The review called out mutation requests sending empty CSRF tokens. Most mutation paths already validate tokens, but the favorites removal path could still use `video.csrfToken ?: token`; a blank parsed token is non-null and would be sent instead of the valid fallback token.

## Verification

Planned verification for this change:

- Run `git diff --check` locally.
- Run `:shared:jvmTest` with JDK 21.
- Stop Gradle/Kotlin daemons after local JVM verification.
- Push the change and wait for the relevant GitHub Actions workflow.
