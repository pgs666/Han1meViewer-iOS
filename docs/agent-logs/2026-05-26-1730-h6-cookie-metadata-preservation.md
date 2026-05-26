# H6: WebView Cookie 元数据保留

## User Input

Original:
H6. WebView 抽 cookie 丢元数据（expires / secure / httpOnly）— LoginView.swift:196-205 把 WKHTTPCookieStore 的 cookie 拼成 name=value 字符串，shared 端解析时丢失 expires/httpOnly/secure/domain/path。

English translation:
H6. WebView cookie extraction loses metadata (expires / secure / httpOnly) — LoginView.swift:196-205 concatenates WKHTTPCookieStore cookies as name=value strings, losing expires/httpOnly/secure/domain/path when parsed by shared code.

## What Changed
- `WebLoginFeature.kt`:
  - Added `importConfirmedLoginCookiesJson(cookieJson, fallbackDomain)` method
  - Added `WebCookiePayload` DTO with full cookie fields
  - Added `importConfirmedLoginCookies(cookies)` internal method
- `LoginView.swift`:
  - Added `fileprivate static func encodeCookiesForImport(_ cookies: [HTTPCookie]) -> String?`
  - Serializes cookies with domain, path, expiresDate, isSecure, isHTTPOnly
  - Updated `importConfirmedLoginCookies(from:)` to pass JSON instead of header string

## Why Changed
- Original implementation lost cookie metadata (expires, httpOnly, secure, domain, path)
- `deleteExpired()` in SessionStore couldn't expire cookies because all had `expires=null`
- Review item H6 from `review-ios-vs-android.md`

## Verification
- CI passed after fix (run 26436212938)

## Mistakes
- Initial implementation used `private static` for `encodeCookiesForImport`, but it was called from `Coordinator` in a different scope
- Caused "'encodeCookiesForImport' is inaccessible due to 'private' protection level" error
- Fixed by changing to `fileprivate static` (commit c641046)

## Known Limits
- Old `importConfirmedLoginCookieHeader()` preserved for backward compatibility and tests
- Could be removed once all callers use the JSON variant
