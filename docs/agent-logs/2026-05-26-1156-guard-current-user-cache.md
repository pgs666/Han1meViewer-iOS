# Guard Current User Cache

Date: 2026-05-26 11:56:00 +08:00

## What Changed

- Added a generation token to `SharedAppEnvironment`'s cached current user id.
- Invalidated in-flight user-id resolution when the session is cleared.
- Kept the fast cached read path, but only when the cached value matches the active generation.

## Why

The cache was already stored in an atomic reference, but an in-flight `resolveCurrentUserId()` could still fetch the old user id and write it back after `clearCachedCurrentUserId()` had cleared the cache. The generation guard prevents stale user ids from being re-cached across logout or session expiry.

## Verification

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew --parallel --max-workers=$(nproc) :shared:jvmTest` passed locally.
- `git diff --check` passed locally.
- Gradle/Kotlin daemon check returned no remaining `GradleDaemon` or `KotlinCompileDaemon` processes.
- CI is required after commit because this changes shared KMP code.

## User Input

Original:

```text
修复上面你觉得有价值的问题
```

English translation:

```text
Fix the issues above that you think are valuable.
```
