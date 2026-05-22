# Agent Log: Fix Video Upload Date Regex Groups

Time: 2026-05-22 10:55 +08:00

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## User Input

Original:

```text
验证 suspend 函数调用 —— 在 SharedSmokeTest 里加一个 suspend fun fetchSomething() 的方法，用 Ktor 发一个真实 HTTP
请求，在 Swift 端用 async/await 调用它。这会同时验证：
- suspend 函数的 Swift 互操作
- Ktor Darwin 引擎在 iOS 上能跑
- async/await 桥接  日常开发循环（Windows）：
```

English translation:

```text
Verify suspend function calls: add a suspend fun fetchSomething() method in SharedSmokeTest, use Ktor to make a real HTTP request, and call it from Swift with async/await. This will verify:
- Swift interop for suspend functions
- The Ktor Darwin engine can run on iOS
- async/await bridging. Daily development loop on Windows:
```

## What Went Wrong

Running the new Windows local command failed:

```powershell
.\gradlew.bat :shared:jvmTest
```

Failure:

```text
KsoupHtmlParserTest[jvm] > parsesVideoSourcesAndTags[jvm] FAILED
java.lang.IndexOutOfBoundsException at KsoupHtmlParserTest.kt:80
```

Cause:

- `KsoupHtmlParser.parseVideo` reused Android-style group indexing.
- The KMP parser regex `(.+?)\s*(\d{4}-\d{2}-\d{2})` has two capture groups.
- The code incorrectly read group `3` for upload date and group `2` for views.

## What I Changed

Updated the group indexes:

```kotlin
val uploadTime = uploadGroups?.get(2)?.value
val views = uploadGroups?.get(1)?.value?.trim()
```

## Why

This is exactly why adding `:shared:jvmTest` is useful: it catches shared parser bugs on Windows before waiting for macOS CI.

## Verification

Verification is run immediately after this fix with:

```powershell
.\gradlew.bat :shared:jvmTest
```
