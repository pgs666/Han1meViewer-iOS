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

- Added the plan for a shared Cloudflare feature that imports challenge cookies into the existing KMP session store.

## Why

- Cloudflare cookies must be persisted through the same session pipeline used by Ktor repositories so later requests can include `cf_clearance`.

## Mistakes Or Failed Attempts

- No failed attempt in this step.

## Verification

- Pending Gradle and iOS CI verification after implementation.

## Known Limits

- The shared feature only stores cookies; the actual challenge UI is implemented in Swift with WKWebView.
