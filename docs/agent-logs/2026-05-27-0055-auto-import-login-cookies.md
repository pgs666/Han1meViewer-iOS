# 修复 WebView 登录成功后不自动导入 cookie

## User Input

Original:
现在webview登录成功之后不会自动退出并导入cookie，需要手动点击上方的刷新才会正常登录成功，修复它

English translation:
After WebView login succeeds, it does not automatically close and import cookies. It only logs in successfully after manually tapping the top refresh button. Fix it.

## What Changed
- `LoginView.swift` now attempts cookie import from three signals:
  - WKWebView finishes loading a Hanime URL that is not `/login`
  - Navigation policy sees a Hanime URL that is not `/login`
  - `WKHTTPCookieStoreObserver.cookiesDidChange` fires after WebView writes cookies
- The old DOM heuristic is still kept, but now only as one additional signal.
- Opportunistic imports suppress error UI and rely on shared `importConfirmedLoginCookiesJson()` to verify the session.

## Why Changed
- The previous implementation only imported cookies when a fragile DOM heuristic detected logout/user-menu text.
- In the failing flow, cookies are present after login, but the heuristic does not fire until the user manually refreshes.
- Android logs in by reading WebView CookieManager cookies on redirect; this patch mirrors that more closely by reacting to navigation/cookie changes and then verifying through shared code.

## Verification
- CI pending

## Mistakes
- None in this fix

## Known Limits
- If the website changes to a pure AJAX login that neither navigates nor writes cookies until later, the cookie observer should still catch the cookie write.
