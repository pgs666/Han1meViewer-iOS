# Agent Log: Add Coroutines Test Dependency

Time: 2026-05-22 10:22 +08:00

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## What I Changed

1. Added `kotlinx-coroutines-test` to the version catalog.
2. Added `libs.coroutines.test` to `commonTest.dependencies`.
3. Imported the shared `runTest` helper in `CookieHeaderProviderTest`.

## Why

`CookieHeaderProvider` has suspend functions, so its common tests need a coroutine test runner.
