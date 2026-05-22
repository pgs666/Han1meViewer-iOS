# Agent Log: Ktor Cookie Auth Repository

Time: 2026-05-22 11:10 +08:00

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## User Input

Original:

```text
把 CookieHeaderProvider 接入 Ktor，然后实现 AuthRepository 的登录流程
```

English translation:

```text
Connect CookieHeaderProvider to Ktor, then implement the AuthRepository login flow.
```

## What I Changed

1. Added `SetCookieParser`.
   - Parses basic `Set-Cookie` headers into `SessionCookie`.
   - Supports `Domain`, `Path`, and `Max-Age`.
   - Uses the request host as fallback domain.

2. Added `Headers.setCookieHeaders()`.
   - Reads all response `Set-Cookie` headers from Ktor response headers.

3. Added `KtorAuthRepository`.
   - Implements `AuthRepository`.
   - Uses `CookieHeaderProvider` to add stored cookies to Ktor requests.
   - Saves response cookies back through `CookieHeaderProvider`.
   - Mirrors Android's login flow:
     - GET `/login` and parse `_token`.
     - POST `/login` with `_token`, `email`, `password`, and `X-CSRF-TOKEN`.
     - GET `/login` again.
     - Treat HTTP 404 as successful login.

4. Added `SetCookieParserTest`.
   - Verifies basic `Set-Cookie` parsing.
   - Verifies fallback domain behavior.

## Why

This is the next vertical slice toward real authentication:

- Ktor requests now have a cookie persistence path.
- AuthRepository has a concrete shared implementation.
- The login flow follows the Android source behavior.

## Known Limits

- `Expires=` date parsing is not implemented yet; only `Max-Age` is handled for expiration.
- Login cannot be fully tested without credentials.
- Successful `LoginResult` currently returns `userId = null` and `username = null`; these can be filled after a post-login home page parse.
- This implementation stores cookies manually rather than using Ktor's built-in cookie storage, because the project already has a shared `SessionStore`.

## Verification

Run locally:

```powershell
.\gradlew.bat :shared:jvmTest
.\gradlew.bat :shared:compileTestKotlinIosSimulatorArm64
```

Then push for GitHub Actions macOS app build verification.
