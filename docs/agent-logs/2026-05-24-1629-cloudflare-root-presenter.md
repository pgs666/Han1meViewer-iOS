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

- Attached the Cloudflare challenge presenter to the app root.

## Why

- Cloudflare blocks can happen from any tab. A root-level presenter allows the app to show one shared challenge flow without duplicating sheet state in every screen.

## Mistakes Or Failed Attempts

- No failed attempt in this step.

## Verification

- Pending iOS CI verification.

## Known Limits

- The presenter opens automatically when the app's error mapper detects a Cloudflare/403 block.
