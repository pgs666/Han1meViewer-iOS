# 对齐 Android：登录 cookie 导入时替换旧登录 cookie

## User Input

Original:
还是同样的问题，你先读明白了Android版收藏的代码再修改iOS版，不要瞎改了，在昨天上午的版本中收藏还是可用的

English translation:
Still the same problem. First understand the Android favorite code before modifying the iOS version. Don't make things up. In yesterday morning's version, favorite still worked.

## What Changed
- `WebLoginFeature.importConfirmedLoginCookies()` now calls `sessionStore.clearLoginCookies()` before saving newly imported login cookies
- Added regression test: confirmed login import replaces old login cookies while preserving `cf_clearance`

## Why Changed
- Android `login(cookies: String)` replaces `Preferences.loginCookie` as a whole string
- iOS was only upserting imported cookies, leaving old session/XSRF cookies in SQLDelight
- If a stale `hanime1_session` remains while the detail page provides a CSRF token from the new session, Laravel returns HTTP 419 on `/like`
- This aligns iOS login-cookie lifecycle with Android instead of changing `/like` request fields

## Verification
- Local targeted JVM tests passed:
  - `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest --tests '*WebLoginFeatureTest*' --tests '*CookieHeaderProviderTest*' --parallel --max-workers=$(nproc)`
- Stopped Gradle/Kotlin daemons after test
- CI pending

## Mistakes
- Previous fix only deduplicated cookie headers; that was insufficient because stale exact-domain cookies could still remain in the store

## Known Limits
- Existing users with stale cookies may need one fresh WebView login to replace old login cookies in the store
