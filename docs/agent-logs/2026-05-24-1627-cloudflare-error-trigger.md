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

- Updated the shared Swift error-message path to request Cloudflare challenge presentation when a Cloudflare/403 block is detected.

## Why

- All current ViewModels already call this error mapper, so it provides app-wide challenge handling without per-screen wiring.

## Mistakes Or Failed Attempts

- No failed attempt in this step.

## Verification

- Pending iOS CI verification.

## Known Limits

- Very broad 403 responses may also present the challenge screen. This is intentional for now because the target site commonly uses Cloudflare for blocking.
