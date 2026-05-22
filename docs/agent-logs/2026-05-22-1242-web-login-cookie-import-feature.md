# Agent Log: Web Login Cookie Import Feature

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
登录界面在安卓上是一个网页，ios上这个没法正常登录的
```

English translation:

```text
The login screen on Android is a web page; on iOS this cannot log in normally.
```

## Changes

- Added `WebLoginFeature` in the shared KMP auth layer.
- Added `SharedAppEnvironment.webLoginFeature()` so Swift can import cookies into the same SQLDelight-backed session store used by Home and Video repositories.
- Added a JVM unit test that imports a browser-style cookie header and confirms the login session cookie is saved.

## Why

Android supports WebView login and extracts cookies from the platform browser cookie store. iOS needs the same shape: let the website handle login in a real web view, then pass the resulting cookies back into KMP so Ktor requests can reuse the authenticated session.

## Verification

- Pending `./gradlew :shared:jvmTest`.

## Known Limits

- This feature imports the cookie names and values from a header string. It does not preserve browser cookie expiry metadata yet.
