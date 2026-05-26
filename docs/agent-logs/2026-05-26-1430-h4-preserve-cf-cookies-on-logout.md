# H4: Preserve CF cookies on logout

Date: 2026-05-26 14:30:00 +08:00

## What Changed

- Added `deleteNonCloudflare` SQL query to `SessionCookie.sq`.
- Added `clearLoginCookies()` to `SessionStore` interface — deletes all cookies except `cf_clearance`.
- Updated `SqlDelightSessionStore`, `MemorySessionStore` to implement `clearLoginCookies()`.
- Changed `WebLoginFeature.clearSession()` and `HomeFeature` to use `clearLoginCookies()` instead of `clear()`.

## Why

iOS was calling `sessionStore.clear()` on logout, which deleted ALL cookies including `cf_clearance`. This caused:
1. Immediate Cloudflare challenge after logout.
2. Unnecessary CF challenge escalation for the IP.

Android only clears login cookies and preserves `cf_clearance`. This fix aligns iOS behavior.

## Verification

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.

## Review Reference

`Han1meViewer-iOS-review/review-ios-vs-android.md` — H4

## User Input

Original:

```text
查看review文件夹，听从里面的建议，并修复你觉得有价值的问题，一次修复一个并推送等待ci
```

English translation:

```text
Check the review folder, follow the suggestions, and fix issues you think are valuable. Fix one at a time, push and wait for CI.
```
