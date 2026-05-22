# Agent Log: Fix Premature Web Login Success

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
现在还是有问题：一打开网页就提示已登录，然后退出登录页面
```

English translation:

```text
There is still a problem now: as soon as the web page opens, it says logged in and exits the login screen.
```

## Changes

- Stopped importing login cookies from `WKWebView.didFinish` on the `/login` page.
- Only confirms login when the WebView navigates to a `hanime1.me` URL whose path is not `/login`.
- Added `WebLoginFeature.importConfirmedLoginCookieHeader(...)`.
- Changed `currentSessionSnapshot()` to read an app-owned confirmed-login marker instead of treating any `hanime1_session` cookie as proof of login.
- Added tests proving that a plain session cookie does not report logged in.

## Why

The login page itself can set normal website session cookies before the user authenticates. Those cookies are needed for the web page but are not proof that the account login succeeded.

## Verification

- Pending `./gradlew :shared:jvmTest`.
- Pending GitHub Actions iOS app build.

## Known Limits

- Login confirmation is based on the site redirecting away from `/login`. If the site changes to an in-place login flow without navigation, this will need a stronger page-state check.
