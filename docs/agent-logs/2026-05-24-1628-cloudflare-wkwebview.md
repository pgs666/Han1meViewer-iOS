## User Input

Original:

```text
做 完整 WKWebView 自动过挑战
```

English translation:

```text
Implement full automatic WKWebView Cloudflare challenge handling.
```

## What Changed

- Added a SwiftUI Cloudflare challenge presenter and WKWebView-based challenge view.
- The WebView watches the default WK cookie store and imports `cf_clearance` into KMP session storage when available.

## Why

- Ktor cannot complete browser-based Cloudflare challenges. WKWebView can run the site challenge scripts and then export the resulting clearance cookie to shared networking.

## Mistakes Or Failed Attempts

- No failed attempt in this step.

## Verification

- Pending iOS CI verification.

## Known Limits

- After the challenge is solved, the current failed page is not automatically retried. The user can refresh the affected screen.
