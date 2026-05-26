# H7: Stop aggressively clearing session on login verification

Date: 2026-05-26 14:10:00 +08:00

## What Changed

- `verifyCurrentSession`: Use only `userId` as login signal (not `|| username`), matching Android.
- `importCookieHeader`: Don't clear session on parse failure or invalid session; throw but preserve cookies.
- `currentSessionSnapshot`: Don't clear session on transient parse failures; only clear when confirmed logged out.

## Why

iOS was too aggressive in clearing session cookies:
1. Using `username` as a secondary login signal caused false negatives when the site changed its HTML.
2. Clearing all cookies on any parse failure (including transient network issues) forced users to re-login via WebView.
3. Android does not clear cookies on transient failures — it only clears when explicitly confirmed on the login page.

## Verification

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest` passed (all 7 tests).
- `git diff --check` passed.

## Review Reference

`Han1meViewer-iOS-review/review-ios-vs-android.md` — H7

## User Input

Original:

```text
查看review文件夹，听从里面的建议，并修复你觉得有价值的问题，一次修复一个并推送等待ci
```

English translation:

```text
Check the review folder, follow the suggestions, and fix issues you think are valuable. Fix one at a time, push and wait for CI.
```
