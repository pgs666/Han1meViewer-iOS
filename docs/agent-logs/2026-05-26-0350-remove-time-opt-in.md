# Agent Log: Remove Time Opt-In

Time: 2026-05-26 03:50:00 +08:00

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

- Removed the stale `ExperimentalTime` import and `@OptIn(ExperimentalTime::class)` annotation from `TimeProvider`.

## Why

The review identified unnecessary experimental time opt-ins as code noise. The project uses Kotlin 2.3.x, where `kotlin.time.Clock.System.now()` no longer requires this opt-in, so keeping the annotation makes the shared utility look riskier than it is.

## Verification

Planned verification for this change:

- Run `git diff --check` locally.
- Run `:shared:jvmTest` with JDK 21.
- Stop Gradle/Kotlin daemons after local JVM verification.
- Push the change and wait for the relevant GitHub Actions workflow.
