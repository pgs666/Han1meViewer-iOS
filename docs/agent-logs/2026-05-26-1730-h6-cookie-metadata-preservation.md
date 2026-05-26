# H6: WebView Cookie 元数据保留

## 原始输入
H6. WebView 抽 cookie 丢元数据（expires / secure / httpOnly）— LoginView.swift:196-205 把 WKHTTPCookieStore 的 cookie 拼成 name=value 字符串，shared 端解析时丢失 expires/httpOnly/secure/domain/path。

## English Summary
Preserved full WKHTTPCookieStore metadata when importing login cookies:
- Added `importConfirmedLoginCookiesJson()` to WebLoginFeature accepting structured JSON
- Swift side serializes cookies with domain, path, expiresDate, isSecure, isHTTPOnly
- Falls back correctly if expiresDate is nil
- Old `importConfirmedLoginCookieHeader` preserved for tests

## Changes
- `WebLoginFeature.kt`: Added `importConfirmedLoginCookiesJson()`, `WebCookiePayload` DTO, new `importConfirmedLoginCookies()` internal method
- `LoginView.swift`: Added `encodeCookiesForImport()`, updated `importConfirmedLoginCookies(from:)` to pass JSON
