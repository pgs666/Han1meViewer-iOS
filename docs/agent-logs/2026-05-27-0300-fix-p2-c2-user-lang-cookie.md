# Fix P2-C2: user_lang cookie injection

Date: 2026-05-27 03:00 +08:00
Branch: fix/review-bugs-performance-quality
Commit: cab9333

## User Input

Original:

```text
也一并提交
```

English translation:

```text
Submit those as well.
```

(Context: User asked to fix and commit all remaining valuable review items including P2-C2.)

## What Changed

- `CookieHeaderProvider.kt`: Added `preferencesCookies()` method that reads `contentLanguage` and `subtitleLanguage` from `PreferencesStore` and encodes them as a `user_lang` cookie in the format `content_lang=xx_subtitle_lang=xx`. The cookie is injected in `buildCookieHeader()` alongside existing session cookies.
- `CookieHeaderProviderTest.kt`: Updated expected test values to include the `user_lang` cookie that now appears first (alphabetical sort).

## Why

The Android version injects `user_lang` cookie in `CookieJarImpl.loadForRequest()` via `preferencesCookies()`. The iOS/KMP shared layer was missing this, so the server didn't receive language preferences from the cookie header.

## Mistakes / Failed Attempts

- Initial test fix had wrong expected cookie order — `user_lang` sorts before `cf_clearance` alphabetically. Fixed by reordering expected strings.

## Verification

- Local JVM test: `:shared:jvmTest` — BUILD SUCCESSFUL
- CI run `26457652111` — success

## Known Limits / Follow-up

- The `user_lang` cookie value format (`content_lang=xx_subtitle_lang=xx`) is inferred from Android source; actual server-side parsing behavior should be verified with a real device.
- P1-D4 (settings UI) still not done — the shared `PreferencesStore` infra is ready but iOS UI work is needed.
