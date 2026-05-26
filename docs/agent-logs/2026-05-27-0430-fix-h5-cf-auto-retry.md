# Fix H5: Cloudflare auto-retry after challenge resolution

Date: 2026-05-27 04:30 +08:00
Branch: fix/review-bugs-performance-quality
Commits: 26dd68e, 1940d8e, 91cfd50

## User Input

Original:

```text
也一并提交
```

English translation:

```text
Submit those as well.
```

(Context: User asked to fix and commit all remaining valuable review items including H5.)

## What Changed

### Shared layer (KMP)
- `CloudflareRetryHandler.kt`: New class with `signalResolved()` / `signalFailed()` methods using `CompletableDeferred` for coroutine suspension/resumption. Also has `retryAfterCloudflareResolution()` helper.

### iOS layer (Swift)
- `CloudflareRetryCenter.swift`: New class with:
  - `waitForResolution()`: Swift-native async waiting via `NotificationCenter`
  - `retryOnCloudflare()`: Wrapper that catches CF errors, shows challenge UI, waits for resolution, and retries
  - `signalResolved()` / `signalFailed()`: Bridges with KMP handler
- `CloudflareChallengeView.swift`: Calls `CloudflareRetryCenter.signalResolved()` on successful CF resolution
- `HomeViewModel.swift`: `loadHome()` uses `CloudflareRetryCenter.retryOnCloudflare {}`
- `VideoDetailViewModel.swift`: `loadVideo()` uses `CloudflareRetryCenter.retryOnCloudflare {}`
- `CommentViewModel.swift`: `loadComments()` uses `CloudflareRetryCenter.retryOnCloudflare {}`
- `PaginatedViewModel.swift`: `applyLoadError()` detects CF errors and auto-retries via `CloudflareRetryCenter`

## Why

Android uses `CountDownLatch` in `CloudflareInterceptor` to block OkHttp chain until CF challenge is resolved, then retries with `chain.proceed(request)`. iOS had no such mechanism — users had to manually refresh after CF resolution.

## Mistakes / Failed Attempts

1. First attempt tried calling KMP `suspend fun` with lambda parameters from Swift — KMP suspend functions with functional params don't translate to Swift closures properly. Error: `closure passed to parameter of type 'any KotlinSuspendFunction0'`.
2. Second attempt had extraneous `}` in CommentViewModel from regex replacement error.
3. Final approach: Keep KMP handler for signaling only, use Swift-native `NotificationCenter`-based async waiting for the retry loop.

## Verification

- Local JVM test: `:shared:jvmTest` — BUILD SUCCESSFUL
- CI run `26461493540` — success

## Known Limits / Follow-up

- `MineViewModel.refreshLoginState()` and `runAction()` methods still use the old `requestChallengeIfNeeded` pattern — these are mutation flows where auto-retry may not be desirable.
- The CF retry only retries once; if the challenge fails again, the error is shown to the user.
- `PaginatedViewModel.loadMore` CF errors are not auto-retried (only initial load).
