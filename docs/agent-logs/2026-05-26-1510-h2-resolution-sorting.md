# H2: Sort playback sources by resolution

Date: 2026-05-26 15:10:00 +08:00

## What Changed

Added `RESOLUTION_ORDER` map and `sortedByDescending` to `KsoupHtmlParser` so playback sources are ordered 2160P → 1440P → 1080P → 720P → 480P → 360P → 240P → auto.

## Why

iOS was using HTML document order for playback sources. If the site changes its HTML order, the default source might not be the highest quality. Android uses `HanimeResolution` for the same purpose.

## Verification

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.

## Review Reference

`Han1meViewer-iOS-review/review-ios-vs-android.md` — H2

## User Input

Original:

```text
查看review文件夹，听从里面的建议，并修复你觉得有价值的问题，一次修复一个并推送等待ci
```

English translation:

```text
Check the review folder, follow the suggestions, and fix issues you think are valuable. Fix one at a time, push and wait for CI.
```
