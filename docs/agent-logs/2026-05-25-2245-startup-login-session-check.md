# 2026-05-25 22:45 Startup login session check parity

## Request

Continue reviewing the iOS/KMP port against the Android implementation and fix confirmed issues.

## Android reference

- Android upstream commit `6505b8b` adds startup login-state detection.
- Android `Parser.homePageVer2` treats a previously logged-in account whose home page no longer exposes user info as an expired login state.

## Finding

- The iOS port only verified login state from `MineViewModel.refreshLoginState()` when the user opened the Mine tab.
- If a confirmed web-login marker existed but the home page no longer exposed `userId` or `username`, `HomeFeature.loadHome()` still returned a logged-out home feed and left stale session cookies/cached user id intact.
- This made expired sessions harder to detect and differed from Android's startup/home-load behavior.

## Changes

- Added shared `LoginSessionMarker` so the confirmed-login marker is not duplicated between login import and home-load checks.
- Updated `HomeFeature` to clear the session and throw `DomainError.Auth` when a confirmed login marker exists but home user info is missing.
- Wired `SharedAppEnvironment.homeFeature()` with `SessionStore` and cache clearing so startup/home refresh invalidates stale current-user id.
- Added `HomeFeatureTest` coverage for expired confirmed sessions, anonymous sessions, and valid confirmed sessions.

## Validation

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest --parallel --max-workers=$(nproc) && git diff --check` passed locally.
- `./gradlew --stop` stopped the Gradle daemon.
- `ps -ef | grep -E 'GradleDaemon|KotlinCompileDaemon|[g]radle' | grep -v grep || true` returned no leftover Gradle/Kotlin daemon process.
