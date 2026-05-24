# Agent Log: Fix Auth Required Crash

## User Input

Original:

```text
# Files mentioned by the user:

## Han1meViewer-2026-05-24-150721.ips: C:/Users/PGS/Downloads/Han1meViewer-2026-05-24-150721.ips

## My request for Codex:
```

English translation:

```text
The user provided an iOS crash report file: C:/Users/PGS/Downloads/Han1meViewer-2026-05-24-150721.ips.
```

## Findings

- The crash report shows `EXC_CRASH / SIGABRT`.
- The last exception backtrace points to `UserVideoListFeature.load`.
- The immediate cause is Kotlin `IllegalStateException` from `error("Login is required before loading this list.")`.
- On iOS, this kind of Kotlin/Native exception can abort the app instead of being safely handled by Swift `do/catch`.

## Changes

- Replaced login-required `error(...)` paths in user list, playlist, online watch history, and following KMP flows with typed `authRequired` snapshot flags.
- Updated Swift ViewModels to show a login-required error message instead of treating that path as a thrown exception.

## Why

Login-required navigation is a normal app state, not a process-fatal condition. The app should show a user-facing message and keep running.

## Verification

- `.\gradlew :shared:jvmTest` passed locally.
- Scanned `shared/src/commonMain/kotlin` for remaining `error(...)` calls; none remain.
- iOS/Xcode verification is pending GitHub Actions.

## Known Limits

- This fixes the known crash from missing login state in account-bound list features. Other raw Kotlin exceptions may need the same treatment if future crash logs identify them.
